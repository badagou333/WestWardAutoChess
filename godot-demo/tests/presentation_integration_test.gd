extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for index in range(3):
		game._on_shop_pressed(index)
	var hero = game.heroes[0]
	assert(hero.star == 2 and hero.presentation != null, "Merge keeps presentation")
	assert(hero.presentation.role == "wild_hunter", "Legacy visual alias")
	assert(not hero.portrait.visible, "No duplicate old portrait")
	hero.set_bench_mode(true)
	assert(hero.presentation.scale.x < 1, "Bench fits compact slots")
	hero.set_bench_mode(false)
	assert(hero.presentation.scale == Vector2.ONE, "Board restores scale")
	var hp: float = hero.health
	hero.presentation.play_hit()
	assert(hero.health == hp, "Presentation cannot apply damage")
	hero.play_attack()
	game.battle_paused = true
	var phase: float = hero.presentation.pose_time
	hero._process(0.2)
	assert(hero.presentation.pose_time == phase, "Pause freezes new pose")
	game.battle_paused = false
	game.battle_speed = 2
	hero._process(0.05)
	assert(is_equal_approx(hero.presentation.pose_time, phase + 0.1), "Double-speed pose clock")
	hero.take_damage(hero.max_health)
	assert(hero.presentation.pose == "retreat" and hero.visible, "Death keeps fade visible")
	hero.end_battle()
	assert(not hero.presentation.dead and hero.presentation.pose == "idle", "Return resets visual death")
	game._spawn_enemy("tiger", Vector2i(0, 3))
	var boss = game.enemies[0]
	assert(boss.presentation.role == "bear_lord", "Boss visual loaded")
	boss.take_damage(boss.max_health)
	assert(boss.presentation.pose == "retreat", "Boss fade begins")
	boss._process(2)
	assert(boss.is_queued_for_deletion(), "Faded boss is released")
	game.queue_free()
	await process_frame
	print("PRESENTATION_INTEGRATION_OK")
	quit()
