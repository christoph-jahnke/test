extends Node3D

const Assets = preload("res://game/asset_catalog.gd")
const Simulation = preload("res://game/simulation_3d.gd")
const CommandUI = preload("res://game/command_ui.gd")
var terrain: Node3D
var ghost: Node3D
var cursor_position = Vector2.ZERO
var cursor_valid = false
var building = false
var hovered_tower = -1
var hit_material: StandardMaterial3D
var floating_credits: Array[Dictionary] = []
var death_effects: Array[Dictionary] = []
var ghost_good: StandardMaterial3D
var ghost_bad: StandardMaterial3D
var command_ui: CanvasLayer
var sun: DirectionalLight3D
var sound_players: Array[AudioStreamPlayer] = []
var sound_streams: Dictionary = {}
var sound_index = 0
var last_shot_sound = 0
var beam_pool: Array[MeshInstance3D] = []
var blast_pool: Array[MeshInstance3D] = []
var spark_pool: Array[MeshInstance3D] = []
var camera_shift = Vector3.ZERO
var sim: Node2D
var camera: Camera3D
var units: Node3D
var effects: Node3D
var range_ring: MeshInstance3D
var materials: Dictionary = {}

func point(pos: Vector2, height: float = 0.0) -> Vector3:
	return Vector3((pos.x - 700) / 32.0, height, (pos.y - 400) / 32.0)

func mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key = str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.75
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.albedo_color = color.darkened(0.65)
		result.emission_energy_multiplier = 0.9
	materials[key] = result
	return result

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return shape(parent, at, mesh, color, glow)

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return shape(parent, at, mesh, color)

func sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return shape(parent, at, mesh, color)

func shape(parent: Node3D, at: Vector3, mesh: Mesh, color: Color, glow: bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color, glow)
	parent.add_child(node)
	node.position = at
	return node

func _ready() -> void:
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b2a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("6e93bd")
	environment.environment.ambient_light_energy = 0.52
	var sky = Sky.new()
	var atmosphere = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("23364e")
	atmosphere.sky_horizon_color = Color("52667a")
	atmosphere.ground_bottom_color = Color("151c26")
	atmosphere.ground_horizon_color = Color("363b43")
	sky.sky_material = atmosphere
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color("ffd6a0")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 60
	camera.position = Vector3(6, 36, 30)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 3.0))
	camera.current = true
	sim = Simulation.new()
	add_child(sim)
	for child in sim.get_children():
		if child is CanvasLayer:
			child.visible = false
	build_colony()
	sim.map_changed.connect(build_colony)
	sim.enemy_defeated.connect(spawn_credit)
	units = Node3D.new()
	add_child(units)
	effects = Node3D.new()
	add_child(effects)
	range_ring = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = 0.99
	ring.outer_radius = 1.01
	ring.rings = 64
	ring.ring_segments = 6
	range_ring.mesh = ring
	range_ring.material_override = mat(Color("47acc7"), true)
	add_child(range_ring)
	for kind in ["shot", "mortar", "cryo", "build", "wave", "alarm"]:
		sound_streams[kind] = load("res://audio/%s.wav" % kind)
	for i in 10:
		var player = AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		sound_players.append(player)
	ghost = Node3D.new()
	add_child(ghost)
	ghost_good = preview_material(Color(0.2, 0.9, 0.7, 0.5))
	ghost_bad = preview_material(Color(0.95, 0.2, 0.25, 0.5))
	ghost.visible = false
	hit_material = StandardMaterial3D.new()
	hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_material.albedo_color = Color(1.0, 0.62, 0.43, 0.42)
	command_ui = CommandUI.new()
	command_ui.world = self
	add_child(command_ui)
	# Simulation steps first, then synchronize the 3D representation.
	process_priority = 10
	get_tree().auto_accept_quit = false

