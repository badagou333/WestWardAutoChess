extends SceneTree
## Standalone source/main-pack D001 silence audit. No listening/rendering claim.
const Board = preload("res://scripts/board_trial.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const DISABLED := ["rat_death","boar_death","wolf_death","bear_lord_death","victory"]
const ALLOWED := ["guard_monk_attack","wild_hunter_attack","sparrow_spirit_attack","herbal_spirit_child_attack","foxfire_imp_attack","rat_attack","boar_attack","wolf_attack","bear_lord_attack","tangseng_hurt_warning"]
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
var failures := 0
var cases := []
var naturals := []
var initializations := []
var baseline_path := "res://tests/board-trial-runtime/board-balance-20261009-natural.json"
var output_path := "/tmp/board-audio-silence-20261010-source.json"

class RecordingAudio extends "res://scripts/presentation/board_trial_audio.gd":
	var actual_load_attempts: Array[String]=[]
	var cue_requests: Array[String]=[]
	func _load_cue(key: String, path: String) -> void:
		actual_load_attempts.append(key)
		super._load_cue(key,path)
	func play_cue(key: String, target_id := 0) -> bool:
		cue_requests.append(key) # Includes attempted requests even if rejected.
		return super.play_cue(key,target_id)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func verify_initialization(sound, label: String) -> void:
	check(sound.PROFILE=="board-selected-noncommercial-20261010",label+" current short-wolf profile")
	check(sound.streams.size()==10 and sound.stream_paths.size()==10 and sound.loaded_keys.size()==10,label+" actual initialization loads exactly ten event keys")
	check(sound.role_rules.size()==9 and sound.secondary_cues.size()==1,label+" nine role behaviors plus one secondary warning")
	var loaded := {}
	var paths := {}
	for key in sound.loaded_keys:
		check(key in ALLOWED and not loaded.has(key),label+" actual load attempts contain only unique approved keys")
		loaded[key]=true
		paths[sound.stream_paths.get(key,"")]=true
	for key in ALLOWED: check(sound.streams.has(key) and sound.streams[key]!=null and loaded.has(key),label+" approved actual stream exists "+key)
	check(paths.size()==9,label+" ten event keys share exactly nine runtime WAV assets")
	for key in DISABLED: check(not sound.streams.has(key) and not sound.stream_paths.has(key) and key not in sound.loaded_keys,label+" disabled sound is never initialized "+key)
	check(not sound.streams.has("ui") and not sound.streams.keys().any(func(key): return key.begins_with("shared_hit_") or key.ends_with("_death")),label+" no UI/material/death fallback stream is loaded")
	check(sound.rejected_keys.is_empty(),label+" no forbidden request was attempted during initialization")
	initializations.append({"label":label,"loaded_keys":sound.loaded_keys.duplicate(),"unique_assets":paths.size(),"disabled_loads":0,"disabled_requests":sound.rejected_keys.size()})
func fresh():
	var game=Board.new()
	game.enemy_profile="bear"
	root.add_child(game)
	game.set_process(false)
	verify_initialization(game.audio_feedback,"production controller initializer")
	var old=game.audio_feedback
	game.combat.projectile_released.disconnect(old.released)
	old.free()
	var sound=RecordingAudio.new()
	game.audio_feedback=sound
	game.add_child(sound)
	game.combat.projectile_released.connect(sound.released)
	verify_initialization(sound,"recording subclass initializer")
	check(sound.actual_load_attempts==sound.loaded_keys,"independent load interception equals actual loaded-key ledger")
	return game
func isolate(game, keep: Array) -> void:
	for actor in game.actors:
		if actor.id not in keep:
			actor.node.take_damage(actor.hp_max)
			actor.dead=true
func forbidden_requests(sound) -> Array:
	return sound.cue_requests.filter(func(key): return key in DISABLED or key.ends_with("_death") or key in ["defeat","failure","battle_result"])
func forbidden_played(heard: Array) -> Array:
	return heard.filter(func(key): return key in DISABLED or key.ends_with("_death") or key in ["defeat","failure","battle_result"])
func no_disabled(sound, heard: Array, label: String) -> void:
	check(forbidden_requests(sound).is_empty() and sound.rejected_keys.is_empty(),label+" actual controller makes zero disabled/death/result requests")
	check(forbidden_played(heard).is_empty(),label+" zero disabled/death/result scheduling signals")
	check(sound.actual_load_attempts.size()==10 and not sound.actual_load_attempts.any(func(key): return key in DISABLED),label+" actual initializer never attempted disabled load")

func death_case(id: String) -> void:
	var game=fresh()
	game.start_battle()
	isolate(game,["guard_monk","tangseng",id,"E6"])
	var guard: Dictionary=game._record("guard_monk")
	var target: Dictionary=game._record(id)
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	game._set_cell(guard,Vector2i(3,3))
	game._set_cell(target,Vector2i(4,3))
	game._set_cell(game._record("E6"),Vector2i(11,6))
	for actor in game.actors:
		if game._active(actor): actor.cooldown=100.0
	# Explicit lethal boundary fixture: only current target HP is lowered. The
	# actual guard attack, original damage, event and death lifecycle execute.
	target.node.health=guard.damage
	guard.target=target.id
	guard.cooldown=0
	var heard: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append(key))
	var body=target.node
	game._attack(guard,target)
	while game._active(target) and game.phase==game.Phase.BATTLE and game.elapsed<1: game.step(Config.STEP)
	var death_pose: bool=is_instance_valid(body) and body.presentation.pose=="retreat"
	check(target.dead and not game._active(target) and game.metrics.damage.get(guard.id,0)==guard.damage,"actual original guard event kills real "+target.key)
	check(death_pose and target.move.is_empty() and target.target.is_empty(),"death animation starts and actual activity/claims clear "+target.key)
	var holder: Dictionary=game._occupant(target.cell)
	check(holder.is_empty() or holder.id!=id,"dead enemy no longer owns its logical cell "+target.key)
	var faded := false
	while is_instance_valid(body) and game.elapsed<2:
		game._tick(Config.STEP)
		if body.presentation.visual_alpha<1: faded=true
		if body.presentation.visual_alpha<=0: break
	await process_frame
	await process_frame
	check(faded and not is_instance_valid(body),"real death view fades and queued enemy node is actually released "+target.key)
	check(game.phase==game.Phase.BATTLE and game._active(game._record("E6")),"explicit live spare opponent preserves actual battle during corpse lifecycle")
	no_disabled(game.audio_feedback,heard,"real "+target.key+" death")
	cases.append({"case":"real_enemy_death_silence","id":id,"key":target.key,"real_damage":game.metrics.damage.get(guard.id,0),"death_animation_started":death_pose,"faded":faded,"node_freed":not is_instance_valid(body),"disabled_requests":forbidden_requests(game.audio_feedback).size(),"disabled_played":forbidden_played(heard).size(),"loaded_disabled":0})
	game.free()

