extends Node2D

signal gameplay_event(kind: String)
signal enemy_defeated(position: Vector2, reward: int)

const ROUTE = [Vector2(-30, 220), Vector2(320, 220), Vector2(320, 450), Vector2(730, 450), Vector2(730, 250), Vector2(1130, 250)]
const PADS = [Vector2(140, 140), Vector2(220, 300), Vector2(410, 330), Vector2(520, 530), Vector2(640, 350), Vector2(820, 360), Vector2(930, 170)]
const MARINE = preload("res://art/marine_turret.svg")
const ZOMBIE = preload("res://art/zombie.svg")
const BASE = preload("res://art/base.svg")
const WEAPONS = [
	{"name": "Marine", "cost": 60, "damage": 13.0, "rate": 0.55, "range": 155.0, "color": Color("79d3f4")},
	{"name": "Mörser", "cost": 110, "damage": 32.0, "rate": 1.65, "range": 195.0, "color": Color("ffb55e")},
	{"name": "Kryo", "cost": 85, "damage": 5.0, "rate": 0.65, "range": 145.0, "color": Color("b29aff")}
]
var build_type = 0
var countdown = 12.0
var speed = 1.0
var spawned = 0
var kills = 0
var build_buttons: Array[Button] = []
var sell_button: Button
var speed_button: Button
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

func get_route() -> Array:
	return ROUTE

func get_pads() -> Array:
	return PADS

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
	help.position = Vector2(24, 602)
	help.text = "VERTEIDIGUNG / Klicke auf einen Bauplatz: Marine-Turm $60. Turm anklicken zum Aufrüsten.\nHalte die Stellung. Jeder durchgebrochene Zombie kostet ein Leben."
	ui.add_child(help)
	start = make_button(ui, "Welle starten", Vector2(24, 720), launch_wave)
	upgrade = make_button(ui, "Aufrüsten", Vector2(230, 720), upgrade_selected)
	pause_button = make_button(ui, "Pause", Vector2(440, 720), toggle_pause)
	make_button(ui, "Neuer Versuch", Vector2(620, 720), reset_run)
	for i in WEAPONS.size():
		build_buttons.append(make_button(ui, "", Vector2(24 + i * 206, 667), choose_weapon.bind(i)))
	sell_button = make_button(ui, "Verkaufen", Vector2(642, 667), sell_selected)
	speed_button = make_button(ui, "Tempo 1×", Vector2(824, 720), toggle_speed)
	refresh_ui()

func choose_weapon(kind: int) -> void:
	build_type = kind
	refresh_ui()

func toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	refresh_ui()

func weapon(tower: Dictionary) -> Dictionary:
	return WEAPONS[int(tower.get("kind", 0))]

func get_targets(_tower: Dictionary) -> Array:
	return enemies

func tower_range(tower: Dictionary) -> float:
	return weapon(tower).range + tower.level * 10

func upgrade_price(tower: Dictionary) -> int:
	return int(weapon(tower).cost * 0.75 * tower.level)

func build_at(pad: int) -> bool:
	if pad < 0 or pad >= get_pads().size() or paused or lives <= 0 or cash < WEAPONS[build_type].cost:
		return false
	for tower in towers:
		if tower.pad == pad:
			return false
	cash -= int(WEAPONS[build_type].cost)
	towers.append({"pad": pad, "kind": build_type, "level": 1, "cooldown": 0.0, "spent": int(WEAPONS[build_type].cost)})
	selected = towers.size() - 1
	gameplay_event.emit("build")
	refresh_ui()
	return true

func sell_selected() -> void:
	if selected < 0 or paused or lives <= 0:
		return
	cash += int(towers[selected].get("spent", weapon(towers[selected]).cost) * 0.7)
	towers.remove_at(selected)
	selected = -1
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
	spawned = 0
	remaining = 7 + wave * 3
	spawn_clock = 0
	active = true
	gameplay_event.emit("wave")
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
	countdown = 12.0
	speed = 1.0
	kills = 0
	active = false
	paused = false
	refresh_ui()
	queue_redraw()

func upgrade_selected() -> void:
	if selected < 0 or paused or lives <= 0:
		return
	var price = upgrade_price(towers[selected])
	if cash >= price:
		cash -= price
		towers[selected]["spent"] = int(towers[selected].get("spent", weapon(towers[selected]).cost)) + price
		towers[selected].level += 1
		gameplay_event.emit("build")
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not paused and lives > 0:
		for i in get_pads().size():
			if get_global_mouse_position().distance_to(get_pads()[i]) < 28:
				selected = -1
				for t in towers.size():
					if towers[t].pad == i:
						selected = t
				if selected == -1:
					build_at(i)
				refresh_ui()

