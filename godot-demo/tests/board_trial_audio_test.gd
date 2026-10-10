extends SceneTree
## Standalone source/main-pack audit. Headless verifies scheduling, not hearing.
const Config = preload("res://scripts/data/board_trial_config.gd")
const Board = preload("res://scripts/board_trial.gd")
const RUNTIME_MANIFEST := "res://audio/runtime/board-selected-20261010/manifest.json"
const DISABLED := ["rat_death","boar_death","wolf_death","bear_lord_death","victory"]
const EXPECTED := {
	"guard_monk":["monk_bear_whack","melee_damage_applied","monk_bear_whack.wav","56502597d09207bc3b4acc3f866ef685eb5a4306852e2f16b89889cc666d4fde",19459,2],
	"wild_hunter":["hunter_launch_02_noncommercial","projectile_launched","hunter_launch_02.wav","6936dbe90b719c90d1dfa8900fc1736ca1bda035b767931d00e67e94027ac9a7",5732,2],
	"sparrow_spirit":["sparrow_attack","projectile_launched","sparrow_attack_first.wav","32f3ba8d0c0f48572f5d410202e53add1e675934ec0d2f0a52f11f34f86ee995",22491,2],
	"herbal_spirit_child":["healer_new","positive_healing_applied","healer_new_full.wav","3a40ab16654b2be18d4888976833984b6f13057897b11c643aec001f7fa2c894",39900,2],
	"foxfire_imp":["foxfire_A","projectile_launched","foxfire_A_faithful.wav","aa30009e92190a69ec99a404f047b453606a8f6e79e5a0f4fe3de495a900a7db",25137,1],
	"rat":["rat_attack","projectile_damage_applied","rat_attack_second.wav","7b1461f9f572778ab1b58bb5d746b50775087b74abbc160d53620121cc012f94",8820,2],
	"boar":["boar_attack_full","melee_damage_applied","boar_attack_full.wav","73258a27856e1b5453e4bbec55555b9fc574b1d522c74ec9c1ac157283fe56c3",17052,2],
	"wolf":["wolf_first_call","melee_damage_applied","wolf_first_call.wav","04b1add76cfc42dfa2c3384020d638d04fd279f053211485961c512dea49831c",12789,2],
	"bear_lord":["monk_bear_whack","melee_damage_applied","monk_bear_whack.wav","56502597d09207bc3b4acc3f866ef685eb5a4306852e2f16b89889cc666d4fde",19459,2]}
const IDS := {"guard_monk":"guard_monk","wild_hunter":"wild_hunter","sparrow_spirit":"sparrow_spirit","herbal_spirit_child":"herbal_spirit_child","foxfire_imp":"foxfire_imp","rat":"E5","boar":"E3","wolf":"E1","bear_lord":"E7"}
var failures := 0
var assets := []
var cases := []
var naturals := []
var baseline_path := ""
var output_path := "/tmp/board-audio-20261010-source.json"
var skip_natural := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func hash_bytes(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func fresh():
	var game=Board.new()
	game.enemy_profile="bear"
	root.add_child(game)
	game.set_process(false)
	return game
func isolate(game, ids: Array) -> void:
	for actor in game.actors:
		if actor.id not in ids:
			actor.node.take_damage(actor.hp_max)
			actor.dead=true
func cues_for(heard: Array, key: String) -> Array:
	return heard.filter(func(row): return row.key==key)
func event_for(source: Dictionary, target: Dictionary, serial: int) -> Dictionary:
	return {"source":source.node,"target":target.node,"view":source.node.presentation,"source_key":source.key,"serial":serial,"healing":source.key=="herbal_spirit_child","splash":source.key=="foxfire_imp","amount":source.damage,"projectile_kind":"","time":0.0}
func fixture(role: String, extra: Array = []) -> Dictionary:
	var game=fresh()
	check(game.start_battle(),"actual audio fixture starts "+role)
	var source: Dictionary=game._record(IDS[role])
	var target_id: String="guard_monk" if not source.friendly or role=="herbal_spirit_child" else "E5"
	var keep: Array=[source.id,target_id,"tangseng"]
	if role=="herbal_spirit_child": keep.append("E1") # Keep real battle open until healing arrives.
	keep.append_array(extra)
	isolate(game,keep)
	var target: Dictionary=game._record(target_id)
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	game._set_cell(source,Vector2i(3,3))
	game._set_cell(target,Vector2i(5,3) if source.reach==3 else Vector2i(4,3))
	if role=="herbal_spirit_child": game._set_cell(game._record("E1"),Vector2i(11,0))
	for actor in game.actors:
		if game._active(actor): actor.cooldown=100.0
	source.target=target.id
	source.cooldown=0.0
	if source.friendly!=target.friendly: target.target=source.id
	var heard: Array=[]
	var launched: Array=[]
	var applied: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append({"key":key,"time":game.elapsed}))
	game.combat.projectile_released.connect(func(event): launched.append(event.duplicate(false)))
	game.combat.resolved.connect(func(_target,_amount,_healing,event): applied.append(event.duplicate(false)))
	return {"game":game,"source":source,"target":target,"heard":heard,"launched":launched,"applied":applied}

