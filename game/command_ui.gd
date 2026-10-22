extends CanvasLayer

const CombatAssets = preload("res://game/asset_catalog.gd")

var world: Node3D
var sim: Node2D
var header: Label
var integrity: Label
var wave_stat: Label
var enemy_stat: Label
var upgrade_preview: Label
var inspector_portrait: TextureRect
var ability_progress: ColorRect
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
var build_view: Control
var inspector_view: Control
var placement_hint: Label
var branch_buttons: Array[Button] = []
var target_button: Button
var research_panel: Control
var research_info: Label
var research_buttons: Array[Button] = []
var save_button: Button
var load_button: Button
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
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func button_at(parent: Node, text: String, at: Vector2, size: Vector2, action: Callable) -> Button:
	var node = Button.new()
	node.position = at
	node.size = size
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_color_override("font_disabled_color", Color("718596"))
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
	game_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = panel(Vector2(20, 18), Vector2(1400, 80), game_panel)
	label_at(top, "MARINE OUTPOST", Vector2(20, 10), 23)
	label_at(top, "SEKTOR 07 / QUARANTÄNE", Vector2(21, 46), 11, Color("6ab9cf"))
	for entry in [[320, "KREDITS"], [530, "BASIS-INTEGRITÄT"], [770, "WELLE"], [970, "FEINDE"]]:
		label_at(top, entry[1], Vector2(entry[0], 9), 11, Color("8fa5b5"))
	header = label_at(top, "", Vector2(320, 26), 28, Color("f3cc7e"))
	integrity = label_at(top, "", Vector2(530, 26), 28)
	wave_stat = label_at(top, "", Vector2(770, 26), 28)
	enemy_stat = label_at(top, "", Vector2(970, 26), 28)
	button_at(top, "Menü / Esc", Vector2(1230, 18), Vector2(150, 42), open_menu)
	intel = label_at(game_panel, "", Vector2(34, 105), 12, Color("a0b4bd"))
	# One compact dock: commands above, construction OR selected tower below.
	var dock = panel(Vector2(20, 704), Vector2(1400, 178), game_panel)
	wave_button = button_at(dock, "", Vector2(16, 9), Vector2(350, 34), sim.launch_wave)
	wave_button.add_theme_font_size_override("font_size", 13)
	speed_button = button_at(dock, "", Vector2(376, 9), Vector2(100, 34), sim.toggle_speed)
	button_at(dock, "F / Kamera", Vector2(486, 9), Vector2(130, 34), world.center_camera)
	ability_button = button_at(dock, "", Vector2(626, 9), Vector2(300, 34), sim.activate_overdrive)
	ability_button.add_theme_font_size_override("font_size", 14)
	ability_button.tooltip_text = "8 Sekunden doppelte Feuerrate. Q aktiviert Overdrive."
	var track = ColorRect.new()
	track.position = Vector2(628, 44)
	track.size = Vector2(296, 3)
	track.color = Color("1e3b47")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(track)
	ability_progress = ColorRect.new()
	ability_progress.size = Vector2(296, 3)
	ability_progress.color = Color("65d4cd")
	ability_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(ability_progress)
	label_at(dock, "WASD bewegen · Mausrad zoomen · Rechtsklick abbrechen", Vector2(948, 17), 12, Color("8fabbc"))
	var line = ColorRect.new()
	line.position = Vector2(16, 52)
	line.size = Vector2(1368, 1)
	line.color = Color("294657")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(line)
	build_view = Control.new()
	build_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(build_view)
	var descriptions = ["1  SENTINEL     $60\nMarine · schnelles Einzelziel\n13 Schaden  /  5,2 m", "2  BULWARK     $110\nMörser · Flächenschaden\n32 Schaden  /  6,4 m", "3  PRISM     $85\nKryo · 50% Verlangsamung\n5 Schaden  /  4,8 m"]
	for i in 3:
		var button = button_at(build_view, descriptions[i], Vector2(16 + i * 308, 63), Vector2(294, 102), world.begin_build.bind(i))
		button.add_theme_font_size_override("font_size", 14)
		button.icon = load("res://art/portraits/%s.png" % ["marine", "mortar", "cryo"][i])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 76)
		button.tooltip_text = "Wählen, dann frei platzieren. Shift + Klick baut mehrere Türme."
		build_buttons.append(button)
	placement_hint = label_at(build_view, "", Vector2(960, 76), 15)
	inspector_view = Control.new()
	inspector_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(inspector_view)
	inspector_portrait = TextureRect.new()
	inspector_portrait.position = Vector2(16, 66)
	inspector_portrait.size = Vector2(80, 80)
	inspector_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspector_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspector_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_view.add_child(inspector_portrait)
	details = label_at(inspector_view, "", Vector2(110, 65), 16)
	details.size = Vector2(290, 96)
	upgrade_button = button_at(inspector_view, "", Vector2(415, 64), Vector2(250, 42), sim.upgrade_selected)
	upgrade_preview = label_at(inspector_view, "", Vector2(418, 113), 13, Color("81cbb8"))
	for choice in 2:
		var button = button_at(inspector_view, "", Vector2(690, 63 + choice * 52), Vector2(310, 44), specialize.bind(choice))
		branch_buttons.append(button)
	target_button = button_at(inspector_view, "", Vector2(1025, 64), Vector2(346, 42), sim.cycle_target)
	sell_button = button_at(inspector_view, "", Vector2(1025, 116), Vector2(206, 42), sell_tower)
	sell_button.add_theme_color_override("font_color", Color("e7af9a"))
	button_at(inspector_view, "Zurück / Esc", Vector2(1241, 116), Vector2(130, 42), deselect_tower)
	toast = label_at(game_panel, "", Vector2(34, 136), 17, Color("eac48b"))
	build_menu()
	build_research_panel()
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
	var card = panel(Vector2(100, 70), Vector2(1240, 760), menu)
	label_at(card, "KOLONIE 07  /  TAKTISCHES KOMMANDO", Vector2(44, 32), 14, Color("69bcd2"))
	menu_title = label_at(card, "MARINE\nOUTPOST", Vector2(40, 65), 66)
	label_at(card, "HALTE DIE LINIE.", Vector2(44, 244), 23, Color("e3b677"))
	menu_info = label_at(card, "", Vector2(44, 292), 17)
	resume_button = button_at(card, "Operation starten", Vector2(44, 426), Vector2(450, 56), resume_action)
	button_at(card, "Neuer Einsatz", Vector2(44, 496), Vector2(215, 44), request_new_run)
	button_at(card, "Spiel beenden", Vector2(274, 496), Vector2(220, 44), quit_game)
	label_at(card, "EINSATZBRIEFING", Vector2(624, 66), 19, Color("69bcd2"))
	label_at(card, "01  Turm wählen und frei neben der Straße bauen.\n02  Marine, Mörser und Kryo kombinieren.\n03  Wellen starten automatisch nach der Baupause.\n04  Jeder fünfte Angriff bringt einen Titan.\n05  Overdrive rettet dich bei Durchbrüchen.", Vector2(624, 110), 18)
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
	save_button = button_at(card, "Einsatz speichern", Vector2(44, 552), Vector2(215, 44), manual_save)
	load_button = button_at(card, "Spielstand laden", Vector2(274, 552), Vector2(220, 44), manual_load)
	button_at(card, "FORSCHUNG / permanente Verbesserungen", Vector2(44, 610), Vector2(450, 48), show_research)
	button_at(card, "Modellgalerie / 32 Assets", Vector2(624, 552), Vector2(450, 48), open_gallery)
	label_at(card, "ENTWICKLUNGSVERSION 0.9  /  SINGLEPLAYER\nOriginale Low-Poly-Grafik und synthetisierte Effekte.\nMultiplayer und Steam-Integration sind noch in Planung.", Vector2(44, 684), 14, Color("7f9aac"))

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
	save_button.disabled = sim.lives <= 0
	load_button.disabled = not FileAccess.file_exists(sim.save_path) and not FileAccess.file_exists(sim.save_path + ".bak")
	resume_button.text = ("Spielstand fortsetzen" if not sim.has_started and not load_button.disabled else ("Operation starten" if sim.wave == 0 else "Einsatz fortsetzen"))
	menu_title.text = "BASIS\nVERLOREN" if sim.lives <= 0 else "MARINE\nOUTPOST"
	menu_info.text = "30 Leben. Endlose Horden. Deine Verteidigung.\nFreier Turmbau · Zufällige Route · Titan-Angriffe\nLokaler Rekord: %d Wellen · Forschung: %d Punkte" % [sim.best, sim.research_points]
	if sim.lives <= 0:
		menu_info.text = "Welle %d erreicht · %d Abschüsse\nBaue deine nächste Verteidigung besser auf.\nLokaler Rekord: %d abgeschlossene Wellen" % [sim.wave, sim.kills, sim.best]

