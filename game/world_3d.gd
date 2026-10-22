extends Node3D

const Simulation = preload("res://game/simulation_3d.gd")
const CommandUI = preload("res://game/command_ui.gd")
var terrain: Node3D
var ghost: Node3D
var cursor_position = Vector2.ZERO
var cursor_valid = false
var building = false
var floating_credits: Array[Dictionary] = []
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
	environment.environment.ambient_light_energy = 0.4
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color("ffd6a0")
	sun.light_energy = 1.35
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
	var preview = cylinder(ghost, Vector3(0, 0.3, 0), 0.75, 0.18, Color("55dcb6"))
	preview.name = "Footprint"
	box(ghost, Vector3(0, 0.65, 0), Vector3(0.7, 0.55, 0.7), Color("55dcb6"))
	ghost.visible = false
	command_ui = CommandUI.new()
	command_ui.world = self
	add_child(command_ui)
	# Simulation steps first, then synchronize the 3D representation.
	process_priority = 10
	get_tree().auto_accept_quit = false

func ground_material() -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.roughness = 1
	var noise = FastNoiseLite.new()
	noise.seed = sim.map_seed
	noise.frequency = 0.45
	noise.fractal_octaves = 4
	var texture = NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.seamless = true
	var gradient = Gradient.new()
	gradient.set_color(0, Color("14232f"))
	gradient.set_color(1, Color("263b47"))
	texture.color_ramp = gradient
	result.albedo_texture = texture
	return result

func build_colony() -> void:
	for credit in floating_credits:
		credit.node.queue_free()
	floating_credits.clear()
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
		for step in range(0, int(length), 2):
			var pos = a.move_toward(b, step)
			var direction = (b - a).normalized()
			var normal = Vector3(-direction.z, 0, direction.x)
			for side in [-1, 1]:
				var lamp = box(terrain, pos + normal * side * 0.98 + Vector3(0, 0.16, 0), Vector3(0.09, 0.045, 0.55), Color("f4b85c"), true)
				lamp.rotation.y = shoulder.rotation.y
	# All solid scenery is outside the freely buildable field.
	var rng = RandomNumberGenerator.new()
	rng.seed = sim.map_seed + 42
	for i in 9:
		var x = -26.0 + i * 6.4
		var h = rng.randf_range(1.8, 5.3)
		box(terrain, Vector3(x, h / 2, -13.6), Vector3(3.8, h, 3), Color("27394c"))
		box(terrain, Vector3(x, h + 0.16, -13.6), Vector3(4.2, 0.32, 3.4), Color("607389"))
		for window in 4:
			box(terrain, Vector3(x - 1.25 + window * 0.85, h * 0.65, -12.08), Vector3(0.4, 0.4, 0.05), Color("62c8e6"), true)
		cylinder(terrain, Vector3(x + 0.8, h + 0.75, -13.6), 0.22, 1.2, Color("516677"))
	for i in 30:
		var x = rng.randf_range(-27, 27)
		var z = rng.randf_range(11.4, 14.5) if i % 2 == 0 else rng.randf_range(-15.5, -12.2)
		var rock = cylinder(terrain, Vector3(x, 0.12, z), rng.randf_range(0.2, 0.65), rng.randf_range(0.3, 0.9), Color("56606b"))
		rock.rotation.z = rng.randf_range(-0.5, 0.5)
	for x in range(-25, 27, 6):
		box(terrain, Vector3(x, 0.35, 13), Vector3(3.2, 0.7, 0.65), Color("465865"))
		box(terrain, Vector3(x, 0.76, 13), Vector3(1, 0.1, 0.4), Color("6daec2"), true)
	# Entry anomaly and the command bunker move with the random lane.
	var entry = point(path[0] + Vector2(90, 0))
	var portal = TorusMesh.new()
	portal.inner_radius = 0.9
	portal.outer_radius = 1.15
	var gate = shape(terrain, entry + Vector3(0, 1.25, 0), portal, Color("b74e68"), true)
	gate.rotation.z = PI / 2
	var base = point(path[-1] - Vector2(80, 0))
	box(terrain, base + Vector3(0, 1.1, 0), Vector3(2.8, 2.2, 3.3), Color("304d64"))
	box(terrain, base + Vector3(0, 2.3, 0), Vector3(3.2, 0.25, 3.7), Color("7594a6"))
	box(terrain, base + Vector3(-1.44, 0.95, 0), Vector3(0.08, 1.7, 2.1), Color("4fd8ec"), true)
	for side in [-1, 1]:
		cylinder(terrain, base + Vector3(0.2, 2.7, side), 0.28, 0.7, Color("1c3549"))
		box(terrain, base + Vector3(0.2, 3.1, side), Vector3(0.45, 0.1, 0.45), Color("65d7eb"), true)

