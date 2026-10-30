extends "res://tests/board_trial_ai_test.gd"
## D003: legacy enemy profile is explicit. Isolated activity fixtures are not
## new seven-enemy balance evidence; natural on/off runs never override brains.
const MonkView = preload("res://scripts/presentation/board_trial_monk_view.gd")
const SharedView = preload("res://scripts/presentation/character_presentation.gd")
const Motion = preload("res://scripts/presentation/motion.gd")
var sample_evidence := []
var natural_evidence := []

class ActivityGame extends "res://scripts/board_trial.gd":
	var driven_ids := []
	func _brain(actor: Dictionary, delta: float) -> void:
		if actor.id in driven_ids: super._brain(actor,delta)
		# Only labelled activity fixtures hold the other brains.

func fresh():
	var game=load("res://scripts/board_trial.gd").new()
	check(game.get_script().resource_path=="res://scripts/board_trial.gd","historical monk sample geometry explicitly uses the rectangular 0.72 legacy controller")
	game.enemy_profile="legacy"
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func activity(enabled: bool):
	var game=ActivityGame.new()
	game.enemy_profile="legacy"
	game.monk_sample_enabled=enabled
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	check(game.start_battle(),"isolated monk activity starts with original six enemies")
	isolate(game,["tangseng","guard_monk","E1"])
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	game._set_cell(game._record("guard_monk"),Vector2i(3,3))
	game._set_cell(game._record("E1"),Vector2i(4,3))
	return game

func visual_state(view) -> Dictionary:
	var values := {}
	for key in MonkView.PLAYBACK_KEYS:
		var value=view.get(key)
		values[key]=value.duplicate(true) if value is Dictionary else value
	return values

func state(game) -> Dictionary:
	var actors := []
	for actor in game.actors:
		var value: Dictionary=actor.duplicate(true)
		value.erase("node")
		value.root=actor.node.position
		value.hp=game._hp(actor)
		value.visual=visual_state(actor.node.presentation)
		actors.append(value)
	var pending := []
	for strike in game.combat.strikes:
		pending.append({"serial":strike.serial,"time":strike.time,"amount":strike.amount,"source":strike.source.get_instance_id(),"target":strike.target.get_instance_id()})
	return {"report":game.report().duplicate(true),"actors":actors,"pending":pending,"combat_counts":game.combat.counts.duplicate(true),
		"missiles":game.combat.missiles.duplicate(true),"marks":game.combat.marks.duplicate(true),"phase":game.phase,
		"paused":game.paused,"speed":game.speed,"accumulator":game.accumulator,"deployment":game.deployment.duplicate(true),
		"selected":game.selected,"pointer_drag":game.pointer_drag,"pointer_origin":game.pointer_origin}

func toggle_unchanged(game, label: String) -> void:
	var before:=state(game)
	game.set_monk_sample(false)
	check(not game._record("guard_monk").node.presentation.motion_sample_enabled and state(game)==before,"sample off preserves all activity/AI/HP/clocks "+label)
	game.set_monk_sample(true)
	check(game._record("guard_monk").node.presentation.motion_sample_enabled and state(game)==before,"sample on preserves all activity/AI/HP/clocks "+label)

func sample_metadata_and_scope() -> void:
	var game=fresh()
	var monk: Dictionary=game._record("guard_monk")
	var view=monk.node.presentation
	check(view.get_script()==MonkView and view.motion_sample_enabled,"new board monk defaults to its local sample adapter")
	check(view.foot_anchor==Vector2.ZERO and monk.node.scale==Vector2.ONE*0.72,"board foot origin and actual actor scale stay unchanged")
	check(view.sample_body.get_size()==Vector2(3328,256) and view.sample_track.manifest.frames.size()==13,"existing thirteen-frame atlas loads without repacking")
	var anchor: Array=view.sample_track.manifest.frame.foot_anchor
	check(int(anchor[0])==128 and int(anchor[1])==218 and view.sample_track.manifest.source_facing=="right","existing source orientation and frame foot anchor remain authoritative")
	check(is_equal_approx(view.impact_delay(),0.235) and is_equal_approx(Motion.duration(view.motion),0.54),"candidate uses original release and attack lifecycle duration")
	var old_body=view.body
	toggle_unchanged(game,"deployment")
	game.set_monk_sample(false)
	check(view.body==old_body and not view.motion_sample_enabled and view.get_script()==MonkView,"legacy display restores the existing body through the same local adapter")
	for actor in game.actors:
		if actor.id!="guard_monk": check(not actor.node.presentation.motion_sample_enabled,"no other role is opted into the monk sample")
	game.load_formation("C")
	check(not game._record("guard_monk").node.presentation.motion_sample_enabled,"formation rebuild preserves sample-off option")
	game.set_monk_sample(true)
	check(game.start_battle(),"metadata lifecycle starts")
	game.retry()
	check(game._record("guard_monk").node.presentation.motion_sample_enabled and game._record("guard_monk").node.presentation.sample_walk_time==0,"retry creates a fresh sampled actor and resets only its new lifecycle")
	monk=game._record("guard_monk")
	view=monk.node.presentation
	var old_mode=SharedView.new()
	old_mode.setup_visual("guard_monk","nine_sols_v1")
	check(not old_mode.motion_sample_enabled and old_mode.get_script()==SharedView,"legacy shared presentation does not acquire the board adaptation")
	old_mode.free()
	sample_evidence.append({"kind":"metadata_scope_lifecycle","profile":"legacy","frames":13,"release":view.impact_delay(),"duration":0.54})
	game.free()

