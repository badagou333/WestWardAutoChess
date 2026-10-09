extends "res://tests/board_trial_enemy_profiles_test.gd"
## Three explicit profiles x A/B/C/R x two public schedules, all actual AI.
## Observation records real HP deltas; never substitutes combat stats or brains.
const SUPPORT := [Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
var natural_results := []
var baseline := {}
var every_step_total := 0

class BalanceGame extends "res://scripts/board_trial.gd":
	var auditor := Callable()
	var received := {}
	var restored := {}
	var first_received := {}
	var damage_sources := {}
	var heal_sources := {}
	var resolve_count := 0
	var movement_counts := {}
	var completed_counts := {}
	var started := {}
	var audited_steps := 0
	func _move(actor: Dictionary, next: Vector2i) -> bool:
		var from: Vector2i=actor.cell
		var held: Dictionary=actor.move.duplicate(true)
		var owner: Dictionary=_occupant(next,actor.id)
		var issued: bool=super._move(actor,next)
		if issued:
			movement_counts[actor.id]=movement_counts.get(actor.id,0)+1
			started[actor.id]={"time":elapsed,"from":from,"to":next,"serial":actor.step_serial}
			if auditor.is_valid(): auditor.call("move",self,{"actor":actor,"from":from,"to":next,"previous":held,"owner":owner})
		return issued
	func _attack(actor: Dictionary, target: Dictionary, healing := false) -> void:
		var count: int=metrics.attack_times.get(actor.id,[]).size()
		super._attack(actor,target,healing)
		if metrics.attack_times.get(actor.id,[]).size()>count and auditor.is_valid(): auditor.call("attack",self,{"actor":actor,"target":target,"healing":healing})
	func _brain(actor: Dictionary, delta: float) -> void:
		var held: Dictionary=actor.move.duplicate(true)
		var target: String=actor.target
		var pose: String=actor.node.presentation.pose
		super._brain(actor,delta)
		if auditor.is_valid(): auditor.call("brain",self,{"actor":actor,"move":held,"target":target,"pose":pose})
	func _resolve(target, amount: float, healing: bool, event: Dictionary) -> void:
		var source: Dictionary=_by_node(event.source)
		var source_id: String=source.get("id","")
		var before := {}
		for actor in actors: before[actor.id]=_hp(actor)
		super._resolve(target,amount,healing,event)
		for actor in actors:
			var delta: float=_hp(actor)-float(before[actor.id])
			if absf(delta)<0.000000001: continue
			resolve_count+=1
			if delta<0:
				received[actor.id]=received.get(actor.id,0.0)-delta
				damage_sources[source_id]=damage_sources.get(source_id,0.0)-delta
				if not first_received.has(actor.id): first_received[actor.id]={"source":source_id,"time":elapsed,"actual_damage":-delta}
			else:
				restored[actor.id]=restored.get(actor.id,0.0)+delta
				heal_sources[source_id]=heal_sources.get(source_id,0.0)+delta
			if auditor.is_valid(): auditor.call("resolve",self,{"actor":actor,"delta":delta,"source":source_id,"healing":healing,"requested":amount})
	func _tick(delta: float) -> void:
		var previous := {}
		for actor in actors: previous[actor.id]={"cell":actor.cell,"move":actor.move.duplicate(true),"completed":actor.step_completed}
		super._tick(delta)
		audited_steps+=1
		if auditor.is_valid(): auditor.call("tick",self,{"previous":previous})

func audit(kind: String, game, event: Dictionary) -> void:
	if kind=="move":
		var actor: Dictionary=event.actor
		check(event.previous.is_empty() and event.owner.is_empty(),"natural commit never interrupts a segment or overlaps an owner "+actor.id)
		check(Config.valid(event.to) and Config.distance(event.from,event.to)==1,"natural commit is one legal four-neighbor step "+actor.id)
		check(actor.move.from==actor.cell and actor.move.to==event.to and actor.move.duration==0.5,"natural actual segment retains full shared duration "+actor.id)
		check(not actor.friendly or actor.id not in ["tangseng","herbal_spirit_child"],"stationary support/core never issue natural motion")
	elif kind=="attack":
		var actor: Dictionary=event.actor
		var target: Dictionary=event.target
		check(actor.move.is_empty() and game._active(target) and Config.distance(actor.cell,target.cell)<=actor.reach,"every natural attack/heal starts inside its actual range "+actor.id)
		check(is_equal_approx(actor.cooldown,actor.interval),"natural action sets original attack/heal cooldown exactly once "+actor.id)
		if actor.id=="E7": check(actor.damage==20.0 and actor.interval==1.2 and actor.reach==1,"real bear natural action uses approved prototype stats")
	elif kind=="brain":
		var actor: Dictionary=event.actor
		if not event.move.is_empty(): check(actor.move==event.move and actor.target==event.target,"natural in-flight brain preserves complete segment and target "+actor.id)
		if event.pose=="basic_attack": check(actor.move.is_empty() and actor.target==event.target,"natural brain preserves existing attack activity "+actor.id)
	elif kind=="resolve":
		check((event.delta>0)==event.healing and absf(event.delta)<=event.requested+0.000000001,"observation records only actual capped hit/heal effect")
	else:
		var occupied := {}
		for actor in game.actors:
			if not game._active(actor):
				if actor.dead: check(actor.move.is_empty() and actor.target.is_empty() and actor.handoff.is_empty() and actor.step_wait.is_empty(),"natural death removes activity and claims "+actor.id)
				game.started.erase(actor.id)
				continue
			var cells: Array=[actor.cell]
			if not actor.move.is_empty(): cells.append(actor.move.to)
			for cell in cells:
				check(Config.valid(cell) and not occupied.has(cell),"all natural actor source/destination claims remain unique")
				occupied[cell]=actor.id
			var foot: Vector2=Config.center(actor.cell)
			if not actor.move.is_empty(): foot=Config.center(actor.move.from).lerp(Config.center(actor.move.to),minf(1,actor.move.time/actor.move.duration))
			check(actor.node.position.distance_to(foot)<0.000001,"actual natural body foot follows its logical full segment "+actor.id)
			if actor.id in ["tangseng","herbal_spirit_child"]: check(actor.cell==actor.anchor and actor.move.is_empty(),"natural support/core keep their deployment positions")
			var old: Dictionary=event.previous[actor.id]
			if not old.move.is_empty():
				if old.move.time+Config.STEP+0.00000001<old.move.duration:
					check(actor.cell==old.cell and not actor.move.is_empty() and actor.move.from==old.move.from and actor.move.to==old.move.to,"natural movement cannot land/turn before full duration "+actor.id)
				else:
					check(actor.cell==old.move.to,"natural whole segment commits its actual destination "+actor.id)
					if not actor.move.is_empty(): check(actor.move.from==actor.cell,"same-tick renewed segment starts from real landing "+actor.id)
			if actor.step_completed>old.completed:
				game.completed_counts[actor.id]=game.completed_counts.get(actor.id,0)+1
				# A renewed move replaces started in _move before this observer runs;
				# old.move independently verifies the full 60 fixed-step progression.
				check(not old.move.is_empty() and is_equal_approx(old.move.time+Config.STEP,0.5),"natural completed movement takes exactly sixty simulation ticks "+actor.id)

func number_equal(a, b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<0.000000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not number_equal(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not number_equal(a[index],b[index]): return false
		return true
	return a==b

func historical_report(report: Dictionary) -> Dictionary:
	# Only metadata added by this batch is excluded. Entire old combat metrics,
	# original times, HP, casualties and result still have to match independent07.
	var result: Dictionary=report.duplicate(true)
	for key in ["config","enemy_profile","enemy_parameters"]: result.erase(key)
	return result

func pause_snapshot(game) -> Dictionary:
	var actors := []
	for actor in game.actors:
		actors.append({"id":actor.id,"cell":actor.cell,"dead":actor.dead,"hp":game._hp(actor),"move":actor.move.duplicate(true),"target":actor.target,"cooldown":actor.cooldown,"think":actor.think,"age":actor.step_age,"wait":actor.step_wait.duplicate(true),"retarget":actor.step_retarget,"pose":actor.node.presentation.pose,"pose_time":actor.node.presentation.pose_time,"position":actor.node.position})
	return {"report":game.report().duplicate(true),"actors":actors,"resolved":game.resolve_count,"issued":game.movement_counts.duplicate(true),"completed":game.completed_counts.duplicate(true),"steps":game.audited_steps}

func natural(profile: String, formation: String, fps: int, sim_speed: int, pause_once: bool) -> Dictionary:
	var game=BalanceGame.new()
	game.enemy_profile=profile
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	if formation=="R":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=SUPPORT[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	roster(game,profile,"natural "+formation)
	game.auditor=Callable(self,"audit")
	check(game.start_battle(),"all original real actors start natural profile battle "+profile+" "+formation)
	game.speed=sim_speed
	var did_pause := false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/fps)
		if pause_once and not did_pause and game.elapsed>=1.0:
			var before: Dictionary=pause_snapshot(game)
			game.paused=true
			game.step(5)
			check(pause_snapshot(game)==before,"natural pause preserves HP/activity/request clocks and observer data "+profile+" "+formation)
			game.paused=false
			did_pause=true
	check(game.phase==game.Phase.RESULT and game.result_count==1,"natural profile battle reaches one actual result, never timeout victory "+profile+" "+formation)
	var report: Dictionary=game.report().duplicate(true)
	var rows := []
	var friendly_damage := 0.0
	var friendly_received := 0.0
	var friendly_healing := 0.0
	for actor in game.actors:
		var loss: float=game.received.get(actor.id,0.0)
		var heal: float=game.restored.get(actor.id,0.0)
		var hp: float=game._hp(actor)
		check(is_equal_approx(actor.hp_max-loss+heal,hp),"actual natural per-recipient damage/heal/remaining-HP ledger balances "+actor.id)
		check(is_equal_approx(float(game.damage_sources.get(actor.id,0.0)),float(game.metrics.damage.get(actor.id,0.0))),"real observed damage equals production resolved metric "+actor.id)
		check(is_equal_approx(float(game.heal_sources.get(actor.id,0.0)),float(game.metrics.healing.get(actor.id,0.0))),"real observed effective healing equals production metric "+actor.id)
		if actor.friendly:
			friendly_damage+=float(game.damage_sources.get(actor.id,0.0))
			friendly_received+=loss
			friendly_healing+=heal
		rows.append({"id":actor.id,"key":actor.key,"friendly":actor.friendly,"hp_max":actor.hp_max,"remaining_hp":hp,"dead":actor.dead,"cell":[actor.cell.x+1,actor.cell.y+1],"damage":game.damage_sources.get(actor.id,0.0),"received_damage":loss,"effective_healing_received":heal,"effective_healing_done":game.heal_sources.get(actor.id,0.0),"first_engagement":game.metrics.first_engagement.get(actor.id,{}),"first_received_hit":game.first_received.get(actor.id,{}),"issued_steps":game.movement_counts.get(actor.id,0),"completed_steps":game.completed_counts.get(actor.id,0)})
	var bear: Dictionary=game._record("E7")
	if profile=="bear":
		check(game.movement_counts.get("E7",0)>0 and game.completed_counts.get("E7",0)>0,"real bear naturally walks and lands, not merely a texture")
		check(not game.metrics.attack_times.get("E7",[]).is_empty() and game.damage_sources.get("E7",0.0)>0,"real bear naturally executes melee and inflicts actual damage")
		if game.victory: check(bear.dead and bear.move.is_empty() and bear.target.is_empty(),"natural bear victory requires actual bear death and claim cleanup")
	var historical_equal := false
	if profile=="legacy" and formation in ["A","B","C"]:
		historical_equal=number_equal(historical_report(report),historical_report(baseline[formation]))
		check(historical_equal,"legacy full natural report preserves independent07 baseline "+formation)
	var result := {"profile":profile,"formation":formation,"kind":"natural_all_original_production_AI","actor_count":game.actors.size(),"report":report,"units":rows,"steps":game.audited_steps,"issued_segments":game.movement_counts,"completed_segments":game.completed_counts,"resolved_recipient_effects":game.resolve_count,"friendly_actual_damage":friendly_damage,"friendly_received_damage":friendly_received,"friendly_effective_healing":friendly_healing,"legacy_independent07_equal":historical_equal}
	every_step_total+=game.audited_steps
	var saved: Dictionary=game.start_deployment.duplicate()
	game.retry()
	check(game.enemy_profile==profile and game.deployment==saved and game.phase==game.Phase.DEPLOY and game.elapsed==0 and game.speed==1 and not game.paused,"natural retry preserves selected profile and original deployment "+profile+" "+formation)
	roster(game,profile,"natural retry "+formation)
	check(game.actors.all(func(actor): return not actor.dead and actor.move.is_empty() and actor.target.is_empty() and actor.handoff.is_empty() and actor.step_wait.is_empty() and actor.step_serial==0 and actor.step_completed==0 and actor.cooldown==0),"natural retry clears all twelve/thirteen actor activities "+profile+" "+formation)
	game.free()
	return result

func run() -> void:
	# The independent baseline is a host sibling, not a packaged game resource.
	var reference_path: String=ProjectSettings.globalize_path("res://").path_join("../docs/release/QA_BOARD_STEPWISE_20261009.json")
	check(FileAccess.file_exists(reference_path),"independent07 host baseline exists")
	var reference=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	check(reference is Dictionary and reference.get("production","")=="b59227d","actual committed independent07 baseline loads")
	if not reference is Dictionary:
		quit(1)
		return
	for entry in reference.cases: baseline[entry.case]=entry.report
	check(baseline.has("A") and baseline.has("B") and baseline.has("C"),"baseline contains all original ABC full reports")
	for profile in PROFILES:
		for formation in ["A","B","C","R"]:
			var first: Dictionary=natural(profile,formation,37,1,false)
			var repeat: Dictionary=natural(profile,formation,60,2,true)
			check(number_equal(first,repeat),"whole natural report and actual recipient ledger repeat across FPS/2x/pause "+profile+" "+formation)
			first["schedules"]=[[37,1],[60,2]]
			first["repeat_equal"]=number_equal(first.report,repeat.report) and number_equal(first.units,repeat.units)
			natural_results.append(first)
	check(natural_results.size()==12,"all twelve profile/formation comparisons complete")
	var wins := {}
	for profile in PROFILES:
		wins[profile]=[]
		for result in natural_results:
			if result.profile==profile and result.report.victory: wins[profile].append(result.formation)
	# No arbitrary win assertion or automatic tuning: report all-bear losses for
	# the explicitly authorized bounded review/one additional arrangement.
	var file:=FileAccess.open("/tmp/board-balance-20261009-natural.json",FileAccess.WRITE)
	check(file!=null,"natural profile balance evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"D-20261009-002","coordinate_base":1,"natural_runs":24,"schedules":[[37,1],[60,2]],"paused_repeat":true,"all_AI_and_original_friendly_stats":true,"every_step_total":every_step_total,"baseline_source":"docs/release/QA_BOARD_STEPWISE_20261009.json","wins":wins,"cases":natural_results,"failures":failures},"\t"))
	print("BOARD_BALANCE natural_runs=24 comparisons=",natural_results.size()," wins=",wins," failures=",failures)
	quit(1 if failures else 0)
