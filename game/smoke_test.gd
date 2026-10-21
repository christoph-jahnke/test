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
	# Countdown, pause, and repeat waves without user input.
	scene.paused = true
	scene._process(15)
	assert(scene.wave == 0 and scene.countdown == 12)
	scene.paused = false
	for tick in range(121):
		scene._process(0.1)
	assert(scene.wave == 1 and scene.active)
	scene.remaining = 0
	scene.enemies.clear()
	scene._process(0.1)
	assert(not scene.active and scene.countdown == 8)
	for tick in range(81):
		scene._process(0.1)
	assert(scene.wave == 2 and scene.active)
	# Duplicate pads and insufficient funds must not spend cash.
	scene.reset_run()
	assert(scene.build_at(0))
	assert(not scene.build_at(0) and scene.cash == 100)
	scene.build_type = 1
	assert(not scene.build_at(1))
	scene.sell_selected()
	assert(scene.cash == 142 and scene.towers.is_empty())
	# Armor reduces marine damage; mortar ignores it.
	scene.wave = 3
	scene.spawned = 2
	var armored = scene.create_enemy()
	assert(armored.kind == "Panzer")
	var health: float = armored.hp
	scene.damage_enemy(armored, 20, false)
	assert(is_equal_approx(health - armored.hp, 9.0))
	health = armored.hp
	scene.damage_enemy(armored, 20, true)
	assert(is_equal_approx(health - armored.hp, 20.0))
	# Mortar damages nearby enemies but not distant ones.
	scene.reset_run()
	scene.build_type = 1
	assert(scene.build_at(0))
	scene.active = true
	scene.remaining = 0
	for pos in [Vector2(140, 220), Vector2(160, 220), Vector2(600, 450)]:
		var enemy = scene.create_enemy()
		enemy.pos = pos
		enemy.hp = 100.0
		enemy.max_hp = 100.0
		scene.enemies.append(enemy)
	scene._process(0.01)
	assert(scene.enemies[0].hp == 68 and scene.enemies[1].hp == 68)
	assert(scene.enemies[2].hp == 100)
	# Cryo applies a real movement penalty, not just a visual effect.
	scene.reset_run()
	scene.build_type = 2
	assert(scene.build_at(0))
	var chilled = scene.create_enemy()
	chilled.pos = Vector2(140, 220)
	scene.enemies.append(chilled)
	scene.active = true
	scene._process(0.01)
	assert(chilled.slow_time > 0)
	var old_x: float = chilled.pos.x
	scene._process(0.1)
	assert(is_equal_approx(chilled.pos.x - old_x, 2.4))
	# Titan wave and leak penalty; defeat must stop future waves.
	scene.reset_run()
	scene.wave = 5
	scene.spawned = 0
	var boss = scene.create_enemy()
	assert(boss.kind == "Titan" and boss.leak == 5)
	boss.pos = Vector2(1130, 250)
	boss.segment = 5
	scene.enemies.append(boss)
	scene.lives = 5
	scene._process(0.01)
	assert(scene.lives == 0)
	scene._process(100)
	assert(scene.wave == 5)
	scene.reset_run()
	scene.toggle_speed()
	scene._process(1)
	assert(scene.countdown == 10)
	# Deterministic unattended run: reaches game over with waves progressing.
	scene.reset_run()
	assert(scene.build_at(0))
	for tick in range(18000):
		scene._process(0.1)
		if scene.lives <= 0:
			break
	assert(scene.wave >= 2 and scene.lives == 0)
	print("PASS: automatic waves, pause, economy, sale, armor, splash, cryo, boss, speed, unattended run")
	quit(0)