func verify_assets() -> void:
	var game=fresh()
	var sound=game.audio_feedback
	check(sound.PROFILE=="board-selected-noncommercial-20261010","board uses current short-wolf/noncommercial selected audio profile")
	check(sound.role_rules.size()==9 and not sound.role_rules.has("tangseng"),"nine selected behaviors; core gets no new primary attack")
	check(sound.primary_slots.size()==8 and sound.slots.size()==8 and sound.voices.size()==16,"selected eight-voice pool is isolated from eight warning voices")
	check(sound.streams.size()==10 and sound.stream_paths.size()==10 and sound.loaded_keys.size()==10,"actual initialization loads only nine role keys plus warning")
	for key in DISABLED: check(not sound.streams.has(key) and not sound.stream_paths.has(key) and key not in sound.loaded_keys,"disabled cue is not initialized or loaded "+key)
	check(not sound.streams.has("ui") and not sound.streams.keys().any(func(key): return key.begins_with("shared_hit_")),"no synthetic UI/result or material fallback is loaded")
	check(game.ui.usage_label.text.contains("非商业试玩") and game.ui.audio_button!=null and game.ui.audio_volume!=null,"actual board controls expose usage marker/sound switch/volume (not rendered/input acceptance)")
	var attribution: String=FileAccess.get_file_as_string(sound.RUNTIME+"ATTRIBUTION.md")
	check(attribution.contains("Robinhood76") and attribution.contains("126464") and attribution.contains("CC BY-NC 4.0") and attribution.contains("Cheddababy") and attribution.contains("DWOBoyle"),"actual runtime/package contains required authors/source/license attribution")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_MANIFEST))
	check(manifest is Dictionary,"runtime provenance manifest loads in source or actual PCK")
	if not manifest is Dictionary:
		game.free()
		return
	var entries := {}
	for entry in manifest.assets: entries[entry.id]=entry
	var checked := {}
	for role in EXPECTED:
		var expected: Array=EXPECTED[role]
		var rule: Dictionary=sound.role_rules.get(role,{})
		var key: String=role+"_attack"
		check(rule.get("asset","")==expected[0] and rule.get("event_key","")==key and rule.get("recommended_trigger","")==expected[1],"actual role maps to approved single trigger "+role)
		check(sound.stream_paths.has(key) and sound.streams.get(key)!=null,"selected role loads actual runtime stream "+role)
		if not sound.stream_paths.has(key) or sound.streams.get(key)==null: continue
		var path: String=sound.stream_paths[key]
		check(path.begins_with("res://audio/runtime/board-selected-20261010/") and path.get_file()==expected[2],"runtime path uses current adopted asset "+role)
		var stream=sound.streams[key]
		check(stream is AudioStreamWAV and stream.mix_rate==44100 and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.stereo==(expected[5]==2),"actual selected stream retains PCM16/44100/channels "+role)
		check(absf(stream.get_length()-float(expected[4])/44100.0)<1.0/44100.0,"actual selected stream retains the approved clip duration "+role)
		var entry: Dictionary=entries.get(expected[0],{})
		check(entry.get("sha256","")==expected[3],"runtime provenance retains approved original WAV SHA "+role)
		var pcm_hash: String=hash_bytes(stream.data)
		check(not entry.get("pcm_sha256","").is_empty() and pcm_hash==entry.get("pcm_sha256",""),"decoded runtime/PCK PCM equals independently manifested source PCM "+role)
		if checked.has(path): continue
		checked[path]=true
		var raw_available: bool=FileAccess.file_exists(path)
		if raw_available: check(hash_bytes(FileAccess.get_file_as_bytes(path))==expected[3],"source original WAV bytes retain approved SHA "+role)
		assets.append({"asset":expected[0],"path":path,"original_wav_sha256":expected[3],"original_wav_available":raw_available,"verification":"original_WAV_and_imported_PCM" if raw_available else "imported_PCM_plus_embedded_original_SHA","pcm_sha256":pcm_hash,"duration":stream.get_length(),"pitch":1.0})
	check(checked.size()==8,"nine selected role keys load exactly eight shared runtime files")
	check(sound.stream_paths.guard_monk_attack==sound.stream_paths.bear_lord_attack,"guard and bear share the selected file without sharing attack identity")
	check(sound.secondary_cues.size()==1 and sound.secondary_cues[0].event_key=="tangseng_hurt_warning","warning is the only secondary cue")
	if sound.secondary_cues.size()==1:
		var rule: Dictionary=sound.secondary_cues[0]
		var entry: Dictionary=entries.get(rule.asset,{})
		var path: String=sound.stream_paths.get("tangseng_hurt_warning","")
		var stream=sound.streams.get("tangseng_hurt_warning")
		var expected_sha := "e1396159d6686440c57136d996d013d36fa45de9ca7e8c21c662383cc6069778"
		check(stream is AudioStreamWAV and stream.mix_rate==44100 and stream.format==AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and is_equal_approx(stream.get_length(),0.52),"existing warning retains mono PCM16/44100/full0.52 seconds")
		if stream!=null:
			var pcm: String=hash_bytes(stream.data)
			var raw: bool=FileAccess.file_exists(path)
			check(entry.get("sha256","")==expected_sha and pcm==entry.get("pcm_sha256",""),"retained warning original provenance and actual imported PCM are exact")
			if raw: check(hash_bytes(FileAccess.get_file_as_bytes(path))==expected_sha,"retained warning original WAV SHA is unchanged")
			assets.append({"asset":rule.asset,"path":path,"original_wav_sha256":expected_sha,"original_wav_available":raw,"verification":"original_WAV_and_imported_PCM" if raw else "imported_PCM_plus_embedded_original_SHA","pcm_sha256":pcm,"duration":stream.get_length(),"pitch":1.0})
	check(sound.rejected_keys.is_empty(),"initialization makes zero disabled-cue requests")
	game.free()

