extends Node2D

signal defeated(actor)

const FOOT := Vector2(0, 35)
var role := ""
var display_name := ""
var manifest: Dictionary
var body: Texture2D
var vfx: Texture2D
var effects := {}
var pose := "idle"
var pose_time := 0.0
var frame_index := 0
var facing := 1.0
var visual_alpha := 1.0
var board_row := -1
var board_col := -1
var battle_cell := Vector2i(-1, -1)
var home_cell := Vector2i(-1, -1)
var health := 100.0
var max_health := 100.0
var damage := 20.0
var attack_range_cells := 1
var attack_interval := 1.1
var move_interval := 0.6
var cooldown := 0.0
var attack_cooldown := 0.0
var move_cooldown := 0.0
var active_in_battle := true
var battle_dead := false
var dead := false
var enemy_side := false
var move_start := Vector2.ZERO
var move_end := Vector2.ZERO
var move_left := 0.0
var show_anchor := true
var effects_on := true
var events := {"idle": 1, "move": 0, "basic_attack": 0, "hit": 0, "retreat": 0}

func setup_role(key: String, title: String, stats: Array, enemy := false) -> void:
	role = key
	display_name = title
	enemy_side = enemy
	max_health = float(stats[0]); health = max_health
	damage = float(stats[1]); attack_range_cells = int(stats[2])
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
	set_pose("basic_attack")

func take_damage(amount: float) -> bool:
	if dead:
		return true
	health = maxf(0.0, health - amount)
	if health <= 0:
		dead = true; battle_dead = true; active_in_battle = false
		move_left = 0.0
		set_pose("retreat")
		defeated.emit(self)
	else:
		set_pose("hit")
	return dead

func heal(amount: float) -> void:
	if not dead:
		health = minf(max_health, health + amount)

func move_to(point: Vector2) -> void:
	move_start = position; move_end = point; move_left = 0.30
	if absf(point.x - position.x) > 1:
		facing = signf(point.x - position.x)
	set_pose("move")

func face(point: Vector2) -> void:
	if absf(point.x - position.x) > 1:
		facing = signf(point.x - position.x)

func impact_delay() -> float:
	var action: Dictionary = manifest.actions.basic_attack
	return float(action.get("body_frame_seconds", [0.12])[0]) if action.body_frames.size() > 1 else 0.08

func emission_position() -> Vector2:
	var action: Dictionary = manifest.actions.basic_attack
	if not action.has("spawn_vfx"):
		return position + FOOT + Vector2(36 * facing, -70)
	var center: Array = manifest.standalone_vfx[action.spawn_vfx].aligned_center_trial
	return position + FOOT + Vector2((float(center[0]) - 128) * facing, float(center[1]) - 218)

func tick(delta: float) -> void:
	pose_time += delta
	if move_left > 0:
		move_left = maxf(0, move_left - delta)
		position = move_start.lerp(move_end, smoothstep(0, 1, 1 - move_left / 0.30))
	update_frame()
	z_index = int(round(position.y + FOOT.y))
	queue_redraw()

func update_frame() -> void:
	var action: Dictionary = manifest.actions[pose]
	frame_index = int(action.body_frames[0])
	visual_alpha = 1.0
	if pose == "basic_attack":
		var durations: Array = action.get("body_frame_seconds", [0.24])
		var end := 0.0
		for i in range(durations.size()):
			end += float(durations[i])
			if pose_time < end:
				frame_index = int(action.body_frames[i])
				break
		if pose_time >= end:
			set_pose("move" if move_left > 0 else "idle")
	elif pose == "hit" and pose_time >= float(action.hold_seconds):
		set_pose("move" if move_left > 0 else "idle")
	elif pose == "move" and move_left <= 0:
		set_pose("idle")
	elif pose == "retreat":
		visual_alpha = clampf(1 - (pose_time - float(action.hold_seconds)) / float(action.fade_seconds), 0, 1)

func _draw() -> void:
	if body == null:
		return
	var tint := Color(1, 1, 1, visual_alpha)
	draw_set_transform(FOOT, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 25, Color(0.07, 0.06, 0.04, visual_alpha * 0.2))
	var bob := sin(pose_time * TAU / 0.4) * 2 if pose == "move" else 0.0
	draw_set_transform(FOOT + Vector2(0, bob), 0, Vector2(facing, 1))
	var source := Rect2(frame_index * 256, 0, 256, 256)
	draw_texture_rect_region(body, Rect2(-128, -218, 256, 256), source, tint)
	var separate_projectile: bool = pose == "basic_attack" and manifest.actions.basic_attack.has("spawn_vfx")
	if effects_on and vfx != null and not separate_projectile:
		draw_texture_rect_region(vfx, Rect2(-128, -218, 256, 256), source, tint)
	draw_set_transform(Vector2.ZERO)
	if show_anchor and visual_alpha > 0:
		draw_line(FOOT - Vector2(5, 0), FOOT + Vector2(5, 0), Color("33b7c8"))
		draw_line(FOOT - Vector2(0, 5), FOOT + Vector2(0, 5), Color("33b7c8"))
	if not dead:
		var y := -148.0 if enemy_side else -120.0
		draw_rect(Rect2(-65, y - 27, 130, 23), Color(0.08, 0.13, 0.16, 0.82))
		draw_rect(Rect2(-37, y, 74, 7), Color("302921"))
		draw_rect(Rect2(-35, y + 2, 70 * health / max_health, 3), Color("ed7574") if enemy_side else Color("6bd58a"))
		draw_string(ThemeDB.fallback_font, Vector2(-62, y - 7), display_name, HORIZONTAL_ALIGNMENT_CENTER, 124, 17, Color("fff5df"))
