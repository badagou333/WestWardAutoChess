extends "res://tests/monk_animation_trial_input_test.gd"
## Fixed-step engine review evidence, not real-time/OS video or a natural battle.
## Run with --write-movie <temp.avi> --fixed-fps 15 to prevent skipped draws.
## Normal production _process (no manual step/pose loop);
## a single purchased hero, hidden normal enemies, wounded HP and no wave spawns.
var capture_dir := ""
var samples: Array = []
var recording_done := false
var recording_started := 0
var simulation_started := 0.0
var phase := "待机"
var phase_label: Label
var monk
signal sample_saved
const SAMPLE_FPS := 15
const SAMPLE_COUNT := 180

func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	if not capture_dir.begins_with("/tmp/monk-runtime-review."):
		push_error("Supply a fresh /tmp/monk-runtime-review.* capture directory")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	game = load("res://scenes/monk_animation_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.audio_feedback.enabled = false
	await frames()
	await press(KEY_SPACE)
	await click(game.shop_buttons[0].get_global_rect().get_center())
	check(game.heroes.size()==1,"capture uses exactly one legally purchased monk")
	if game.heroes.size()!=1:
		await finish_capture()
		return
	monk = game.heroes[0]
	await click(monk.position)
	await click(game.escort.position+Vector2(50,-30))
	check(monk.board_row>=0,"capture deploys via complete input")
	await click(game.start_button.get_global_rect().get_center())
	game.intermission = 10000 # No unrelated wave actors obscure review silhouettes.
	var center := Map.center(Vector2i(3,8))
	await press(KEY_1)
	await click(center,MOUSE_BUTTON_RIGHT)
	var began := Time.get_ticks_msec()
	while game._brain(monk).mode=="手动" and Time.get_ticks_msec()-began < 15000: await process_frame
	check(monk.position.distance_to(center)<0.1,"review actor reaches open land by real root navigation, not teleportation")
	if failures:
		await finish_capture()
		return
	phase_label = game._make_label(Vector2(330,155),Vector2(1450,40),20,Color("fff2c8"),2095)
	recording_started = Time.get_ticks_msec()
	simulation_started = game.battle_elapsed
	capture_frames() # Same engine scene/clock, fixed step independent of PNG I/O.
	await until(1.0)
	phase = "向右行走（两循环以上）"
	check(game._command_free(monk,center+Vector2(150,0)),"right review command accepted")
	await until(2.4)
	check(game._brain(monk).mode=="驻守","right walk stops normally")
	phase = "停步"
	await until(2.9)
	phase = "转向左行（两循环以上）"
	check(game._command_free(monk,center-Vector2(150,0)),"left review command accepted")
	await until(5.4)
	check(game._brain(monk).mode=="驻守","left walk stops normally")
	phase = "停步 / 转向"
	await until(5.9)
	phase = "向右回到原位"
	check(game._command_free(monk,center),"return review command accepted")
	await until(7.3)
	check(game._brain(monk).mode=="驻守","return walk reaches real anchor")
	phase = "一次普攻 · 隐藏14HP测试靶"
	var target = hidden_enemy()
	target.health = monk.damage # Wounded target dies from one normal 14-damage attack.
	target.attack_cooldown = 10000
	var hits: int = game.combat.counts.hits
	await until(8.6)
	check((not is_instance_valid(target) or target.dead) and game.combat.counts.hits==hits+1,"normal AI attack applies one production damage event")
	phase = "非致命受击 · 隔离隐藏攻击源"
	game._establish_guard(monk,"") # Same cancel/guard path, no attack-speed override.
	var attacker = hidden_enemy()
	# Keep the real source/strike/presentation ticking, but do not expose this
	# one-shot diagnostic source to hero AI (which would suppress idle hit pose).
	game.enemies.erase(attacker)
	game.retiring.append(attacker)
	var hp: float = monk.health
	game.combat.request(attacker,monk)
	var hit_started: float = game.battle_elapsed
	while monk.health==hp and game.battle_elapsed-hit_started < 1.0: await process_frame
	check(monk.health==hp-attacker.damage and monk.presentation.pose=="hit","normal attack generates nonlethal drawn hit")
	clear_threats()
	await until(9.8)
	phase = "真实伤害致死 · 1HP伤员夹具"
	game._establish_guard(monk,"")
	monk.health = 1
	attacker = hidden_enemy()
	game.combat.request(attacker,monk)
	await until(10.9)
	check(monk.run_fallen and monk.presentation.visual_alpha==0,"normal damage triggers persistent death and one fade")
	phase = "阵亡保留，不回待机"
	while not recording_done: await process_frame
	var observed := {}
	var walk_right := {}
	var walk_left := {}
	for sample in samples:
		observed[sample.frame] = true
		if sample.pose=="move":
			if sample.facing>0: walk_right[sample.frame] = true
			else: walk_left[sample.frame] = true
	check([2,3,4,5].all(func(index): return walk_right.has(index) and walk_left.has(index)),"capture samples all four walk frames in both directions")
	check([6,7,8,9,10,11,12].all(func(index): return observed.has(index)),"capture includes windup, accelerate, contact, recovery, hit and both death frames")
	var report := {"kind":"actual_Godot_Viewport_fixed_step_sampling_not_realtime_or_OS_video","engine_fixed_fps":15,"sample_fps":SAMPLE_FPS,"playback_seconds":12,"simulation_started":simulation_started,"wall_elapsed_ms":Time.get_ticks_msec()-recording_started,"size":[1280,720],"samples":samples,"failures":failures,"fixtures":"one paid monk; hidden normal enemy nodes; nonlethal source isolated from hero AI target list but production strike/visual ticking retained; 14HP target/1HP monk; wave delay only; production damage/interval/root navigation unchanged"}
	var file := FileAccess.open(capture_dir+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	await finish_capture()

func until(seconds: float) -> void:
	while game.battle_elapsed-simulation_started < seconds: await process_frame

func hidden_enemy():
	game._spawn_enemy("boar",Map.ROUTE[0])
	var enemy = game.enemies.back()
	enemy.position = monk.position+Vector2(58,24)
	check(game.space.valid(enemy.position) and game._in_range(enemy,monk),"hidden combat actor has real legal range and sight")
	enemy.visible = false # Visibility only, no synthetic pose or damage event.
	return enemy

func clear_threats() -> void:
	for enemy in game.enemies: enemy.queue_free()
	for enemy in game.retiring: enemy.queue_free()
	game.enemies.clear()
	game.retiring.clear()
	game.combat.clear()

func capture_frames() -> void:
	for index in range(SAMPLE_COUNT):
		await until(float(index)/SAMPLE_FPS)
		phase_label.text = "引擎固定步长 · 采样15fps · 隐藏靶夹具 · 非实时录像 · %.2fs · %s" % [game.battle_elapsed-simulation_started,phase]
		call_deferred("save_sample",index)
		await sample_saved
	recording_done = true

func save_sample(index: int) -> void:
	# Force a real draw after scene processing: frame_post_draw alone may skip
	# while macOS suppresses ordinary redraws. No simulation or pose is advanced.
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(capture_dir+"/frame-%03d.png" % index)==OK,"save raw viewport sample")
	var view = monk.presentation
	samples.append({"index":index,"wall_ms":Time.get_ticks_msec()-recording_started,"simulation_time":game.battle_elapsed,"phase":phase,"pose":view.pose,"pose_time":view.pose_time,"frame":view.frame_index,"facing":view.facing,"hp":monk.health,"serial":view.attack_serial,"position":[monk.position.x,monk.position.y]})
	sample_saved.emit()

func finish_capture() -> void:
	print("MONK_RUNTIME_CAPTURE failures=",failures," samples=",samples.size()," directory=",capture_dir)
	game.free()
	quit(1 if failures else 0)
