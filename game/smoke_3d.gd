extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world = load("res://game/world_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.sim.set_process(false)
	# Camera ray picking must hit every build pad in the default view.
	for index in world.sim.PADS.size():
		var screen: Vector2 = world.camera.unproject_position(world.point(world.sim.PADS[index], 0.25))
		assert(screen.x > 0 and screen.x < 1100 and screen.y > 82 and screen.y < 560, "Pad must be visible outside HUD")
		world.sim.cash = 1000
		world.select_at_screen(screen)
		assert(world.sim.towers.size() == index + 1, "Ray picking must build on the selected pad")
	world._process(0.01)
	assert(world.units.get_child_count() == 7)
	world.sim.sell_selected()
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 6, "Selling must remove the 3D model")
	world.sim.wave = 5
	world.sim.spawned = 0
	var boss = world.sim.create_enemy()
	world.sim.enemies.append(boss)
	world._process(0.01)
	assert(is_instance_valid(boss.model) and boss.model.scale.x > 1.5)
	world.sim.reset_run()
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 0, "Reset must clear all 3D units")
	# Fresh auto-wave actually creates a 3D zombie, then cleanup on death.
	world.sim.countdown = 0
	world.sim._process(0.1)
	world._process(0.1)
	assert(world.sim.active and world.sim.enemies.size() == 1)
	assert(is_instance_valid(world.sim.enemies[0].model))
	world.sim.enemies.clear()
	world._process(0.1)
	await process_frame
	assert(world.units.get_child_count() == 0)
	print("PASS: 3D startup, visible pads, camera ray picking, models, sale, boss scale, reset, auto-wave")
	quit(0)
