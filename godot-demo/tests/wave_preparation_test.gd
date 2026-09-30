extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func play_wave(game):
	game._start_battle()
	for tick in range(120*120):
		game.step(1.0/120)
		if game.state != game.GameState.BATTLE_RUNNING: return
	check(false,"Wave must terminate within 120 seconds")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.coins==3,"Three-coin start")
	game._start_battle()
	check(game.state==game.GameState.PREPARING,"Cannot start empty board")
	for i in [0,1,2]: game._on_shop_pressed(i)
	var cells = [Vector2i(2,2),Vector2i(1,3),Vector2i(3,3)]
	for i in range(3): game._place_hero_on_board(game.heroes[i],cells[i])
	play_wave(game)
	check(game.wave_index==0 and game.state==game.GameState.PREPARING,"First clear waits for player")
	check(game.coins==3 and game.earned_loot==3 and game.pending_loot==0,"First wave reward spendable immediately")
	check(game.shop_open and game.shop_types.size()==3,"Camp restocks exactly three offers")
	check(game.combat.strikes.is_empty() and game.combat.missiles.is_empty() and game.moving.is_empty(),"No old combat pending")
	var elapsed: float = game.battle_elapsed
	var hp: float = game.escort.health
	game.step(30)
	check(game.state==game.GameState.PREPARING and game.battle_elapsed==elapsed and game.escort.health==hp,"Preparation does not auto-advance or damage escort")
	game._enter_wave_preparation()
	check(game.coins==3,"No duplicate wave payment")
	for hero in game.heroes:
		check(hero.health==hero.max_health and not hero.battle_dead and hero.position==game._cell_center(Vector2i(hero.board_row,hero.board_col)),"Heroes recover and return to saved formation")
	game._on_refresh_pressed()
	check(game.coins==1,"First refresh costs two")
	game._on_refresh_pressed()
	check(game.coins==1,"Insufficient gold rejects second refresh")
	# Controlled stock tests purchase/merge across waves, without injecting gold.
	game.shop_types[0] = "guard_monk"
	game._on_shop_pressed(0)
	check(game.heroes.size()==4 and game.coins==0,"Purchase during inter-wave preparation")
	game.escort.health = 250
	game._place_hero_on_board(game.heroes[1],Vector2i(1,4))
	game._start_battle()
	check(game.wave_index==1 and game.escort.health==250,"Next wave preserves escort health and advances once")
	var count: int = game.heroes.size()
	game._on_shop_pressed(1)
	game._on_refresh_pressed()
	check(game.heroes.size()==count and game.coins==0,"No shopping during battle")
	for tick in range(120*120):
		game.step(1.0/120)
		if game.state!=game.GameState.BATTLE_RUNNING: break
	check(game.state==game.GameState.PREPARING and game.coins==4,"Second wave rewards")
	game.shop_types[0] = "guard_monk"
	game._on_shop_pressed(0)
	check(game.heroes[0].star==2 and game.heroes.size()==3 and game.coins==3,"Cross-wave three-of-a-kind merges")
	var kept = game.heroes[0]
	play_wave(game)
	check(game.state==game.GameState.PREPARING and game.coins==9,"Third wave rewards")
	game._on_level_pressed()
	check(game.population==4 and game.coins==5,"Affordable population upgrade")
	game.shop_types[0] = "foxfire_imp"
	game._on_shop_pressed(0)
	game._place_hero_on_board(game.heroes.back(),Vector2i(2,4))
	check(game._deployed_count()==4,"Fourth unit deploys")
	play_wave(game)
	check(game.state==game.GameState.RESULT and game.wave_index==3 and not game.escort.dead,"Four-wave victory with preparation purchases")
	check(kept.star==2 and game.earned_loot==20 and game.coins==11,"Merged unit persists and no double final reward")
	game._finish_battle(true)
	check(game.coins==11,"Result idempotent")
	game._restart_demo()
	check(game.coins==3 and game.wave_index==-1 and game.earned_loot==0 and game.pending_loot==0,"Restart resets entire run")
	# A defeated unit is recoverable next wave, not lost from owned roster.
	game._on_shop_pressed(0)
	game._place_hero_on_board(game.heroes[0],Vector2i(2,2))
	game._start_battle()
	game.heroes[0].take_damage(9999)
	game.spawn_queue.clear(); game.spawn_entries.clear(); game.intermission=0
	game._enter_wave_preparation()
	check(not game.heroes[0].battle_dead and not game.heroes[0].presentation.dead and game.heroes[0].health==game.heroes[0].max_health,"Defeated hero restored for next wave")
	game._start_battle()
	game.pending_loot = 2
	var before: int = game.coins
	game.escort.take_damage(9999)
	game.step(0.05)
	check(game.state==game.GameState.RESULT and game.coins==before,"Failed wave pays no pending loot")
	game._restart_demo()
	game.pending_loot = 6
	game.escort.health = 100
	game._settle_wave_loot()
	check(game.coins==8 and game.last_wave_reward==5,"Health multiplier retained per wave")
	game.free()
	print("WAVE_PREPARATION: failures=",failures)
	quit(1 if failures else 0)
