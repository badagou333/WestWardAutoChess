extends "res://tests/free_escort_test.gd"
## Fixed-anchor regression: fixtures move targets, never rewrite anchors during a chase.
func ticks(game, seconds: float) -> void:
	for i in range(int(seconds*120)): game.step(1.0/120)

func run() -> void:
	var game = fresh()
	recruit(game)
	quiet(game)
	var center := Map.center(Vector2i(3,8))
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	monk.position = center
	hunter.position = center+Vector2(-80,65)
	healer.position = center+Vector2(-160,65)
	for hero in game.heroes: game.guard_anchors[hero] = hero.position
	game.escort.position = center+Vector2(500,0)
	ticks(game,3)
	check(monk.position==center and game._brain(monk).anchor==center,"Tang far away does not relocate guard")
	var healer_start: Vector2 = healer.position
	game.escort.health = 50
	ticks(game,2)
	check(healer.position==healer_start and game.escort.health==50,"healer never chases distant wounded Tang")
	monk.health = 50
	ticks(game,2)
	check(monk.health>50 and healer.position==healer_start,"stationary healer treats nearby wounded ally")
	game._spawn_enemy("boar",Vector2i(3,10))
	var first = game.enemies[0]
	first.position = center+Vector2(180,0)
	first.health = 100000
	first.damage = 0
	first.move_interval = 100000
	ticks(game,1)
	var brain: Dictionary = game._brain(monk)
	check(brain.mode=="接战" and brain.anchor==center and monk.position!=center,"acquires near anchor even when Tang is far")
	var clock: float = brain.chase
	# Explicit acquisition with a different reachable target must not reset time.
	game._spawn_enemy("boar",Vector2i(3,10))
	var second = game.enemies.back()
	second.position = center+Vector2(180,60)
	second.damage = 0
	second.health = 100000
	second.move_interval = 100000
	brain.skip[first.get_instance_id()] = game.battle_elapsed+30
	game._acquire(monk,brain)
	check(brain.target==second and brain.chase==clock and brain.anchor==center,"switch target preserves excursion clock and anchor")
	second.position = center+Vector2(game.Rules.LEASH_RADIUS+20,0)
	ticks(game,0.02)
	check(brain.mode=="归位" and brain.anchor==center,"target outside anchor leash triggers return")
	first.position = monk.position+Vector2(35,0)
	ticks(game,0.1)
	check(brain.mode=="归位" and brain.target==null,"nearby chain target cannot interrupt return")
	first.position = center+Vector2(200,60)
	second.position = center+Vector2(230,60)
	# Occupied anchor cannot cause a new far-away anchor or early acquisition.
	hunter.position = center
	ticks(game,5)
	check(brain.mode=="归位" and brain.anchor==center and brain.target==null,"occupied anchor waits without drift or reacquisition")
	hunter.position = center+Vector2(-80,65)
	for i in range(1000):
		game.step(1.0/120)
		if brain.mode=="驻守": break
	check(brain.mode=="驻守" and monk.position.distance_to(center)<0.1 and brain.chase==0,"return completes at exact fixed anchor before timer resets")
	brain.think = 0
	brain.skip.clear()
	ticks(game,0.1)
	check(brain.mode=="接战","fresh excursion after completed return")
	brain.chase = game.Rules.CHASE_SECONDS
	ticks(game,0.02)
	check(brain.mode=="归位","total chase timer bounded independently of distance")
	brain.mode = "接战"
	brain.target = first
	brain.chase = 0
	brain.blocked = game.Rules.UNREACHABLE_SECONDS+1
	ticks(game,0.02)
	check(brain.mode=="归位" and brain.anchor==center,"unreachable target returns to same anchor")
	brain.mode = "接战"
	brain.target = second
	second.take_damage(1000000)
	ticks(game,0.02)
	check(brain.mode=="归位" and brain.target==null and brain.anchor==center,"dead target returns before another acquisition")
	var goal := center+Vector2(-40,-60)
	check(game._command_free(monk,goal),"manual order takes over return")
	var old_anchor: Vector2 = brain.anchor
	ticks(game,0.2)
	check(brain.mode=="手动" and brain.anchor==old_anchor,"manual transit keeps previous anchor until arrival")
	check(not game._command_free(monk,Vector2(1000,470)) and brain.goal==goal,"invalid replacement preserves valid manual task")
	for i in range(1200):
		game.step(1.0/120)
		if game._brain(monk).mode!="手动": break
	check(game.guard_anchors[monk].distance_to(goal)<0.1,"completed manual movement updates anchor")
	check(game._command_free(monk,center+Vector2(-120,-20)),"second manual task accepted")
	ticks(game,0.15)
	var canceled_at: Vector2 = monk.position
	game._establish_guard(monk,"已取消 · 当前合法位置驻守")
	check(monk.position==canceled_at and game.guard_anchors[monk]==canceled_at and game._brain(monk).mode=="驻守","cancel on legal ground establishes local anchor without teleport")
	# Death invalidates only the dead hero's command, not other anchors/numbering.
	var hunter_slot: int = game.hero_slots.find(hunter)
	monk.take_damage(100000)
	ticks(game,0.02)
	check(not game.brains.has(monk) and game.hero_slots.find(hunter)==hunter_slot,"death clears brain without renumbering survivors")
	game._enter_wave_preparation()
	check(not monk.battle_dead and game.guard_anchors[monk]==monk.position,"camp revival starts a valid local guard")
	game._restart_demo()
	check(game.guard_anchors.is_empty() and game.hero_slots.is_empty() and game.bench_open,"restart clears anchors and slots, retaining permanent bench")
	game.free()
	print("FREE_GUARD_TEST failures=",failures)
	quit(1 if failures else 0)
