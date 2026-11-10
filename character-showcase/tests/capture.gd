extends SceneTree
## D-20261110-005 real-window screenshots through the app: the selector, then
## each character/direction at configured review moments (full Viewport PNG).
##   --output=<abs dir> [--character=<id>]
## Crop-level equality with the pre-merge projects is tests/baseline.gd's job.
const SIZE := Vector2i(1440, 810)
const MOMENTS := {"bear":[0.0, 1.4], "kingfisher":[0, 31, 97], "herb_boy":[0, 35, 83]}
var output := ""
var wanted := "all"
var app
var samples: Array = []
var errors: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--character="): wanted = arg.trim_prefix("--character=")
	call_deferred("run")

func shot(name: String, extra: Dictionary) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_size() != SIZE:
		errors.append("viewport size " + name)
		return
	var path := output.path_join(name + ".png")
	if img.save_png(path) != OK:
		errors.append("save " + path)
		return
	extra["file"] = name + ".png"
	extra["sha256"] = FileAccess.get_sha256(path)
	samples.append(extra)

func run() -> void:
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path():
		push_error("capture needs a real window and an absolute --output")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	AudioServer.set_bus_mute(0, true)
	root.title = "D-20261110-005 Character Showcase Capture (Muted)"
	root.size = SIZE
	app = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await shot("selector", {"screen":"selector"})
	var ids: Array = app.character_ids() if wanted == "all" else [wanted]
	for id in ids:
		app.open_character(id)
		var p = app.player
		p.set_process(false)
		if not p.ready_to_play:
			errors.append(id + " did not load")
			continue
		for d in p.directions.size():
			for moment in MOMENTS[id]:
				if p.mode == "loop":
					p.select_direction((d + 1) % p.directions.size())
					p.select_direction(d)
					p.elapsed = float(moment)
				else:
					p.select_direction(d)
					if int(moment) == p.frames.size() - 1:
						p.play_from_start()
						p._process(p.duration)
					elif int(moment) == 0:
						p.sound_player.stop()
						p.state = "ready"
						p.elapsed = 0.0
						p._update_controls()
					else:
						p.inspect_frame(int(moment))
				p.sound_player.stop()
				p.queue_redraw()
				var name := "%s-%s-%s" % [id, p.directions[d].id, str(moment)]
				await shot(name, {"character":id, "direction":p.directions[d].id, "moment":moment,
					"frame":p.current_frame_index(), "state":p.state if p.mode != "loop" else "loop",
					"world_foot":[p.source_to_world(p.foot_reference).x, p.source_to_world(p.foot_reference).y]})
		app.close_character()
	var report := {"schema":"character-showcase-capture-v1", "task":"D-20261110-005",
		"display_server":DisplayServer.get_name(), "rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"video_adapter":RenderingServer.get_video_adapter_name(), "engine":Engine.get_version_info().string,
		"os_input":false, "master_muted":true, "samples":samples, "errors":errors, "success":errors.is_empty()}
	var f := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t") + "\n")
	f.close()
	app.queue_free()
	await process_frame
	print("CHARACTER_CAPTURE ", samples.size(), " screenshots / ", errors.size(), " errors")
	quit(0 if errors.is_empty() else 1)
