extends SceneTree
## Actual graphical Viewport samples, never an offline board/character composite.
const VIEWPORT_SIZE := Vector2i(1440,810)
const FRONT_FRAME_NUMBERS := [1,7,41,42,43,44,45,46,48,83,84]
const CROP_MARGIN := 12
const SAMPLE_EPSILON := 0.000001
var output := "/tmp/bear-front-v2-four-direction-render"
var all_frames := false
var scene
var errors: Array[String] = []
var saved_png_count := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg=="--all-frames": all_frames = true
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		errors.append(message)
		push_error(message)
	return condition

func vector_json(value: Vector2) -> Array:
	return [value.x,value.y]

func valid_sha256(value: String) -> bool:
	return value.length()==64 and value.is_valid_hex_number(false)

func checked_save(picture: Image, filename: String) -> String:
	var path := output.path_join(filename)
	if not require(picture!=null and not picture.is_empty(),"Empty viewport image: "+filename): return ""
	if not require(picture.save_png(path)==OK,"Could not save viewport PNG: "+path): return ""
	saved_png_count += 1
	var digest := FileAccess.get_sha256(path)
	if not require(valid_sha256(digest),"Could not hash saved viewport PNG: "+path): return ""
	return digest

func read_manifest(clip_id: String) -> Dictionary:
	var clip: Dictionary = scene.clips[clip_id]
	var path: String = clip.manifest_path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not require(parsed is Dictionary,"Invalid runtime manifest: "+path): return {}
	if not require(parsed.get("frames") is Array,"Missing runtime manifest frames: "+path): return {}
	var expected_count := 84 if clip_id=="front" else 340
	if not require(parsed.frames.size()==expected_count and clip.frames.size()==expected_count and clip.times.size()==expected_count,
		"Unexpected runtime/manifest frame count for "+clip_id): return {}
	var expected_canvas := Vector2(400,320) if clip_id=="front" else Vector2(384,320)
	if not require(clip.canvas==expected_canvas and clip.foot==Vector2(177,213) and is_equal_approx(float(clip.scale),0.75),
		"Canvas, canvas foot or display scale changed for "+clip_id): return {}
	var expected_duration := 3.0 if clip_id=="front" else 3.5416666666666665
	var expected_interval := 0.0 if clip_id=="front" else 0.35
	if not require(absf(float(clip.duration)-expected_duration)<0.0000001 and absf(float(clip.interval)-expected_interval)<0.0000001,
		"Unexpected duration or loop interval for "+clip_id): return {}
	var digest := FileAccess.get_sha256(path)
	if not require(valid_sha256(digest),"Could not hash runtime manifest: "+path): return {}
	return {"manifest":parsed,"path":path,"sha256":digest}

