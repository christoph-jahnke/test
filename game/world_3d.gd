extends Node3D

const Simulation = preload("res://game/simulation_3d.gd")
var sim: Node2D
var camera: Camera3D
var units: Node3D
var effects: Node3D
var range_ring: MeshInstance3D
var status: Label
var materials: Dictionary = {}

func point(pos: Vector2, height: float = 0.0) -> Vector3:
	return Vector3((pos.x - 550) / 32.0, height, (pos.y - 335) / 32.0)

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
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffdfb5")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 40
	camera.position = Vector3(0, 27, 23)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 2.0))
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
	var ui = CanvasLayer.new()
	add_child(ui)
	status = Label.new()
	status.position = Vector2(24, 568)
	status.add_theme_color_override("font_color", Color("a5d7ed"))
	ui.add_child(status)
	# Simulation steps first, then synchronize the 3D representation.
	process_priority = 10

func build_colony() -> void:
	box(self, Vector3(0, -0.45, 0), Vector3(37, 0.8, 17), Color("182a34"))
	for x in range(-18, 19, 2):
		for z in range(-8, 9, 2):
			box(self, Vector3(x, -0.02, z), Vector3(1.96, 0.08, 1.96), Color("21333e") if (x + z) % 4 == 0 else Color("263943"))
	for i in range(sim_route().size() - 1):
		var a = point(sim_route()[i])
		var b = point(sim_route()[i + 1])
		var length = a.distance_to(b)
		var road = box(self, (a + b) / 2 + Vector3(0, 0.04, 0), Vector3(1.65, 0.1, length + 1.65), Color("101a23"))
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)
		for step in range(int(length)):
			var position = a.move_toward(b, step)
			box(self, position + Vector3(0, 0.11, 0), Vector3(0.12, 0.025, 0.12), Color("d8ac58"), true)
	for pad in Simulation.PADS:
		var pos = point(pad)
		box(self, pos + Vector3(0, 0.1, 0), Vector3(1.65, 0.25, 1.65), Color("3b5365"))
		box(self, pos + Vector3(0, 0.24, 0), Vector3(1.35, 0.08, 1.35), Color("172734"))
		for side in [-1, 1]:
			box(self, pos + Vector3(side * 0.65, 0.32, -0.65), Vector3(0.16, 0.12, 0.3), Color("52d7ec"), true)
	for pos in [Vector3(-14, 0, 4), Vector3(-12, 0, 5), Vector3(0, 0, -6), Vector3(3, 0, -6), Vector3(12, 0, 6)]:
		box(self, pos + Vector3(0, 0.5, 0), Vector3(1.8, 1, 1.1), Color("4d6066"))
		for rib in range(5):
			box(self, pos + Vector3(-0.72 + rib * 0.36, 0.55, 0), Vector3(0.08, 1.1, 1.17), Color("738186"))
	# Rear fortification, powered gate, generator stacks.
	for x in [-16, -10, -4, 2, 8, 14]:
		box(self, Vector3(x, 0.7, -8), Vector3(5.6, 1.4, 0.5), Color("445564"))
	var base = point(Vector2(1040, 250))
	box(self, base + Vector3(0.5, 1, 0), Vector3(2.8, 2, 3.4), Color("435c70"))
	box(self, base + Vector3(0.5, 2.15, 0), Vector3(3.2, 0.3, 3.8), Color("70899a"))
	box(self, base + Vector3(-0.94, 0.85, 0), Vector3(0.12, 1.7, 2.1), Color("35b9db"), true)
	for side in [-1, 1]:
		cylinder(self, base + Vector3(0.4, 2.7, side), 0.3, 1, Color("284859"))
		box(self, base + Vector3(0.4, 3.25, side), Vector3(0.45, 0.1, 0.45), Color("58e5ed"), true)

func sim_route() -> Array:
	return Simulation.ROUTE