func actual_warning() -> void:
	var game=fresh()
	game.start_battle()
	isolate(game,["tangseng","E1"])
	var wolf: Dictionary=game._record("E1")
	var core: Dictionary=game._record("tangseng")
	game._set_cell(wolf,Vector2i(3,3))
	game._set_cell(core,Vector2i(4,3))
	wolf.cooldown=0
	core.cooldown=100
	wolf.target=core.id
	var heard: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append(key))
	game._attack(wolf,core)
	while game.metrics.damage.get("E1",0)==0 and game.phase==game.Phase.BATTLE and game.elapsed<1: game.step(Config.STEP)
	check(core.node.health==300.0-wolf.damage and heard.count("tangseng_hurt_warning")==1,"positive actual core damage retains one original warning")
	check(heard.count("wolf_attack")==1,"same real event retains approved short wolf primary")
	no_disabled(game.audio_feedback,heard,"actual core damage warning")
	cases.append({"case":"actual_core_warning_retained","remaining_hp":core.node.health,"warning_count":heard.count("tangseng_hurt_warning"),"disabled_requests":0,"disabled_played":0})
	game.free()

func manual_rejection() -> void:
	var game=fresh()
	var heard: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append(key))
	for key in DISABLED: check(not game.audio_feedback.play_cue(key),"explicit manual disabled-key request rejects "+key)
	check(game.audio_feedback.rejected_keys==DISABLED and forbidden_requests(game.audio_feedback)==DISABLED and heard.is_empty(),"independent recorder observes all five manual rejects without any playback")
	check(game.audio_feedback.actual_load_attempts.size()==10,"manual rejection never lazily loads a disabled file")
	cases.append({"case":"manual_rejection_only_not_natural","rejected":game.audio_feedback.rejected_keys.duplicate(),"disabled_played":0,"loaded_disabled":0})
	game.free()

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

