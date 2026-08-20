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

	# 固定商店内容，购买三个一星玉米，检查是否自动合成为一个二星单位。
	for i in range(3):
		game.shop_types[0] = "corn"
		game._update_shop_buttons()
		game._on_shop_pressed(0)
	if game.units.size() != 1:
		_fail("三合一后单位数量错误：%d" % game.units.size())
		return
	if game.units[0].star != 2 or game.units[0].unit_type != "corn":
		_fail("三合一没有生成二星玉米")
		return

	# 走真实的指针拖放链路，将合成单位部署到棋盘。
	var merged_unit = game.units[0]
	game._begin_pointer_action(merged_unit.global_position)
	game.dragging = true
	game._end_pointer_action(game._cell_center(1, 1))
	if merged_unit.lane != 1 or merged_unit.column != 1 or merged_unit.bench_slot != -1:
		_fail("单位拖放部署失败")
		return

	# 开始第一波，检查敌人生成链路。
	game._start_next_wave()
	game._process_wave(1.0)
	if game.current_wave != 1 or game.enemies.is_empty():
		_fail("第一波没有正常启动或生成敌人")
		return

	# 验证伤害、击杀奖励和敌人移除。
	var enemy = game.enemies[0]
	enemy.lane = 1
	enemy.position = merged_unit.position + Vector2(140, 0)
	var coins_before_kill = game.coins
	game._on_projectile_impact(enemy, enemy.max_health + 10.0, 0.0, enemy.global_position)
	if game.enemies.has(enemy) or game.coins <= coins_before_kill:
		_fail("攻击击杀或金币奖励链路失败")
		return

	# 验证重新开始会清空战局状态。
	game._restart_game()
	if not game.units.is_empty() or not game.enemies.is_empty() or game.current_wave != 0 or game.coins != 100:
		_fail("重新开始没有完整重置战局")
		return

	print("SMOKE_TEST_OK: 购买、三合一、真实拖放、战斗击杀、波次生成和重开均通过")
	game.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error("SMOKE_TEST_FAILED: " + message)
	quit(1)
