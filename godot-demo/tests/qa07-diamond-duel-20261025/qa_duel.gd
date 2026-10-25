extends SceneTree
## 07 independent D-20261018-002 deployment/input/real-battle verification.
## Instantiates the real independent scene and drives its actual controller.
## Logical InputEvent and Button callbacks only; OS pointer/frame evidence is
## recorded separately and is NOT claimed here.
const Board = preload("res://scripts/data/diamond_duel_board.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const Units = preload("res://scripts/data/demo_units.gd")
const SCENE := "res://scenes/diamond_duel.tscn"
const LEFT := MOUSE_BUTTON_LEFT
const RIGHT := MOUSE_BUTTON_RIGHT

var checks := 0
var failures: Array[String] = []
var failed_samples := 0
var battles: Array = []
var deployment_case: Dictionary = {}
var output := "/tmp/qa07-duel-20261025/qa-duel.json"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failed_samples < 30:
			failed_samples += 1
			push_error(label)

func fresh():
	var game = load(SCENE).instantiate()
	root.add_child(game)
	game.set_process(false)
	if is_instance_valid(game.stage): game.stage.set_process(false)
	game.audio_feedback.enabled = false
	check(game.get_script().resource_path == "res://scripts/diamond_duel.gd", "actual independent production scene instantiated")
	return game

func actor(game, id: String) -> Dictionary:
	return game._record(id)

func click(game, cell: Vector2i, button := LEFT, move_to := true) -> void:
	var point: Vector2 = Board.center(cell)
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.position = point
	down.global_position = point
	down.pressed = true
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.position = point
	up.global_position = point
	up.pressed = false
	if button == RIGHT: game._input(down)
	else: game._unhandled_input(down)
	if move_to: game._unhandled_input(up)

func click_point(game, point: Vector2, button := LEFT, release := true) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.position = point
	down.global_position = point
	down.pressed = true
	game._unhandled_input(down)
	if release:
		var up := InputEventMouseButton.new()
		up.button_index = button
		up.position = point
		up.global_position = point
		up.pressed = false
		game._unhandled_input(up)

func deploy_pair(game, monk_cell: Vector2i, wolf_cell: Vector2i) -> bool:
	if not game.place("monk",monk_cell): return false
	return game.place("wolf",wolf_cell)

func same_number(a, b, eps := 0.000001) -> bool:
	return absf(float(a)-float(b)) <= eps

func close_value(a, b, eps := 0.0001) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(a)-float(b)) <= eps
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not close_value(a[key],b[key],eps): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not close_value(a[i],b[i],eps): return false
		return true
	return a == b

func snapshot(game) -> Dictionary:
	var cells := {}
	for item in game.actors: cells[item.id] = item.cell
	return {"phase":game.phase,"selected":game.selected,"paused":game.paused,"speed":game.speed,
		"setup":game.setup_specs.duplicate(true),"deployment":game.deployment.duplicate(true),
		"cells":cells,"report":game.report().duplicate(true)}

