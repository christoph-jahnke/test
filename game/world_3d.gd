extends Node3D

const Simulation = preload("res://game/simulation_3d.gd")
const CommandUI = preload("res://game/command_ui.gd")
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
var status: Label
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
		result.emission_energy_multiplier = 1.8
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
	environment.environment.ambient_light_color = Color("8cacc4")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffdfb5")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 60
	camera.position = Vector3(0, 38, 34)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 5.0))
	camera.current = true
	build_colony()
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
	sim = Simulation.new()
	add_child(sim)
	for child in sim.get_children():
		if child is CanvasLayer:
			child.visible = false
	for kind in ["shot", "mortar", "cryo", "build", "wave", "alarm"]:
		sound_streams[kind] = load("res://audio/%s.wav" % kind)
	for i in 10:
		var player = AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		sound_players.append(player)
	command_ui = CommandUI.new()
	command_ui.world = self
	add_child(command_ui)
	var ui = CanvasLayer.new()
	add_child(ui)
	status = Label.new()
	status.visible = false
	status.add_theme_color_override("font_color", Color("a5d7ed"))
	ui.add_child(status)
	# Simulation steps first, then synchronize the 3D representation.
	process_priority = 10
	get_tree().auto_accept_quit = false

func build_colony() -> void:
	box(self, Vector3(0, -0.45, 0), Vector3(58, 0.8, 34), Color("182a34"))
	for x in range(-28, 29, 4):
		for z in range(-16, 17, 4):
			box(self, Vector3(x, -0.02, z), Vector3(3.96, 0.08, 3.96), Color("21333e") if (x + z) % 4 == 0 else Color("263943"))
	for i in range(sim_route().size() - 1):
		var a = point(sim_route()[i])
		var b = point(sim_route()[i + 1])
		var length = a.distance_to(b)
		var road = box(self, (a + b) / 2 + Vector3(0, 0.04, 0), Vector3(1.65, 0.1, length + 1.65), Color("101a23"))
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)
		for step in range(int(length)):
			var position = a.move_toward(b, step)
			box(self, position + Vector3(0, 0.11, 0), Vector3(0.12, 0.025, 0.12), Color("d8ac58"), true)
	for pad in Simulation.LARGE_PADS:
		var pos = point(pad)
		box(self, pos + Vector3(0, 0.1, 0), Vector3(1.65, 0.25, 1.65), Color("3b5365"))
		box(self, pos + Vector3(0, 0.24, 0), Vector3(1.35, 0.08, 1.35), Color("172734"))
		for side in [-1, 1]:
			box(self, pos + Vector3(side * 0.65, 0.32, -0.65), Vector3(0.16, 0.12, 0.3), Color("52d7ec"), true)
	for pos in [Vector3(-24, 0, 7), Vector3(-21, 0, 9), Vector3(-4, 0, -12), Vector3(-1, 0, -12), Vector3(17, 0, 10)]:
		box(self, pos + Vector3(0, 0.5, 0), Vector3(1.8, 1, 1.1), Color("4d6066"))
		for rib in range(5):
			box(self, pos + Vector3(-0.72 + rib * 0.36, 0.55, 0), Vector3(0.08, 1.1, 1.17), Color("738186"))
	# Rear fortification, powered gate, generator stacks.
	for x in [-16, -10, -4, 2, 8, 14]:
		box(self, Vector3(x, 0.7, -16), Vector3(5.6, 1.4, 0.5), Color("445564"))
	var base = point(Vector2(1405, 340))
	box(self, base + Vector3(0.5, 1, 0), Vector3(2.8, 2, 3.4), Color("435c70"))
	box(self, base + Vector3(0.5, 2.15, 0), Vector3(3.2, 0.3, 3.8), Color("70899a"))
	box(self, base + Vector3(-0.94, 0.85, 0), Vector3(0.12, 1.7, 2.1), Color("35b9db"), true)
	for side in [-1, 1]:
		cylinder(self, base + Vector3(0.4, 2.7, side), 0.3, 1, Color("284859"))
		box(self, base + Vector3(0.4, 3.25, side), Vector3(0.45, 0.1, 0.45), Color("58e5ed"), true)
	# Industrial skyline stays outside the traversable lane.
	for i in 8:
		var x = -25.0 + i * 7.0
		var h = 2.0 + float(i % 3) * 1.4
		box(self, Vector3(x, h / 2, -14.5), Vector3(4, h, 2.2), Color("344757"))
		box(self, Vector3(x, h + 0.15, -14.5), Vector3(4.3, 0.3, 2.5), Color("617583"))
		for window in 4:
			box(self, Vector3(x - 1.3 + window * 0.85, h * 0.65, -13.36), Vector3(0.48, 0.35, 0.04), Color("6bbacf"), true)
		cylinder(self, Vector3(x + 0.8, h + 0.8, -14.5), 0.18, 1.4, Color("536570"))
	for x in range(-25, 27, 5):
		box(self, Vector3(x, 0.45, 15), Vector3(3.7, 0.9, 0.6), Color("53616a"))
		box(self, Vector3(x, 0.95, 15), Vector3(1.4, 0.08, 0.65), Color("c9a160"))
	for x in [-24, -12, 0, 12, 24]:
		cylinder(self, Vector3(x, 1.8, -11.8), 0.08, 3.6, Color("526577"))
		box(self, Vector3(x, 3.6, -11.8), Vector3(0.8, 0.12, 0.4), Color("b9dfeb"), true)
		var lamp = OmniLight3D.new()
		lamp.position = Vector3(x, 2.8, -11.8)
		lamp.light_color = Color("75c3e7")
		lamp.omni_range = 6
		lamp.light_energy = 0.5
		add_child(lamp)
	var sign = Label3D.new()
	sign.text = "SEKTOR 07 / QUARANTÄNE"
	sign.position = Vector3(0, 3, -13.2)
	sign.font_size = 64
	sign.pixel_size = 0.012
	sign.modulate = Color("74cbe5")
	add_child(sign)
	# Landing apron, power conduits and perimeter rubble give the districts identity.
	cylinder(self, Vector3(-12, 0.08, 11.4), 3, 0.08, Color("304553"))
	var landing = TorusMesh.new()
	landing.inner_radius = 2.65
	landing.outer_radius = 2.72
	shape(self, Vector3(-12, 0.15, 11.4), landing, Color("d3b679"))
	for side in [-1, 1]:
		box(self, Vector3(-12 + side * 0.55, 0.18, 11.4), Vector3(0.15, 0.04, 1.7), Color("b9c8cc"))
	box(self, Vector3(-12, 0.18, 11.4), Vector3(1.1, 0.04, 0.15), Color("b9c8cc"))
	for x in [-23, 21]:
		for side in [-1, 1]:
			cylinder(self, Vector3(x + side * 0.7, 1.1, 11), 0.55, 2.2, Color("596c75"))
			cylinder(self, Vector3(x + side * 0.7, 2.24, 11), 0.58, 0.12, Color("a98e5b"))
	for i in 32:
		var angle = i * 2.399
		var x = cos(angle) * (26 + float(i % 2))
		var z = sin(angle) * 15
		var rock = cylinder(self, Vector3(x, 0.15, z), 0.25 + float(i % 3) * 0.13, 0.4, Color("4c5054"))
		rock.rotation.z = float(i % 4) * 0.2
	for spec in [["01 / FRACHT", Vector3(-19, 0.16, 6)], ["02 / REAKTOR", Vector3(0, 0.16, -2.8)], ["03 / BASTION", Vector3(16, 0.16, 11)]]:
		var decal = Label3D.new()
		decal.text = spec[0]
		decal.position = spec[1]
		decal.rotation_degrees.x = -90
		decal.pixel_size = 0.008
		decal.font_size = 48
		decal.modulate = Color("8c9c9e")
		add_child(decal)

