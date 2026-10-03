extends "res://tests/free_escort_test.gd"

func purchase(game, kind: String):
	game.shop_types[0] = kind
	game._on_shop_pressed(0)
	return game.heroes.back()

func camp_fixture():
	var game = fresh()
	recruit(game)
	quiet(game)
	var center := Map.center(Vector2i(3,8))
	game.escort.position = Map.center(Vector2i(3,14))
	for i in range(3): game.heroes[i].position = center+Vector2(i*60,30)
	game.pending_loot = 3
	game._enter_wave_preparation()
	game.coins = 50 # Boundary-test fixture, not earned economy.
	return game

func ownership(game) -> void:
	var slots := {}
	var seats := {}
	for hero in game.heroes:
		if hero.board_row >= 0:
			check(hero.bench_slot==-1,"field actor has no bench ownership")
			var index: int = game.hero_slots.find(hero)
			check(index>=0 and not seats.has(index),"each deployed actor owns one numbered seat")
			seats[index] = hero
		else:
			check(hero.bench_slot>=0 and hero.bench_slot<8 and not slots.has(hero.bench_slot),"bench slots remain unique and bounded")
			slots[hero.bench_slot] = hero
	check(seats.size()<=game.population and slots.size()<=8,"capacity is never exceeded")

func run() -> void:
	var game = camp_fixture()
	var monk = game.heroes[0]
	var hunter = game.heroes[1]
	var healer = game.heroes[2]
	var original: Vector2 = monk.position
	var other_at: Vector2 = hunter.position
	check(original.distance_to(game.escort.position)>game.Rules.DEPLOY_RADIUS,"fixture ends far from Tang")
	check(game.camp_positions.points.size()==3 and game.guard_anchors[monk]==original,"camp freezes actual ending positions, replacing stale guard anchor")
	check(not game._place_free(monk,game._near_free(game.escort.position+Vector2(0,60),monk)),"camp cannot move existing field hero")
	check(monk.position==original and hunter.position==other_at,"camp rejection never moves other heroes")
	game._select_hero(monk)
	game._withdraw_selected()
	var wallet: int = game.coins
	check(monk.board_row<0 and game.selected_hero==null and not game.brains.has(monk) and not game.guard_anchors.has(monk),"R withdraw clears selection and combat task")
	check(game.camp_positions.points[0]==original and game._seat_hero(0)==null,"R leaves exact empty seat and number")
	game._withdraw_selected()
	check(game._deployed_count()==2 and game.coins==wallet,"repeated withdrawal cannot duplicate inventory or spend")
	game._on_level_pressed()
	check(game.population==4 and game.coins==wallet-4,"upgrade preserves standard price and capacity")
	var new_point: Vector2 = game._near_free(game.escort.position+Vector2(20,70),monk)
	check(game._place_free(monk,original+Vector2(6,3)) and monk.position==original,"click near empty marker fills exact distant old position")
	var fox = purchase(game,"foxfire_imp")
	check(game._place_free(fox,new_point) and game._deployed_count()==4,"3/4 allows new fourth hero at chosen nearby point")
	var fox_seat: int = game.hero_slots.find(fox)
	check(game.camp_positions.points[fox_seat]==new_point and hunter.position==other_at,"only new seat is created; incumbents stay still")
	game._select_hero(fox)
	game._withdraw_selected()
	check(not game._place_free(fox,new_point+Vector2(0,50)),"newly committed seat also locks after R")
	check(game._place_free(fox,new_point),"new hero can return to own exact seat")
	# Selling only removes ownership, not the coordinate entitlement.
	game._select_hero(monk)
	game._sell_selected()
	var bird = purchase(game,"sparrow_spirit")
	check(not game._place_free(bird,new_point+Vector2(0,60)),"selling incumbent does not create a new free-placement entitlement")
	check(game._place_free(bird,original) and game.hero_slots[0]==bird,"sale leaves original numbered vacancy available")
	# Full bench R refusal, followed by F atomic exchange.
	for hero in game.heroes: hero.merge_locked = true
	for i in range(8):
		var reserve = purchase(game,"guard_monk")
		reserve.merge_locked = true
	var incoming = game._hero_in_bench(7)
	game._select_hero(hunter)
	wallet = game.coins
	var total: int = game.heroes.size()
	game._withdraw_selected()
	check(hunter.board_row>=0 and hunter.position==other_at and game.selected_hero==hunter and "后备已满" in game.command_note,"full bench refuses R without losing selection or actor")
	game._begin_swap()
	check(game.swap_source==hunter and game.bench_open,"F selects source and opens bench")
	check(game._swap_with_bench(incoming),"F can exchange with full bench")
	check(incoming.position==other_at and game.hero_slots[1]==incoming and hunter.bench_slot==7,"incoming inherits exact coordinate and number; outgoing uses incoming bench seat")
	check(game.heroes.size()==total and game.coins==wallet and game.population==4 and game._deployed_count()==4,"swap conserves copies, currency and population")
	check(game.swap_source==null and game.carry_hero==null and game.selected_hero==null,"swap commits once and clears selection and pending input")
	check(not game._swap_with_bench(hunter),"repeated completion cannot repeat swap")
	ownership(game)
	# Begin combat: no automatic return to a previous battle's anchor.
	game._start_battle()
	game.intermission = 999
	var start: Vector2 = incoming.position
	game.step(0.2)
	check(incoming.position==start and game._brain(incoming).anchor==start,"next wave holds final camp position until normal orders")
	game._select_hero(incoming)
	game._withdraw_selected()
	game._begin_swap()
	check(incoming.board_row>=0 and game.swap_source==null,"battle R/F never remove or swap actors")
	var destination: Vector2 = game._near_free(incoming.position+Vector2(0,-70),incoming)
	check(game._command_free(incoming,destination),"normal manual movement resumes in next wave")
	game._finish_battle(false)
	game._restart_demo()
	check(game.camp_positions.points.is_empty() and game.swap_source==null,"restart clears camp ledger and swap mode")
	game.free()
	merge_and_casualty()
	unused_capacity()
	progression()
	print("CAMP_ROSTER_TEST failures=",failures)
	quit(1 if failures else 0)

