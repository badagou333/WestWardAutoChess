extends "res://tests/run_casualties_input_test.gd"
## Production frames and complete Viewport input. Wounded HP, passive enemy and
## accelerated cleared checkpoint are explicit fixtures, not normal play outcomes.

func settle_pointer(point: Vector2) -> void:
	# Cocoa's queued warp motion can overwrite the injected press position.
	# Wait for the actual logical pointer to be stable, not just one fixed delay.
	root.grab_focus()
	await process_frame
	root.warp_mouse(point)
	var began := Time.get_ticks_msec()
	var stable := 0
	while stable < 3 and Time.get_ticks_msec()-began < 1500:
		await create_timer(0.04).timeout
		stable = stable+1 if root.get_mouse_position().distance_to(point)<5 else 0
	if stable < 3:
		print("TRIAL_POINTER_TIMEOUT point=",point," actual=",root.get_mouse_position()," window_size=",root.size," window_position=",root.position," screen_size=",DisplayServer.screen_get_size())
	check(stable==3,"system pointer settles before complete trial gesture")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)

func click(point: Vector2, button := MOUSE_BUTTON_LEFT):
	await super.click(point,button)
	if "--trace-input" in OS.get_cmdline_user_args() and is_instance_valid(game):
		print("TRIAL_CLICK point=",point," pointer=",root.get_mouse_position()," logical=",game.get_global_mouse_position()," coins=",game.coins," heroes=",game.heroes.size()," carry=",game.carry_hero)

func shot(name: String) -> void:
	game._update_ui()
	game.queue_redraw()
	await frames()
	# A passed toggle assertion is not proof the OS refreshed the viewport.
	# Draw actual scene state before reading pixels; do not advance pose/time.
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("/tmp/"+name+".png")==OK,"Screenshot "+name)

func native_roster() -> bool:
	await press(KEY_SPACE)
	for card in game.shop_buttons: await click(card.get_global_rect().get_center())
	check(game.heroes.size()==3,"three paid purchases required before trial input")
	if game.heroes.size()!=3: return false
	for i in range(3):
		var hero = game.heroes[i]
		var source: Vector2 = hero.position
		var goal: Vector2 = game.escort.position+Vector2(50+i*60,-30)
		await click(source)
		if game.carry_hero!=hero:
			print("TRIAL_PICKUP source=",source," pointer=",root.get_mouse_position()," selected=",game.selected_hero," carry=",game.carry_hero)
			check(false,"reserve pickup must select the exact paid hero "+hero.unit_type)
			return false
		await click(goal)
		if hero.board_row<0:
			print("TRIAL_DEPLOY unit=",hero.unit_type," source=",source," goal=",goal," pointer=",root.get_mouse_position()," carry=",game.carry_hero," notice=",game.command_note)
			check(false,"legal fixture deployment required "+hero.unit_type)
			return false
	await click(game.start_button.get_global_rect().get_center())
	game.intermission = 10000
	check(game.state==game.GameState.BATTLE_RUNNING,"trial starts with native departure button")
	return game.state==game.GameState.BATTLE_RUNNING

