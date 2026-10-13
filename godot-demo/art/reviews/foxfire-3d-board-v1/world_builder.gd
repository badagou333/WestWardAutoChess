extends RefCounted
## Original small diorama. All scenery is generated from geometry, no borrowed game assets.

static func mat(hex_color: String, roughness: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex_color)
	m.roughness = roughness
	m.metallic_specular = 0.18
	return m

static func mineral(hex_color: String) -> ShaderMaterial:
	# Low-frequency mineral variation, generated in world space. No image assets.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 stone_color : source_color;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_position.xz;
 float broad=noise(p*2.8)*0.6+noise(p*8.2)*0.28+noise(p*26.0)*0.12;
 ALBEDO=stone_color.rgb*mix(0.81,1.07,broad);
 ROUGHNESS=0.94; SPECULAR=0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("stone_color",Color(hex_color))
	return material

static func instance(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.position = position
	parent.add_child(item)
	return item

static func box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return instance(parent, mesh, position, material)

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, top: float = -1.0, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return instance(parent, mesh, position, material)

static func branch(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var part := cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), material, radius * 0.55, 7)
	var direction := (b - a).normalized()
	part.quaternion = Quaternion(Vector3.UP, direction)
	return part

static func stone(parent: Node3D, center: Vector3, size: Vector3, material: Material, bevel: float = 0.08) -> MeshInstance3D:
	# Chamfered block: broad planes, a narrow catching rim, no infinitely sharp cubes.
	var x: float = size.x * 0.5
	var z: float = size.z * 0.5
	var y: float = size.y * 0.5
	var b: float = minf(bevel, minf(x, minf(y * 0.8, z)))
	var outline: Array[Vector2] = [Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
	var bottom: Array[Vector3] = []
	var rim: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for v in outline:
		bottom.append(Vector3(v.x,-y,v.y))
		rim.append(Vector3(v.x,y-b,v.y))
		upper.append(Vector3(v.x * (1.0-b/x), y, v.y * (1.0-b/z)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(8):
		var j: int = (i+1)%8
		tri(st, upper[j], Vector3(0,y,0), upper[i])
		quad(st, rim[j], upper[j], upper[i], rim[i])
		quad(st, bottom[j], rim[j], rim[i], bottom[i])
	st.generate_normals()
	return instance(parent, st.commit(), center, material)

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(st,a,b,c)
	tri(st,a,c,d)

static func rock(parent: Node3D, point: Vector3, scale_value: Vector3, material: Material, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 3
	var geo := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = geo[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		# Deterministic displacement shared by seam-coincident vertices.
		var k: float = 1.0 + 0.13*sin(v.x*19.0 + v.y*11.0 + v.z*17.0)
		vertices[i] = v * k
	geo[Mesh.ARRAY_VERTEX] = vertices
	geo[Mesh.ARRAY_NORMAL] = null
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,geo)
	var surface := SurfaceTool.new()
	surface.create_from(array_mesh,0)
	surface.deindex()
	surface.set_smooth_group(-1)
	surface.generate_normals()
	var item := instance(parent,surface.commit(),point,material)
	item.scale = scale_value
	item.rotation.y = rng.randf_range(-PI,PI)
	return item

static func foliage(parent: Node3D, point: Vector3, radius: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 9
	mesh.rings = 4
	var node := instance(parent,mesh,point,material)
	node.scale = radius
	return node

static func tree(parent: Node3D, position: Vector3, height: float, autumn: bool, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = position
	parent.add_child(root)
	var bark := mineral("514b40")
	var bend := Vector3(rng.randf_range(-.18,.18),height*.47,.1)
	var trunk_top := Vector3(.12,height*.92,-.06)
	branch(root, Vector3.ZERO, bend, height*.052, bark)
	branch(root, bend, trunk_top, height*.039, bark)
	var palette: Array[String] = ["203e39","2d5143","42694e","4c7054"]
	if autumn:
		palette = ["5c3634","784137","91583b","a67847"]
	var leaf_mats: Array[ShaderMaterial] = []
	for tint in palette: leaf_mats.append(mineral(tint))
	# Irregular spreading pine tiers. Thin foliage fans reveal the branching structure.
	for i in range(8):
		var angle: float = i * 2.40 + rng.randf_range(-.2,.2)
		var level: float = float(i)/8.0
		var radius: float = height * lerpf(.35,.16,level)
		var base := Vector3(.04,height*(.38+level*.43),.04)
		var end := Vector3(cos(angle)*radius,height*(.51+level*.43),sin(angle)*radius)
		branch(root,base,end,.068,bark)
		for j in range(5):
			var offset := Vector3(rng.randf_range(-.42,.42),rng.randf_range(-.07,.10),rng.randf_range(-.37,.37))
			var extent: float = height*rng.randf_range(.17,.24)
			rock(root,end+offset,Vector3(extent,extent*.37,extent*.82),leaf_mats[(i+j)%4],rng)
	for i in range(3):
		rock(root,trunk_top+Vector3(rng.randf_range(-.22,.22),.02,rng.randf_range(-.22,.22)),Vector3(height*.27,height*.12,height*.25),leaf_mats[2+i%2],rng)
	for i in range(4):
		var angle: float = i*PI*.5
		branch(root,Vector3(0,.18,0),Vector3(cos(angle)*.55,-.02,sin(angle)*.55),.095,bark)

static func landform(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var upper: Array[Vector3] = []
	var middle: Array[Vector3] = []
	var lower: Array[Vector3] = []
	for i in range(40):
		var a: float = float(i)/40.0*TAU
		# Superellipse follows the court while giving its rocky foundation an organic edge.
		var sx: float = signf(cos(a))*pow(absf(cos(a)),.57)
		var sz: float = signf(sin(a))*pow(absf(sin(a)),.57)
		var jitter: float = rng.randf_range(.94,1.06)
		upper.append(Vector3(sx*7.24*jitter,-.42+rng.randf_range(-.10,.02),sz*4.58*jitter))
		middle.append(Vector3(sx*7.35*jitter,-1.22+rng.randf_range(-.15,.15),sz*4.70*jitter))
		lower.append(Vector3(sx*6.80*jitter,-2.20+rng.randf_range(-.20,.10),sz*4.40*jitter))
	for i in range(40):
		var j: int = (i+1)%40
		tri(st,upper[j],Vector3(0,-.44,0),upper[i])
		quad(st,middle[j],upper[j],upper[i],middle[i])
		quad(st,lower[j],middle[j],middle[i],lower[i])
	st.generate_normals()
	instance(parent,st.commit(),Vector3.ZERO,mineral("344b50"))

static func roof(parent: Node3D, center: Vector3, width: float, depth: float, material: Material) -> void:
	# Two curved eaves and their fascia; modelled surfaces catch the shared key light.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for i in range(5):
			var t: float = float(i)/5.0
			var u: float = float(i+1)/5.0
			var za: float = float(side) * depth*.5*t
			var zb: float = float(side) * depth*.5*u
			var ya: float = .54 - .80*t + .39*t*t*t
			var yb: float = .54 - .80*u + .39*u*u*u
			var a := Vector3(-width*.5-.22*t*t,ya,za)
			var b := Vector3(width*.5+.22*t*t,ya,za)
			var c := Vector3(width*.5+.22*u*u,yb,zb)
			var d := Vector3(-width*.5-.22*u*u,yb,zb)
			if side==1: quad(st,a,b,c,d)
			else: quad(st,d,c,b,a)
	st.generate_normals()
	var shell := instance(parent,st.commit(),center,material)
	var roof_mat := material.duplicate() as StandardMaterial3D
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = roof_mat
	box(parent,center+Vector3(0,.51,0),Vector3(width+.32,.16,.20),mat("66776b"))
	for side in [-1,1]:
		box(parent,center+Vector3(0,.10,float(side)*depth*.5),Vector3(width+.50,.15,.14),mat("3b5651"))
	# Restrained tile courses rather than a noisy roof texture.
	for i in range(17):
		var xx: float = (float(i)/16.0-.5)*width
		for side in [-1,1]:
			var last := center+Vector3(xx,.55,0)
			for j in range(1,4):
				var t: float = float(j)/3.0
				var next := center+Vector3(xx,.56-.80*t+.39*t*t*t,float(side)*depth*.5*t)
				branch(parent,last,next,.024,mat("5b7165"))
				last=next

static func lantern(parent: Node3D, point: Vector3, large: bool = false) -> void:
	var node := Node3D.new()
	parent.add_child(node)
	node.position=point
	var stone_mat := mat("657467")
	var metal := mat("574b36",.72)
	stone(node,Vector3(0,.08,0),Vector3(.65,.16,.65),stone_mat,.05)
	cylinder(node,Vector3(0,.48,0),.105,.72,stone_mat)
	stone(node,Vector3(0,.81,0),Vector3(.55,.13,.55),stone_mat,.03)
	var glow := mat("ffbe64",.8)
	glow.emission_enabled=true
	glow.emission=Color("efad58")
	glow.emission_energy_multiplier=.8
	box(node,Vector3(0,1.04,0),Vector3(.29,.39,.29),glow)
	for x in [-1,1]:
		for z in [-1,1]:
			box(node,Vector3(x*.17,1.04,z*.17),Vector3(.055,.46,.055),metal)
	cylinder(node,Vector3(0,1.29,0),.45,.18,metal,.09,4)
	cylinder(node,Vector3(0,1.42,0),.055,.10,metal,.018,8)
	var light := OmniLight3D.new()
	light.position=Vector3(0,1.1,0)
	light.light_color=Color("ffc275")
	light.light_energy=.9 if large else .55
	light.omni_range=2.2
	light.shadow_enabled=false
	node.add_child(light)

static func build(parent: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=492861
	var environment_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("1c3237")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("bac8d2")
	env.ambient_light_energy=.44
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_exposure=1.0
	env.ssao_enabled=true
	env.ssao_radius=.72
	env.ssao_intensity=1.7
	env.ssao_power=1.5
	env.ssao_light_affect=.35
	env.glow_enabled=true
	env.glow_intensity=.45
	env.glow_bloom=.04
	env.fog_enabled=true
	env.fog_light_color=Color("365356")
	env.fog_density=.004
	environment_node.environment=env
	parent.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.name="WarmKey"
	sun.rotation_degrees=Vector3(-55,-32,0)
	sun.light_color=Color("ffe8c6")
	sun.light_energy=1.05
	sun.light_angular_distance=2.0
	sun.shadow_enabled=not OS.get_cmdline_user_args().has("--no-shadow")
	sun.directional_shadow_max_distance=55.0
	sun.shadow_bias=.07
	sun.shadow_normal_bias=1.0
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-42,145,0)
	fill.light_color=Color("87bfc7")
	fill.light_energy=.14
	parent.add_child(fill)
	var scenery := Node3D.new()
	scenery.name="OriginalCourtyard"
	parent.add_child(scenery)
	box(scenery,Vector3(0,-2.15,0),Vector3(70,.2,70),mineral("233e44"))
	landform(scenery,rng)
	stone(scenery,Vector3(0,-.54,0),Vector3(13.85,1.02,8.65),mineral("3b4d52"),.25)
	stone(scenery,Vector3(0,-.19,0),Vector3(13.60,.28,8.45),mineral("667b7a"),.10)
	box(scenery,Vector3(0,-.09,0),Vector3(12.1,.10,7.1),mat("566963"))
	var tiles: Array[ShaderMaterial] = []
	for color in ["8c9692","87918b","959b92","838e89","90978b","8c9690"]:
		tiles.append(mineral(color))
	for row in range(7):
		for col in range(12):
			var center := Vector3(float(col)-5.5,-.062,float(row)-3.0)
			stone(scenery,center,Vector3(.983,.12,.983),tiles[rng.randi_range(0,5)],.018)
	# Continuous outer rim visually separates playable floor from the forest.
	var trim := mineral("677e78")
	for side in [-1,1]:
		for i in range(14):
			stone(scenery,Vector3(float(i)-6.5,-.03,float(side)*3.87),Vector3(.99,.23,.52),trim,.035)
		for i in range(7):
			stone(scenery,Vector3(float(side)*6.5,-.03,float(i)-3),Vector3(.52,.23,.99),trim,.035)
	# Front entrance: three shallow steps, never part of the logical movement grid.
	for i in range(3):
		stone(scenery,Vector3(-1.0,-.19-float(i)*.20,4.18+float(i)*.34),Vector3(3.2+float(i)*.20,.21,.43),mineral("83938a"),.055)
	# Edge rocks and a few lush shrubs; keep all play tiles unobstructed.
	for i in range(44):
		var angle: float = TAU*float(i)/44.0
		var x: float = cos(angle)*7.0
		var z: float = sin(angle)*4.62
		if z>3.8 and x>-3.0 and x<1.0: continue
		rock(scenery,Vector3(x,-.58,z),Vector3(rng.randf_range(.75,1.4),rng.randf_range(.75,1.35),rng.randf_range(.65,1.3)),mineral(["3c5056","4a605f","5b706c"][i%3]),rng)
	for i in range(25):
		var side: float = -1.0 if i%2==0 else 1.0
		var x: float = side*rng.randf_range(6.6,7.7)
		var z: float = rng.randf_range(-4.0,3.7)
		foliage(scenery,Vector3(x,-.02,z),Vector3(rng.randf_range(.7,1.15),.40,rng.randf_range(.65,1.1)),mat(["365448","426451","536e52"][i%3]))
	# Background gate, original vernacular architecture, not a copied game location.
	var wood := mat("594533")
	var bronze := mat("a18b57",.60)
	for side in [-1,1]:
		var x: float = side*2.65
		stone(scenery,Vector3(x,.13,-4.17),Vector3(.77,.46,.79),mat("6e7e6d"),.07)
		cylinder(scenery,Vector3(x,1.58,-4.17),.16,2.88,wood,.13,10)
		cylinder(scenery,Vector3(x,.41,-4.17),.19,.18,bronze)
		cylinder(scenery,Vector3(x,2.72,-4.17),.18,.14,bronze)
	box(scenery,Vector3(0,2.82,-4.17),Vector3(5.9,.28,.28),wood)
	box(scenery,Vector3(0,2.46,-4.17),Vector3(5.55,.12,.21),wood)
	roof(scenery,Vector3(0,2.99,-4.17),6.20,1.50,mat("344f4a"))
	stone(scenery,Vector3(0,2.62,-3.98),Vector3(1.34,.50,.12),mat("5c6852"),.04)
	var seal := cylinder(scenery,Vector3(0,2.62,-3.90),.12,.025,bronze,.12,12)
	seal.rotation_degrees.x=90
	for p in [Vector3(-6.46,.06,2.50),Vector3(6.46,.06,2.50),Vector3(-4.65,.02,-3.89),Vector3(4.65,.02,-3.89)]:
		lantern(scenery,p,true)
	# Trees form a dark frame, leaving the centre bright and low detail.
	tree(scenery,Vector3(-7.5,-.28,-2.6),3.8,false,rng)
	tree(scenery,Vector3(-7.8,-.30,1.6),3.25,false,rng)
	tree(scenery,Vector3(7.55,-.25,-2.9),3.65,true,rng)
	tree(scenery,Vector3(7.85,-.40,1.9),3.15,false,rng)
	tree(scenery,Vector3(-5.5,-.3,-5.15),3.8,false,rng)
	tree(scenery,Vector3(5.6,-.3,-5.15),3.5,false,rng)
	# Scattered fallen leaves use a single MultiMesh; intentionally avoid centre noise.
	var leaf_mesh := PrismMesh.new()
	leaf_mesh.size=Vector3(.14,.018,.065)
	var leaves := MultiMesh.new()
	leaves.transform_format=MultiMesh.TRANSFORM_3D
	leaves.use_colors=true
	leaves.mesh=leaf_mesh
	leaves.instance_count=58
	for i in range(58):
		var cluster := [Vector2(-5.45,-2.95),Vector2(4.8,-2.95),Vector2(5.35,2.9),Vector2(-4.9,3.0)][i%4] as Vector2
		var x: float = clampf(cluster.x+rng.randfn(0,.6),-5.9,5.9)
		var z: float = clampf(cluster.y+rng.randfn(0,.24),-3.4,3.4)
		var basis := Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*rng.randf_range(.7,1.2))
		leaves.set_instance_transform(i,Transform3D(basis,Vector3(x,.005,z)))
		leaves.set_instance_color(i,Color("a47943").lerp(Color("7c633d"),rng.randf()))
	var leaf_node := MultiMeshInstance3D.new()
	leaf_node.multimesh=leaves
	var leaf_material := mat("ffffff")
	leaf_material.vertex_color_use_as_albedo=true
	leaf_material.vertex_color_is_srgb=true
	leaf_node.material_override=leaf_material
	leaf_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery.add_child(leaf_node)
	var grid := Node3D.new()
	grid.name="OptionalGrid"
	parent.add_child(grid)
	var grid_material := mat("afc9b4")
	grid_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.albedo_color.a=.28
	grid_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(13):
		var line := box(grid,Vector3(float(i)-6.0,.012,0),Vector3(.012,.001,7.0),grid_material)
		line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(8):
		var line := box(grid,Vector3(0,.012,float(i)-3.5),Vector3(12.0,.001,.012),grid_material)
		line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.visible=false
	return {"grid":grid,"blocked":[]}
