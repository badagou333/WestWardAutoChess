extends Node2D
## D-20261110-005 shared data-driven character player.
## One instance shows one character from res://characters/<id>/character.json.
## Two playback modes reproduce the pre-merge projects exactly:
##   loop     (bear): automatic loop, per-loop WAV restart, direction switch restarts.
##   one_shot (kingfisher, herb_boy): Ready -> Play -> Ended on the last frame,
##            WAV event at audio_start_seconds with late-phase seek, replay,
##            direction switch changes presentation only.
## No combat, healing or additional effects.
signal back_requested

const BOARD_PATH := "res://shared/forest-board.png"
const BOARD_SHA := "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"
const GRID_HALF := Vector2(72, 36)
const GRID_BOUNDS := Rect2(216, 225, 1008, 432)
const LOOP := "loop"
const READY := "ready"
const PLAYING := "playing"
const ENDED := "ended"
const INSPECTION := "inspection"

var character_id := ""
var config: Dictionary = {}
var mode := ""
var ready_to_play := false
var load_error := ""
var board: Texture2D
var font: Font
var sound_player: AudioStreamPlayer
var clips: Dictionary = {}
var directions: Array = []
var direction_index := -1
var world_foot := Vector2(720, 441)

# Active clip (both modes)
var frames: Array[Texture2D] = []
var frame_times: Array[float] = []   # seconds; loop mode uses these directly
var frame_ticks: Array[int] = []     # one_shot: PTS ticks
var time_base := 1
var canvas := Vector2.ZERO
var foot_reference := Vector2.ZERO
var display_scale := 1.0
var facing := 1
var duration := 0.0
var loop_interval := 0.0
var elapsed := 0.0
var state := READY
var audio_start_seconds := 0.0
var audio_event_handled := false
var _inspection_index := 0

var play_button: Button
var replay_button: Button
var status_label: Label
var back_button: Button
var direction_buttons: Array[Button] = []

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Heiti SC", "Noto Sans CJK SC", "Arial Unicode MS"])
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	ready_to_play = _load()
	if ready_to_play and bool(config.get("mipmaps", false)):
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_make_controls()
	if ready_to_play:
		if mode == LOOP:
			select_direction(0)
		else:
			_activate_clip(0)
			state = READY
	_update_controls()
	queue_redraw()

# ---- loading -------------------------------------------------------------------
func _require(ok: bool, message: String) -> bool:
	if not ok and load_error.is_empty():
		load_error = message
		push_error(message)
	return ok

func _local_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains(":") or path.contains("\\"):
		return false
	for part in path.split("/", true):
		if part in ["", ".", ".."]: return false
	return true

func _dig(source: Dictionary, dotted: String) -> Variant:
	var value: Variant = source
	for key in dotted.split("."):
		if not value is Dictionary: return null
		value = value.get(key)
	return value

func _pair(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2: return Vector2(NAN, NAN)
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int): return Vector2(NAN, NAN)
	return Vector2(float(value[0]), float(value[1]))

func _load() -> bool:
	if not _require(character_id.is_valid_identifier(), "Unknown character id"): return false
	var root := "res://characters/" + character_id
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + "/character.json"))
	if not _require(raw is Dictionary and raw.get("schema", "") == "character-showcase-v1" and raw.get("id", "") == character_id,
		"Character configuration missing or invalid: " + character_id): return false
	config = raw
	mode = str(config.get("mode", ""))
	if not _require(mode in [LOOP, "one_shot"] and str(config.get("board_style", "")) in ["grid", "cell"], "Unsupported mode or board style"): return false
	world_foot = _pair(config.get("world_foot"))
	if not _require(world_foot.is_finite(), "Missing world foot"): return false
	if not _require(FileAccess.get_sha256(BOARD_PATH) == BOARD_SHA, "Forest board differs from the approved board"): return false
	var board_image := Image.new()
	if not _require(board_image.load(BOARD_PATH) == OK, "Forest board could not load"): return false
	board = ImageTexture.create_from_image(board_image)
	if not _require(config.get("clips") is Dictionary and config.get("directions") is Array and not config.directions.is_empty(),
		"Clips and directions are required"): return false
	for clip_id in config.clips:
		var clip := _load_loop_clip(root, config.clips[clip_id], clip_id) if mode == LOOP else _load_one_shot_clip(root, config.clips[clip_id])
		if clip.is_empty(): return false
		clips[clip_id] = clip
	for item in config.directions:
		if not _require(item is Dictionary and clips.has(str(item.get("clip", ""))) and int(item.get("sign", 0)) in [-1, 1],
			"Invalid direction entry"): return false
	directions = config.directions
	return true

