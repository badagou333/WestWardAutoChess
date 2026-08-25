extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var game_scene = load("res://scenes/main.tscn")
	if game_scene == null:
		_fail("无法加载主场景")
		return
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame

	if game.population != 3 or game.escort.position != game._cell_center(Vector2i(2, 3)):
		_fail("初始人口或唐僧中央位置错误")
		return
	if game.coins != 10 or game.refresh_token != 1 or game.shop_types.size() != 5:
		_fail("初始经济或商店错误")
		return

	for i in range(3):
		game._on_shop_pressed(i)
	if game.heroes.size() != 1:
		_fail("三合一后队员数量错误：%d" % game.heroes.size())
		return
	var merged = game.heroes[0]
	if merged.star != 2 or merged.unit_type != "rabbit" or game.coins != 7:
		_fail("自动三合一或招募金币结算错误")
		return

	game._begin_pointer_action(merged.position)
	game.dragging = true
	game._end_pointer_action(game._cell_center(Vector2i(2, 2)))
	if merged.board_row != 2 or merged.board_col != 2 or game._deployed_count() != 1:
		_fail("拖放布阵失败")
		return

	game.coins = 20
	game._on_level_pressed()
	if game.population != 4 or game.coins != 10:
		_fail("升人口价格或结果错误")
		return

	game._start_battle()
	if game.state != game.GameState.BATTLE_RUNNING or not merged.active_in_battle or game.intermission <= 0.0:
		_fail("战斗启动或3秒预告错误")
		return
	game.intermission = 0.0
	game._begin_wave()
	game._process_wave(0.1)
	if game.enemies.is_empty():
		_fail("第一波敌人没有生成")
		return

	var enemy = game.enemies[0]
	enemy.battle_cell = Vector2i(2, 1)
	enemy.position = game._cell_center(enemy.battle_cell)
	merged.mana = merged.max_mana
	var health_before: float = enemy.health
	game._cast_skill(merged, enemy)
	if enemy.health >= health_before or merged.mana != 0.0:
		_fail("自动技能释放错误")
		return

	merged.active_in_battle = false
	game._spawn_enemy("boar", Vector2i(2, 2))
	enemy = game.enemies.back()
	enemy.attack_cooldown = 0.0
	var escort_before: float = game.escort.health
	game._process_enemies(0.1)
	if game.escort.health >= escort_before:
		_fail("敌人没有攻击唐僧")
		return

	game.coins = 5
	game.pending_loot = 20
	game.escort.health = game.escort.max_health
	game._finish_battle(true)
	if game.coins != 25 or not game.overlay.visible:
		_fail("三星战利品结算错误")
		return

	game._restart_demo()
	if not game.heroes.is_empty() or not game.enemies.is_empty() or game.coins != 10 or game.population != 3 or game.state != game.GameState.PREPARING:
		_fail("重新体验没有完整重置")
		return

	print("SMOKE_TEST_OK: 商店、自动合成、布阵、人口、波次、技能、唐僧受击、战后结算和重开均通过")
	game.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error("SMOKE_TEST_FAILED: " + message)
	quit(1)