func sim_route() -> Array:
	return Simulation.LARGE_ROUTE

func make_tower(data: Dictionary) -> Node3D:
	var model = Node3D.new()
	units.add_child(model)
	cylinder(model, Vector3(0, 0.4, 0), 0.58, 0.4, Color("263948"))
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
	var skin: Color = Color("859f54") * data.get("tint", Color.WHITE)
	box(model, Vector3(0, 0.8, 0), Vector3(0.48, 0.55, 0.28), Color("4b5d4c"))
	box(model, Vector3(0, 1.24, -0.02), Vector3(0.35, 0.34, 0.32), skin)
	for side in [-1, 1]:
		var leg = box(model, Vector3(side * 0.15, 0.28, 0), Vector3(0.17, 0.55, 0.2), Color("343f44"))
		leg.name = "LegL" if side == -1 else "LegR"
		var arm = box(model, Vector3(side * 0.35, 0.83, -0.22), Vector3(0.14, 0.17, 0.65), skin)
		arm.rotation.x = -0.2
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
	camera.position = Vector3(0, 38, 34)
	camera.look_at(Vector3(0, 0, 5))
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
		elif event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			if command_ui.research_panel.visible:
				command_ui.hide_research()
			elif command_ui.menu.visible:
				command_ui.resume_action()
			else:
				command_ui.open_menu()
		elif not command_ui.menu.visible:
			if event.keycode in [KEY_1, KEY_2, KEY_3]:
				sim.choose_weapon(event.keycode - KEY_1)
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
		elif event.button_index == MOUSE_BUTTON_LEFT and not sim.paused and sim.lives > 0:
			select_at_screen(event.position)

