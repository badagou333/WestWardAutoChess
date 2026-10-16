extends Node2D
## A frontal, fixed-camera 2D diorama. Every ground edge shares GroundProjection.
## No mesh, camera, hidden 3D viewport or changes to the simulation live here.
const GroundProjection = preload("res://scripts/presentation/board_depth_projection.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
const INK := Color("172c30")
const GOLD := Color("c9b77c")
const BACKDROP=preload("res://art/boards/depth_trial_v1/woodland.png")
const STONE=preload("res://art/boards/depth_trial_v1/limestone.png")
var game
var stones: Array[Dictionary] = []
var leaves: Array[Dictionary] = []
var clock := 0.0

func setup(host) -> void:
	game = host
	var rng := RandomNumberGenerator.new()
	rng.seed = 1401026
	for y in range(7):
		for x in range(12):
			var facets: Array[PackedVector2Array] = []
			for j in range(4):
				var p := Vector2(x+rng.randf_range(0.1,0.75),y+rng.randf_range(0.1,0.8))
				facets.append(PackedVector2Array([GroundProjection.point(p),GroundProjection.point(p+Vector2(rng.randf_range(.12,.22),-.03)),GroundProjection.point(p+Vector2(.1,.12))]))
			stones.append({"cell":Vector2i(x,y),"tone":rng.randf_range(-.028,.028),"facets":facets})
	for i in range(34):
		leaves.append({"p":Vector2(rng.randf_range(210,1540),rng.randf_range(210,890)),"v":rng.randf_range(5,12),"phase":rng.randf_range(0,TAU)})
	queue_redraw()

func _process(delta: float) -> void:
	if game==null: return
	if not game.paused: clock += delta
	queue_redraw()

func shape(points: PackedVector2Array, color: Color, edge := Color.TRANSPARENT, width := 1.0) -> void:
	draw_colored_polygon(points,color)
	if edge.a>0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed,edge,width,true)

func plane(a: Vector2,b: Vector2,height := 0.0) -> PackedVector2Array:
	var down := Vector2(0,height)
	return PackedVector2Array([GroundProjection.point(a)+down,GroundProjection.point(Vector2(b.x,a.y))+down,GroundProjection.point(b)+down,GroundProjection.point(Vector2(a.x,b.y))+down])

func stone_face(points: PackedVector2Array,tint: Color) -> void:
	draw_polygon(points,PackedColorArray([tint]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,.2),Vector2(0,.2)]),STONE)

func ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(at,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if game==null: return
	_environment()
	_platform()
	_tiles()
	_highlights()
	_shadows()
	# Matching, frontal lanterns stand outside the far/near playable edges.
	# An orthographic camera does not make the back pair smaller.
	_lantern(GroundProjection.point(Vector2(.2,-.36)),1.0)
	_lantern(GroundProjection.point(Vector2(11.8,-.36)),1.0)
	_lantern(GroundProjection.point(Vector2(.2,7.98)),1.0)
	_lantern(GroundProjection.point(Vector2(11.8,7.98)),1.0)
	for leaf in leaves:
		var p: Vector2 = leaf.p+Vector2(sin(clock*.22+leaf.phase)*8,fmod(clock*leaf.v,45))
		if p.y<260 or p.y>820:
			shape(PackedVector2Array([p,p+Vector2(5,-3),p+Vector2(10,0),p+Vector2(4,2)]),Color(.54,.47,.28,.38))

func _environment() -> void:
	draw_rect(Rect2(0,0,1920,1080),Color("13282d"))
	draw_texture_rect(BACKDROP,Rect2(0,0,1920,1080),false,Color(.85,.91,.90))
	# Grounded, diffuse foundation shadow — several transparent bands, not a box.
	for i in range(16,-1,-1):
		var pad := .2+i*.028
		shape(plane(Vector2(-pad,-pad),Vector2(12+pad,7+pad),45+i*2),Color(0.005,.018,.020,.025))

func _platform() -> void:
	var edge := .22
	var a := GroundProjection.point(Vector2(-edge,-edge))
	var b := GroundProjection.point(Vector2(12+edge,-edge))
	var c := GroundProjection.point(Vector2(12+edge,7+edge))
	var d := GroundProjection.point(Vector2(-edge,7+edge))
	var down := Vector2(0,40)
	# Looking straight along the depth axis exposes the front fascia, not an
	# invented left/right side. The old slanted side would collapse to zero area.
	stone_face(PackedVector2Array([d,c,c+down,d+down]),Color(.48,.61,.56))
	for x in range(13):
		var p:=GroundProjection.point(Vector2(x,7+edge))
		draw_line(p+Vector2(0,8),p+down,Color("2b403e"),2,true)
	stone_face(PackedVector2Array([a,b,c,d]),Color(.77,.88,.81))
	# A narrow stone bevel catches the light on the top, another closes the fascia.
	draw_line(a,b,Color("aab39b"),2,true)
	draw_line(a,d,Color("b6b99b"),3,true)
	draw_line(b,c,Color("8d9e8b"),2,true)
	draw_line(d,c,Color("a3ad93"),3,true)
	draw_line(d+down,c+down,Color("253d3b"),3,true)
	draw_line(d+Vector2(0,10),c+Vector2(0,10),Color("5b7066"),2,true)
	# Two centered entrance steps, with parallel horizontal fronts and no skew.
	for i in [1,0]:
		var top := plane(Vector2(4.7,7.20+i*.32),Vector2(7.3,7.52+i*.32),14+i*13)
		shape(PackedVector2Array([top[3],top[2],top[2]+Vector2(0,13),top[3]+Vector2(0,13)]),Color("3e5350"),INK,1)
		shape(top,Color("748477"),Color("a4ac91"),1)
		for x in range(5,8):
			draw_line(GroundProjection.point(Vector2(x,7.20+i*.32))+Vector2(0,14+i*13),GroundProjection.point(Vector2(x,7.52+i*.32))+Vector2(0,14+i*13),Color("53685f"),1,true)

func _tiles() -> void:
	shape(plane(Vector2.ZERO,Vector2(12,7)),Color("455c56"))
	for stone in stones:
		var cell: Vector2i = stone.cell
		var p := GroundProjection.polygon(cell,.014)
		var checker := .018 if (cell.x+cell.y)%2==0 else -.012
		var tone: float = stone.tone+checker
		var uv0:=Vector2((cell.x*53%67)/100.0,(cell.y*43%67)/100.0)
		var uv:=PackedVector2Array([uv0,uv0+Vector2(.22,0),uv0+Vector2(.22,.22),uv0+Vector2(0,.22)])
		var tint:=Color(.84+tone,.91+tone,.87+tone)
		draw_polygon(p,PackedColorArray([tint]),uv,STONE)
		draw_line(p[0]+Vector2(0,1),p[1]+Vector2(0,1),Color(.75,.77,.63,.40),1.2,true)
		draw_line(p[0],p[3],Color(.70,.75,.62,.30),1,true)
		draw_line(p[3],p[2],Color(.21,.32,.29,.34),1.0,true)
		for facet in stone.facets: shape(facet,Color(.75,.77,.66,.06))
		if (cell.x*3+cell.y*7)%11==0:
			var m := GroundProjection.point(Vector2(cell)+Vector2(.14,.08))
			draw_polyline(PackedVector2Array([m,m+Vector2(7,6),m+Vector2(5,11),m+Vector2(14,16)]),Color(.20,.32,.29,.23),1,true)
	# Brass inlay only at the perimeter. No giant opaque checkerboard overlay.
	for y in range(7):
		var p:=GroundProjection.point(Vector2(-.11,y+.5))
		draw_line(p-Vector2(0,3),p+Vector2(0,3),GOLD.darkened(.25),2,true)
	if game.phase==game.Phase.DEPLOY:
		for row in range(7):
			var a:=GroundProjection.point(Vector2(6,row+.32))
			var b:=GroundProjection.point(Vector2(6,row+.65))
			draw_line(a,b,Color(.82,.74,.48,.55),2,true)

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
				ellipse(at+Vector2(view.facing*8,-2),Vector2(7+i*4,2+i*1.1),Color(.98,.37,.07,.013))

func _lantern(p: Vector2, size_factor: float) -> void:
	draw_set_transform(p,0,Vector2.ONE*size_factor)
	# Rectangular footing and symmetric roof obey the same non-rotated camera.
	shape(PackedVector2Array([Vector2(-19,0),Vector2(19,0),Vector2(19,8),Vector2(-19,8)]),Color("415a54"),INK,1.5)
	shape(PackedVector2Array([Vector2(-19,-8),Vector2(19,-8),Vector2(19,0),Vector2(-19,0)]),Color("728678"),INK,1.5)
	draw_rect(Rect2(-7,-32,14,29),Color("526b60"))
	draw_line(Vector2(-7,-32),Vector2(-7,-4),Color("859481"),1.5,true)
	shape(PackedVector2Array([Vector2(-13,-32),Vector2(-13,-58),Vector2(13,-58),Vector2(13,-32)]),Color("2c4542"),INK,2)
	draw_rect(Rect2(-7,-53,14,16),Color("ecb95f"))
	draw_rect(Rect2(-3,-51,6,12),Color("ffe0a1"))
	shape(PackedVector2Array([Vector2(-23,-57),Vector2(-8,-70),Vector2(8,-70),Vector2(23,-57)]),Color("668577"),INK,2)
	draw_line(Vector2(-19,-59),Vector2(-7,-68),Color("a2ab82"),1.5,true)
	draw_line(Vector2(-23,-56),Vector2(23,-56),Color("253d3a"),2,true)
	draw_set_transform(Vector2.ZERO)