func real_single(role: String) -> void:
	var ctx:=fixture(role)
	var game=ctx.game
	var source: Dictionary=ctx.source
	var target: Dictionary=ctx.target
	if role=="herbal_spirit_child": target.node.take_damage(40.0)
	var before: float=game._hp(target)
	game._attack(source,target,role=="herbal_spirit_child")
	var serial: int=source.node.presentation.attack_serial
	check(cues_for(ctx.heard,role+"_attack").is_empty(),"request/windup alone does not schedule primary sound "+role)
	while ctx.applied.is_empty() and game.elapsed<1.0 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	var own: Array=ctx.applied.filter(func(event): return event.source==source.node and event.serial==serial)
	check(own.size()==1,"real original event resolves once "+role)
	var delta: float=game._hp(target)-before
	check(delta>0 if role=="herbal_spirit_child" else delta<0,"real HP effect precedes applied trigger "+role)
	var heard: Array=cues_for(ctx.heard,role+"_attack")
	check(heard.size()==1,"one actual primary scheduling for the selected behavior "+role)
	var rows: Array=game.audio_feedback.audit.filter(func(row): return row.source_id==source.node.get_instance_id() and row.serial==serial and row.key==role+"_attack")
	check(rows.size()==1 and rows[0].trigger==EXPECTED[role][1] and rows[0].source_key==role,"semantic audit binds actual source instance, serial and approved trigger "+role)
	if EXPECTED[role][1]=="projectile_launched":
		check(ctx.launched.size()==1 and heard.size()==1 and heard[0].time<game.elapsed,"remote primary occurs at actual launch, not impact "+role)
	else: check(heard.size()==1 and is_equal_approx(heard[0].time,game.elapsed),"impact/heal primary occurs at actual positive application "+role)
	check(not ctx.heard.any(func(row): return row.key.begins_with("shared_hit_")),"selected attacks do not add generic material hit layer "+role)
	cases.append({"case":"real_role","role":role,"serial":serial,"actual_hp_delta":delta,"launch_events":ctx.launched.size(),"primary_count":heard.size(),"audit":rows})
	game.free()

