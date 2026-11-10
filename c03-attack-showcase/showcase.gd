extends Node2D
## Isolated preparation candidate. Not executed or accepted for runtime yet.
## One source direction, source PTS, one WAV. No combat or additional effects.
const MANIFEST_SHA := "fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98"
const BOARD_SHA := "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"
const AUDIO_SHA := "d1310bdaa9ea6017c2bef9e9b159c73f9fa39e15f3d6e337b37250f65ca77cfb"
const READY := "ready"
const PLAYING := "playing"
const ENDED := "ended"
const INSPECTION := "inspection"
const CONFIG_FILE := "res://showcase.json"

var ready_to_play := false
var load_error := ""
var state := READY
var elapsed := 0.0
var frames: Array[Texture2D] = []
var frame_ticks: Array[int] = []
var source_duration_ticks: Array[int] = []
var time_base := 1.0 / 90000.0
var media_end_ticks := 260250
var duration := 260250.0 / 90000.0
var foot_reference := Vector2(475, 760)
var world_foot := Vector2(720, 441)
var canvas := Vector2(960, 960)
var display_scale := 0.21
var audio_start_seconds := 0.405
var audio_event_handled := false
var sound_player: AudioStreamPlayer
var board: Texture2D
var font: Font
var play_button: Button
var replay_button: Button
var status_label: Label
var _inspection_index := 0
## D-20261110-004 horizontal mirror. 1 = original source direction, -1 = mirrored
## around the same world foot. Facing is presentation only: switching never
## touches elapsed time, state, the sound event or the playing WAV.
const FACING_ORIGINAL := 1
const FACING_MIRRORED := -1
var facing := FACING_ORIGINAL
var original_button: Button
var mirrored_button: Button
## Review-only: hide board/cell overlay so pixel symmetry can be measured.
var review_plain_background := false

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "Arial Unicode MS"])
	sound_player = AudioStreamPlayer.new()
	sound_player.max_polyphony = 1
	add_child(sound_player)
	ready_to_play = _load_assets()
	_make_controls()
	_update_controls()
	queue_redraw()

func _require(ok: bool, message: String) -> bool:
	if not ok:
		load_error = message
		push_error(message)
	return ok

func _local_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains(":") or path.contains("\\"):
		return false
	for part in path.split("/", true):
		if part in ["", ".", ".."]: return false
	return true

func _numeric_pair(value: Variant, expected: Vector2) -> bool:
	if not value is Array or value.size() != 2: return false
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int): return false
	return float(value[0]) == expected.x and float(value[1]) == expected.y

