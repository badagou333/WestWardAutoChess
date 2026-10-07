extends "res://tests/board_trial_ai_test.gd"
## Natural 12-actor runs plus isolated, fully live two-sided AI movement fixtures.
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const IDS := ["guard_monk","E1","E2","E3","E4"]
const VIDEO := [Vector2i(1,4),Vector2i(6,4),Vector2i(1,3),Vector2i(1,5),Vector2i(2,4),Vector2i(3,4)]
var evidence := {}
var reports := []
var old_video := {}

func cell_data(cell: Vector2i) -> Array: return [cell.x+1,cell.y+1]

func sample(game) -> Array:
	var result := []
	for id in IDS:
		var actor: Dictionary = game._record(id)
		var target: Dictionary = game._record(actor.target)
		var route := []
		for cell in actor.route: route.append(cell_data(cell))
		var move := {}
		if not actor.move.is_empty():
			move = {"from":cell_data(actor.move.from),"to":cell_data(actor.move.to),
				"time":actor.move.time,"duration":actor.move.duration,"serial":actor.move_serial}
		result.append({"id":id,"cell":cell_data(actor.cell),"target":actor.target,
			"target_cell":cell_data(target.cell) if not target.is_empty() else [],
			"move":move,"completed":actor.move_completed,"route":route,
			"endpoint":route.back() if not route.is_empty() else [],"planned_against":cell_data(actor.route_goal),
			"handoff":actor.handoff.duplicate(),"blocked_seconds":actor.blocked_elapsed,
			"pose":actor.node.presentation.pose,"cooldown":actor.cooldown,"mode":actor.mode,
			"dead":actor.dead,"hp":game._hp(actor),"attacks":game.metrics.attack_times.get(id,[]).size()})
	return result

func signature(state: Array) -> String:
	var key: Array = state.duplicate(true)
	for actor in key:
		actor.erase("cooldown")
		actor.erase("blocked_seconds")
		if not actor.move.is_empty(): actor.move.erase("time")
	return JSON.stringify(key)

func verify_step(game, before: Array, after: Array) -> void:
	ownership(game)
	for index in range(IDS.size()):
		var old: Dictionary = before[index]
		var now: Dictionary = after[index]
		var actor: Dictionary = game._record(now.id)
		if not old.move.is_empty() and not now.dead:
			if not now.move.is_empty() and old.move.serial==now.move.serial:
				check(now.cell==old.cell and now.move.from==old.move.from and now.move.to==old.move.to,"live segment never reverses/cancels half a cell")
			else: check(now.cell==old.move.to,"completed segment commits its exact reserved destination")
		if now.attacks>old.attacks:
			var target: Dictionary = game._record(now.target)
			check(actor.move.is_empty() and not target.is_empty() and Config.distance(actor.cell,target.cell)<=actor.reach,"all five melee attacks use actual range at a grid boundary")
		if not actor.move.is_empty() and (old.move.is_empty() or old.move.serial!=actor.move_serial):
			var target: Dictionary = game._record(actor.target)
			if not target.is_empty(): check(Config.distance(actor.cell,target.cell)>actor.reach,"new pursuit step never leaves an actual attack position for cooldown")
		if not actor.handoff.is_empty():
			var target: Dictionary = game._record(actor.target)
			check(actor.move.is_empty() and actor.node.presentation.pose!="basic_attack" and target.target==actor.id,"handoff does not cancel own segment/attack or manufacture pairing")
			check(Config.distance(actor.cell,target.cell)==2 and target.move_completed<actor.handoff.segment,"handoff only holds its observed incomplete segment at actual distance two")
			check(now.attacks==old.attacks,"distance-two waiting is not extra attack range")
			if actor.friendly and not old.handoff.is_empty(): check(now.blocked_seconds==old.blocked_seconds,"handoff steps do not accrue monk obstruction")

