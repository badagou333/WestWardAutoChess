extends "res://tests/camp_roster_test.gd"
## Ownership/HP/coordinate invariants, independent of rendered UI hit testing.
func run() -> void:
	for camp in [false,true]:
		var game = camp_fixture() if camp else fresh()
		if not camp: recruit(game)
		game.coins = 50
		var a = game.heroes[0]
		var b = game.heroes[1]
		a.upgrade()
		a.health = 41.5
		b.health = 27.25
		var point_a: Vector2 = a.position
		var point_b: Vector2 = b.position
		var ledger: Dictionary = game.camp_positions.points.duplicate()
		var wallet: int = game.coins
		var count: int = game.heroes.size()
		game._brain(a).mode = "手动"
		game._brain(b).mode = "归位"
		game._select_hero(a)
		game._begin_swap()
		check(game._swap_heroes(b),"field exchange valid both initially and in camp")
		check(a.position==point_b and b.position==point_a and game.hero_slots[0]==b and game.hero_slots[1]==a,"coordinates and numbers stay with slots")
		check(a.health==41.5 and b.health==27.25 and a.star==2 and b.star==1,"exact health and star follow identities")
		check(game.coins==wallet and game.heroes.size()==count and game._deployed_count()==3 and game.camp_positions.points==ledger,"exchange cannot mint coordinates, gold or heroes")
		check(not game.brains.has(a) and not game.brains.has(b) and game.guard_anchors[a]==point_b and game.guard_anchors[b]==point_a,"both old commands cleared and new anchors assigned")
		check(game.selected_hero==null and game.swap_source==null and game.carry_hero==null,"successful exchange releases all selection gestures")
		check(not game._swap_heroes(a),"repeated completion never repeats transaction")
		ownership(game)
		game._select_hero(b)
		game._begin_swap()
		a.battle_dead = true
		check(not game._swap_heroes(a) and b.position==point_a,"dead target is never exchanged")
		a.battle_dead = false
		b.battle_dead = true
		game._validate_swap()
		check(game.swap_source==null and not game._swap_heroes(a),"dead source cancels pending exchange")
		b.battle_dead = false
		game._select_hero(b)
		game._begin_swap()
		b.upgrade()
		game._validate_swap()
		check(game.swap_source==null,"source merged/upgraded cancels pending exchange")
		# Full bench swap must preserve exact, non-full HP as well as ownership.
		for hero in game.heroes: hero.merge_locked = true
		for i in range(8):
			var reserve = purchase(game,"guard_monk")
			reserve.merge_locked = true
		var incoming = game._hero_in_bench(7)
		incoming.health = 13.75
		b.health = 22.5
		game._select_hero(b)
		game._begin_swap()
		check(game._swap_heroes(incoming),"full-bench exchange uses one atomic transaction")
		check(incoming.health==13.75 and b.health==22.5 and b.bench_slot==7 and incoming.position==point_a and game.selected_hero==null,"bench exchange preserves each actor's HP and releases selection")
		ownership(game)
		game._select_hero(a)
		game._begin_swap()
		game._set_shop_open(false)
		check(game.swap_source==null and not game.bench_open,"panel close cancels exchange")
		game._begin_swap()
		game._start_battle()
		check(game.swap_source==null and not game.bench_open and not game.shop_open,"phase entry clears swap and closes both panels")
		game._select_hero(a)
		game._begin_swap()
		check(game.swap_source==null and not game._swap_heroes(incoming),"battle never permits field teleport")
		game.free()
	# A source removed from inventory while still referenced is also invalid.
	var game = camp_fixture()
	var source = game.heroes[0]
	game._select_hero(source)
	game._begin_swap()
	game.heroes.erase(source)
	game._validate_swap()
	check(game.swap_source==null,"removed source cancels without writing ownership")
	source.free()
	game._update_ui()
	check(game.roster_hud.slots[0].is_empty(),"freed slot is empty in HUD, not renumbered")
	game.free()
	print("OPERATION_ROSTER_TEST failures=",failures)
	quit(1 if failures else 0)
