# Render the current build. Use an isolated XDG data/config/cache directory.
# godot --path . --rendering-method gl_compatibility --script res://tools/capture_release.gd
extends SceneTree

const SEED = 481516
var output = ""
var version = ""

func _initialize() -> void:
	version = str(ProjectSettings.get_setting("application/config/version"))
	output = "res://docs/previews/v%s" % version
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	call_deferred("capture")

func screenshot(name: String) -> bool:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image.get_width() != 1440 or image.get_height() != 900:
		push_error("Preview resolution mismatch: %dx%d" % [image.get_width(), image.get_height()])
		quit(1)
		return false
	if image.save_png(output + "/" + name + ".png") != OK:
		push_error("Could not save preview: " + name)
		quit(1)
		return false
	print("CAPTURED ", output, "/", name, ".png")
	return true

func capture() -> void:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var world = load("res://game/world_3d.tscn").instantiate()
	root.add_child(world)
	# Fixture writes are isolated even if this script is run from a normal profile.
	world.sim.save_path = "user://preview_run.json"
	world.sim.profile_path = "user://preview_research.json"
	world.sim.research_levels = [0, 0, 0]
	world.sim.run_research = [0, 0, 0]
	world.sim.research_points = 0
	await create_timer(0.35).timeout
	if not await screenshot("menu"):
		return
	world.command_ui.close_menu()
	world.sim.generate_map(SEED)
	world.sim.cash = 12000
	var path: Array = world.sim.get_route()
	for i in range(1, path.size() - 1):
		var pos: Vector2 = path[i].lerp(path[i + 1], 0.5)
		var normal = (path[i + 1] - path[i]).normalized().orthogonal() * 86
		if not world.sim.placement_reason(pos + normal).is_empty():
			normal = -normal
		world.sim.build_type = i % 3
		world.sim.place_at(pos + normal)
	# Exercise the real upgrade/branch flow to show all nine weapon silhouettes.
	for i in range(3, mini(9, world.sim.towers.size())):
		world.sim.selected = i
		world.sim.upgrade_selected()
		world.sim.upgrade_selected()
		assert(world.sim.specialize(0 if i < 6 else 1))
	world.sim.cash = 428
	world.sim.wave = 5
	world.sim.active = true
	world.sim.remaining = 0
	for i in 15:
		world.sim.spawned = i
		var enemy = world.sim.create_enemy()
		enemy.segment = 1 + i % (path.size() - 1)
		enemy.pos = path[enemy.segment - 1].lerp(path[enemy.segment], 0.25 + (i % 3) * 0.23)
		world.sim.enemies.append(enemy)
	await create_timer(0.6).timeout
	for i in 3:
		var dead = world.sim.create_enemy()
		dead.pos = path[2 + i * 3]
		world.sim.damage_enemy(dead, 100000, true)
	await create_timer(0.25).timeout
	world.sim.paused = true
	for enemy in world.sim.enemies:
		if enemy.kind == "Panzer":
			enemy.hp = enemy.max_hp * 0.65
			enemy.slow_time = 2.0
			break
	world.sim.selected = -1
	if not await screenshot("battle"):
		return
	world.sim.selected = 6
	if not await screenshot("inspector"):
		return
	world.camera.size = 35
	if not await screenshot("closeup"):
		return
	world.queue_free()
	await process_frame
	var gallery = load("res://game/model_gallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.show_all()
	await create_timer(0.2).timeout
	if not await screenshot("gallery"):
		return
	gallery.show_combat(false)
	if not await screenshot("towers"):
		return
	gallery.show_combat(true)
	if not await screenshot("monsters"):
		return
	gallery.queue_free()
	await create_timer(0.15).timeout
	var metadata = {
		"version": version, "width": 1440, "height": 900,
		"map_seed": SEED, "arranged_gameplay_fixture": true,
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"assets": load("res://game/asset_catalog.gd").IDS.size(),
		"frames": ["menu", "battle", "inspector", "closeup", "gallery", "towers", "monsters"]
	}
	var file = FileAccess.open(output + "/capture.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("PASS: rendered release preview for ", version)
	quit()
