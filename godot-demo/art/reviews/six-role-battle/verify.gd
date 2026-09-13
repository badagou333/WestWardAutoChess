extends SceneTree

var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://art/reviews/six-role-battle/battle.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.actors.size() == 6, "Six actors loaded")
	var ticks := 0
	while scene.state == scene.GameState.BATTLE_RUNNING and ticks < 12000:
		scene.step(1.0 / 60)
		ticks += 1
	check(scene.state == scene.GameState.RESULT, "Battle reaches result")
	check(not scene.escort.dead and scene.enemies.is_empty(), "Default trial wins")
	check(scene.counts.projectiles > 0 and scene.counts.heals > 0, "Projectiles and healing occur")
	var actual_events := {}
	for actor in scene.actors:
		actual_events[actor.role] = actor.events.duplicate()
		check(actor.events.basic_attack > 0, actor.role + " attacks in actual trial")
		check(actor.z_index == int(round(actor.position.y + 35)), actor.role + " foot-depth sort")
	var battle_counts: Dictionary = scene.counts.duplicate()
	var seconds: float = scene.elapsed
	# Pause freezes both damage processing and pose time.
	scene.reset_trial()
	var clock: float = scene.actors[0].pose_time
	scene._toggle_pause(); scene.step(1)
	check(scene.elapsed == 0 and scene.actors[0].pose_time == clock, "Pause freezes simulation")
	scene._toggle_pause()
	# Delayed hit and independent missile: no damage at cast time or release.
	var fox = scene.heroes[4]; var boss = scene.enemies[0]
	var hp: float = boss.health
	scene.queue_attack(fox, boss, false)
	check(boss.health == hp, "No immediate damage")
	fox.tick(fox.impact_delay() - 0.02); scene._resolve_strikes(0.1)
	check(boss.health == hp and scene.missiles.is_empty(), "Windup before release")
	fox.tick(0.021); scene._resolve_strikes(0.03)
	check(boss.health == hp and scene.missiles.size() == 1, "Single missile release")
	check(scene.missiles[0].position.distance_to(fox.emission_position()) < 0.01, "Release follows rendered hand transform")
	scene._resolve_strikes(0.25)
	check(boss.health == hp - fox.damage and scene.missiles.is_empty(), "Damage on projectile arrival")
	scene._resolve_strikes(0.25)
	check(boss.health == hp - fox.damage, "Attack resolves once")
	# Dead targets cancel in-flight damage safely.
	scene.queue_attack(fox, boss, false); fox.tick(fox.impact_delay() + 0.01); scene._resolve_strikes(0.01)
	boss.take_damage(boss.max_health); scene._resolve_strikes(0.3)
	check(scene.missiles.is_empty(), "No orphan missile")
	# Presentation contracts, separate from actual encounter coverage.
	scene.reset_trial()
	var sprite_coverage := {}
	for actor in scene.actors:
		if actor.motion_body == null: continue
		check(actor.motion_body.get_width() == actor.motion_manifest.frames.size() * 256 and actor.motion_body.get_height() == 256, actor.role + " motion atlas dimensions")
		var move_frames := {}; var attack_frames := {}
		actor.move_to(actor.position + Vector2(100, 0))
		for sample in 120:
			actor.tick(actor.motion.walk / 120.0)
			if actor.pose == "move" and actor.motion_frame >= 0: move_frames[actor.motion_frame] = true
		actor.tick(0.1); actor.play_attack()
		for sample in 180:
			actor.tick(actor.Motion.duration(actor.motion) / 180.0)
			if actor.pose == "basic_attack" and actor.motion_frame >= 0: attack_frames[actor.motion_frame] = true
			if actor.pose == "basic_attack" and actor.pose_time < actor.impact_delay():
				check(actor.motion_frame != int(actor.motion_manifest.attack.impact), actor.role + " impact image never early")
		check(move_frames.keys().size() == actor.motion_manifest.move.size(), actor.role + " all movement images actually played")
		var expected_attack_frames := 4
		if actor.motion_manifest.has("attack_track"):
			var configured := {}
			for key in actor.motion_manifest.attack_track: configured[int(key.frame)] = true
			expected_attack_frames = configured.size()
		check(attack_frames.keys().size() == expected_attack_frames, actor.role + " all attack images actually played")
		actor.play_attack(); actor.tick(actor.impact_delay())
		check(actor.motion_frame == int(actor.motion_manifest.attack.impact), actor.role + " image matches exact damage release")
		sprite_coverage[actor.role] = {"move":move_frames.keys(),"attack":attack_frames.keys()}
	check(sprite_coverage.size() == 6, "All six roles use added frames")
	check(not sprite_coverage.guard_monk.attack.has(7), "Monk no longer inserts old retract before extended recovery")
	check(not sprite_coverage.wild_hunter.attack.has(7), "Hunter uses continuous new knife recovery")
	check(not sprite_coverage.bear_lord.attack.has(7), "Bear uses continuous new two-handed club recovery")
	for melee in [scene.heroes[0], scene.heroes[1], scene.enemies[0]]:
		for direction in [-1,1]:
			melee.face(melee.position + Vector2(direction * 200,0)); melee.play_attack()
			melee.tick(melee.Motion.duration(melee.motion) - 0.001)
			var last_recovery: int = melee.motion_frame
			var before: Transform2D = melee.visual_transform()
			melee.tick(0.002)
			check(last_recovery == 11 and melee.motion_frame == last_recovery and melee.pose == "idle", melee.role + " recovery ends on identical ready image in both facings")
			check(before.origin.distance_to(melee.visual_transform().origin) < 0.01, melee.role + " body does not jump at return boundary")
			melee.play_attack(); melee.tick(0)
			check(melee.motion_frame == last_recovery, melee.role + " next attack starts on same ready image")
	# New fox hand point is used on both facings, including actor translation and lean.
	var cast_fox = scene.heroes[4]
	for direction in [-1, 1]:
		cast_fox.face(cast_fox.position + Vector2(direction * 200, 0))
		cast_fox.play_attack(); cast_fox.tick(cast_fox.impact_delay())
		var socket: Array = cast_fox.motion_manifest.hand_sockets[4]
		var rendered_origin: Vector2 = cast_fox.position + cast_fox.visual_transform() * Vector2(socket[0] - 128, socket[1] - 226)
		check(rendered_origin.distance_to(cast_fox.emission_position()) < 0.01, "Fox projectile matches annotated palm in facing %d" % direction)
	# Herbal palm sockets replace the old horizontal-staff projectile origin.
	var herbal = scene.heroes[2]
	for direction in [-1, 1]:
		scene.strikes.clear(); scene.missiles.clear()
		var patient = scene.heroes[0]
		patient.health = patient.max_health - 60
		herbal.face(herbal.position + Vector2(direction * 200, 0))
		scene.queue_attack(herbal, patient, true)
		herbal.tick(herbal.impact_delay() - 0.001); scene._resolve_strikes(0)
		check(scene.missiles.is_empty() and patient.health == patient.max_health - 60, "Herbal cannot release or heal during windup")
		herbal.tick(0.0011); scene._resolve_strikes(0)
		var palm: Array = herbal.motion_manifest.hand_sockets[4]
		var origin: Vector2 = herbal.position + herbal.visual_transform() * Vector2(palm[0] - 128, palm[1] - 218)
		check(scene.missiles.size() == 1 and herbal.motion_frame == 4, "Herbal release frame emits one missile")
		if scene.missiles.size() == 1:
			check(scene.missiles[0].position.distance_to(origin) < 0.01, "Herbal missile starts on rendered palm in facing %d" % direction)
		scene._resolve_strikes(0.24)
		check(patient.health == patient.max_health - 60, "Herbal healing waits for arrival")
		scene._resolve_strikes(0.02); scene._resolve_strikes(0.5)
		check(patient.health == patient.max_health - 60 + herbal.damage, "Herbal heals exactly once on arrival")
		herbal.tick(herbal.Motion.duration(herbal.motion) - herbal.pose_time - 0.001)
		check(herbal.motion_frame == 0, "Herbal settles onto ready frame before boundary")
		var before: Transform2D = herbal.visual_transform()
		herbal.tick(0.002)
		check(herbal.pose == "idle" and herbal.motion_frame == 0 and before.origin.distance_to(herbal.visual_transform().origin) < 0.01, "Herbal returns to same planted ready pose")
		herbal.play_attack(); herbal.tick(0)
		check(herbal.motion_frame == 0, "Herbal next cast starts on identical ready pose")
	# Sparrow's independent projectile follows the wing, not an old fixed body-frame origin.
	var sparrow = scene.heroes[3]
	for direction in [-1, 1]:
		scene.strikes.clear(); scene.missiles.clear()
		var target = scene.enemies[0]
		target.health = target.max_health
		sparrow.face(sparrow.position + Vector2(direction * 200, 0))
		scene.queue_attack(sparrow, target, false)
		sparrow.tick(sparrow.impact_delay() - 0.001); scene._resolve_strikes(0)
		check(scene.missiles.is_empty() and target.health == target.max_health, "Sparrow windup cannot release or damage")
		sparrow.tick(0.0011); scene._resolve_strikes(0)
		var tip: Array = sparrow.motion_manifest.emission_sockets[4]
		var origin: Vector2 = sparrow.position + sparrow.visual_transform() * Vector2(tip[0] - 128, tip[1] - 218)
		check(scene.missiles.size() == 1 and sparrow.motion_frame == 4, "Sparrow release frame emits one independent wind blade")
		if scene.missiles.size() == 1:
			check(scene.missiles[0].position.distance_to(origin) < 0.01, "Sparrow missile starts at rendered wing tip in facing %d" % direction)
		scene._resolve_strikes(0.24)
		check(target.health == target.max_health, "Sparrow damage waits for flight arrival")
		scene._resolve_strikes(0.02); scene._resolve_strikes(0.5)
		check(target.health == target.max_health - sparrow.damage, "Sparrow projectile damages once")
		sparrow.tick(sparrow.Motion.duration(sparrow.motion) - sparrow.pose_time - 0.001)
		check(sparrow.motion_frame == 0, "Sparrow completes folding onto ready frame")
		var before: Transform2D = sparrow.visual_transform()
		sparrow.tick(0.002)
		check(sparrow.pose == "idle" and sparrow.motion_frame == 0 and before.origin.distance_to(sparrow.visual_transform().origin) < 0.01, "Sparrow return boundary preserves planted origin")
		sparrow.play_attack(); sparrow.tick(0)
		check(sparrow.motion_frame == 0, "Sparrow next cast starts on identical ready pose")
	scene._toggle_motion_frames()
	for actor in scene.actors:
		check(actor.motion_frame == -1, actor.role + " comparison switch restores original atlas")
	scene.reset_trial()
	check(not scene.motion_frames_enabled and not scene.actors[0].use_motion_frames, "Restart preserves comparison preference")
	scene._toggle_motion_frames(); scene.reset_trial()
	var profiles := {}
	for actor in scene.actors:
		profiles[actor.role] = actor.motion
		var start: Vector2 = actor.position
		actor.move_to(start + Vector2(100, 0)); actor.tick(actor.motion.walk * 0.25)
		check(actor.pose == "move" and actor.visual_transform().origin.y < actor.FOOT.y, actor.role + " step lift")
		actor.tick(actor.motion.walk)
		check(actor.position == start + Vector2(100, 0), actor.role + " exact landing, no accumulated drift")
		actor.face(actor.position + Vector2(200, 0)); actor.play_attack(); actor.tick(0.02)
		check(actor.pose == "basic_attack", actor.role + " attack pose")
		var phase: float = actor.pose_time
		actor.take_damage(1)
		check(actor.pose == "basic_attack" and actor.pose_time == phase, actor.role + " light hit does not restart attack")
		actor.tick(actor.impact_delay())
		check(actor.visual_transform().origin.x > 0, actor.role + " forward release")
		actor.tick(1.0)
		check(actor.pose == "idle" and actor.visual_transform().origin.distance_to(actor.FOOT) < 0.01, actor.role + " recovery returns to planted origin")
		actor.take_damage(1); actor.tick(0.02)
		check(actor.pose == "hit", actor.role + " idle hit pose")
		phase = actor.pose_time; actor.take_damage(1)
		check(actor.pose_time == phase, actor.role + " repeat hit cannot lock recoil")
		actor.take_damage(actor.max_health); actor.tick(0.46)
		check(actor.pose == "retreat" and actor.visual_alpha > 0, actor.role + " retreat hold/fade")
		actor.tick(0.3)
		check(actor.visual_alpha == 0 and actor.dead, actor.role + " complete fade")
	var rate_results := {}
	for rate in [30, 120]:
		scene.reset_trial()
		var iterations := 0
		while scene.state == scene.GameState.BATTLE_RUNNING and iterations < rate * 120:
			scene.step(1.0 / rate)
			iterations += 1
		check(absf(scene.elapsed - seconds) < 0.04, "Stable battle timing at %d FPS" % rate)
		check(scene.counts == battle_counts, "Stable hit/release counts at %d FPS" % rate)
		rate_results[rate] = scene.elapsed
	var result := {"scope": "Isolated art trial using existing board navigation; provisional stats; not formal skills/balance acceptance", "seconds": seconds, "frame_rate_seconds": rate_results, "motion_profiles": profiles, "added_sprite_coverage":sprite_coverage, "battle_counts": battle_counts, "actual_battle_events": actual_events, "failures": failures}
	var file := FileAccess.open("res://art/reviews/six-role-battle/validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("SIX_ROLE_BATTLE_CHECK: actors=6 seconds=%.2f failures=%d" % [seconds, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