func delayed_serial_and_duplicates() -> void:
	var ctx:=fixture("rat")
	var game=ctx.game
	while ctx.launched.is_empty() and game.elapsed<0.75 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(ctx.launched.size()==1 and cues_for(ctx.heard,"rat_attack").is_empty(),"rat's actual projectile launch remains silent")
	if ctx.launched.is_empty():
		game.free()
		return
	var event: Dictionary=ctx.launched[0]
	var serial: int=event.serial
	# Explicit post-launch lifecycle fixture: begin a later presentation action.
	# The first missile remains a genuine production event with immutable serial.
	ctx.source.node.play_attack()
	check(ctx.source.node.presentation.attack_serial>serial and event.serial==serial,"in-flight projectile retains its original serial across later presentation action")
	while ctx.applied.is_empty() and game.elapsed<1.0 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(cues_for(ctx.heard,"rat_attack").size()==1,"late real rat impact triggers exactly its original attack sound")
	var before: int=game.audio_feedback.stats.duplicates
	game.audio_feedback.role_applied(event,1.0)
	game.audio_feedback.role_applied(event,1.0)
	check(game.audio_feedback.stats.duplicates==before+2 and cues_for(ctx.heard,"rat_attack").size()==1,"duplicate applied callbacks never replay the old missile serial")
	cases.append({"case":"delayed_serial_duplicates","serial":serial,"later_presentation_serial":ctx.source.node.presentation.attack_serial,"stats":game.audio_feedback.stats.duplicate(true)})
	game.free()

func distinct_instances(shared_file: bool) -> void:
	var game=fresh()
	game.start_battle()
	var ids: Array=["guard_monk","E7","tangseng"] if shared_file else ["E1","E2","guard_monk","tangseng"]
	isolate(game,ids)
	var first: Dictionary=game._record("guard_monk" if shared_file else "E1")
	var second: Dictionary=game._record("E7" if shared_file else "E2")
	var target: Dictionary=second if shared_file else game._record("guard_monk")
	game._set_cell(game._record("tangseng"),Vector2i(0,6))
	game._set_cell(first,Vector2i(3,3))
	game._set_cell(second,Vector2i(4,3) if shared_file else Vector2i(4,2))
	if not shared_file: game._set_cell(target,Vector2i(4,3))
	for actor in game.actors:
		if game._active(actor): actor.cooldown=100.0
	var heard: Array=[]
	game.audio_feedback.cue_played.connect(func(key): heard.append({"key":key,"time":game.elapsed}))
	first.cooldown=0
	second.cooldown=0
	first.target=target.id
	second.target=first.id if shared_file else target.id
	game._attack(first,target)
	game._attack(second,first if shared_file else target)
	check(first.node.presentation.attack_serial==second.node.presentation.attack_serial,"distinct live attackers really share the same serial number")
	while game.elapsed<0.7 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(cues_for(heard,first.key+"_attack").size()==(1 if shared_file else 2),"same serial or same file does not swallow independent source-instance attacks")
	if shared_file: check(cues_for(heard,second.key+"_attack").size()==1,"bear retains its independent main sound using shared guard file")
	check(game.audio_feedback.stats.duplicates==0,"two independent same-serial attacks are not semantic duplicates")
	cases.append({"case":"shared_file_instances" if shared_file else "two_wolf_instances","source_ids":[first.node.get_instance_id(),second.node.get_instance_id()],"stats":game.audio_feedback.stats.duplicate(true),"heard":heard})
	game.free()

