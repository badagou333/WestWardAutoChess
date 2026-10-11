extends SceneTree
## Standalone source/main-pack test. API/headless callbacks are not OS input,
## rendered UI or listening acceptance. Every natural survivor uses real AI.
const Trial = preload("res://scripts/audio_trial.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const Units = preload("res://scripts/data/demo_units.gd")
const FRIEND_KEYS := ["tangseng","guard_monk","wild_hunter","sparrow_spirit","herbal_spirit_child","foxfire_imp"]
const ENEMY_KEYS := ["wolf","boar","rat","bear_lord"]
const DISABLED := ["rat_death","boar_death","wolf_death","bear_lord_death","victory"]
var failures := 0
var cases := []
var natural_reports := []
var output_path := "/tmp/audio-trial-20261010-source.json"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func fresh():
	var game=Trial.new()
	root.add_child(game)
	game.set_process(false)
	return game
func rows(game, friendly: bool) -> Array:
	return game.actors.filter(func(actor): return actor.friendly==friendly)
func actor_key(game, key: String, friendly: bool) -> Dictionary:
	var found: Array=rows(game,friendly).filter(func(actor): return actor.key==key)
	return found[0] if not found.is_empty() else {}
func state(game) -> Dictionary:
	return {"specs":game.setup_specs.duplicate(true),"starts":game.start_specs.duplicate(true),"report":game.report().duplicate(true),"selected":game.selected}
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

func assets_and_roster(game, label: String) -> void:
	var sound=game.audio_feedback
	check(sound.PROFILE=="board-selected-noncommercial-20261010" and sound.role_rules.size()==9,label+" inherits approved selected audio without reimplementing trigger table")
	check(sound.streams.size()==10 and sound.stream_paths.size()==10 and sound.loaded_keys.size()==10,label+" exactly ten approved cue keys are actually loaded")
	var unique := {}
	for path in sound.stream_paths.values(): unique[path]=true
	check(unique.size()==9,label+" exactly nine underlying streams, including shared monk/bear")
	for key in DISABLED: check(key not in sound.loaded_keys and not sound.streams.has(key),label+" no disabled/result/death cue is loaded "+key)
	check(sound.rejected_keys.is_empty(),label+" no disabled-cue request was attempted")
	check(not sound.streams.has("ui") and not sound.streams.keys().any(func(key): return key.begins_with("shared_hit_") or key.ends_with("_death")),label+" no generic/result/retreat fallback loaded")
	var identities := {}
	for actor in game.actors:
		check(not identities.has(actor.id),label+" each duplicate role has an independent actor ID")
		identities[actor.id]=true
		check(actor.id.begins_with("F" if actor.friendly else "E") and actor.id.substr(1).is_valid_int(),label+" actor ID uses its side and global sequence")
		check(actor.node.has_meta("audio_trial_friendly") and bool(actor.node.get_meta("audio_trial_friendly"))==actor.friendly,label+" actual node stores the exact unique source team")
		var expected: Dictionary=Config.CORE if actor.key=="tangseng" else (Units.HEROES[actor.key] if actor.friendly else Config.enemy_stats(actor.key,"bear"))
		check(actor.hp_max==expected.hp and actor.damage==expected.damage and actor.interval==expected.interval and actor.reach==expected.range,label+" original fixed combat attributes remain intact "+actor.id)
		check(actor.walk==0.5 and actor.node.move_interval==0.5,label+" shared whole-tile movement remains intact")
	check(rows(game,true).size()<=6 and rows(game,false).size()<=6,label+" actual side capacities never exceed six")

func configuration_boundaries() -> void:
	var game=fresh()
	check(game.CAP_PER_SIDE==6 and game.phase==game.Phase.DEPLOY,"independent trial boots in setup with explicit six-per-side capacity")
	check(game.setup_specs.size()==2 and rows(game,true).size()==1 and rows(game,false).size()==1,"default contains one guard and one wolf")
	check(actor_key(game,"guard_monk",true).cell==Vector2i(4,3) and actor_key(game,"wolf",false).cell==Vector2i(6,3),"default starts at the documented opposite cells without a mandatory core")
	check(not game.actors.any(func(actor): return actor.key=="tangseng"),"default no-core roster is real")
	assets_and_roster(game,"default")
	game.clear_trial()
	check(game.setup_specs.is_empty() and game.actors.is_empty() and not game.start_battle(),"empty setup cannot start a fabricated victory")
	check(game.add_units(true,"guard_monk",1) and not game.start_battle(),"friendly-only setup cannot start")
	game.clear_trial()
	check(game.add_units(false,"wolf",1) and not game.start_battle(),"enemy-only setup cannot start")
	game.clear_trial()
	var last_sequence := 0
	for key in FRIEND_KEYS:
		check(game.add_units(true,key,1),"every existing friendly kind is accepted "+key)
		var actor: Dictionary=actor_key(game,key,true)
		var serial: int=int(actor.id.substr(1))
		check(serial>last_sequence,"new friendly instances use increasing global IDs")
		last_sequence=serial
	for key in ENEMY_KEYS:
		check(game.add_units(false,key,1),"every existing enemy kind is accepted "+key)
		var actor: Dictionary=actor_key(game,key,false)
		var serial: int=int(actor.id.substr(1))
		check(serial>last_sequence,"opposite side continues the same global ID sequence")
		last_sequence=serial
	check(game.add_units(false,"wolf",2),"same enemy kind supports independent repeated instances")
	check(game.setup_specs.size()==12 and rows(game,true).size()==6 and rows(game,false).size()==6,"full twelve-instance setup reaches both exact caps")
	var snapshot: Dictionary=state(game)
	for invalid in [[true,"guard_monk",1],[false,"wolf",1],[true,"unknown",1],[false,"guard_monk",1],[true,"wolf",1],[true,"guard_monk",0],[true,"guard_monk",7],[false,"wolf",-1]]:
		check(not game.add_units(invalid[0],invalid[1],invalid[2]) and state(game)==snapshot,"invalid type/count/cap addition is atomic and leaves state intact")
	var friends: Array=rows(game,true)
	var enemies: Array=rows(game,false)
	check(game.place(friends[0].id,Vector2i(11,6)) and game.place(enemies[0].id,Vector2i(0,0)),"both armies may be placed anywhere on the full trial board")
	var first: Dictionary=friends[0]
	var second: Dictionary=friends[1]
	var from: Vector2i=first.cell
	var to: Vector2i=second.cell
	check(game.place(first.id,to) and first.cell==to and second.cell==from,"same-team placement swaps atomically without changing identities")
	snapshot=state(game)
	check(not game.place(first.id,enemies[0].cell) and state(game)==snapshot,"cross-team occupied placement is rejected atomically")
	for outside in [Vector2i(-1,0),Vector2i(12,0),Vector2i(0,7)]: check(not game.place(first.id,outside) and state(game)==snapshot,"out-of-board placement preserves setup")
	check(game.set_initial_health(first.id,0.5) and is_equal_approx(first.node.health,first.hp_max*0.5),"friendly fifty-percent preparation uses original max HP")
	check(game.set_initial_health(first.id,1.0) and first.node.health==first.hp_max,"restore-full preparation does not change combat attributes")
	snapshot=state(game)
	check(not game.set_initial_health(enemies[0].id,0.5) and state(game)==snapshot,"enemy HP helper is not exposed")
	check(not game.set_initial_health(first.id,0.25) and state(game)==snapshot,"preparation rejects unsupported ratios instead of changing formal stats")
	var removed: String=second.id
	game.selected=removed
	check(game.remove_selected() and game._record(removed).is_empty() and game.setup_specs.size()==11,"selected-instance removal preserves remaining roster")
	game.selected=""
	check(not game.remove_selected(),"no selected instance cannot remove an arbitrary actor")
	game.reset_default()
	check(game.setup_specs.size()==2,"reset-default rebuilds only the documented pair")
	assets_and_roster(game,"reset default")
	cases.append({"case":"configuration_ID_kind_count_capacity_placement_health_delete","maximum_instances":12,"default_without_core":true})
	game.free()

func locked_configuration_and_retry() -> void:
	var game=fresh()
	check(game.start_battle() and game.phase==game.Phase.BATTLE,"real default battle starts without Tang")
	var starts: Array=game.start_specs.duplicate(true)
	var actor: Dictionary=game.actors[0]
	game.toggle_pause()
	var snapshot: Dictionary=state(game)
	check(not game.add_units(true,"guard_monk",1) and not game.place(actor.id,Vector2i(1,1)) and not game.set_initial_health(actor.id,0.5),"paused battle remains configuration-locked")
	game.selected=actor.id
	check(not game.remove_selected(),"paused battle cannot remove an instance")
	game.selected=snapshot.selected
	game.clear_trial()
	game.reset_default()
	game.healing_preset()
	check(state(game)==snapshot,"all preset/clear/reset attempts preserve the paused locked battle")
	game.toggle_pause()
	game.step(0.8)
	check(not game.audio_feedback.seen.is_empty() and not game.combat.marks.is_empty(),"retry boundary starts with real resolved sound tokens and still-live hit effects")
	game.audio_feedback.level=0.21
	game.audio_feedback.enabled=false
	game.set_listen(false,true)
	game.retry()
	check(game.phase==game.Phase.BATTLE and game.elapsed==0 and game.setup_specs==starts and game.start_specs==starts,"retry restores exact opening setup and immediately restarts battle")
	check(game.audio_feedback.level==0.21 and not game.audio_feedback.enabled and game.audio_feedback.seen.is_empty(),"retry preserves chosen sound level/enabled state and clears semantic history")
	check(not game.listen_friendly and game.listen_enemy and not game.audio_feedback.listen_friendly and game.audio_feedback.listen_enemy,"retry also preserves selected army listening switches")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty() and game.combat.marks.is_empty() and game.actors.all(func(item): return item.move.is_empty() and item.target.is_empty() and item.cooldown==0 and item.step_serial==0),"retry clears real attack, effect and movement state")
	game.return_to_setup()
	check(game.phase==game.Phase.DEPLOY and game.setup_specs==starts,"return-to-setup restores exact original choices without immediate battle")
	cases.append({"case":"pause_lock_same_setup_retry_controls_and_pending_clear","opening_instances":starts.size()})
	game.free()

