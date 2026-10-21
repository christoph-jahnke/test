extends Node2D

const ROUTE = [Vector2(-30, 220), Vector2(320, 220), Vector2(320, 450), Vector2(730, 450), Vector2(730, 250), Vector2(1130, 250)]
const PADS = [Vector2(140, 140), Vector2(220, 300), Vector2(410, 330), Vector2(520, 530), Vector2(640, 350), Vector2(820, 360), Vector2(930, 170)]
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
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 22)
	ui.add_child(hud)
	help = Label.new()
	help.position = Vector2(24, 610)
	help.text = "Click a circular pad to build a marine turret ($60). Click a turret to select it.\nDefend the blue outpost. Each escaped zombie costs one life."
	ui.add_child(help)
	start = make_button(ui, "Launch wave", Vector2(24, 665), launch_wave)
	upgrade = make_button(ui, "Upgrade", Vector2(230, 665), upgrade_selected)
	pause_button = make_button(ui, "Pause", Vector2(440, 665), toggle_pause)
	make_button(ui, "New run", Vector2(620, 665), reset_run)
	refresh_ui()

func make_button(ui: CanvasLayer, title: String, at: Vector2, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.position = at
	button.size = Vector2(175, 38)
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
	hud.text = "MARINE OUTPOST   |   $%d   |   Lives %d/30   |   Wave %d   |   Best cleared %d" % [cash, lives, wave, best]
	start.disabled = active or lives <= 0 or paused
	start.text = "Game over" if lives <= 0 else ("Wave in progress" if active else "Launch wave %d" % (wave + 1))
	upgrade.disabled = selected < 0 or paused or lives <= 0
	if selected >= 0:
		var price = 45 * int(towers[selected].level)
		upgrade.text = "Upgrade L%d: $%d" % [towers[selected].level, price]
		upgrade.disabled = upgrade.disabled or cash < price
	else:
		upgrade.text = "Select a turret"
	pause_button.text = "Resume" if paused else "Pause"

func _draw() -> void:
	for x in range(0, 1100, 40):
		draw_line(Vector2(x, 85), Vector2(x, 580), Color(0.07, 0.11, 0.15))
	for y in range(100, 580, 40):
		draw_line(Vector2(0, y), Vector2(1100, y), Color(0.07, 0.11, 0.15))
	for i in range(ROUTE.size() - 1):
		draw_line(ROUTE[i], ROUTE[i + 1], Color(0.17, 0.20, 0.24), 48)
	draw_rect(Rect2(1040, 215, 55, 70), Color(0.15, 0.6, 0.95))
	for pad in PADS:
		draw_circle(pad, 26, Color(0.15, 0.23, 0.30))
		draw_arc(pad, 26, 0, TAU, 32, Color(0.30, 0.52, 0.65), 2)
	for i in towers.size():
		var tower = towers[i]
		var pos: Vector2 = PADS[tower.pad]
		if i == selected:
			draw_arc(pos, 155 + tower.level * 10, 0, TAU, 64, Color(0.2, 0.65, 0.85, 0.4), 1)
		draw_circle(pos, 16, Color(0.2, 0.7, 0.8))
		draw_line(pos, pos + Vector2(24, 0), Color(0.75, 0.9, 1), 7)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 5), str(tower.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	for e in enemies:
		var radius = minf(23, 9 + wave * 0.65)
		draw_circle(e.pos, radius, Color(0.45, 0.75, 0.22))
		draw_line(e.pos + Vector2(-radius, -radius - 5), e.pos + Vector2(radius, -radius - 5), Color(0.4, 0.1, 0.1), 3)
		draw_line(e.pos + Vector2(-radius, -radius - 5), e.pos + Vector2(-radius + radius * 2 * e.hp / e.max_hp, -radius - 5), Color.GREEN, 3)
	for shot in shots:
		draw_line(shot.from, shot.to, Color(1, 0.85, 0.35), 2)
