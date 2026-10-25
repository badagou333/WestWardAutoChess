extends Node2D
## Screen-horizontal rectangular arena. Only complete logical diamond cells
## are rendered as playable; geometry/interaction/pathfinding share Geometry.
const Geometry = preload("res://scripts/data/diamond_duel_board.gd")
var game

func setup(host) -> void:
	game = host
	z_index = -100
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _shape(points: PackedVector2Array, fill: Color, edge: Color, width: float = 1.0) -> void:
	draw_colored_polygon(points, fill)
	if edge.a > 0 and not points.is_empty():
		var loop: PackedVector2Array = points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, edge, width, true)

func _ellipse(at: Vector2, radius: Vector2, tint: Color) -> void:
	draw_set_transform(at, 0, radius)
	draw_circle(Vector2.ZERO, 1, tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if game == null: return
	draw_rect(Rect2(0, 0, 1920, 1080), Color("102126"))
	var arena: Rect2 = Geometry.ARENA
	# These are horizontal rectangles, not a rotated rectangular board. The
	# exposed stone perimeter is visibly different from a legal diamond cell.
	draw_rect(Rect2(arena.position + Vector2(-15, 15), arena.size + Vector2(30, 22)), Color("080f12"))
	draw_rect(arena.grow(13), Color("727b76"))
	draw_rect(arena.grow(7), Color("354d4d"))
	draw_rect(arena, Color("243c3e"))
	# Gentle horizontal stone courses belong only to the non-playable margin.
	for y in range(int(arena.position.y) + 24, int(arena.end.y), 48):
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color(.34, .43, .41, .15), 1, true)
	for cell in Geometry.cells():
		var checker: int = posmod(cell.x + cell.y, 2)
		var fill := Color("3e5652") if checker == 0 else Color("465e59")
		_shape(Geometry.polygon(cell), fill, Color("8a9c8b"), 1.4)
	_highlights()
	_shadows()

func _highlights() -> void:
	var chosen: Dictionary = game._record(str(game.selected))
	for cell in game.range_cells():
		if Geometry.valid(cell):
			_shape(Geometry.polygon(cell, 0.04), Color(.56, .78, .78, .09), Color(.65, .86, .81, .23), 1.2)
	if not chosen.is_empty() and Geometry.valid(chosen.cell):
		_shape(Geometry.polygon(chosen.cell, 0.035), Color(.94, .78, .45, .16), Color("f1d18d"), 3)
	var hover: Vector2i = game.hover_cell()
	if Geometry.valid(hover):
		var blocked := false
		if game.phase == game.Phase.DEPLOY and not chosen.is_empty():
			for actor in game.actors:
				if str(actor.id) != str(chosen.id) and actor.cell == hover:
					blocked = true
		_shape(Geometry.polygon(hover, 0.065), Color(.9, .84, .62, .07), Color("df8d76") if blocked else Color("d7d2ad"), 2)

func _shadows() -> void:
	for actor in game.actors:
		var node = actor.node
		if not is_instance_valid(node) or not node.visible: continue
		var opacity: float = node.modulate.a*node.presentation.visual_alpha
		if opacity <= 0: continue
		# A compact anchor-contact shadow, not fabricated per-foot contact data.
		# Unknown/airborne feet are deliberately not painted with false dots.
		var at: Vector2 = node.position
		var radius := Vector2(23, 6) if str(actor.id) == "monk" else Vector2(34, 8)
		for index in range(5, 0, -1):
			_ellipse(at, radius + Vector2(index * 1.9, index * .65), Color(.025, .045, .04, .035 * opacity))
		_ellipse(at, radius * .73, Color(.018, .035, .031, .16 * opacity))