func duplicate_monk_binding() -> void:
	var game=fresh()
	game.clear_trial()
	game.add_units(true,"guard_monk",2)
	game.add_units(false,"wolf",1)
	var monks: Array=rows(game,true)
	game.place(monks[0].id,Vector2i(1,1))
	game.place(monks[1].id,Vector2i(1,4))
	game.place(rows(game,false)[0].id,Vector2i(11,6))
	game.start_battle()
	check(game._move(monks[0],Vector2i(2,1)) and game._move(monks[1],Vector2i(1,5)),"two independent guards start actual movement segments")
	# Explicit partial-progress boundary state, not a natural battle sample.
	monks[1].move.time=0.125
	game._tick(Config.STEP)
	for monk in monks:
		var view=monk.node.presentation
		check(view.board_actor.id==monk.id and view.board_actor.node==monk.node,"each repeated monk sample binds by its own node/instance")
		check(is_equal_approx(view.sample_walk_time,float(monk.step_completed)*monk.walk+monk.move.time),"each repeated monk's gait uses its own committed partial progress")
	check(not is_equal_approx(monks[0].node.presentation.sample_walk_time,monks[1].node.presentation.sample_walk_time),"different instance progress is not collapsed into role-key lookup")
	cases.append({"case":"duplicate_monk_per_node_visual_binding","ids":[monks[0].id,monks[1].id],"walk_times":[monks[0].node.presentation.sample_walk_time,monks[1].node.presentation.sample_walk_time]})
	game.free()

