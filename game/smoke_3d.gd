extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world = load("res://game/world_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	assert(world.command_ui.menu.visible and world.sim.paused)
	world.command_ui.close_menu()
	assert(not world.sim.paused)
	world.sim.set_process(false)
	# Camera ray picking must hit every build pad in the default view.
	for index in world.sim.get_pads().size():
		var screen: Vector2 = world.camera.unproject_position(world.point(world.sim.get_pads()[index], 0.25))
		assert(screen.x > 0 and screen.x < 1440 and screen.y > 106 and screen.y < 658, "Pad must be visible outside HUD")
		world.sim.cash = 1000
		world.select_at_screen(screen)
		assert(world.sim.towers.size() == index + 1, "Ray picking must build on the selected pad")
	world._process(0.01)
	assert(world.units.get_child_count() == 16)
	world.sim.sell_selected()
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 15, "Selling must remove the 3D model")
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
	world.sim.reset_run()
	world.sim.build_at(0)
	world.sim.activate_overdrive()
	assert(world.sim.overdrive == 8 and world.sim.overdrive_cooldown == 45)
	world.sim._process(1)
	assert(world.sim.overdrive == 7 and world.sim.overdrive_cooldown == 44)
	world.sim.activate_overdrive()
	assert(world.sim.overdrive == 7, "Ability cannot bypass cooldown")
	world.command_ui.open_menu()
	world.sim._process(10)
	assert(world.sim.overdrive == 7, "Menu freezes ability timers")
	world.command_ui.close_menu()
	world.command_ui.new_run()
	assert(world.sim.overdrive_cooldown == 0 and world.sim.towers.is_empty())
	world.sim.lives = 0
	world.command_ui._process(0.1)
	assert(world.command_ui.menu.visible and world.command_ui.resume_button.disabled)
	world.command_ui.new_run()
	assert(not world.command_ui.menu.visible and world.sim.lives == 30)
	# Saved settings are readable, and rendering effects reuse their meshes.
	world.command_ui.master_volume = 0.4
	world.command_ui.shadows = false
	world.command_ui.apply_settings()
	world.command_ui.save_settings()
	var saved = ConfigFile.new()
	assert(saved.load("user://settings.cfg") == OK)
	assert(is_equal_approx(float(saved.get_value("audio", "volume")), 0.4))
	assert(not world.sun.shadow_enabled)
	world.sim.shots.append({"from": Vector2(80, 140), "to": Vector2(100, 210), "ttl": 0.1})
	world._process(0.01)
	var count_before = world.effects.get_child_count()
	world._process(0.01)
	assert(world.effects.get_child_count() == count_before)
	world.sim.shots.clear()
	world._process(0.01)
	assert(not world.beam_pool[0].visible)
	# The start screen must resume an existing slot instead of overwriting it.
	world.sim.save_path = "user://test_resume_%d.json" % OS.get_process_id()
	world.sim.cash = 321
	assert(world.sim.save_run() == OK)
	world.sim.has_started = false
	world.sim.cash = 160
	world.command_ui.open_menu()
	world.command_ui.resume_action()
	assert(world.sim.cash == 321 and not world.sim.paused)
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(world.sim.save_path + suffix):
			DirAccess.remove_absolute(world.sim.save_path + suffix)
	for player in world.sound_players:
		player.stop()
	await create_timer(0.15).timeout
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("PASS: 3D startup, visible pads, camera ray picking, models, sale, boss scale, reset, auto-wave, menu, ability cooldown, game-over flow, settings, effect pooling")
	quit(0)