func capture_sample(direction: int, at: float, expected_index: int, metadata: Dictionary, sample_number: int) -> Dictionary:
	var render_time := at+SAMPLE_EPSILON
	scene.elapsed = render_time
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame_index: int = scene.frame_at(scene.elapsed)
	if not require(frame_index==expected_index,"Wrong frame at requested sample time for direction %d: expected %d, got %d" % [direction,expected_index,frame_index]): return {}
	var manifest: Dictionary = metadata.manifest
	var item: Dictionary = manifest.frames[frame_index]
	if direction<2:
		if not require(int(item.get("source_frame",-1))==frame_index+1 and int(item.get("original_source_frame",-1))==frame_index+10,
			"Front source-frame mapping does not match original 10..93"): return {}
		if not require(item.has("source_pts") and item.has("original_source_pts") and item.has("duration_ticks"),
			"Front manifest is missing exact PTS/duration fields"): return {}
	var source_file := str(item.get("file",""))
	var source_path: String = str(metadata.path).get_base_dir().path_join(source_file)
	var actual_source_sha := FileAccess.get_sha256(source_path)
	var declared_source_sha := str(item.get("sha256",""))
	if not require(valid_sha256(actual_source_sha),"Could not hash runtime source PNG: "+source_path): return {}
	if not require((direction>=2 or valid_sha256(declared_source_sha)) and (declared_source_sha=="" or declared_source_sha==actual_source_sha),
		"Runtime PNG does not match declared source SHA-256: "+source_path): return {}
	var world_foot: Vector2 = scene.source_to_world(scene.frame_foot)
	if not require(world_foot.is_equal_approx(Vector2(720,441)),"World foot changed during capture"): return {}
	var picture: Image = root.get_texture().get_image()
	if not require(picture!=null and not picture.is_empty() and picture.get_size()==VIEWPORT_SIZE,
		"Graphical viewport must render exactly 1440x810"): return {}
	# Crop pixels only from the image just returned by this real Viewport. The
	# conservative integer rectangle includes the full transformed frame canvas.
	var corner_a: Vector2 = scene.source_to_world(Vector2.ZERO)
	var corner_b: Vector2 = scene.source_to_world(scene.canvas)
	var left := floori(minf(corner_a.x,corner_b.x))-CROP_MARGIN
	var top := floori(minf(corner_a.y,corner_b.y))-CROP_MARGIN
	var right := ceili(maxf(corner_a.x,corner_b.x))+CROP_MARGIN
	var bottom := ceili(maxf(corner_a.y,corner_b.y))+CROP_MARGIN
	var crop_rect := Rect2i(left,top,right-left,bottom-top)
	if not require(Rect2i(Vector2i.ZERO,VIEWPORT_SIZE).encloses(crop_rect),"Character viewport crop falls outside the game viewport"): return {}
	var crop: Image = picture.get_region(crop_rect)
	if not require(crop.get_size()==crop_rect.size,"Viewport crop has an unexpected size"): return {}
	var direction_id: String = scene.DIRECTIONS[direction].id
	var filename := "%s-%03d-frame-%04d.png" % [direction_id,sample_number,frame_index+1]
	var crop_filename := "%s-%03d-frame-%04d-character.png" % [direction_id,sample_number,frame_index+1]
	var picture_sha := checked_save(picture,filename)
	if picture_sha=="": return {}
	var crop_sha := checked_save(crop,crop_filename)
	if crop_sha=="": return {}
	return {
		"direction":direction_id,"clip":scene.DIRECTIONS[direction].clip,
		"time":at,"render_time_seconds":render_time,"frame":frame_index,"frame_index_base":0,
		"manifest_array_index":frame_index,"source_index":item.get("source_index",null),
		"source_frame":item.get("source_frame",null),"original_source_frame":item.get("original_source_frame",null),
		"source_pts":item.get("source_pts",null),"original_source_pts":item.get("original_source_pts",null),
		"source_time_base":manifest.get("source_time_base",null),
		"duration_ticks":item.get("duration_ticks",null),"duration_seconds":item.get("duration_seconds",null),
		"source_time_seconds":item.get("source_time_seconds",null),"output_time_seconds":item.get("output_time_seconds",null),
		"source_file":source_file,"runtime_source_path":source_path,
		"declared_source_sha256":declared_source_sha,"runtime_source_sha256":actual_source_sha,
		"runtime_manifest_path":metadata.path,"runtime_manifest_sha256":metadata.sha256,
		"manifest_frame":item.duplicate(true),
		"canvas":vector_json(scene.canvas),"canvas_foot":vector_json(scene.frame_foot),
		"world_foot":vector_json(world_foot),"display_scale":scene.display_scale,"mirrored":scene.mirrored,
		"direction_sign":scene.DIRECTIONS[direction].sign,
		"source_sign":scene.clips[scene.DIRECTIONS[direction].clip].source_sign,
		"canvas_world_corners":[vector_json(corner_a),vector_json(corner_b)],
		"file":filename,"sha256":picture_sha,"viewport_size":[picture.get_width(),picture.get_height()],
		"character_file":crop_filename,"character_sha256":crop_sha,
		"character_viewport_rect":[crop_rect.position.x,crop_rect.position.y,crop_rect.size.x,crop_rect.size.y],
		"world_foot_in_character_crop":vector_json(world_foot-Vector2(crop_rect.position))
	}