func natural(mode: String, fps: int, sim_speed: int, paused_run: bool, multiple := false) -> Dictionary:
	var game=fresh()
	if multiple:
		game.clear_trial()
		game.add_units(true,"guard_monk",2)
		game.add_units(false,"wolf",2)
	game.set_listen(mode in ["all","friendly"],mode in ["all","enemy"])
	assets_and_roster(game,"natural "+mode)
	var teams := {}
	for actor in game.actors: teams[actor.node.get_instance_id()]=actor.friendly
	game.start_battle()
	var starts: Array=game.start_specs.duplicate(true)
	game.speed=sim_speed
	var paused_once := false
	while game.phase==game.Phase.BATTLE and game.elapsed<90:
		game.step(1.0/fps)
		if paused_run and not paused_once and game.elapsed>=1:
			game.toggle_pause()
			var before: Dictionary=game.report().duplicate(true)
			var audit_count: int=game.audio_feedback.audit.size()
			game.step(5)
			check(game.report()==before and game.audio_feedback.audit.size()==audit_count,"trial pause freezes complete actual combat/audio event clocks")
			game.toggle_pause()
			paused_once=true
	check(game.phase==game.Phase.RESULT and game.result_count==1,"actual trial settles once without requiring a core "+mode)
	var living_friends: int=rows(game,true).filter(func(actor): return game._active(actor)).size()
	var living_enemies: int=rows(game,false).filter(func(actor): return game._active(actor)).size()
	check(living_friends==0 or living_enemies==0,"trial ending reflects genuine full army elimination")
	check(game.victory==(living_friends>0 and living_enemies==0),"actual army elimination uses friendly failure priority")
	var played_teams := []
	var actual_sources := {}
	for row in game.audio_feedback.audit:
		check(teams.has(row.source_id),"every primary semantic event comes from a real unique instance")
		actual_sources[row.source_id]=true
		if row.outcome=="played":
			var friendly: bool=teams[row.source_id]
			played_teams.append(friendly)
			check((friendly and game.listen_friendly) or (not friendly and game.listen_enemy),"actual scheduled primary source belongs only to a listened army")
	check(game.audio_feedback.audit.size()>0 and game.audio_feedback.stats.requested>0,"natural battle really executes inherited sound-trigger events")
	if mode=="none": check(game.audio_feedback.stats.played==0 and game.audio_feedback.filtered_count>0,"both-off filter consumes primary requests without scheduling")
	elif mode=="all": check(game.audio_feedback.filtered_count==0 and not played_teams.is_empty(),"all-on filter preserves genuine primary scheduling")
	else: check(game.audio_feedback.filtered_count>0 and not played_teams.is_empty(),"single-army filter suppresses opposite real requests but preserves allowed source")
	if multiple: check(actual_sources.size()==4,"two guards and two wolves all emit independently keyed actual source events")
	check(game.audio_feedback.rejected_keys.is_empty() and game.audio_feedback.voices.all(func(player): return is_equal_approx(player.pitch_scale,1.0)),"trial never requests disabled cue and never changes pitch at2x")
	var report: Dictionary=game.report().duplicate(true)
	var result := {"mode":mode,"fps":fps,"speed":sim_speed,"multiple":multiple,"report":report,"source_instances":actual_sources.size(),"filtered_count":game.audio_feedback.filtered_count,"warning_filtered":game.audio_feedback.warning_filtered,"audio_stats":game.audio_feedback.stats.duplicate(true),"disabled_requests":game.audio_feedback.rejected_keys.size()}
	game.retry()
	check(game.phase==game.Phase.BATTLE and game.elapsed==0 and game.start_specs==starts and game.setup_specs==starts and game.audio_feedback.seen.is_empty(),"natural trial retry rebuilds same instances/configuration and starts a fresh real battle")
	game.return_to_setup()
	check(game.phase==game.Phase.DEPLOY and game.setup_specs==starts,"natural trial return restores saved configuration")
	game.free()
	return result

