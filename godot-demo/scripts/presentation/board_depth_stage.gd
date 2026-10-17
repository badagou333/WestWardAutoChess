extends Node2D
## D002 clean static scene plus exact projected overlays and live actor shadows.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const BACKDROP = preload("res://art/boards/perspective_stage_v1/scene-clean.png")
var game

func setup(host) -> void:
	game=host
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func shape(points: PackedVector2Array, color: Color, edge := Color.TRANSPARENT, width := 1.0) -> void:
	draw_colored_polygon(points,color)
	if edge.a>0:
		var closed:=points.duplicate()
		closed.append(points[0])
		draw_polyline(closed,edge,width,true)

func ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(at,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if game==null: return
	draw_rect(Rect2(0,0,1920,1080),Color("102323"))
	draw_texture_rect(BACKDROP,GroundProjection.IMAGE_RECT,false)
	# The delivered scene already contains the forest, rim, steps and four lamps.
	# Only this exact 12x7 grid is added; no old platform/material is composited.
	for col in range(Config.COLS+1):
		draw_line(GroundProjection.point(Vector2(col,0)),GroundProjection.point(Vector2(col,Config.ROWS)),Color(.16,.22,.20,.42),1.2,true)
	for row in range(Config.ROWS+1):
		draw_line(GroundProjection.point(Vector2(0,row)),GroundProjection.point(Vector2(Config.COLS,row)),Color(.16,.22,.20,.42),1.2,true)
	if game.phase==game.Phase.DEPLOY:
		for row in range(Config.ROWS):
			draw_line(GroundProjection.point(Vector2(Config.DEPLOY_COLS,row+.25)),GroundProjection.point(Vector2(Config.DEPLOY_COLS,row+.70)),Color(.87,.76,.45,.75),2,true)
	_highlights()
	_shadows()

func _highlights() -> void:
	var selected: Dictionary=game._record(game.selected)
	for cell in game.range_cells():
		shape(GroundProjection.polygon(cell,.045),Color(.54,.76,.75,.065),Color(.63,.83,.78,.16),1)
	if not selected.is_empty() and Config.valid(selected.cell):
		shape(GroundProjection.polygon(selected.cell,.025),Color(.87,.74,.40,.13),Color("ead59a"),2.4)
	var hover: Vector2i=game.hover_cell()
	if Config.valid(hover):
		var invalid: bool=game.phase==game.Phase.DEPLOY and not selected.is_empty() and selected.friendly and not Config.deployable(hover)
		shape(GroundProjection.polygon(hover,.04),Color(.87,.75,.43,.06),Color("dc836e") if invalid else Color(.92,.87,.64,.70),1.8)

func _shadows() -> void:
	for actor in game.actors:
		var node=actor.node
		if not is_instance_valid(node) or not node.visible: continue
		var view=node.presentation
		var opacity: float=view.visual_alpha
		if opacity<=0: continue
		var at: Vector2=node.position+view.ground_offset()*node.scale
		var sample: Dictionary=view.draw_sample() if view.has_method("draw_sample") else {}
		if not sample.is_empty():
			# Use exactly the same crop, source scale, pivot and front/back bank
			# as the visible body. Contact points retain both feet's depth offsets.
			var cast:=Transform2D(Vector2(node.scale.x,0),Vector2(-.46,-.19)*node.scale.y,at+Vector2(2,2))
			draw_set_transform_matrix(cast*Transform2D(sample.transform))
			if not sample.polygon.is_empty():
				draw_colored_polygon(sample.polygon,Color(.016,.035,.030,.23*opacity),sample.uvs,sample.texture)
			else:
				draw_texture_rect_region(sample.texture,sample.destination,sample.region,Color(.016,.035,.030,.23*opacity))
		else:
			var texture: Texture2D=view.body
			var frame: int=view.frame_index
			if view.motion_sample_enabled: texture=view.sample_body
			elif view.motion_frame>=0:
				texture=view.motion_body
				frame=view.motion_frame
			var facing: float=view.visual_transform().x.x
			var cast:=Transform2D(Vector2(facing*node.scale.x,0),Vector2(-.46,-.19)*node.scale.y,at+Vector2(2,2))
			draw_set_transform_matrix(cast)
			draw_texture_rect_region(texture,Rect2(-128,-218,256,256),Rect2(frame*256,0,256,256),Color(.016,.035,.030,.23*opacity))
		draw_set_transform(Vector2.ZERO)
		var width := 25.0 if actor.key not in ["bear_lord","boar","wolf"] else 33.0
		for i in range(8,0,-1):
			ellipse(at,Vector2(width+i*.6,5+i*.48)*node.scale,Color(.025,.055,.043,.031*opacity))
		ellipse(at,Vector2(width*.66,3.5)*node.scale,Color(.03,.055,.04,.20*opacity))
		var feet: Array[Vector2]=[Vector2(-10,0),Vector2(12,0)]
		match actor.key:
			"guard_monk", "boar", "bear_lord": feet=[Vector2(-23,0),Vector2(23,0)]
			"wolf": feet=[Vector2(-26,-3),Vector2(-12,0),Vector2(15,-3),Vector2(29,0)]
			"tangseng": feet=[Vector2(-7,0),Vector2(3,0)]
		if not sample.is_empty(): feet.assign(sample.feet)
		for foot in feet:
			ellipse(at+foot*node.scale,Vector2(7,2.5)*node.scale,Color(.018,.039,.025,.32*opacity))
		if actor.key=="foxfire_imp" and not actor.dead:
			for i in range(7,0,-1):
				ellipse(at+Vector2(view.facing*8,-2)*node.scale,Vector2(7+i*4,2+i*1.1)*node.scale,Color(.98,.37,.07,.013))