func _verified_manifest(root: String, settings: Dictionary) -> Dictionary:
	var file := str(settings.get("manifest", ""))
	if not _require(_local_path(file), "Manifest path must stay inside the character folder"): return {}
	var path := root.path_join(file)
	if not _require(FileAccess.get_sha256(path) == str(settings.get("manifest_sha256", "")), "Manifest bytes changed: " + path): return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _require(raw is Dictionary and raw.get("frames") is Array and not raw.frames.is_empty(), "Invalid manifest: " + path): return {}
	var manifest: Dictionary = raw
	manifest["_path"] = path
	return manifest

func _load_image(path: String, size: Vector2i, mipmaps: bool) -> Texture2D:
	var picture := Image.new()
	if picture.load(path) != OK or picture.get_size() != size: return null
	if mipmaps: picture.generate_mipmaps()
	return ImageTexture.create_from_image(picture)

## Bear (pre-merge bear-forehand-showcase/showcase.gd load_clip, plus SHA pins).
func _load_loop_clip(root: String, settings: Dictionary, clip_id: String) -> Dictionary:
	var manifest := _verified_manifest(root, settings)
	if manifest.is_empty(): return {}
	var audio_file := str(settings.get("audio", ""))
	if not _require(_local_path(audio_file) and FileAccess.get_sha256(root.path_join(audio_file)) == str(settings.get("audio_sha256", "")),
		"Audio bytes changed: " + audio_file): return {}
	var clip_canvas := _pair(manifest.get("canvas"))
	var clip_foot := _pair(manifest.get("foot"))
	var clip_duration := float(settings.get("video_duration_seconds", 0))
	var clip_interval := float(settings.get("loop_interval_seconds", -1))
	var clip_scale := float(settings.get("display_scale", 0))
	var source_sign := int(settings.get("source_sign", 0))
	if not _require(clip_canvas.is_finite() and clip_canvas.x > 0 and clip_canvas.y > 0 and clip_foot.is_finite()
		and clip_foot.x >= 0 and clip_foot.y >= 0 and clip_foot.x <= clip_canvas.x and clip_foot.y <= clip_canvas.y
		and is_finite(clip_duration) and clip_duration > 0 and is_finite(clip_interval) and clip_interval >= 0
		and is_finite(clip_scale) and clip_scale > 0 and source_sign in [-1, 1]
		and int(manifest.get("source_sign", 0)) == source_sign
		and bool(manifest.get("source_back", false)) == bool(settings.get("source_back", false)),
		"Unexpected clip composition: " + clip_id): return {}
	var size := Vector2i(clip_canvas)
	var mipmaps := bool(config.get("mipmaps", false))
	var loaded: Array[Texture2D] = []
	var times: Array[float] = []
	var textures := {}
	var previous := -1.0
	var base: String = manifest._path.get_base_dir()
	for item in manifest.frames:
		if not _require(item is Dictionary, "Invalid frame record"): return {}
		var filename := str(item.get("file", ""))
		var raw_time: Variant = item.get("source_time_seconds")
		if not _require((raw_time is float or raw_time is int), "Missing frame time"): return {}
		var at := float(raw_time)
		if not _require(filename == filename.get_file() and filename.ends_with(".png") and is_finite(at) and at > previous and at < clip_duration,
			"Frame order or time changed: " + filename): return {}
		if not textures.has(filename):
			var texture := _load_image(base.path_join(filename), size, mipmaps)
			if not _require(texture != null, "Frame could not load: " + filename): return {}
			textures[filename] = texture
		loaded.append(textures[filename])
		times.append(at)
		previous = at
	if not _require(is_zero_approx(times[0]), "First frame must start at zero"): return {}
	var stream := AudioStreamWAV.load_from_file(root.path_join(audio_file))
	if not _require(stream != null and stream.get_length() > 0 and stream.get_length() <= clip_duration + clip_interval + 0.001,
		"Audio must fit inside one loop"): return {}
	return {"frames":loaded, "times":times, "ticks":[] as Array[int], "time_base":1, "canvas":clip_canvas, "foot":clip_foot,
		"duration":clip_duration, "interval":clip_interval, "scale":clip_scale, "source_sign":source_sign,
		"stream":stream, "audio_start":0.0, "unique_textures":textures.size()}

