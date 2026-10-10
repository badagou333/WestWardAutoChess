extends "res://scripts/presentation/audio_feedback.gd"
## Opt-in board profile. Legacy entry points keep their original AudioFeedback.
const PROFILE := "board-selected-noncommercial-20261010"
const RUNTIME := "res://audio/runtime/board-selected-20261010/"
const MANIFEST_PATH := RUNTIME+"manifest.json"
const Events = preload("res://scripts/combat/attack_events.gd")
var role_rules := {}
var asset_map := {}
const DISABLED_CUES := ["rat_death","boar_death","wolf_death","bear_lord_death","victory"]
const FILE_BY_KEY := {
	"guard_monk_attack":"monk_bear_whack.wav","bear_lord_attack":"monk_bear_whack.wav",
	"wild_hunter_attack":"hunter_launch_02.wav","sparrow_spirit_attack":"sparrow_attack_first.wav",
	"herbal_spirit_child_attack":"healer_new_full.wav","foxfire_imp_attack":"foxfire_A_faithful.wav",
	"rat_attack":"rat_attack_second.wav","boar_attack":"boar_attack_full.wav",
	"wolf_attack":"wolf_first_call.wav","tangseng_hurt_warning":"tangseng_hurt_warning.wav"}
var loaded_keys: Array[String]=[]
var rejected_keys: Array[String]=[]
var secondary_cues := []
var primary_slots: Array[Dictionary]=[]
var seen := {}
var audit := []
var stats := {"requested":0,"played":0,"duplicates":0,"muted":0,"paused":0,"dropped":0,"preempted":0,"expired":0,"invalid":0,"direct_primary_rejected":0}

func _ready() -> void:
	# Do NOT invoke the legacy initializer: it loads death/material sounds and
	# synthesizes victory. Only this board's explicit current allow-list is read.
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(manifest.profile==PROFILE)
	for asset in manifest.assets: asset_map[asset.id]=asset
	for rule in manifest.roles:
		role_rules[rule.role]=rule
		var path: String=RUNTIME+asset_map[rule.asset].file
		_load_cue(rule.event_key,path)
	secondary_cues=manifest.secondary_cues
	for rule in secondary_cues: _load_cue(rule.event_key,RUNTIME+asset_map[rule.asset].file)
	bus_name="DemoSFX_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,bus_name)
	AudioServer.set_bus_send(bus,"Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db=-1.0
	AudioServer.add_bus_effect(bus,limiter)
	# Eight warning slots and eight primary slots retain mute/level/pause behavior.
	for index in 16:
		var player:=AudioStreamPlayer.new()
		player.bus=bus_name
		add_child(player)
		voices.append(player)
		if index<8: slots.append({"until":0,"priority":0,"key":""})
		else: primary_slots.append({"until":0,"priority":0,"key":""})

func _load_cue(key: String, path: String) -> void:
	if not FILE_BY_KEY.has(key) or path!=RUNTIME+"wav/"+str(FILE_BY_KEY[key]):
		push_error("Rejected board sound outside current key/path allow-list: "+key)
		return # Runtime guard also applies in release builds without assertions.
	loaded_keys.append(key) # Actual loading path, not inferred from a static table.
	# A fresh source checkout may have tracked import settings but no generated
	# sample cache yet. Read its exact raw WAV; PCKs load their imported resource.
	streams[key]=AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else load(path)
	stream_paths[key]=path

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
	if key in DISABLED_CUES:
		rejected_keys.append(key)
		return false
	# A role sound must carry an instance + immutable event serial, never an
	# unqualified key or the legacy role-wide 60ms throttle.
	if _primary_key(key):
		stats.direct_primary_rejected+=1
		return false
	if key!="tangseng_hurt_warning": return false
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
	if is_escort: hit(target,ranged,true)

func hit(_target, _ranged: bool, is_escort: bool) -> void:
	# Direct legacy API is board-local too: never requests a material fallback.
	if is_escort: play_cue("tangseng_hurt_warning")

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
		rejected_keys.clear()
		for key in stats: stats[key]=0
