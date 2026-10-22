extends SceneTree

const Simulation = preload("res://game/simulation_3d.gd")

func _initialize() -> void:
	call_deferred("check_maps")

func check_maps() -> void:
	var sim = Simulation.new()
	sim.save_path = "user://test_maps_%d.json" % OS.get_process_id()
	root.add_child(sim)
	sim.set_process(false)
	var signatures = {}
	for seed_value in range(1, 101):
		sim.generate_map(seed_value)
		assert(sim.route == sim.route_for_seed(seed_value))
		assert(sim.route.size() == 12)
		for i in range(sim.route.size() - 1):
			var a: Vector2 = sim.route[i]
			var b: Vector2 = sim.route[i + 1]
			assert(a.x <= b.x and (is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y)))
			assert(a.distance_to(b) > 70)
			assert(not sim.placement_reason((a + b) / 2).is_empty())
		signatures[str(sim.route)] = true
		assert(sim.build_sites.is_empty())
	assert(signatures.size() == 100, "Seeds must produce different lanes")
	sim.cash = 10000
	var pos = Vector2(80.25, 80.75)
	assert(sim.place_at(pos))
	assert(sim.build_sites[sim.towers[0].pad] == pos, "No grid snapping")
	var money: int = sim.cash
	assert(not sim.place_at(pos + Vector2(20, 10)) and sim.cash == money)
	assert(not sim.place_at(Vector2(-10, 400)))
	sim.selected = 0
	sim.sell_selected()
	# Sell/build reuses storage; no hidden 16-slot limit or abandoned positions.
	for i in 150:
		sim.cash = 10000
		assert(sim.place_at(pos))
		sim.sell_selected()
	assert(sim.build_sites.size() == 1)
	sim.paused = true
	assert(not sim.place_at(pos))
	sim.queue_free()
	await process_frame
	print("PASS: 100 random connected lanes, deterministic seeds, road exclusion, continuous positions, collision checks, site reuse, pause")
	quit()
