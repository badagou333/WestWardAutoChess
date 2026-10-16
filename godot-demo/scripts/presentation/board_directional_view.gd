extends "res://scripts/presentation/board_trial_monk_view.gd"
## Optional board-only artwork adapter. The inherited pose/event clock is authoritative.
## Manifest coordinates (foot, feet, emission_socket) are relative to each region.
const BASE := "res://art/production/directional_v1/"
const SCHEMA := "board-directional-v1"
static var pack_cache := {}
var direction_pack := {}
var direction_body: Texture2D
var direction_scale := 1.0
var direction_back := false
var direction_sign := 1.0
var direction_actor := {}

static func _point_valid(value) -> bool:
	return value is Array and value.size()==2 and value.all(func(n): return (n is float or n is int) and is_finite(float(n)))

static func _positive(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>0

static func load_pack(key: String) -> Dictionary:
	if pack_cache.has(key): return pack_cache[key]
	var path := BASE+key+"/manifest.json"
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema","")!=SCHEMA or parsed.get("character","")!=key:
		push_warning("Directional artwork rejected: invalid manifest for "+key)
		return {}
	var frames = parsed.get("frames")
	var factor = parsed.get("scale")
	if not frames is Array or frames.size()!=16 or not _positive(factor):
		push_warning("Directional artwork rejected: incomplete frames/scale for "+key)
		return {}
	var atlas_scales=parsed.get("atlas_scales",{})
	if not atlas_scales is Dictionary: return {}
	var textures: Array[Texture2D]=[]
	var source_factors: Array[float]=[]
	var polygons: Array[PackedVector2Array]=[]
	var uvs: Array[PackedVector2Array]=[]
	var images: Dictionary={}
	var scales: Dictionary={}
	var bounds: Array[Rect2]=[]
	for frame in frames:
		if not frame is Dictionary: return {}
		var atlas_name: String=str(frame.get("atlas",parsed.get("atlas","atlas.png")))
		if atlas_name!=atlas_name.get_file(): return {} # Stay inside this character's package.
		var factor_override=frame.get("source_scale",atlas_scales.get(atlas_name,1.0))
		if not _positive(factor_override): return {}
		if atlas_scales.has(atlas_name) and (not _positive(atlas_scales[atlas_name]) or not is_equal_approx(float(factor_override),float(atlas_scales[atlas_name]))): return {}
		# A replacement sheet can have another source resolution. Its scale must
		# be sheet-wide, never adjusted pose by pose to disguise size drift.
		if scales.has(atlas_name) and not is_equal_approx(float(factor_override),float(scales[atlas_name])): return {}
		scales[atlas_name]=float(factor_override)
		var image_path := BASE+key+"/"+atlas_name
		# Exported textures may exist only through Godot's import remap, not as
		# their raw PNG source. Both source projects and actual PCKs must work.
		if not ResourceLoader.exists(image_path) and not FileAccess.file_exists(image_path): return {}
		var texture: Texture2D=_texture(image_path)
		if texture==null: return {}
		if not images.has(atlas_name): images[atlas_name]=texture.get_image()
		var image: Image=images[atlas_name]
		var image_rect := Rect2i(Vector2i.ZERO,image.get_size())
		var region=frame.get("region")
		if not region is Array or region.size()!=4 or not region.all(func(n): return (n is float or n is int) and is_finite(float(n)) and float(n)==floorf(float(n))): return {}
		var rect:=Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3]))
		if rect.size.x<=0 or rect.size.y<=0 or not image_rect.encloses(rect): return {}
		if not _point_valid(frame.get("foot")) or not _point_valid(frame.get("emission_socket")): return {}
		if not frame.get("feet") is Array or not frame.feet.all(func(point): return _point_valid(point)): return {}
		var alpha_rect:=image.get_region(rect).get_used_rect()
		if not alpha_rect.has_area(): return {}
		var clipped_bounds:=Rect2(alpha_rect)
		var polygon:=PackedVector2Array()
		var texture_uvs:=PackedVector2Array()
		if frame.has("clip_polygon"):
			var raw_polygon=frame.clip_polygon
			if not raw_polygon is Array or raw_polygon.size()<3 or not raw_polygon.all(func(point): return _point_valid(point)): return {}
			for point in raw_polygon:
				var vertex:=Vector2(point[0],point[1])
				if vertex.x<0 or vertex.y<0 or vertex.x>rect.size.x or vertex.y>rect.size.y: return {}
				polygon.append(vertex)
				texture_uvs.append((Vector2(rect.position)+vertex)/Vector2(image.get_size()))
			if Geometry2D.triangulate_polygon(polygon).size()!=(polygon.size()-2)*3: return {}
			var polygon_bounds:=Rect2(polygon[0],Vector2.ZERO)
			for vertex in polygon: polygon_bounds=polygon_bounds.expand(vertex)
			clipped_bounds=clipped_bounds.intersection(polygon_bounds)
			if not clipped_bounds.has_area(): return {}
		bounds.append(clipped_bounds)
		textures.append(texture)
		source_factors.append(float(factor_override))
		polygons.append(polygon)
		uvs.append(texture_uvs)
	var result: Dictionary=parsed.duplicate(true)
	result["texture"]=textures[0]
	result["textures"]=textures
	result["source_factors"]=source_factors
	result["polygons"]=polygons
	result["uvs"]=uvs
	result["bounds"]=bounds
	# A stable full-health bar clearance from both standing banks, not a bar that
	# jumps on every footstep or follows the weapon's striking tip.
	var hud_top:=0.0
	for index in [0,8]:
		hud_top=minf(hud_top,(bounds[index].position.y-float(frames[index].foot[1]))*float(factor)*source_factors[index]-13.0)
	result["hud_top"]=hud_top
	pack_cache[key]=result
	return result

