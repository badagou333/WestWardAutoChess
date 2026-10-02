extends "res://tests/free_roster_input_test.gd"
## Production _process runs normally. Camp transition, wallet and extra stock are
## boundary fixtures; all R/F/click/drag/refresh/upgrade actions use Viewport input.
func echo_key(code) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)
	await frames()

func run():
	game = load("res://scenes/free_escort.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	await press(KEY_SPACE)
	for card in game.shop_buttons: await click(card.get_global_rect().get_center())
	await press(KEY_SPACE)
	await press(KEY_B)
	for i in range(3):
		await click(game.heroes[i].position)
		await click(game.escort.position+Vector2(50+i*50,-30))
	check(game._deployed_count()==3,"initial placement remains freely chosen")
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	var monk_at: Vector2 = monk.position
	var hunter_at: Vector2 = hunter.position
	var healer_at: Vector2 = healer.position
	await click(game.start_button.get_global_rect().get_center())
	if game.state != game.GameState.BATTLE_RUNNING:
		check(false,"native departure must succeed before the camp fixture")
		await shot("camp-departure-failed")
		print("CAMP_ROSTER_INPUT failures=",failures)
		game.free()
		quit(1)
		return
	game.intermission = 999
	game.escort.position = Map.center(Vector2i(3,8))
	game._enter_wave_preparation()
	game.coins = 40
	await frames()
	check(game.is_processing() and game._camp_locked(),"normal-frame camp fixture")
	check(monk.position==monk_at and hunter.position==hunter_at and healer.position==healer_at,"camp never moves surviving team toward Tang")
	game.shop_types[0] = "foxfire_imp"
	await frames()
	await click(game.shop_buttons[0].get_global_rect().get_center())
	var fox = game.heroes.back()
	var wallet: int = game.coins
	var stock: Array = game.shop_types.duplicate()
	await press(KEY_1)
	await press(KEY_R)
	check(game.shop_types==stock and game.coins==wallet and monk.board_row<0,"R withdraws instead of refreshing even while shop open")
	check(game.selected_hero==null and game.camp_positions.points[0]==monk_at and game._deployed_count()==2,"R leaves exact empty marker and clears selection")
	await press(KEY_R)
	await echo_key(KEY_R)
	check(game._deployed_count()==2 and game.heroes.size()==4,"repeated/echo R cannot duplicate withdrawal")
	await click(game.refresh_button.get_global_rect().get_center())
	check(game.coins==wallet-2,"mouse refresh still costs two")
	await press(KEY_SPACE)
	var extra_point: Vector2 = game.escort.position+Vector2(20,60)
	await click(monk.position)
	await click(extra_point)
	check(game.carry_hero==monk and monk.board_row<0 and "原位" in game.status_label.text,"R then arbitrary point cannot rearrange existing unit")
	var cancelled_bench: Vector2 = monk.position
	await click(extra_point,MOUSE_BUTTON_RIGHT)
	check(monk.board_row<0 and game.carry_hero==null and game.carry_preview==null and monk.position==cancelled_bench and game.camp_positions.points[0]==monk_at and "已取消拿起" in game.status_label.text,"camp right click cancels pickup without bypassing lock or moving inventory")
	await press(KEY_ESCAPE)
	await pointer(monk.position,"motion")
	await pointer(monk.position,"press")
	await pointer(extra_point,"motion")
	await pointer(extra_point,"release")
	check(monk.board_row<0 and game.carry_hero==monk,"drag cannot bypass camp lock")
	await click(monk_at+Vector2(4,2))
	check(monk.position==monk_at and game.hero_slots[0]==monk,"point near distant empty marker replaces exactly, beyond initial deploy radius")
	await press(KEY_2)
	await pointer(hunter.position,"motion")
	await pointer(hunter.position,"press")
	await pointer(extra_point,"motion")
	await pointer(extra_point,"release")
	check(hunter.position==hunter_at and game.carry_hero==null,"deployed-hero drag cannot move a locked hero")
	await click(extra_point)
	check(hunter.position==hunter_at,"selected-hero ground click cannot move a locked hero")
	await press(KEY_F)
	check(game.swap_source==hunter and game.bench_open,"F arms selected field hero and opens bench")
	await press(KEY_ESCAPE)
	check(game.swap_source==null and hunter.position==hunter_at and fox.board_row<0,"Escape cancels exchange without ownership change")
	await press(KEY_F)
	await press(KEY_B)
	check(game.swap_source==null and not game.bench_open,"closing bench cancels pending exchange")
	await press(KEY_F)
	await press(KEY_3)
	check(game.swap_source==null and game.selected_hero==healer,"number switching cancels pending exchange")
	await press(KEY_2)
	await press(KEY_F)
	await echo_key(KEY_F)
	check(game.swap_source==hunter,"held F does not exchange or duplicate anything")
	await shot("camp-exchange-select")
	wallet = game.coins
	await click(fox.position)
	check(game.hero_slots[1]==fox and fox.position==hunter_at and hunter.board_row<0 and game.swap_source==null,"click reserve atomically exchanges and inherits exact numbered position")
	check(game.coins==wallet and game.population==3 and game.heroes.size()==4 and game._deployed_count()==3,"F changes no copies, coins or capacity")
	# Mouse upgrading buys capacity, not a fixed program-chosen coordinate.
	await click(game.level_button.get_global_rect().get_center())
	check(game.population==4 and game._deployed_count()==3 and game.coins==wallet-4,"native upgrade shows three of four with original cost")
	await click(hunter.position)
	await click(extra_point)
	var fourth = hunter
	check(game._deployed_count()==4 and fourth.position==extra_point and game.hero_slots[3]==fourth,"3/4 accepts an already-owned reserve at chosen new point without requiring another purchase")
	check(monk.position==monk_at and fox.position==hunter_at and healer.position==healer_at,"adding fourth does not rearrange the three existing heroes")
	await press(KEY_4)
	await press(KEY_R)
	await click(fourth.position)
	await click(extra_point+Vector2(0,55))
	check(fourth.board_row<0,"new point becomes fixed after first deployment")
	await click(extra_point)
	check(fourth.position==extra_point,"new seat refills at its chosen location")
	# Full-bench fixture: create eight independent locked reserves.
	game.coins = 60
	for hero in game.heroes: hero.merge_locked = true
	while game._free_bench_slot()>=0:
		game.shop_types[0] = "guard_monk"
		game._on_shop_pressed(0)
		game.heroes.back().merge_locked = true
	await frames()
	var reserve = game._hero_in_bench(7)
	await press(KEY_1)
	var before := snapshot()
	await press(KEY_R)
	check(snapshot()==before and game.selected_hero==monk and monk.position==monk_at and "后备已满" in game.status_label.text,"native full bench refuses R visibly and preserves state")
	await press(KEY_F)
	await click(reserve.position)
	check(snapshot()==before and game.hero_slots[0]==reserve and reserve.position==monk_at and monk.bench_slot==7,"native F works with full bench without a temporary extra slot")
	await shot("camp-exchange-complete")
	# GUI text focus must keep new shortcuts inert too.
	var edit := LineEdit.new()
	edit.position = Vector2(340,830)
	edit.size = Vector2(300,30)
	edit.z_index = 2100
	game.add_child(edit)
	edit.grab_focus()
	await press(KEY_R)
	await press(KEY_F)
	check(game.swap_source==null and snapshot()==before,"R/F do not steal text focus")
	edit.release_focus()
	edit.queue_free()
	await press(KEY_F)
	await click(game.start_button.get_global_rect().get_center())
	game.intermission = 999
	await press(KEY_P)
	check(game.swap_source==null and game.carry_hero==null and not game.bench_open,"departure clears exchange and pickup state")
	await press(KEY_4)
	var goal: Vector2 = fourth.position+Vector2(45,0)
	await click(goal,MOUSE_BUTTON_RIGHT)
	check(game._brain(fourth).mode=="手动" and game._brain(fourth).goal==goal,"next wave restores ordinary right-click movement")
	before = snapshot()
	await press(KEY_R)
	await press(KEY_F)
	check(snapshot()==before and game.swap_source==null and game._brain(fourth).goal==goal,"battle R/F cannot withdraw, swap or erase manual order")
	await press(KEY_P)
	await create_timer(0.3).timeout
	check(fourth.position!=extra_point,"normal frames execute resumed order")
	game._restart_demo()
	await frames()
	check(game.camp_positions.points.is_empty() and game.swap_source==null and game.hero_slots.is_empty() and game.coins==3,"restart returns to free initial preparation")
	print("CAMP_ROSTER_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
