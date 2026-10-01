extends "res://tests/free_escort_graphical_test.gd"
## QA-20261001-02: assert the rendered Control text, not command_note.
func visible_text(fragment: String) -> bool:
	return game.status_label.is_visible_in_tree() and fragment in game.status_label.text

func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	await press(KEY_SPACE)
	await press(KEY_1)
	await press(KEY_SPACE)
	var hero = game.heroes[0]
	await click(hero.position)
	await click(game.escort.position+Vector2(70,-20))
	await click(game.start_button.get_global_rect().get_center())
	check(game.state==game.GameState.BATTLE_RUNNING,"native departure")
	game.intermission = 999
	await click(hero.position)
	await press(KEY_P)
	var frozen: Vector2 = hero.position
	var escort_frozen: Vector2 = game.escort.position
	var battle_clock: float = game.battle_elapsed
	await click(Vector2(1000,470))
	check(visible_text("暂停") and visible_text("目标无效") and visible_text("保留原任务"),"QA-02 paused rejection reason remains visible beside pause status")
	await shot("free-feedback-paused-rejection")
	check(game._brain(hero).mode=="跟随" and game.battle_paused,"rejection does not change task or unpause")
	var first_goal: Vector2 = hero.position+Vector2(0,-80)
	await click(first_goal)
	check(visible_text("暂停") and visible_text("手动移动优先") and not visible_text("目标无效"),"paused accepted order replaces rejection visibly")
	await shot("free-feedback-paused-accepted")
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==first_goal,"accepted order retained while paused")
	await click(Vector2(1000,470))
	check(visible_text("目标无效") and not visible_text("手动移动优先"),"new rejection replaces accepted feedback")
	check(game._brain(hero).goal==first_goal,"rejected replacement retains accepted task")
	await click(game.speed_button.get_global_rect().get_center())
	check(game.battle_speed==2 and game.battle_paused,"UI feedback does not interfere with paused double speed")
	# This timer is wall-clock, with the game's process disabled and battle time
	# frozen: a simulation-tick countdown cannot satisfy this visible assertion.
	await create_timer(1.6).timeout
	await frames()
	check(visible_text("目标无效"),"double speed does not halve real-time feedback duration")
	await create_timer(1.7).timeout
	await frames()
	check(visible_text("暂停") and not visible_text("目标无效"),"paused feedback expires in real time without battle ticks")
	game.step(2)
	check(hero.position==frozen and game.escort.position==escort_frozen and game.battle_elapsed==battle_clock and game.battle_paused,"feedback aging does not advance the paused simulation")
	var second_goal: Vector2 = hero.position+Vector2(-35,-100)
	await click(second_goal,MOUSE_BUTTON_RIGHT)
	check(visible_text("暂停") and visible_text("手动移动优先") and game._brain(hero).goal==second_goal,"new paused order refreshes expired feedback")
	await press(KEY_P)
	check(not visible_text("暂停") and not visible_text("手动移动优先") and visible_text("自动护卫"),"resume removes stale paused feedback")
	check(game._brain(hero).goal==second_goal and not game.battle_paused,"resume preserves pending command")
	game.step(0.1)
	check(hero.position!=frozen,"resumed command executes")
	await click(Vector2(1000,470))
	check(visible_text("目标无效") and not visible_text("暂停"),"running rejection remains visible")
	await create_timer(3.3).timeout
	await frames()
	check(not visible_text("目标无效") and visible_text("自动护卫"),"running feedback expires without simulation-speed dependency")
	await click(hero.position+Vector2(0,-80),MOUSE_BUTTON_RIGHT)
	check(visible_text("手动移动优先"),"running accepted feedback visible")
	# Lifecycle is controlled only to enter the camp/restart fixtures; input
	# feedback above always originates from complete Viewport mouse/key events.
	game._enter_wave_preparation()
	await frames()
	check(visible_text("营地抵达") and not visible_text("手动移动优先") and not visible_text("暂停"),"camp replaces prior command feedback")
	game._restart_demo()
	await frames()
	check(not visible_text("营地抵达") and not visible_text("手动移动优先") and visible_text("招募后部署"),"restart clears previous feedback")
	game.free()
	game = load("res://scenes/escort_route.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	await press(KEY_SPACE)
	await press(KEY_1)
	await press(KEY_SPACE)
	hero = game.heroes[0]
	await click(hero.position)
	await click(game._cell_center(Vector2i(7,1)))
	await click(game.start_button.get_global_rect().get_center())
	await click(hero.position)
	await press(KEY_P)
	await click(Vector2(1000,470),MOUSE_BUTTON_RIGHT)
	check(visible_text("战术暂停") and game.battle_paused and game.orders.is_empty(),"legacy pause and invalid-order behavior unchanged")
	print("FREE_FEEDBACK_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