func walking(flipped: bool) -> void:
	var game=activity(true)
	var monk: Dictionary=game._record("guard_monk")
	var target: Dictionary=game._record("E1")
	game._set_cell(target,Vector2i(3,4))
	var from := Vector2i(3,3)
	var to := Vector2i(2,3) if flipped else Vector2i(4,3)
	var end := Vector2i(1,3) if flipped else Vector2i(5,3)
	check(game._move(monk,to),"board issues actual sample walk segment")
	# This is a real incoming melee event during the moving segment, not a
	# synthetic change of impact_stop or a mutation of the gait timer.
	game._attack(target,monk)
	var expected_hp: float=monk.hp_max-target.damage
	for tick in range(30):
		game.step(Config.STEP)
		ownership(game)
	var view=monk.node.presentation
	check(game._hp(monk)==expected_hp and view.hit_pulse>0,"actual incoming event hits while the root is walking")
	check(is_equal_approx(view.sample_walk_time,0.25) and view.frame_index==4,"walk foot phase follows actual halfway progress despite shared impact stop")
	check(monk.node.position.distance_to(Config.center(from).lerp(Config.center(to),0.5))<0.000001 and view.position==Vector2.ZERO,"sample does not add root translation on top of board interpolation")
	var facing: float=-1.0 if flipped else 1.0
	var matrix: Transform2D=view.visual_transform()
	check(matrix.origin==Vector2.ZERO and matrix.x==Vector2(facing,0) and matrix.y==Vector2.DOWN and view.ground_offset()==Vector2.ZERO,"sample walking has one logical mirror and no old bob/lean/reach")
	toggle_unchanged(game,"mid-walk and hitstop")
	game.paused=true
	var held:=state(game)
	game.step(2)
	check(state(game)==held,"pause freezes actual sampled segment and all presentation clocks")
	toggle_unchanged(game,"paused walk")
	game.paused=false
	for tick in range(30): game.step(Config.STEP)
	check(monk.cell==to and monk.move.is_empty() and is_equal_approx(view.sample_walk_time,0.5) and view.frame_index in [0,1],"real landing stops drawn walking at the cell rather than completing hitstop-delayed visual travel")
	check(game._move(monk,end),"second real board segment starts")
	check(is_equal_approx(view.sample_walk_time,0.5) and view.frame_index==2,"new segment preserves continuous previous half-second gait phase")
	for tick in range(15): game.step(Config.STEP)
	check(is_equal_approx(view.sample_walk_time,0.625) and view.frame_index==3,"second segment advances the existing cycle rather than resets it")
	toggle_unchanged(game,"second moving segment")
	sample_evidence.append({"kind":"isolated_real_walk_and_incoming_hit","mirrored":flipped,"half_time":0.25,"continuous_time":view.sample_walk_time,"hp":game._hp(monk),"root":str(monk.node.position)})
	game.free()

func first_contact_and_toggle(flipped: bool) -> void:
	var game=activity(true)
	var monk: Dictionary=game._record("guard_monk")
	var target: Dictionary=game._record("E1")
	game._set_cell(target,Vector2i(2,3) if flipped else Vector2i(4,3))
	var hp: float=game._hp(target)
	game._attack(monk,target)
	var view=monk.node.presentation
	var serial: int=view.attack_serial
	for tick in range(12): game.step(Config.STEP)
	toggle_unchanged(game,"actual attack windup")
	check(view.attack_serial==serial and game._hp(target)==hp,"windup switches do not release damage or a new serial")
	for tick in range(16): game.step(Config.STEP)
	check(view.pose_time<0.235 and game._hp(target)==hp,"actual shared event waits for the unchanged release threshold")
	game.step(Config.STEP)
	check(view.frame_index==8 and game._hp(target)==hp-monk.damage and view.attack_serial==serial,"real original release applies exactly one hit on candidate contact frame")
	var facing: float=-1.0 if flipped else 1.0
	check(view.visual_transform().origin==Vector2.ZERO and view.visual_transform().x==Vector2(facing,0) and view.ground_offset()==Vector2.ZERO,"attack sample removes old wholebody lunge and mirrors only once")
	check(view.emission_position()==Vector2(71*facing,-65),"candidate contact socket is source-foot-relative and logically mirrored")
	var global_contact: Vector2=view.to_global(Vector2(71*facing,-65))
	check(global_contact.distance_to(monk.node.global_position+Vector2(71*facing,-65)*0.72)<0.000001,"actual scaled board contact transforms from the same fixed foot origin")
	toggle_unchanged(game,"contact and source/target impact stop")
	game.paused=true
	var held:=state(game)
	game.step(3)
	check(state(game)==held,"paused contact does not advance sample, damage or impact stop")
	game.paused=false
	for tick in range(50): game.step(Config.STEP)
	check(game._hp(target)==hp-monk.damage and view.attack_serial==serial and game.metrics.attack_times.guard_monk.size()==1,"contact/recovery switching cannot duplicate hit or attack request")
	sample_evidence.append({"kind":"isolated_shared_attack_event","mirrored":flipped,"release_threshold":0.235,"first_contact_step":29,"serial":serial,"damage":hp-game._hp(target)})
	game.free()