func close_menu() -> void:
	if sim.lives <= 0:
		return
	if not sim.has_started:
		sim.run_research = sim.research_levels.duplicate()
		sim.cash = 160 + int(sim.run_research[1]) * 25
		sim.has_started = true
	sim.paused = false
	menu.visible = false
	game_panel.visible = true

func new_run() -> void:
	world.building = false
	sim.reset_run()
	previous_wave = 0
	previous_lives = 30
	world.center_camera()
	close_menu()
	sim.save_run()

func on_event(kind: String) -> void:
	world.play_sound(kind)
	if kind == "save_error":
		show_toast("SPEICHERN FEHLGESCHLAGEN / Datenträger prüfen")
	elif kind == "alarm":
		show_toast("WARNUNG / Feinde durchgebrochen!")
	elif kind == "research":
		show_toast("FORSCHUNG GEWONNEN / %d Punkte verfügbar" % sim.research_points)
	elif kind == "wave":
		show_toast("TITAN IM ANMARSCH" if sim.wave % 5 == 0 else "ANGRIFFSWELLE %02d" % sim.wave)

func show_toast(message: String) -> void:
	toast.text = message
	toast_time = 3

func _process(delta: float) -> void:
	if sim.lives <= 0 and not menu.visible:
		open_menu()
	var showing_tower = sim.selected >= 0 and not world.building
	inspector_view.visible = showing_tower
	build_view.visible = not showing_tower
	if world.building:
		placement_hint.text = "LINKSKLICK: BAUEN\n" + ("Position frei · bereit zum Bauen" if world.cursor_valid else sim.placement_reason(world.cursor_position)) + "\nShift + Klick: mehrfach bauen"
		placement_hint.modulate = Color("84dec3") if world.cursor_valid else Color("edb0a1")
	else:
		placement_hint.text = "VERTEIDIGUNG BAUEN\n1 / 2 / 3 wählt einen Turm.\nTurm anklicken: Werte & Upgrades"
		placement_hint.modulate = Color("a6bcca")
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0
	header.text = "$ %s" % sim.cash
	integrity.text = "%02d / 30" % sim.lives
	integrity.modulate = Color("f0917d") if sim.lives <= 10 else Color.WHITE
	wave_stat.text = "%02d" % sim.wave
	enemy_stat.text = "%02d" % (sim.enemies.size() + sim.remaining)
	intel.text = "%d ABSCHÜSSE   /   %d FORSCHUNG   /   REKORD %d WELLEN" % [sim.kills, sim.research_points, sim.best]
	for i in build_buttons.size():
		var base: Dictionary = sim.WEAPONS[i]
		var role: String = ["Marine · schnelles Einzelziel", "Mörser · Flächenschaden", "Kryo · 50% Verlangsamung"][i]
		build_buttons[i].text = "%d  %s     $%d\n%s\n%d Schaden  /  %.1f m" % [i + 1, ["SENTINEL", "BULWARK", "PRISM"][i], base.cost, role, base.damage * (1 + int(sim.run_research[0]) * 0.05), (base.range + 10) / 32]
		build_buttons[i].modulate = Color("72d8ed") if world.building and sim.build_type == i else Color.WHITE
		# Unaffordable cards stay selectable: preview explains the missing credits.
		build_buttons[i].tooltip_text = "Frei platzieren · Shift + Klick: mehrfach bauen" if sim.cash >= sim.WEAPONS[i].cost else "Es fehlen $%d. Vorschau weiterhin möglich." % (sim.WEAPONS[i].cost - sim.cash)
		build_buttons[i].add_theme_color_override("font_color", Color("d7e6ee") if sim.cash >= sim.WEAPONS[i].cost else Color("a7a1a0"))
	upgrade_button.disabled = sim.selected < 0
	sell_button.disabled = sim.selected < 0
	if sim.selected >= 0:
		var tower: Dictionary = sim.towers[sim.selected]
		var spec: Dictionary = sim.weapon(tower)
		details.text = "%s / MK %d\nSchaden %d  ·  Reichweite %.1fm\nFeuerrate %.1f / s" % [spec.name, tower.level, spec.damage * tower.level, sim.tower_range(tower) / 32, (1 + (tower.level - 1) * 0.08) / spec.rate]
		inspector_portrait.texture = load(CombatAssets.portrait_path(CombatAssets.tower_index(int(tower.kind), int(tower.get("branch", -1)))))
		upgrade_button.text = "MK %d → %d  /  $%d" % [tower.level, tower.level + 1, sim.upgrade_price(tower)]
		upgrade_preview.text = "Schaden %d → %d  ·  +0,3 m\nFeuerrate %.2f → %.2f / s" % [spec.damage * tower.level, spec.damage * (tower.level + 1), (1 + (tower.level - 1) * 0.08) / spec.rate, (1 + tower.level * 0.08) / spec.rate]
		if sim.cash < sim.upgrade_price(tower):
			upgrade_preview.text = "Es fehlen $%d für MK %d.\nSchaden %d → %d" % [sim.upgrade_price(tower) - sim.cash, tower.level + 1, spec.damage * tower.level, spec.damage * (tower.level + 1)]
		upgrade_preview.modulate = Color("edb0a1") if sim.cash < sim.upgrade_price(tower) else Color.WHITE
		upgrade_button.disabled = sim.cash < sim.upgrade_price(tower)
		sell_button.text = "Verkaufen / +$%d" % int(tower.spent * 0.7)
	else:
		details.text = "BAUPLATZ WÄHLEN\nTurm anklicken für Details und Upgrades."
		upgrade_button.text = "Aufrüsten"
		sell_button.text = "Verkaufen"
	target_button.disabled = sim.selected < 0
	target_button.text = "Ziel: —" if sim.selected < 0 else "Ziel: " + ["Erster", "Stärkster", "Nächster"][int(sim.towers[sim.selected].get("target", 0))]
	for choice in branch_buttons.size():
		var button = branch_buttons[choice]
		button.disabled = true
		button.text = "Spezialisierung ab MK 3"
		if sim.selected >= 0:
			var tower: Dictionary = sim.towers[sim.selected]
			var branch = int(tower.get("branch", -1))
			var name: String = sim.BRANCHES[int(tower.kind)][choice]
			button.text = name + (" ✓" if branch == choice else (" / $%d" % sim.branch_price(tower) if branch == -1 else " —"))
			if tower.level < 3 and branch == -1:
				button.text = "Ab MK 3 / " + name
			button.add_theme_font_size_override("font_size", 15)
			button.disabled = tower.level < 3 or branch != -1 or sim.cash < sim.branch_price(tower)
			button.tooltip_text = [["Mehr Schaden und Reichweite; langsamere Schüsse.", "Schnelleres Feuer; weniger Schaden je Treffer."], ["Mehr Schaden pro Explosion; langsamere Schüsse.", "Größerer Explosionsradius; weniger Einzelschaden."], ["75% Verlangsamung für 3,5 Sekunden.", "Mehr Reichweite und schnellere Schüsse."]][int(tower.kind)][choice]
	if research_panel.visible:
		update_research()
	wave_button.disabled = sim.active
	wave_button.text = "WELLE %d / IM EINSATZ" % sim.wave if sim.active else "NÄCHSTE WELLE IN %ds  /  jetzt starten" % ceili(sim.countdown)
	speed_button.text = "TEMPO %d×" % sim.speed
	ability_progress.size.x = 296 * clampf(sim.overdrive / 8 if sim.overdrive > 0 else 1 - sim.overdrive_cooldown / (45.0 - int(sim.run_research[2]) * 3), 0, 1)
	ability_button.modulate = Color("74ead2") if sim.overdrive > 0 else Color.WHITE
	ability_button.disabled = sim.overdrive_cooldown > 0
	ability_button.text = "OVERDRIVE AKTIV" if sim.overdrive > 0 else ("OVERDRIVE / %ds" % ceili(sim.overdrive_cooldown) if sim.overdrive_cooldown > 0 else "OVERDRIVE [Q] / bereit")

