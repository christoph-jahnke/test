extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world = load("res://game/world_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.sim.set_process(false)
	assert(world.command_ui.menu.visible and world.sim.paused)
	world.command_ui.close_menu()
	for seed_value in range(1, 51):
		for route_point in world.sim.route_for_seed(seed_value):
			var projected: Vector2 = world.camera.unproject_position(world.point(route_point, 0.8))
			assert(projected.x > 0 and projected.x < 1440 and projected.y > 104 and projected.y < 704, "Default camera must keep random lanes outside HUD")
	world.sim.cash = 10000
	# Free points are picked with the actual camera projection, not pad indices.
	var placements: Array[Vector2] = []
	for x in range(80, 1300, 100):
		for y in range(90, 700, 100):
			var pos = Vector2(x + 7, y + 3)
			if world.sim.placement_reason(pos).is_empty():
				placements.append(pos)
				world.begin_build(0)
				world.select_at_screen(world.camera.unproject_position(world.point(pos, 0.15)), placements.size() == 1)
				if placements.size() == 1:
					assert(world.building and world.sim.selected == -1, "Shift keeps construction active")
				assert(world.sim.towers.size() == placements.size())
				if placements.size() == 6:
					break
		if placements.size() == 6:
			break
	assert(world.sim.towers.size() == 6)
	world.begin_build(1)
	var before_hud: int = world.sim.cash
	world.select_at_screen(Vector2(1100, 760), true)
	assert(world.sim.towers.size() == 6 and world.sim.cash == before_hud, "HUD clicks cannot place or select towers")
	world.building = false
	world._process(0.01)
	assert(world.units.get_child_count() == 6)
	# Specialization must change actual imported geometry, including the gun rotor.
	world.sim.selected = 0
	world.sim.towers[0].level = 3
	assert(world.sim.specialize(1))
	world.sim.towers[0].cooldown = 1
	world._process(0.01)
	await process_frame
	assert(world.sim.towers[0].model.get_meta("asset_id") == "05_assault_reaper")
	assert(world.sim.towers[0].model.find_child("Rotor", true, false) != null)
	# Clicking a body switches to its inspector; deselection restores the shop.
	world.sim.selected = -1
	world.select_at_screen(world.camera.unproject_position(world.point(placements[0], 0.8)))
	assert(world.sim.selected == 0 and not world.building)
	world.command_ui._process(0.01)
	assert(world.command_ui.inspector_view.visible and not world.command_ui.build_view.visible)
	assert(world.command_ui.upgrade_preview.text.contains("→"))
	assert(world.command_ui.ability_progress.size.y == 3, "Cooldown stays a thin strip")
	assert(world.command_ui.inspector_portrait.texture.resource_path.ends_with("05_assault_reaper.png"))
	world.sim.cash = 0
	world.command_ui._process(0.01)
	assert(world.command_ui.upgrade_button.disabled and world.command_ui.upgrade_preview.text.contains("Es fehlen"))
	world.sim.cash = 10000
	world.sim.towers[0].model.set_meta("last_cooldown", 0.0)
	world.sim.towers[0].cooldown = 0.5
	world._process(0.01)
	assert(world.sim.towers[0].model.find_child("MuzzleFX", true, false).visible, "Shot starts muzzle flash")
	var barrel = world.sim.towers[0].model.find_child("MuzzleFX", true, false)
	assert(world.tower_at_screen(world.camera.unproject_position(barrel.global_position)) == 0, "Rendered barrels stay selectable")
	world._process(0.2)
	assert(not world.sim.towers[0].model.find_child("MuzzleFX", true, false).visible, "Muzzle flash expires")
	world.command_ui.deselect_tower()
	world.command_ui._process(0.01)
	assert(world.command_ui.build_view.visible and not world.command_ui.inspector_view.visible)
	# Killing pays exactly once and creates a rising coin, frozen while paused.
	var enemy = world.sim.create_enemy()
	enemy.pos = world.sim.get_route()[1]
	var money_before: int = world.sim.cash
	world.sim.damage_enemy(enemy, 1000000, true)
	assert(world.sim.cash == money_before + enemy.reward)
	assert(world.floating_credits.size() == 1)
	world.sim.damage_enemy(enemy, 1000000, true)
	assert(world.floating_credits.size() == 1)
	var coin = world.floating_credits[0].node
	var initial_height: float = coin.position.y
	world._process(0.3)
	assert(coin.position.y > initial_height)
	world.sim.paused = true
	var age: float = world.floating_credits[0].age
	world._process(0.3)
	assert(world.floating_credits[0].age == age)
	world.sim.paused = false
	world._process(2)
	await process_frame
	assert(world.floating_credits.is_empty())
	# Damage feedback, frost state and the animated anatomical rig are actual scene nodes.
	var wounded = world.sim.create_enemy()
	wounded.pos = world.sim.get_route()[1]
	world.sim.enemies.append(wounded)
	world._process(0.01)
	wounded.hp -= 1
	wounded.slow_time = 2.0
	world._process(0.01)
	assert(wounded.model.get_meta("hit_time") > 0 and wounded.model.get_node("Frost").visible)
	assert(wounded.model.find_child("ShinL", true, false) != null)
	assert(wounded.model.get_node("Health/Fill").scale.x < 1.0)
	var health = wounded.model.get_node("Health")
	var towards_camera = (world.camera.global_position - health.global_position).normalized()
	assert((health.get_node("Fill").global_position - health.global_position).dot(towards_camera) > 0, "Health fill must be in front of its backing")
	world.sim.paused = true
	var hit_age: float = wounded.model.get_meta("hit_time")
	world._process(0.5)
	assert(wounded.model.get_meta("hit_time") == hit_age)
	world.sim.paused = false
	world._process(0.2)
	assert(wounded.model.get_meta("hit_time") == 0.0)
	world.sim.enemies.clear()
	world._process(0.01)
	await process_frame
	# Free positions and the seed survive a full save/load + terrain rebuild.
	world.sim.save_path = "user://test_free_%d.json" % OS.get_process_id()
	var old_route: Array = world.sim.route.duplicate()
	var old_positions: Array = world.sim.build_sites.duplicate()
	assert(world.sim.save_run() == OK)
	world.sim.route = world.sim.route_for_seed(5)
	assert(world.sim.load_run())
	assert(world.sim.route == old_route and world.sim.build_sites == old_positions)
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 6)
	world.command_ui.close_menu()
	world.sim.selected = 0
	world.sim.sell_selected()
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 5)
	world.command_ui.new_run()
	world._process(0.01)
	await process_frame
	assert(world.units.get_child_count() == 0 and world.sim.route != old_route)
	world.sim.countdown = 0
	world.sim._process(0.1)
	world._process(0.1)
	assert(world.sim.active and is_instance_valid(world.sim.enemies[0].model))
	world.sim.activate_overdrive()
	world.command_ui.open_menu()
	world.sim._process(10)
	assert(world.sim.overdrive == 8)
	world.command_ui.master_volume = 0.4
	world.command_ui.shadows = false
	world.command_ui.apply_settings()
	world.command_ui.save_settings()
	assert(not world.sun.shadow_enabled)
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(world.sim.save_path + suffix):
			DirAccess.remove_absolute(world.sim.save_path + suffix)
	for player in world.sound_players:
		player.stop()
	await create_timer(0.1).timeout
	world.queue_free()
	await create_timer(0.15).timeout
	print("PASS: free camera picking, contextual upgrade UI, repeat construction, HUD exclusion, muzzle/hit/frost feedback, kill coins, pause, seed/position persistence, visual rebuild, sale, random restart, waves, settings")
	quit(0)
