extends RefCounted
## Limited adapter for the archived monk sample; no gameplay events or root motion.
const BASE := "res://art/reviews/animation-samples-20261004/guard_monk/"
var manifest: Dictionary

func _init() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))

func compatible(role: String, release: float, duration: float) -> bool:
	if role != "guard_monk" or manifest.get("schema","") != "motion-sample-v1-requires-player-adapter": return false
	if manifest.character != role or manifest.frames.size() != 13: return false
	return is_equal_approx(float(manifest.actions.basic_attack.events[0].at),release) and is_equal_approx(float(manifest.actions.basic_attack.duration_seconds),duration)

func frame_at(pose: String, time: float, walk_time: float) -> int:
	var action: Dictionary = manifest.actions[pose]
	if action.has("track"):
		var result := int(action.track[0].frame)
		for key in action.track:
			if time+0.00000001 >= float(key.at): result = int(key.frame)
		return result
	var durations: Array = action.body_frame_seconds
	var total := 0.0
	for seconds in durations: total += float(seconds)
	var clock := walk_time if pose == "move" else time
	if action.get("loop",false): clock = fposmod(clock,total)
	for i in range(durations.size()):
		if clock+0.00000001 < float(durations[i]): return int(action.body_frames[i])
		clock -= float(durations[i])
	return int(action.body_frames[-1])

func contact_offset() -> Vector2:
	var point: Array = manifest.contact_socket_candidate.point
	var anchor: Array = manifest.frame.foot_anchor
	return Vector2(point[0]-anchor[0],point[1]-anchor[1])
