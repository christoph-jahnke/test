extends Node2D

const ROUTE = [Vector2(-30, 220), Vector2(320, 220), Vector2(320, 450), Vector2(730, 450), Vector2(730, 250), Vector2(1130, 250)]
const PADS = [Vector2(140, 140), Vector2(220, 300), Vector2(410, 330), Vector2(520, 530), Vector2(640, 350), Vector2(820, 360), Vector2(930, 170)]
const MARINE = preload("res://art/marine_turret.svg")
const ZOMBIE = preload("res://art/zombie.svg")
const BASE = preload("res://art/base.svg")
var visual_time = 0.0
var impacts: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var cash = 160
var lives = 30
var wave = 0
var best = 0
var selected = -1
var remaining = 0
var spawn_clock = 0.0
var active = false
var hud: Label
var help: Label
var start: Button
var upgrade: Button
var pause_button: Button
var paused = false

func _ready() -> void:
	var save = ConfigFile.new()
	if save.load("user://scores.cfg") == OK:
		best = int(save.get_value("scores", "best_wave", 0))
	var ui = CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(24, 34)
	hud.add_theme_font_size_override("font_size", 20)
	ui.add_child(hud)
	help = Label.new()
	help.position = Vector2(24, 610)
	help.text = "VERTEIDIGUNG / Klicke auf einen Bauplatz: Marine-Turm $60. Turm anklicken zum Aufrüsten.\nHalte die Stellung. Jeder durchgebrochene Zombie kostet ein Leben."
	ui.add_child(help)
	start = make_button(ui, "Welle starten", Vector2(24, 665), launch_wave)
	upgrade = make_button(ui, "Aufrüsten", Vector2(230, 665), upgrade_selected)
	pause_button = make_button(ui, "Pause", Vector2(440, 665), toggle_pause)
	make_button(ui, "Neuer Versuch", Vector2(620, 665), reset_run)
	refresh_ui()