func _load_assets() -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_FILE))
	if not _require(raw is Dictionary, "C3 showcase configuration is missing or invalid"): return false
	var config: Dictionary = raw
	if not _require(config.get("schema", "") == "c03-single-showcase-v1", "Unsupported C3 showcase configuration"): return false
	for key in ["assets", "presentation", "playback", "audio"]:
		if not _require(config.get(key) is Dictionary, "Missing showcase section: " + key): return false
	var assets: Dictionary = config.assets
	var manifest_file := str(assets.get("manifest", ""))
	var board_file := str(assets.get("board", ""))
	if not _require(_local_path(manifest_file) and _local_path(board_file), "Asset paths must remain inside this standalone project"): return false
	var manifest_path := "res://" + manifest_file
	var board_path := "res://" + board_file
	if not _require(str(assets.get("manifest_sha256", "")) == MANIFEST_SHA and FileAccess.get_sha256(manifest_path) == MANIFEST_SHA,
		"C3 manifest differs from the frozen repository mapping"): return false
	if not _require(str(assets.get("board_sha256", "")) == BOARD_SHA and FileAccess.get_sha256(board_path) == BOARD_SHA,
		"Forest board differs from the approved board"): return false
	var manifest_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _require(manifest_raw is Dictionary, "Invalid C3 asset manifest"): return false
	var manifest: Dictionary = manifest_raw
	if not _require(manifest.get("schema", "") == "c3-frozen-repository-mapping-v1"
		and _numeric_pair(manifest.get("time_base"), Vector2(1, 90000))
		and _numeric_pair(manifest.get("canvas"), Vector2(960, 960))
		and _numeric_pair(manifest.get("foot_reference"), Vector2(475, 760)), "Unexpected source timing or fixed composition"): return false
	var playback: Dictionary = config.playback
	if not _require(int(playback.get("media_end_ticks", -1)) == media_end_ticks
		and int(playback.get("terminal_index", -1)) == 97
		and playback.get("terminal_policy", "") == "ended_static", "The terminal policy must preserve the zero-duration final sample"): return false
	# Use division consistently for exact source boundaries, including T.
	duration = float(media_end_ticks) / 90000.0
	if not _require(absf(float(manifest.get("source_video_media_end_seconds", -1)) - duration) < 0.000000000001
		and int(manifest.get("final_sample_duration_ticks", -1)) == 0, "Unexpected exact media end"): return false
	var presentation: Dictionary = config.presentation
	var point: Variant = presentation.get("world_foot")
	if not _require(point is Array and point.size() == 2, "Missing world foot"): return false
	world_foot = Vector2(float(point[0]), float(point[1]))
	display_scale = float(presentation.get("display_scale", 0))
	audio_start_seconds = float(config.audio.get("start_seconds", -1))
	if not _require(world_foot.is_finite() and is_finite(display_scale) and display_scale > 0
		and is_finite(audio_start_seconds) and audio_start_seconds >= 0 and audio_start_seconds < duration,
		"Invalid trial scale, world foot or audio suggestion"): return false
	var source_frames: Variant = manifest.get("frames")
	if not _require(source_frames is Array and source_frames.size() == 98, "All 98 source records are required"): return false
	var loaded: Array[Texture2D] = []
	var ticks: Array[int] = []
	var lengths: Array[int] = []
	var next_tick := 0
	var asset_root := manifest_path.get_base_dir()
	for index in source_frames.size():
		var item: Dictionary = source_frames[index]
		var filename := str(item.get("file", ""))
		var pts := int(item.get("pts_ticks", -1))
		var hold := int(item.get("source_duration_ticks", -1))
		var is_terminal: bool = index == 97
		if not _require(int(item.get("index", -1)) == index and pts == next_tick
			and ((is_terminal and hold == 0 and pts == media_end_ticks) or (not is_terminal and hold > 0 and pts < media_end_ticks)),
			"Source PTS, index or duration changed at record " + str(index)): return false
		if not _require(_local_path(filename) and filename.begins_with("frames/") and filename.ends_with(".png"),
			"Invalid source PNG path"): return false
		var path := asset_root.path_join(filename)
		if not _require(FileAccess.get_sha256(path) == str(item.get("sha256", "")), "Source PNG bytes changed: " + filename): return false
		var picture := Image.new()
		if not _require(picture.load(path) == OK and picture.get_size() == Vector2i(960, 960), "Source PNG could not load at its fixed canvas size"): return false
		loaded.append(ImageTexture.create_from_image(picture))
		ticks.append(pts)
		lengths.append(hold)
		next_tick += hold
	if not _require(next_tick == media_end_ticks, "Source duration sum differs from the media end"): return false
	var audio: Dictionary = manifest.audio
	var audio_file := str(audio.get("file", ""))
	if not _require(_local_path(audio_file) and FileAccess.get_sha256(asset_root.path_join(audio_file)) == AUDIO_SHA
		and str(audio.get("sha256", "")) == AUDIO_SHA, "Selected WAV bytes changed"): return false
	var stream := AudioStreamWAV.load_from_file(asset_root.path_join(audio_file))
	if not _require(stream != null and stream.mix_rate == 44100 and stream.stereo
		and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.data.size() == 44100 * 4
		and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Selected WAV must retain its original one-second PCM"): return false
	var board_image := Image.new()
	if not _require(board_image.load(board_path) == OK, "Forest board could not load"): return false
	board = ImageTexture.create_from_image(board_image)
	frames = loaded
	frame_ticks = ticks
	source_duration_ticks = lengths
	sound_player.stream = stream
	# source_frozen_file, source_video and historic status are never runtime paths.
	return true

func frame_at(seconds: float) -> int:
	if not ready_to_play or frame_ticks.is_empty() or not is_finite(seconds): return -1
	if seconds >= duration: return 97
	var current := 0
	for index in frame_ticks.size():
		if float(frame_ticks[index]) / 90000.0 > maxf(seconds, 0.0): break
		current = index
	return current

func current_frame_index() -> int:
	return _inspection_index if state == INSPECTION else frame_at(elapsed)

func source_to_world(point: Vector2) -> Vector2:
	return world_foot + (point - foot_reference) * draw_scale()

func draw_scale() -> Vector2:
	return Vector2(display_scale * float(facing), display_scale)

func set_facing(value: int) -> void:
	if value != FACING_ORIGINAL and value != FACING_MIRRORED: return
	if value == facing: return
	facing = value
	_update_controls()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: set_facing(FACING_ORIGINAL)
		KEY_2: set_facing(FACING_MIRRORED)

func play_from_start() -> void:
	if not ready_to_play: return
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
	# Compare the absolute endpoint first; subtracting the offset at the exact
	# audio tail may otherwise round a phase very slightly below one second.
	if elapsed >= audio_start_seconds + sound_player.stream.get_length(): return
	var phase := elapsed - audio_start_seconds
	# A stalled frame catches up at the CURRENT WAV phase; stale sounds stay silent.
	if state == PLAYING and phase >= 0.0 and phase < sound_player.stream.get_length():
		sound_player.play(phase)

func _process(delta: float) -> void:
	if not ready_to_play or state != PLAYING or not is_finite(delta) or delta < 0.0: return
	elapsed = minf(elapsed + delta, duration)
	if elapsed >= duration:
		state = ENDED
		audio_event_handled = true
		sound_player.stop()
		_update_controls()
	else:
		_sync_audio_event()
	queue_redraw()

func inspect_frame(index: int) -> void:
	# Programmatic review only: a still frame must never emit an old sound event.
	if not ready_to_play or index < 0 or index >= frames.size(): return
	sound_player.stop()
	audio_event_handled = true
	_inspection_index = index
	elapsed = float(frame_ticks[index]) / 90000.0
	state = INSPECTION
	_update_controls()
	queue_redraw()

func _make_controls() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(1050, 24)
	row.add_theme_constant_override("separation", 12)
	play_button = Button.new()
	replay_button = Button.new()
	play_button.text = "播放"
	replay_button.text = "重播"
	for button in [play_button, replay_button]:
		button.custom_minimum_size = Vector2(155, 48)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 22)
		row.add_child(button)
	play_button.pressed.connect(play_from_start)
	replay_button.pressed.connect(play_from_start)
	add_child(row)
	var facing_row := HBoxContainer.new()
	facing_row.position = Vector2(1050, 84)
	facing_row.add_theme_constant_override("separation", 12)
	original_button = Button.new()
	mirrored_button = Button.new()
	original_button.text = "原向 (1)"
	mirrored_button.text = "镜像 (2)"
	for button in [original_button, mirrored_button]:
		button.custom_minimum_size = Vector2(155, 44)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		facing_row.add_child(button)
	original_button.pressed.connect(set_facing.bind(FACING_ORIGINAL))
	mirrored_button.pressed.connect(set_facing.bind(FACING_MIRRORED))
	add_child(facing_row)
	status_label = Label.new()
	status_label.position = Vector2(35, 62)
	status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 19)
	add_child(status_label)