func natural(key: String, fps: int, speed: int, record: bool, pause_once: bool) -> Dictionary:
	var game = fresh()
	if key=="video":
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=VIDEO[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(key)
	check(game.start_battle(),"natural deployment starts without modifying AI/stats/enemies")
	var trace := []
	var previous := sample(game)
	var last_signature := signature(previous)
	trace.append({"time":0.0,"actors":previous})
	var paused_once := false
	var crossed_boundary := false
	var first_contact := false
	var at_twenty := {}
	# External frame grouping varies; every production STEP is still observed.
	var frame_accumulator := 0.0
	while game.phase==game.Phase.BATTLE and game.elapsed<120:
		frame_accumulator += float(speed)/fps
		while frame_accumulator+0.00000001>=Config.STEP and game.phase==game.Phase.BATTLE:
			frame_accumulator -= Config.STEP
			game.step(Config.STEP)
			var current := sample(game)
			verify_step(game,previous,current)
			var current_signature := signature(current)
			if record and current_signature!=last_signature:
				trace.append({"time":game.elapsed,"actors":current})
			last_signature = current_signature
			previous = current
			if key=="video" and not crossed_boundary and game.elapsed+0.00000001>=151*Config.STEP:
				var monk: Dictionary = game._record("guard_monk")
				check(monk.cell==Vector2i(6,3) and monk.move.is_empty() and monk.target=="E3" and monk.handoff.get("target","")=="E3","video 1.258 boundary waits at 7,4 instead of issuing 8,4")
				crossed_boundary = true
			if key=="video" and not first_contact and game.elapsed+0.00000001>=169*Config.STEP:
				var monk: Dictionary = game._record("guard_monk")
				check(monk.cell==Vector2i(6,3) and game._record("E3").cell==Vector2i(6,2) and monk.move.is_empty() and monk.handoff.is_empty() and monk.node.presentation.pose=="basic_attack","video E3 actual 7,3 landing immediately starts contact at 1.408")
				first_contact = true
			if at_twenty.is_empty() and game.elapsed>=20.0: at_twenty=game.report().duplicate(true)
			if pause_once and not paused_once and game.elapsed>=1.3:
				var held := sample(game)
				var report: Dictionary = game.report().duplicate(true)
				game.paused = true
				game.step(5)
				check(sample(game)==held and game.report()==report,"pause freezes observed segment, handoff, cooldown and full simulation")
				game.paused = false
				paused_once = true
	var report: Dictionary = game.report().duplicate(true)
	check(game.phase==game.Phase.RESULT and game.result_count==1,"live five-melee natural "+key+" terminates without timeout or permanent waiting")
	if key=="video": check(crossed_boundary and first_contact,"video exact boundary and real landing were observed")
	if record:
		evidence[key]={"kind":"natural_all_12_production_AI","coordinate_base":1,"frame_schedule":[fps,speed],
			"trace_encoding":"complete state changes; unchanged discrete states persist until next event; continuous move time/cooldown sampled at each event; all STEP invariants checked",
			"trace":trace,"report":report,"at_20_seconds":at_twenty}
	game.retry()
	check(game.actors.all(func(actor): return actor.handoff.is_empty() and actor.move_serial==0 and actor.move_completed==0 and actor.route.is_empty()),"retry rebuilds all activity, wait and path state")
	game.free()
	return report

func pair_fixture(id: String, mirrored: bool, fast_monk: bool, reverse_order: bool):
	var game = fresh()
	isolate(game,["tangseng","guard_monk",id])
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	var monk: Dictionary = game._record("guard_monk")
	var enemy: Dictionary = game._record(id)
	game._set_cell(monk,Vector2i(5,3))
	# Mirrored off-axis starts keep more than one legal approach, so reversing
	# update order cannot legitimately seal monk's ONLY initial attack route.
	game._set_cell(enemy,Vector2i(3,2) if mirrored else Vector2i(7,4))
	game.start_battle()
	# Explicit movement-speed fixtures only, not natural balance evidence.
	monk.walk=0.35 if fast_monk else 0.8
	enemy.walk=0.8 if fast_monk else 0.35
	if reverse_order: game.actors.reverse()
	return game

func live_pairs() -> void:
	for id in ["E1","E2","E3","E4"]:
		for mirrored in [false,true]:
			for fast in [false,true]:
				for reversed in [false,true]:
					var game = pair_fixture(id,mirrored,fast,reversed)
					var previous := sample(game)
					var movements := {"guard_monk":0,id:0}
					var contact_cells := {}
					while game.phase==game.Phase.BATTLE and game.elapsed<4:
						game.step(Config.STEP)
						var current := sample(game)
						verify_step(game,previous,current)
						previous=current
						for actor_id in ["guard_monk",id]:
							var actor: Dictionary = game._record(actor_id)
							movements[actor_id]=actor.move_serial
							if actor.node.presentation.pose=="basic_attack":
								if not contact_cells.has(actor_id): contact_cells[actor_id]=actor.cell
								check(actor.cell==contact_cells[actor_id] and actor.move.is_empty(),"live mutual melee contact never begins a pointless circuit")
					check(movements.guard_monk>0 and movements[id]>0 and contact_cells.size()==2,"wolf/boar mirrored unequal-speed/order fixture runs both real pursuit and both real attacks")
					evidence["pair_%s_%s_%s_%s" % [id,mirrored,fast,reversed]]={"kind":"isolated_live_both_AI_speed_fixture","moves":movements,"contact_cells":str(contact_cells),"report":game.report()}
					game.free()

func run() -> void:
	if FileAccess.file_exists("/tmp/qa-monk-user-video-trace.json"):
		old_video=JSON.parse_string(FileAccess.get_file_as_string("/tmp/qa-monk-user-video-trace.json")).report
	for key in ["video","A","B","C"]:
		var reference := natural(key,30,1,true,false)
		var repeated := natural(key,120,2,false,true)
		check(reference==repeated,"entire natural "+key+" report/times reproducible under 30/120 frame groups, 2x and pause")
		# Also use both public frame schedules, not only fine-grained observation.
		for schedule in [[30,1],[120,2]]:
			var game = fresh()
			if key=="video":
				game.deployment.clear()
				for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=VIDEO[index]-Vector2i.ONE
				game._reset_roster()
			else: game.load_formation(key)
			game.start_battle()
			game.speed=schedule[1]
			while game.phase==game.Phase.BATTLE and game.elapsed<120: game.step(1.0/schedule[0])
			check(game.report()==reference,"public grouped step yields exact natural "+key+" report")
			game.free()
		reports.append({"formation":key,"report":reference})
	live_pairs()
	var file := FileAccess.open("/tmp/board-d006-melee-traces.json",FileAccess.WRITE)
	var old_complete: Variant = null
	if FileAccess.file_exists("/tmp/board-d006-old-video-report.json"):
		old_complete=JSON.parse_string(FileAccess.get_file_as_string("/tmp/board-d006-old-video-report.json"))
	file.store_string(JSON.stringify({"rule":Melee.RULE,"old_video_snapshot_only":old_video,"old_video_natural_baseline":old_complete,
		"verified_public_schedules":[[30,1],[120,2]],"paused_fine_step_repeat":true,"cases":evidence,"failures":failures}))
	file=FileAccess.open("/tmp/board-d006-comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"config":Config.VERSION,"comparisons":reports,"failures":failures},"\t"))
	print("BOARD_MELEE_HANDOFF natural=4 live_pairs=32 failures=",failures)
	quit(1 if failures else 0)
