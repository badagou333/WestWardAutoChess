extends "res://scripts/presentation/audio_feedback.gd"
## Opt-in board profile. Legacy entry points keep their original AudioFeedback.
const PROFILE := "board-selected-noncommercial-20261009"
const RUNTIME := "res://audio/runtime/board-selected-20261009/"
const MANIFEST_PATH := RUNTIME+"manifest.json"
const Events = preload("res://scripts/combat/attack_events.gd")
var role_rules := {}
var asset_map := {}
var primary_slots: Array[Dictionary]=[]
var seen := {}
var audit := []
var stats := {"requested":0,"played":0,"duplicates":0,"muted":0,"paused":0,"dropped":0,"preempted":0,"expired":0,"invalid":0,"direct_primary_rejected":0}

func _ready() -> void:
	super._ready() # Original UI, death and Tang warning cues/controls remain.
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(manifest.profile==PROFILE)
	for asset in manifest.assets: asset_map[asset.id]=asset
	for rule in manifest.roles:
		role_rules[rule.role]=rule
		var path: String=RUNTIME+asset_map[rule.asset].file
		streams[rule.event_key]=load(path) if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
		stream_paths[rule.event_key]=path
	# Keep the original eight UI/death/warning slots separate. New long wolf
	# tails cannot occupy or steal their channels; volume/mute still see all16.
	for index in 8:
		var player:=AudioStreamPlayer.new()
		player.bus=bus_name
		add_child(player)
		voices.append(player)
		primary_slots.append({"until":0,"priority":0,"key":""})

func _primary_key(key: String) -> bool:
	for rule in role_rules.values():
		if rule.event_key==key: return true
	return false

func _expired(now: int) -> void:
	for slot in primary_slots:
		if int(slot.until)>0 and int(slot.until)<=now:
			if _primary_key(slot.key): stats.expired+=1
			slot.until=0
			slot.priority=0
			slot.key=""

func play_cue(key: String, target_id := 0) -> bool:
	# A role sound must carry an instance + immutable event serial, never an
	# unqualified key or the legacy role-wide 60ms throttle.
	if _primary_key(key):
		stats.direct_primary_rejected+=1
		return false
	return super.play_cue(key,target_id)

func _play_primary(key: String) -> String:
	if not enabled or level<=0: return "muted"
	if paused: return "paused"
	if not streams.has(key) or streams[key]==null: return "invalid"
	var now := Time.get_ticks_msec()
	_expired(now)
	var chosen := -1
	for index in primary_slots.size():
		if int(primary_slots[index].until)<=now:
			chosen=index
			break
	if chosen<0: return "dropped" # No queue or equal-priority tail interruption.
	var player: AudioStreamPlayer=voices[chosen+8]
	player.stop()
	player.stream=streams[key]
	player.pitch_scale=1.0 # Game 2x never changes the selected sound's pitch/speed.
	player.volume_db=linear_to_db(maxf(level,0.0001))-6.0
	primary_slots[chosen]={"until":now+int(ceil(player.stream.get_length()*1000)),"priority":priority(key),"key":key}
	if DisplayServer.get_name()!="headless": player.play()
	cue_played.emit(key)
	return "played"

func _role_event(event: Dictionary, trigger: String) -> void:
	var role: String=str(event.get("source_key",""))
	if not role_rules.has(role) or role_rules[role].recommended_trigger!=trigger: return
	var source=event.get("source")
	var serial: int=int(event.get("serial",0))
	if not Events.alive(source) or serial<=0:
		stats.invalid+=1
		return
	var instance: int=source.get_instance_id()
	var token := "%d:%d" % [instance,serial]
	var key: String=role_rules[role].event_key
	stats.requested+=1
	var outcome := "duplicates"
	if not seen.has(token):
		# Muted, paused or capacity-dropped events are consumed too. No catch-up
		# sound when unmuting/unpausing, no delayed duplicate callback playback.
		seen[token]=true
		outcome=_play_primary(key)
	stats[outcome]+=1
	audit.append({"source_id":instance,"serial":serial,"source_key":role,"trigger":trigger,"key":key,"outcome":outcome})

func released(event: Dictionary) -> void:
	if event.get("healing",false): return
	if not Events.alive(event.get("target")):
		stats.invalid+=1
		return
	_role_event(event,"projectile_launched")

func role_applied(event: Dictionary, effective_amount: float) -> void:
	if effective_amount<=0: return
	if event.get("healing",false):
		_role_event(event,"positive_healing_applied")
	else:
		_role_event(event,"projectile_damage_applied" if event.has("texture") else "melee_damage_applied")

func resolved_attack(_event: Dictionary) -> void: pass # No old pre-HP main cue.

func hit_event(target, ranged: bool, is_escort: bool, event: Dictionary, effective_amount: float) -> void:
	# Selected role audio already supplies the primary sound; never add the old
	# shared material hit layer. Tang's separate warning is not an attack cue.
	if effective_amount<=0: return
	if is_escort or not role_rules.has(str(event.get("source_key",""))): super.hit(target,ranged,is_escort)

func set_paused(value: bool) -> void:
	if paused==value: return
	if not value:
		var gap: int=Time.get_ticks_msec()-pause_at
		for slot in primary_slots:
			if int(slot.until)>pause_at: slot.until+=gap
	super.set_paused(value)

func stop_all(reset_pause := true) -> void:
	super.stop_all(reset_pause)
	for slot in primary_slots: slot.until=0
	if reset_pause:
		seen.clear()
		audit.clear()
		for key in stats: stats[key]=0