func begin_build(kind: int) -> void:
	sim.choose_weapon(kind)
	sim.selected = -1
	building = true

func ground_at(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.15).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func spawn_credit(pos: Vector2, amount: int) -> void:
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

func make_tower(data: Dictionary) -> Node3D:
	var model = Node3D.new()
	units.add_child(model)
	cylinder(model, Vector3(0, 0.15, 0), 0.83, 0.25, Color("374958"))
	cylinder(model, Vector3(0, 0.32, 0), 0.65, 0.12, Color("78929d"))
	cylinder(model, Vector3(0, 0.5, 0), 0.48, 0.3, Color("24394a"))
	var head = Node3D.new()
	head.name = "Head"
	model.add_child(head)
	var color: Color = sim.weapon(data).color
	box(head, Vector3(0, 0.9, 0), Vector3(0.85, 0.6, 0.8), color.darkened(0.45))
	for side in [-1, 1]:
		box(head, Vector3(side * 0.52, 0.95, 0.05), Vector3(0.25, 0.32, 0.52), color.darkened(0.2))
		box(model, Vector3(side * 0.42, 0.28, 0.4), Vector3(0.25, 0.25, 0.3), Color("75848b"))
	box(head, Vector3(0, 1.35, 0.1), Vector3(0.45, 0.4, 0.42), Color("6c8799"))
	box(head, Vector3(0, 1.38, -0.13), Vector3(0.36, 0.12, 0.08), Color("ffd37b"), true)
	var kind = int(data.get("kind", 0))
	if kind == 1:
		var barrel = cylinder(head, Vector3(0, 1.1, -0.5), 0.23, 0.9, Color("8b754f"))
		barrel.rotation.x = PI / 3
	elif kind == 2:
		box(head, Vector3(0, 1.05, -0.65), Vector3(0.3, 0.3, 1.1), Color("635794"))
		cylinder(head, Vector3(0, 1.2, -0.85), 0.18, 0.4, color)
	else:
		for side in [-1, 1]:
			box(head, Vector3(side * 0.22, 1, -0.6), Vector3(0.13, 0.15, 1.1), Color("8195a1"))
	var badge = Label3D.new()
	badge.name = "Badge"
	badge.position = Vector3(0, 1.85, 0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font_size = 32
	badge.pixel_size = 0.014
	badge.modulate = color
	model.add_child(badge)
	if int(data.get("branch", -1)) >= 0:
		for side in [-1, 1]:
			box(head, Vector3(side * 0.35, 1.2, 0.35), Vector3(0.15, 0.45, 0.18), color, true)
	return model

func make_zombie(data: Dictionary) -> Node3D:
	var model = Node3D.new()
	units.add_child(model)
	var skin: Color = Color("8ca575") * data.get("tint", Color.WHITE)
	var body = CapsuleMesh.new()
	body.radius = 0.25
	body.height = 0.7
	body.radial_segments = 10
	body.rings = 4
	shape(model, Vector3(0, 0.8, 0), body, Color("394a45"))
	box(model, Vector3(0, 0.83, -0.23), Vector3(0.14, 0.32, 0.06), Color("734b46"))
	sphere(model, Vector3(0, 1.24, -0.02), 0.2, skin)
	for side in [-1, 1]:
		var leg = cylinder(model, Vector3(side * 0.15, 0.28, 0), 0.09, 0.55, Color("343f44"))
		leg.name = "LegL" if side == -1 else "LegR"
		var arm = cylinder(model, Vector3(side * 0.33, 0.83, -0.23), 0.085, 0.65, skin)
		arm.rotation.x = PI / 2 - 0.2
		sphere(model, Vector3(side * 0.33, 0.79, -0.55), 0.11, skin)
		box(model, Vector3(side * 0.1, 1.28, -0.19), Vector3(0.07, 0.05, 0.035), Color("ff7451"), true)
	if data.get("kind", "") == "Panzer":
		box(model, Vector3(0, 0.85, -0.17), Vector3(0.52, 0.4, 0.12), Color("7893a7"))
	if data.get("kind", "") == "Titan":
		for side in [-1, 1]:
			box(model, Vector3(side * 0.36, 1.15, 0), Vector3(0.25, 0.25, 0.4), Color("846858"))
		var badge = Label3D.new()
		badge.text = "TITAN"
		badge.position = Vector3(0, 1.85, 0)
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.font_size = 32
		badge.pixel_size = 0.012
		badge.modulate = Color("f0ad85")
		model.add_child(badge)
	var health = box(model, Vector3(0, 1.65, 0), Vector3(0.7, 0.06, 0.06), Color("b7e775"), true)
	health.name = "Health"
	return model

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
			select_at_screen(event.position)

func select_at_screen(screen: Vector2) -> void:
	var hit = ground_at(screen)
	if hit == null:
		return
	var map_pos = Vector2(hit.x * 32 + 700, hit.z * 32 + 400)
	# Pick rendered bodies first so clicking the barrel/head also selects a tower.
	for index in sim.towers.size():
		var tower: Dictionary = sim.towers[index]
		var pos: Vector2 = sim.get_pads()[tower.pad]
		var projected = camera.unproject_position(point(pos, 0.8))
		if map_pos.distance_to(pos) < 34 or projected.distance_to(screen) < 22:
			sim.selected = index
			building = false
			return
	if building:
		var reason: String = sim.placement_reason(map_pos)
		if not sim.place_at(map_pos):
			command_ui.show_toast(reason)
		else:
			building = false
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
	ghost.visible = building and not command_ui.menu.visible and hit != null and get_viewport().get_mouse_position().y > 104 and get_viewport().get_mouse_position().y < 655
	if ghost.visible:
		cursor_position = Vector2(hit.x * 32 + 700, hit.z * 32 + 400)
		cursor_valid = sim.placement_reason(cursor_position).is_empty()
		ghost.position = point(cursor_position)
		for child in ghost.get_children():
			child.material_override = mat(Color("4bd3ae") if cursor_valid else Color("e16d73"), true)
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
		model.get_node("Head").rotation.y = -float(data.get("aim", 0))
	for data in sim.enemies:
		if not is_instance_valid(data.get("model")):
			data["model"] = make_zombie(data)
		var model: Node3D = data.model
		model.set_meta("retained", true)
		model.position = point(data.pos)
		var target = point(sim.get_route()[mini(data.segment, sim.get_route().size() - 1)])
		if model.position.distance_to(target) > 0.01:
			model.look_at(target)
		var size = minf(1.65, 0.75 + sim.wave * 0.045) * float(data.get("size", 1))
		model.scale = Vector3.ONE * size
		model.get_node("LegL").rotation.x = sin(sim.visual_time * 10 + data.pos.x) * 0.5
		model.get_node("LegR").rotation.x = -model.get_node("LegL").rotation.x
		model.get_node("Health").material_override = mat(Color("9edaff") if float(data.get("slow_time", 0)) > 0 else Color("b7e775"), true)
		model.get_node("Health").visible = data.hp < data.max_hp or data.get("kind", "") == "Titan"
		model.get_node("Health").scale.x = maxf(0.01, data.hp / data.max_hp)
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
		var a = point(shot.from, 1.0)
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
