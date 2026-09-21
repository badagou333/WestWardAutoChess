extends Node

# Original synthesized placeholder cues. Replace streams by event key for final audio.
const CUES := {"ui":[660,0.04],"release":[420,0.06],"hit":[150,0.07],"heal":[880,0.12],"retreat":[95,0.14],"victory":[1046,0.18]}
var enabled := true
var level := 0.35
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var last_played := {}

func _ready() -> void:
	for key in CUES:
		var spec: Array = CUES[key]
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var count := int(float(spec[1]) * stream.mix_rate)
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in range(count):
			var t := float(i) / stream.mix_rate
			var envelope := sin(PI * float(i) / count) * exp(-t * 18)
			var sample := sin(TAU * float(spec[0]) * t) * envelope * 0.45
			bytes.encode_s16(i * 2,int(sample * 32767))
		stream.data = bytes
		streams[key] = stream
	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)

func play_cue(key: String) -> void:
	if not enabled or level <= 0 or DisplayServer.get_name() == "headless": return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(key,-1000)) < 45: return
	last_played[key] = now
	for player in voices:
		if not player.playing:
			player.stream = streams[key]
			player.volume_db = linear_to_db(level)
			player.play()
			return

func set_paused(value: bool) -> void:
	for player in voices: player.stream_paused = value

func stop_all() -> void:
	for player in voices:
		player.stop()
		player.stream_paused = false
	last_played.clear()
