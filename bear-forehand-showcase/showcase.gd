extends Node2D
## Two source views and their authorised horizontal mirrors; no combat logic.
const CLIPS_FILE := "res://clips.json"
const FOOT := Vector2(720,441)
const GRID_HALF := Vector2(72,36)
const GRID_BOUNDS := Rect2(216,225,1008,432)
const DIRECTIONS := [
	{"id":"front_right","label":"右前","clip":"front","sign":1},
	{"id":"front_left","label":"左前","clip":"front","sign":-1},
	{"id":"back_right","label":"右后","clip":"back","sign":1},
	{"id":"back_left","label":"左后","clip":"back","sign":-1},
]
var clips: Dictionary = {}
var frames: Array[Texture2D] = []
var board: Texture2D
var frame_times: Array[float] = []
var frame_foot := Vector2.ZERO
var canvas := Vector2.ZERO
var display_scale := 1.0
var mirrored := false
var duration := 0.0
var loop_interval := 0.0
var impact := 0.0
var elapsed := 0.0
var direction_index := -1
var ready_to_play := false
var sound_player: AudioStreamPlayer
var font: Font
var direction_buttons: Array[Button] = []

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial Unicode MS"])
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	var board_image := Image.new()
	if board_image.load("res://art/forest-board.png")==OK: board = ImageTexture.create_from_image(board_image)
	ready_to_play = board!=null and load_clips()
	make_direction_buttons()
	if ready_to_play: select_direction(0)
	queue_redraw()

func local_resource(path: String) -> bool:
	return path!="" and not path.begins_with("/") and not path.contains("..") and not path.contains(":")

func load_clips() -> bool:
	if not FileAccess.file_exists(CLIPS_FILE): return false
	var config = JSON.parse_string(FileAccess.get_file_as_string(CLIPS_FILE))
	if not config is Dictionary or config.get("schema","")!="bear-attack-showcase-v1": return false
	if not config.get("clips") is Dictionary: return false
	var loaded := {}
	for clip_id in ["front","back"]:
		if not config.clips.get(clip_id) is Dictionary: return false
		var clip := load_clip(config.clips[clip_id],clip_id)
		if clip.is_empty(): return false
		loaded[clip_id] = clip
	clips = loaded
	return true

func load_clip(settings: Dictionary, clip_id: String) -> Dictionary:
	var manifest_path := str(settings.get("manifest",""))
	var audio_path := str(settings.get("audio",""))
	if not local_resource(manifest_path) or not local_resource(audio_path): return {}
	manifest_path = "res://"+manifest_path
	if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists("res://"+audio_path): return {}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary: return {}
	if not manifest.get("frames") is Array or manifest.frames.is_empty(): return {}
	if not manifest.get("canvas") is Array or manifest.canvas.size()!=2: return {}
	if not manifest.get("foot") is Array or manifest.foot.size()!=2: return {}
	var clip_canvas := Vector2i(int(manifest.canvas[0]),int(manifest.canvas[1]))
	var clip_foot := Vector2(float(manifest.foot[0]),float(manifest.foot[1]))
	var clip_duration := float(settings.get("video_duration_seconds",0))
	var clip_interval := float(settings.get("loop_interval_seconds",-1))
	var clip_scale := float(settings.get("display_scale",0))
	var source_sign := int(settings.get("source_sign",0))
	if clip_canvas.x<=0 or clip_canvas.y<=0 or not clip_foot.is_finite(): return {}
	if clip_foot.x<0 or clip_foot.y<0 or clip_foot.x>clip_canvas.x or clip_foot.y>clip_canvas.y: return {}
	if not is_finite(clip_duration) or clip_duration<=0 or not is_finite(clip_interval) or clip_interval<0: return {}
	if not is_finite(clip_scale) or clip_scale<=0 or source_sign not in [-1,1]: return {}
	if int(manifest.get("source_sign",0))!=source_sign or bool(manifest.get("source_back",false))!=(clip_id=="back"): return {}
	var loaded_frames: Array[Texture2D] = []
	var times: Array[float] = []
	var textures := {}
	var previous := -1.0
	for item in manifest.frames:
		if not item is Dictionary: return {}
		var filename := str(item.get("file",""))
		var raw_time = item.get("source_time_seconds")
		if not (raw_time is float or raw_time is int): return {}
		var at := float(raw_time)
		if filename!=filename.get_file() or not filename.ends_with(".png") or not is_finite(at) or at<=previous or at>=clip_duration: return {}
		if not textures.has(filename):
			var picture := Image.new()
			if picture.load(manifest_path.get_base_dir().path_join(filename))!=OK or picture.get_size()!=clip_canvas: return {}
			textures[filename] = ImageTexture.create_from_image(picture)
		loaded_frames.append(textures[filename])
		times.append(at)
		previous = at
	if not is_zero_approx(times[0]): return {}
	var stream := AudioStreamWAV.load_from_file("res://"+audio_path)
	if stream==null or stream.get_length()<=0: return {}
	if stream.get_length()>clip_duration+clip_interval+0.001: return {}
	var impact_index := int(manifest.get("impact_index",-1))
	var clip_impact := times[impact_index] if impact_index>=0 and impact_index<times.size() else -1.0
	return {"frames":loaded_frames,"times":times,"canvas":Vector2(clip_canvas),"foot":clip_foot,
		"duration":clip_duration,"interval":clip_interval,"scale":clip_scale,"source_sign":source_sign,
		"stream":stream,"impact":clip_impact,"manifest_path":manifest_path,"unique_textures":textures.size()}

