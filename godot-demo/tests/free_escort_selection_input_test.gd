extends "res://tests/free_escort_graphical_test.gd"
## QA-20261001-01: real Viewport input, no direct movement-command calls.
func pointer(point: Vector2, kind: String) -> void:
	await settle_pointer(point)
	if kind == "motion":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion,true)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = kind == "press"
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		root.push_input(event,true)
	await frames()

func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	await press(KEY_SPACE)
	await click(game.shop_buttons[0].get_global_rect().get_center())
	await click(game.shop_buttons[1].get_global_rect().get_center())
	var hero = game.heroes[0]
	var other = game.heroes[1]
	await click(hero.position)
	await click(game.escort.position+Vector2(70,-20))
	await click(other.position)
	await click(game.escort.position+Vector2(160,30))
	check(game._deployed_count()==2,"fixture native deployment")
	await click(game.start_button.get_global_rect().get_center())
	check(game.state==game.GameState.BATTLE_RUNNING,"fixture native start")
	game.intermission = 999
	await click(hero.position)
	await press(KEY_P)
	var above: Vector2 = hero.position+Vector2(0,-80)
	check(game.space.valid(above) and game._stop_free(above,hero),"QA target is valid ground inside own hitbox")
	check(game._hero_at_position(above)==hero,"QA target really hits the selected hero's tall hitbox")
	await click(above)
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==above,"QA-01 paused left click above selected hero creates exact order")
	check("手动移动优先" in game.command_note,"accepted click gives manual feedback")
	var frozen: Vector2 = hero.position
	game.step(1)
	check(hero.position==frozen,"paused command does not move actor")
	await click(above,MOUSE_BUTTON_RIGHT)
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==above,"same-point right click still works")
	await press(KEY_1)
	await press(KEY_ESCAPE)
	await press(KEY_P)
	await click(above)
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==above,"QA-01 running left click above selected hero creates exact order")
	# An actual nearby enemy must not steal this UI-issued manual order.
	game._spawn_enemy("boar",Map.ROUTE[0])
	game.enemies[0].position = hero.position+Vector2(80,0)
	game.step(0.12)
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==above,"automatic engagement cannot steal left-click order")
	await press(KEY_P)
	await click(other.position)
	check(game.selected_hero==other and game._brain(other).mode!="手动","click different hero switches selection, not a ground order")
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==above,"switch selection preserves first hero's command")
	await click(hero.position)
	check(game.selected_hero==hero,"switch selection back")
	var before_goal: Vector2 = game._brain(hero).goal
	var drag_end: Vector2 = hero.position+Vector2(-45,-110)
	await pointer(hero.position,"motion")
	await pointer(hero.position,"press")
	check(game._brain(hero).goal==before_goal,"drag press on selected hero does not issue premature move")
	await pointer(drag_end,"motion")
	await pointer(drag_end,"release")
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==drag_end,"selected hero drag dispatches release destination")
	await click(Vector2(1020,650))
	check(game._brain(hero).goal==drag_end and "保留原任务" in game.command_note,"invalid left ground retains order with feedback")
	# The current actor's own foot is inside its hitbox, but occupied by the
	# escort in this explicit invalid-location fixture: rejection must retain order.
	var escort_before: Vector2 = game.escort.position
	game.escort.position = hero.position
	await click(hero.position)
	check(game._brain(hero).goal==drag_end,"invalid repeated selection does not erase existing order")
	game.escort.position = escort_before
	var right_goal: Vector2 = hero.position+Vector2(-55,-70)
	await click(right_goal,MOUSE_BUTTON_RIGHT)
	check(game._brain(hero).goal==right_goal,"right click replaces left/drag order")
	await press(KEY_1)
	await press(KEY_ESCAPE)
	check(game._brain(hero).mode=="驻守" and game.pointer_hero==null,"cancel clears pending pointer and establishes guard")
	# Starting a drag on a different hero both selects it and moves that hero.
	var other_end: Vector2 = other.position+Vector2(-20,65)
	await pointer(other.position,"motion")
	await pointer(other.position,"press")
	await pointer(other_end,"motion")
	await pointer(other_end,"release")
	check(game.selected_hero==other and game._brain(other).mode=="手动" and game._brain(other).goal==other_end,"other-hero drag still selects and commands")
	await pointer(other.position,"motion")
	await pointer(other.position,"press")
	await press(KEY_ESCAPE)
	await pointer(other.position+Vector2(0,-80),"release")
	check(game._brain(other).mode=="驻守" and not game.pointer_was_selected,"cancel during held click prevents release from reviving order")
	game.free()
	# Preserve the old grid mode's repeat-click selection convention through
	# the same real Viewport event route, not a direct input-handler invocation.
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
	check(game.state==game.GameState.BATTLE_RUNNING,"legacy native start")
	game.intermission = 999
	await click(hero.position)
	await press(KEY_P)
	await click(hero.position+Vector2(0,-80))
	check(game.selected_hero==hero and game.orders.is_empty(),"legacy repeated-selection convention unchanged")
	print("FREE_SELECTION_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
