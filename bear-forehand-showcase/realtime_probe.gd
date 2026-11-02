extends SceneTree
## Normal graphical playback observations, not listening or human animation QA.
var output := "/tmp/bear-front-v2-realtime.json"
var failures: Array[String]=[]
var cases: Array=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Real-time probe requires the authorized dedicated graphical window")
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810)
	root.title="熊山君正面84帧 · 实时循环自测专用"
	var scene=load("res://showcase.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.sound_player.stop()
	await process_frame
	await process_frame
	check(scene.ready_to_play,"real source assets load")
	if not scene.ready_to_play:
		quit(1)
		return
	for direction in [0,1,2,3]:
		# Initial scene startup may have spent time rendering the first frame.
		if scene.direction_index==direction: scene.select_direction((direction+1)%4)
		scene.select_direction(direction)
		scene.set_process(true)
		var period: float=scene.duration+scene.loop_interval
		var target_cycles: int=3 if direction==0 else 1
		var wall_start:=Time.get_ticks_usec()
		var previous_cycle:=0
		var playback=scene.sound_player.get_stream_playback()
		var previous_playback: int=playback.get_instance_id() if playback!=null else 0
		var observations: Array=[]
		var seen_frames := {}
		var restarts:=0
		var maximum_phase_difference:=0.0
		var samples:=0
		while scene.elapsed<period*target_cycles+.15 and Time.get_ticks_usec()-wall_start<30000000:
			await process_frame
			var cycle:=floori(scene.elapsed/period)
			var phase:=fposmod(scene.elapsed,period)
			var frame: int=scene.frame_at(scene.elapsed)
			seen_frames[frame]=true
			var current=scene.sound_player.get_stream_playback() if scene.sound_player.playing else null
			var instance: int=current.get_instance_id() if current!=null else 0
			if cycle!=previous_cycle:
				check(cycle==previous_cycle+1,"normal graphical playback advances a single loop boundary")
				check(instance!=0 and instance!=previous_playback,"actual loop replaces the stopped old audio playback")
				observations.append({"cycle":cycle,"phase":phase,"frame":frame,"audio_position":scene.sound_player.get_playback_position(),"new_audio_playback":instance!=previous_playback})
				restarts+=1
				previous_cycle=cycle
			previous_playback=instance
			if scene.sound_player.playing and phase<scene.sound_player.stream.get_length():
				maximum_phase_difference=maxf(maximum_phase_difference,absf(scene.sound_player.get_playback_position()-phase))
			samples+=1
		check(restarts==target_cycles,"requested real-time loops complete without timeout")
		check(scene.sound_player.max_polyphony==1,"single-player polyphony remains one")
		cases.append({"direction":scene.DIRECTIONS[direction].id,"period":period,"cycles":restarts,"sample_count":samples,"distinct_frames_observed":seen_frames.size(),"wall_seconds":float(Time.get_ticks_usec()-wall_start)/1000000,"elapsed":scene.elapsed,"maximum_raw_audio_phase_difference":maximum_phase_difference,"boundaries":observations})
	scene.sound_player.stop()
	scene.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"real-time evidence opens")
	if file!=null: file.store_string(JSON.stringify({"scope":"normal graphical automatic playback; no OS pointer or speaker output","display_backend":DisplayServer.get_name(),"window_size":[root.size.x,root.size.y],"audio_driver":AudioServer.get_driver_name(),"device_listening":false,"human_continuous_visual_acceptance":false,"cases":cases,"failures":failures},"\t"))
	print("BEAR_FRONT_REALTIME cases=",cases.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