func make_direction_buttons() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(800,24)
	row.add_theme_constant_override("separation",8)
	var group := ButtonGroup.new()
	for i in DIRECTIONS.size():
		var button := Button.new()
		button.text = "%d  %s" % [i+1,DIRECTIONS[i].label]
		button.custom_minimum_size = Vector2(145,48)
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_override("font",font)
		button.add_theme_font_size_override("font_size",22)
		button.disabled = not ready_to_play
		button.pressed.connect(select_direction.bind(i))
		row.add_child(button)
		direction_buttons.append(button)
	add_child(row)

func select_direction(index: int) -> void:
	if not ready_to_play or index<0 or index>=DIRECTIONS.size(): return
	if direction_index==index: return
	sound_player.stop()
	var direction: Dictionary = DIRECTIONS[index]
	var clip: Dictionary = clips[direction.clip]
	frames = clip.frames
	frame_times = clip.times
	frame_foot = clip.foot
	canvas = clip.canvas
	duration = clip.duration
	loop_interval = clip.interval
	display_scale = clip.scale
	impact = clip.impact
	mirrored = int(direction.sign)!=int(clip.source_sign)
	elapsed = 0.0
	direction_index = index
	sound_player.stream = clip.stream
	sound_player.play(0.0)
	for i in direction_buttons.size(): direction_buttons[i].set_pressed_no_signal(i==index)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
		KEY_4: index = 3
	if index>=0:
		select_direction(index)
		get_viewport().set_input_as_handled()

func frame_at(time: float) -> int:
	if not ready_to_play or frame_times.is_empty(): return -1
	var phase := fposmod(time,duration+loop_interval)
	var attack_time := minf(phase,duration)
	var current := 0
	for index in frame_times.size():
		if attack_time+0.00000001<frame_times[index]: break
		current = index
	return current

func source_to_world(point: Vector2) -> Vector2:
	return FOOT+(point-frame_foot)*Vector2(-display_scale if mirrored else display_scale,display_scale)

func _process(delta: float) -> void:
	if not ready_to_play: return
	var period := duration+loop_interval
	var before := floori(elapsed/period)
	elapsed += delta
	var after := floori(elapsed/period)
	if after>before and sound_player.stream!=null:
		sound_player.stop()
		var phase:=fposmod(elapsed,period)
		if phase<sound_player.stream.get_length(): sound_player.play(phase)
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
	var selected:=diamond(FOOT,0.96)
	draw_colored_polygon(selected,Color(0.44,0.73,0.58,0.14))
	selected.append(selected[0])
	draw_polyline(selected,Color("a9dbb1"),2,true)
	if ready_to_play:
		draw_set_transform(FOOT,0,Vector2(25,7))
		draw_circle(Vector2.ZERO,1,Color(.02,.04,.03,.30))
		draw_set_transform(FOOT,0,Vector2(-display_scale if mirrored else display_scale,display_scale))
		draw_texture_rect(frames[frame_at(elapsed)],Rect2(-frame_foot,canvas),false)
		draw_set_transform(Vector2.ZERO)
	elif font!=null:
		draw_string(font,Vector2(420,500),"素材未就绪，请检查动作文件",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if font!=null:
		draw_rect(Rect2(20,20,410,78),Color(0.04,0.08,0.07,0.65))
		draw_string(font,Vector2(35,51),"熊山君 · 四方向攻击",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e3e6db"))
		draw_string(font,Vector2(35,81),"点击按钮或按 1–4 切换方向",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("c4cfc4"))
