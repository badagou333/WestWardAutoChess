extends SceneTree
## Standalone so an absolute host script also runs against --main-pack.
## The source evidence is an external host file, never a bundled test resource.
const Config = preload("res://scripts/data/board_trial_config.gd")
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
const CLOCK_KEYS := ["pose","pose_time","animation_clock","attack_serial","attack_direction","facing","visual_alpha","dead","move_start","move_end","move_left","position","hit_pulse","hit_cooldown","impact_stop","landing","sample_walk_time","events"]
var failures := 0
var source_cases := {}
var evidence := []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func equal(a, b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<0.000000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not equal(a[index],b[index]): return false
		return true
	return a==b

func toggle_snapshot(game) -> Dictionary:
	var view=game._record("guard_monk").node.presentation
	var clocks := {}
	for key in CLOCK_KEYS:
		var value=view.get(key)
		clocks[key]=value.duplicate(true) if value is Dictionary else value
	var actors := []
	for actor in game.actors:
		actors.append({"id":actor.id,"cell":actor.cell,"hp":game._hp(actor),"dead":actor.dead,"move":actor.move.duplicate(true),"target":actor.target,"cooldown":actor.cooldown,"think":actor.think,"age":actor.step_age,"wait":actor.step_wait.duplicate(true),"retarget":actor.step_retarget})
	return {"report":game.report().duplicate(true),"actors":actors,"clocks":clocks,"strikes":game.combat.strikes.duplicate(true),"missiles":game.combat.missiles.duplicate(true),"elapsed":game.elapsed,"accumulator":game.accumulator,"deployment":game.deployment.duplicate(true)}

func toggle_check(game, enabled: bool, label: String) -> void:
	var view=game._record("guard_monk").node.presentation
	var before: Dictionary=toggle_snapshot(game)
	game.set_monk_sample(enabled)
	check(game._record("guard_monk").node.presentation==view and view.motion_sample_enabled==enabled,"legacy comparison API preserves installed directional adapter "+label)
	check(toggle_snapshot(game)==before,"pack display switch preserves every observed gameplay/playback clock "+label)

func natural(profile: String, formation: String, sampled: bool) -> void:
	var game=load("res://scenes/board_trial.tscn").instantiate()
	game.enemy_profile=profile
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	check(game.get_script().resource_path=="res://scripts/board_depth.gd","profile pack runs the actual main depth controller")
	var stage=game.get("stage")
	check(is_instance_valid(stage) and stage.get_script().resource_path=="res://scripts/presentation/board_depth_stage.gd" and stage.game==game and stage.get_parent()==game,"profile pack keeps the actual attached depth stage through roster rebuilds")
	check(is_equal_approx(game.BODY_SCALE,0.9) and game.actors.all(func(actor): return actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(actor.cell)+Vector2(0.5,0.5))) and actor.node.position==GroundProjection.center(actor.cell) and actor.node.position==game.display_center(actor.cell)),"profile pack has upright bodies at one projected foot/depth scale, not fixed scale across rows")
	var view=game._record("guard_monk").node.presentation
	check(view.get_script().resource_path=="res://scripts/presentation/board_directional_view.gd","pack instantiates actual board-only directional adapter")
	for actor in game.actors:
		check(actor.node.presentation.has_method("draw_sample") and actor.node.presentation.direction_pack.frames.size()==16,"pack actually enables every actor's sixteen directional poses: "+actor.id)
	var sample: Dictionary=view.draw_sample()
	check(view.direction_pack.frames.size()==16 and view.direction_pack.textures.size()==16 and sample.texture!=null and sample.region.has_area() and sample.frame==view.direction_frame(),"pack actually draws current sixteen-frame monk directional package, not retained legacy sample clock art")
	var monk: Dictionary=game._record("guard_monk")
	check(is_equal_approx(view.impact_delay(),0.235) and monk.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(monk.cell)+Vector2(0.5,0.5))) and view.foot_anchor==Vector2.ZERO,"pack retains actual contact time and foot origin with per-depth upright body size")
	check(game.actors.size()==(13 if profile=="bear" else 12) and game.actors.all(func(actor): return actor.walk==0.5 and actor.node.move_interval==0.5),"pack uses selected full roster and shared movement duration")
	toggle_check(game,sampled,"deployment")
	check(game.start_battle(),"pack starts actual profile formation "+profile+" "+formation)
	game.speed=2 if not sampled else 1
	var switched := false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/60)
		if not switched and game.elapsed>=0.25:
			toggle_check(game,not sampled,"in-flight battle")
			toggle_check(game,sampled,"in-flight restore")
			game.paused=true
			var paused: Dictionary=toggle_snapshot(game)
			game.step(3)
			check(toggle_snapshot(game)==paused,"pack pause freezes actual gameplay and sample clocks")
			toggle_check(game,not sampled,"paused")
			toggle_check(game,sampled,"paused restore")
			game.paused=false
			switched=true
	check(game.phase==game.Phase.RESULT and game.result_count==1 and switched,"pack complete real profile battle reaches one Result")
	var report: Dictionary=game.report().duplicate(true)
	var reference: Dictionary=source_cases[profile+"/"+formation]
	var matched: bool=equal(report,reference.report)
	check(matched,"entire actual pack report/attack times/HP matches source "+profile+" "+formation+" sampled="+str(sampled))
	toggle_check(game,not sampled,"result")
	toggle_check(game,sampled,"result restore")
	if profile=="bear":
		check(not report.metrics.attack_times.get("E7",[]).is_empty() and report.metrics.damage.get("E7",0)>0,"pack bear really engages and damages, not just a sprite")
		if report.victory:
			game.selected="E7"
			game._process(1.0) # Only real Result fade clocks, no further combat.
			await process_frame
			await process_frame
			check(not is_instance_valid(game._record("E7").node),"pack real bear fade actually frees dead enemy node")
			game.ui.refresh()
			check(game.ui.selected_hp.text.contains("0 / 280") and game.ui.info_label.text.contains("阵亡"),"dead E7 remains inspectable after its node is actually freed")
	var saved: Dictionary=game.start_deployment.duplicate(true)
	game.retry()
	check(game.enemy_profile==profile and game.monk_sample_enabled==sampled and game.deployment==saved and game.elapsed==0 and game.phase==game.Phase.DEPLOY,"pack retry retains profile/display/deployment and resets battle")
	check(game.actors.all(func(actor): return not actor.dead and actor.move.is_empty() and actor.target.is_empty() and actor.cooldown==0 and actor.step_completed==0),"pack retry restores all actual actors and clears activity")
	evidence.append({"profile":profile,"formation":formation,"sampled":sampled,"source_full_report_equal":matched,"victory":report.victory,"seconds":report.seconds,"tangseng_hp":report.tangseng_hp,"bear_actual_damage":report.metrics.damage.get("E7",0),"battle_pause_result_retry_switch_checked":true})
	print("BOARD_PROFILE_PACK ",profile," ",formation," sample=",sampled," source_equal=",matched," seconds=",report.seconds)
	game.free()

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var reference_path: String=ProjectSettings.globalize_path("res://tests/board-trial-runtime/board-balance-20261009-natural.json")
	var output_path: String="/tmp/board-perspective-profile-pack-20261017.json"
	for argument in args:
		if argument.begins_with("--reference="): reference_path=argument.trim_prefix("--reference=")
		elif argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
		elif not argument.begins_with("--"): reference_path=argument
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(reference_path)) if FileAccess.file_exists(reference_path) else null
	check(parsed is Dictionary and parsed.get("natural_runs",0)==24 and parsed.get("failures",-1)==0 and parsed.get("cases",[]).size()==12,"actual complete source comparison evidence must exist")
	if not parsed is Dictionary or parsed.get("cases",[]).size()!=12:
		quit(1)
		return
	for entry in parsed.cases: source_cases[entry.profile+"/"+entry.formation]=entry
	for profile in Config.ENEMY_PROFILES:
		for formation in ["A","B","C","R"]:
			for sampled in [true,false]: await natural(profile,formation,sampled)
	check(evidence.size()==24,"all source-vs-pack legacy-flag compatibility profile formations actually executed")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"pack runtime evidence opens")
	if file!=null: file.store_string(JSON.stringify({"source_evidence":reference_path,"directional_frames_per_role":16,"legacy_sample_flag_checked_for_state_compatibility_only":true,"profile_formations":12,"actual_runs":evidence.size(),"cases":evidence,"graphical_rendering_verified":false,"failures":failures},"\t"))
	print("BOARD_PROFILE_PACK runs=",evidence.size()," failures=",failures)
	quit(1 if failures else 0)
