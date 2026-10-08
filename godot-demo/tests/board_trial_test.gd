extends SceneTree
const Config = preload("res://scripts/data/board_trial_config.gd")
var failures := 0
var comparisons := []
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func fresh():
	var game = load("res://scenes/board_trial.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled = false
	return game
func ownership(game) -> void:
	var held := {}
	for actor in game.actors:
		if not game._active(actor): continue
		var cells: Array[Vector2i] = [actor.cell]
		if not actor.move.is_empty(): cells.append(actor.move.to)
		for cell in cells:
			check(not held.has(cell),"every live source/destination has unique owner")
			held[cell] = actor.id
		if actor.friendly and actor.key in ["tangseng","herbal_spirit_child"]:
			check(actor.cell==actor.anchor and actor.move.is_empty(),"core/healer stay at deployment")
		elif actor.friendly:
			check(actor.key in ["guard_monk","wild_hunter","sparrow_spirit","foxfire_imp"],"only the four combat heroes are exempt from Tang/healer stationary constraints")
			check(cells.all(func(cell): return Config.valid(cell)),"mobile hero source/destination remain inside the full legal board")
			if not actor.move.is_empty():
				check(actor.move.from==actor.cell and Config.distance(actor.cell,actor.move.to)==1,"mobile hero reserves one legal four-neighbor segment, not a teleport")
func simulate(key: String, fps: int, speed: int) -> Dictionary:
	var game = fresh()
	game.load_formation(key)
	check(game.actors.size()==12 and game.deployment.size()==6,"fixed six friends/six advertised enemies, no population cap")
	check(game.start_battle(),"formation starts")
	game.speed = speed
	while game.phase==game.Phase.BATTLE and game.elapsed<180:
		game.step(1.0/fps)
		ownership(game)
	var report: Dictionary = game.report()
	check(game.phase==game.Phase.RESULT,"natural battle reaches result, never timeout victory")
	check(game.result_count==1,"natural result settled exactly once")
	# D-007 may keep every enemy outside Tang's range in A. Damage is no longer
	# guaranteed by deployment; exercise the real weak attack in its own fixture.
	var core: Dictionary = game._record("tangseng")
	check(core.cell==core.anchor and core.move.is_empty(),"core stays deployed even when enemy pursuit never brings a target in range")
	print("BOARD_COMPARISON ",key," fps=",fps," speed=",speed," ",JSON.stringify(report))
	# Retry returns to the START snapshot, not combat cells, and resets every clock.
	var snapshot: Dictionary = game.start_deployment.duplicate()
	game.retry()
	check(game.phase==game.Phase.DEPLOY and game.deployment==snapshot and game.elapsed==0 and game.result_count==0,"retry restores initial layout/time/results")
	check(game.actors.all(func(actor): return game._alive(actor) and game._hp(actor)==actor.hp_max and actor.move.is_empty() and actor.target.is_empty() and actor.cooldown==0),"retry restores all friends/enemies and clears motion/target/cooldown")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"retry has no pending strikes/missiles")
	game.free()
	return report
func core_attack_fixture() -> void:
	var game = fresh()
	for actor in game.actors:
		if actor.id not in ["tangseng","E5"]:
			actor.node.take_damage(actor.hp_max)
			actor.dead = true
	var core: Dictionary = game._record("tangseng")
	var rat: Dictionary = game._record("E5")
	game._set_cell(core,Vector2i(0,3))
	game._set_cell(rat,Vector2i(3,3))
	var initial_hp: float = rat.node.health
	game.start_battle()
	while game.elapsed<3.0:
		game.step(Config.STEP)
		ownership(game)
	var damage: float = game.metrics.damage.get("tangseng",0)
	check(damage>0,"weak core contributes real ranged damage")
	check(is_equal_approx(initial_hp-rat.node.health,damage) and is_equal_approx(fmod(damage,Config.CORE.damage),0),"live range-three fixture applies original Tang damage exactly")
	var times: Array = game.metrics.attack_times.get("tangseng",[])
	check(times.size()>=2 and core.move.is_empty() and rat.move.is_empty(),"both real ranged brains engage without a movement/frozen-target workaround")
	for index in range(1,times.size()): check(is_equal_approx(times[index]-times[index-1],Config.CORE.interval),"weak core retains original attack interval")
	game.free()
func comparable(report: Dictionary) -> Dictionary:
	var result := report.duplicate(true)
	result.erase("seconds")
	return result
func run() -> void:
	core_attack_fixture()
	var game = fresh()
	var before: Dictionary = game.deployment.duplicate()
	check(Config.center(Vector2i(5,6))==Vector2(825,853),"column/row projection is not transposed")
	check(Config.cell_at(Config.center(Vector2i(11,6)))==Vector2i(11,6),"last board cell roundtrips")
	check(not game.place("tangseng",Vector2i(6,3)) and game.deployment==before,"seventh column rejected without mutation")
	check(not game.place("guard_monk",Vector2i(-1,0)) and game.deployment==before,"outside rejected")
	var a: Vector2i = game.deployment.tangseng
	var b: Vector2i = game.deployment.guard_monk
	check(game.place("tangseng",b) and game.deployment.guard_monk==a,"occupied deployment swaps atomically")
	game.select("tangseng")
	game.withdraw()
	check(not game.start_battle(),"Tang must be legally deployed")
	check(game.place("tangseng",Vector2i(5,6)),"sixth column allowed")
	for key in Config.FRIENDS:
		if key=="tangseng": continue
		game.select(key)
		game.withdraw()
	check(game.start_battle(),"core alone may start, optional heroes not forced six or three")
	var core: Dictionary = game._record("tangseng")
	game.paused = true
	game.step(2)
	check(game.elapsed==0 and not game.place("tangseng",Vector2i(0,0)),"pause freezes simulation but never unlocks formation")
	game.select("tangseng")
	game.withdraw()
	check(core.cell==Vector2i(5,6),"battle withdraw rejected")
	game.paused = false
	# Same completed tick with mutual elimination: failure outranks victory.
	for actor in game.actors:
		if not actor.friendly: actor.node.take_damage(actor.hp_max)
	core.node.take_damage(core.hp_max)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.RESULT and not game.victory and game.result_count==1,"same-step core/enemies dead is one failure")
	game._settle()
	game.step(1)
	check(game.result_count==1,"result cannot settle twice")
	var settled: Dictionary = game.report()
	game._process(0.8)
	check(game.report()==settled and core.node.presentation.visual_alpha==0,"result fade finishes without additional time/damage/result")
	game.retry()
	game.load_formation("A")
	game.start_battle()
	for actor in game.actors:
		if actor.friendly and actor.key!="tangseng": actor.node.take_damage(actor.hp_max)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.BATTLE,"all heroes fallen but living core continues")
	var dead: Dictionary = game._record("guard_monk")
	dead.node.heal(10000)
	check(dead.node.health==0 and not game.place("guard_monk",Vector2i(0,0)),"dead hero cannot heal or be replaced in battle")
	game.free()
	for key in ["A","B","C"]:
		var first := simulate(key,30,1)
		comparisons.append({"formation":key,"report":first})
		var second := simulate(key,120,2)
		check(comparable(first)==comparable(second) and is_equal_approx(first.seconds,second.seconds),"same layout deterministic across fps/2x "+key)
	var file := FileAccess.open("/tmp/board-trial-comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"config":Config.VERSION,"comparisons":comparisons,"failures":failures},"\t"))
	print("BOARD_TRIAL_TEST failures=",failures)
	quit(1 if failures else 0)
