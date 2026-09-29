extends Node
# Adoption list controls runtime assets; deferred hero retreats are never loaded.
signal cue_played(key: String)
const PACK := "res://audio/candidates/v1/"
const CUES := {"ui":[660,0.04],"victory":[1046,0.18]}
var enabled := true:
	set(value):
		enabled = value
		if not value: stop_all(false)
var level := 0.35:
	set(value):
		level = clampf(value,0,1)
		for player in voices: player.volume_db = linear_to_db(maxf(level,0.0001))-6.0
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var slots: Array[Dictionary] = []
var last_played := {}
var target_hits := {}
var paused := false
var pause_at := 0
var bus_name := ""

func _ready() -> void:
	var adoption: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"adoption.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))
	for entry in manifest.entries:
		if entry.key in adoption.approved_for_integration:
			var path: String = PACK+entry.file
			streams[entry.key] = load(path) if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
	for key in CUES:
		var spec: Array = CUES[key]
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var count := int(float(spec[1])*stream.mix_rate)
		var bytes := PackedByteArray()
		bytes.resize(count*2)
		for i in range(count):
			var t := float(i)/stream.mix_rate
			var envelope := sin(PI*float(i)/count)*exp(-t*18)
			bytes.encode_s16(i*2,int(sin(TAU*float(spec[0])*t)*envelope*0.45*32767))
		stream.data = bytes
		streams[key] = stream
	bus_name = "DemoSFX_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,bus_name)
	AudioServer.set_bus_send(bus,"Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus,limiter)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = bus_name
		add_child(player)
		voices.append(player)
		slots.append({"until":0,"priority":0,"key":""})

func priority(key: String) -> int:
	if key in ["tangseng_hurt_warning","bear_lord_death"]: return 4
	if key == "victory": return 3
	if key.ends_with("_attack"): return 2
	if key.ends_with("_death") or key == "ui": return 1
	return 0

func cooldown(key: String) -> int:
	if key == "tangseng_hurt_warning": return 1000
	if key.begins_with("shared_hit_"): return 120
	if key.ends_with("_death"): return 200
	return 60

func play_cue(key: String, target_id := 0) -> bool:
	if not enabled or level <= 0 or paused or not streams.has(key): return false
	if streams[key] == null: return false
	var now := Time.get_ticks_msec()
	if now-int(last_played.get(key,-10000)) < cooldown(key): return false
	if target_id != 0 and now-int(target_hits.get(target_id,-10000)) < 180: return false
	var chosen := -1
	for i in range(slots.size()):
		if int(slots[i].until) <= now:
			chosen = i
			break
	if chosen < 0:
		for i in range(slots.size()):
			if int(slots[i].priority) < priority(key) and (chosen < 0 or slots[i].priority < slots[chosen].priority): chosen = i
	if chosen < 0: return false
	last_played[key] = now
	if target_id != 0: target_hits[target_id] = now
	for id in target_hits.keys():
		if now-int(target_hits[id]) > 1000: target_hits.erase(id)
	var player := voices[chosen]
	player.stop()
	player.stream = streams[key]
	player.pitch_scale = 1.0
	player.volume_db = linear_to_db(maxf(level,0.0001))-6.0
	slots[chosen] = {"until":now+int(player.stream.get_length()*1000),"priority":priority(key),"key":key}
	if DisplayServer.get_name() != "headless": player.play()
	# Headless reports scheduling, not audible output.
	cue_played.emit(key)
	return true

func released(event: Dictionary) -> void:
	if not event.healing: play_cue(str(event.source_key)+"_attack")

func resolved_attack(event: Dictionary) -> void:
	if event.healing or not event.has("texture"):
		play_cue(str(event.source_key)+"_attack")

func hit(target, ranged: bool, is_escort: bool) -> void:
	if is_escort:
		play_cue("tangseng_hurt_warning")
		return
	if target.get("dead") == true or target.get("battle_dead") == true: return
	# Melee cues already include impact; avoid doubling that hit.
	if not ranged: return
	var key = target.get("unit_type")
	if key == null: key = target.get("enemy_type")
	var material := "flesh"
	if key in ["guard_monk","boar"]: material = "armor"
	elif key in ["wild_hunter","foxfire_imp","rat","wolf","bear_lord"]: material = "fur"
	play_cue("shared_hit_"+material,target.get_instance_id())

func set_paused(value: bool) -> void:
	if paused == value: return
	var now := Time.get_ticks_msec()
	if value: pause_at = now
	else:
		var gap := now-pause_at
		for slot in slots:
			if int(slot.until) > pause_at: slot.until += gap
	paused = value
	for player in voices:
		if player.playing or player.stream_paused: player.stream_paused = value

func stop_all(reset_pause := true) -> void:
	for player in voices:
		player.stop()
		player.stream_paused = false
	for slot in slots: slot.until = 0
	last_played.clear()
	target_hits.clear()
	if reset_pause: paused = false

func _exit_tree() -> void:
	stop_all()
	var bus := AudioServer.get_bus_index(bus_name)
	if bus > 0: AudioServer.remove_bus(bus)
