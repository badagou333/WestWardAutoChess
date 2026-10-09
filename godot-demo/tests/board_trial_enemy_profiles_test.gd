extends "res://tests/board_trial_ai_test.gd"
## D002 isolated runtime/stat/activity boundaries. Natural battles are separate.
const Units = preload("res://scripts/data/demo_units.gd")
const LegacyEnemies = preload("res://scripts/enemy.gd")
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const PROFILES := ["legacy","normal","bear"]
const CELLS := [Vector2i(8,2),Vector2i(8,6),Vector2i(9,3),Vector2i(9,5),Vector2i(11,2),Vector2i(11,6),Vector2i(10,4)]
const ORIGINAL := {"wolf":[155.0,14.0,0.90,1],"boar":[96.0,10.0,1.10,1],"rat":[52.0,7.0,0.95,3],"bear_lord":[400.0,22.0,1.10,1]}
const STRONG := {"wolf":[180.0,17.0,0.90,1],"boar":[120.0,12.0,1.10,1],"rat":[65.0,9.0,0.95,3],"bear_lord":[280.0,20.0,1.20,1]}
var evidence := []

func profile_game(profile: String):
	var game = load("res://scenes/board_trial.tscn").instantiate()
	game.enemy_profile=profile
	root.add_child(game)
	game.set_process(false)
	game.audio_feedback.enabled=false
	return game

func roster(game, profile: String, label: String) -> void:
	var count: int=13 if profile=="bear" else 12
	check(game.actors.size()==count,label+" actual actor count")
	check(game.report().get("enemy_profile","")==profile and game.report().config==Config.version_for(profile),label+" actual report identifies profile and version")
	var specs: Array=Config.enemy_specs(profile)
	check(specs.size()==count-6,label+" config contains exact enemy count")
	var parameters: Array=game.report().get("enemy_parameters",[])
	check(parameters.size()==specs.size(),label+" public report contains every real enemy parameter row")
	for index in specs.size():
		var actor: Dictionary=game._record("E%d" % (index+1))
		var expected: Array=(ORIGINAL if profile=="legacy" else STRONG)[actor.key]
		var stats: Dictionary=Config.enemy_stats(actor.key,profile)
		check(actor.cell==CELLS[index]-Vector2i.ONE and specs[index][1]==CELLS[index],label+" documented one-based enemy position "+actor.id)
		check(actor.hp_max==expected[0] and actor.node.max_health==expected[0] and actor.node.health==expected[0],label+" exact enemy HP without second multiplier "+actor.id)
		check(actor.damage==expected[1] and actor.node.damage==expected[1] and stats.damage==expected[1],label+" exact actor/node/config damage "+actor.id)
		check(actor.interval==expected[2] and actor.node.attack_interval==expected[2] and stats.interval==expected[2],label+" original or approved attack interval "+actor.id)
		check(actor.reach==expected[3] and actor.node.attack_range_cells==expected[3] and stats.range==expected[3],label+" single-cell melee or actual rat range3 "+actor.id)
		check(actor.walk==0.5 and actor.node.move_interval==0.5,label+" shared movement duration "+actor.id)
		if index<parameters.size():
			var public: Dictionary=parameters[index]
			check(public.id==actor.id and public.key==actor.key and public.hp==expected[0] and public.damage==expected[1] and public.interval==expected[2] and public.range==expected[3] and public.walk==0.5 and public.initial_cell==[CELLS[index].x,CELLS[index].y],label+" public enemy parameters match actual runtime "+actor.id)
	for actor in game.actors:
		if not actor.friendly: continue
		var original: Dictionary=Config.CORE if actor.key=="tangseng" else Units.HEROES[actor.key]
		check(actor.hp_max==original.hp and actor.damage==original.damage and actor.interval==original.interval and actor.reach==original.range,label+" original friendly combat attributes "+actor.id)
	if profile=="bear":
		check(game._record("E7").key=="bear_lord" and Melee.applies(game._record("E7")),label+" real bear uses shared melee policy")
		check(game.ui.enemy_rows.size()==4 and game.ui.enemy_rows[3].visible and game.ui.enemy_names[3].text=="熊山君" and game.ui.enemy_buttons.size()==7,label+" opening enemy row and specific selection publicly identify actual E7 bear")
		check(game.enemies_label.text.contains("7 / 7"),label+" opening enemy total publishes all seven opponents")
	else: check(game._record("E7").is_empty(),label+" six-enemy roster has no hidden bear")
	ownership(game)

