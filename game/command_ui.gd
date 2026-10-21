extends CanvasLayer

var world: Node3D
var sim: Node2D
var header: Label
var intel: Label
var details: Label
var toast: Label
var toast_time = 0.0
var previous_wave = 0
var previous_lives = 30
var build_buttons: Array[Button] = []
var upgrade_button: Button
var sell_button: Button
var wave_button: Button
var speed_button: Button
var ability_button: Button
var menu: Control
var menu_title: Label
var menu_info: Label
var resume_button: Button
var game_panel: Control
var settings = ConfigFile.new()
var master_volume = 0.65
var shadows = true

func panel(at: Vector2, size: Vector2, parent: Node) -> Panel:
	var node = Panel.new()
	node.position = at
	node.size = size
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085, 0.96)
	style.border_color = Color("294657")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node

func label_at(parent: Node, text: String, at: Vector2, font_size: int, color: Color = Color("d7e6ee")) -> Label:
	var node = Label.new()
	node.position = at
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func button_at(parent: Node, text: String, at: Vector2, size: Vector2, action: Callable) -> Button:
	var node = Button.new()
	node.position = at
	node.size = size
	node.text = text
	node.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("142c3b") if state == "normal" else (Color("254c5d") if state == "hover" else Color("0b1d29"))
		style.border_color = Color("466579") if state != "hover" else Color("71d8ee")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		node.add_theme_stylebox_override(state, style)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _ready() -> void:
	layer = 5
	sim = world.sim
	settings.load("user://settings.cfg")
	master_volume = clampf(float(settings.get_value("audio", "volume", 0.65)), 0, 1)
	shadows = bool(settings.get_value("video", "shadows", true))
	apply_settings()
	game_panel = Control.new()
	add_child(game_panel)
	var top = panel(Vector2(18, 16), Vector2(1404, 90), game_panel)
	label_at(top, "MARINE / OUTPOST", Vector2(20, 10), 25)
	label_at(top, "SEKTOR 07     /     ENDLOS-OPERATION", Vector2(21, 46), 12, Color("6ab9cf"))
	header = label_at(top, "", Vector2(430, 15), 22)
	intel = label_at(top, "", Vector2(430, 49), 14, Color("e8b972"))
	button_at(top, "ESC / Menü", Vector2(1240, 23), Vector2(140, 42), open_menu)
	var bottom = panel(Vector2(18, 688), Vector2(1404, 194), game_panel)
	label_at(bottom, "VERTEIDIGUNGSNETZ", Vector2(18, 10), 13, Color("6ab9cf"))
	var descriptions = ["MARINE / $60\nPräzision · Salven", "MÖRSER / $110\nFläche · gegen Panzer", "KRYO / $85\nVerlangsamt um 50%"]
	for i in 3:
		var button = button_at(bottom, descriptions[i], Vector2(18 + i * 200, 38), Vector2(188, 76), sim.choose_weapon.bind(i))
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = "Turm wählen, dann eine beleuchtete Plattform anklicken."
		build_buttons.append(button)
	details = label_at(bottom, "", Vector2(636, 14), 16)
	upgrade_button = button_at(bottom, "Aufrüsten", Vector2(636, 78), Vector2(220, 36), sim.upgrade_selected)
	sell_button = button_at(bottom, "Verkaufen", Vector2(870, 78), Vector2(200, 36), sim.sell_selected)
	ability_button = button_at(bottom, "", Vector2(1090, 38), Vector2(294, 76), sim.activate_overdrive)
	ability_button.tooltip_text = "8 Sekunden doppelte Feuerrate. 45 Sekunden Abklingzeit."
	wave_button = button_at(bottom, "", Vector2(18, 135), Vector2(300, 38), sim.launch_wave)
	speed_button = button_at(bottom, "", Vector2(330, 135), Vector2(148, 38), sim.toggle_speed)
	button_at(bottom, "Kamera zentrieren [F]", Vector2(490, 135), Vector2(240, 38), world.center_camera)
	label_at(bottom, "WASD: Kamera  ·  Mausrad: Zoom  ·  1/2/3: Turm  ·  Leertaste: Pause", Vector2(752, 144), 13, Color("9bb5c6"))
	toast = label_at(game_panel, "", Vector2(38, 126), 22, Color("eac48b"))
	build_menu()
	sim.gameplay_event.connect(on_event)
	open_menu()

