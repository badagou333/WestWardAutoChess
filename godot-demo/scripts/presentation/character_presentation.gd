extends Node2D


const FOOT := Vector2(0, 35)
const Motion = preload("res://scripts/presentation/motion.gd")
var motion: Dictionary
var animation_clock := 0.0
var attack_serial := 0
var attack_direction := Vector2.RIGHT
var hit_pulse := 0.0
var hit_cooldown := 0.0
var impact_stop := 0.0
var landing := 0.0
var role := ""
var manifest: Dictionary
var body: Texture2D
var motion_body: Texture2D
var motion_manifest := {}
var motion_revision := 3
var ground_drawn_walk := true
var use_motion_frames := true
var motion_frame := -1
var vfx: Texture2D
var effects := {}
var pose := "idle"
var pose_time := 0.0
var frame_index := 0
var facing := 1.0
var visual_alpha := 1.0
var dead := false
var move_start := Vector2.ZERO
var move_end := Vector2.ZERO
var move_left := 0.0
var show_anchor := true
var show_status := true
var show_name := false
var effects_on := true
var events := {"idle": 1, "move": 0, "basic_attack": 0, "hit": 0, "retreat": 0}

func setup_visual(key: String) -> void:
	role = key
	motion = Motion.PROFILES[key]
	var base := "res://art/production/%s/demo_v1/" % role
	manifest = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
	if manifest.has("atlas"):
		manifest["atlases"] = {"body": manifest.atlas.file}
		manifest["standalone_vfx"] = {}
		for action in manifest.actions.values():
			action["body_frames"] = action.frames
			if action.has("frame_seconds"):
				action["body_frame_seconds"] = action.frame_seconds
	body = ImageTexture.create_from_image(Image.load_from_file(base + manifest.atlases.body))
	var motion_base := "res://art/production/%s/motion_v1/" % role
	for revision in range(motion_revision, 1, -1):
		var revised_base := "res://art/production/%s/motion_v%d/" % [role, revision]
		if FileAccess.file_exists(revised_base + "manifest.json"):
			motion_base = revised_base
			break
	if FileAccess.file_exists(motion_base + "manifest.json"):
		motion_manifest = JSON.parse_string(FileAccess.get_file_as_string(motion_base + "manifest.json"))
		motion_body = ImageTexture.create_from_image(Image.load_from_file(motion_base + motion_manifest.atlas))
	if manifest.atlases.has("vfx"):
		vfx = ImageTexture.create_from_image(Image.load_from_file(base + manifest.atlases.vfx))
	for key_name in manifest.standalone_vfx:
		effects[key_name] = ImageTexture.create_from_image(Image.load_from_file(base + manifest.standalone_vfx[key_name].file))
	queue_redraw()

func set_pose(value: String) -> void:
	if dead and value != "retreat":
		return
	pose = value
	pose_time = 0.0
	events[value] += 1
	update_frame()

func play_attack() -> void:
	attack_serial += 1
	set_pose("basic_attack")

func play_hit() -> void:
	if dead: return
	hit_pulse = 0.14
	if pose not in ["basic_attack", "move", "hit"] and hit_cooldown <= 0:
		set_pose("hit")
		hit_cooldown = 0.30

func play_retreat() -> void:
	dead = true
	move_left = 0.0
	set_pose("retreat")

func reset_visual() -> void:
	dead = false
	move_left = 0.0
	impact_stop = 0.0
	hit_pulse = 0.0
	hit_cooldown = 0.0
	visual_alpha = 1.0
	position = Vector2.ZERO
	set_pose("idle")

func move_to(point: Vector2) -> void:
	move_start = position; move_end = point; move_left = motion.walk
	if absf(point.x - position.x) > 1:
		facing = signf(point.x - position.x)
	set_pose("move")

func face(point: Vector2) -> void:
	attack_direction = (point - position).normalized()
	if absf(point.x - position.x) > 1:
		facing = signf(point.x - position.x)

func impact_delay() -> float:
	return Motion.release(motion)

func emission_position() -> Vector2:
	if motion_frame >= 0 and (motion_manifest.has("emission_sockets") or motion_manifest.has("hand_sockets")):
		return position + visual_transform() * motion_effect_socket()
	var action: Dictionary = manifest.actions.basic_attack
	if not action.has("spawn_vfx"):
		return position + FOOT + Vector2(36 * facing, -70)
	var center: Array = manifest.standalone_vfx[action.spawn_vfx].aligned_center_trial
	return position + visual_transform() * Vector2(float(center[0]) - 128, float(center[1]) - 218)