func profile_boundaries() -> void:
	check(Config.DEFAULT_ENEMY_PROFILE=="bear","default profile exposes reinforced enemies and bear")
	check(Config.ENEMY_HP_FACTOR==1.0 and Config.ENEMY_DAMAGE_FACTOR==1.0,"global enemy multipliers remain neutral")
	for key in ORIGINAL:
		var old: Dictionary=LegacyEnemies.ENEMY_DATA[key]
		check(old.hp==ORIGINAL[key][0] and old.damage==ORIGINAL[key][1] and old.interval==ORIGINAL[key][2],"shared legacy enemy catalog unchanged "+key)
	for profile in PROFILES:
		var game=profile_game(profile)
		roster(game,profile,"fresh "+profile)
		evidence.append({"case":"roster","profile":profile,"actors":game.actors.size(),"report":game.report()})
		game.free()
	var game=profile_game("legacy")
	check(game.set_enemy_profile("normal"),"deployment permits explicit profile rebuilding")
	roster(game,"normal","changed deployment")
	check(game.start_battle(),"changed profile starts actual battle")
	var snapshot: Dictionary=game.report().duplicate(true)
	check(not game.set_enemy_profile("bear") and game.report()==snapshot and game.enemy_profile=="normal","battle denies profile changes without altering state")
	game._record("tangseng").node.take_damage(300.0)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.RESULT and not game.set_enemy_profile("legacy") and game.enemy_profile=="normal","result denies profile change until retry")
	game.retry()
	roster(game,"normal","profile retry")
	evidence.append({"case":"profile_change_lifecycle","profile":game.enemy_profile})
	game.free()

func bear_pair(mirrored := false, friends: Array = ["guard_monk"]):
	var game=profile_game("bear")
	check(game.start_battle(),"bear activity fixture starts production battle")
	var ids: Array=["E7","tangseng"]
	ids.append_array(friends)
	isolate(game,ids)
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	var bx: int=8 if mirrored else 3
	var gx: int=5 if mirrored else 6
	game._set_cell(bear,Vector2i(bx,3))
	if game._active(guard): game._set_cell(guard,Vector2i(gx,3))
	game._set_cell(game._record("tangseng"),Vector2i(11 if mirrored else 0,6))
	for actor in game.actors:
		if game._active(actor): actor.cooldown=100.0
	bear.target="guard_monk"
	if game._active(guard): guard.target="E7"
	return game

func bear_movement(mirrored: bool) -> void:
	var game=bear_pair(mirrored)
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	var from: Vector2i=bear.cell
	var to: Vector2i=from+(Vector2i.LEFT if mirrored else Vector2i.RIGHT)
	game._brain(bear,Config.STEP)
	check(not bear.move.is_empty() and bear.move.get("to")==to,"bear chooses actual near-target next cell in both directions")
	check(not game._move(guard,to),"another real body cannot claim bear's reserved destination")
	for index in 30:
		game._tick(Config.STEP)
		ownership(game)
	check(bear.cell==from and not bear.move.is_empty() and is_equal_approx(bear.move.time,0.25),"bear half step remains an in-flight segment")
	check(bear.node.position.distance_to(Config.center(from).lerp(Config.center(to),0.5))<0.000001,"bear actual foot reaches exact half-step point")
	check(game._occupant(from,guard.id).id==bear.id and game._occupant(to,guard.id).id==bear.id,"bear owns both endpoints throughout interpolation")
	var before: Dictionary=game.report().duplicate(true)
	var held: Dictionary=bear.move.duplicate(true)
	game.paused=true
	game.step(3)
	check(game.report()==before and bear.move==held,"pause freezes actual bear activity and battle clocks")
	game.paused=false
	for index in 30:
		game._tick(Config.STEP)
		ownership(game)
	check(bear.cell==to and bear.step_completed==1 and bear.node.position==Config.center(to),"bear lands after one full 0.50-second segment")
	# The guard starts on the first battle tick, one STEP later than the
	# explicit bear request. Same speed does not imply simultaneous landing.
	if not guard.move.is_empty():
		check(bear.move.is_empty() and Config.distance(bear.cell,guard.cell)==2,"bear safely waits for the guard's actually unfinished last STEP")
		game._tick(Config.STEP)
		ownership(game)
	check(bear.move.is_empty() and Config.distance(bear.cell,guard.cell)==1,"bear stops at true melee range during original cooldown")
	evidence.append({"case":"bear_movement","mirrored":mirrored,"seconds":game.elapsed,"completed":bear.step_completed,"cell":[bear.cell.x+1,bear.cell.y+1]})
	game.free()

