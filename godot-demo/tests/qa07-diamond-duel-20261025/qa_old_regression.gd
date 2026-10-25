extends SceneTree
## 07 independent regression for the shared hooks changed by D-20261018-002.
## Old rectangular board, legacy board and audio audition must keep their 84-cell
## domain, placement/input rules, 0.50-second steps and original catalogs.
const Config = preload("res://scripts/data/board_trial_config.gd")
const Board = preload("res://scripts/data/diamond_duel_board.gd")

var checks := 0
var failures: Array[String] = []
var failed_samples := 0
var output := "/tmp/qa07-duel-20261025/qa-old.json"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failed_samples < 25:
			failed_samples += 1
			push_error(label)

func _initialize() -> void:
	call_deferred("run")

func fresh(path: String):
	var node = load(path).instantiate()
	root.add_child(node)
	node.set_process(false)
	if node.has_method("get") and node.get("stage") != null and is_instance_valid(node.stage):
		node.stage.set_process(false)
	if node.get("audio_feedback") != null: node.audio_feedback.enabled = false
	return node

func logical_click(game, cell: Vector2i) -> void:
	var point: Vector2 = Config.center(cell)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		game._unhandled_input(event)

func chapter_board() -> Dictionary:
	var game = fresh("res://scenes/board_trial.tscn")
	check(game.get_script().resource_path == "res://scripts/board_depth.gd", "actual main depth board scene boots")
	check(game.phase == game.Phase.DEPLOY, "main board boots in deployment")
	check(game.actors.size() == 13, "main board still has six heroes plus seven bear-profile enemies")
	check(game.legal_cells().size() == 84, "instance legal cells still expose the 12x7=84 domain")
	var all_legacy := true
	var all_valid := true
	for cell in game.legal_cells():
		all_legacy = all_legacy and Config.valid(cell)
		all_valid = all_valid and game.valid_cell(cell) == Config.valid(cell)
	check(all_legacy and all_valid, "old board hook exactly matches the original 12x7 legal domain")
	check(game.report().config == "board-v5-bear" and game.report().enemy_parameters.size() == 7, "main board keeps bear profile and seven enemy parameters")
	var tangseng: Dictionary = game._record("tangseng")
	check(not tangseng.is_empty() and Config.deployable(tangseng.cell), "legacy Tang deployment rule still present")
	var friend: Dictionary = game._record("guard_monk")
	var original: Vector2i = friend.cell
	check(game.place("guard_monk",Vector2i(0,0)), "old board still accepts a legal left-half placement")
	check(friend.cell == Vector2i(0,0) and friend.node.position.distance_to(game.display_center(Vector2i(0,0))) < 0.001, "old placement uses the original rectangular centres")
	check(not game.place("guard_monk",Vector2i(6,0)), "old board still rejects the right half for friendly deployment")
	check(not game.place("guard_monk",Vector2i(12,0)), "old board still rejects x=12")
	check(not game.place("E1",Vector2i(0,1)), "old board still refuses enemy placement through the friendly API")
	check(game.place("guard_monk",original), "old board placement can be restored")
	check(game.place("guard_monk",game._record("wild_hunter").cell), "same-army swap still works on the old board")
	# Restore the pre-test formation before starting the shared battle.
	game.load_formation("A")
	check(game.start_battle(), "old board still starts a real battle")
	game.step(1.0)
	var walked := 0
	for actor in game.actors:
		if not actor.move.is_empty():
			walked += 1
			check(is_equal_approx(float(actor.move.duration),0.5), "old board movement still uses 0.50 seconds per cell")
	check(walked > 0, "old board actually has moving units after one second")
	var occupied := {}
	var safe := true
	for actor in game.actors:
		if not game._active(actor): continue
		safe = safe and not occupied.has(actor.cell)
		occupied[actor.cell] = true
	check(safe, "old board still keeps unique cell occupancy")
	check(game.report().config == "board-v5-bear", "old board report config unchanged during battle")
	var result := {"scene":"board_trial.tscn","actors":game.actors.size(),"legal_cells":game.legal_cells().size(),"moving_after_1s":walked}
	game.free()
	return result