func select_at_screen(screen: Vector2) -> void:
	var plane = Plane(Vector3.UP, 0.25)
	var hit = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return
	for i in Simulation.LARGE_PADS.size():
		if (hit as Vector3).distance_to(point(Simulation.LARGE_PADS[i], 0.25)) < 0.95:
			sim.selected = -1
			for index in sim.towers.size():
				if sim.towers[index].pad == i:
					sim.selected = index
			if sim.selected == -1:
				if not sim.build_at(i):
					command_ui.show_toast("Nicht genügend Kredits für diesen Turm.")
			sim.refresh_ui()
			return

func _process(_delta: float) -> void:
	if not command_ui.menu.visible:
		var direction = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		camera_shift += direction * _delta * 15
		camera_shift.x = clampf(camera_shift.x, -16, 16)
		camera_shift.z = clampf(camera_shift.z, -10, 10)
		camera.position = Vector3(0, 38, 34) + camera_shift
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
		model.position = point(Simulation.LARGE_PADS[data.pad])
		var branch_name: String = sim.BRANCHES[int(data.kind)][branch] if branch >= 0 else sim.weapon(data).name
		model.get_node("Badge").text = "%s / MK %d" % [branch_name, data.level]
		model.get_node("Head").rotation.y = -float(data.get("aim", 0))
	for data in sim.enemies:
		if not is_instance_valid(data.get("model")):
			data["model"] = make_zombie(data)
		var model: Node3D = data.model
		model.set_meta("retained", true)
		model.position = point(data.pos)
		var target = point(Simulation.LARGE_ROUTE[mini(data.segment, Simulation.LARGE_ROUTE.size() - 1)])
		if model.position.distance_to(target) > 0.01:
			model.look_at(target)
		var size = minf(1.65, 0.75 + sim.wave * 0.045) * float(data.get("size", 1))
		model.scale = Vector3.ONE * size
		model.get_node("LegL").rotation.x = sin(sim.visual_time * 10 + data.pos.x) * 0.5
		model.get_node("LegR").rotation.x = -model.get_node("LegL").rotation.x
		model.get_node("Health").material_override = mat(Color("9edaff") if float(data.get("slow_time", 0)) > 0 else Color("b7e775"), true)
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
	range_ring.visible = sim.selected >= 0
	if range_ring.visible:
		var data: Dictionary = sim.towers[sim.selected]
		range_ring.position = point(Simulation.LARGE_PADS[data.pad], 0.29)
		var radius: float = sim.tower_range(data) / 32
		range_ring.scale = Vector3(radius, 0.12, radius)
	status.text = "3D / Mausrad: Zoom · Bauplatz anklicken" if not sim.paused and sim.lives > 0 else ("PAUSE / Weiter zum Fortsetzen" if sim.paused else "BASIS VERLOREN / Neuer Versuch")

func _exit_tree() -> void:
	for player in sound_players:
		player.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(sim) and sim.has_started and sim.lives > 0:
			sim.save_run()
		get_tree().quit()