func healing_assistance() -> void:
	var game=fresh()
	game.healing_preset()
	var guard: Dictionary=actor_key(game,"guard_monk",true)
	var healer: Dictionary=actor_key(game,"herbal_spirit_child",true)
	check(game.setup_specs.size()==3 and not guard.is_empty() and not healer.is_empty() and rows(game,false)[0].key=="rat","healing preset contains actual selected guard/healer/distant rat")
	game.start_battle()
	check(guard.node.health==guard.hp_max*0.5 and guard.hp_max==310.0,"50% preparation survives actual begin_battle without modifying max HP")
	while game.phase==game.Phase.BATTLE and game.metrics.healing.get(healer.id,0)==0 and game.elapsed<4: game.step(Config.STEP)
	check(game.metrics.healing.get(healer.id,0)>0,"real healing preset resolves positive HP restoration under actual AI")
	check(game.audio_feedback.audit.any(func(row): return row.source_id==healer.node.get_instance_id() and row.trigger=="positive_healing_applied"),"actual positive healing emits inherited unique healer semantic event")
	check(game.audio_feedback.rejected_keys.is_empty(),"healing fixture requests no disabled categories")
	cases.append({"case":"real_positive_healing_assisted_preset","effective_healing":game.metrics.healing.get(healer.id,0),"original_max_hp":guard.hp_max})
	game.free()

