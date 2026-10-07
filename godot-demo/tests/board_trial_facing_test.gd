extends "res://tests/board_trial_ai_test.gd"
var releases: Array[Dictionary] = []

func side(game, actor: Dictionary, expected: float, label: String) -> void:
	var view = actor.node.presentation
	var source := -1.0 if view.manifest.get("source_facing","right")=="left" else 1.0
	check(view.facing==expected and signf(view.visual_transform().x.x)==expected*source,label+" uses one source mirror in final rendering matrix")
	check(actor.node.position==Config.center(actor.cell),label+" keeps exact root foot point")
	check(view.position==Vector2.ZERO and view.foot_anchor==Vector2.ZERO,label+" never offsets local foot anchor")

func defaults(game, label: String) -> void:
	for actor in game.actors:
		if game._active(actor): side(game,actor,1.0 if actor.friendly else -1.0,label+" "+actor.id)

func action(key: String, delta_cell: Vector2i, healing := false) -> void:
	var game = fresh()
	var actor: Dictionary = game._record(key)
	var target: Dictionary = game._record("tangseng" if healing else "E1")
	game._set_cell(actor,Vector2i(3,3))
	game._set_cell(target,actor.cell+delta_cell)
	if healing: target.node.health -= 30
	var hp_before: float = target.node.health
	var rendered_sign: float = signf(actor.node.presentation.visual_transform().x.x)
	releases.clear()
	game.combat.projectile_released.connect(func(event):
		var correct: Vector2 = game.combat.to_local(event.view.get_parent().to_global(event.view.emission_position()))
		releases.append({"from":event.from,"expected":correct,"time":event.view.pose_time})
		check(event.from.distance_to(correct)<0.000001,"released point includes actual 0.72 parent transform")
		check(event.from.distance_to(actor.node.position+event.view.emission_position())>0.1,"fixture proves scaled origin differs from old unscaled addition"))
	game.combat.request(actor.node,target.node,healing)
	var view = actor.node.presentation
	var expected := Vector2(delta_cell).normalized()
	check(view.attack_direction.distance_to(expected)<0.000001,"face uses parent-space target, not absolute world point "+key+str(delta_cell))
	if delta_cell.x!=0: side(game,actor,signf(delta_cell.x),"real action "+key)
	else: check(signf(view.visual_transform().x.x)==rendered_sign and view.attack_direction.length()>0.99,"vertical action has nonzero direction, retains valid side")
	for frame in range(160):
		actor.node.tick_visual(Config.STEP)
		target.node.tick_visual(Config.STEP)
		game.combat.tick(Config.STEP)
	check(releases.size()==1 and game.combat.counts.get("heals" if healing else "hits")==1,"real attack releases and applies once "+key)
	check(is_equal_approx(target.node.health,hp_before+(actor.damage if healing else -actor.damage)),"orientation/origin never changes effective damage or healing")
	check(actor.node.position==Config.center(actor.cell),"action socket adaptation never moves actor foot")
	game.free()

func run() -> void:
	var game = fresh()
	defaults(game,"initial formation")
	for key in ["A","B","C"]:
		game.load_formation(key)
		defaults(game,"formation "+key)
	game.load_formation("A")
	var fox: Dictionary = game._record("foxfire_imp")
	fox.node.presentation.facing = -1
	game.place("foxfire_imp",Vector2i(0,6))
	side(game,fox,1,"redeploy fox")
	game.start_battle()
	for actor in game.actors: actor.node.presentation.facing = -1 if actor.friendly else 1
	game.retry()
	defaults(game,"retry")
	game.free()
	for key in ["tangseng","wild_hunter","sparrow_spirit","foxfire_imp"]:
		for delta_cell in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,-1)]: action(key,delta_cell)
	action("herbal_spirit_child",Vector2i(-1,0),true)
	game = fresh()
	isolate(game,["guard_monk","tangseng","E1"])
	var monk: Dictionary = game._record("guard_monk")
	game._set_cell(game._record("tangseng"),Vector2i(0,0))
	game._set_cell(game._record("E1"),Vector2i(11,6))
	game._set_cell(monk,Vector2i(5,3))
	game.start_battle()
	monk.cell = Vector2i(6,3)
	monk.node.position = Config.center(monk.cell)
	monk.mode = "归位"
	game._return(monk)
	check(monk.node.presentation.facing==-1 and monk.move.to==monk.anchor,"actual left return faces its anchor, not locked right")
	for frame in range(120): game._tick(Config.STEP)
	check(monk.cell==monk.anchor and monk.move.is_empty() and monk.target.is_empty(),"return completes without target or anchor drift")
	side(game,monk,1,"idle after returning")
	game.free()
	game = fresh()
	isolate(game,["wild_hunter","tangseng","E1"])
	game._set_cell(game._record("E1"),Vector2i(11,6))
	var hunter: Dictionary = game._record("wild_hunter")
	hunter.node.presentation.facing = -1
	hunter.node.presentation.attack_direction = Vector2.LEFT
	game.start_battle()
	game._tick(Config.STEP)
	check(hunter.target.is_empty(),"idle fixture has no reachable target")
	side(game,hunter,1,"no-target ranged idle")
	check(hunter.node.presentation.attack_direction==Vector2.RIGHT,"idle default resets stale attack direction too")
	game.free()
	print("BOARD_TRIAL_FACING failures=",failures)
	quit(1 if failures else 0)
