extends "res://game/main.gd"

signal map_changed
var map_seed = 0
var route: Array = []
var build_sites: Array = []
var overdrive = 0.0
var overdrive_cooldown = 0.0

func get_route() -> Array:
	return route

func get_pads() -> Array:
	return build_sites

func route_for_seed(seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array = []
	var z = rng.randf_range(150, 250)
	result.append(Vector2(-110, z))
	for column in 5:
		var x = 150.0 + column * 270.0 + rng.randf_range(-35, 35)
		result.append(Vector2(x, z))
		z = rng.randf_range(500, 650) if column % 2 == 0 else rng.randf_range(150, 280)
		result.append(Vector2(x, z))
	result.append(Vector2(1500, z))
	return result

func generate_map(seed_value: int) -> void:
	map_seed = seed_value
	route = route_for_seed(seed_value)
	build_sites.clear()
	map_changed.emit()

func road_distance(pos: Vector2, path: Array = []) -> float:
	var points = route if path.is_empty() else path
	var distance = INF
	for i in range(points.size() - 1):
		distance = minf(distance, pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, points[i], points[i + 1])))
	return distance

func placement_reason(pos: Vector2) -> String:
	if pos.x < 25 or pos.x > 1345 or pos.y < 65 or pos.y > 735:
		return "Außerhalb des Baugebiets"
	if road_distance(pos) < 56:
		return "Abstand zur Straße halten"
	for tower in towers:
		if pos.distance_to(build_sites[tower.pad]) < 56:
			return "Zu nah an einem anderen Turm"
	if towers.size() >= 80:
		return "Maximal 80 Türme"
	if cash < WEAPONS[build_type].cost:
		return "Nicht genügend Credits"
	return ""

func place_at(pos: Vector2) -> bool:
	if paused or lives <= 0 or not placement_reason(pos).is_empty():
		return false
	var occupied = []
	for tower in towers:
		occupied.append(int(tower.pad))
	var index = build_sites.size()
	for i in build_sites.size():
		if i not in occupied:
			index = i
			break
	if index == build_sites.size():
		build_sites.append(pos)
	else:
		build_sites[index] = pos
	return super.build_at(index)

func build_at(_pad: int) -> bool:
	# The 3D game accepts world positions, never predefined build pads.
	return false

func activate_overdrive() -> void:
	if paused or lives <= 0 or overdrive_cooldown > 0:
		return
	overdrive = 8.0
	overdrive_cooldown = 45.0 - int(run_research[2]) * 3
	gameplay_event.emit("cryo")

func reset_run() -> void:
	generate_map(randi_range(1, 2000000000))
	super.reset_run()
	run_research = research_levels.duplicate()
	has_started = true
	run_id = "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	cash = 160 + int(run_research[1]) * 25
	autosave_clock = 20
	for path in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	overdrive = 0
	overdrive_cooldown = 0

func _process(delta: float) -> void:
	if not paused and lives > 0:
		overdrive = maxf(0, overdrive - delta * speed)
		overdrive_cooldown = maxf(0, overdrive_cooldown - delta * speed)
		if overdrive > 0:
			for tower in towers:
				tower.cooldown -= delta * speed
	var was_alive = lives > 0
	super._process(delta)
	if not paused and lives > 0:
		autosave_clock -= delta
		if autosave_clock <= 0:
			autosave_clock = 20.0
			if save_run() != OK:
				gameplay_event.emit("save_error")
	if was_alive and lives <= 0:
		# A defeated run must not be resumable from an autosave.
		for path in [save_path, save_path + ".bak"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)

func _draw() -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass

const Store = preload("res://game/save_store.gd")
const RESEARCH_NAMES = ["Ballistik", "Logistik", "Energietechnik"]
const BRANCHES = [
	["Scharfschütze", "Sturmgeschütz"],
	["Belagerung", "Streubomben"],
	["Tiefkälte", "Feldkontrolle"]
]
var has_started = false
var research_points = 0
var research_levels = [0, 0, 0]
var run_research = [0, 0, 0]
var run_id = ""
var awards: Dictionary = {}
var persistence_message = ""
var autosave_clock = 20.0
var save_path = "user://run_v2.json"
var profile_path = "user://research_v1.json"

