extends SceneTree
var failures := 0
var game
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func frames():
	for i in range(3):
		# The simulation is manually clocked, but Controls still need the same UI
		# refresh as the production _process loop before mouse hit testing.
		if is_instance_valid(game): game._update_ui()
		await process_frame
func press(code):
	var event := InputEventKey.new()
	event.keycode=code; event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=InputEventKey.new(); event.keycode=code; event.pressed=false
	Input.parse_input_event(event)
	await frames()
func click(point: Vector2, button := MOUSE_BUTTON_LEFT):
	await settle_pointer(point)
	# push_input routes through actual Control hit testing and unhandled input.
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point; event.button_index=button; event.pressed=true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	root.push_input(event,true)
	await frames()
	event=InputEventMouseButton.new()
	event.position=point; event.global_position=point; event.button_index=button; event.pressed=false
	root.push_input(event,true)
	await frames()
func settle_pointer(point: Vector2) -> void:
	# Cocoa delivers warp-generated OS motion asynchronously. Let it settle,
	# then set the logical pointer immediately before the complete gesture.
	root.warp_mouse(point)
	await create_timer(0.05).timeout
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
func shot(name: String):
	game._update_ui(); game.queue_redraw(); await frames()
	check(root.get_texture().get_image().save_png("/tmp/"+name+".png")==OK,"Screenshot "+name)
func run():
	game=load("res://scenes/escort_route.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	await frames()
	await press(KEY_SPACE)
	check(game.shop_open,"Native Space opens shop")
	await shot("nine-sols-shop")
	await click(game.refresh_button.get_global_rect().get_center())
	check(game.coins==1,"Native refresh button charges two")
	var stock=game.shop_types.duplicate()
	await click(game.refresh_button.get_global_rect().get_center())
	check(game.coins==1 and game.shop_types==stock,"Native disabled refresh preserves stock")
	game._restart_demo(); await press(KEY_SPACE)
	await press(KEY_4); await press(KEY_5)
	check(game.heroes.is_empty(),"Native 4/5 rejected")
	await press(KEY_1); await press(KEY_2); await press(KEY_3)
	check(game.heroes.size()==3 and game.coins==0,"Native 1/2/3 purchases")
	await press(KEY_SPACE)
	var cells := [Vector2i(7,1),Vector2i(9,1),Vector2i(9,2)]
	for i in range(3):
		await click(game.heroes[i].position)
		await click(game._cell_center(cells[i]))
	check(game._deployed_count()==3,"Native selection and land clicks deploy three")
	await click(game.start_button.get_global_rect().get_center())
	check(game.state==game.GameState.BATTLE_RUNNING,"Native start button")
	game.intermission=999
	await click(game.heroes[0].position)
	await click(game._cell_center(Vector2i(5,2)),MOUSE_BUTTON_RIGHT)
	check(game.orders.has(game.heroes[0]),"Native right-click creates order")
	game.step(.2)
	await press(KEY_P)
	var position: Vector2=game.heroes[0].position
	await press(KEY_ESCAPE)
	game.step(2)
	check(game.heroes[0].position==position and not game.orders.has(game.heroes[0]),"Native pause/escape")
	await press(KEY_P); game.step(2)
	await shot("nine-sols-route")
	# Visual-only scene population displays every adopted skin without changing
	# gameplay data or presenting this gallery as a legally purchased formation.
	game._restart_demo(); game.coins=20; game.population=8
	var gallery_cells := [Vector2i(4,3),Vector2i(4,6),Vector2i(4,9),Vector2i(4,12),Vector2i(4,15)]
	for i in range(5):
		game.shop_types[0]=game.DemoUnits.SHOP[i]; game._on_shop_pressed(0)
		var actor=game.heroes.back()
		actor.board_row=gallery_cells[i].x; actor.board_col=gallery_cells[i].y
		actor.bench_slot=-1
		actor.battle_cell=gallery_cells[i]; actor.position=game._cell_center(gallery_cells[i]); actor.set_bench_mode(false)
	for i in range(4): game._spawn_enemy(["rat","wolf","boar","bear_lord"][i],Vector2i(10,3+i*4))
	game._tick(0)
	game._set_shop_open(false)
	await shot("nine-sols-cast")
	print("GRAPHICAL_INPUT failures=",failures)
	game.free(); quit(1 if failures else 0)