func run():
	root.size = Vector2i(1440,810) if "--review-1440" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	game = load("res://scenes/monk_animation_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	check(game.is_processing() and game.monk_sample_enabled,"explicit sample entry runs normal production frames")
	check(game.animation_toggle.get_global_rect().end.y <= game.order_label.get_global_rect().position.y,"comparison button does not overlap instructions")
	check(game.animation_toggle.z_index>game.order_label.z_index,"comparison button is above the lifted sidebar background")
	if not await native_roster():
		await finish_trial()
		return
	var hero = game.heroes[0]
	check(hero.board_row>=0 and game._deployed_count()==3,"native fixture deployed all three, including sampled monk")
	if hero.board_row<0 or game._deployed_count()!=3:
		print("MONK_DEPLOYMENT position=",hero.position," carry=",game.carry_hero," notice=",game.command_note)
		await finish_trial()
		return
	var view = hero.presentation
	check(view.motion_sample_enabled and not game.heroes[1].presentation.motion_sample_enabled and not game.heroes[2].presentation.motion_sample_enabled,"only monk changes animation, not other purchased roles")
	for ally in game.heroes: ally.cooldown = 10000
	var origin: Vector2 = hero.position
	var goal: Vector2 = game._near_free(origin+Vector2(160,-45),hero,200)
	check(goal!=Vector2.INF and goal.x>origin.x+100,"real movement fixture has a rightward legal destination")
	await press(KEY_1)
	await click(goal,MOUSE_BUTTON_RIGHT)
	var phases := {}
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 7000 and game._brain(hero).mode=="手动":
		if view.pose=="move": phases[view.frame_index] = true
		await process_frame
	check([2,3,4,5].all(func(index): return phases.has(index)),"real root movement displays all four walk phases")
	check(hero.position.distance_to(goal)<0.1 and view.pose=="idle" and view.frame_index in [0,1],"arrival stops drawn walk at exact legal goal")
	await click(game.speed_button.get_global_rect().get_center())
	check(game.battle_speed==2,"normal speed button enables 2x sample")
	await press(KEY_1)
	await click(origin,MOUSE_BUTTON_RIGHT)
	began = Time.get_ticks_msec()
	while view.pose!="move" and Time.get_ticks_msec()-began < 1000: await process_frame
	await press(KEY_P)
	var at: Vector2 = hero.position
	var clock: float = view.sample_walk_time
	check(view.facing==-1 and view.pose=="move" and view.visual_transform().origin==Vector2.ZERO,"leftward walk mirrors around unchanged root anchor")
	await create_timer(0.12).timeout
	check(hero.position==at and view.sample_walk_time==clock,"pause freezes root and walk phase even at 2x")
	await shot("monk-trial-20261004-walk-left")
	await click(game.animation_toggle.get_global_rect().get_center())
	check(not view.motion_sample_enabled and game._brain(hero).goal==origin and hero.position==at and view.sample_walk_time==clock,"paused native switch to old keeps movement and phase")
	await click(game.animation_toggle.get_global_rect().get_center())
	check(view.motion_sample_enabled and view.sample_walk_time==clock,"native switch back keeps phase, not a new walk")
	await press(KEY_P)
	began = Time.get_ticks_msec()
	while game._brain(hero).mode=="手动" and Time.get_ticks_msec()-began < 7000: await process_frame
	check(hero.position.distance_to(origin)<0.1 and view.pose=="idle","2x turn/return reaches origin and stops")
	await click(game.speed_button.get_global_rect().get_center())
	# Real AI attack with normal monk damage, passive high-HP enemy fixture.
	game._spawn_enemy("boar",Map.ROUTE[0])
	var target = game.enemies.back()
	target.position = game._near_free(hero.position+Vector2(45,0),target,60)
	target.health = 100000
	target.max_health = 100000
	target.damage = 0
	target.attack_cooldown = 10000
	target.move_interval = 100000
	check(game._in_range(hero,target),"window target has legal melee range and sight line")
	hero.cooldown = 0
	var hp: float = target.health
	var hits: int = game.combat.counts.hits
	began = Time.get_ticks_msec()
	while target.health==hp and Time.get_ticks_msec()-began < 2000: await process_frame
	check(target.health==hp-hero.damage and view.frame_index==8 and game.combat.counts.hits==hits+1,"normal-frame original damage event coincides with sample contact frame exactly once")
	await press(KEY_P)
	var serial: int = view.attack_serial
	var time: float = view.pose_time
	var wallet: int = game.coins
	await shot("monk-trial-20261004-contact-new")
	await click(game.animation_toggle.get_global_rect().get_center())
	check(not view.motion_sample_enabled and view.attack_serial==serial and view.pose_time==time and target.health==hp-hero.damage,"native old comparison never repeats contact damage")
	await shot("monk-trial-20261004-contact-old")
	check(FileAccess.get_file_as_bytes("/tmp/monk-trial-20261004-contact-new.png")!=FileAccess.get_file_as_bytes("/tmp/monk-trial-20261004-contact-old.png"),"new/old comparison pixels actually refresh, not identical stale captures")
	await click(game.animation_toggle.get_global_rect().get_center())
	check(view.motion_sample_enabled and view.attack_serial==serial and game.coins==wallet,"new comparison preserves serial and economy")
	await press(KEY_P)
	hero.cooldown = 10000
	await create_timer(0.6).timeout
	check(view.pose=="idle","recovery completes before nonlethal hit fixture")
	game._spawn_enemy("boar",Map.ROUTE[0])
	var striker = game.enemies.back()
	striker.position = game._near_free(hero.position+Vector2(-30,0),striker,60)
	check(game._in_range(striker,hero),"nonlethal attacker has clear range and sight")
	var live_hp: float = hero.health
	game.combat.request(striker,hero)
	began = Time.get_ticks_msec()
	while hero.health==live_hp and Time.get_ticks_msec()-began < 2000: await process_frame
	check(hero.health==live_hp-striker.damage and view.pose=="hit" and view.frame_index==10,"normal nonlethal damage uses drawn hit frame")
	await press(KEY_P)
	serial = view.attack_serial
	await click(game.animation_toggle.get_global_rect().get_center())
	await click(game.animation_toggle.get_global_rect().get_center())
	check(view.pose=="hit" and view.frame_index==10 and view.attack_serial==serial,"hit comparison preserves recovery and attack sequence")
	await press(KEY_P)
	for threat in game.enemies: threat.queue_free()
	game.enemies.clear()
	game.combat.clear()
	await create_timer(0.2).timeout
	await native_combat_loss(hero)
	began = Time.get_ticks_msec()
	while view.pose_time < 0.17 and Time.get_ticks_msec()-began < 1000: await process_frame
	await press(KEY_P)
	check(hero.run_fallen and view.pose=="retreat" and view.frame_index==12,"real death uses terminal low pose, never returns to idle")
	await shot("monk-trial-20261004-death")
	await click(game.animation_toggle.get_global_rect().get_center())
	await click(game.animation_toggle.get_global_rect().get_center())
	check(hero.run_fallen and hero.health==0 and view.dead and view.pose=="retreat" and game.casualties.seats.has(0),"death comparison cannot revive or free seat")
	await press(KEY_P)
	await create_timer(0.7).timeout
	check(view.visual_alpha==0,"death fades once in real time without loop")
	await native_camp()
	check(hero.run_fallen and not hero.visible and game.roster_hud.slots[0].permanent,"camp keeps dead sample hidden and blocked")
	await click(game.animation_toggle.get_global_rect().get_center())
	game._restart_demo()
	await frames()
	await press(KEY_SPACE)
	await click(game.shop_buttons[0].get_global_rect().get_center())
	check(not game.heroes[0].presentation.motion_sample_enabled and not game.heroes[0].run_fallen and game.coins==2,"restart creates new living inventory, retains chosen old comparison mode")
	await click(game.animation_toggle.get_global_rect().get_center())
	check(game.heroes[0].presentation.motion_sample_enabled,"newly recruited monk can switch back to sample")
	# The ordinary mode switch still creates an isolated legacy run.
	for child in game.get_children():
		if child is Button and child.text.begins_with("切换格子版"):
			await click(child.get_global_rect().get_center())
			break
	game = current_scene
	check(game.get_script().resource_path=="res://scripts/escort_route.gd" and game.coins==3,"trial's legacy switch still restarts isolated ordinary mode")
	await press(KEY_SPACE)
	await press(KEY_1)
	check(not game.heroes[0].presentation.motion_sample_enabled,"legacy mode never adopts trial frames")
	await finish_trial()

func finish_trial() -> void:
	print("MONK_ANIMATION_TRIAL_INPUT failures=",failures)
	game.free()
	quit(1 if failures else 0)