func deployment_and_input() -> void:
	var game = fresh()
	check(game.actors.size() == 2, "exactly two fixed actors")
	check(actor(game,"monk").key == "guard_monk" and actor(game,"wolf").key == "wolf", "roles are the requested monk and wolf")
	check(game.phase == game.Phase.DEPLOY, "boots in deployment")
	check(game.legal_cells().size() == 71 and game.legal_cells().all(func(cell): return Board.valid(cell)), "controller exposes the 71-cell instance mask")
	check(game.legal_cells().has(Vector2i(-1,-1)), "controller legal list includes negative real cells")
	check(game.hover_cell() == Board.INVALID, "headless hover off-board is rejected, not clamped")
	var legal := {}
	for cell in game.legal_cells(): legal[cell] = true
	# Every legal cell is a parseable placement target and every residual rim is not.
	var rejected_rim := 0
	for y in range(-8,9):
		for x in range(-8,9):
			var cell := Vector2i(x,y)
			if legal.has(cell): continue
			var center: Vector2 = Board.center(cell)
			var a: Rect2 = Board.ARENA
			if center.x >= a.position.x and center.x <= a.end.x and center.y >= a.position.y and center.y <= a.end.y:
				rejected_rim += 1
				check(not game.valid_cell(cell), "visible partial rim cell is not placeable "+str(cell))
	check(rejected_rim == 26, "26 visible partial rim cells are rejected by the instance mask")

	# Actual portrait-card callback selects only its fixed instance.
	game.ui.monk_button.pressed.emit()
	check(game.selected == "monk", "monk card callback selects monk")
	var monk_target := Vector2i(-2,1)
	check(legal.has(monk_target), "chosen deployment cell is legal")
	click(game,monk_target)
	check(actor(game,"monk").cell == monk_target, "logical mouse press places selected monk")
	check(game.selected.is_empty() and not game.pointer_drag, "successful placement clears selection and drag ownership")

	# Cross-army occupied cell is refused without moving either unit.
	game.ui.wolf_button.pressed.emit()
	check(game.selected == "wolf", "wolf card callback selects wolf")
	var before := snapshot(game)
	click(game,monk_target)
	check(snapshot(game) == before, "placing wolf onto the monk cell is refused and changes nothing")
	check(actor(game,"wolf").cell == Vector2i(3,0), "wolf keeps its original cell after refusal")
	check(game.selected == "wolf", "failed placement keeps selection for retry")

	# Right button cancels through the controller's native-style event path.
	var right := InputEventMouseButton.new()
	right.button_index = RIGHT
	right.position = Vector2.ZERO
	right.global_position = Vector2.ZERO
	right.pressed = true
	game._input(right)
	check(game.selected.is_empty(), "right mouse button cancels selection")
	game.select("monk")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game._unhandled_input(escape)
	check(game.selected.is_empty(), "Escape cancels selection without changing roster")

	# Real drag: press on the placed friendly unit, release over a different legal cell.
	game.select("monk")
	var from_cell: Vector2i = actor(game,"monk").cell
	var press := InputEventMouseButton.new()
	press.button_index = LEFT
	press.position = Board.center(from_cell)
	press.global_position = press.position
	press.pressed = true
	game._unhandled_input(press)
	check(game.pointer_drag and game.selected == "monk", "press on own placed unit starts a real drag")
	var drag_target := Vector2i(-4,2)
	check(legal.has(drag_target), "drag destination is a complete cell")
	click_point(game,Board.center(drag_target),LEFT,true)
	check(actor(game,"monk").cell == drag_target and game.selected.is_empty(), "drag release re-places exactly once and clears selection")

	# Failed off-board release ends the gesture but does not move or clear silently.
	game.select("monk")
	var press2 := InputEventMouseButton.new()
	press2.button_index = LEFT
	press2.position = Board.center(drag_target)
	press2.global_position = press2.position
	press2.pressed = true
	game._unhandled_input(press2)
	click_point(game,Vector2(280,588),LEFT,true)
	check(actor(game,"monk").cell == drag_target and not game.pointer_drag, "release over outer stone frame ends drag without relocation")

	# Enemy placement uses the same inverse and can be freely moved in deployment.
	game.ui.wolf_button.pressed.emit()
	var wolf_target := Vector2i(2,-1)
	click(game,wolf_target)
	check(actor(game,"wolf").cell == wolf_target and game.selected.is_empty(), "enemy card placement uses the same inverse and clears selection")

	# Start validation: duplicate or residual cells are rejected before battle.
	var wolf_spec: Dictionary = game._spec("wolf")
	var saved: Vector2i = wolf_spec.cell
	wolf_spec.cell = actor(game,"monk").cell
	check(not game.start_battle() and game.phase == game.Phase.DEPLOY, "duplicate start cells are rejected")
	wolf_spec.cell = Vector2i(0,6)
	check(not game.start_battle() and game.phase == game.Phase.DEPLOY, "partial rim start cell is rejected")
	wolf_spec.cell = saved

	# Start through the real button and verify the deployment lock.
	var start_cells := {"monk":actor(game,"monk").cell,"wolf":actor(game,"wolf").cell}
	game.ui.start_button.pressed.emit()
	check(game.phase == game.Phase.BATTLE, "actual start button starts the real battle")
	check(game.start_specs.size() == 2 and game.start_specs[0].cell == start_cells.monk, "start snapshot preserves both start cells")
	var locked := {"deployment":game.deployment.duplicate(true),"setup":game.setup_specs.duplicate(true),
		"cells":snapshot(game).cells,"report":game.report().duplicate(true)}
	var empty_cell := Vector2i(5,0)
	check(legal.has(empty_cell), "lock probe cell is legal")
	game.ui.monk_button.pressed.emit() # cards remain browsable during battle
	click(game,empty_cell)
	var after_lock_click := {"deployment":game.deployment.duplicate(true),"setup":game.setup_specs.duplicate(true),
		"cells":snapshot(game).cells,"report":game.report().duplicate(true)}
	check(after_lock_click == locked, "battle locks formation even after a card callback and board click")
	check(not game.place("monk",empty_cell), "data-level place is also locked during battle")
	# The actual shared BFS finds a real range-1 attack cell under the instance mask.
	var approach: Array = game._path(actor(game,"monk"),actor(game,"wolf").cell,1)
	check(not approach.is_empty() and approach.all(func(cell): return Board.valid(cell)), "real shared path uses only complete cells")
	if not approach.is_empty():
		check(Config.distance(approach.back(),actor(game,"wolf").cell) == 1 and approach.back() != actor(game,"wolf").cell, "real shared path ends in a non-overlapping range-1 attack cell")
	# Residual rim cells cannot be entered through the actual movement entry.
	var before_rim: Vector2i = actor(game,"monk").cell
	check(not game._move(actor(game,"monk"),Vector2i(0,6)), "actual movement refuses a residual rim tile")
	check(actor(game,"monk").cell == before_rim and actor(game,"monk").move.is_empty(), "refused rim movement leaves the unit untouched")

	# Pause freezes the complete report and setup.
	game.ui.pause_button.pressed.emit()
	check(game.paused, "pause button pauses")
	var paused_state := snapshot(game)
	game.step(3.0)
	check(snapshot(game) == paused_state, "pause freezes elapsed, report and setup for 3 simulated seconds")
	game.ui.pause_button.pressed.emit()
	check(not game.paused, "pause button resumes")
	game.ui.pause_button.pressed.emit()
	check(game.paused, "pause can be entered again")
	game.ui.retry_button.pressed.emit()
	check(not game.paused and game.elapsed == 0.0 and game.speed == 1, "same-formation retry from pause clears pause/time/speed")

	# Speed button doubles the real accumulator; 0.25 wall seconds becomes 0.5 battle seconds.
	game.ui.retry_button.pressed.emit()
	game.accumulator = 0.0
	game.speed = 1
	game.step(0.25)
	var one_x: float = game.elapsed
	game.ui.retry_button.pressed.emit()
	game.accumulator = 0.0
	game.ui.speed_button.pressed.emit()
	check(game.speed == 2, "speed button switches to 2x")
	game.step(0.25)
	check(close_value(game.elapsed,one_x*2.0,1.0/120.0), "2x speed advances simulated battle time twice as fast (%f vs %f)" % [one_x,game.elapsed])
	# Restore a clean snapshot for retry checks.
	game.ui.retry_button.pressed.emit()
	game.accumulator = 0.0
	game.step(0.3)
	check(game.actors.any(func(item): return not item.move.is_empty()), "real movement is in flight before retry")
	game.ui.retry_button.pressed.emit()
	check(game.phase == game.Phase.BATTLE and game.elapsed == 0.0 and not game.paused, "retry restarts immediately at zero battle time")
	check(actor(game,"monk").cell == start_cells.monk and actor(game,"wolf").cell == start_cells.wolf, "retry restores the exact saved start cells")
	check(game.actors.all(func(item): return item.move.is_empty() and item.target.is_empty() and item.cooldown == 0.0 and item.step_serial == 0 and item.step_wait.is_empty() and item.handoff.is_empty()), "retry clears all movement/target/cooldown/reservation state")
	check(game.step_requests.is_empty() and game.combat.strikes.is_empty() and game.combat.missiles.is_empty() and game.combat.marks.is_empty(), "retry clears pending attacks/effects")
	check(game.audio_feedback.seen.is_empty(), "retry clears inherited audio serial ledger")

	# Return to deployment restores the saved pair and leaves it editable.
	game.step(0.2)
	game.ui.pause_button.pressed.emit()
	check(game.paused, "battle can be paused before returning")
	game.ui.return_button.pressed.emit()
	check(game.phase == game.Phase.DEPLOY and not game.paused, "return button stops battle, clears pause and unlocks deployment")
	check(actor(game,"monk").cell == start_cells.monk and actor(game,"wolf").cell == start_cells.wolf, "return restores the saved start formation")
	check(game.selected.is_empty() and game.setup_specs.size() == 2, "return leaves a clean editable two-unit roster")
	check(game.elapsed == 0.0 and game.speed == 1 and game.result_count == 0, "return clears elapsed/speed/result state")
	check(game.actors.all(func(item): return item.move.is_empty() and item.cooldown == 0.0 and item.step_serial == 0 and item.step_wait.is_empty() and item.handoff.is_empty() and item.target.is_empty()), "return clears movement/cooldown/step/target state")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty() and game.combat.marks.is_empty() and game.audio_feedback.seen.is_empty(), "return clears pending effects and inherited audio ledger")

	# Original catalogs and stats are not changed by screen geometry.
	for item in game.actors:
		var expected: Dictionary = Units.HEROES.guard_monk if item.id == "monk" else Config.enemy_stats("wolf","bear")
		check(item.hp_max == expected.hp and item.damage == expected.damage and item.interval == expected.interval and item.reach == expected.range,
			"original catalog hp/damage/interval/range retained "+item.id)
		check(item.walk == 0.5 and item.node.move_interval == 0.5, "original 0.50-second step retained "+item.id)
	check(game.report().config == "diamond-duel-v1" and game.report().legal_cell_count == 71, "report identifies instance config and 71-cell mask")
	check(not game.add_units(true,"guard_monk",1) and not game.add_units(false,"boar",1), "sample refuses extra units through inherited API")
	deployment_case = {"legal_cells":game.legal_cells().size(),"rim_rejected":rejected_rim,"start_cells":{"monk":[start_cells.monk.x,start_cells.monk.y],"wolf":[start_cells.wolf.x,start_cells.wolf.y]},"one_x_seconds":one_x,"OS_mouse":false}
	game.free()

