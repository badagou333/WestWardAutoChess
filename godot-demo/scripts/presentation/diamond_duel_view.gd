extends "res://scripts/presentation/board_trial_monk_view.gd"
## Independent, isolated PNG adapter. Inherited gameplay pose/impact clocks stay
## authoritative; drawings never emit damage and unknown feet remain unknown.
const ART := "res://art/runtime/diamond_duel_v1/"
const REJECTED := ["monk_ne_move_b","wolf_se_move_b","wolf_ne_move_b"]
static var frame_bank := {}
static var frame_textures := {}
static var frame_bounds := {}
var direction_actor := {}
var direction_sign := 1.0
var direction_back := false
var frame_id := ""
var actor_art := ""
var artwork_ready := false

func attach(source, actor: Dictionary) -> bool:
	if frame_bank.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
		if not parsed is Dictionary or parsed.get("schema","")!="diamond-duel-runtime-v1": return false
		if parsed.get("frames",[]).size()!=17: return false
		var bank := {}
		var textures := {}
		var bounds := {}
		for frame in parsed.frames:
			if frame.id in REJECTED or not is_equal_approx(float(frame.uniform_scale_to_design),.34): return false
			var path: String=ART+str(frame.image)
			if not ResourceLoader.exists(path): return false
			var texture: Texture2D=load(path)
			if texture==null: return false
			bank[frame.id]=frame
			textures[frame.id]=texture
			bounds[frame.id]=Rect2(texture.get_image().get_used_rect())
		frame_bank=bank
		frame_textures=textures
		frame_bounds=bounds
	var available := {}
	for property in get_property_list(): available[property.name]=true
	for property in source.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)!=0 and available.has(property.name):
			set(property.name,source.get(property.name))
	direction_actor=actor
	actor_art="monk" if actor.key=="guard_monk" else "wolf"
	direction_sign=facing
	foot_anchor=Vector2.ZERO
	position=Vector2.ZERO
	show_anchor=false
	show_status=false
	show_shadow=false
	motion_sample_enabled=false
	use_motion_frames=false
	artwork_ready=true
	current_frame()
	return true

func set_motion_sample(_enabled: bool) -> bool:
	return false # This dedicated adapter has no old-atlas fallback or skin switch.

func face(point: Vector2) -> void:
	if dead: return
	super.face(point)
	var delta:=point-position
	if absf(delta.x)>.001: direction_sign=signf(delta.x)
	if absf(delta.y)>.001: direction_back=delta.y<0
	if artwork_ready: current_frame()
	queue_redraw()

func update_frame() -> void:
	super.update_frame()
	if artwork_ready: current_frame()

func current_frame() -> Dictionary:
	if not artwork_ready: return {}
	var action:="idle"
	if pose=="basic_attack":
		action="attack_prepare" if pose_time+.00000001<impact_delay() else "attack_contact"
		if pose_time>=Motion.duration(motion)-float(motion.recover)*.30: action="idle"
	elif pose not in ["retreat","hit"] and not direction_actor.get("move",{}).is_empty():
		var move: Dictionary=direction_actor.move
		action="move_a"
		# Only this source pair depicts distinct leg phases. Others deliberately
		# retain a finite travel pose, not an invented alternating gait.
		if actor_art=="monk" and not direction_back and float(move.time)/float(move.duration)>=.5: action="move_b"
	frame_id=actor_art+("_ne_" if direction_back else "_se_")+action
	return frame_bank[frame_id]

func visual_transform() -> Transform2D:
	return Transform2D(0,Vector2(direction_sign*.34,.34),0,Vector2.ZERO)

func ground_offset() -> Vector2:
	return Vector2.ZERO # No legacy whole-body hop, lunge or second scale.

func mirrored_design(value):
	if value==null: return null
	var result: Array=[]
	for point in value: result.append([float(point[0])*direction_sign,float(point[1])])
	return result

func draw_sample() -> Dictionary:
	var frame:=current_frame()
	if frame.is_empty(): return {}
	var anchor:=Vector2(frame.anchor_crop[0],frame.anchor_crop[1])
	var texture: Texture2D=frame_textures[frame_id]
	var transform:=visual_transform()
	var bounds: Rect2=frame_bounds[frame_id]
	bounds.position-=anchor
	var feet: Array=[]
	for foot in frame.feet:
		var copy: Dictionary=foot.duplicate(true)
		for key in ["visible_envelope_design","contact_proxy_design","ground_projection_design"]:
			copy[key]=mirrored_design(foot.get(key))
		feet.append(copy)
	var contact: Vector2=Vector2(0,-45)
	if frame.attack_contact_design!=null: contact=Vector2(frame.attack_contact_design[0]*direction_sign,frame.attack_contact_design[1])
	return {"frame_id":frame_id,"texture":texture,"destination":Rect2(-anchor,texture.get_size()),
		"transform":transform,"bounds":transform*bounds,"hud_top":(transform*bounds).position.y-13,
		"feet":feet,"support_complete":frame.support_complete,
		"support_footprint_design":mirrored_design(frame.support_footprint_design),
		"known_contact_proxy_hull_design":mirrored_design(frame.known_contact_proxy_hull_design),
		"issues":frame.issues,"emission":contact,"alpha":visual_alpha}

func emission_position() -> Vector2:
	return position+Vector2(draw_sample().get("emission",Vector2(0,-45)))

func _draw() -> void:
	if not artwork_ready: return
	var sample:=draw_sample()
	var flash:=maxf(0,(hit_pulse-.09)/.05)*.3
	draw_set_transform_matrix(sample.transform)
	draw_texture_rect(sample.texture,sample.destination,false,Color(1+flash,1+flash*.8,1+flash*.5,visual_alpha))
	draw_set_transform(Vector2.ZERO)