func no_effect_and_splash() -> void:
	var ctx:=fixture("herbal_spirit_child")
	var game=ctx.game
	game._attack(ctx.source,ctx.target,true)
	while ctx.applied.is_empty() and game.elapsed<1 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(ctx.applied.size()==1 and game._hp(ctx.target)==ctx.target.hp_max and cues_for(ctx.heard,"herbal_spirit_child_attack").is_empty(),"real full-health healing has zero effective HP and no main sound")
	cases.append({"case":"full_health_heal","healing":game.metrics.healing.get(ctx.source.id,0.0),"primary_count":cues_for(ctx.heard,"herbal_spirit_child_attack").size()})
	game.free()
	ctx=fixture("foxfire_imp",["E6"])
	game=ctx.game
	var adjacent: Dictionary=game._record("E6")
	game._set_cell(adjacent,Vector2i(5,4))
	adjacent.cooldown=100
	var before: float=game._hp(ctx.target)+game._hp(adjacent)
	game._attack(ctx.source,ctx.target,false)
	while ctx.applied.is_empty() and game.elapsed<1 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(is_equal_approx(before-game._hp(ctx.target)-game._hp(adjacent),2*ctx.source.damage),"one real fox attack damages two actual splash recipients")
	check(cues_for(ctx.heard,"foxfire_imp_attack").size()==1,"multiple actual splash victims never multiply launch main sound")
	cases.append({"case":"real_fox_splash","actual_damage":before-game._hp(ctx.target)-game._hp(adjacent),"primary_count":cues_for(ctx.heard,"foxfire_imp_attack").size()})
	game.free()

func lifecycle_scheduler() -> void:
	var ctx:=fixture("wolf")
	var game=ctx.game
	var sound=game.audio_feedback
	var event: Dictionary=event_for(ctx.source,ctx.target,100)
	sound.enabled=false
	var played: int=sound.stats.played
	sound.role_applied(event,1.0)
	check(sound.stats.muted>0 and sound.stats.played==played,"disabled audio consumes eligible semantic event without playback")
	sound.enabled=true
	sound.role_applied(event,1.0)
	check(sound.stats.played==played and sound.stats.duplicates>0,"reenabling never replays previously muted attack")
	sound.level=0
	event.serial=101
	sound.role_applied(event,1.0)
	check(sound.stats.played==played,"level zero suppresses actual main scheduling")
	sound.level=0.35
	sound.role_applied(event,1.0)
	check(sound.stats.played==played,"restoring level does not replay consumed zero-level attack")
	game.toggle_pause()
	var before: Dictionary=game.report().duplicate(true)
	game.step(5)
	check(game.report()==before and sound.paused,"real game pause freezes combat and pauses audio")
	event.serial=102
	sound.role_applied(event,1.0)
	check(sound.stats.paused>0 and sound.stats.played==played,"paused semantic callback is consumed without playback")
	game.toggle_pause()
	sound.role_applied(event,1.0)
	check(sound.stats.played==played,"resume never replays a stale paused attack")
	# Explicit capacity fixtures exercise real bounded voice policy without
	# making claims about wall-clock realtime congestion or audible output.
	var now: int=Time.get_ticks_msec()
	var legacy_slots: Array=sound.slots.duplicate(true)
	for slot in sound.primary_slots:
		slot.until=now+10000
		slot.key="wolf_attack"
	var occupied_tails: Array=sound.primary_slots.duplicate(true)
	check(not sound.play_cue("ui") and sound.play_cue("tangseng_hurt_warning") and sound.primary_slots==occupied_tails,"full selected pool preserves retained warning while unused UI remains unloaded")
	legacy_slots=sound.slots.duplicate(true)
	event.serial=103
	var dropped: int=sound.stats.dropped
	sound.role_applied(event,1.0)
	check(sound.stats.dropped==dropped+1 and sound.primary_slots==occupied_tails,"full selected pool drops new event without cutting any existing tail")
	sound.primary_slots[0].until=Time.get_ticks_msec()-1
	event.serial=104
	sound.role_applied(event,1.0)
	check(sound.stats.played==played+1 and sound.stats.preempted==0 and sound.slots==legacy_slots,"expired selected slot is reused without touching legacy warning/UI/death capacity")
	game.speed=2
	check(sound.voices.all(func(player): return is_equal_approx(player.pitch_scale,1.0)),"2x battle speed does not alter adopted audio pitch")
	var expired: int=sound.stats.expired
	for slot in sound.primary_slots:
		slot.until=Time.get_ticks_msec()-1
		slot.key="wolf_attack"
	event.serial=105
	sound.role_applied(event,1.0)
	check(sound.stats.expired==expired+sound.primary_slots.size(),"past selected tails explicitly expire and release bounded voice capacity")
	check(sound.voices[8].stream==sound.streams.wolf_attack and is_equal_approx(sound.voices[8].pitch_scale,1.0),"rescheduled wolf retains the selected short stream and original pitch")
	var before_direct: int=sound.stats.played
	check(not sound.play_cue("wolf_attack") and sound.stats.played==before_direct,"selected main sound cannot bypass semantic event adapter")
	ctx.source.node.take_damage(ctx.source.hp_max)
	event.serial=106
	var requested: int=sound.stats.requested
	sound.role_applied(event,1.0)
	check(sound.stats.requested==requested and sound.stats.played==before_direct,"dead source cannot request or play selected main sound")
	var stats: Dictionary=sound.stats.duplicate(true)
	game.retry()
	check(sound.seen.is_empty() and not sound.paused and game.combat.strikes.is_empty() and game.combat.missiles.is_empty(),"retry clears semantic cache and pending old attack/effect state")
	cases.append({"case":"mute_pause_pool_death_retry","primary_capacity":sound.primary_slots.size(),"legacy_capacity":sound.slots.size(),"stats_before_retry":stats})
	game.free()

