extends "res://tests/route_graphical_input_test.gd"
const Map = preload("res://scripts/data/escort_map.gd")

func click(point: Vector2, button := MOUSE_BUTTON_LEFT):
	# Move the native pointer before pressing so Control hover/hit-test state is
	# settled even when the OS reused a differently sized previous game window.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await frames()
	await super.click(point,button)

func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	game.debug_navigation = true
	await shot("free-escort-boundaries")
	game.debug_navigation = false
	await press(KEY_SPACE)
	await press(KEY_4)
	check(game.heroes.is_empty(),"no hidden fourth slot")
	await press(KEY_1)
	await press(KEY_2)
	await press(KEY_3)
	check(game.coins==0 and game.heroes.size()==3,"native three purchases")
	await press(KEY_SPACE)
	for i in range(3):
		await click(game.heroes[i].position)
		await click(game.escort.position+Vector2(45+i*32,-35))
	check(game._deployed_count()==3,"native continuous deployment")
	await shot("free-escort-preparation")
	await click(game.start_button.get_global_rect().get_center())
	check(game.state==game.GameState.BATTLE_RUNNING,"native departure")
	game.intermission = 999
	var hero = game.heroes[0]
	await click(hero.position)
	await press(KEY_P)
	var goal := Map.center(Vector2i(5,3))+Vector2(17,8)
	await click(goal,MOUSE_BUTTON_RIGHT)
	check(game._brain(hero).mode=="手动" and game._brain(hero).goal==goal,"native paused precise command")
	await click(Vector2(1020,650),MOUSE_BUTTON_RIGHT)
	check(game._brain(hero).goal==goal,"native water click retains command")
	var frozen: Vector2 = hero.position
	game.step(2)
	check(hero.position==frozen,"native pause freezes movement")
	await shot("free-escort-manual")
	await press(KEY_P)
	game.step(0.5)
	check(hero.position!=frozen,"native resume")
	await press(KEY_ESCAPE)
	check(game._brain(hero).mode=="跟随","native cancel returns to guard")
	await click(game.speed_button.get_global_rect().get_center())
	check(game.battle_speed==2,"native double speed")
	game.intermission = 0
	game._begin_wave()
	game.step(6)
	await shot("free-escort-combat")
	# The UI switch constructs a new scene, never reuses AI/economy state.
	var switch_button: Button
	for child in game.get_children():
		if child is Button and child.text.begins_with("切换格子版"): switch_button = child
	check(switch_button != null,"legacy comparison entry present")
	await click(switch_button.get_global_rect().get_center())
	game = current_scene
	game.set_process(false)
	check(game.get_script().resource_path=="res://scripts/escort_route.gd" and game.coins==3 and game.heroes.is_empty() and game.battle_speed==1,"switch resets to isolated legacy scene")
	for child in game.get_children():
		if child is Button and child.text.begins_with("无格子试验"): switch_button = child
	await click(switch_button.get_global_rect().get_center())
	game = current_scene
	game.set_process(false)
	check(game.get_script().resource_path=="res://scripts/free_escort.gd" and game.brains.is_empty() and game.coins==3,"round-trip switch clears AI")
	print("FREE_GRAPHICAL_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
