extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func add_hero(game, cell: Vector2i, key := "guard_monk"):
	var hero = game.HeroScene.new()
	hero.setup(key)
	hero.board_row = cell.x
	hero.board_col = cell.y
	hero.position = game._cell_center(cell)
	hero.set_bench_mode(false)
	game.add_child(hero)
	game.heroes.append(hero)
	hero.begin_battle()
	return hero
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state = game.GameState.BATTLE_RUNNING
	var hero = add_hero(game,Vector2i(0,0))
	hero.home_cell = Vector2i(0,1)
	var blocker = add_hero(game,Vector2i(0,1))
	game._spawn_enemy("wolf",Vector2i(0,3))
	var path = game._combat_path(hero,Vector2i(0,3),1,true)
	check(path.size()>1 and path[1]==Vector2i(1,0),"Detours around an occupied direct route")
	for cell in path:
		check(game._cell_distance(cell,hero.home_cell)<=2,"Every path step obeys leash")
	check(hero.presentation.visual_transform().origin.is_equal_approx(Vector2.ZERO),"Hero foot at cell center")
	check(game.enemies[0].presentation.visual_transform().origin.is_equal_approx(Vector2.ZERO),"Wolf foot at cell center")
	game._move_hero_toward(hero,Vector2i(0,3))
	check(game._is_moving(hero),"Starts detour movement")
	check(game._cell_blocked(Vector2i(0,0),blocker),"Moving actor reserves source")
	check(game._cell_blocked(Vector2i(1,0),blocker),"Moving actor reserves destination")
	game.moving.clear()
	hero.battle_cell = Vector2i(0,0)
	hero.home_cell = Vector2i(0,0)
	game.enemies[0].battle_cell = Vector2i(0,6)
	game._spawn_enemy("rat",Vector2i(2,0))
	check(game._reachable_enemy(hero)==game.enemies[1],"Skips unreachable target")
	game.enemies[1].battle_cell = Vector2i(4,6)
	check(game._reachable_enemy(hero)==null,"No pursuit outside leash")
	# A closer target sealed behind bodies must not hide another reachable enemy.
	hero.home_cell = Vector2i(0,1)
	game.enemies[0].battle_cell = Vector2i(0,2)
	var wall = add_hero(game,Vector2i(1,2))
	game.enemies[1].battle_cell = Vector2i(2,0)
	check(game._reachable_enemy(hero)==game.enemies[1],"Chooses reachable enemy over blocked nearest")
	var healer = add_hero(game,Vector2i(4,6),"herbal_spirit_child")
	hero.health = 1
	wall.battle_cell = Vector2i(3,4)
	wall.health -= 1
	check(game._healing_target(healer)==wall,"Healer skips unreachable injured ally")
	game.free()
	print("NAVIGATION_TEST: failures=",failures)
	quit(1 if failures else 0)
