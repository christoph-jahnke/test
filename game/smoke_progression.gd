extends SceneTree

const Simulation = preload("res://game/simulation_3d.gd")
const Store = preload("res://game/save_store.gd")

func _initialize() -> void:
	call_deferred("check_progression")

func check_progression() -> void:
	var sim = Simulation.new()
	sim.save_path = "user://test_run_%d.json" % OS.get_process_id()
	sim.profile_path = "user://test_profile_%d.json" % OS.get_process_id()
	root.add_child(sim)
	sim.set_process(false)
	sim.research_points = 9
	sim.paused = true
	assert(sim.buy_research(0))
	assert(sim.research_points == 6 and sim.research_levels[0] == 1)
	assert(sim.run_research[0] == 0, "Research applies only to a new run")
	assert(sim.buy_research(1))
	sim.reset_run()
	assert(sim.cash == 185 and sim.run_research[0] == 1)
	var regular = {"kind": 0, "level": 1, "pad": 0}
	assert(is_equal_approx(float(sim.weapon(regular).damage), 13 * 1.05))
	# Both choices for each tower alter combat parameters, charge once, and lock.
	for kind in 3:
		for choice in 2:
			sim.towers.clear()
			sim.cash = 1000
			sim.build_type = kind
			assert(sim.place_at(Vector2(80, 80)))
			assert(not sim.specialize(choice), "Requires MK 3")
			sim.towers[0].level = 3
			var price: int = sim.branch_price(sim.towers[0])
			var before: int = sim.cash
			assert(sim.specialize(choice))
			assert(sim.cash == before - price)
			assert(not sim.specialize(1 - choice), "Branch choice is permanent")
			var spec: Dictionary = sim.weapon(sim.towers[0])
			if kind == 0:
				assert(spec.range > 155 if choice == 0 else spec.rate < 0.55)
			elif kind == 1:
				assert(spec.damage > 32 if choice == 0 else spec.splash == 115)
			else:
				assert(spec.slow_factor == 0.25 if choice == 0 else spec.range > 145)
	# Targeting chooses furthest progress, greatest HP, or nearest distance.
	var a = {"pos": Vector2(200, 210), "segment": 1, "hp": 100}
	var b = {"pos": Vector2(230, 250), "segment": 2, "hp": 50}
	var c = {"pos": Vector2(80, 150), "segment": 1, "hp": 20}
	sim.enemies.assign([a, b, c])
	for mode in 3:
		sim.towers[0]["target"] = mode
		assert(sim.get_targets(sim.towers[0])[0] == [b, a, c][mode])
	# Save and reload a live wave with upgraded towers and slowed enemies.
	sim.wave = 7
	sim.remaining = 12
	sim.spawned = 18
	sim.active = true
	sim.cash = 567
	sim.enemies.clear()
	var enemy = sim.create_enemy()
	enemy.pos = Vector2(220, 300)
	enemy.segment = 2
	enemy.slow_time = 1.5
	enemy["slow_factor"] = 0.25
	sim.enemies.append(enemy)
	assert(sim.save_run() == OK)
	sim.cash = 999
	assert(sim.save_run() == OK)
	# A corrupt primary file falls back to the previous complete snapshot.
	var file = FileAccess.open(sim.save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	sim.cash = 0
	sim.enemies.clear()
	assert(sim.load_run())
	assert(sim.cash == 567 and sim.paused and sim.active and sim.remaining == 12)
	assert(sim.enemies[0].pos == Vector2(220, 300) and sim.enemies[0].slow_factor == 0.25)
	assert(sim.towers[0].branch == 1 and sim.run_research[1] == 1)
	assert(sim.persistence_message.contains("Sicherung"))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(sim.pack_state()))
	assert(sim.validate_state(snapshot))
	var invalid = snapshot.duplicate(true)
	invalid.towers[0].pad = 0.5
	assert(not sim.restore_state(invalid) and sim.cash == 567)
	invalid = snapshot.duplicate(true)
	invalid.towers[0].erase("pad")
	assert(not sim.restore_state(invalid))
	invalid = snapshot.duplicate(true)
	invalid.enemies[0].segment = 999
	assert(not sim.restore_state(invalid))
	invalid = snapshot.duplicate(true)
	invalid.version = 999
	assert(not sim.restore_state(invalid))
	# Replaying a saved wave never awards its research twice.
	sim.run_id = "research-replay-test"
	sim.wave = 1
	var points_before: int = sim.research_points
	sim.handle_progress("clear")
	assert(sim.research_points == points_before + 1)
	sim.handle_progress("clear")
	assert(sim.research_points == points_before + 1)
	sim.wave = 5
	sim.handle_progress("clear")
	assert(sim.research_points == points_before + 4)
	var profile = Store.read_json(sim.profile_path)
	assert(profile.points == sim.research_points and profile.awards[sim.run_id] == 5)
	var restored = Simulation.new()
	restored.save_path = sim.save_path
	restored.profile_path = sim.profile_path
	root.add_child(restored)
	restored.set_process(false)
	assert(restored.research_points == sim.research_points)
	assert(restored.research_levels == sim.research_levels)
	assert(restored.load_run() and restored.run_id == sim.run_id and restored.route == sim.route and restored.build_sites == sim.build_sites)
	restored.queue_free()
	await process_frame
	# Autosave and defeat invalidation use the same state rules as manual save.
	sim.paused = false
	sim.autosave_clock = 0
	sim._process(0.01)
	assert(FileAccess.file_exists(sim.save_path))
	sim.lives = 1
	sim.enemies.clear()
	var escaping = sim.create_enemy()
	escaping.pos = sim.get_route()[-1]
	escaping.segment = sim.get_route().size() - 1
	sim.enemies.append(escaping)
	sim._process(0.01)
	assert(sim.lives == 0 and not FileAccess.file_exists(sim.save_path))
	assert(not FileAccess.file_exists(sim.save_path + ".bak"))
	for path in [sim.save_path, sim.profile_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	sim.queue_free()
	await process_frame
	print("PASS: research, six branches, targeting, active-wave save/load, backup recovery, invalid-save rejection, replay protection, autosave, defeat cleanup")
	quit(0)