func build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var cover = ColorRect.new()
	cover.color = Color(0.015, 0.03, 0.055, 0.8)
	cover.size = Vector2(1440, 900)
	menu.add_child(cover)
	var card = panel(Vector2(100, 95), Vector2(1240, 710), menu)
	label_at(card, "KOLONIE 07  /  TAKTISCHES KOMMANDO", Vector2(44, 32), 14, Color("69bcd2"))
	menu_title = label_at(card, "MARINE\nOUTPOST", Vector2(40, 65), 66)
	label_at(card, "HALTE DIE LINIE.", Vector2(44, 244), 23, Color("e3b677"))
	menu_info = label_at(card, "", Vector2(44, 292), 17)
	resume_button = button_at(card, "Operation starten", Vector2(44, 426), Vector2(450, 56), close_menu)
	button_at(card, "Neuer Einsatz", Vector2(44, 496), Vector2(215, 44), new_run)
	button_at(card, "Spiel beenden", Vector2(274, 496), Vector2(220, 44), func(): get_tree().quit())
	label_at(card, "EINSATZBRIEFING", Vector2(624, 66), 19, Color("69bcd2"))
	label_at(card, "01  Turm auswählen, dann Plattform anklicken.\n02  Marine, Mörser und Kryo kombinieren.\n03  Wellen starten automatisch nach der Baupause.\n04  Jeder fünfte Angriff bringt einen Titan.\n05  Overdrive rettet dich bei Durchbrüchen.", Vector2(624, 110), 18)
	label_at(card, "EINSTELLUNGEN", Vector2(624, 320), 19, Color("69bcd2"))
	label_at(card, "Lautstärke", Vector2(624, 366), 16)
	var volume = HSlider.new()
	volume.position = Vector2(770, 371)
	volume.size = Vector2(330, 24)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.01
	volume.value = master_volume
	volume.value_changed.connect(func(value): master_volume = value; apply_settings(); save_settings())
	card.add_child(volume)
	var shadow_toggle = CheckButton.new()
	shadow_toggle.text = "Schatten aktivieren"
	shadow_toggle.position = Vector2(624, 414)
	shadow_toggle.button_pressed = shadows
	shadow_toggle.toggled.connect(func(value): shadows = value; apply_settings(); save_settings())
	card.add_child(shadow_toggle)
	var fullscreen = CheckButton.new()
	fullscreen.text = "Vollbild [F11]"
	fullscreen.position = Vector2(624, 462)
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	card.add_child(fullscreen)
	label_at(card, "ENTWICKLUNGSVERSION 0.4  /  SINGLEPLAYER\nOriginale Low-Poly-Grafik und synthetisierte Effekte.\nMultiplayer und Steam-Integration sind noch in Planung.", Vector2(44, 610), 14, Color("7f9aac"))

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	world.sun.shadow_enabled = shadows

func save_settings() -> void:
	settings.set_value("audio", "volume", master_volume)
	settings.set_value("video", "shadows", shadows)
	settings.save("user://settings.cfg")

func open_menu() -> void:
	sim.paused = true
	menu.visible = true
	game_panel.visible = false
	resume_button.disabled = sim.lives <= 0
	resume_button.text = "Operation starten" if sim.wave == 0 else "Einsatz fortsetzen"
	menu_title.text = "BASIS\nVERLOREN" if sim.lives <= 0 else "MARINE\nOUTPOST"
	menu_info.text = "30 Leben. Endlose Horden. Deine Verteidigung.\n16 Bauplätze · 3 Waffensysteme · Titan-Angriffe\nLokaler Rekord: %d abgeschlossene Wellen" % sim.best
	if sim.lives <= 0:
		menu_info.text = "Welle %d erreicht · %d Abschüsse\nBaue deine nächste Verteidigung besser auf.\nLokaler Rekord: %d abgeschlossene Wellen" % [sim.wave, sim.kills, sim.best]

func close_menu() -> void:
	if sim.lives <= 0:
		return
	sim.paused = false
	menu.visible = false
	game_panel.visible = true

func new_run() -> void:
	sim.reset_run()
	previous_wave = 0
	previous_lives = 30
	world.center_camera()
	close_menu()

func on_event(kind: String) -> void:
	world.play_sound(kind)
	if kind == "build":
		show_toast("VERTEIDIGUNG AKTUALISIERT")
	elif kind == "alarm":
		show_toast("WARNUNG / Feinde durchgebrochen!")
	elif kind == "wave":
		show_toast("TITAN IM ANMARSCH" if sim.wave % 5 == 0 else "ANGRIFFSWELLE %02d" % sim.wave)

func show_toast(message: String) -> void:
	toast.text = message
	toast_time = 3

func _process(delta: float) -> void:
	if sim.lives <= 0 and not menu.visible:
		open_menu()
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0
	header.text = "KREDITS  %04d     INTEGRITÄT  %02d / 30     WELLE  %02d" % [sim.cash, sim.lives, sim.wave]
	intel.text = "FEINDKONTAKTE: %d  ·  ABSCHÜSSE: %d  ·  REKORD: %d" % [sim.enemies.size() + sim.remaining, sim.kills, sim.best]
	for i in build_buttons.size():
		build_buttons[i].modulate = Color("72d8ed") if sim.build_type == i else Color.WHITE
		build_buttons[i].disabled = sim.cash < sim.WEAPONS[i].cost
	upgrade_button.disabled = sim.selected < 0
	sell_button.disabled = sim.selected < 0
	if sim.selected >= 0:
		var tower: Dictionary = sim.towers[sim.selected]
		var spec: Dictionary = sim.weapon(tower)
		details.text = "%s / MK %d\nSchaden %d  ·  Reichweite %.1fm" % [spec.name, tower.level, spec.damage * tower.level, sim.tower_range(tower) / 32]
		upgrade_button.text = "Aufrüsten / $%d" % sim.upgrade_price(tower)
		upgrade_button.disabled = sim.cash < sim.upgrade_price(tower)
		sell_button.text = "Verkaufen / +$%d" % int(tower.spent * 0.7)
	else:
		details.text = "BAUPLATZ WÄHLEN\nTurm anklicken für Details und Upgrades."
		upgrade_button.text = "Aufrüsten"
		sell_button.text = "Verkaufen"
	wave_button.disabled = sim.active
	wave_button.text = "WELLE %d / IM EINSATZ" % sim.wave if sim.active else "NÄCHSTE WELLE IN %ds / jetzt starten" % ceili(sim.countdown)
	speed_button.text = "TEMPO %d×" % sim.speed
	ability_button.disabled = sim.overdrive_cooldown > 0
	ability_button.text = "OVERDRIVE AKTIV" if sim.overdrive > 0 else ("OVERDRIVE / %ds" % ceili(sim.overdrive_cooldown) if sim.overdrive_cooldown > 0 else "OVERDRIVE [Q]\n8s doppelte Feuerrate")