func preserved_secondary_cues() -> void:
	var game=fresh()
	var sound=game.audio_feedback
	var heard: Array=[]
	sound.cue_played.connect(func(key): heard.append({"key":key}))
	var guard: Dictionary=game._record("guard_monk")
	var core: Dictionary=game._record("tangseng")
	var wolf: Dictionary=game._record("E1")
	sound.hit_event(guard.node,true,false,event_for(wolf,guard,777),1.0)
	check(heard.is_empty(),"selected attacks suppress the replaced material layer")
	sound.hit_event(core.node,true,true,event_for(wolf,core,778),1.0)
	check(cues_for(heard,"tangseng_hurt_warning").size()==1,"existing core damage warning remains")
	sound.hit_event(guard.node,true,false,event_for(core,guard,779),1.0)
	check(not heard.any(func(row): return row.key.begins_with("shared_hit_")),"unselected core attack does not restore disabled material layer")
	for key in ["ui","victory","rat_death","boar_death","wolf_death","bear_lord_death"]: check(not sound.streams.has(key),"removed result/UI/death assets stay unloaded "+key)
	check(not sound.streams.has("guard_monk_death"),"deferred hero death cue is not newly enabled")
	check(sound.rejected_keys.is_empty(),"warning-only fixture makes zero disabled event requests")
	cases.append({"case":"retained_warning_no_material_result_or_death","heard":heard})
	game.free()

func cancelled_projectile(source_dies: bool) -> void:
	var ctx:=fixture("rat")
	var game=ctx.game
	while ctx.launched.is_empty() and game.elapsed<1 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(ctx.launched.size()==1 and cues_for(ctx.heard,"rat_attack").is_empty(),"real cancellable rat missile launches without a main sound")
	if not ctx.launched.is_empty():
		var event: Dictionary=ctx.launched[0]
		var killed: Dictionary=ctx.source if source_dies else ctx.target
		killed.node.take_damage(killed.hp_max)
		game._tick(Config.STEP)
		check(game.combat.missiles.is_empty() and ctx.applied.is_empty() and cues_for(ctx.heard,"rat_attack").is_empty(),"actual dead source/target cancels missile without hit sound")
		if source_dies:
			game.audio_feedback.released(event)
			game.audio_feedback.role_applied(event,1)
			check(cues_for(ctx.heard,"rat_attack").is_empty(),"stale dead-source callbacks cannot resurrect a primary sound")
	cases.append({"case":"real_projectile_source_death" if source_dies else "real_projectile_target_death","applied_count":ctx.applied.size(),"primary_count":cues_for(ctx.heard,"rat_attack").size()})
	game.free()

func lethal_melee() -> void:
	var ctx:=fixture("guard_monk")
	var game=ctx.game
	ctx.target.node.take_damage(ctx.target.hp_max-5) # HP setup; original attack stats remain.
	game._attack(ctx.source,ctx.target)
	while ctx.applied.is_empty() and game.elapsed<1 and game.phase==game.Phase.BATTLE: game.step(Config.STEP)
	check(ctx.applied.size()==1 and game._hp(ctx.target)==0 and game.metrics.damage.get(ctx.source.id,0)==5,"actual original14 melee clamps to five remaining HP")
	check(cues_for(ctx.heard,"guard_monk_attack").size()==1,"lethal positive damage still plays exactly one main sound")
	cases.append({"case":"real_lethal_melee","actual_damage":game.metrics.damage.get(ctx.source.id,0),"primary_count":cues_for(ctx.heard,"guard_monk_attack").size()})
	game.free()

