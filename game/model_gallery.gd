extends Node3D

const Assets = preload("res://game/asset_catalog.gd")
var camera: Camera3D
var display: Node3D
var title: Label
var detail: Label
var index_panel: Panel
var selection = 0
var all_models = false

func _ready() -> void:
	get_tree().auto_accept_quit = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101a26")
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4c657b")
	sky_material.sky_horizon_color = Color("b9b9b0")
	sky_material.ground_bottom_color = Color("101722")
	sky.sky_material = sky_material
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.environment.ambient_light_energy = 0.5
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	add_child(environment)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -25, 0)
	key.light_color = Color("ffe0b4")
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("80bcdc")
	fill.light_energy = 0.45
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	add_child(camera)
	display = Node3D.new()
	add_child(display)
	var ui = CanvasLayer.new()
	add_child(ui)
	title = Label.new()
	title.position = Vector2(30, 22)
	title.add_theme_font_size_override("font_size", 28)
	ui.add_child(title)
	detail = Label.new()
	detail.position = Vector2(30, 63)
	detail.add_theme_color_override("font_color", Color("88bdcc"))
	ui.add_child(detail)
	index_panel = Panel.new()
	index_panel.position = Vector2(20, 110)
	index_panel.size = Vector2(340, 710)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("0b1520")
	style.set_corner_radius_all(6)
	index_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(index_panel)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(324, 694)
	index_panel.add_child(scroll)
	var choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(choices)
	for i in Assets.IDS.size():
		var button = Button.new()
		button.custom_minimum_size = Vector2(302, 30)
		button.text = "%02d / %s" % [i + 1, Assets.NAMES[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(show_model.bind(i))
		choices.add_child(button)
	make_button(ui, "← Vorheriges", Vector2(385, 834), func(): show_model(posmod(selection - 1, Assets.IDS.size())))
	make_button(ui, "Nächstes →", Vector2(640, 834), func(): show_model(posmod(selection + 1, Assets.IDS.size())))
	make_button(ui, "Alle %d ansehen" % Assets.IDS.size(), Vector2(895, 834), show_all)
	make_button(ui, "Zurück zum Spiel", Vector2(1150, 834), func(): get_tree().change_scene_to_file("res://game/world_3d.tscn"))
	show_model(0)

func make_button(ui: CanvasLayer, text: String, pos: Vector2, action: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(240, 44)
	button.pressed.connect(action)
	ui.add_child(button)

func clear_display() -> void:
	for child in display.get_children():
		child.free()

func pedestal(at: Vector3, radius: float) -> void:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.03
	mesh.height = 0.12
	mesh.radial_segments = 48
	node.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("1d2c3a")
	material.roughness = 0.7
	node.material_override = material
	display.add_child(node)
	node.position = at - Vector3(0, 0.08, 0)

func show_model(index: int) -> void:
	index_panel.visible = true
	selection = index
	all_models = false
	clear_display()
	var model = Assets.create(index)
	display.add_child(model)
	model.position = Vector3(-1, 0, 0)
	pedestal(Vector3(-1, 0, 0), 2.3)
	camera.size = 7.2 if index >= 17 else 5.4
	camera.position = Vector3(4.8, 3.1, -5.5)
	camera.look_at(Vector3(0.15, 0.9, 0))
	title.text = "MODELLGALERIE / %02d  %s" % [index + 1, Assets.NAMES[index]]
	detail.text = "Originales GLB-Asset · PBR-Materialien · Mausrad: Zoom · Pfeiltasten: Modell wechseln"

func show_all() -> void:
	index_panel.visible = false
	all_models = true
	clear_display()
	for index in Assets.IDS.size():
		var model = Assets.create(index)
		display.add_child(model)
		model.rotation.y = PI
		model.position = Vector3((index % 8 - 3.5) * 4.3, 0, (index / 8 - 1.5) * 4.6)
		pedestal(model.position, 1.85)
		if index >= 17:
			model.scale *= 0.7
		var label = Label3D.new()
		label.text = "%02d / %s" % [index + 1, Assets.NAMES[index].split(" / ")[0]]
		label.position = model.position + Vector3(0, 0.1, 1.7)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = 0.008
		label.modulate = Color("b4ceda")
		display.add_child(label)
	camera.size = 42
	camera.position = Vector3(0, 26, 22)
	camera.look_at(Vector3(0, 0, 0))
	title.text = "MODELLGALERIE / %d ORIGINALE ASSETS" % Assets.IDS.size()
	detail.text = "9 Türme · 4 Gegner · 4 Wegarten · 15 Kolonieobjekte"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_RIGHT:
			show_model(posmod(selection + 1, Assets.IDS.size()))
		elif event.keycode == KEY_LEFT:
			show_model(posmod(selection - 1, Assets.IDS.size()))
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://game/world_3d.tscn")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(3, camera.size * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(35, camera.size * 1.1)
