extends Node2D
## A single sprite showcase, without the game scene, combat or other actors.
const MANIFEST := "res://art/attack/manifest.json"
## The approved source clip's video track is 3.500 s; this is not its 0.820 s battle cut.
const VIDEO_DURATION := 3.5
const LOOP_INTERVAL := 0.35
## Same canvas, grid origin, and 2:1 cell as the selected forest board.
const FOOT := Vector2(720,441)
const DISPLAY_SCALE := 0.75
const GRID_HALF := Vector2(72,36)
const GRID_BOUNDS := Rect2(216,225,1008,432)
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
	var sound_path := "res://audio/source-track.wav"
	if FileAccess.file_exists(sound_path): sound_player.stream = AudioStreamWAV.load_from_file(sound_path)
	var board_image := Image.new()
	if board_image.load("res://art/forest-board.png")==OK: board = ImageTexture.create_from_image(board_image)
	ready_to_play = board!=null and load_frames()
	if ready_to_play and sound_player.stream!=null: sound_player.play()
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
	var before := floori(elapsed/period)
	elapsed += delta
	var after := floori(elapsed/period)
	if after>before and sound_player.stream!=null:
		var phase:=fposmod(elapsed,period)
		if phase<sound_player.stream.get_length(): sound_player.play(phase)
		else: sound_player.stop()
	queue_redraw()

func diamond(center: Vector2, inset: float=1.0) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(0,-GRID_HALF.y)*inset,center+Vector2(GRID_HALF.x,0)*inset,
		center+Vector2(0,GRID_HALF.y)*inset,center+Vector2(-GRID_HALF.x,0)*inset])

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,810),Color("102323"))
	if board!=null: draw_texture_rect(board,Rect2(0,0,1440,810),false)
	for u in range(-12,13):
		for v in range(-12,13):
			var center:=FOOT+Vector2((u-v)*GRID_HALF.x,(u+v)*GRID_HALF.y)
			if center.x-GRID_HALF.x<GRID_BOUNDS.position.x or center.x+GRID_HALF.x>GRID_BOUNDS.end.x or center.y-GRID_HALF.y<GRID_BOUNDS.position.y or center.y+GRID_HALF.y>GRID_BOUNDS.end.y: continue
			var line:=diamond(center)
			line.append(line[0])
			draw_polyline(line,Color(0.05,0.13,0.11,0.055),1,true)
	# The selected central cell is visible like the reference deployment view.
	var selected:=diamond(FOOT,0.96)
	draw_colored_polygon(selected,Color(0.44,0.73,0.58,0.14))
	selected.append(selected[0])
	draw_polyline(selected,Color("a9dbb1"),2,true)
	if ready_to_play:
		draw_set_transform(FOOT,0,Vector2(25,7))
		draw_circle(Vector2.ZERO,1,Color(.02,.04,.03,.30))
		draw_set_transform(Vector2.ZERO)
		var dest := Rect2(FOOT-frame_foot*DISPLAY_SCALE,Vector2(384,320)*DISPLAY_SCALE)
		draw_texture_rect(frames[frame_at(elapsed)],dest,false)
	elif font!=null:
		draw_string(font,Vector2(420,500),"素材未就绪，请检查攻击帧",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if font!=null:
		draw_string(font,Vector2(35,55),"熊山君 · 普通攻击展示",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e3e6db"))