func natural(formation: String, fps: int, sim_speed: int, pause_once: bool, golden: Dictionary) -> Dictionary:
	var game=fresh()
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	var heard: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append(key))
	check(game.start_battle() and game.actors.size()==13,"silenced result trial starts all thirteen real actors "+formation)
	game.speed=sim_speed
	var did_pause := false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/fps)
		if pause_once and not did_pause and game.elapsed>=1:
			game.toggle_pause()
			var before: Dictionary=game.report().duplicate(true)
			var requests: Array=game.audio_feedback.cue_requests.duplicate()
			var cue_count: int=heard.size()
			game.step(5)
			check(game.report()==before and game.audio_feedback.cue_requests==requests and heard.size()==cue_count,"real pause advances no combat or cue request/playback")
			game.toggle_pause()
			did_pause=true
	var report: Dictionary=game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1 and equal_value(report,golden),"complete real victory/failure report preserves original gameplay "+formation)
	check(game.message.contains("胜利" if game.victory else "失败"),"real result notice still distinguishes victory/failure "+formation)
	no_disabled(game.audio_feedback,heard,"natural deaths and result "+formation)
	check(game.audio_feedback.audit.size()>0 and game.audio_feedback.voices.all(func(player): return is_equal_approx(player.pitch_scale,1.0)),"retained main semantic events execute at unmodified pitch in real natural battle")
	var result := {"formation":formation,"fps":fps,"speed":sim_speed,"report":report,"whole_golden_report_equal":equal_value(report,golden),"disabled_requests":forbidden_requests(game.audio_feedback).size(),"disabled_played":forbidden_played(heard).size(),"disabled_loads":0,"actual_initialized_keys":game.audio_feedback.actual_load_attempts.duplicate(),"retained_main_stats":game.audio_feedback.stats.duplicate(true)}
	var count: int=heard.size()
	var calls: Array=game.audio_feedback.cue_requests.duplicate()
	game.step(5)
	check(game.report()==report and heard.size()==count and game.audio_feedback.cue_requests==calls,"completed result neither advances battle nor schedules replacement result audio")
	var deployment: Dictionary=game.start_deployment.duplicate()
	game.retry()
	check(game.phase==game.Phase.DEPLOY and game.elapsed==0 and game.deployment==deployment and game.actors.size()==13,"actual retry retains original full roster and prebattle deployment")
	check(game.audio_feedback.seen.is_empty() and game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"actual retry clears attack/audio state without reviving removed categories")
	no_disabled(game.audio_feedback,heard,"natural retry "+formation)
	verify_initialization(game.audio_feedback,"natural retry reused initializer")
	game.free()
	return result

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="): baseline_path=argument.trim_prefix("--baseline=")
		elif argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	for id in ["E5","E3","E1","E7"]: await death_case(id)
	actual_warning()
	manual_rejection()
	check(cases.size()==6,"four actual death lifecycles, real warning and explicit manual-reject boundary all execute")
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	check(baseline is Dictionary,"original complete balance baseline loads")
	if baseline is Dictionary:
		for formation in ["A","R","B"]:
			var rows: Array=baseline.cases.filter(func(row): return row.profile=="bear" and row.formation==formation)
			check(rows.size()==1,"one original report exists for bear "+formation)
			if rows.size()!=1: continue
			var first:=natural(formation,30,1,false,rows[0].report)
			var repeated:=natural(formation,120,2,true,rows[0].report)
			check(equal_value(first.report,repeated.report),"victory/failure full report repeats across FPS/2x/pause "+formation)
			naturals.append(first)
			naturals.append(repeated)
	check(naturals.size()==6,"two true victories and true failure complete under both schedules")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"standalone silence evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"D-20261010-001","profile":"board-selected-noncommercial-20261010","headless_is_scheduling_not_listening":true,"disabled_cues":DISABLED,"allowed_keys":ALLOWED,"initialization_checks":initializations,"case_count":cases.size(),"cases":cases,"natural_count":naturals.size(),"naturals":naturals,"failures":failures},"\t"))
	print("BOARD_AUDIO_SILENCE cases=",cases.size()," natural_runs=",naturals.size()," failures=",failures)
	quit(1 if failures else 0)