func make_button(ui: CanvasLayer, title: String, at: Vector2, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.position = at
	button.size = Vector2(175, 38)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("183345")
	style.border_color = Color("3d7b91")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color("285568")
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	ui.add_child(button)
	return button

func launch_wave() -> void:
	if active or lives <= 0 or paused:
		return
	wave += 1
	remaining = 7 + wave * 3
	spawn_clock = 0
	active = true
	refresh_ui()

func toggle_pause() -> void:
	paused = not paused
	refresh_ui()

func reset_run() -> void:
	towers.clear()
	enemies.clear()
	shots.clear()
	impacts.clear()
	cash = 160
	lives = 30
	wave = 0
	selected = -1
	remaining = 0
	active = false
	paused = false
	refresh_ui()
	queue_redraw()

func upgrade_selected() -> void:
	if selected < 0 or paused or lives <= 0:
		return
	var price = 45 * int(towers[selected].level)
	if cash >= price:
		cash -= price
		towers[selected].level += 1
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not paused and lives > 0:
		for i in PADS.size():
			if get_global_mouse_position().distance_to(PADS[i]) < 28:
				selected = -1
				for t in towers.size():
					if towers[t].pad == i:
						selected = t
				if selected == -1 and cash >= 60:
					cash -= 60
					towers.append({"pad": i, "level": 1, "cooldown": 0.0})
					selected = towers.size() - 1
				refresh_ui()

func _process(delta: float) -> void:
	if paused or lives <= 0:
		return
	visual_time += delta
	for impact in impacts:
		impact.ttl -= delta
	impacts = impacts.filter(func(effect): return effect.ttl > 0)
	if active and remaining > 0:
		spawn_clock -= delta
		if spawn_clock <= 0:
			var health = 25.0 * pow(1.22, wave - 1)
			enemies.append({"pos": ROUTE[0], "segment": 1, "hp": health, "max_hp": health})
			remaining -= 1
			spawn_clock = maxf(0.25, 0.85 - wave * 0.025)
	for e in enemies:
		var target: Vector2 = ROUTE[e.segment]
		e.pos = (e.pos as Vector2).move_toward(target, (48 + min(wave * 2, 60)) * delta)
		if (e.pos as Vector2).distance_to(target) < 0.1:
			e.segment += 1
			if e.segment >= ROUTE.size():
				e.hp = -1
				lives = maxi(0, lives - 1)
	for tower in towers:
		tower.cooldown -= delta
		if tower.cooldown > 0:
			continue
		var origin: Vector2 = PADS[tower.pad]
		for e in enemies:
			if e.hp > 0 and origin.distance_to(e.pos) <= 155 + tower.level * 10:
				e.hp -= 13 * tower.level
				tower.cooldown = 0.55
				tower["aim"] = (e.pos - origin).angle() + PI / 2
				impacts.append({"pos": e.pos, "ttl": 0.25, "kill": e.hp <= 0})
				shots.append({"from": origin, "to": e.pos, "ttl": 0.10})
				if e.hp <= 0:
					cash += 4
				break
	enemies = enemies.filter(func(e): return e.hp > 0)
	for shot in shots:
		shot.ttl -= delta
	shots = shots.filter(func(s): return s.ttl > 0)
	if active and remaining == 0 and enemies.is_empty() and lives > 0:
		active = false
		cash += 35 + wave * 5
		if wave > best:
			best = wave
			var save = ConfigFile.new()
			save.set_value("scores", "best_wave", best)
			save.save("user://scores.cfg")
	refresh_ui()
	queue_redraw()

func refresh_ui() -> void:
	hud.text = "MARINE OUTPOST   |   $%d   |   Leben %d/30   |   Welle %d   |   Rekord %d" % [cash, lives, wave, best]
	start.disabled = active or lives <= 0 or paused
	start.text = "Basis verloren" if lives <= 0 else ("Welle läuft" if active else "Welle %d starten" % (wave + 1))
	upgrade.disabled = selected < 0 or paused or lives <= 0
	if selected >= 0:
		var price = 45 * int(towers[selected].level)
		upgrade.text = "Stufe %d → $%d" % [towers[selected].level, price]
		upgrade.disabled = upgrade.disabled or cash < price
	else:
		upgrade.text = "Turm auswählen"
	pause_button.text = "Weiter" if paused else "Pause"
	queue_redraw()

func _draw() -> void:
	# Authored vector sprites over a deterministic colony floor.
	draw_rect(Rect2(0, 80, 1100, 510), Color("101c27"))
	for x in range(0, 1100, 48):
		for y in range(90, 590, 48):
			var shade = 0.075 + float((x * 7 + y * 13) % 5) * 0.004
			draw_rect(Rect2(x + 1, y + 1, 46, 46), Color(shade, shade + 0.025, shade + 0.04))
			draw_circle(Vector2(x + 5, y + 5), 1, Color("344451"))
	for i in range(ROUTE.size() - 1):
		draw_line(ROUTE[i], ROUTE[i + 1], Color("070e16"), 64)
		draw_line(ROUTE[i], ROUTE[i + 1], Color("425158"), 56)
		draw_line(ROUTE[i], ROUTE[i + 1], Color("252f36"), 48)
		var distance = ROUTE[i].distance_to(ROUTE[i + 1])
		for step in range(0, int(distance), 32):
			var pos = ROUTE[i].move_toward(ROUTE[i + 1], step)
			draw_line(pos, pos + (ROUTE[i + 1] - ROUTE[i]).normalized() * 12, Color("64705c"), 2)
	# Cargo, service buildings, and warning beacons frame the combat lane.
	for pos in [Vector2(45, 410), Vector2(110, 460), Vector2(485, 125), Vector2(560, 145), Vector2(905, 490)]:
		draw_rect(Rect2(pos + Vector2(4, 7), Vector2(62, 43)), Color("080e15"))
		draw_rect(Rect2(pos, Vector2(62, 40)), Color("35444a"))
		draw_rect(Rect2(pos + Vector2(4, 4), Vector2(54, 32)), Color("26343d"), false, 2)
		for rib in range(10, 60, 12):
			draw_line(pos + Vector2(rib, 5), pos + Vector2(rib, 35), Color("4d5b60"), 3)
		draw_rect(Rect2(pos + Vector2(5, 16), Vector2(8, 6)), Color("d5a75d"))
	draw_texture_rect(BASE, Rect2(986, 177, 114, 145), false)
	for pad in PADS:
		draw_rect(Rect2(pad - Vector2(29, 25), Vector2(58, 54)), Color("080f19"))
		draw_rect(Rect2(pad - Vector2(26, 26), Vector2(52, 48)), Color("354859"))
		draw_rect(Rect2(pad - Vector2(22, 22), Vector2(44, 40)), Color("1b2c3b"))
		draw_line(pad - Vector2(7, 2), pad + Vector2(7, -2), Color("6195a6"), 2)
		draw_line(pad - Vector2(0, 9), pad + Vector2(0, 5), Color("6195a6"), 2)
		for corner in [-1, 1]:
			draw_rect(Rect2(pad + Vector2(corner * 22 - 2, -23), Vector2(4, 6)), Color("e6b25c"))
	for i in towers.size():
		var tower = towers[i]
		var pos: Vector2 = PADS[tower.pad]
		if i == selected:
			draw_circle(pos, 155 + tower.level * 10, Color(0.2, 0.65, 0.85, 0.045))
			draw_arc(pos, 155 + tower.level * 10, 0, TAU, 96, Color(0.2, 0.65, 0.85, 0.35), 1)
			draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 54)), Color("68e3ff"), false, 2)
		draw_set_transform(pos, float(tower.get("aim", 0.0)))
		draw_texture_rect(MARINE, Rect2(-28, -28, 56, 56), false)
		draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-15, 40), "MK %d" % tower.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a4d3e4"))
	for e in enemies:
		var scale_factor = minf(1.65, 0.75 + wave * 0.045)
		var facing = (ROUTE[mini(e.segment, ROUTE.size() - 1)] - e.pos).angle() + PI / 2
		var sway = sin(visual_time * 11 + e.pos.x * 0.1) * 0.09
		draw_set_transform(e.pos, facing + sway, Vector2.ONE * scale_factor)
		draw_texture_rect(ZOMBIE, Rect2(-22, -22, 44, 44), false)
		draw_set_transform(Vector2.ZERO)
		var bar: Vector2 = e.pos + Vector2(-16, -30 * scale_factor)
		draw_rect(Rect2(bar, Vector2(32, 4)), Color("431c25"))
		draw_rect(Rect2(bar, Vector2(32 * e.hp / e.max_hp, 4)), Color("a3c969"))
	for shot in shots:
		draw_line(shot.from, shot.to, Color(1, 0.65, 0.2, 0.16), 7)
		draw_line(shot.from, shot.to, Color("ffe6a3"), 2)
		draw_circle(shot.from, 6, Color("fff1bb"))
	for impact in impacts:
		var life: float = impact.ttl / 0.25
		var tint = Color("8aaa54") if impact.kill else Color("ffba64")
		tint.a = life
		for ray in range(7):
			var direction = Vector2.from_angle(ray * TAU / 7)
			draw_line(impact.pos + direction * (1 - life) * 22, impact.pos + direction * ((1 - life) * 22 + 5), tint, 2)
	draw_rect(Rect2(0, 0, 1100, 82), Color("09121f"))
	draw_line(Vector2(0, 81), Vector2(1100, 81), Color("346079"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(24, 20), "KOLONIE 07 / PERIMETER-KOMMANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5c9bb4"))
	draw_rect(Rect2(0, 592, 1100, 128), Color("09121f"))
	draw_line(Vector2(0, 592), Vector2(1100, 592), Color("346079"), 2)
	if lives <= 0 or paused:
		draw_rect(Rect2(300, 265, 500, 95), Color(0.02, 0.05, 0.09, 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(340, 310), "BASIS VERLOREN" if lives <= 0 else "TAKTISCHE PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e5ba7d"))
		draw_string(ThemeDB.fallback_font, Vector2(340, 340), "Unten einen neuen Versuch starten." if lives <= 0 else "Mit Weiter geht es zurück ins Gefecht.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9cb7c5"))
