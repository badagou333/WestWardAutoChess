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
	scene._resolve_strikes(0.10)
	check(boss.health == hp and scene.missiles.is_empty(), "Windup before release")
	scene._resolve_strikes(0.03)
	check(boss.health == hp and scene.missiles.size() == 1, "Single missile release")
	scene._resolve_strikes(0.25)
	check(boss.health == hp - fox.damage and scene.missiles.is_empty(), "Damage on projectile arrival")
	# Dead targets cancel in-flight damage safely.
	scene.queue_attack(fox, boss, false); scene._resolve_strikes(0.13)
	boss.take_damage(boss.max_health); scene._resolve_strikes(0.3)
	check(scene.missiles.is_empty(), "No orphan missile")
	# Every actor's five-state contract, including heroes that survive this trial.
	scene.reset_trial()
	for actor in scene.actors:
		actor.move_to(actor.position + Vector2(8, 0)); actor.tick(0.1)
		check(actor.pose == "move", actor.role + " move pose")
		actor.play_attack(); actor.tick(0.02)
		check(actor.pose == "basic_attack", actor.role + " attack pose")
		actor.take_damage(1); actor.tick(0.02)
		check(actor.pose == "hit", actor.role + " hit pose")
		actor.take_damage(actor.max_health); actor.tick(0.46)
		check(actor.pose == "retreat" and actor.visual_alpha > 0, actor.role + " retreat hold/fade")
		actor.tick(0.3)
		check(actor.visual_alpha == 0 and actor.dead, actor.role + " complete fade")
	var result := {"scope": "Isolated art trial using existing board navigation; provisional stats; not formal skills/balance acceptance", "seconds": seconds, "battle_counts": battle_counts, "actual_battle_events": actual_events, "failures": failures}
	var file := FileAccess.open("res://art/reviews/six-role-battle/validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("SIX_ROLE_BATTLE_CHECK: actors=6 seconds=%.2f failures=%d" % [seconds, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