func ground_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
uniform float ground_seed = 0.0;
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),u.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),u.x),u.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p = world_pos.xz + vec2(ground_seed,ground_seed*0.37);
 float dust = noise2(p*0.6);
 float grain = noise2(p*38.0);
 float scars = smoothstep(0.60,0.78,noise2(p*2.0));
 vec3 soil = mix(vec3(0.065,0.082,0.095),vec3(0.125,0.112,0.090),dust);
 ALBEDO = soil * (0.84 + grain*0.28) * (1.0 - scars*0.18);
 ROUGHNESS = 0.96;
}
"""
	var result = ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("ground_seed", float(sim.map_seed % 1000))
	return result

func scenery(index: int, at: Vector3, angle: float = 0.0, scale_value: float = 1.0) -> Node3D:
	var model = Assets.create(index)
	terrain.add_child(model)
	model.position = at
	model.rotation.y = angle
	model.scale *= scale_value
	return model

func build_colony() -> void:
	for credit in floating_credits:
		credit.node.queue_free()
	floating_credits.clear()
	for effect in death_effects:
		effect.node.queue_free()
	death_effects.clear()
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.queue_free()
	terrain = Node3D.new()
	add_child(terrain)
	var floor_node = box(terrain, Vector3(0, -0.35, 0), Vector3(58, 0.6, 34), Color("27323c"))
	floor_node.material_override = ground_material()
	var path: Array = sim.get_route()
	for i in range(path.size() - 1):
		var a = point(path[i])
		var b = point(path[i + 1])
		var length = a.distance_to(b)
		var shoulder = box(terrain, (a + b) / 2, Vector3(2.35, 0.12, length + 2.35), Color("465258"))
		shoulder.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var road = box(terrain, (a + b) / 2 + Vector3(0, 0.08, 0), Vector3(1.7, 0.12, length + 1.7), Color("151e29"))
		road.rotation.y = shoulder.rotation.y
		var offset = 0.0
		while offset < length - 0.001:
			var span = minf(2.0, length - offset)
			var kind = [0, 0, 1, 3][posmod(i + sim.map_seed, 4)]
			if i % 4 == 2 and absf(offset - length / 2) < 2:
				kind = 2
			var tile = Assets.create(13 + kind)
			terrain.add_child(tile)
			tile.position = a.move_toward(b, offset + span / 2) + Vector3(0, 0.18, 0)
			tile.rotation.y = shoulder.rotation.y
			tile.scale.z = span / 2
			offset += span

	# Raised scenery stays beyond the free-build bounds; only flat ground damage is inside.
	var rng = RandomNumberGenerator.new()
	rng.seed = sim.map_seed + 42
	var skyline = [30, 22, 18, 29, 23, 24, 30, 22, 18]
	for i in skyline.size():
		var x = -26.0 + i * 6.4
		scenery(skyline[i], Vector3(x, 0, -13.4), PI + rng.randf_range(-0.16, 0.16))
		scenery(20 if i % 2 == 0 else 21, Vector3(x + 1.6, 0, -11.8), rng.randf_range(-0.4, 0.4), 0.8)
	var foreground = [28, 19, 29, 25, 20, 19, 22, 21]
	for i in foreground.size():
		scenery(foreground[i], Vector3(-25 + i * 7.0, 0, 12.5), PI + rng.randf_range(-0.3, 0.3))
	for x in [-21.0, 13.0]:
		scenery(24, Vector3(x, 0, 11.65))
		var lamp = OmniLight3D.new()
		lamp.position = Vector3(x, 2.6, 11.4)
		lamp.light_color = Color("b8c8d0")
		lamp.omni_range = 5
		lamp.light_energy = 0.6
		terrain.add_child(lamp)
	# Scorch marks and shallow rubble do not create invisible building restrictions.
	for i in 18:
		var pos = Vector2(rng.randf_range(35, 1330), rng.randf_range(80, 720))
		if sim.road_distance(pos) > 85:
			scenery(26 if i % 3 == 0 else 27, point(pos, 0.002), rng.randf_range(0, TAU), rng.randf_range(0.6, 1.1))
	# Entry anomaly and the command bunker move with the random lane.
	var entry = point(path[0] + Vector2(90, 0))
	scenery(31, entry, PI / 2)
	var portal = TorusMesh.new()
	portal.inner_radius = 0.9
	portal.outer_radius = 1.15
	var gate = shape(terrain, entry + Vector3(-1.7, 1.25, 0), portal, Color("b74e68"), true)
	gate.rotation.z = PI / 2
	var base = point(path[-1] - Vector2(80, 0))
	var bunker = Assets.create(17)
	terrain.add_child(bunker)
	bunker.position = base
	bunker.rotation.y = PI / 2

func preview_material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.albedo_color = color
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func tint_preview(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		tint_preview(child, material)

func begin_build(kind: int) -> void:
	for child in ghost.get_children():
		child.free()
	ghost.add_child(Assets.create(kind))
	sim.choose_weapon(kind)
	sim.selected = -1
	building = true

func ground_at(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.15).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func spawn_credit(pos: Vector2, amount: int) -> void:
	spawn_death_effect(pos)
	var coin = Node3D.new()
	add_child(coin)
	coin.position = point(pos, 1.0)
	var token = cylinder(coin, Vector3.ZERO, 0.22, 0.065, Color("ffd474"))
	token.rotation.x = PI / 2
	var text = Label3D.new()
	text.text = "+$%d" % amount
	text.position = Vector3(0, 0.45, 0)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.font_size = 48
	text.pixel_size = 0.016
	text.modulate = Color("ffe09a")
	text.no_depth_test = true
	coin.add_child(text)
	floating_credits.append({"node": coin, "pos": coin.position, "age": 0.0, "token": token})

func spawn_death_effect(pos: Vector2) -> void:
	if death_effects.size() >= 24:
		death_effects[0].node.queue_free()
		death_effects.pop_front()
	var group = Node3D.new()
	add_child(group)
	group.position = point(pos, 0.31)
	var stain = sphere(group, Vector3.ZERO, 0.32, Color("38121c"))
	stain.scale = Vector3(1.3, 0.025, 0.8)
	var pieces = []
	for i in 5:
		var mesh = sphere(group, Vector3(0, 0.5, 0), 0.055 + i * 0.008, Color("7e3033") if i % 2 == 0 else Color("b1a478"))
		pieces.append({"mesh": mesh, "velocity": Vector3(cos(i * 2.4) * 1.5, 1.8 + i * 0.2, sin(i * 2.4) * 1.5)})
	death_effects.append({"node": group, "age": 0.0, "pieces": pieces})

func make_tower(data: Dictionary) -> Node3D:
	var model = Assets.create(Assets.tower_index(int(data.kind), int(data.get("branch", -1))))
	units.add_child(model)
	var badge = Label3D.new()
	badge.name = "Badge"
	badge.position = Vector3(0, 2.05, 0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font_size = 32
	badge.pixel_size = 0.014
	badge.modulate = sim.weapon(data).color
	model.add_child(badge)
	var ring = TorusMesh.new()
	ring.inner_radius = 0.83
	ring.outer_radius = 0.88
	ring.rings = 40
	ring.ring_segments = 6
	var selection = shape(model, Vector3(0, 0.13, 0), ring, Color("6cded1"), true)
	selection.name = "Selection"
	selection.visible = false
	var head = model.find_child("Head", true, false)
	var flash = Node3D.new()
	flash.name = "MuzzleFX"
	head.add_child(flash)
	var kind = int(data.kind)
	var branch = int(data.get("branch", -1))
	flash.position = Vector3(0, 0.98, -1.18 if branch < 0 else (-1.85 if branch == 0 else -1.52))
	if kind == 1:
		flash.position = Vector3(0, 1.58 if branch != 0 else 1.88, -0.68)
	elif kind == 2:
		flash.position = Vector3(0, 1.55, -0.08)
	var glow = sphere(flash, Vector3.ZERO, 0.16 if kind == 0 else 0.22, Color("b6edff") if kind == 2 else Color("ffca71"))
	glow.material_override = mat(Color("b6edff") if kind == 2 else Color("ffca71"), true)
	glow.scale = Vector3(0.65, 0.65, 1.8) if kind == 0 else Vector3.ONE
	flash.visible = false
	model.set_meta("last_cooldown", float(data.cooldown))
	model.set_meta("recoil_time", 0.0)
	return model

func make_zombie(data: Dictionary) -> Node3D:
	var model = Assets.create(Assets.enemy_index(data.get("kind", "Zombie")))
	units.add_child(model)
	model.set_meta("asset_scale", model.scale)
	if data.get("kind", "") == "Titan":
		var badge = Label3D.new()
		badge.text = "TITAN"
		badge.position = Vector3(0, 2.1, 0)
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.font_size = 32
		badge.pixel_size = 0.012
		badge.modulate = Color("f0ad85")
		model.add_child(badge)
	var health = Node3D.new()
	health.name = "Health"
	model.add_child(health)
	health.position = Vector3(0, 1.95, 0)
	box(health, Vector3.ZERO, Vector3(0.85, 0.095, 0.01), Color("0c141c"))
	var fill = box(health, Vector3(0, 0, -0.012), Vector3(0.8, 0.05, 0.015), Color("bedc83"), true)
	fill.name = "Fill"
	var frost_mesh = TorusMesh.new()
	frost_mesh.inner_radius = 0.32
	frost_mesh.outer_radius = 0.36
	frost_mesh.rings = 24
	frost_mesh.ring_segments = 6
	var frost = shape(model, Vector3(0, 0.03, 0), frost_mesh, Color("90d8ee"), true)
	frost.name = "Frost"
	frost.visible = false
	model.set_meta("previous_hp", float(data.hp))
	model.set_meta("hit_time", 0.0)
	return model

func damage_overlay(node: Node, active: bool) -> void:
	if node.name in ["Health", "Frost"]:
		return
	if node is MeshInstance3D:
		node.material_overlay = hit_material if active else null
	for child in node.get_children():
		damage_overlay(child, active)

func center_camera() -> void:
	camera_shift = Vector3.ZERO
	camera.position = Vector3(6, 36, 30)
	camera.look_at(Vector3(0, 0, 3))
	camera.size = 60

func play_sound(kind: String) -> void:
	if not sound_streams.has(kind):
		return
	if kind in ["shot", "cryo"]:
		var now = Time.get_ticks_msec()
		if now - last_shot_sound < 85:
			return
		last_shot_sound = now
	var player = sound_players[sound_index % sound_players.size()]
	player.stop()
	player.stream = sound_streams[kind]
	player.play()
	sound_index += 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if sim.save_run() == OK:
				command_ui.show_toast("EINSATZ GESPEICHERT")
		elif event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE and (building or sim.selected >= 0) and not command_ui.menu.visible:
			building = false
			sim.selected = -1
		elif event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			if command_ui.research_panel.visible:
				command_ui.hide_research()
			elif command_ui.menu.visible:
				command_ui.resume_action()
			else:
				command_ui.open_menu()
		elif not command_ui.menu.visible:
			if event.keycode in [KEY_1, KEY_2, KEY_3]:
				begin_build(event.keycode - KEY_1)
			elif event.keycode == KEY_Q:
				sim.activate_overdrive()
			elif event.keycode == KEY_F:
				center_camera()
	if command_ui.menu.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(26, camera.size - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(70, camera.size + 2)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			building = false
			sim.selected = -1
		elif event.button_index == MOUSE_BUTTON_LEFT and not sim.paused and sim.lives > 0:
			select_at_screen(event.position, event.shift_pressed)

func tower_at_screen(screen: Vector2) -> int:
	# Nearest projected body wins; array order must not pick a neighbouring turret.
	var closest = -1
	var distance = 27.0
	for index in sim.towers.size():
		var pos: Vector2 = sim.get_pads()[sim.towers[index].pad]
		var projected = camera.unproject_position(point(pos, 0.75))
		var candidate = projected.distance_to(screen)
		var model = sim.towers[index].get("model")
		if is_instance_valid(model):
			var muzzle = model.find_child("MuzzleFX", true, false)
			if muzzle != null:
				var tip = camera.unproject_position(muzzle.global_position)
				candidate = minf(candidate, screen.distance_to(Geometry2D.get_closest_point_to_segment(screen, projected, tip)))
		if candidate < distance:
			closest = index
			distance = candidate
	return closest

func select_at_screen(screen: Vector2, repeat_build: bool = false) -> void:
	if command_ui.blocks_world(screen):
		return
	var hit = ground_at(screen)
	if hit == null:
		return
	var map_pos = Vector2(hit.x * 32 + 700, hit.z * 32 + 400)
	var picked = tower_at_screen(screen)
	if picked >= 0:
		sim.selected = picked
		building = false
		return
	if building:
		var reason: String = sim.placement_reason(map_pos)
		if not sim.place_at(map_pos):
			command_ui.show_toast(reason)
		else:
			building = repeat_build and sim.cash >= sim.WEAPONS[sim.build_type].cost
			if building:
				sim.selected = -1
	else:
		sim.selected = -1

func _process(_delta: float) -> void:
	if not command_ui.menu.visible:
		var direction = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		camera_shift += direction * _delta * 15
		camera_shift.x = clampf(camera_shift.x, -16, 16)
		camera_shift.z = clampf(camera_shift.z, -10, 10)
		camera.position = Vector3(6, 36, 30) + camera_shift
	var hit = ground_at(get_viewport().get_mouse_position())
	var screen_mouse = get_viewport().get_mouse_position()
	hovered_tower = tower_at_screen(screen_mouse) if not building and not command_ui.blocks_world(screen_mouse) else -1
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered_tower >= 0 else Input.CURSOR_ARROW)
	ghost.visible = building and not command_ui.blocks_world(screen_mouse) and hit != null
	if ghost.visible:
		cursor_position = Vector2(hit.x * 32 + 700, hit.z * 32 + 400)
		cursor_valid = sim.placement_reason(cursor_position).is_empty()
		ghost.position = point(cursor_position)
		tint_preview(ghost, ghost_good if cursor_valid else ghost_bad)
	for effect in death_effects:
		if not sim.paused:
			effect.age += _delta * sim.speed
			for piece in effect.pieces:
				piece.mesh.position += piece.velocity * _delta * sim.speed
				piece.velocity.y -= _delta * sim.speed * 6
				if piece.mesh.position.y < 0:
					piece.mesh.position.y = 0
					piece.velocity = Vector3.ZERO
		if effect.age > 4:
			effect.node.scale = Vector3.ONE * maxf(0.01, (6 - effect.age) / 2)
		if effect.age >= 6:
			effect.node.queue_free()
	death_effects = death_effects.filter(func(effect): return effect.age < 6)
	for credit in floating_credits:
		if not sim.paused:
			credit.age += _delta * sim.speed
			credit.token.rotation.y += _delta * 8
		credit.node.position = credit.pos + Vector3(0, sin(minf(credit.age / 0.8, 1) * PI / 2) * 1.5, 0)
		credit.node.scale = Vector3.ONE * clampf((1.4 - credit.age) * 3, 0.01, 1)
		if credit.age >= 1.4:
			credit.node.queue_free()
	floating_credits = floating_credits.filter(func(credit): return credit.age < 1.4)
	for child in units.get_children():
		child.set_meta("retained", false)
	var muzzle_origins: Dictionary = {}
	for data in sim.towers:
		var branch = int(data.get("branch", -1))
		if is_instance_valid(data.get("model")) and int(data.get("rendered_branch", -1)) != branch:
			data.model.queue_free()
			data.erase("model")
		if not is_instance_valid(data.get("model")):
			data["model"] = make_tower(data)
			data["rendered_branch"] = branch
		var model: Node3D = data.model
		model.set_meta("retained", true)
		model.position = point(sim.get_pads()[data.pad])
		var branch_name: String = sim.BRANCHES[int(data.kind)][branch] if branch >= 0 else sim.weapon(data).name
		model.get_node("Badge").visible = sim.selected >= 0 and data == sim.towers[sim.selected]
		model.get_node("Badge").text = "%s / MK %d" % [branch_name, data.level]
		var selected = sim.selected >= 0 and data == sim.towers[sim.selected]
		var hovered = hovered_tower >= 0 and data == sim.towers[hovered_tower]
		model.get_node("Selection").visible = selected or hovered
		model.get_node("Selection").scale = Vector3.ONE * (1.0 if selected else 0.9)
		var head = model.find_child("Head", true, false)
		head.rotation.y = -float(data.get("aim", 0))
		var recoil = float(model.get_meta("recoil_time", 0.0))
		if not sim.paused:
			recoil = maxf(0, recoil - _delta * sim.speed)
			if float(data.cooldown) > float(model.get_meta("last_cooldown", 0.0)) + 0.001:
				recoil = 0.16
		model.set_meta("recoil_time", recoil)
		model.set_meta("last_cooldown", float(data.cooldown))
		head.position.z = recoil * 0.7 if int(data.kind) != 2 else 0.0
		var flash = head.get_node("MuzzleFX")
		flash.visible = recoil > 0.09
		flash.scale = Vector3.ONE * (0.5 + recoil * 4)
		muzzle_origins[sim.get_pads()[data.pad]] = flash.global_position
		var rotor = model.find_child("Rotor", true, false)
		if rotor != null and not sim.paused and data.cooldown > 0:
			rotor.rotation.z += _delta * sim.speed * 25
	for data in sim.enemies:
		if not is_instance_valid(data.get("model")):
			data["model"] = make_zombie(data)
		var model: Node3D = data.model
		model.set_meta("retained", true)
		var gait = 14.0 if data.get("kind", "") == "Sprinter" else (5.0 if data.get("kind", "") == "Titan" else 8.0)
		var phase = sim.visual_time * gait + data.pos.x
		var frozen = float(data.get("slow_time", 0)) > 0
		model.position = point(data.pos, 0.29 + absf(sin(phase)) * 0.025)
		var target = point(sim.get_route()[mini(data.segment, sim.get_route().size() - 1)])
		target.y = model.position.y
		if model.position.distance_to(target) > 0.01:
			model.look_at(target)
		var size = minf(1.65, 0.75 + sim.wave * 0.045) * float(data.get("size", 1))
		model.scale = model.get_meta("asset_scale", Vector3.ONE) * size
		model.find_child("LegL", true, false).rotation.x = sin(phase) * 0.44
		model.find_child("LegR", true, false).rotation.x = -sin(phase) * 0.44
		for side in 2:
			var offset = phase + side * PI
			model.find_child(["ShinL", "ShinR"][side], true, false).rotation.x = maxf(0, -sin(offset)) * 0.55
			model.find_child(["ArmL", "ArmR"][side], true, false).rotation.x = sin(offset + 0.6) * 0.23
			model.find_child(["ForearmL", "ForearmR"][side], true, false).rotation.x = -0.1 + sin(offset) * 0.16
		model.find_child("Body", true, false).rotation.z = sin(phase * 0.5) * 0.025
		var health = model.get_node("Health")
		health.look_at(camera.global_position)
		health.visible = data.hp < data.max_hp or data.get("kind", "") == "Titan"
		var ratio = clampf(data.hp / data.max_hp, 0.01, 1)
		health.get_node("Fill").scale.x = ratio
		health.get_node("Fill").position.x = -0.4 * (1 - ratio)
		health.get_node("Fill").material_override = mat(Color("9edaff") if frozen else (Color("eb956b") if ratio < 0.3 else Color("bedc83")), true)
		model.get_node("Frost").visible = frozen
		var hit_time = float(model.get_meta("hit_time", 0.0))
		var was_hit = hit_time > 0
		if not sim.paused:
			hit_time = maxf(0, hit_time - _delta * sim.speed)
			if float(data.hp) < float(model.get_meta("previous_hp", data.hp)):
				hit_time = 0.12
		if was_hit != (hit_time > 0):
			damage_overlay(model, hit_time > 0)
		model.set_meta("hit_time", hit_time)
		model.set_meta("previous_hp", float(data.hp))
	for child in units.get_children():
		if not child.get_meta("retained"):
			child.queue_free()
	# Reuse beam and impact meshes rather than allocating them every frame.
	for mesh in beam_pool:
		mesh.visible = false
	for mesh in blast_pool:
		mesh.visible = false
	for mesh in spark_pool:
		mesh.visible = false
	var index = 0
	for shot in sim.shots:
		if beam_pool.size() <= index:
			beam_pool.append(box(effects, Vector3.ZERO, Vector3.ONE, Color.WHITE, true))
		var beam = beam_pool[index]
		var a: Vector3 = muzzle_origins.get(shot.from, point(shot.from, 1.0))
		var b = point(shot.to, 0.8)
		beam.visible = true
		beam.position = (a + b) / 2
		beam.scale = Vector3(0.045, 0.045, maxf(0.01, a.distance_to(b)))
		beam.material_override = mat(shot.get("color", Color.YELLOW), true)
		if a.distance_to(b) > 0.01:
			beam.look_at(b)
		index += 1
	var blast_index = 0
	var spark_index = 0
	for impact in sim.impacts:
		if impact.get("blast", false):
			if blast_pool.size() <= blast_index:
				var blast_mesh = TorusMesh.new()
				blast_mesh.inner_radius = 0.82
				blast_mesh.outer_radius = 1.0
				blast_mesh.rings = 32
				blast_mesh.ring_segments = 8
				blast_pool.append(shape(effects, Vector3.ZERO, blast_mesh, Color("f0a347"), true))
			var blast = blast_pool[blast_index]
			blast.visible = true
			blast.position = point(impact.pos, 0.2)
			var radius = maxf(0.05, (1 - impact.ttl / 0.5) * 2.2)
			blast.scale = Vector3(radius, 0.12, radius)
			blast_index += 1
		else:
			if spark_pool.size() <= spark_index:
				spark_pool.append(box(effects, Vector3.ZERO, Vector3.ONE, Color("f4c579"), true))
			var spark = spark_pool[spark_index]
			spark.visible = true
			spark.position = point(impact.pos, 0.8 + (0.25 - impact.ttl) * 2)
			spark.scale = Vector3.ONE * maxf(0.03, impact.ttl * 0.8)
			spark.rotation += Vector3(0.1, 0.2, 0.1)
			spark_index += 1
	range_ring.visible = sim.selected >= 0 or ghost.visible
	if range_ring.visible:
		var radius: float
		if ghost.visible:
			range_ring.position = point(cursor_position, 0.25)
			radius = (sim.WEAPONS[sim.build_type].range + 10) / 32
		else:
			var data: Dictionary = sim.towers[sim.selected]
			range_ring.position = point(sim.get_pads()[data.pad], 0.25)
			radius = sim.tower_range(data) / 32
		range_ring.scale = Vector3(radius, 0.12, radius)

func _exit_tree() -> void:
	for player in sound_players:
		player.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(sim) and sim.has_started and sim.lives > 0:
			sim.save_run()
		get_tree().quit()