## Kingfisher / herb boy (pre-merge c03 / b04 showcase.gd _load_assets, generalised).
func _load_one_shot_clip(root: String, settings: Dictionary) -> Dictionary:
	var manifest := _verified_manifest(root, settings)
	if manifest.is_empty(): return {}
	var timing: Variant = settings.get("timing")
	if not _require(timing is Dictionary, "Missing timing"): return {}
	var pts_field := str(timing.get("pts_field", ""))
	var tb := int(timing.get("time_base", 0))
	var media_end := int(settings.get("media_end_ticks", -1))
	var clip_canvas := _pair(_dig(manifest, str(settings.get("canvas_field", ""))))
	var clip_foot := _pair(_dig(manifest, str(settings.get("foot_field", ""))))
	var clip_scale := float(settings.get("display_scale", 0))
	var audio_start := float(settings.get("audio_start_seconds", -1))
	var clip_duration := float(media_end) / float(tb)
	if not _require(tb > 0 and media_end > 0 and clip_canvas.is_finite() and clip_foot.is_finite()
		and is_finite(clip_scale) and clip_scale > 0 and is_finite(audio_start) and audio_start >= 0 and audio_start < clip_duration,
		"Invalid timing, composition, scale or audio offset"): return {}
	var size := Vector2i(clip_canvas)
	var mipmaps := bool(config.get("mipmaps", false))
	var base: String = manifest._path.get_base_dir()
	var source: Array = manifest.frames
	var loaded: Array[Texture2D] = []
	var ticks: Array[int] = []
	var times: Array[float] = []
	var next_tick := 0
	for index in source.size():
		var item: Dictionary = source[index]
		var pts := int(item.get(pts_field, -1))
		var is_last: bool = index == source.size() - 1
		var end_tick: int = media_end if is_last else int(source[index + 1].get(pts_field, -1))
		# The last record may sit exactly at T with zero duration (kingfisher) or
		# hold until T (herb boy); every other record must hold a positive interval.
		var valid_hold: bool = (end_tick > pts) or (is_last and pts == media_end)
		var filename := str(item.get("file", ""))
		if not _require(int(item.get("index", -1)) == index and pts == next_tick and valid_hold and pts <= media_end,
			"Source PTS or index changed at record " + str(index)): return {}
		if not _require(_local_path(filename) and filename.begins_with("frames/") and filename.ends_with(".png"), "Invalid frame path"): return {}
		var path := base.path_join(filename)
		if not _require(FileAccess.get_sha256(path) == str(item.get("sha256", "")), "Frame bytes changed: " + filename): return {}
		var texture := _load_image(path, size, mipmaps)
		if not _require(texture != null, "Frame could not load at its canvas size: " + filename): return {}
		loaded.append(texture)
		ticks.append(pts)
		times.append(float(pts) / float(tb))
		next_tick = end_tick
	if not _require(next_tick == media_end, "Frame durations do not end at the media end"): return {}
	var audio: Variant = manifest.get("audio")
	var audio_file := str(audio.get("file", "")) if audio is Dictionary else ""
	if not _require(_local_path(audio_file) and FileAccess.get_sha256(base.path_join(audio_file)) == str(settings.get("audio_sha256", "")),
		"Audio bytes changed"): return {}
	var stream := AudioStreamWAV.load_from_file(base.path_join(audio_file))
	if not _require(stream != null and stream.get_length() > 0 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Audio could not load"): return {}
	return {"frames":loaded, "times":times, "ticks":ticks, "time_base":tb, "canvas":clip_canvas, "foot":clip_foot,
		"duration":clip_duration, "interval":0.0, "scale":clip_scale, "source_sign":1, "stream":stream,
		"audio_start":audio_start, "unique_textures":loaded.size()}

func _activate_clip(index: int) -> void:
	var direction: Dictionary = directions[index]
	var clip: Dictionary = clips[str(direction.clip)]
	frames = clip.frames
	frame_times = clip.times
	frame_ticks = clip.ticks
	time_base = clip.time_base
	canvas = clip.canvas
	foot_reference = clip.foot
	display_scale = clip.scale
	duration = clip.duration
	loop_interval = clip.interval
	audio_start_seconds = clip.audio_start
	facing = int(direction.sign) * int(clip.source_sign)
	if sound_player.stream != clip.stream:
		sound_player.stop()
		sound_player.stream = clip.stream
	direction_index = index

# ---- direction selection -----------------------------------------------------
func select_direction(index: int) -> void:
	if not ready_to_play or index < 0 or index >= directions.size(): return
	if direction_index == index: return
	if str(config.get("direction_switch", "")) == "restart":
		# Pre-merge bear: stop, switch clip, restart from zero with its own WAV.
		sound_player.stop()
		_activate_clip(index)
		elapsed = 0.0
		sound_player.play(0.0)
	else:
		# Pre-merge kingfisher: presentation only; time, state and sound continue.
		var direction: Dictionary = directions[index]
		if str(direction.clip) != str(directions[direction_index].clip): return
		facing = int(direction.sign)
		direction_index = index
	_update_controls()
	queue_redraw()

# ---- timing --------------------------------------------------------------------
func period() -> float:
	return duration + loop_interval if mode == LOOP else duration

func frame_at(seconds: float) -> int:
	if not ready_to_play or frames.is_empty(): return -1
	if mode == LOOP:
		var phase := fposmod(seconds, duration + loop_interval)
		var attack_time := minf(phase, duration)
		var current := 0
		for index in frame_times.size():
			if attack_time + 0.00000001 < frame_times[index]: break
			current = index
		return current
	if not is_finite(seconds): return -1
	if seconds >= duration: return frames.size() - 1
	var found := 0
	for index in frame_ticks.size():
		if float(frame_ticks[index]) / float(time_base) > maxf(seconds, 0.0): break
		found = index
	return found

func current_frame_index() -> int:
	if mode == LOOP: return frame_at(elapsed)
	return _inspection_index if state == INSPECTION else frame_at(elapsed)

func draw_scale() -> Vector2:
	return Vector2(display_scale * float(facing), display_scale)

func source_to_world(point: Vector2) -> Vector2:
	return world_foot + (point - foot_reference) * draw_scale()

# ---- one_shot playback ---------------------------------------------------------
func play_from_start() -> void:
	if not ready_to_play or mode == LOOP: return
	sound_player.stop()
	elapsed = 0.0
	audio_event_handled = false
	state = PLAYING
	_sync_audio_event()
	_update_controls()
	queue_redraw()

func _sync_audio_event() -> void:
	if audio_event_handled or elapsed < audio_start_seconds: return
	audio_event_handled = true
	# Compare the absolute endpoint first so an exact tail never replays.
	if elapsed >= audio_start_seconds + sound_player.stream.get_length(): return
	var phase := elapsed - audio_start_seconds
	# A stalled frame catches up at the CURRENT WAV phase; stale sounds stay silent.
	if state == PLAYING and phase >= 0.0 and phase < sound_player.stream.get_length():
		sound_player.play(phase)

func inspect_frame(index: int) -> void:
	# Programmatic review only: a still frame never emits sound.
	if not ready_to_play or mode == LOOP or index < 0 or index >= frames.size(): return
	sound_player.stop()
	audio_event_handled = true
	_inspection_index = index
	elapsed = float(frame_ticks[index]) / float(time_base)
	state = INSPECTION
	_update_controls()
	queue_redraw()

func _process(delta: float) -> void:
	if not ready_to_play: return
	if mode == LOOP:
		var length := duration + loop_interval
		var before := floori(elapsed / length)
		elapsed += delta
		var after := floori(elapsed / length)
		if after > before and sound_player.stream != null:
			sound_player.stop()
			var phase := fposmod(elapsed, length)
			if phase < sound_player.stream.get_length(): sound_player.play(phase)
		queue_redraw()
		return
	if state != PLAYING or not is_finite(delta) or delta < 0.0: return
	elapsed = minf(elapsed + delta, duration)
	if elapsed >= duration:
		state = ENDED
		audio_event_handled = true
		sound_player.stop()
		_update_controls()
	else:
		_sync_audio_event()
	queue_redraw()

# ---- controls ------------------------------------------------------------------
func _styled(button: Button, size: Vector2, font_size: int) -> void:
	button.custom_minimum_size = size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)