func make_tower(data: Dictionary) -> Node3D:
	var model = Node3D.new()
	units.add_child(model)
	cylinder(model, Vector3(0, 0.4, 0), 0.58, 0.4, Color("263948"))
	var head = Node3D.new()
	head.name = "Head"
	model.add_child(head)
	var color: Color = sim.weapon(data).color
	box(head, Vector3(0, 0.9, 0), Vector3(0.85, 0.6, 0.8), color.darkened(0.45))
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
	var health = box(model, Vector3(0, 1.65, 0), Vector3(0.7, 0.06, 0.06), Color("b7e775"), true)
	health.name = "Health"
	return model

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(25, camera.size - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(48, camera.size + 2)
		elif event.button_index == MOUSE_BUTTON_LEFT and not sim.paused and sim.lives > 0:
			select_at_screen(event.position)

func select_at_screen(screen: Vector2) -> void:
	var plane = Plane(Vector3.UP, 0.25)
	var hit = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return
	for i in Simulation.PADS.size():
		if (hit as Vector3).distance_to(point(Simulation.PADS[i], 0.25)) < 0.95:
			sim.selected = -1
			for index in sim.towers.size():
				if sim.towers[index].pad == i:
					sim.selected = index
			if sim.selected == -1:
				sim.build_at(i)
			sim.refresh_ui()
			return

func _process(_delta: float) -> void:
	for child in units.get_children():
		child.set_meta("retained", false)
	for data in sim.towers:
		if not is_instance_valid(data.get("model")):
			data["model"] = make_tower(data)
		var model: Node3D = data.model
		model.set_meta("retained", true)
		model.position = point(Simulation.PADS[data.pad])
		model.get_node("Head").rotation.y = -float(data.get("aim", 0))
	for data in sim.enemies:
		if not is_instance_valid(data.get("model")):
			data["model"] = make_zombie(data)
		var model: Node3D = data.model
		model.set_meta("retained", true)
		model.position = point(data.pos)
		var target = point(Simulation.ROUTE[mini(data.segment, Simulation.ROUTE.size() - 1)])
		if model.position.distance_to(target) > 0.01:
			model.look_at(target)
		var size = minf(1.65, 0.75 + sim.wave * 0.045) * float(data.get("size", 1))
		model.scale = Vector3.ONE * size
		model.get_node("LegL").rotation.x = sin(sim.visual_time * 10 + data.pos.x) * 0.5
		model.get_node("LegR").rotation.x = -model.get_node("LegL").rotation.x
		model.get_node("Health").scale.x = maxf(0.01, data.hp / data.max_hp)
	for child in units.get_children():
		if not child.get_meta("retained"):
			child.queue_free()
	for child in effects.get_children():
		child.free()
	for shot in sim.shots:
		var a = point(shot.from, 1.0)
		var b = point(shot.to, 0.8)
		var beam = box(effects, (a + b) / 2, Vector3(0.035, 0.035, a.distance_to(b)), shot.get("color", Color.YELLOW), true)
		if a.distance_to(b) > 0.01:
			beam.look_at(b)
	for impact in sim.impacts:
		if impact.get("blast", false):
			var radius = maxf(0.05, (1 - impact.ttl / 0.5) * 2.2)
			cylinder(effects, point(impact.pos, 0.15), radius, 0.12, Color("d68835"))
	range_ring.visible = sim.selected >= 0
	if range_ring.visible:
		var data: Dictionary = sim.towers[sim.selected]
		range_ring.position = point(Simulation.PADS[data.pad], 0.29)
		var radius: float = sim.tower_range(data) / 32
		range_ring.scale = Vector3(radius, 0.12, radius)
	status.text = "3D / Mausrad: Zoom · Bauplatz anklicken" if not sim.paused and sim.lives > 0 else ("PAUSE / Weiter zum Fortsetzen" if sim.paused else "BASIS VERLOREN / Neuer Versuch")