func hit_death_and_result() -> void:
	var game=activity(true)
	var monk: Dictionary=game._record("guard_monk")
	var view=monk.node.presentation
	monk.node.take_damage(1)
	check(view.pose=="hit" and view.frame_index==10,"idle damage uses the existing drawn hit frame")
	toggle_unchanged(game,"actual hit activity")
	for tick in range(22): game.step(Config.STEP)
	check(view.pose=="idle" and view.frame_index in [0,1],"existing hit duration recovers without a new attack")
	monk.node.take_damage(monk.hp_max)
	check(view.dead and view.pose=="retreat" and view.frame_index==11,"real gameplay death begins candidate collapse without standing reset")
	toggle_unchanged(game,"real death start")
	for tick in range(20): game.step(Config.STEP)
	check(view.frame_index==12 and monk.dead,"real dead rest is used after collapse")
	game._record("tangseng").node.take_damage(10000)
	game.step(Config.STEP)
	check(game.phase==game.Phase.RESULT and not game.victory,"result fixture reaches actual failure without overriding settlement")
	var report: Dictionary=game.report().duplicate(true)
	game._process(0.8)
	check(game.report()==report and view.visual_alpha==0 and view.dead,"result-only fade changes display, never battle clock/HP/report")
	toggle_unchanged(game,"finished result fade")
	check(view.frame_index==12 and view.visual_alpha==0 and view.dead,"switching a terminal body cannot revive or re-fade it")
	game.retry()
	monk=game._record("guard_monk")
	check(game._alive(monk) and monk.node.presentation.motion_sample_enabled and monk.node.presentation.pose=="idle" and monk.node.presentation.sample_walk_time==0 and monk.node.presentation.attack_serial==0,"retry rebuilds a fresh alive sampled actor with cleared visual lifecycle")
	sample_evidence.append({"kind":"real_hit_death_failure_fade_retry","profile":"legacy","visual_only_result_fade":true})
	game.free()

func natural_sample(key: String, enabled: bool, fps: int, sim_speed: int, switches: bool, profile := "legacy") -> Dictionary:
	var game=fresh()
	check(game.set_enemy_profile(profile),"animation comparison selects its explicit enemy profile")
	game.set_monk_sample(enabled)
	game.load_formation(key)
	check(game.start_battle(),"natural animation comparison starts "+key)
	game.speed=sim_speed
	var switched := false
	while game.phase==game.Phase.BATTLE and game.elapsed<120:
		game.step(1.0/fps)
		ownership(game)
		if switches and not switched and game.elapsed>=1.0:
			toggle_unchanged(game,"natural "+key)
			game.paused=true
			var held:=state(game)
			game.step(3)
			check(state(game)==held,"natural sampled battle pause freezes all state "+key)
			game.paused=false
			switched=true
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural on/off "+profile+" battle reaches one real result "+key)
	game.free()
	return report

func run() -> void:
	sample_metadata_and_scope()
	for flipped in [false,true]:
		walking(flipped)
		first_contact_and_toggle(flipped)
	hit_death_and_result()
	for profile in Config.ENEMY_PROFILES:
		for key in ["A","B","C"]:
			var old:=natural_sample(key,false,30,1,false,profile)
			var sampled:=natural_sample(key,true,30,1,false,profile)
			var repeated:=natural_sample(key,true,120,2,true,profile)
			check(old==sampled and old==repeated,"full natural report/metrics/attack times are identical off/on/FPS/2x/toggle/pause "+profile+" "+key)
			natural_evidence.append({"formation":key,"enemy_profile":profile,"report":sampled,"off_on_repeat_equal":old==sampled and old==repeated})
	check(sample_evidence.size()==6 and natural_evidence.size()==9,"all six sample activity fixtures and all nine profile/formation comparisons completed")
	var file:=FileAccess.open("/tmp/board-monk-sample-20261009.json",FileAccess.WRITE)
	check(file!=null,"independent board monk sample evidence opens")
	if file!=null: file.store_string(JSON.stringify({"activity_enemy_profile":"legacy","natural_enemy_profiles":Config.ENEMY_PROFILES,"candidate_frames":13,"activity_fixtures":sample_evidence,"natural":natural_evidence,
		"known_visual_P3_closed":false,"failures":failures},"\t"))
	print("BOARD_MONK_SAMPLE activity=",sample_evidence.size()," natural=",natural_evidence.size()," failures=",failures)
	quit(1 if failures else 0)