func _process(delta: float) -> void:
	if paused or lives <= 0:
		return
	delta *= speed
	if not active:
		countdown -= delta
		if countdown <= 0:
			launch_wave()
	visual_time += delta
	for impact in impacts:
		impact.ttl -= delta
	impacts = impacts.filter(func(effect): return effect.ttl > 0)
	if active and remaining > 0:
		spawn_clock -= delta
		if spawn_clock <= 0:
			enemies.append(create_enemy())
			spawned += 1
			remaining -= 1
			spawn_clock = maxf(0.25, 0.85 - wave * 0.025)
	for e in enemies:
		var target: Vector2 = get_route()[e.segment]
		e["slow_time"] = maxf(0, float(e.get("slow_time", 0)) - delta)
		var movement = (48 + min(wave * 2, 60)) * float(e.get("pace", 1.0))
		if e.slow_time > 0:
			movement *= float(e.get("slow_factor", 0.5))
		e.pos = (e.pos as Vector2).move_toward(target, movement * delta)
		if (e.pos as Vector2).distance_to(target) < 0.1:
			e.segment += 1
			if e.segment >= get_route().size():
				e.hp = -1
				lives = maxi(0, lives - int(e.get("leak", 1)))
				gameplay_event.emit("alarm")
	for tower in towers:
		tower.cooldown -= delta
		if tower.cooldown > 0:
			continue
		var origin: Vector2 = get_pads()[tower.pad]
		for e in get_targets(tower):
			if e.hp > 0 and origin.distance_to(e.pos) <= tower_range(tower):
				var spec = weapon(tower)
				var kind = int(tower.get("kind", 0))
				gameplay_event.emit("mortar" if kind == 1 else ("cryo" if kind == 2 else "shot"))
				tower.cooldown = spec.rate / (1 + (tower.level - 1) * 0.08)
				tower["aim"] = (e.pos - origin).angle() + PI / 2
				shots.append({"from": origin, "to": e.pos, "ttl": 0.16, "color": spec.color})
				var hit_position: Vector2 = e.pos
				if kind == 1:
					impacts.append({"pos": hit_position, "ttl": 0.5, "kill": false, "blast": true})
					for victim in enemies:
						if victim.hp > 0 and (victim.pos as Vector2).distance_to(hit_position) < float(spec.get("splash", 70)):
							damage_enemy(victim, spec.damage * tower.level, true)
				else:
					damage_enemy(e, spec.damage * tower.level, false)
					if kind == 2:
						e["slow_time"] = float(spec.get("slow_duration", 2.5))
						e["slow_factor"] = float(spec.get("slow_factor", 0.5))
				break
	enemies = enemies.filter(func(e): return e.hp > 0)
	for shot in shots:
		shot.ttl -= delta
	shots = shots.filter(func(s): return s.ttl > 0)
	if active and remaining == 0 and enemies.is_empty() and lives > 0:
		active = false
		countdown = 8.0
		cash += 35 + wave * 5
		gameplay_event.emit("clear")
		if wave > best:
			best = wave
			var save = ConfigFile.new()
			save.set_value("scores", "best_wave", best)
			save.save("user://scores.cfg")
	refresh_ui()
	queue_redraw()

func create_enemy() -> Dictionary:
	var kind = "Zombie"
	var health = 25.0 * pow(1.19, wave - 1)
	var pace = 1.0
	var armor = 0.0
	var reward = 4
	var leak = 1
	var tint = Color.WHITE
	var size = 1.0
	if wave % 5 == 0 and spawned == 0:
		kind = "Titan"
		health *= 12
		pace = 0.6
		armor = 0.25
		reward = 70
		leak = 5
		tint = Color("eaa385")
		size = 2.0
	elif wave >= 3 and spawned % 5 == 2:
		kind = "Panzer"
		health *= 2.5
		pace = 0.72
		armor = 0.55
		reward = 10
		tint = Color("a3b9db")
		size = 1.3
	elif wave >= 2 and spawned % 3 == 1:
		kind = "Sprinter"
		health *= 0.65
		pace = 1.8
		reward = 6
		tint = Color("e6db8e")
	return {"pos": get_route()[0], "segment": 1, "hp": health, "max_hp": health, "kind": kind, "pace": pace, "armor": armor, "reward": reward, "leak": leak, "tint": tint, "size": size, "slow_time": 0.0}

