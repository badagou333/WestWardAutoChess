extends Node2D
## D-20261110-004 B4 herb boy front attack, single standalone character.
## Plays 84 source frames on their own variable PTS (time base 1/15360) with the
## original WAV started together with frame 0 (offset 0). One shot, stops on the
## last frame, never loops. No mirror, combat, healing or extra effects.
const MANIFEST_SHA := "cefc1cec66ffdf3c0df817dd050f191a1dc96bf16b683e062e806e829d5afa84"
const BOARD_SHA := "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"
const AUDIO_SHA := "66ee72af663a0c2eecdd4c7c6817b149cb3b232227ae337e3b85a2333b7d3418"
const TIME_BASE := 15360
const FRAME_COUNT := 84
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
var media_end_ticks := 53760
var terminal_index := 83
var duration := 53760.0 / 15360.0
var foot_reference := Vector2(303, 684)
var world_foot := Vector2(720, 441)
var canvas := Vector2(864, 760)
var display_scale := 0.16
var use_mipmaps := true
var audio_start_seconds := 0.0
var audio_event_handled := false
var sound_player: AudioStreamPlayer
var board: Texture2D
var font: Font
var play_button: Button
var replay_button: Button
var status_label: Label
var _inspection_index := 0

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Heiti SC", "Noto Sans CJK SC", "Arial Unicode MS"])
	sound_player = AudioStreamPlayer.new()
	sound_player.max_polyphony = 1
	add_child(sound_player)
	ready_to_play = _load_assets()
	if use_mipmaps: texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if not _require(raw is Dictionary, "B4 showcase configuration is missing or invalid"): return false
	var config: Dictionary = raw
	if not _require(config.get("schema", "") == "b04-single-showcase-v1", "Unsupported B4 showcase configuration"): return false
	for key in ["assets", "presentation", "playback", "audio"]:
		if not _require(config.get(key) is Dictionary, "Missing showcase section: " + key): return false
	var assets: Dictionary = config.assets
	var manifest_file := str(assets.get("manifest", ""))
	var board_file := str(assets.get("board", ""))
	if not _require(_local_path(manifest_file) and _local_path(board_file), "Asset paths must remain inside this standalone project"): return false
	var manifest_path := "res://" + manifest_file
	var board_path := "res://" + board_file
	if not _require(str(assets.get("manifest_sha256", "")) == MANIFEST_SHA and FileAccess.get_sha256(manifest_path) == MANIFEST_SHA,
		"B4 manifest differs from the 05 delivery (180acf2)"): return false
	if not _require(str(assets.get("board_sha256", "")) == BOARD_SHA and FileAccess.get_sha256(board_path) == BOARD_SHA,
		"Forest board differs from the approved board"): return false
	var manifest_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _require(manifest_raw is Dictionary, "Invalid B4 asset manifest"): return false
	var manifest: Dictionary = manifest_raw
	var video: Variant = manifest.get("video")
	var canvas_info: Variant = manifest.get("canvas")
	if not _require(manifest.get("id", "") == "b04_herb_boy_attack_v1" and video is Dictionary and canvas_info is Dictionary
		and video.get("time_base", "") == "1/15360" and int(video.get("video_end_pts", -1)) == media_end_ticks
		and int(video.get("decoded_frames", -1)) == FRAME_COUNT
		and _numeric_pair(canvas_info.get("size"), canvas) and _numeric_pair(manifest.get("foot"), foot_reference),
		"Unexpected source timing, canvas or foot anchor"): return false
	var playback: Dictionary = config.playback
	if not _require(int(playback.get("media_end_ticks", -1)) == media_end_ticks
		and int(playback.get("terminal_index", -1)) == terminal_index
		and playback.get("terminal_policy", "") == "ended_static", "Terminal policy must stop on the last source frame"): return false
	duration = float(media_end_ticks) / float(TIME_BASE)
	var presentation: Dictionary = config.presentation
	var point: Variant = presentation.get("world_foot")
	if not _require(point is Array and point.size() == 2, "Missing world foot"): return false
	world_foot = Vector2(float(point[0]), float(point[1]))
	# display_scale is the 05 proposal (0.16) pending owner review: edit showcase.json.
	display_scale = float(presentation.get("display_scale", 0))
	use_mipmaps = bool(presentation.get("mipmaps", true))
	audio_start_seconds = float(config.audio.get("start_seconds", -1))
	if not _require(world_foot.is_finite() and is_finite(display_scale) and display_scale > 0 and display_scale <= 1.0
		and is_finite(audio_start_seconds) and audio_start_seconds >= 0 and audio_start_seconds < duration,
		"Invalid display scale, world foot or audio offset"): return false
	var source_frames: Variant = manifest.get("frames")
	if not _require(source_frames is Array and source_frames.size() == FRAME_COUNT, "All 84 source frames are required"): return false
	var loaded: Array[Texture2D] = []
	var ticks: Array[int] = []
	var lengths: Array[int] = []
	var next_tick := 0
	var asset_root := manifest_path.get_base_dir()
	for index in source_frames.size():
		var item: Dictionary = source_frames[index]
		var filename := str(item.get("file", ""))
		var pts := int(item.get("pts", -1))
		# The next PTS (or the media end) defines each frame's exact hold.
		var next_pts := media_end_ticks if index == FRAME_COUNT - 1 else int(source_frames[index + 1].get("pts", -1))
		var hold := next_pts - pts
		if not _require(int(item.get("index", -1)) == index and pts == next_tick and hold > 0
			and absf(float(item.get("duration_s", -1.0)) - float(hold) / TIME_BASE) < 0.000001
			and absf(float(item.get("time_s", -1.0)) - float(pts) / TIME_BASE) < 0.000001,
			"Source PTS, index or duration changed at frame " + str(index)): return false
		if not _require(_local_path(filename) and filename.begins_with("frames/") and filename.ends_with(".png"),
			"Invalid source PNG path"): return false
		var path := asset_root.path_join(filename)
		if not _require(FileAccess.get_sha256(path) == str(item.get("sha256", "")), "Source PNG bytes changed: " + filename): return false
		var picture := Image.new()
		if not _require(picture.load(path) == OK and picture.get_size() == Vector2i(canvas), "Source PNG could not load at its fixed canvas size"): return false
		if use_mipmaps: picture.generate_mipmaps()
		loaded.append(ImageTexture.create_from_image(picture))
		ticks.append(pts)
		lengths.append(hold)
		next_tick += hold
	if not _require(next_tick == media_end_ticks, "Source duration sum differs from the media end"): return false
	var audio: Dictionary = manifest.audio
	var audio_file := str(audio.get("file", ""))
	if not _require(_local_path(audio_file) and FileAccess.get_sha256(asset_root.path_join(audio_file)) == AUDIO_SHA
		and str(audio.get("sha256", "")) == AUDIO_SHA and float(audio.get("offset_to_video_start_s", -1)) == 0.0,
		"Original WAV bytes or offset changed"): return false
	var stream := AudioStreamWAV.load_from_file(asset_root.path_join(audio_file))
	if not _require(stream != null and stream.mix_rate == 44100 and stream.stereo
		and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.data.size() == 154350 * 4
		and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Original WAV must keep its 3.5 second 44.1kHz stereo PCM"): return false
	var board_image := Image.new()
	if not _require(board_image.load(board_path) == OK, "Forest board could not load"): return false
	board = ImageTexture.create_from_image(board_image)
	frames = loaded
	frame_ticks = ticks
	source_duration_ticks = lengths
	sound_player.stream = stream
	return true

func frame_at(seconds: float) -> int:
	if not ready_to_play or frame_ticks.is_empty() or not is_finite(seconds): return -1
	if seconds >= duration: return terminal_index
	var current := 0
	for index in frame_ticks.size():
		if float(frame_ticks[index]) / float(TIME_BASE) > maxf(seconds, 0.0): break
		current = index
	return current

func current_frame_index() -> int:
	return _inspection_index if state == INSPECTION else frame_at(elapsed)

func source_to_world(point: Vector2) -> Vector2:
	return world_foot + (point - foot_reference) * display_scale

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
	# Offset 0: the WAV starts together with frame 0. A late first update seeks to
	# the current phase; once the WAV would already be over nothing is replayed.
	if audio_event_handled or elapsed < audio_start_seconds: return
	audio_event_handled = true
	if elapsed >= audio_start_seconds + sound_player.stream.get_length(): return
	var phase := elapsed - audio_start_seconds
	if state == PLAYING and phase >= 0.0 and phase < sound_player.stream.get_length():
		sound_player.play(phase)

func _process(delta: float) -> void:
	if not ready_to_play or state != PLAYING or not is_finite(delta) or delta < 0.0: return
	elapsed = minf(elapsed + delta, duration)
	if elapsed >= duration:
		# WAV length equals the video track (3.5 s); stop together with the picture.
		state = ENDED
		audio_event_handled = true
		sound_player.stop()
		_update_controls()
	else:
		_sync_audio_event()
	queue_redraw()

func inspect_frame(index: int) -> void:
	# Programmatic review only: a still frame never emits sound.
	if not ready_to_play or index < 0 or index >= frames.size(): return
	sound_player.stop()
	audio_event_handled = true
	_inspection_index = index
	elapsed = float(frame_ticks[index]) / float(TIME_BASE)
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
	status_label = Label.new()
	status_label.position = Vector2(35, 62)
	status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 19)
	add_child(status_label)

func _update_controls() -> void:
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

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 810), Color("102323"))
	if board != null: draw_texture_rect(board, Rect2(0, 0, 1440, 810), false)
	if ready_to_play:
		var diamond := PackedVector2Array([world_foot + Vector2(0, -34.56), world_foot + Vector2(69.12, 0),
			world_foot + Vector2(0, 34.56), world_foot + Vector2(-69.12, 0)])
		draw_colored_polygon(diamond, Color(0.44, 0.73, 0.58, 0.14))
		diamond.append(diamond[0])
		draw_polyline(diamond, Color("a9dbb1"), 2, true)
		draw_set_transform(world_foot, 0, Vector2.ONE * display_scale)
		draw_texture_rect(frames[current_frame_index()], Rect2(-foot_reference, canvas), false)
		draw_set_transform(Vector2.ZERO)
	if font != null:
		draw_rect(Rect2(20, 20, 410, 78), Color(0.04, 0.08, 0.07, 0.65))
		draw_string(font, Vector2(35, 51), "药龄童子 · 正面攻击", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e3e6db"))

func _exit_tree() -> void:
	if is_instance_valid(sound_player): sound_player.stop()