func same_value(a, b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<0.000000001
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same_value(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not same_value(a[index],b[index]): return false
		return true
	return a==b
func natural(formation: String, fps: int, sim_speed: int, pause_once: bool) -> Dictionary:
	var game=fresh()
	if formation=="R":
		var cells: Array=[Vector2i(2,4),Vector2i(5,4),Vector2i(4,3),Vector2i(4,5),Vector2i(3,4),Vector2i(4,4)]
		game.deployment.clear()
		for index in Config.FRIENDS.size(): game.deployment[Config.FRIENDS[index]]=cells[index]-Vector2i.ONE
		game._reset_roster()
	else: game.load_formation(formation)
	check(game.start_battle(),"audio natural starts unchanged actual bear "+formation)
	game.speed=sim_speed
	var did_pause := false
	while game.phase==game.Phase.BATTLE and game.elapsed<60:
		game.step(1.0/fps)
		if pause_once and not did_pause and game.elapsed>=1:
			game.toggle_pause()
			var report: Dictionary=game.report().duplicate(true)
			var count: int=game.audio_feedback.audit.size()
			game.step(5)
			check(game.report()==report and count==game.audio_feedback.audit.size(),"actual paused audio natural advances no combat or semantic callbacks")
			game.toggle_pause()
			did_pause=true
	check(game.phase==game.Phase.RESULT and game.result_count==1,"audio natural finishes once "+formation)
	check(game.audio_feedback.rejected_keys.is_empty(),"actual natural deaths/results issue zero disabled requests "+formation)
	check(game.audio_feedback.voices.all(func(player): return is_equal_approx(player.pitch_scale,1.0)),"all natural scheduled audio voices retain pitch1 at normal/2x speed")
	var result := {"formation":formation,"fps":fps,"speed":sim_speed,"report":game.report().duplicate(true),"audio_stats":game.audio_feedback.stats.duplicate(true),"semantic_audit_rows":game.audio_feedback.audit.size()}
	game.free()
	return result

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="): baseline_path=argument.trim_prefix("--baseline=")
		elif argument.begins_with("--output="): output_path=argument.trim_prefix("--output=")
		elif argument=="--skip-natural": skip_natural=true
	if baseline_path.is_empty(): baseline_path="res://tests/board-trial-runtime/board-balance-20261009-natural.json"
	verify_assets()
	for role in EXPECTED: real_single(role)
	delayed_serial_and_duplicates()
	distinct_instances(false)
	distinct_instances(true)
	no_effect_and_splash()
	lifecycle_scheduler()
	preserved_secondary_cues()
	cancelled_projectile(true)
	cancelled_projectile(false)
	lethal_melee()
	check(assets.size()==9 and cases.size()==19,"all nine unique assets and nineteen audio semantic/runtime cases executed")
	var reference=null if skip_natural else JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	if not skip_natural: check(reference is Dictionary,"existing balanced bear full-report baseline loads")
	if not skip_natural and reference is Dictionary:
		for formation in ["A","R"]:
			var expected: Array=reference.cases.filter(func(row): return row.profile=="bear" and row.formation==formation)
			check(expected.size()==1,"unique existing bear baseline exists "+formation)
			var first:=natural(formation,30,1,false)
			var second:=natural(formation,120,2,true)
			check(expected.size()==1 and same_value(first.report,expected[0].report) and same_value(second.report,expected[0].report),"selected audio does not change any full original gameplay report "+formation)
			naturals.append(first)
			naturals.append(second)
	check(naturals.size()==(0 if skip_natural else 4),"requested natural-run scope completed without an early-success exit")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	check(file!=null,"standalone audio evidence output opens")
	if file!=null: file.store_string(JSON.stringify({"profile":"board-selected-noncommercial-20261010","headless_is_scheduling_not_listening":true,"asset_count":assets.size(),"assets":assets,"semantic_case_count":cases.size(),"cases":cases,"natural_count":naturals.size(),"natural_explicitly_skipped":skip_natural,"naturals":naturals,"failures":failures},"\t"))
	print("BOARD_AUDIO assets=",assets.size()," semantic_cases=",cases.size()," natural_runs=",naturals.size()," failures=",failures)
	quit(1 if failures else 0)
