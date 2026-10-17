extends SceneTree
## Actual main scene / legacy simulation / fixed historical report parity.
## Run headless. Cue signals prove scheduling only, not audible output or GUI QA.
const Config = preload("res://scripts/data/board_trial_config.gd")
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
const DISABLED := ["rat_death","boar_death","wolf_death","bear_lord_death","victory"]
const ALLOWED := ["guard_monk_attack","wild_hunter_attack","sparrow_spirit_attack","herbal_spirit_child_attack","foxfire_imp_attack","rat_attack","boar_attack","wolf_attack","bear_lord_attack","tangseng_hurt_warning"]
const IMAGE := "res://art/boards/perspective_stage_v1/scene-clean.png"
var failures := 0
var checks := 0
var naturals := []
var baselines := {}
var source_rows := {}
var baseline_path := "res://tests/board-trial-runtime/board-balance-20261009-natural.json"
var source_path := ""
var output_path := "/tmp/board-perspective-20261017-runtime-source.json"

class RecordingAudio extends "res://scripts/presentation/board_trial_audio.gd":
	var host
	var actual_load_attempts: Array[String]=[]
	var cue_requests: Array=[]
	var role_events: Array=[]
	func _load_cue(key: String, path: String) -> void:
		actual_load_attempts.append(key)
		super._load_cue(key,path)
	func play_cue(key: String, target_id := 0) -> bool:
		cue_requests.append({"time":host.elapsed,"key":key})
		return super.play_cue(key,target_id)
	func _role_event(event: Dictionary, trigger: String) -> void:
		var role: String=str(event.get("source_key",""))
		if role_rules.has(role) and role_rules[role].recommended_trigger==trigger:
			var source: Dictionary=host._by_node(event.get("source"))
			var recipient: Dictionary=host._by_node(event.get("target"))
			role_events.append({"time":host.elapsed,"source":source.get("id",""),"target":recipient.get("id",""),"serial":event.get("serial",0),"role":role,"trigger":trigger,"key":role_rules[role].event_key})
		super._role_event(event,trigger)

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func equal_value(a, b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<0.000000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal_value(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not equal_value(a[index],b[index]): return false
		return true
	return a==b

func initialized(sound, label: String) -> void:
	check(sound.PROFILE=="board-selected-noncommercial-20261010",label+" retains the selected noncommercial sound profile")
	check(sound.loaded_keys.size()==10 and sound.streams.size()==10 and sound.stream_paths.size()==10,label+" actually initializes ten event keys")
	var paths: Dictionary={}
	for key in sound.loaded_keys:
		check(key in ALLOWED and sound.streams.get(key)!=null,label+" loads an approved non-null stream "+key)
		paths[sound.stream_paths.get(key,"")]=true
	check(paths.size()==9 and sound.role_rules.size()==9 and sound.secondary_cues.size()==1,label+" uses nine resources for nine primary behaviors and the retained warning")
	for key in DISABLED:
		check(key not in sound.loaded_keys and not sound.streams.has(key) and not sound.stream_paths.has(key),label+" never initializes disabled cue "+key)
	check(sound.loaded_keys.all(func(key): return key in ALLOWED) and sound.rejected_keys.is_empty(),label+" contains no extra UI/material/death/result sound or rejected initialization request")

func fresh(depth: bool):
	var game=load("res://scenes/board_trial.tscn" if depth else "res://scenes/board_trial_legacy.tscn").instantiate()
	game.enemy_profile="bear"
	root.add_child(game)
	game.set_process(false)
	initialized(game.audio_feedback,"actual scene initializer")
	var previous=game.audio_feedback
	game.combat.projectile_released.disconnect(previous.released)
	previous.free()
	var sound=RecordingAudio.new()
	sound.host=game
	game.audio_feedback=sound
	game.add_child(sound)
	game.combat.projectile_released.connect(sound.released)
	initialized(sound,"independent recording initializer")
	check(sound.actual_load_attempts==sound.loaded_keys,"recording intercepts all actual stream load attempts, not a static manifest count")
	check(game.get_script().resource_path==("res://scripts/board_depth.gd" if depth else "res://scripts/board_trial.gd"),"test instantiates the real requested scene controller")
	return game

func event_row(game, event: Dictionary) -> Dictionary:
	var source: Dictionary=game._by_node(event.source)
	var target: Dictionary=game._by_node(event.target)
	return {"time":game.elapsed,"source":source.get("id",""),"target":target.get("id",""),"source_key":event.get("source_key",""),"serial":event.get("serial",0),"amount":event.get("amount",0),"healing":event.get("healing",false),"projectile":event.has("texture")}

func natural(depth: bool, formation: String, fps: int, sim_speed: int, pause_once: bool) -> Dictionary:
	var game=fresh(depth)
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	var released: Array=[]
	var applied: Array=[]
	var scheduled: Array=[]
	game.combat.projectile_released.connect(func(event): released.append(event_row(game,event)))
	game.combat.resolved.connect(func(_target,_amount,_healing,event): applied.append(event_row(game,event)))
	game.audio_feedback.cue_played.connect(func(key): scheduled.append({"time":game.elapsed,"key":key}))
	check(game.start_battle() and game.actors.size()==13,"natural actual full thirteen-actor bear battle starts "+formation)
	check(game.actors.all(func(actor): return actor.walk==0.5 and actor.node.move_interval==0.5),"every actor retains the original half-second movement setting")
	if depth:
		check(is_instance_valid(game.stage) and game.stage.get_parent()==game,"real scene owns its actual stage, not an offline composition")
		check(game.actors.all(func(actor): return actor.node.presentation.has_method("draw_sample") and actor.node.presentation.direction_pack.frames.size()==16),"all thirteen actual instances keep the existing ten-role directional artwork adapters")
		check(game.actors.all(func(actor): return actor.node.scale.is_equal_approx(Vector2.ONE*game.BODY_SCALE*GroundProjection.depth_scale(Vector2(actor.cell)+Vector2(0.5,0.5)))),"all actual initial bodies adopt their own projective row scale")
	game.speed=sim_speed
	var did_pause:=false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/fps)
		if pause_once and not did_pause and game.elapsed>=1:
			game.toggle_pause()
			var before: Dictionary=game.report().duplicate(true)
			var cue_before: Array=game.audio_feedback.role_events.duplicate(true)
			var warning_before: Array=game.audio_feedback.cue_requests.duplicate(true)
			var release_count: int=released.size()
			var apply_count: int=applied.size()
			var scheduled_count: int=scheduled.size()
			var visuals: Array=[]
			for actor in game.actors: visuals.append({"position":actor.node.position,"scale":actor.node.scale,"order":actor.node.z_index})
			game.step(3)
			check(game.report()==before and game.audio_feedback.role_events==cue_before and game.audio_feedback.cue_requests==warning_before and released.size()==release_count and applied.size()==apply_count and scheduled.size()==scheduled_count,"pause advances no battle, launch, impact, warning or primary sound event")
			for index in game.actors.size():
				var node=game.actors[index].node
				check(node.position==visuals[index].position and node.scale==visuals[index].scale and node.z_index==visuals[index].order,"pause freezes each actual foot/scale/order "+game.actors[index].id)
			game.toggle_pause()
			did_pause=true
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural battle reaches one genuine Result, never a timeout substitute "+formation)
	check(equal_value(report,baselines[formation]),"entire actual report/parameters/HP/damage/healing/all attack timestamps equals fixed historical bear baseline "+formation)
	check(not released.is_empty() and not applied.is_empty() and not game.audio_feedback.role_events.is_empty() and not scheduled.is_empty(),"actual natural simulation executes releases, contacts and retained sound scheduling "+formation)
	check(game.audio_feedback.actual_load_attempts==game.audio_feedback.loaded_keys and game.audio_feedback.actual_load_attempts.all(func(key): return key in ALLOWED),"all real natural loads remain exactly the approved ten keys")
	check(game.audio_feedback.cue_requests.all(func(row): return row.key=="tangseng_hurt_warning") and game.audio_feedback.rejected_keys.is_empty(),"natural damage/death/result never requests any of the five disabled cues or replacement result/material sound")
	check(scheduled.all(func(row): return row.key in ALLOWED) and game.audio_feedback.voices.all(func(player): return is_equal_approx(player.pitch_scale,1.0)),"actual retained scheduling uses approved sounds at original pitch")
	check(game.audio_feedback.stats.requested==game.audio_feedback.role_events.size(),"semantic recorder observes every actual primary event request")
	var trace: Dictionary={"attack_times":report.metrics.attack_times.duplicate(true),"projectile_releases":released.duplicate(true),"applied_contacts":applied.duplicate(true),"primary_audio_events":game.audio_feedback.role_events.duplicate(true),"secondary_cue_requests":game.audio_feedback.cue_requests.duplicate(true)}
	var result: Dictionary={"depth":depth,"formation":formation,"fps":fps,"speed":sim_speed,"paused":did_pause,"report":report,"fixed_full_report_equal":equal_value(report,baselines[formation]),"trace":trace,"actual_load_attempts":game.audio_feedback.actual_load_attempts.duplicate(),"unique_resources":9,"disabled_loads":0,"disabled_requests":0,"disabled_scheduled":0,"scheduled":scheduled.duplicate(true),"primary_stats":game.audio_feedback.stats.duplicate(true)}
	var initial_requests: Array=game.audio_feedback.cue_requests.duplicate(true)
	var initial_role_events: Array=game.audio_feedback.role_events.duplicate(true)
	var scheduled_count: int=scheduled.size()
	game.step(3)
	check(game.report()==report and game.audio_feedback.cue_requests==initial_requests and game.audio_feedback.role_events==initial_role_events and scheduled.size()==scheduled_count,"Result neither advances simulation nor schedules death/result catch-up")
	var setup: Dictionary=game.start_deployment.duplicate(true)
	game.retry()
	check(game.phase==game.Phase.DEPLOY and game.elapsed==0 and game.deployment==setup and game.actors.size()==13,"retry restores the exact original full configuration")
	check(game.audio_feedback.seen.is_empty() and game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"retry clears pending attack, projectile and primary event state")
	game.free()
	return result

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="): baseline_path=argument.trim_prefix("--baseline=")
		elif argument.begins_with("--source="): source_path=argument.trim_prefix("--source=")
		elif argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(baseline_path)) if FileAccess.file_exists(baseline_path) else null
	check(parsed is Dictionary and parsed.get("failures",-1)==0,"fixed committed historical complete-report baseline loads")
	if not parsed is Dictionary:
		quit(1)
		return
	for row in parsed.get("cases",[]):
		if row.profile=="bear" and row.formation in ["A","R","B"]: baselines[row.formation]=row.report
	check(baselines.size()==3,"fixed bear A/R/B baseline reports all exist")
	if baselines.size()!=3:
		quit(1)
		return
	if not source_path.is_empty():
		var source=JSON.parse_string(FileAccess.get_file_as_string(source_path)) if FileAccess.file_exists(source_path) else null
		check(source is Dictionary and source.get("failures",-1)==0 and source.get("natural_count",0)==9,"external completed source evidence loads for actual-pack comparison")
		if not source is Dictionary:
			quit(1)
			return
		# JSON numbers are floats in Godot, while the live schedule uses ints.
		# Normalize only the row identity; full report/trace values remain untouched.
		for row in source.get("naturals",[]): source_rows[str(row.depth)+"/"+row.formation+"/"+str(int(row.fps))]=row
	check(ResourceLoader.exists(IMAGE),"effective perspective scene texture exists through source or actual imported PCK remap")
	if ResourceLoader.exists(IMAGE):
		var texture: Texture2D=load(IMAGE)
		check(texture!=null and texture.get_size()==Vector2(1672,941),"actual runtime texture retains the approved 1672 by 941 handoff dimensions")
	for formation in ["A","R","B"]:
		var legacy: Dictionary=natural(false,formation,30,1,false)
		naturals.append(legacy)
		for schedule in [[30,1,false],[120,2,true]]:
			var current: Dictionary=natural(true,formation,schedule[0],schedule[1],schedule[2])
			current["legacy_full_report_equal"]=equal_value(current.report,legacy.report)
			current["legacy_critical_trace_equal"]=equal_value(current.trace,legacy.trace)
			check(current.legacy_full_report_equal and current.legacy_critical_trace_equal,"new display preserves complete gameplay, actual release/contact times and semantic sound requests versus legacy "+formation+" FPS="+str(schedule[0]))
			naturals.append(current)
			print("BOARD_PERSPECTIVE_RUNTIME ",formation," fps=",schedule[0]," report=",current.legacy_full_report_equal," trace=",current.legacy_critical_trace_equal)
	check(naturals.size()==9,"three legacy controls and six actual new-scene full natural runs all executed")
	if not source_path.is_empty():
		check(source_rows.size()==9,"actual-pack comparison requires all nine externally completed source rows")
		for row in naturals:
			var token: String=str(row.depth)+"/"+row.formation+"/"+str(int(row.fps))
			var reference: Dictionary=source_rows.get(token,{})
			row["source_full_report_and_critical_trace_equal"]=not reference.is_empty() and equal_value(row.report,reference.get("report")) and equal_value(row.trace,reference.get("trace"))
			check(row.source_full_report_and_critical_trace_equal,"actual pack equals external source complete report and full critical trace "+token)
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"new runtime evidence opens at caller-selected output path")
	if file!=null:
		file.store_string(JSON.stringify({"scope":"D-20261017-002 actual perspective scene runtime parity","baseline":baseline_path,"source_evidence":source_path,"natural_count":naturals.size(),"new_scene_natural_count":6,"legacy_control_count":3,"checks":checks,"failures":failures,"allowed_keys":ALLOWED,"disabled_keys":DISABLED,"headless_is_scheduling_not_listening":true,"OS_input_or_visual_acceptance":false,"wall_clock_voice_capacity_outcomes_not_compared":true,"naturals":naturals},"\t"))
	print("BOARD_PERSPECTIVE_RUNTIME checks=",checks," natural_runs=",naturals.size()," failures=",failures)
	quit(1 if failures else 0)