func main_catalog(game) -> Dictionary:
	return {"monk":game._record("monk"),"wolf":game._record("wolf")}

func natural(label: String, monk_cell: Vector2i, wolf_cell: Vector2i, fps := 120, speed := 1, pause_once := false) -> Dictionary:
	var game = fresh()
	check(game.phase == game.Phase.DEPLOY, "natural starts in deployment "+label)
	check(deploy_pair(game,monk_cell,wolf_cell), "natural pair is deployed through the real placement API "+label)
	check(actor(game,"monk").cell == monk_cell and actor(game,"wolf").cell == wolf_cell, "natural pair actually occupies requested cells "+label)
	var contacts: Array = []
	var last_hp := {"monk":310.0,"wolf":180.0}
	var serials := {"monk":{},"wolf":{}}
	var serial_order := {"monk":[],"wolf":[]}
	var bad_contacts: Array[String] = []
	game.combat.resolved.connect(func(target, amount, healing, event):
		var source: Dictionary = game._by_node(event.source)
		var recipient: Dictionary = game._by_node(target)
		var source_id := str(source.get("id",""))
		var target_id := str(recipient.get("id",""))
		var serial := int(event.get("serial",-1))
		var prior: float = float(last_hp.get(target_id,0.0))
		var after: float = float(recipient.node.health) if not recipient.is_empty() else 0.0
		var row := {"time":game.elapsed,"source":source_id,"target":target_id,"serial":serial,
			"amount":float(amount),"healing":healing,"prior_hp":prior,"after_hp":after,
			"effective":prior-after,"source_cell":[source.get("cell",Vector2i(-9999,-9999)).x,source.get("cell",Vector2i(-9999,-9999)).y],
			"target_cell":[recipient.get("cell",Vector2i(-9999,-9999)).x,recipient.get("cell",Vector2i(-9999,-9999)).y]}
		contacts.append(row)
		last_hp[target_id]=after
		if source_id.is_empty() or target_id.is_empty(): bad_contacts.append("unknown source/target "+label)
		if healing: bad_contacts.append("unexpected healing "+label)
		if serials[source_id].has(serial): bad_contacts.append("duplicate serial "+str(serial)+" "+label)
		serials[source_id][serial]=true
		serial_order[source_id].append(serial)
		if not same_number(amount,14.0) and not same_number(amount,17.0): bad_contacts.append("unexpected damage %.3f %s" % [amount,label])
		if not same_number(amount,14.0 if source_id=="monk" else 17.0): bad_contacts.append("damage does not match original catalog "+source_id+" "+label)
		if Config.distance(source.get("cell",Vector2i(9999,9999)),recipient.get("cell",Vector2i(9999,9999))) > int(source.get("reach",1)):
			bad_contacts.append("contact outside real range-1 "+label)
		if source.get("cell") == recipient.get("cell"): bad_contacts.append("same-cell contact "+label)
		if prior-after > amount+0.000001: bad_contacts.append("HP loss exceeds dealt damage "+label)
		if source_id=="monk" and target_id!="wolf": bad_contacts.append("monk hit non-wolf "+label)
		if source_id=="wolf" and target_id!="monk": bad_contacts.append("wolf hit non-monk "+label))
	check(game.start_battle(), "natural real battle starts "+label)
	var dt := 1.0/float(fps)
	var moves := {}
	var completed_steps := 0
	var occupancy_safe := true
	var legal_safe := true
	var scale_safe := true
	var duration_safe := true
	var landing_safe := true
	var did_pause := false
	var prior_cells := {"monk":monk_cell,"wolf":wolf_cell}
	var paused_equal := true
	var max_elapsed := 0.0
	while game.phase == game.Phase.BATTLE and game.elapsed < 60.0:
		game.step(dt)
		var elapsed: float = game.elapsed
		max_elapsed = maxf(max_elapsed,elapsed)
		var occupied := {}
		for item in game.actors:
			if not game._active(item): continue
			legal_safe = legal_safe and Board.valid(item.cell)
			occupancy_safe = occupancy_safe and not occupied.has(item.cell)
			occupied[item.cell] = item.id
			scale_safe = scale_safe and item.node.scale.is_equal_approx(Vector2.ONE)
			# A landing and the following departure can happen in the same
			# simulated tick, so segments are tracked by the controller's own
			# move_serial rather than by observing an empty move slot.
			var sim_step := dt*float(speed)
			var low := 0.5-sim_step-1.0/120.0-0.0001
			var high := 0.5+sim_step+0.0001
			if item.move.is_empty():
				if moves.has(item.id):
					var record: Dictionary = moves[item.id]
					var observed: float = elapsed-record.observed_start
					check(item.cell == record.to, "landing ends at the declared destination "+label+" "+item.id)
					check(same_number(record.duration,0.5), "movement segment duration is exactly 0.50 seconds "+label)
					duration_safe = duration_safe and same_number(record.duration,0.5)
					check(observed >= low and observed <= high, "observed cell travel time is 0.50 seconds (%.4f) %s" % [observed,label])
					landing_safe = landing_safe and observed >= low and observed <= high
					completed_steps += 1
					moves.erase(item.id)
			else:
				var from_cell: Vector2i = item.move.from
				var to_cell: Vector2i = item.move.to
				var serial := int(item.move_serial)
				legal_safe = legal_safe and Board.valid(from_cell) and Board.valid(to_cell)
				check(Config.distance(from_cell,to_cell) == 1, "each movement is one logical four-neighbour "+label)
				duration_safe = duration_safe and same_number(item.move.duration,0.5)
				if moves.has(item.id) and int(moves[item.id].serial) != serial:
					var previous: Dictionary = moves[item.id]
					var observed: float = elapsed-previous.observed_start
					check(item.cell == previous.to, "chained landing starts from the previous destination "+label+" "+item.id)
					check(observed >= low and observed <= high, "observed cell travel time is 0.50 seconds (%.4f) %s" % [observed,label])
					landing_safe = landing_safe and observed >= low and observed <= high
					completed_steps += 1
					moves.erase(item.id)
				if not moves.has(item.id):
					moves[item.id] = {"serial":serial,"observed_start":elapsed,"from":from_cell,"to":to_cell,"duration":float(item.move.duration)}
				var record: Dictionary = moves[item.id]
				record.to = to_cell
				var expected_position: Vector2 = Board.point(Vector2(from_cell).lerp(Vector2(to_cell),minf(1.0,float(item.move.time)/float(item.move.duration))))
				check(item.node.position.distance_to(expected_position) < 0.01, "display interpolation follows the logical half-cell fraction "+label)
			if prior_cells.has(item.id) and prior_cells[item.id] != item.cell:
				check(Config.distance(prior_cells[item.id],item.cell) == 1, "committed landing is one logical four-neighbour "+label)
			prior_cells[item.id] = item.cell
		# Both source and destination are reserved during a half-cell move.
		for item in game.actors:
			if not game._active(item) or item.move.is_empty(): continue
			occupancy_safe = occupancy_safe and (not occupied.has(item.move.to) or occupied[item.move.to] == item.id)
			occupied[item.move.to] = item.id
		if pause_once and not did_pause and game.elapsed > 0.2:
			game.toggle_pause()
			var frozen: Dictionary = game.report().duplicate(true)
			game.step(3.0)
			paused_equal = paused_equal and game.report() == frozen and game.elapsed > 0.0
			game.toggle_pause()
			did_pause = true
	check(occupancy_safe, "no double-cell occupancy for the whole natural fight "+label)
	check(legal_safe, "every active cell and destination stays in the 71-cell mask "+label)
	check(scale_safe, "actor scale stays exactly 1 during natural fight "+label)
	check(duration_safe and landing_safe, "every cell still takes 0.50 seconds in the real fight "+label)
	check(bad_contacts.is_empty(), "every contact is one adjacent original-damage hit "+label)
	check(game.phase == game.Phase.RESULT and game.result_count == 1, "natural fight reaches exactly one real result "+label)
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty(), "result clears pending strike/missile state "+label)
	check(not contacts.is_empty(), "natural fight really produced contacts "+label)
	check(int(game.combat.counts.hits) == contacts.size(), "resolved contact count equals inherited hit counter "+label)
	check(int(game.combat.counts.attacks) >= int(game.combat.counts.hits)+int(game.combat.counts.cancelled), "applied plus cancelled never exceeds issued requests "+label)
	check(int(game.combat.counts.heals) == 0 and int(game.combat.counts.projectiles) == 0, "no fabricated healing or projectile in this melee duel "+label)
	for id in ["monk","wolf"]:
		var times: Array = game.metrics.attack_times.get(id,[])
		var interval: float = float(game._record(id).interval)
		var gap_ok := true
		for index in range(1,times.size()):
			gap_ok = gap_ok and float(times[index])-float(times[index-1]) >= interval-0.000001
		check(gap_ok, "attack interval unchanged for "+id+" "+label)
		var ordered: Array = serial_order[id].duplicate()
		var unique_ordered := true
		for index in range(1,ordered.size()): unique_ordered = unique_ordered and ordered[index] > ordered[index-1]
		check(unique_ordered, "attack serials strictly increase once per source "+id+" "+label)
	var monk: Dictionary = game._record("monk")
	var wolf: Dictionary = game._record("wolf")
	var monk_hp: float = 0.0 if monk.dead else float(monk.node.health)
	var wolf_hp: float = 0.0 if wolf.dead else float(wolf.node.health)
	check(monk_hp == 0.0 or wolf_hp == 0.0, "at least one side is eliminated "+label)
	check(game.victory == (monk_hp > 0.0), "victory flag means the monk actually survived "+label)
	check(not contacts.is_empty() and float(contacts[0].time) >= 0.0, "first contact timestamp recorded "+label)
	var report: Dictionary = game.report().duplicate(true)
	var trace := {"contacts":contacts,"attack_times":game.metrics.attack_times.duplicate(true),"counts":game.combat.counts.duplicate(true)}
	var opened := {"label":label,"monk":monk_cell,"wolf":wolf_cell,"fps":fps,"speed":speed,"paused":did_pause,
		"start_distance":Config.distance(monk_cell,wolf_cell),"result":("monk_win" if game.victory else "wolf_win"),
		"seconds":game.elapsed,"monk_hp":monk_hp,"wolf_hp":wolf_hp,"result_count":game.result_count,
		"contacts":contacts.size(),"attacks":int(game.combat.counts.attacks),"hits":int(game.combat.counts.hits),
		"cancelled":int(game.combat.counts.cancelled),"completed_steps":completed_steps,
		"first_contact":float(contacts[0].time) if not contacts.is_empty() else -1.0,
		"max_elapsed_observed":max_elapsed,"paused_report_frozen":paused_equal,
		"report":report,"trace":trace}
	# Retry after a real result restores the exact saved pair and a clean battle.
	game.retry()
	check(game.phase == game.Phase.BATTLE and game.elapsed == 0.0 and not game.paused, "post-result retry starts a fresh battle "+label)
	check(actor(game,"monk").cell == monk_cell and actor(game,"wolf").cell == wolf_cell, "post-result retry restores exact pair "+label)
	check(game.actors.all(func(item): return item.move.is_empty() and item.step_wait.is_empty() and item.handoff.is_empty() and item.target.is_empty()), "post-result retry clears movement/target reservation state "+label)
	game.free()
	battles.append(opened)
	return opened