func unused_capacity() -> void:
	var game = camp_fixture()
	var outgoing = game.heroes[0]
	var reserve = purchase(game,"foxfire_imp")
	game._select_hero(outgoing)
	game._begin_swap()
	check(game._swap_with_bench(reserve),"prepare formerly deployed reserve")
	game._on_level_pressed()
	var point: Vector2 = game._near_free(game.escort.position+Vector2(20,70),outgoing)
	check(game._place_free(outgoing,point) and game._deployed_count()==4,"former field hero can use genuinely new capacity without buying another hero")
	game._select_hero(outgoing)
	game._withdraw_selected()
	check(not game._place_free(outgoing,point+Vector2(45,0)),"one upgrade cannot create endless new positions through R")
	game.free()

func progression() -> void:
	var game = fresh()
	recruit(game)
	var monk = game.heroes[0]
	game._start_battle()
	var next_order := 3.0
	var camps := 0
	var reserve = null
	for frame in range(240*60):
		if game.state == game.GameState.RESULT: break
		if game.state == game.GameState.PREPARING:
			camps += 1
			var position: Vector2 = monk.position
			var wallet: int = game.coins
			game._select_hero(monk)
			game._withdraw_selected()
			check(game._place_free(monk,position) and game.coins==wallet,"natural camp R/refill keeps position and gold")
			if camps==1:
				# Controlled offer identity only: all spending uses earned gold.
				reserve = purchase(game,"foxfire_imp")
				game._select_hero(monk)
				game._begin_swap()
				check(game._swap_with_bench(reserve),"natural camp exchanges purchased reserve")
				game._select_hero(reserve)
				game._begin_swap()
				check(game._swap_with_bench(monk),"natural camp exchanges back without extra charge")
				check(game.coins==wallet-1 and monk.position==position,"exchange pair spends only the original purchase")
			elif camps==2:
				game._on_level_pressed()
				check(game.population==4 and game.coins==wallet-4,"earned gold upgrades at second camp")
				var point: Vector2 = game._near_free(game.escort.position+Vector2(-30,70),reserve)
				check(game._place_free(reserve,point) and game._deployed_count()==4,"second camp fills new fourth seat")
			else:
				purchase(game,"guard_monk")
				purchase(game,"guard_monk")
				check(monk.star==2 and monk.position==position and game.coins==wallet-2,"third camp paid three-to-one preserves field keeper")
			ownership(game)
			game._start_battle()
		if game.battle_elapsed>=next_order:
			next_order += 2
			for i in range(game.heroes.size()):
				var hero = game.heroes[i]
				if hero.board_row<0 or hero.battle_dead or game._brain(hero).mode=="手动": continue
				if hero.position.distance_to(game.escort.position)<120: continue
				var point: Vector2 = game._near_free(game.escort.position+Vector2(30+i*36,-45),hero)
				if point!=Vector2.INF: game._command_free(hero,point)
		game.step(1.0/60)
	print("CAMP_PROGRESSION camps=%d route=%d hp=%.1f gold=%d earned=%d seconds=%.3f" % [camps,game.route_index,game.escort.health,game.coins,game.earned_loot,game.battle_elapsed])
	check(game.state==game.GameState.RESULT and game.route_index==25 and camps==3 and game.escort.health>0,"full four-stage run includes three real camp transactions and reaches victory")
	check(game.earned_loot==20 and game.coins==13 and game.population==4 and monk.star==2,"full run balances earned rewards, purchase/upgrade/merge costs exactly")
	game._restart_demo()
	check(game.coins==3 and game.population==3 and game.camp_positions.points.is_empty(),"victory restart clears camp and economic history")
	game.free()