func specialize(choice: int) -> void:
	if sim.specialize(choice):
		show_toast("SPEZIALISIERUNG INSTALLIERT")

func manual_save() -> void:
	sim.save_run()
	menu_info.text = sim.persistence_message
	load_button.disabled = not FileAccess.file_exists(sim.save_path)

func manual_load() -> void:
	if sim.load_run():
		world.center_camera()
		open_menu()
	menu_info.text = sim.persistence_message

func build_research_panel() -> void:
	research_panel = Control.new()
	add_child(research_panel)
	var cover = ColorRect.new()
	cover.color = Color(0.015, 0.03, 0.055, 0.98)
	cover.size = Vector2(1440, 900)
	research_panel.add_child(cover)
	var card = panel(Vector2(160, 110), Vector2(1120, 680), research_panel)
	label_at(card, "FORSCHUNG / KOLONIE-LABOR", Vector2(34, 30), 32, Color("7bcce4"))
	research_info = label_at(card, "", Vector2(34, 88), 18)
	var texts = ["BALLISTIK\n+5% Turmschaden je Stufe", "LOGISTIK\n+$25 Startkapital je Stufe", "ENERGIETECHNIK\n−3s Overdrive-Abklingzeit je Stufe"]
	for i in 3:
		var block = panel(Vector2(34 + i * 354, 190), Vector2(336, 260), card)
		label_at(block, texts[i], Vector2(18, 24), 16)
		var button = button_at(block, "", Vector2(18, 164), Vector2(300, 56), purchase_research.bind(i))
		research_buttons.append(button)
	label_at(card, "Pro abgeschlossener Welle: 1 Punkt. Titan-Wellen: 3 Punkte.\nJeder Bereich hat maximal 5 Stufen. Neue Forschung gilt erst im nächsten Einsatz.\nEin gespeicherter Run behält seine bisherigen Forschungsboni.", Vector2(34, 480), 17)
	button_at(card, "Zurück zum Kommando", Vector2(34, 582), Vector2(330, 48), hide_research)
	research_panel.visible = false

