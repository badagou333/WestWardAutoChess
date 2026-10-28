extends Node2D
## A single sprite showcase, without the game scene, combat or other actors.
const MANIFEST := "res://art/attack/manifest.json"
## The approved source clip's video track is 3.500 s; this is not its 0.820 s battle cut.
const VIDEO_DURATION := 3.5
const LOOP_INTERVAL := 0.35
const FOOT := Vector2(960,650)
const DISPLAY_SCALE := 2.0
const RATIO := 1152.0/1400.0
var frames: Array[Texture2D] = []
var board: Texture2D
var frame_times: Array[float] = []
var frame_foot := Vector2.ZERO
var duration := 0.0
var impact := 0.0
var elapsed := 0.0
var ready_to_play := false
var sound_player: AudioStreamPlayer
var font: Font

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial Unicode MS"])
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	var sound_path := "res://audio/attack.wav"
	if FileAccess.file_exists(sound_path): sound_player.stream = AudioStreamWAV.load_from_file(sound_path)
	var board_image := Image.new()
	if board_image.load("res://art/board.png")==OK: board = ImageTexture.create_from_image(board_image)
	ready_to_play = board!=null and load_frames()
	queue_redraw()

func load_frames() -> bool:
	if not FileAccess.file_exists(MANIFEST): return false
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary or manifest.get("schema","") != "board-bear-forehand-trial-v1": return false
	if manifest.get("source_sign",0) != 1 or manifest.get("source_back",true) != false: return false
	if not manifest.get("frames") is Array or manifest.frames.size()!=20: return false
	if not manifest.get("foot") is Array or manifest.foot.size()!=2: return false
	var target_duration := VIDEO_DURATION
	var index := int(manifest.get("impact_index",-1))
	if target_duration<=0.0 or index<0 or index>=manifest.frames.size(): return false
	var loaded: Array[Texture2D] = []
	var times: Array[float] = []
	var previous := -1.0
	for item in manifest.frames:
		if not item is Dictionary: return false
		var filename := str(item.get("file",""))
		var raw_time = item.get("source_time_seconds")
		if not (raw_time is float or raw_time is int): return false
		var at := float(raw_time)
		if filename!=filename.get_file() or not filename.ends_with(".png") or not is_finite(at) or at<=previous or at>=target_duration: return false
		var path := "res://art/attack/"+filename
		var picture := Image.new()
		if picture.load(path)!=OK or picture.get_size()!=Vector2i(384,320): return false
		var texture := ImageTexture.create_from_image(picture)
		loaded.append(texture)
		times.append(at)
		previous = at
	if not is_zero_approx(times[0]): return false
	frames = loaded
	frame_times = times
	frame_foot = Vector2(manifest.foot[0],manifest.foot[1])
	duration = target_duration
	impact = times[index]
	return true

func frame_at(time: float) -> int:
	if not ready_to_play: return -1
	var phase := fposmod(time,duration+LOOP_INTERVAL)
	var attack_time := minf(phase,duration)
	var current := 0
	for index in frame_times.size():
		if attack_time+0.00000001<frame_times[index]: break
		current = index
	return current

func _process(delta: float) -> void:
	if not ready_to_play: return
	var period := duration+LOOP_INTERVAL
	var before := floori((elapsed-impact)/period)
	elapsed += delta
	var after := floori((elapsed-impact)/period)
	if after>before and sound_player.stream!=null: sound_player.play()
	queue_redraw()

func board_point(grid: Vector2) -> Vector2:
	var denominator := 1.0+(RATIO-1.0)*grid.y/7.0
	return Vector2(120.0+0.92*(824.0+1152.0*(grid.x/12.0-0.5)/denominator),
		110.0+0.92*(228.0+450.0*RATIO*(grid.y/7.0)/denominator))

func _draw() -> void:
	draw_rect(Rect2(0,0,1920,1080),Color("102323"))
	if board!=null: draw_texture_rect(board,Rect2(Vector2(120,110),Vector2(1672,941)*0.92),false)
	for x in range(13): draw_line(board_point(Vector2(x,0)),board_point(Vector2(x,7)),Color(.16,.22,.20,.42),1.2,true)
	for y in range(8): draw_line(board_point(Vector2(0,y)),board_point(Vector2(12,y)),Color(.16,.22,.20,.42),1.2,true)
	if ready_to_play:
		draw_set_transform(FOOT,0,Vector2(52,9))
		draw_circle(Vector2.ZERO,1,Color(.02,.04,.03,.30))
		draw_set_transform(Vector2.ZERO)
		var dest := Rect2(FOOT-frame_foot*DISPLAY_SCALE,Vector2(384,320)*DISPLAY_SCALE)
		draw_texture_rect(frames[frame_at(elapsed)],dest,false)
	elif font!=null:
		draw_string(font,Vector2(610,555),"素材未就绪，请检查攻击帧",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color.WHITE)
	if font!=null:
		draw_string(font,Vector2(145,95),"熊山君 · 普通攻击展示",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("e3e6db"))
