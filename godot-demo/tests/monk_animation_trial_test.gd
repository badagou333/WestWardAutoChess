extends "res://tests/run_casualties_test.gd"
const View = preload("res://scripts/presentation/character_presentation.gd")

func fresh():
	var trial = load("res://scenes/monk_animation_trial.tscn").instantiate()
	root.add_child(trial)
	trial.set_process(false)
	trial.audio_feedback.enabled = false
	return trial

func run() -> void:
	player_tracks()
	var original := attack_run(false,30,1.0)
	for sample in [attack_run(true,30,1.0),attack_run(true,120,2.0)]:
		check(sample==original,"sample and production attacks have identical clocks/damage/serials at 1x/2x")
	switch_in_attack()
	recovery_and_capacity() # Real combat loss, all camps, new capacity and new run.
	legacy_recovery()
	var run_result := battle(60,1.0,true)
	check(is_equal_approx(run_result.hp,271.2) and is_equal_approx(run_result.time,101.73333333336) and run_result.loot==20,"sample's complete four-stage run retains production outcome and economy")
	print("MONK_ANIMATION_TRIAL failures=",failures)
	quit(1 if failures else 0)

func player_tracks() -> void:
	var view = View.new()
	view.setup_visual("guard_monk","nine_sols_v1")
	root.add_child(view)
	view.foot_anchor = Vector2.ZERO
	var original_body = view.body
	check(view.set_motion_sample(true) and view.motion_body==null and not view.use_motion_frames,"explicit sample does not load old-skin motion packs")
	check(view.sample_body.get_size()==Vector2(3328,256),"sample atlas has thirteen 256 frames")
	for key in [[0.0,0],[0.55,1],[0.90,0],[1.45,0]]:
		view.pose_time = key[0]
		view.update_frame()
		check(view.frame_index==key[1],"idle per-frame timing %s" % str(key))
	view.move_to(Vector2.ZERO)
	for cycle in range(3):
		for frame in range(4):
			view.sample_walk_time = cycle*0.5+frame*0.125+0.001
			view.update_frame()
			check(view.frame_index==frame+2,"four drawn walk phases without root displacement")
		view.move_left = 0
		view.update_frame()
		var phase: float = view.sample_walk_time
		view.move_to(Vector2.ZERO)
		check(view.sample_walk_time==phase,"segment restart preserves continuous gait phase")
	view.play_attack()
	var serial: int = view.attack_serial
	for key in [[0.0,6],[0.156,7],[0.235,8],[0.348,9],[0.516,0]]:
		view.pose_time = key[0]
		view.update_frame()
		check(view.frame_index==key[1] and view.attack_serial==serial,"attack track never emits another serial %s" % str(key))
		for facing in [-1.0,1.0]:
			view.facing = facing
			var transform = view.visual_transform()
			check(transform.origin==Vector2.ZERO and transform.x==Vector2(facing,0) and transform.y==Vector2.DOWN and view.ground_offset()==Vector2.ZERO,"sample is anchored and mirrored, not procedurally lunging")
	view.facing = -1
	check(view.emission_position()==Vector2(-71,-65),"candidate contact socket mirrors around shared foot anchor")
	view.reset_visual()
	view.play_hit()
	check(view.frame_index==10,"idle hit enters drawn hit frame")
	view.pose_time = 0.121
	view.update_frame()
	check(view.frame_index==0,"hit recovers to baseline without another attack")
	view.reset_visual()
	view.play_attack()
	serial = view.attack_serial
	view.play_hit()
	check(view.pose=="basic_attack" and view.attack_serial==serial,"hit during attack flashes without restarting attack")
	view.play_retreat()
	check(view.frame_index==11,"death begins at collapse frame")
	view.pose_time = 0.161
	view.update_frame()
	check(view.frame_index==12,"death ends at drawn low resting frame")
	view.pose_time = 0.50
	view.update_frame()
	check(is_equal_approx(view.visual_alpha,0.5),"terminal death frame fades once")
	view.pose_time = 2
	view.update_frame()
	view.set_motion_sample(false)
	check(view.dead and view.pose=="retreat" and view.visual_alpha==0 and view.body==original_body,"switch back retains death and production resource")
	view.set_motion_sample(true)
	view.play_attack()
	check(view.pose=="retreat" and view.visual_alpha==0,"dead visual cannot return to standing on switch")
	view.reset_visual()
	check(view.pose=="idle" and view.frame_index==0 and view.sample_walk_time==0,"explicit new actor lifecycle resets animation phase")
	view.free()
	var other = View.new()
	other.setup_visual("wild_hunter","nine_sols_v1")
	check(not other.set_motion_sample(true) and not other.motion_sample_enabled,"adapter cannot opt in another role")
	other.free()

func combat_fixture(enabled: bool):
	var trial = fresh()
	trial.set_monk_sample(enabled)
	trial._on_shop_pressed(0)
	var monk = trial.heroes[0]
	check(trial._place_free(monk,trial.escort.position+Vector2(50,-30)),"trial deploys a paid monk")
	quiet(trial)
	trial._spawn_enemy("boar",Map.ROUTE[0])
	var target = trial.enemies[0]
	target.position = trial._near_free(monk.position+Vector2(45,0),target,60)
	check(target.position!=Vector2.INF and trial._in_range(monk,target),"attack fixture has valid land and line of sight")
	target.health = 100000
	target.max_health = 100000
	target.damage = 0
	target.move_interval = 100000
	return trial

func attack_run(enabled: bool, fps: int, speed: float) -> Dictionary:
	var trial = combat_fixture(enabled)
	trial.battle_speed = speed
	for frame in range(int(8*fps/speed)): trial.step(1.0/fps)
	var result := {"hp":trial.enemies[0].health,"attacks":trial.combat.counts.attacks,"hits":trial.combat.counts.hits,"serial":trial.heroes[0].presentation.attack_serial,"time":trial.battle_elapsed,"coins":trial.coins}
	print("MONK_TIMING sample=",enabled," fps=",fps," speed=",speed," ",result)
	trial.free()
	return result

func switch_in_attack() -> void:
	var trial = combat_fixture(true)
	var hero = trial.heroes[0]
	var enemy = trial.enemies[0]
	trial._process_heroes(0)
	check(hero.presentation.pose=="basic_attack","real attack started before toggle")
	for i in range(18): trial._tick(1.0/120)
	var time: float = hero.presentation.pose_time
	var serial: int = hero.presentation.attack_serial
	var hp: float = enemy.health
	var coins: int = trial.coins
	var at: Vector2 = hero.position
	trial.set_monk_sample(false)
	trial.set_monk_sample(true)
	check(hero.presentation.pose_time==time and hero.presentation.attack_serial==serial and enemy.health==hp and hero.position==at and trial.coins==coins,"windup toggle preserves clocks, serial, root and economy")
	while hero.presentation.pose_time < hero.presentation.impact_delay(): trial._tick(1.0/120)
	check(hero.presentation.frame_index==8 and enemy.health==hp-hero.damage,"contact frame and original combat event apply exactly one hit")
	trial.set_monk_sample(false)
	trial.set_monk_sample(true)
	for i in range(20): trial._tick(1.0/120)
	check(enemy.health==hp-hero.damage,"switch after contact cannot apply duplicate hit")
	trial.battle_paused = true
	time = hero.presentation.pose_time
	trial.step(3)
	check(hero.presentation.pose_time==time,"paused sample does not advance")
	trial.free()