func damage_enemy(enemy: Dictionary, amount: float, piercing: bool) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp -= amount * (1.0 if piercing else 1.0 - float(enemy.get("armor", 0)))
	impacts.append({"pos": enemy.pos, "ttl": 0.25, "kill": enemy.hp <= 0})
	if enemy.hp <= 0:
		cash += int(enemy.get("reward", 4))
		enemy_defeated.emit(enemy.pos, int(enemy.get("reward", 4)))
		kills += 1
		gameplay_event.emit("kill")

func refresh_ui() -> void:
	hud.text = "MARINE OUTPOST   |   $%d   |   Leben %d/30   |   Welle %d   |   Rekord %d" % [cash, lives, wave, best]
	start.disabled = active or lives <= 0 or paused
	start.text = "Basis verloren" if lives <= 0 else ("Welle läuft" if active else "Start in %ds / früher" % ceili(countdown))
	upgrade.disabled = selected < 0 or paused or lives <= 0
	if selected >= 0:
		var price = upgrade_price(towers[selected])
		upgrade.text = "Stufe %d → $%d" % [towers[selected].level, price]
		upgrade.disabled = upgrade.disabled or cash < price
	else:
		upgrade.text = "Turm auswählen"
	for i in build_buttons.size():
		build_buttons[i].text = ("▶ " if i == build_type else "") + "%s $%d" % [WEAPONS[i].name, WEAPONS[i].cost]
		build_buttons[i].modulate = Color.WHITE if cash >= WEAPONS[i].cost else Color("72818b")
	sell_button.disabled = selected < 0 or paused or lives <= 0
	sell_button.text = "Verkaufen" if selected < 0 else "Verkauf +$%d" % int(towers[selected].get("spent", weapon(towers[selected]).cost) * 0.7)
	speed_button.text = "Tempo %d×" % int(speed)
	var next = wave if active else wave + 1
	var intel = "TITAN: 5 Leben!" if next % 5 == 0 else ("Panzer + Sprinter" if next >= 3 else ("Sprinter" if next >= 2 else "Zombies"))
	help.text = "AUTO-WELLEN / Nächste Bedrohung: %s | Abschüsse: %d\nMarine: Einzelschaden · Mörser: Flächenschaden, ignoriert Panzerung · Kryo: verlangsamt\nTurm unten wählen → Bauplatz klicken. Verkauf: 70%% zurück. Pause stoppt auch den Countdown." % [intel, kills]
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
	for i in range(get_route().size() - 1):
		draw_line(get_route()[i], get_route()[i + 1], Color("070e16"), 64)
		draw_line(get_route()[i], get_route()[i + 1], Color("425158"), 56)
		draw_line(get_route()[i], get_route()[i + 1], Color("252f36"), 48)
		var distance = get_route()[i].distance_to(get_route()[i + 1])
		for step in range(0, int(distance), 32):
			var pos = get_route()[i].move_toward(get_route()[i + 1], step)
			draw_line(pos, pos + (get_route()[i + 1] - get_route()[i]).normalized() * 12, Color("64705c"), 2)
	# Cargo, service buildings, and warning beacons frame the combat lane.
	for pos in [Vector2(45, 410), Vector2(110, 460), Vector2(485, 125), Vector2(560, 145), Vector2(905, 490)]:
		draw_rect(Rect2(pos + Vector2(4, 7), Vector2(62, 43)), Color("080e15"))
		draw_rect(Rect2(pos, Vector2(62, 40)), Color("35444a"))
		draw_rect(Rect2(pos + Vector2(4, 4), Vector2(54, 32)), Color("26343d"), false, 2)
		for rib in range(10, 60, 12):
			draw_line(pos + Vector2(rib, 5), pos + Vector2(rib, 35), Color("4d5b60"), 3)
		draw_rect(Rect2(pos + Vector2(5, 16), Vector2(8, 6)), Color("d5a75d"))
	draw_texture_rect(BASE, Rect2(986, 177, 114, 145), false)
	for pad in get_pads():
		draw_rect(Rect2(pad - Vector2(29, 25), Vector2(58, 54)), Color("080f19"))
		draw_rect(Rect2(pad - Vector2(26, 26), Vector2(52, 48)), Color("354859"))
		draw_rect(Rect2(pad - Vector2(22, 22), Vector2(44, 40)), Color("1b2c3b"))
		draw_line(pad - Vector2(7, 2), pad + Vector2(7, -2), Color("6195a6"), 2)
		draw_line(pad - Vector2(0, 9), pad + Vector2(0, 5), Color("6195a6"), 2)
		for corner in [-1, 1]:
			draw_rect(Rect2(pad + Vector2(corner * 22 - 2, -23), Vector2(4, 6)), Color("e6b25c"))
	for i in towers.size():
		var tower = towers[i]
		var pos: Vector2 = get_pads()[tower.pad]
		if i == selected:
			draw_circle(pos, tower_range(tower), Color(0.2, 0.65, 0.85, 0.045))
			draw_arc(pos, tower_range(tower), 0, TAU, 96, Color(0.2, 0.65, 0.85, 0.35), 1)
			draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 54)), Color("68e3ff"), false, 2)
		draw_set_transform(pos, float(tower.get("aim", 0.0)))
		draw_texture_rect(MARINE, Rect2(-28, -28, 56, 56), false, weapon(tower).color)
		if int(tower.get("kind", 0)) == 1:
			draw_rect(Rect2(-8, -23, 16, 22), Color("d2aa78"))
			draw_circle(Vector2(0, -23), 6, Color("202a35"))
		elif int(tower.get("kind", 0)) == 2:
			draw_circle(Vector2(0, -20), 8, Color("ae9bff"))
			draw_circle(Vector2(0, -20), 4, Color("ecddff"))
		draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-15, 40), "%s %d" % [weapon(tower).name, tower.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a4d3e4"))
	for e in enemies:
		var scale_factor = minf(1.65, 0.75 + wave * 0.045) * float(e.get("size", 1.0))
		var facing = (get_route()[mini(e.segment, get_route().size() - 1)] - e.pos).angle() + PI / 2
		var sway = sin(visual_time * 11 + e.pos.x * 0.1) * 0.09
		draw_set_transform(e.pos, facing + sway, Vector2.ONE * scale_factor)
		draw_texture_rect(ZOMBIE, Rect2(-22, -22, 44, 44), false, e.get("tint", Color.WHITE))
		if float(e.get("slow_time", 0)) > 0:
			draw_arc(Vector2.ZERO, 24, 0, TAU, 16, Color("acb5ff"), 2)
		draw_set_transform(Vector2.ZERO)
		var bar: Vector2 = e.pos + Vector2(-16, -30 * scale_factor)
		draw_rect(Rect2(bar, Vector2(32, 4)), Color("431c25"))
		draw_rect(Rect2(bar, Vector2(32 * e.hp / e.max_hp, 4)), Color("a3c969"))
	for shot in shots:
		draw_line(shot.from, shot.to, Color(1, 0.65, 0.2, 0.16), 7)
		draw_line(shot.from, shot.to, shot.get("color", Color("ffe6a3")), 2)
		draw_circle(shot.from, 6, Color("fff1bb"))
	for impact in impacts:
		var life: float = minf(1.0, impact.ttl / 0.25)
		if impact.get("blast", false):
			draw_circle(impact.pos, (1.0 - impact.ttl / 0.5) * 70, Color(1, 0.5, 0.12, impact.ttl * 0.4))
		var tint = Color("8aaa54") if impact.kill else Color("ffba64")
		tint.a = life
		for ray in range(7):
			var direction = Vector2.from_angle(ray * TAU / 7)
			draw_line(impact.pos + direction * (1 - life) * 22, impact.pos + direction * ((1 - life) * 22 + 5), tint, 2)
	draw_rect(Rect2(0, 0, 1100, 82), Color("09121f"))
	draw_line(Vector2(0, 81), Vector2(1100, 81), Color("346079"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(24, 20), "KOLONIE 07 / PERIMETER-KOMMANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5c9bb4"))
	draw_rect(Rect2(0, 592, 1100, 188), Color("09121f"))
	draw_line(Vector2(0, 592), Vector2(1100, 592), Color("346079"), 2)
	if lives <= 0 or paused:
		draw_rect(Rect2(300, 265, 500, 95), Color(0.02, 0.05, 0.09, 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(340, 310), "BASIS VERLOREN" if lives <= 0 else "TAKTISCHE PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e5ba7d"))
		draw_string(ThemeDB.fallback_font, Vector2(340, 340), "Unten einen neuen Versuch starten." if lives <= 0 else "Mit Weiter geht es zurück ins Gefecht.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9cb7c5"))
