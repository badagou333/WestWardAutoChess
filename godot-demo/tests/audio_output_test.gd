extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":
		print("AUDIO_OUTPUT_SKIPPED: requires a window and real audio driver")
		quit(2)
		return
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_process(false)
	var sound = game.audio_feedback
	var cue := OS.get_environment("AUDIO_TEST_CUE")
	if cue.is_empty(): cue = "bear_lord_death"
	check(sound.play_cue(cue),"Requested cue scheduled")
	await create_timer(0.05).timeout
	var player = sound.voices[0]
	check(player.playing,"Real player started")
	sound.set_paused(true)
	var position: float = player.get_playback_position()
	await create_timer(0.10).timeout
	check(player.stream_paused and absf(player.get_playback_position()-position)<0.04,"Pause freezes active stream")
	sound.set_paused(false)
	var peak := -200.0
	var bus := AudioServer.get_bus_index(sound.bus_name)
	for i in range(30):
		await create_timer(0.01).timeout
		peak = maxf(peak,AudioServer.get_bus_peak_volume_left_db(bus,0))
	check(peak > -90,"Nonzero mixer signal")
	for child in game.get_children():
		if child is HSlider:
			child.value = 0.7
			check(is_equal_approx(sound.level,0.7),"Slider updates volume")
		if child is Button and child.text=="音效：开":
			child.pressed.emit()
			check(not sound.enabled and sound.voices.all(func(p):return not p.playing),"UI toggle stops sound")
			child.pressed.emit()
			check(sound.enabled,"UI toggle re-enables")
	print("AUDIO_OUTPUT cue=",cue," driver=",AudioServer.get_driver_name()," device=",AudioServer.output_device," peak_db=",peak," failures=",failures,"; not a human listening test")
	game.free()
	quit(1 if failures else 0)