func _initialize() -> void:
	call_deferred("run")

func defeat_path_probe() -> Dictionary:
	# Clearly synthetic: the natural 1v1 always ends with the monk surviving at the
	# shipped numbers, so the loss branch is exercised with a test-only low-HP monk.
	var game = fresh()
	check(deploy_pair(game,Vector2i(-3,0),Vector2i(3,0)), "defeat probe deploys the default pair")
	check(game.start_battle(), "defeat probe starts a real battle")
	var monk: Dictionary = actor(game,"monk")
	monk.node.health = 10.0
	var contacts: Array = [0]
	game.combat.resolved.connect(func(_target,_amount,healing,_event):
		if not healing: contacts[0] += 1)
	var guard := 0
	while game.phase == game.Phase.BATTLE and game.elapsed < 60.0 and guard < 9000:
		game.step(1.0/120.0)
		guard += 1
	check(game.phase == game.Phase.RESULT and game.result_count == 1, "loss branch reaches exactly one result")
	check(not game.victory and actor(game,"monk").node.health == 0.0 and actor(game,"wolf").node.health > 0.0, "loss branch ends with monk eliminated and wolf alive")
	check(contacts[0] > 0, "loss branch still uses a real adjacent contact")
	check(str(game.ui.result_summary.text).contains("山狼获胜"), "result UI reports the wolf winner")
	game.retry()
	check(game.phase == game.Phase.BATTLE and actor(game,"monk").node.health == 310.0 and game.elapsed == 0.0, "retry after loss restores full original HP and fresh battle")
	var row := {"synthetic_low_hp":true,"seconds":game.elapsed,"monk_hp_after":actor(game,"monk").node.health,"contacts":contacts[0]}
	game.free()
	return row

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	root.size = Vector2i(1920,1080)
	var started := Time.get_ticks_msec()
	deployment_and_input()
	var far := natural("SE_NW_far",Vector2i(-3,0),Vector2i(3,0))
	var near := natural("NW_SE_near",Vector2i(1,0),Vector2i(-1,0))
	var other := natural("SW_NE_far",Vector2i(0,-3),Vector2i(0,3))
	var corner := natural("corner_extreme",Vector2i(-3,3),Vector2i(3,-3))
	var rim := natural("rim_edge",Vector2i(1,4),Vector2i(1,-4))
	var defeat := defeat_path_probe()
	var paused := natural("SE_NW_far_paused_2x",Vector2i(-3,0),Vector2i(3,0),30,2,true)
	check(paused.paused, "paused/2x run actually paused")
	check(paused.paused_report_frozen, "pause froze the full report for three simulated seconds")
	check(close_value(paused.report,far.report,0.0001), "paused/2x run preserves the full battle report")
	check(close_value(paused.trace.attack_times,far.trace.attack_times,0.0001), "paused/2x run preserves all attack request times")
	var same_contacts := true
	if far.trace.contacts.size() != paused.trace.contacts.size():
		same_contacts = false
	else:
		for index in far.trace.contacts.size():
			var a: Dictionary = far.trace.contacts[index]
			var b: Dictionary = paused.trace.contacts[index]
			same_contacts = same_contacts and a.source == b.source and a.target == b.target and a.serial == b.serial and same_number(a.amount,b.amount) and same_number(a.time,b.time,0.0001)
	check(same_contacts, "paused/2x run preserves the complete contact sequence")

	var report := {
		"scope":"07 independent D002 deployment/input/real battles",
		"headless_logical_input":true,
		"OS_mouse":false,
		"native_window":false,
		"checks":checks,
		"failures":failures,
		"deployment":deployment_case,
		"battle_count":battles.size(),
		"defeat_probe":defeat,
		"battles":battles,
		"elapsed_ms":Time.get_ticks_msec()-started}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("QA07_DUEL checks=",checks," battles=",battles.size()," failures=",failures.size()," out=",output)
	quit(1 if failures else 0)