func _make_controls() -> void:
	if mode == LOOP:
		var row := HBoxContainer.new()
		row.position = Vector2(800, 24)
		row.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for i in directions.size():
			var button := Button.new()
			button.text = str(directions[i].get("button", ""))
			_styled(button, Vector2(145, 48), 22)
			button.toggle_mode = true
			button.button_group = group
			button.pressed.connect(select_direction.bind(i))
			row.add_child(button)
			direction_buttons.append(button)
		add_child(row)
	elif mode == "one_shot":
		var row := HBoxContainer.new()
		row.position = Vector2(1050, 24)
		row.add_theme_constant_override("separation", 12)
		play_button = Button.new()
		replay_button = Button.new()
		play_button.text = "播放"
		replay_button.text = "重播"
		for button in [play_button, replay_button]:
			_styled(button, Vector2(155, 48), 22)
			row.add_child(button)
		play_button.pressed.connect(play_from_start)
		replay_button.pressed.connect(play_from_start)
		add_child(row)
		if directions.size() > 1:
			var facing_row := HBoxContainer.new()
			facing_row.position = Vector2(1050, 84)
			facing_row.add_theme_constant_override("separation", 12)
			for i in directions.size():
				var button := Button.new()
				button.text = str(directions[i].get("button", ""))
				_styled(button, Vector2(155, 44), 20)
				button.toggle_mode = true
				button.focus_mode = Control.FOCUS_NONE
				button.pressed.connect(select_direction.bind(i))
				facing_row.add_child(button)
				direction_buttons.append(button)
			add_child(facing_row)
		status_label = Label.new()
		status_label.position = Vector2(35, 62)
		status_label.add_theme_font_override("font", font)
		status_label.add_theme_font_size_override("font_size", 19)
		add_child(status_label)
	back_button = Button.new()
	back_button.text = "返回选择 (Esc)"
	back_button.position = Vector2(20, 110)
	_styled(back_button, Vector2(170, 40), 18)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(func(): back_requested.emit())
	add_child(back_button)