func show_research() -> void:
	research_panel.visible = true
	update_research()

func hide_research() -> void:
	research_panel.visible = false
	open_menu()

func update_research() -> void:
	research_info.text = "%d FORSCHUNGSPUNKTE verfügbar\nVerdiene Punkte im Endlosmodus und verbessere kommende Einsätze." % sim.research_points
	for i in research_buttons.size():
		var level = int(sim.research_levels[i])
		research_buttons[i].text = "MAXIMAL / Stufe 5" if level >= 5 else "Stufe %d → %d / %d Punkte" % [level, level + 1, sim.research_cost(i)]
		research_buttons[i].disabled = level >= 5 or sim.research_points < sim.research_cost(i)

func purchase_research(index: int) -> void:
	var success: bool = sim.buy_research(index)
	update_research()
	if not success:
		research_info.text = sim.persistence_message

func quit_game() -> void:
	if sim.has_started and sim.lives > 0 and sim.save_run() != OK:
		menu_info.text = "Speichern fehlgeschlagen. Bitte vor dem Beenden prüfen."
		return
	get_tree().quit()

func request_new_run() -> void:
	if (not sim.has_started and not FileAccess.file_exists(sim.save_path) and not FileAccess.file_exists(sim.save_path + ".bak")) or sim.lives <= 0:
		new_run()
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Neuen Einsatz beginnen?"
	dialog.dialog_text = "Der aktuelle Einsatz und sein Spielstand werden ersetzt.\nDeine Forschung und Rekorde bleiben erhalten."
	dialog.ok_button_text = "Neuen Einsatz starten"
	dialog.cancel_button_text = "Zurück"
	dialog.confirmed.connect(new_run)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 180))

func resume_action() -> void:
	if not sim.has_started and (FileAccess.file_exists(sim.save_path) or FileAccess.file_exists(sim.save_path + ".bak")):
		if not sim.load_run():
			menu_info.text = sim.persistence_message + "\nMit Neuer Einsatz kannst du neu beginnen."
			return
	close_menu()

func deselect_tower() -> void:
	sim.selected = -1
	world.building = false

func sell_tower() -> void:
	sim.sell_selected()
	world.building = false

func open_gallery() -> void:
	if sim.has_started and sim.lives > 0 and sim.save_run() != OK:
		menu_info.text = "Vor dem Galerie-Wechsel konnte nicht gespeichert werden."
		return
	get_tree().change_scene_to_file("res://game/model_gallery.tscn")

# Keep picking, ghosts and UI on the same usable battlefield bounds.
func blocks_world(screen: Vector2) -> bool:
	return menu.visible or research_panel.visible or screen.y < 104 or screen.y >= 704