func copy_playback(source, actor: Dictionary, pack: Dictionary) -> void:
	# Copy all inherited script properties, including special Monk sample clocks,
	# rather than re-running setup/reset or consuming an animation boundary.
	var available: Dictionary={}
	for property in get_property_list(): available[property.name]=true
	for property in source.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0 or not available.has(property.name): continue
		set(property.name,source.get(property.name))
	position=source.position
	z_index=source.z_index
	z_as_relative=source.z_as_relative
	direction_actor=actor
	direction_pack=pack
	direction_body=pack.texture
	direction_scale=float(pack.scale)
	direction_sign=facing
	direction_back=false
	show_shadow=false
	queue_redraw()

func keep_board_direction() -> void:
	pass # Explicit hook: repeated idle defaults must not turn a stopped walker around.

func face(point: Vector2) -> void:
	if dead: return
	super.face(point)
	var delta:=point-position
	if absf(delta.x)>1.0: direction_sign=signf(delta.x)
	# Horizontal paths retain the previous depth-facing bank. A dead-zone avoids
	# front/back chatter when nearly horizontal targets interpolate between cells.
	if absf(delta.y)>maxf(1.0,absf(delta.x)*0.035): direction_back=delta.y<0
	queue_redraw()

func direction_frame() -> int:
	var frame:=0
	if pose=="retreat":
		frame=6 if pose_time<float(manifest.actions.retreat.hold_seconds)*0.46 else 7
	elif pose=="hit":
		frame=5
	elif pose=="basic_attack":
		frame=3 if pose_time+0.00000001<impact_delay() else 4
		if pose_time>=Motion.duration(motion)-float(motion.recover)*0.30: frame=0
	elif not direction_actor.is_empty() and not direction_actor.get("move",{}).is_empty():
		var move: Dictionary=direction_actor.move
		var phase:=clampf(float(move.time)/float(move.duration),0,0.999999)
		# Two opposing support poses per real board segment. No early idle when
		# a legacy role's motion.walk differs from the board's 0.50 second rule.
		frame=1 if phase<0.5 else 2
	return frame+(8 if direction_back else 0)

func ground_offset() -> Vector2:
	# New poses already contain the drawn lunge. Do not add the old whole-body
	# reach/stretch a second time, or move a planted foot out of its logical cell.
	return Vector2.ZERO

func visual_transform() -> Transform2D:
	var factor: float=direction_scale*float(direction_pack.source_factors[direction_frame()])
	return Transform2D(0,Vector2(direction_sign*factor,factor),0,foot_anchor)

func draw_sample() -> Dictionary:
	var index:=direction_frame()
	var frame: Dictionary=direction_pack.frames[index]
	var rect: Array=frame.region
	var foot:=Vector2(frame.foot[0],frame.foot[1])
	var transform:=visual_transform()
	var bounds: Rect2=direction_pack.bounds[index]
	bounds.position-=foot
	var contacts: Array[Vector2]=[]
	for point in frame.feet: contacts.append(transform*(Vector2(point[0],point[1])-foot))
	var polygon: PackedVector2Array=direction_pack.polygons[index].duplicate()
	for i in polygon.size(): polygon[i]-=foot
	return {"texture":direction_pack.textures[index],"region":Rect2(rect[0],rect[1],rect[2],rect[3]),
		"destination":Rect2(-foot,Vector2(rect[2],rect[3])),"transform":transform,
		"polygon":polygon,"uvs":direction_pack.uvs[index],
		"bounds":transform*bounds,"hud_top":direction_pack.hud_top,"alpha":visual_alpha,"frame":index,"feet":contacts,
		"emission":transform*(Vector2(frame.emission_socket[0],frame.emission_socket[1])-foot)}

func emission_position() -> Vector2:
	return position+Vector2(draw_sample().emission)

func _draw() -> void:
	if direction_body==null: return
	var sample:=draw_sample()
	var flash:=maxf(0,(hit_pulse-0.09)/0.05)*0.30
	var tint:=Color(1+flash,1+flash*0.8,1+flash*0.5,visual_alpha)
	draw_set_transform_matrix(sample.transform)
	if not sample.polygon.is_empty():
		draw_colored_polygon(sample.polygon,tint,sample.uvs,sample.texture)
	else:
		draw_texture_rect_region(sample.texture,sample.destination,sample.region,tint)
	draw_set_transform(Vector2.ZERO)