func _ready() -> void:
	generate_map(randi_range(1, 2000000000))
	super._ready()
	load_profile()
	run_research = research_levels.duplicate()
	run_id = "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	cash = 160 + int(run_research[1]) * 25
	gameplay_event.connect(handle_progress)

func load_profile() -> void:
	for path in [profile_path, profile_path + ".bak"]:
		var data = Store.read_json(path)
		if data.get("version") != 1 or not data.get("levels") is Array or data.levels.size() != 3:
			continue
		var valid = number_valid(data.get("points"), 0, 1000000) and data.get("awards", {}) is Dictionary
		for level in data.levels:
			valid = valid and number_valid(level, 0, 5) and int(level) == level
		if valid:
			for key in data.get("awards", {}):
				var value = data.awards[key]
				if not key is String or not number_valid(value, 0, 10000) or int(value) != value:
					valid = false
		if not valid:
			continue
		research_points = int(data.points)
		research_levels = data.levels.map(func(value): return int(value))
		awards = data.get("awards", {}).duplicate()
		return

func save_profile() -> Error:
	return Store.write_json(profile_path, {"version": 1, "points": research_points, "levels": research_levels, "awards": awards})

func research_cost(index: int) -> int:
	return 3 + int(research_levels[index]) * 3

func buy_research(index: int) -> bool:
	if not paused or index < 0 or index > 2 or research_levels[index] >= 5 or research_points < research_cost(index):
		return false
	var cost = research_cost(index)
	research_points -= cost
	research_levels[index] += 1
	if save_profile() != OK:
		research_levels[index] -= 1
		research_points += cost
		persistence_message = "Forschung konnte nicht gespeichert werden."
		return false
	gameplay_event.emit("build")
	return true

func handle_progress(kind: String) -> void:
	if kind == "clear":
		var already = int(awards.get(run_id, 0))
		if wave > already:
			var earned = 1 + (2 if wave % 5 == 0 else 0)
			research_points += earned
			awards[run_id] = wave
			if save_profile() != OK:
				research_points -= earned
				awards[run_id] = already
				persistence_message = "Forschung nicht gespeichert: Datenträger prüfen."
			else:
				gameplay_event.emit("research")
		if save_run() != OK:
			persistence_message = "Autosave fehlgeschlagen. Bitte manuell speichern."

func weapon(tower: Dictionary) -> Dictionary:
	var spec: Dictionary = super.weapon(tower).duplicate()
	spec.damage *= 1.0 + float(run_research[0]) * 0.05
	var branch = int(tower.get("branch", -1))
	var kind = int(tower.get("kind", 0))
	if branch == 0:
		if kind == 0:
			spec.color = Color("f6d387")
			spec.damage *= 2.2
			spec.rate *= 1.5
			spec.range += 80
		elif kind == 1:
			spec.damage *= 1.8
			spec.rate *= 1.25
		else:
			spec["slow_factor"] = 0.25
			spec["slow_duration"] = 3.5
	elif branch == 1:
		if kind == 0:
			spec.color = Color("f59c7a")
			spec.rate *= 0.55
			spec.damage *= 0.85
		elif kind == 1:
			spec["splash"] = 115.0
			spec.damage *= 0.85
		else:
			spec.range += 85
			spec.rate *= 0.55
	if branch >= 0:
		spec.name = BRANCHES[kind][branch]
	return spec

func branch_price(tower: Dictionary) -> int:
	return int(WEAPONS[int(tower.get("kind", 0))].cost * 2)

func specialize(choice: int) -> bool:
	if paused or lives <= 0 or selected < 0 or choice < 0 or choice > 1:
		return false
	var tower: Dictionary = towers[selected]
	var price = branch_price(tower)
	if tower.level < 3 or tower.get("branch", -1) != -1 or cash < price:
		return false
	cash -= price
	tower["spent"] = int(tower.spent) + price
	tower["branch"] = choice
	gameplay_event.emit("build")
	return true

func cycle_target() -> void:
	if selected >= 0 and not paused:
		towers[selected]["target"] = (int(towers[selected].get("target", 0)) + 1) % 3