func motion_effect_socket() -> Vector2:
	var sockets: Array = motion_manifest.get("emission_sockets", motion_manifest.get("hand_sockets", []))
	var point: Array = sockets[motion_frame]
	var offset: Array = motion_manifest.get("socket_offset", [0, -8])
	return Vector2(float(point[0]) - 128 + float(offset[0]), float(point[1]) - 218 + float(offset[1]))

func tick(delta: float) -> void:
	hit_pulse = maxf(0, hit_pulse - delta)
	hit_cooldown = maxf(0, hit_cooldown - delta)
	if impact_stop > 0:
		var frozen := minf(delta, impact_stop)
		impact_stop -= frozen
		delta -= frozen
	animation_clock += delta
	landing = maxf(0, landing - delta)
	pose_time += delta
	if move_left > 0:
		move_left = maxf(0, move_left - delta)
		position = move_start.lerp(move_end, smoothstep(0, 1, 1 - move_left / float(motion.walk)))
		if move_left == 0:
			landing = 0.12
	update_frame()
	z_index = int(round(position.y + FOOT.y))
	queue_redraw()

func update_frame() -> void:
	motion_frame = -1
	var action: Dictionary = manifest.actions[pose]
	frame_index = int(action.body_frames[0])
	visual_alpha = 1.0
	if pose == "idle" and use_motion_frames and motion_manifest.has("idle"):
		motion_frame = int(motion_manifest.idle)
	if pose == "basic_attack":
		var end := Motion.duration(motion)
		if pose_time < float(motion.windup) * 0.30:
			frame_index = int(manifest.actions.idle.body_frames[0])
		elif pose_time >= float(motion.windup):
			frame_index = int(action.body_frames[-1])
		if pose_time >= end - float(motion.recover) * 0.30:
			frame_index = int(manifest.actions.idle.body_frames[0])
		if use_motion_frames and motion_body != null:
			var attack: Dictionary = motion_manifest.attack
			if pose_time >= float(motion.windup) * 0.20:
				motion_frame = int(attack.windup)
			if pose_time >= float(motion.windup) * 0.78:
				motion_frame = int(attack.accelerate)
			# The strongest silhouette and the hit use exactly the same clock.
			if pose_time >= impact_delay():
				motion_frame = int(attack.impact)
			if pose_time >= float(motion.windup) + float(motion.strike) + float(motion.recover) * 0.20:
				motion_frame = int(attack.recover)
			if motion_manifest.has("attack_track"):
				for key in motion_manifest.attack_track:
					var at := float(motion.windup) * float(key.fraction)
					if key.phase == "release": at = impact_delay()
					elif key.phase == "recover": at = float(motion.windup) + float(motion.strike) + float(motion.recover) * float(key.fraction)
					if pose_time >= at: motion_frame = int(key.frame)
		if pose_time >= end:
			set_pose("move" if move_left > 0 else "idle")
	elif pose == "hit" and pose_time >= float(action.hold_seconds):
		set_pose("move" if move_left > 0 else "idle")
	elif pose == "move":
		if use_motion_frames and motion_body != null and not motion_manifest.move.is_empty():
			var progress := clampf(1 - move_left / float(motion.walk), 0, 0.9999)
			motion_frame = int(motion_manifest.move[int(progress * motion_manifest.move.size())])
		if move_left <= 0:
			set_pose("idle")
	elif pose == "retreat":
		visual_alpha = clampf(1 - (pose_time - float(action.hold_seconds)) / float(action.fade_seconds), 0, 1)

