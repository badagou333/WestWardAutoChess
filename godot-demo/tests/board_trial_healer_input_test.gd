extends "res://tests/board_trial_input_test.gd"
const BaseView = preload("res://scripts/presentation/character_presentation.gd")
const FixedView = preload("res://scripts/presentation/board_trial_healer_view.gd")
var samples := []
var release_samples := []

func capture(name: String) -> void:
	game._update_ui()
	game.queue_redraw()
	await frames()
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("/tmp/board-d004-20261007-"+name+".png")==OK,"actual healer evidence "+name)

func load_game() -> void:
	game = load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()

func source_compare() -> void:
	var plate := Node2D.new()
	plate.z_index = 3000
	plate.draw.connect(func(): plate.draw_rect(Rect2(0,0,1920,1080),Color("172a30")))
	game.add_child(plate)
	game.ui.label(Rect2(260,62,1400,58),32,plate).text = "同一药灵原待机帧 · 程序视口放大对照（非战斗画面）"
	for index in range(2):
		var view = BaseView.new() if index==0 else FixedView.new()
		view.setup_visual("herbal_spirit_child","nine_sols_v1")
		view.foot_anchor = Vector2.ZERO
		view.show_anchor = false
		view.show_status = false
		view.position = Vector2(620+index*680,805)
		view.scale = Vector2.ONE*3
		plate.add_child(view)
		game.ui.label(Rect2(340+index*680,160,600,70),28,plate).text = "旧显示：源图实际左向" if index==0 else "本入口：帧0镜像一次，朝右"
		game.ui.label(Rect2(340+index*680,886,600,46),24,plate).text = "同源头像，不翻" if index==0 else "同源头像，翻一次"
		game.ui.portrait(Rect2(540+index*680,865,100,112),plate).setup("herbal_spirit_child",index==1,true)
	check(signf(game._record("herbal_spirit_child").node.presentation.visual_transform().x.x)==-1,"actual idle correction not inferred from wrong shared tag")
	await capture("healer-source-compare")
	plate.free()

func healing(direction: int) -> void:
	await load_game()
	for actor in game.actors:
		if actor.id not in ["herbal_spirit_child","tangseng","E1"]:
			actor.node.take_damage(actor.hp_max)
			actor.dead = true
			actor.node.hide() # Explicit fixture isolation; not a natural full-roster battle.
	var healer: Dictionary = game._record("herbal_spirit_child")
	var core: Dictionary = game._record("tangseng")
	game._set_cell(healer,Vector2i(3,3))
	game._set_cell(core,Vector2i(3+direction,3))
	core.node.health = 100 # Explicit injury fixture, not natural A/B/C statistics.
	game._set_cell(game._record("E1"),Vector2i(11,6))
	for actor in [core,game._record("E1")]:
		actor.think = 100000.0
		actor.cooldown = 100000.0
	game.combat.projectile_released.connect(func(event):
		if event.source!=healer.node: return
		var expected: Vector2 = game.combat.to_local(event.view.get_parent().to_global(event.view.emission_position()))
		check(event.from.distance_to(expected)<0.000001 and signf(event.from.x-healer.node.position.x)==direction,"actual healing socket scales once and emits toward correct target side")
		release_samples.append({"side":direction,"frame":event.view.frame_index,"from":str(event.from),"foot":str(healer.node.position),"time":game.elapsed}))
	await click(game.start_button.get_global_rect().get_center())
	for actor in game.actors:
		if actor.id not in ["herbal_spirit_child","tangseng","E1"]: actor.node.hide()
	await press(KEY_5)
	var seen := {}
	var began := Time.get_ticks_msec()
	while seen.size()<3 and Time.get_ticks_msec()-began<6000:
		await process_frame
		var view = healer.node.presentation
		if view.pose!="basic_attack": continue
		var stage := ""
		if view.frame_index==0 and view.pose_time<0.078: stage = "起手"
		elif view.frame_index==2 and view.pose_time>=view.impact_delay(): stage = "接触"
		elif view.frame_index==0 and view.pose_time>0.57: stage = "收势"
		if stage.is_empty() or seen.has(stage): continue
		check(view.facing==direction and signf(view.visual_transform().x.x)==direction*(-1 if view.frame_index==0 else 1),"actual selected source frame determines one mirror in "+stage)
		check(healer.node.position==Config.center(healer.cell) and view.position==Vector2.ZERO and view.foot_anchor==Vector2.ZERO,"treatment never shifts root/local foot anchors")
		samples.append({"side":direction,"stage":stage,"frame":view.frame_index,"basis":view.visual_transform().x.x,"logical":view.facing,"time":game.elapsed,"hp":core.node.health})
		seen[stage] = true
		if stage=="接触": await capture("heal-right" if direction>0 else "heal-left")
	check(seen.size()==3 and release_samples.any(func(item): return item.side==direction),"normal production frames sample windup/contact/recovery and actual release")
	check(core.node.health>100 and game.metrics.healing.get("herbal_spirit_child",0)>0,"actual healing fixture applied real HP once per release")
	game.free()

func run() -> void:
	root.size = Vector2i(1280,720)
	await load_game()
	await source_compare()
	await click(game.roster_buttons[4].get_global_rect().get_center())
	check(game.ui.card_portraits[4].mirrored and game.ui.selected_portrait.mirrored,"actual idle source, both portrait locations flipped once")
	await capture("deploy-healer-right")
	await click(Config.center(Vector2i(0,6)))
	check(game._record("herbal_spirit_child").node.presentation.facing==1 and signf(game._record("herbal_spirit_child").node.presentation.visual_transform().x.x)==-1,"real redeploy restores actual visual right")
	await click(game.start_button.get_global_rect().get_center())
	await press(KEY_P)
	await click(game.retry_button.get_global_rect().get_center())
	check(game.phase==game.Phase.DEPLOY and game.ui.card_portraits[4].mirrored and signf(game._record("herbal_spirit_child").node.presentation.visual_transform().x.x)==-1,"native retry restores corrected idle body and portrait")
	game.free()
	await healing(1)
	await healing(-1)
	var file := FileAccess.open("/tmp/board-d004-healer-samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source_frames":{"0":"left_verified","1":"right_verified","2":"right_verified","3":"right_retained","4":"ambiguous_retained"},"samples":samples,"releases":release_samples,"failures":failures},"\t"))
	print("BOARD_TRIAL_HEALER_INPUT failures=",failures)
	quit(1 if failures else 0)