func warning_and_consumption(friendly_on: bool, enemy_on: bool) -> void:
	var game=fresh()
	game.clear_trial()
	game.add_units(true,"tangseng",1)
	game.add_units(false,"wolf",1)
	var core: Dictionary=actor_key(game,"tangseng",true)
	var wolf: Dictionary=actor_key(game,"wolf",false)
	game.place(core.id,Vector2i(4,3))
	game.place(wolf.id,Vector2i(5,3))
	game.set_listen(friendly_on,enemy_on)
	game.start_battle()
	core.cooldown=100.0 # Explicit attack isolation; genuine wolf event/HP applies.
	wolf.cooldown=0
	wolf.target=core.id
	var heard := []
	var events := []
	game.audio_feedback.cue_played.connect(func(key): heard.append(key))
	game.combat.resolved.connect(func(_target,_amount,_healing,event): events.append(event.duplicate(false)))
	game._attack(wolf,core)
	while game.phase==game.Phase.BATTLE and game.metrics.damage.get(wolf.id,0)==0 and game.elapsed<1: game.step(Config.STEP)
	check(core.node.health==300.0-wolf.damage and not events.is_empty(),"actual opponent attack damages the source-team-marked core")
	check(heard.count("tangseng_hurt_warning")==int(friendly_on) and game.audio_feedback.warning_filtered==int(not friendly_on),"warning filter follows its actual victim army")
	if not enemy_on:
		check(game.audio_feedback.filtered_count==1 and game.audio_feedback.stats.muted==1 and heard.count("wolf_attack")==0,"filtered primary uses inherited consumed token plus muted outcome")
		var before: int=game.audio_feedback.stats.played
		game.set_listen(true,true)
		if not events.is_empty(): game.audio_feedback.role_applied(events[0],1.0)
		check(game.audio_feedback.stats.duplicates==1 and game.audio_feedback.stats.played==before,"enabling previously filtered army never replays an old consumed attack")
	check(game.audio_feedback.rejected_keys.is_empty(),"warning/filter boundary requests no forbidden fallback")
	cases.append({"case":"victim_warning_and_filtered_primary_consumption","listen_friendly":friendly_on,"listen_enemy":enemy_on,"warning_count":heard.count("tangseng_hurt_warning"),"warning_filtered":game.audio_feedback.warning_filtered})
	game.free()

func simultaneous_elimination() -> void:
	var game=fresh()
	game.start_battle()
	for actor in game.actors: actor.node.take_damage(actor.hp_max)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.RESULT and not game.victory and game.result_count==1,"simultaneous whole-army elimination retains friendly failure priority")
	check(game.audio_feedback.rejected_keys.is_empty(),"simultaneous result does not invent death/result cue")
	cases.append({"case":"simultaneous_all_eliminated_failure"})
	game.free()