func _update_controls() -> void:
	for i in direction_buttons.size():
		direction_buttons[i].disabled = not ready_to_play
		direction_buttons[i].set_pressed_no_signal(i == direction_index)
	if not is_instance_valid(play_button): return
	play_button.disabled = not ready_to_play or state != READY
	replay_button.disabled = not ready_to_play or state == READY
	if not ready_to_play:
		status_label.text = "素材暂未就绪"
	else:
		match state:
			READY: status_label.text = "准备播放"
			PLAYING: status_label.text = "播放中"
			ENDED: status_label.text = "播放结束 · 末帧查看"
			INSPECTION: status_label.text = "静帧查看"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var index: int = event.keycode - KEY_1
	if directions.size() > 1 and index >= 0 and index < directions.size():
		select_direction(index)
		get_viewport().set_input_as_handled()

# ---- drawing -------------------------------------------------------------------
func diamond(center: Vector2, inset: float = 1.0) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -GRID_HALF.y) * inset, center + Vector2(GRID_HALF.x, 0) * inset,
		center + Vector2(0, GRID_HALF.y) * inset, center + Vector2(-GRID_HALF.x, 0) * inset])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 810), Color("102323"))
	if board != null: draw_texture_rect(board, Rect2(0, 0, 1440, 810), false)
	var grid: bool = str(config.get("board_style", "")) == "grid"
	if grid:
		for u in range(-12, 13):
			for v in range(-12, 13):
				var center := world_foot + Vector2((u - v) * GRID_HALF.x, (u + v) * GRID_HALF.y)
				if center.x - GRID_HALF.x < GRID_BOUNDS.position.x or center.x + GRID_HALF.x > GRID_BOUNDS.end.x or center.y - GRID_HALF.y < GRID_BOUNDS.position.y or center.y + GRID_HALF.y > GRID_BOUNDS.end.y: continue
				var line := diamond(center)
				line.append(line[0])
				draw_polyline(line, Color(0.05, 0.13, 0.11, 0.055), 1, true)
		var selected := diamond(world_foot, 0.96)
		draw_colored_polygon(selected, Color(0.44, 0.73, 0.58, 0.14))
		selected.append(selected[0])
		draw_polyline(selected, Color("a9dbb1"), 2, true)
	elif ready_to_play:
		var cell := PackedVector2Array([world_foot + Vector2(0, -34.56), world_foot + Vector2(69.12, 0),
			world_foot + Vector2(0, 34.56), world_foot + Vector2(-69.12, 0)])
		draw_colored_polygon(cell, Color(0.44, 0.73, 0.58, 0.14))
		cell.append(cell[0])
		draw_polyline(cell, Color("a9dbb1"), 2, true)
	if ready_to_play:
		if grid:
			draw_set_transform(world_foot, 0, Vector2(25, 7))
			draw_circle(Vector2.ZERO, 1, Color(.02, .04, .03, .30))
		draw_set_transform(world_foot, 0, draw_scale())
		draw_texture_rect(frames[current_frame_index()], Rect2(-foot_reference, canvas), false)
		draw_set_transform(Vector2.ZERO)
	elif font != null:
		draw_string(font, Vector2(420, 500), "素材未就绪：" + load_error, HORIZONTAL_ALIGNMENT_LEFT, 900, 22, Color.WHITE)
	if font != null:
		draw_rect(Rect2(20, 20, 410, 78), Color(0.04, 0.08, 0.07, 0.65))
		var title := str(config.get("title", character_id))
		if bool(config.get("title_shows_direction", false)) and direction_index >= 0:
			title += " · " + str(directions[direction_index].label)
		draw_string(font, Vector2(35, 51), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e3e6db"))
		if config.has("hint"):
			draw_string(font, Vector2(35, 81), str(config.hint), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("c4cfc4"))

func _exit_tree() -> void:
	if is_instance_valid(sound_player): sound_player.stop()
