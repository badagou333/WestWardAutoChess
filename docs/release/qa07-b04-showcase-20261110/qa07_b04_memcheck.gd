extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var out := {}
	for mode in ["plain", "mip"]:
		await process_frame
		var t0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var keep := []
		for i in 10:
			var img := Image.new()
			img.load("res://art/b04/frames/b04_attack_%03d.png" % i)
			if mode == "mip": img.generate_mipmaps()
			keep.append(ImageTexture.create_from_image(img))
		await process_frame
		await RenderingServer.frame_post_draw
		var t1 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		out[mode] = {"monitor_mb_10tex": (t1 - t0) / 1048576.0, "image_mip": keep[0].get_image().has_mipmaps()}
		keep.clear()
	print("MEMCHECK ", JSON.stringify(out))
	quit()