func logical_input_and_callbacks() -> void:
	var game=fresh()
	var friendly: Dictionary=rows(game,true)[0]
	var enemy: Dictionary=rows(game,false)[0]
	game.select(friendly.id)
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=Config.center(Vector2i(2,1))
	game._unhandled_input(click)
	check(friendly.cell==Vector2i(2,1) and game.selected.is_empty(),"logical left-click placement commits selected instance and clears control")
	click.pressed=false
	game._unhandled_input(click)
	check(friendly.cell==Vector2i(2,1),"logical click release does not submit a second move")
	click.pressed=true
	click.position=Config.center(enemy.cell)
	game._unhandled_input(click)
	check(game.selected==enemy.id and game.pointer_drag,"logical enemy click can select a movable enemy instance")
	click.pressed=false
	click.position=Config.center(Vector2i(10,6))
	game._unhandled_input(click)
	check(enemy.cell==Vector2i(10,6) and game.selected.is_empty(),"logical drag-release moves enemy across full board and clears control")
	game.select(friendly.id)
	var cancel:=InputEventKey.new()
	cancel.pressed=true
	cancel.keycode=KEY_ESCAPE
	game._unhandled_input(cancel)
	check(game.selected.is_empty(),"logical Escape cancels selection without removal")
	game.select(enemy.id)
	var delete:=InputEventKey.new()
	delete.pressed=true
	delete.keycode=KEY_DELETE
	game._unhandled_input(delete)
	check(game._record(enemy.id).is_empty() and game.setup_specs.size()==1,"logical Delete removes only selected enemy during setup")
	game.ui.clear_button.pressed.emit()
	game.ui.friend_kind.select(FRIEND_KEYS.find("guard_monk"))
	game.ui.friend_count.value=2
	game.ui.friend_add.pressed.emit()
	game.ui.enemy_kind.select(ENEMY_KEYS.find("wolf"))
	game.ui.enemy_count.value=1
	game.ui.enemy_add.pressed.emit()
	check(rows(game,true).size()==2 and rows(game,false).size()==1,"actual kind/count/add controls create independently repeated selected types")
	game.ui.unit_choice.item_selected.emit(2)
	var selected: Dictionary=game._record(game.selected)
	check(not selected.is_empty() and selected.friendly,"actual instance-dropdown callback selects one independent actor")
	game.ui.half_health_button.pressed.emit()
	check(selected.node.health==selected.hp_max*0.5,"actual preparation button sets selected friendly half HP")
	game.ui.full_health_button.pressed.emit()
	check(selected.node.health==selected.hp_max,"actual preparation button restores original full HP")
	game.ui.remove_button.pressed.emit()
	check(game.setup_specs.size()==2,"actual remove-button callback removes only selected duplicate")
	game.ui.filter_friendly.set_pressed_no_signal(false)
	game.ui.filter_friendly.toggled.emit(false)
	check(not game.listen_friendly and game.listen_enemy,"actual army-checkbox callback sets source filter")
	game.ui.listen_all_button.pressed.emit()
	check(game.listen_friendly and game.listen_enemy,"actual listen-both callback restores both filters")
	game.ui.volume.value_changed.emit(0.25)
	check(game.audio_feedback.level==0.25,"actual volume callback controls retained audio output")
	game.ui.mute_button.pressed.emit()
	check(not game.audio_feedback.enabled,"actual mute-button callback disables sound")
	game.ui.mute_button.pressed.emit()
	check(game.audio_feedback.enabled,"actual mute-button callback restores sound")
	game.ui.default_button.pressed.emit()
	check(is_instance_valid(game.ui.start_button) and is_instance_valid(game.ui.retry_button) and is_instance_valid(game.ui.pause_button),"actual trial UI exposes connected start/retry/pause controls")
	if is_instance_valid(game.ui.start_button): game.ui.start_button.pressed.emit()
	check(game.phase==game.Phase.BATTLE,"actual start-button callback begins trial")
	if is_instance_valid(game.ui.pause_button): game.ui.pause_button.pressed.emit()
	check(game.paused,"actual pause-button callback freezes trial")
	if is_instance_valid(game.ui.retry_button): game.ui.retry_button.pressed.emit()
	check(game.phase==game.Phase.BATTLE and not game.paused and game.elapsed==0,"actual retry-button callback immediately restarts same battle")
	var active_specs: Array=game.setup_specs.duplicate(true)
	game.select(game.actors[0].id)
	game._unhandled_input(delete)
	check(game.setup_specs==active_specs,"logical Delete cannot remove actors in active battle")
	cases.append({"case":"logical_input_and_actual_control_callbacks","not_OS_pointer_or_rendering_acceptance":true})
	game.free()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
	configuration_boundaries()
	locked_configuration_and_retry()
	duplicate_monk_binding()
	healing_assistance()
	warning_and_consumption(true,false)
	warning_and_consumption(false,true)
	warning_and_consumption(false,false)
	simultaneous_elimination()
	logical_input_and_callbacks()
	var golden := {}
	for mode in ["all","friendly","enemy","none"]:
		var result:=natural(mode,30,1,false)
		if mode=="all": golden=result.report
		else: check(equal_value(result.report,golden),"army audio filtering cannot alter any actual complete combat report "+mode)
		natural_reports.append(result)
	var repeated:=natural("all",120,2,true)
	check(equal_value(repeated.report,golden),"default complete battle repeats at120FPS/2x with pause")
	natural_reports.append(repeated)
	natural_reports.append(natural("all",30,1,false,true))
	check(cases.size()==9 and natural_reports.size()==6,"all nine scoped boundaries and six real complete battles executed")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"standalone audio trial evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"D-20261010-002","headless_API_not_OS_input_or_listening":true,"capacity_per_side":6,"case_count":cases.size(),"cases":cases,"natural_count":natural_reports.size(),"naturals":natural_reports,"failures":failures},"\t"))
	print("AUDIO_TRIAL cases=",cases.size()," natural_runs=",natural_reports.size()," failures=",failures)
	quit(1 if failures else 0)
