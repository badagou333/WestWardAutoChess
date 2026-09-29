extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var geometry = game.BoardGeometry
	check(game.painted_board,"Main uses calibrated projection")
	check(game.escort.position==game._cell_center(Vector2i(2,3)),"Escort remains logical center")
	for row in range(5):
		for col in range(7):
			var cell = Vector2i(row,col)
			var center = game._cell_center(cell)
			check(game._screen_to_cell(center)==cell,"Center click round trip")
			var polygon = geometry.polygon(cell)
			for corner in polygon:
				check(game._screen_to_cell(center.lerp(corner,0.95))==cell,"Near-corner interior click")
			if cell==game.CENTER_CELL: continue
			game._restart_demo()
			game._on_shop_pressed(0)
			var hero = game.heroes[0]
			game._begin_pointer_action(hero.position)
			game.dragging = true
			game._end_pointer_action(center)
			check(Vector2i(hero.board_row,hero.board_col)==cell and hero.position==center,"Drag placement matches stone")
			check((hero.position+hero.presentation.visual_transform().origin).is_equal_approx(center),"Foot at stone center")
	check(game._screen_to_cell(Vector2(960,200))==Vector2i(-1,-1),"Temple is not a deploy cell")
	check(game._screen_to_cell(Vector2(960,900))==Vector2i(-1,-1),"Below board is not a deploy cell")
	game._place_hero_on_board(game.heroes[0],game.CENTER_CELL)
	check(Vector2i(game.heroes[0].board_row,game.heroes[0].board_col)!=game.CENTER_CELL,"Center cannot be occupied")
	game._spawn_enemy("boar",Vector2i(0,0))
	check(game.enemies[0].presentation.manifest.sources[0].path.contains("style-unification-v1"),"Painted boar pack selected")
	game.free()
	print("BOARD_GEOMETRY: failures=",failures)
	quit(1 if failures else 0)