func _update_controls() -> void:
	if not is_instance_valid(play_button): return
	play_button.disabled = not ready_to_play or state != READY
	replay_button.disabled = not ready_to_play or state == READY
	original_button.disabled = not ready_to_play
	mirrored_button.disabled = not ready_to_play
	original_button.set_pressed_no_signal(facing == FACING_ORIGINAL)
	mirrored_button.set_pressed_no_signal(facing == FACING_MIRRORED)
	if not ready_to_play:
		status_label.text = "素材暂未就绪"
	else:
		match state:
			READY: status_label.text = "准备播放"
			PLAYING: status_label.text = "播放中"
			ENDED: status_label.text = "播放结束 · 末帧查看"
			INSPECTION: status_label.text = "静帧查看"

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 810), Color("102323"))
	if board != null and not review_plain_background: draw_texture_rect(board, Rect2(0, 0, 1440, 810), false)
	if ready_to_play and not review_plain_background:
		var diamond := PackedVector2Array([world_foot + Vector2(0, -34.56), world_foot + Vector2(69.12, 0),
			world_foot + Vector2(0, 34.56), world_foot + Vector2(-69.12, 0)])
		draw_colored_polygon(diamond, Color(0.44, 0.73, 0.58, 0.14))
		diamond.append(diamond[0])
		draw_polyline(diamond, Color("a9dbb1"), 2, true)
	if ready_to_play:
		# Mirror = negative X scale around the same world foot; same texture/PTS.
		draw_set_transform(world_foot, 0, draw_scale())
		draw_texture_rect(frames[current_frame_index()], Rect2(-foot_reference, canvas), false)
		draw_set_transform(Vector2.ZERO)
	if font != null:
		draw_rect(Rect2(20, 20, 410, 78), Color(0.04, 0.08, 0.07, 0.65))
		var title := "翠鸟 · 攻击 · 原向" if facing == FACING_ORIGINAL else "翠鸟 · 攻击 · 镜像"
		draw_string(font, Vector2(35, 51), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e3e6db"))

func _exit_tree() -> void:
	if is_instance_valid(sound_player): sound_player.stop()
