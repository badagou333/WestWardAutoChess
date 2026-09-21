extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in [0,1,3]:
		game._on_shop_pressed(i)
	var cells := [Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 3)]
	for i in range(game.heroes.size()):
		game._place_hero_on_board(game.heroes[i], cells[i])
	game._start_battle()
	var ticks := 0
	while game.state == game.GameState.BATTLE_RUNNING and ticks < 21600:
		game.step(1.0 / 60)
		ticks += 1
	if game.state != game.GameState.RESULT:
		push_error("FULL_BATTLE_TEST_FAILED: 360秒模拟后战斗未结束")
		quit(1)
		return
	if game.escort.dead:
		for hero in game.heroes:
			print("HERO_STATE: %s dead=%s hp=%.1f casts=%d cell=%s" % [hero.unit_type, hero.battle_dead, hero.health, hero.skill_casts, hero.battle_cell])
		for enemy in game.enemies:
			print("ENEMY_STATE: %s hp=%.1f cell=%s" % [enemy.enemy_type, enemy.health, enemy.battle_cell])
		push_error("FULL_BATTLE_TEST_FAILED: 默认阵容无法完成演示战斗；%.2f秒，战利品%d，波次%d" % [game.battle_elapsed, game.pending_loot, game.wave_index + 1])
		quit(1)
		return
	if game.pending_loot != 20:
		push_error("FULL_BATTLE_TEST_FAILED: 总战利品应为20，实际%d" % game.pending_loot)
		quit(1)
		return
	print("FULL_BATTLE_TEST_OK: 默认阵容完成4波Boss战，用时%.1f秒，唐僧剩余%d/%d，战利品%d" % [game.battle_elapsed, int(game.escort.health), int(game.escort.max_health), game.pending_loot])
	quit(0)