func write_report(report: Dictionary) -> bool:
	var path := output.path_join("capture.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not require(file!=null,"Could not open capture report for writing: "+path): return false
	file.store_string(JSON.stringify(report,"\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if not require(result==OK,"Could not finish writing capture report: "+path): return false
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	return require(saved is Dictionary and saved.get("sample_count",-1)==report.sample_count and saved.get("samples",[]).size()==report.sample_count,
		"Saved capture report is incomplete")

func finish(report: Dictionary, succeeded: bool) -> void:
	report["success"] = succeeded and errors.is_empty()
	report["errors"] = errors.duplicate()
	report["sample_count"] = report.samples.size()
	report["saved_png_count"] = saved_png_count
	var report_saved := write_report(report)
	if is_instance_valid(scene):
		if is_instance_valid(scene.sound_player): scene.sound_player.stop()
		scene.queue_free()
		await process_frame
	var exit_code := 0 if succeeded and errors.is_empty() and report_saved else 1
	if exit_code==0:
		print("BEAR_FOUR_DIRECTION_CAPTURE ",report.sample_count," samples / ",report.saved_png_count," PNGs in ",output)
	quit(exit_code)

func run() -> void:
	if not require(DisplayServer.get_name()!="headless","A real graphical Godot Viewport is required; headless capture is refused"):
		quit(1)
		return
	if not require(output!="" and output.is_absolute_path(),"--output must be a nonempty absolute directory"):
		quit(1)
		return
	if not require(DirAccess.make_dir_recursive_absolute(output)==OK,"A writable output directory is required"):
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	root.title = "D-20261102-002 Bear Front v2 Capture (Muted)"
	root.size = VIEWPORT_SIZE
	var packed = load("res://showcase.tscn")
	if not require(packed is PackedScene,"Could not load showcase scene"):
		quit(1)
		return
	scene = packed.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	var expected_count := 848 if all_frames else FRONT_FRAME_NUMBERS.size()*2+8
	var report := {
		"kind":"Godot graphical viewport samples; source animation paused at recorded times",
		"task":"D-20261102-002","all_frames":all_frames,"expected_sample_count":expected_count,
		"expected_png_count":expected_count*2,"front_required_frame_numbers":FRONT_FRAME_NUMBERS,
		"front_frame_number_base":1,"front_original_frame_range":[10,93],
		"display_server":DisplayServer.get_name(),"window_title":root.title,"viewport_size":[1440,810],
		"engine_version":Engine.get_version_info(),"audio":"Master bus muted; no device listening or audio recording",
		"input":"Synthetic Godot Control events only; no operating-system mouse input",
		"crop_method":"Image.get_region of the same real viewport screenshot; no offline compositing",
		"limits":"Paused-time engine samples do not establish continuous human visual review or device listening",
		"clips":{},"direction_sample_counts":{},"samples":[]
	}
	if not require(scene.ready_to_play,"Missing or invalid directional resources"):
		await finish(report,false)
		return
	var manifests := {}
	for clip_id in ["front","back"]:
		var metadata := read_manifest(clip_id)
		if metadata.is_empty():
			await finish(report,false)
			return
		manifests[clip_id] = metadata
		var clip: Dictionary = scene.clips[clip_id]
		report.clips[clip_id] = {
			"runtime_manifest_path":metadata.path,"runtime_manifest_sha256":metadata.sha256,
			"manifest_frame_count":metadata.manifest.frames.size(),
			"source_video":metadata.manifest.get("source_video",null),
			"source_sha256":metadata.manifest.get("source_sha256",null),
			"source_time_base":metadata.manifest.get("source_time_base",null),
			"canvas":vector_json(clip.canvas),"canvas_foot":vector_json(clip.foot),
			"display_scale":clip.scale,"video_duration_seconds":clip.duration,"loop_interval_seconds":clip.interval
		}
	for direction in range(4):
		# These events are confined to this Godot viewport. They do not move or
		# click the operating-system mouse and never address an existing window.
		var location: Vector2 = scene.direction_buttons[direction].get_global_rect().get_center()
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = location
			Input.parse_input_event(event)
		await process_frame
		if not require(scene.direction_index==direction,"Synthetic button input did not select direction %d" % direction):
			await finish(report,false)
			return
		scene.sound_player.stop()
		var times: Array[float] = []
		var indices: Array[int] = []
		if all_frames:
			times.assign(scene.frame_times)
			for index in times.size(): indices.append(index)
		elif direction<2:
			for number in FRONT_FRAME_NUMBERS:
				indices.append(number-1)
				times.append(scene.frame_times[number-1])
		else:
			# Preserve the previous capture script's four back-view source times.
			times.assign([0.0,scene.duration*0.35,scene.duration*0.55,scene.duration-0.001])
			for at in times: indices.append(scene.frame_at(at+SAMPLE_EPSILON))
		var clip_id: String = scene.DIRECTIONS[direction].clip
		var before: int = report.samples.size()
		for i in times.size():
			var sample := await capture_sample(direction,times[i],indices[i],manifests[clip_id],i)
			if sample.is_empty():
				await finish(report,false)
				return
			report.samples.append(sample)
		var direction_count: int = report.samples.size()-before
		report.direction_sample_counts[scene.DIRECTIONS[direction].id] = direction_count
		if not require(direction_count==times.size(),"Incomplete direction sample count"):
			await finish(report,false)
			return
	if not require(report.samples.size()==expected_count and saved_png_count==expected_count*2,"Incomplete total sample/PNG count"):
		await finish(report,false)
		return
	await finish(report,true)
