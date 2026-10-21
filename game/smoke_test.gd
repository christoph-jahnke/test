extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scene = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.towers.append({"pad": 0, "level": 1, "cooldown": 0.0})
	scene.selected = 0
	scene.upgrade_selected()
	assert(scene.cash == 115 and scene.towers[0].level == 2, "Upgrade must cost cash")
	scene.launch_wave()
	assert(scene.wave == 1 and scene.remaining == 10)
	scene._process(0.1)
	assert(scene.enemies.size() == 1, "Wave must spawn an enemy")
	scene.remaining = 0
	scene.enemies.clear()
	scene.enemies.append({"pos": Vector2(140, 220), "segment": 1, "hp": 1.0, "max_hp": 1.0})
	scene.towers[0].cooldown = 0.0
	scene._process(0.01)
	assert(scene.enemies.is_empty(), "Turret must kill an in-range enemy")
	assert(scene.cash == 159 and not scene.active, "Kill and wave completion must pay rewards")
	scene.enemies.clear()
	scene.enemies.append({"pos": Vector2(1130, 250), "segment": 5, "hp": 10.0, "max_hp": 10.0})
	scene._process(0.01)
	assert(scene.lives == 29, "Escaping zombie must cost a life")
	scene.paused = true
	scene._process(20)
	assert(scene.lives == 29)
	scene.reset_run()
	assert(scene.lives == 30 and scene.cash == 160 and scene.wave == 0 and scene.towers.is_empty())
	print("PASS: spawning, upgrade costs, turret combat, wave rewards, life loss, pause, reset")
	quit(0)
