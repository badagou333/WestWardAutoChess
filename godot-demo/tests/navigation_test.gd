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
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.state = game.GameState.BATTLE_RUNNING
	var hero = add_hero(game,Vector2i(0,0))
	hero.home_cell = Vector2i(0,1)
	var blocker = add_hero(game,Vector2i(0,1))
	game._spawn_enemy("wolf",Vector2i(0,3))
	var path = game._combat_path(hero,Vector2i(0,3),1,true)
	check(path.size()>1 and path[1]==Vector2i(1,0),"Detours around an occupied direct route")
	for i in range(1,path.size()):
		check(game._defense_step_allowed(path[i-1],path[i]),"Every path step obeys escort defense zone")
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
	game._spawn_enemy("rat",Vector2i(2,1))
	check(game._reachable_enemy(hero)==game.enemies[1],"Skips unreachable target")
	game.enemies[1].battle_cell = Vector2i(4,6)
	check(game._reachable_enemy(hero)==null,"No pursuit outside leash")
	# Regression: hunter can leave its old spawn leash to defend the other flank.
	hero.battle_cell = Vector2i(0,4)
	hero.home_cell = Vector2i(1,3)
	game.enemies[0].battle_cell = Vector2i(3,1)
	path = game._combat_path(hero,Vector2i(3,1),1,true)
	check(not path.is_empty(),"Can defend opposite flank beyond old spawn leash")
	check(game._cell_distance(path.back(),hero.home_cell)>2,"Regression crosses old leash")
	check(not game._defense_step_allowed(Vector2i(0,4),Vector2i(0,5)),"Cannot chase out of defense zone")
	check(game._defense_step_allowed(Vector2i(0,0),Vector2i(1,0)),"Edge deployment can enter zone")
	# No path through bodies: still wait rather than overlap occupied cells.
	var wall = add_hero(game,Vector2i(1,4))
	var wall2 = add_hero(game,Vector2i(0,3))
	check(game._combat_path(hero,Vector2i(3,1),1,true).is_empty(),"Sealed actor cannot cross teammates")
	wall.active_in_battle = false
	wall.battle_dead = true
	check(not game._combat_path(hero,Vector2i(3,1),1,true).is_empty(),"Released occupancy reopens path")
	game.free()
	print("NAVIGATION_TEST: failures=",failures)
	quit(1 if failures else 0)
