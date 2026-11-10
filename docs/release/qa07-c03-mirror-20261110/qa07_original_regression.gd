extends SceneTree
## 07 regression probe: render all 98 indices on the normal board view in the
## DEFAULT (original) facing and write a SHA-256 of the stage region (y>=140,
## full width, below the title/buttons) per index. Run once on the pre-mirror
## commit and once on the mirror commit; the two lists must match exactly.
## Works on both versions (does not reference facing APIs).
const Y0 := 140
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var hashes := []
	if scene.ready_to_play:
		for i in 98:
			scene.inspect_frame(i)
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var stage := img.get_region(Rect2i(0, Y0, img.get_width(), img.get_height() - Y0))
			var ctx := HashingContext.new()
			ctx.start(HashingContext.HASH_SHA256)
			ctx.update(stage.get_data())
			hashes.append(ctx.finish().hex_encode())
	var f := FileAccess.open(output, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ready": scene.ready_to_play, "stage_sha256": hashes}, "  "))
	f.close()
	print("QA07_ORIGINAL_REGRESSION ready=%s hashes=%d" % [scene.ready_to_play, hashes.size()])
	quit(0 if scene.ready_to_play and hashes.size() == 98 else 1)
