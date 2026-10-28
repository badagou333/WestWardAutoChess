extends "res://scripts/presentation/board_directional_view.gd"
## Trial-only adapter. The inherited combat clock and 16-pose bank stay authoritative.
## A valid external track may replace only the original front/right attack drawing.
const TRIAL_SCHEMA := "board-bear-forehand-trial-v1"
var trial_track: Dictionary = {}

static func _inside(point: Array, size: Vector2i) -> bool:
	return _point_valid(point) and float(point[0]) >= 0.0 and float(point[1]) >= 0.0 and float(point[0]) <= size.x and float(point[1]) <= size.y

static func load_trial(path: String) -> Dictionary:
	# Candidate folders have .gdignore; only explicitly copied runtime resources
	# are loadable in an exported trial. Missing/bad files never enable the track.
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema","") != TRIAL_SCHEMA: return {}
	if not parsed.get("frames") is Array: return {}
	var candidate: Dictionary = parsed.duplicate(true)
	var base := path.get_base_dir()
	for frame in candidate.frames:
		if not frame is Dictionary: return {}
		var name := str(frame.get("file",""))
		if name.is_empty() or name != name.get_file() or not name.ends_with(".png"): return {}
		var image_path := base.path_join(name)
		if not ResourceLoader.exists(image_path) and not FileAccess.file_exists(image_path): return {}
		var texture: Texture2D = _texture(image_path)
		if texture == null: return {}
		frame["texture"] = texture
	return candidate

func configure_trial(candidate: Dictionary) -> bool:
	trial_track = {}
	if candidate.get("schema","") != TRIAL_SCHEMA: return false
	if candidate.get("source_sign",0) != 1 or candidate.get("source_back",true) != false: return false
	if not _positive(candidate.get("scale")): return false
	var frames = candidate.get("frames")
	var feet = candidate.get("feet")
	if not frames is Array or frames.size() < 2 or not feet is Array or feet.is_empty(): return false
	var raw_index = candidate.get("impact_index")
	if not (raw_index is int or raw_index is float) or not is_finite(float(raw_index)) or float(raw_index) != floorf(float(raw_index)): return false
	var impact_index := int(raw_index)
	if impact_index < 0 or impact_index >= frames.size(): return false
	var expected_size := Vector2i.ZERO
	var previous := -1.0
	var checked: Array = []
	for i in frames.size():
		var frame = frames[i]
		if not frame is Dictionary or not frame.get("texture") is Texture2D: return false
		var at = frame.get("at")
		if not (at is int or at is float) or not is_finite(float(at)) or float(at) < 0.0 or float(at) <= previous or float(at) >= Motion.duration(motion): return false
		if i == 0 and not is_zero_approx(float(at)): return false
		previous = float(at)
		var texture: Texture2D = frame.texture
		var image := texture.get_image()
		if image == null or image.is_empty(): return false
		var size: Vector2i = image.get_size()
		if i == 0: expected_size = size
		elif size != expected_size: return false
		var bounds := image.get_used_rect()
		if not bounds.has_area(): return false
		# A white/opaque video frame is not a transparent runtime asset.
		for corner in [Vector2i.ZERO,Vector2i(size.x-1,0),Vector2i(0,size.y-1),size-Vector2i.ONE]:
			if image.get_pixelv(corner).a > 0.05: return false
		checked.append({"at":float(at),"texture":texture,"bounds":Rect2(bounds)})
	if not is_equal_approx(float(frames[impact_index].at),impact_delay()): return false
	if not candidate.get("foot") is Array or not _inside(candidate.foot,expected_size): return false
	if not candidate.get("emission") is Array or not _inside(candidate.emission,expected_size): return false
	for foot in feet:
		if not foot is Array or not _inside(foot,expected_size): return false
	trial_track = {"frames":checked,"size":expected_size,"foot":candidate.foot.duplicate(),"feet":feet.duplicate(true),
		"emission":candidate.emission.duplicate(),"scale":float(candidate.scale),"impact_index":impact_index}
	queue_redraw()
	return true

func trial_active() -> bool:
	return not trial_track.is_empty() and pose == "basic_attack" and not direction_back and direction_sign == 1.0

func trial_frame() -> int:
	if not trial_active(): return -1
	var result := 0
	for i in trial_track.frames.size():
		if pose_time + 0.00000001 < float(trial_track.frames[i].at): break
		result = i
	return result

func draw_sample() -> Dictionary:
	if not trial_active(): return super.draw_sample()
	var index := trial_frame()
	var frame: Dictionary = trial_track.frames[index]
	var size: Vector2i = trial_track.size
	var foot := Vector2(trial_track.foot[0],trial_track.foot[1])
	var factor: float = trial_track.scale
	var transform := Transform2D(0,Vector2(factor,factor),0,foot_anchor)
	var bounds: Rect2 = frame.bounds
	bounds.position -= foot
	var contacts: Array[Vector2] = []
	for point in trial_track.feet: contacts.append(transform*(Vector2(point[0],point[1])-foot))
	return {"texture":frame.texture,"region":Rect2(Vector2.ZERO,Vector2(size)),
		"destination":Rect2(-foot,Vector2(size)),"transform":transform,
		"polygon":PackedVector2Array(),"uvs":PackedVector2Array(),"bounds":transform*bounds,
		"hud_top":direction_pack.hud_top,"alpha":visual_alpha,"frame":direction_frame(),"trial_frame":index,
		"feet":contacts,"emission":transform*(Vector2(trial_track.emission[0],trial_track.emission[1])-foot)}
