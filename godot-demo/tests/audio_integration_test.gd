extends SceneTree
var heard: Array[String] = []
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var sound = game.audio_feedback
	sound.cue_played.connect(func(key): heard.append(key))
	check(sound.streams.size()==19,"17 adopted cues plus UI and victory")
	var fox_path := "res://audio/candidates/foxfire-dwoboyle-v1/foxfire_A_faithful.wav"
	check(sound.stream_paths.foxfire_imp_attack==fox_path,"Selected A overrides legacy synthesis")
	check(FileAccess.get_sha256(fox_path)=="aa30009e92190a69ec99a404f047b453606a8f6e79e5a0f4fe3de495a900a7db","A source unchanged")
	check(absf(sound.streams.foxfire_imp_attack.get_length()-0.57)<0.001,"A duration loaded")
	check(FileAccess.file_exists("res://CREDITS.md"),"Distribution attribution present")
	for key in sound.stream_paths:
		if key != "foxfire_imp_attack": check(sound.stream_paths[key].begins_with(sound.PACK),"Other role assets unchanged")
	for key in sound.streams:
		check(sound.streams[key]!=null and sound.streams[key].get_length()>0,"Valid PCM: "+key)
	check(not sound.play_cue("guard_monk_retreat") and not sound.play_cue("retreat"),"No hero retreat fallback")
	check(sound.play_cue("rat_attack"),"First attack scheduled")
	check(not sound.play_cue("rat_attack"),"Real-time event throttle")
	sound.stop_all()
	for key in ["guard_monk_attack","wild_hunter_attack","sparrow_spirit_attack","herbal_spirit_child_attack","foxfire_imp_attack","rat_attack","boar_attack","wolf_attack"]:
		check(sound.play_cue(key),"Fill voice pool")
	check(sound.play_cue("tangseng_hurt_warning"),"Warning steals lower-priority voice")
	check(sound.slots.filter(func(s):return s.key=="tangseng_hurt_warning").size()==1,"One warning voice")
	check(not sound.play_cue("shared_hit_fur"),"Low priority cannot steal attack voice")
	sound.set_paused(true)
	check(not sound.play_cue("bear_lord_death"),"Pause gates new sounds")
	sound.enabled = false
	sound.enabled = true
	check(sound.paused and not sound.play_cue("ui"),"Mute toggle cannot unpause audio")
	sound.set_paused(false)
	sound.level = 0
	check(not sound.play_cue("ui"),"Zero volume gates playback")
	sound.level = 0.35
	sound.stop_all()
	for i in [0,3,4]: game._on_shop_pressed(i)
	var monk = game.heroes[0]
	var healer = game.heroes[1]
	var fox = game.heroes[2]
	game._spawn_enemy("boar",Vector2i(1,1))
	var enemy = game.enemies[0]
	sound.stop_all(); heard.clear()
	game.combat.request(monk,enemy)
	check(heard.is_empty(),"No melee sound at windup")
	monk.tick_visual(monk.presentation.impact_delay()+0.001)
	game.combat.tick(0)
	check(heard==["guard_monk_attack"],"Melee sound once at impact without generic doubling")
	sound.stop_all(); heard.clear()
	game.combat.request(fox,enemy)
	fox.tick_visual(fox.presentation.impact_delay()+0.001)
	game.combat.tick(0)
	check(heard==["foxfire_imp_attack"],"Projectile sound at release")
	game.combat.tick(0.26)
	check(heard==["foxfire_imp_attack","shared_hit_armor"],"Material hit on projectile arrival")
	sound.stop_all(); heard.clear()
	monk.health -= 30
	game.combat.request(healer,monk,true)
	healer.tick_visual(healer.presentation.impact_delay()+0.001)
	game.combat.tick(0)
	check(heard.is_empty(),"Healing not sounded at release")
	game.combat.tick(0.26)
	check(heard==["herbal_spirit_child_attack"],"Healing sound at actual delivery")
	sound.stop_all(); heard.clear()
	game._apply_combat_event(enemy,10000,false,{"source_key":"foxfire_imp","texture":null,"splash":false,"healing":false})
	check(heard==["boar_death"],"Lethal projectile: death once, no ordinary hit")
	sound.stop_all(); heard.clear()
	game._apply_combat_event(monk,10000,false,{"source_key":"rat","splash":false,"healing":false})
	check(heard==["rat_attack"],"Lethal hero hit has no retreat sound")
	sound.stop_all(); heard.clear()
	game._apply_combat_event(game.escort,1,false,{"source_key":"rat","splash":false,"healing":false})
	check(heard.has("tangseng_hurt_warning"),"Escort warning on damage")
	for key in ["shared_hit_flesh","shared_hit_fur"]:
		sound.stop_all()
		check(sound.play_cue(key,123),"Shared material available: "+key)
		check(not sound.play_cue("shared_hit_armor",123),"Per-target hit throttle")
	game._restart_demo()
	check(sound.slots.all(func(s):return s.until==0) and not sound.paused,"Restart stops all audio")
	game.free()
	print("AUDIO_INTEGRATION: failures=",failures," (scheduling only when headless)")
	quit(1 if failures else 0)