func legacy_board() -> Dictionary:
	var game = fresh("res://scenes/board_trial_legacy.tscn")
	check(game.get_script().resource_path == "res://scripts/board_trial.gd", "actual legacy rectangular board boots")
	check(game.phase == game.Phase.DEPLOY and game.actors.size() == 13, "legacy board keeps its 13-unit bearer roster")
	check(game.legal_cells().size() == 84, "legacy board keeps 84 cells")
	check(game.valid_cell(Vector2i(11,6)) and not game.valid_cell(Vector2i(12,0)), "legacy valid_cell hook keeps original bounds")
	check(game.start_battle(), "legacy board starts")
	game.step(1.0)
	check(game.elapsed > 0.9, "legacy board simulates real time")
	var result := {"scene":"board_trial_legacy.tscn","actors":game.actors.size(),"legal_cells":game.legal_cells().size(),"elapsed":game.elapsed}
	game.free()
	return result

func audio_trial() -> Dictionary:
	var game = fresh("res://scenes/audio_trial.tscn")
	check(game.get_script().resource_path == "res://scripts/audio_trial.gd", "actual audio audition scene boots")
	check(game.phase == game.Phase.DEPLOY and game.setup_specs.size() == 2, "audio audition still starts with monk plus wolf")
	check(game.legal_cells().size() == 84 and game.valid_cell(Vector2i(11,6)), "audio audition keeps the 84-cell rectangular domain")
	var first_friend: Dictionary = game.actors.filter(func(actor): return actor.friendly)[0]
	check(first_friend.cell == Vector2i(4,3), "audio default monk keeps its original (4,3) cell")
	check(game.add_units(true,"guard_monk",1), "audio audition still adds a repeated friendly instance")
	var added: Array = game.setup_specs.filter(func(spec): return spec.friendly and spec.key == "guard_monk")
	check(added.size() == 2, "repeat friendly instance is present")
	check(game.setup_specs.filter(func(spec): return spec.friendly).size() == 2, "friendly count is two after one addition")
	check(game.add_units(true,"guard_monk",4), "audio audition fills to its six-per-side prototype cap")
	check(not game.add_units(true,"guard_monk",1), "audio audition still rejects a seventh friendly")
	check(game.start_battle(), "audio audition starts a real inherited battle")
	game.step(1.0)
	var moving := 0
	for actor in game.actors:
		if not actor.move.is_empty():
			moving += 1
			check(is_equal_approx(float(actor.move.duration),0.5), "audio audition movement still 0.50 seconds per cell")
	check(moving > 0, "audio audition units actually move")
	check(game.report().config == "audio-trial-v1", "audio audition report config unchanged")
	var result := {"scene":"audio_trial.tscn","actors":game.actors.size(),"legal_cells":game.legal_cells().size(),"moving_after_1s":moving}
	game.free()
	return result

func diamond_hook_scope() -> void:
	var game = fresh("res://scenes/diamond_duel.tscn")
	check(game.legal_cells().size() == 71 and not game.legal_cells().has(Vector2i(0,6)), "diamond instance mask is not leaking into old defaults")
	check(game.report().config == "diamond-duel-v1", "diamond report is instance-tagged, not legacy config name")
	check(Config.valid(Vector2i(11,6)) and not Config.valid(Vector2i(-1,-1)), "global Config stays rectangular after instantiating the diamond sample")
	game.free()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var started := Time.get_ticks_msec()
	root.size = Vector2i(1920,1080)
	var chapter := chapter_board()
	var legacy := legacy_board()
	var audio := audio_trial()
	diamond_hook_scope()
	var report := {
		"scope":"07 independent regression for shared hooks changed by D002",
		"headless":true,
		"OS_mouse":false,
		"checks":checks,
		"failures":failures,
		"chapter":chapter,
		"legacy":legacy,
		"audio":audio,
		"elapsed_ms":Time.get_ticks_msec()-started}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print("QA07_OLD checks=",checks," failures=",failures.size()," out=",output)
	quit(1 if failures else 0)