func merge_and_casualty() -> void:
	var game = fresh()
	game.coins = 30
	for i in range(3):
		var actor = purchase(game,"guard_monk")
		actor.merge_locked = true
		check(game._place_free(actor,game.escort.position+Vector2(50+i*45,-40)),"merge fixture deployed")
	var keeper = game.heroes[0]
	var old: Array = game.heroes.map(func(hero): return hero.position)
	quiet(game)
	game.pending_loot = 3
	game._enter_wave_preparation()
	for hero in game.heroes: hero.merge_locked = false
	game._select_hero(game.heroes[2])
	game._begin_swap()
	game._try_auto_merge("guard_monk",1)
	game._update_ui()
	check(game.heroes.size()==1 and keeper.star==2 and keeper.position==old[0],"merge keeps existing keeper identity and location")
	check(game.camp_positions.points.size()==3 and game._seat_hero(1)==null and game._seat_hero(2)==null and game.swap_source==null,"consumed field sources leave seats; pending swap safely cancels")
	var replacement = purchase(game,"wild_hunter")
	check(not game._place_free(replacement,old[1]+Vector2(0,70)),"merge cannot manufacture arbitrary new coordinates")
	check(game._place_free(replacement,old[1]) and game.hero_slots[1]==replacement,"merge-created vacancy can be filled exactly")
	ownership(game)
	game._start_battle()
	game.intermission = 999
	var survivor_at: Vector2 = keeper.position
	replacement.take_damage(10000)
	var fallen_at: Vector2 = replacement.position
	game.escort.position = Map.center(Vector2i(3,8))
	game._enter_wave_preparation()
	check(keeper.position==survivor_at,"loss does not move surviving team toward Tang")
	check(replacement.run_fallen and replacement.health==0 and replacement.position==fallen_at and game.casualties.seats.has(1),"camp never revives or relocates the casualty")
	check(not game._place_free(replacement,fallen_at+Vector2(45,0)),"fallen hero cannot redeploy in camp")
	game.free()
	# Keep transient-overlap coverage as an independent living-team fixture.
	game = camp_fixture()
	keeper = game.heroes[0]
	replacement = game.heroes[1]
	# A transient overlap at wave end must not provoke an automatic team move.
	game._start_battle()
	keeper.position = replacement.position
	game._enter_wave_preparation()
	var overlap: Vector2 = keeper.position
	check(replacement.position==overlap,"camp snapshot preserves transient friendly overlap without teleport")
	var reserve = purchase(game,"foxfire_imp")
	game._select_hero(keeper)
	game._begin_swap()
	check(game._swap_with_bench(reserve) and reserve.position==overlap and replacement.position==overlap,"identity-only swap inherits existing contact without inventing a new stop")
	game._select_hero(reserve)
	game._withdraw_selected()
	game._select_hero(replacement)
	game._withdraw_selected()
	check(game._place_free(reserve,overlap) and game._place_free(replacement,overlap),"overlapping saved empty seats remain individually refillable")
	game.free()