func visual_transform() -> Transform2D:
	var offset := Vector2.ZERO
	var stretch := Vector2.ONE
	var angle := 0.0
	if pose == "idle":
		# Separate phases prevent an entire line of characters breathing in unison.
		var breath := sin(animation_clock * 2.6 + float(role.hash() % 37))
		stretch = Vector2(1 - breath * 0.003, 1 + breath * 0.009)
	elif pose == "move":
		var progress := clampf(1 - move_left / float(motion.walk), 0, 1)
		var step_lift := absf(sin(progress * TAU))
		# Drawn legs already lift: only a small remaining body weight shift is needed.
		var amount := 0.35 if motion_frame >= 0 else 1.0
		if ground_drawn_walk and motion_manifest.has("walk_source_feet"):
			amount = 0.0
		offset.y = -step_lift * float(motion.lift) * amount
		angle = 0.025 * facing * sin(progress * TAU) * amount
		stretch = Vector2(1 + step_lift * 0.012 * amount, 1 - step_lift * 0.016 * amount)
	elif pose == "basic_attack":
		var weight := Motion.attack_weight(pose_time, motion)
		offset = attack_direction * float(motion.reach) * weight
		angle = float(motion.lean) * facing * weight
		if pose_time < float(motion.windup):
			var anticipate := smoothstep(0, motion.windup, pose_time)
			stretch = Vector2(1 + anticipate * 0.018, 1 - anticipate * 0.025)
		if motion_frame >= 0 and motion_manifest.has("recovery_unfold"):
			var recovery_start := float(motion.windup) + float(motion.strike)
			if pose_time >= recovery_start:
				var unfold: Dictionary = motion_manifest.recovery_unfold
				stretch.y *= lerpf(unfold.start_scale_y, 1.0, smoothstep(recovery_start, recovery_start + float(motion.recover) * float(unfold.end_fraction), pose_time))
	elif pose == "hit":
		var recoil := sin(clampf(pose_time / 0.18, 0, 1) * PI)
		offset.x = -facing * recoil * 6
		angle = -facing * recoil * 0.035
	elif pose == "retreat":
		stretch.y = lerpf(1.02, 1, smoothstep(0, 0.20, pose_time))
	if landing > 0:
		stretch *= Vector2(1 + landing * 0.18, 1 - landing * 0.18)
	if hit_pulse > 0 and pose != "retreat":
		offset.x -= facing * sin(hit_pulse / 0.14 * PI) * 2
	var result := Transform2D(angle, stretch * Vector2(facing, 1), 0, FOOT + offset)
	# Drawn planted paws define the ground, not an extra whole-body hop.
	# This fixes vertical contact only; horizontal stride still depends on the artwork.
	if ground_drawn_walk and pose == "move" and motion_frame >= 0:
		var feet := walk_feet()
		if not feet.is_empty():
			var lowest := -INF
			for point in feet:
				lowest = maxf(lowest, (result * point).y)
			result.origin.y += FOOT.y - lowest
	return result

func walk_feet() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if motion_frame < 0 or not motion_manifest.has("walk_source_feet"):
		return points
	var frame: Dictionary = motion_manifest.frames[motion_frame]
	for point in frame.get("feet", []):
		points.append(Vector2(point[0] - 128, point[1] - 218))
	return points

func ground_offset() -> Vector2:
	# A melee step carries the contact shadow; hop height must not move the shadow.
	if pose == "basic_attack":
		return attack_direction * float(motion.reach) * Motion.attack_weight(pose_time, motion)
	return Vector2.ZERO

func _draw() -> void:
	if body == null:
		return
	var flash := maxf(0, (hit_pulse - 0.09) / 0.05) * 0.30
	var tint := Color(1 + flash, 1 + flash * 0.8, 1 + flash * 0.5, visual_alpha)
	var airborne := maxf(0, FOOT.y + ground_offset().y - visual_transform().origin.y)
	var shadow_scale := 1 - airborne * 0.015
	draw_set_transform(FOOT + ground_offset(), 0, Vector2(shadow_scale, 0.28 * shadow_scale))
	draw_circle(Vector2.ZERO, 25, Color(0.07, 0.06, 0.04, visual_alpha * 0.2))
	draw_set_transform_matrix(visual_transform())
	var source := Rect2(frame_index * 256, 0, 256, 256)
	if motion_frame >= 0:
		draw_texture_rect_region(motion_body, Rect2(-128, -218, 256, 256), Rect2(motion_frame * 256, 0, 256, 256), tint)
	else:
		draw_texture_rect_region(body, Rect2(-128, -218, 256, 256), source, tint)
	var separate_projectile: bool = pose == "basic_attack" and manifest.actions.basic_attack.has("spawn_vfx")
	if effects_on and vfx != null and not separate_projectile and motion_frame < 0:
		draw_texture_rect_region(vfx, Rect2(-128, -218, 256, 256), source, tint)
	if effects_on and motion_frame >= 0 and motion_manifest.has("hand_sockets"):
		var effect: Dictionary = motion_manifest.get("charge_effect", {"key":"idle_flame", "size":[24,30], "idle":true})
		var charge := 0.45 if pose == "idle" else clampf(pose_time / impact_delay(), 0.35, 1.0)
		if (pose == "idle" and effect.idle) or (pose == "basic_attack" and pose_time < impact_delay()):
			var size := Vector2(effect.size[0], effect.size[1]) * lerpf(0.55, 1.0, charge)
			draw_texture_rect(effects[effect.key], Rect2(motion_effect_socket() - size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)
	if show_anchor and visual_alpha > 0:
		draw_line(FOOT - Vector2(5, 0), FOOT + Vector2(5, 0), Color("33b7c8"))
		draw_line(FOOT - Vector2(0, 5), FOOT + Vector2(0, 5), Color("33b7c8"))