func bear_cadence_and_damage() -> void:
	var game=bear_pair()
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	game._set_cell(guard,Vector2i(4,3))
	bear.cooldown=0.25
	for index in 29: game._tick(Config.STEP)
	check(game.metrics.attack_times.get("E7",[]).is_empty() and bear.move.is_empty(),"bear actual melee range holds until its existing cooldown completes")
	while game.elapsed<1.9:
		game._tick(Config.STEP)
		ownership(game)
	var times: Array=game.metrics.attack_times.get("E7",[])
	check(times.size()==2 and is_equal_approx(times[0],0.25) and is_equal_approx(times[1]-times[0],1.2),"bear production attacks retain 1.20-second cadence, independent of 0.50 movement")
	check(guard.node.health==270.0 and game.metrics.damage.get("E7",0)==40.0,"two actual bear hits deal exactly 20 each to real friendly HP")
	check(bear.hp_max==280.0 and bear.damage==20.0 and bear.reach==1 and bear.interval==1.2,"bear approved prototype parameters remain intact after attacks")
	evidence.append({"case":"bear_damage_cadence","attack_times":times,"actual_damage":game.metrics.damage.get("E7",0),"recipient_hp":guard.node.health})
	game.free()
	game=bear_pair()
	bear=game._record("E7")
	guard=game._record("guard_monk")
	game._set_cell(guard,Vector2i(4,3))
	guard.cooldown=0
	while game.elapsed<0.8: game._tick(Config.STEP)
	check(bear.node.health==266.0 and game.metrics.damage.get(guard.id,0)==14.0,"bear takes real original 14-damage guard hit")
	evidence.append({"case":"bear_receives_original_hit","remaining_hp":bear.node.health})
	game.free()

func bear_activity_death_retry() -> void:
	var game=bear_pair(false,["guard_monk","foxfire_imp"])
	var bear: Dictionary=game._record("E7")
	var guard: Dictionary=game._record("guard_monk")
	game._set_cell(guard,Vector2i(4,3))
	game._set_cell(game._record("foxfire_imp"),Vector2i(3,2))
	bear.cooldown=0
	game._brain(bear,Config.STEP)
	check(bear.node.presentation.pose=="basic_attack","bear starts real shared melee attack")
	guard.node.take_damage(guard.hp_max)
	game._brain(bear,Config.STEP)
	check(bear.target==guard.id and bear.move.is_empty() and is_equal_approx(bear.cooldown,bear.interval-Config.STEP),"bear safely completes attack before dead-target replacement")
	while bear.node.presentation.pose=="basic_attack" and game.elapsed<2: game._tick(Config.STEP)
	check(bear.target=="foxfire_imp" and bear.move.is_empty() and Config.distance(bear.cell,game._record("foxfire_imp").cell)==1,"bear reacquires actual adjacent opponent after safe completion")
	evidence.append({"case":"bear_attack_activity","replacement":bear.target,"cooldown":bear.cooldown})
	game.free()
	game=bear_pair()
	bear=game._record("E7")
	var from: Vector2i=bear.cell
	var to: Vector2i=from+Vector2i.RIGHT
	check(game._move(bear,to),"bear begins actual movement before death fixture")
	bear.node.take_damage(bear.hp_max)
	game._tick(Config.STEP)
	check(bear.dead and bear.move.is_empty() and bear.target.is_empty() and bear.handoff.is_empty() and bear.step_wait.is_empty(),"bear death clears actual movement/contact/request state")
	check(game._occupant(from).is_empty() and game._occupant(to).is_empty(),"dead bear releases both former endpoint claims")
	check(game.phase==game.Phase.RESULT and game.victory and game.result_count==1,"last actual enemy death gives exactly one victory with living core")
	game.retry()
	roster(game,"bear","bear death retry")
	check(game.actors.all(func(actor): return not actor.dead and actor.target.is_empty() and actor.move.is_empty() and actor.handoff.is_empty() and actor.step_wait.is_empty() and actor.step_serial==0 and actor.step_completed==0 and actor.cooldown==0),"retry rebuilds all thirteen actors with clean runtime activity")
	evidence.append({"case":"bear_death_and_retry","actors":game.actors.size()})
	game.free()
	game=bear_pair()
	game._record("tangseng").node.take_damage(300)
	game._tick(Config.STEP)
	check(game.phase==game.Phase.RESULT and not game.victory and game.result_count==1 and game._active(game._record("E7")),"core death still defeats the trial with a living bear")
	evidence.append({"case":"core_failure_with_bear"})
	game.free()

func run() -> void:
	profile_boundaries()
	bear_movement(false)
	bear_movement(true)
	bear_cadence_and_damage()
	bear_activity_death_retry()
	check(evidence.size()==11,"all eleven profile and actual bear runtime boundaries completed")
	var file:=FileAccess.open("/tmp/board-balance-20261009-boundaries.json",FileAccess.WRITE)
	check(file!=null,"profile/bear boundary evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"D-20261009-002","kind":"isolated_runtime_boundaries_not_natural_balance","profiles":PROFILES,"cases":evidence,"failures":failures},"\t"))
	print("BOARD_ENEMY_PROFILES cases=",evidence.size()," failures=",failures)
	quit(1 if failures else 0)