func get_targets(tower: Dictionary) -> Array:
	var result = enemies.duplicate()
	var mode = int(tower.get("target", 0))
	var origin: Vector2 = get_pads()[tower.pad]
	if mode == 1:
		result.sort_custom(func(a, b): return a.hp > b.hp)
	elif mode == 2:
		result.sort_custom(func(a, b): return origin.distance_squared_to(a.pos) < origin.distance_squared_to(b.pos))
	if mode == 0:
		result.sort_custom(func(a, b):
			if a.segment != b.segment:
				return a.segment > b.segment
			return (a.pos as Vector2).distance_squared_to(get_route()[a.segment]) < (b.pos as Vector2).distance_squared_to(get_route()[b.segment]))
	return result

func number_valid(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

func pack_state() -> Dictionary:
	var tower_data = []
	for tower in towers:
		var clean: Dictionary = tower.duplicate()
		clean.erase("model")
		tower_data.append(clean)
	var enemy_data = []
	for enemy in enemies:
		var clean: Dictionary = enemy.duplicate()
		clean.erase("model")
		clean.pos = [enemy.pos.x, enemy.pos.y]
		var color: Color = enemy.get("tint", Color.WHITE)
		clean.tint = color.to_html()
		enemy_data.append(clean)
	return {"version": 2, "map": "colony_free", "map_seed": map_seed, "sites": build_sites.map(func(pos): return [pos.x, pos.y]), "run_id": run_id, "research": run_research, "cash": cash, "lives": lives, "wave": wave, "kills": kills, "remaining": remaining, "spawned": spawned, "spawn_clock": spawn_clock, "countdown": countdown, "speed": speed, "active": active, "build_type": build_type, "overdrive": overdrive, "overdrive_cooldown": overdrive_cooldown, "towers": tower_data, "enemies": enemy_data}

func save_run() -> Error:
	if lives <= 0:
		return ERR_UNAVAILABLE
	has_started = true
	var error = Store.write_json(save_path, pack_state())
	persistence_message = "Einsatz gespeichert." if error == OK else "Speichern fehlgeschlagen."
	return error

func validate_state(data: Dictionary) -> bool:
	if data.get("version") != 2 or data.get("map") != "colony_free" or not data.get("run_id") is String or (data.run_id.is_empty() or data.run_id.length() > 120):
		return false
	if not number_valid(data.get("map_seed"), 1, 2000000000) or int(data.map_seed) != data.map_seed:
		return false
	if not data.get("sites") is Array or data.sites.size() > 80:
		return false
	var saved_route = route_for_seed(int(data.map_seed))
	for pos in data.sites:
		if not pos is Array or pos.size() != 2 or not number_valid(pos[0], 25, 1345) or not number_valid(pos[1], 65, 735):
			return false
	var bounds = {"cash": [0, 1e12], "lives": [1, 30], "wave": [0, 10000], "kills": [0, 1e12], "remaining": [0, 100000], "spawned": [0, 100000], "spawn_clock": [-100, 10], "countdown": [-100, 30], "speed": [1, 2], "build_type": [0, 2], "overdrive": [0, 8], "overdrive_cooldown": [0, 45]}
	for key in bounds:
		if not number_valid(data.get(key), bounds[key][0], bounds[key][1]):
			return false
	for key in ["cash", "lives", "wave", "kills", "remaining", "spawned", "build_type"]:
		if int(data[key]) != data[key]:
			return false
	if float(data.speed) != 1.0 and float(data.speed) != 2.0:
		return false
	if not data.get("active") is bool or not data.get("research") is Array or data.research.size() != 3:
		return false
	for level in data.research:
		if not number_valid(level, 0, 5) or int(level) != level:
			return false
	if not data.get("towers") is Array or data.towers.size() > 80 or not data.get("enemies") is Array or data.enemies.size() > 1000:
		return false
	var occupied = []
	for tower in data.towers:
		if not tower is Dictionary:
			return false
		for key in ["pad", "level", "kind", "spent", "cooldown"]:
			if not tower.has(key):
				return false
		var limits = {"pad": [0, 79], "level": [1, 10000], "kind": [0, 2], "spent": [0, 1e12], "cooldown": [-100, 10], "branch": [-1, 1], "target": [0, 2], "aim": [-10, 10]}
		for key in limits:
			var value = tower.get(key, -1 if key == "branch" else 0)
			if not number_valid(value, limits[key][0], limits[key][1]):
				return false
		for key in ["pad", "level", "kind", "branch", "target"]:
			var value = tower.get(key, -1 if key == "branch" else 0)
			if int(value) != value:
				return false
		if tower.get("pad", -1) in occupied:
			return false
		if int(tower.pad) >= data.sites.size():
			return false
		var saved_position = Vector2(data.sites[int(tower.pad)][0], data.sites[int(tower.pad)][1])
		if road_distance(saved_position, saved_route) < 56:
			return false
		for other in occupied:
			var other_pos = Vector2(data.sites[int(other)][0], data.sites[int(other)][1])
			if saved_position.distance_to(other_pos) < 56:
				return false
		occupied.append(tower.pad)
	for enemy in data.enemies:
		if not enemy is Dictionary or not enemy.get("pos") is Array or enemy.pos.size() != 2:
			return false
		if not number_valid(enemy.pos[0], -200, 1600) or not number_valid(enemy.pos[1], 0, 900):
			return false
		var limits = {"segment": [1, saved_route.size() - 1], "hp": [0.000001, 1e100], "max_hp": [0.000001, 1e100], "pace": [0.1, 5], "armor": [0, 0.99], "reward": [0, 10000], "leak": [1, 30], "size": [0.1, 5], "slow_time": [0, 10], "slow_factor": [0.1, 1]}
		for key in limits:
			if not number_valid(enemy.get(key, 0.5 if key == "slow_factor" else null), limits[key][0], limits[key][1]):
				return false
		if int(enemy.segment) != enemy.segment or enemy.hp > enemy.max_hp:
			return false
		if not enemy.get("kind") is String or not enemy.get("tint") is String or not Color.html_is_valid(enemy.tint):
			return false
	return true

func restore_state(data: Dictionary) -> bool:
	if not validate_state(data):
		return false
	# Prepare everything before replacing the running state.
	var new_towers: Array[Dictionary] = []
	var new_enemies: Array[Dictionary] = []
	for tower in data.towers:
		var clean: Dictionary = tower.duplicate()
		clean.erase("model")
		clean.pad = int(clean.pad)
		clean.kind = int(clean.kind)
		clean.level = int(clean.level)
		new_towers.append(clean)
	for enemy in data.enemies:
		var clean: Dictionary = enemy.duplicate()
		clean.erase("model")
		clean.pos = Vector2(clean.pos[0], clean.pos[1])
		clean.tint = Color(clean.tint)
		clean.segment = int(clean.segment)
		new_enemies.append(clean)
	map_seed = int(data.map_seed)
	route = route_for_seed(map_seed)
	build_sites = data.sites.map(func(pos): return Vector2(pos[0], pos[1]))
	map_changed.emit()
	towers = new_towers
	enemies = new_enemies
	has_started = true
	run_id = data.run_id
	run_research = data.research.map(func(value): return int(value))
	cash = int(data.cash)
	lives = int(data.lives)
	wave = int(data.wave)
	kills = int(data.kills)
	remaining = int(data.remaining)
	spawned = int(data.spawned)
	spawn_clock = float(data.spawn_clock)
	countdown = float(data.countdown)
	speed = float(data.speed)
	active = data.active
	build_type = int(data.build_type)
	overdrive = float(data.overdrive)
	overdrive_cooldown = float(data.overdrive_cooldown)
	shots.clear()
	impacts.clear()
	selected = -1
	paused = true
	refresh_ui()
	return true

func load_run() -> bool:
	for path in [save_path, save_path + ".bak"]:
		if restore_state(Store.read_json(path)):
			persistence_message = "Einsatz geladen." + (" Sicherung wiederhergestellt." if path.ends_with(".bak") else "")
			return true
	persistence_message = "Kein gültiger Spielstand vorhanden."
	return false
