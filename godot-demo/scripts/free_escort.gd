extends "res://scripts/game.gd"
## Opt-in continuous-space experiment; legacy scenes do not use this controller.
const Map = preload("res://scripts/data/escort_map.gd")
const Rules = preload("res://scripts/data/free_escort_rules.gd")
var space = preload("res://scripts/combat/continuous_space.gd").new()
var brains := {}
var enemy_motion := {}
var route_index := 0
var escort_reason := ""
var command_note := ""
var note_time := 0.0
var route_label: Label
var order_label: Label
var pointer_hero = null
var pointer_start := Vector2.ZERO
var pointer_was_selected := false
var manual_completions := 0
var auto_engagements := 0
var debug_navigation := false # QA-only coast overlay, never an actor grid.

func _create_background() -> void:
	super._create_background()
	background.texture = preload("res://art/production/escort_map/natural_ground_v1/background.png")
	background.z_index = -1000

func _create_escort() -> void:
	super._create_escort()
	escort.position = Map.center(Map.ROUTE[0])

func _cell_center(cell: Vector2i) -> Vector2:
	# Legacy spawn constructor bridge only; continuous movement never calls this.
	return Map.center(cell)

func _create_interface() -> void:
	super._create_interface()
	for child in get_children():
		if child is Label:
			if child.text == "西游护送 · 四波试玩": child.text = "无格子护送 · 试验"
			if "拖" in child.text: child.text = "自动护卫 · 手动移动优先"
	var back := ColorRect.new()
	back.position = Vector2(8,175)
	back.size = Vector2(282,565)
	back.color = Color(0.06,0.09,0.08,0.88)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.z_index = 24
	add_child(back)
	route_label = _make_label(Vector2(22,185),Vector2(260,110),22,Color("eddbaf"),25)
	order_label = _make_label(Vector2(22,305),Vector2(260,420),18,Color("d4ddce"),25)
	order_label.text = "对照试验 · 非最终玩法\n\n地面自由落点，不吸附石块\n无敌：跟随唐僧、分散护卫\n遇敌：近战上前，远程停射\n药灵后侧支援，不追敌\n\n选人点地 / 拖动 / 右键下令\n手动途中不被自动行为抢令\n到达后恢复自动护卫\nEsc 取消移动、恢复自动\n\nP 暂停，可在暂停时下令\n唐僧优先通行友军，不推人\n清敌到营地后整备"
	var switch := _make_button(Vector2(22,755),Vector2(250,46),"切换格子版（重新开局）",Color("697758"),25)
	switch.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/escort_route.tscn"))

func _new_brain() -> Dictionary:
	return {"mode":"跟随", "target":null, "goal":Vector2.ZERO, "path":PackedVector2Array(),
		"repath":0.0, "think":0.0, "follow_clock":0.0, "blocked":0.0, "chase":0.0, "return_until":0.0, "skip":{}, "moving":false}

func _brain(hero) -> Dictionary:
	if not brains.has(hero): brains[hero] = _new_brain()
	return brains[hero]

func _notice(message: String) -> void:
	command_note = message
	note_time = 3.0
	status_label.text = message

func _range(actor) -> float:
	return float(actor.attack_range_cells)*Rules.RANGE_UNIT

func _opponents(actor) -> Array:
	var result: Array = []
	if actor == escort or actor in heroes:
		for enemy in enemies:
			if CombatEvents.alive(enemy): result.append(enemy.position)
	else:
		if CombatEvents.alive(escort): result.append(escort.position)
		for hero in heroes:
			if hero.active_in_battle and not hero.battle_dead: result.append(hero.position)
	return result

func _stop_free(point: Vector2, actor) -> bool:
	if not space.valid(point): return false
	if actor != escort and point.distance_to(escort.position) < Rules.STOP_GAP: return false
	for hero in heroes:
		if hero == actor or hero.board_row < 0 or hero.battle_dead: continue
		if point.distance_to(hero.position) < Rules.STOP_GAP: return false
		if brains.has(hero) and brains[hero].mode == "手动" and point.distance_to(brains[hero].goal) < Rules.STOP_GAP: return false
	for enemy in enemies:
		if enemy != actor and CombatEvents.alive(enemy) and point.distance_to(enemy.position) < Rules.STOP_GAP: return false
	return true

func _near_free(wanted: Vector2, actor, maximum := 150.0) -> Vector2:
	if _stop_free(wanted,actor): return wanted
	for ring in range(1,int(maximum/20)+1):
		for i in range(16):
			var point := wanted+Vector2.from_angle(i*TAU/16)*ring*20.0
			if _stop_free(point,actor): return point
	return Vector2.INF

func _heading() -> Vector2:
	if route_index < Map.ROUTE.size()-1:
		return (Map.center(Map.ROUTE[route_index+1])-escort.position).normalized()
	return Vector2.DOWN

func _guard_goal(hero) -> Vector2:
	var heading := _heading()
	var index := heroes.find(hero)
	var offset: Vector2
	if hero.unit_type == "herbal_spirit_child":
		offset = -heading*Rules.GUARD_RADIUS+heading.orthogonal()*36.0
	else:
		# Alternating shoulders; deeper ranks when population grows.
		var side := 1.0 if index%2 == 0 else -1.0
		offset = heading.orthogonal()*side*(48.0+20.0*(index/2))+heading*(38.0-24.0*(index/2))
	return _near_free(escort.position+offset,hero)

func _place_free(hero, point: Vector2) -> bool:
	if state != GameState.PREPARING or not is_instance_valid(hero): return false
	if point.distance_to(escort.position) > Rules.DEPLOY_RADIUS or not _stop_free(point,hero):
		_notice("无法部署：选择唐僧附近陆地，并与队员留出间距")
		return false
	if space.path(escort.position,point).is_empty():
		_notice("无法部署：该位置不可达")
		return false
	if hero.board_row < 0 and _deployed_count() >= population:
		_notice("人口已满，请先升级人口")
		return false
	# board_row is ONLY a roster/deployed flag in this scene, never navigation.
	hero.board_row = 0
	hero.board_col = heroes.find(hero)
	hero.bench_slot = -1
	hero.position = point
	hero.home_position = point
	hero.set_bench_mode(false)
	queue_redraw()
	return true

func _begin_pointer_action(pos: Vector2) -> void:
	var clicked = _hero_at_position(pos)
	if clicked != null:
		_select_hero(clicked)
		dragged_hero = clicked
		press_position = pos
		drag_origin = {"row":clicked.board_row,"col":clicked.board_col,"bench":clicked.bench_slot,"position":clicked.position,"z":clicked.z_index}
	elif is_instance_valid(selected_hero): _place_free(selected_hero,pos)

func _end_pointer_action(pos: Vector2) -> void:
	if not is_instance_valid(dragged_hero): return
	if dragging:
		var slot := _bench_slot_at(pos)
		if slot >= 0: _place_hero_on_bench(dragged_hero,slot)
		elif not _place_free(dragged_hero,pos): _restore_drag_origin(dragged_hero)
	dragged_hero.dragging = false
	dragging = false
	dragged_hero = null
	queue_redraw()

func _command_free(hero, point: Vector2) -> bool:
	if state != GameState.BATTLE_RUNNING or not is_instance_valid(hero) or not hero.active_in_battle or hero.battle_dead: return false
	if not _stop_free(point,hero):
		_notice("目标无效或落点过挤 · 保留原任务")
		return false
	var route: PackedVector2Array = space.path(hero.position,point,_opponents(hero))
	if route.is_empty():
		_notice("目标当前无路可达 · 保留原任务")
		return false
	var brain := _brain(hero)
	brain.mode = "手动"
	brain.target = null
	brain.goal = point
	brain.path = route
	brain.blocked = 0.0
	brain.repath = Rules.REPATH_SECONDS
	# Cancel unreleased actions immediately; already released missiles keep flying.
	hero.presentation.reset_visual()
	combat.strikes = combat.strikes.filter(func(strike): return strike.source != hero)
	_notice("%s：手动移动优先" % hero.display_name)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.BATTLE_RUNNING:
		super._unhandled_input(event)
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if is_instance_valid(selected_hero):
				brains[selected_hero] = _new_brain()
				_notice("已取消 · 自动护卫")
			pointer_hero = null
			pointer_was_selected = false
		else: super._unhandled_input(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_command_free(selected_hero,event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_hero = null
				pointer_was_selected = false
				var clicked = _hero_at_position(event.position)
				if clicked != null and clicked.active_in_battle:
					pointer_was_selected = clicked == selected_hero
					_select_hero(clicked)
					pointer_hero = clicked
					pointer_start = event.position
				else: _command_free(selected_hero,event.position)
			elif is_instance_valid(pointer_hero):
				# Defer a repeated selection until release, so its tall hitbox
				# cannot swallow ground clicks or issue a premature drag command.
				# A different hero remains selection-only unless actually dragged.
				if event.position.distance_to(pointer_start) > 12 or pointer_was_selected:
					_command_free(pointer_hero,event.position)
				pointer_hero = null
				pointer_was_selected = false

func _start_battle() -> void:
	if state == GameState.PREPARING and _deployed_count() > 0:
		brains.clear()
		enemy_motion.clear()
		command_note = ""
		note_time = 0
	super._start_battle()

func _begin_wave() -> void:
	spawn_queue.assign(WAVES[wave_index].units)
	spawn_entries.assign(Map.ENTRIES[wave_index])
	spawn_cooldown = Map.WARNING_SECONDS

func _process_wave(delta: float) -> void:
	if intermission > 0:
		intermission = maxf(0,intermission-delta)
		if intermission <= 0: _begin_wave()
		return
	_advance_free_escort(delta)
	if not spawn_queue.is_empty():
		spawn_cooldown = maxf(0,spawn_cooldown-delta)
		if spawn_cooldown <= 0:
			var point := _near_free(Map.center(spawn_entries[0]),null,100)
			if point != Vector2.INF:
				_spawn_enemy(spawn_queue.pop_front(),spawn_entries.pop_front())
				enemies[-1].position = point
				spawn_cooldown = Map.WARNING_SECONDS
		return
	if enemies.is_empty() and route_index == Map.CHECKPOINTS[wave_index]:
		if wave_index == WAVES.size()-1: _finish_battle(true)
		else: _enter_wave_preparation()

func _advance_free_escort(delta: float) -> void:
	if route_index >= Map.CHECKPOINTS[wave_index]:
		escort_reason = "已到营地 · 等待清除全部威胁"
		return
	var destination := Map.center(Map.ROUTE[route_index+1])
	var next: Vector2 = escort.position.move_toward(destination,Rules.ESCORT_SPEED*delta)
	# Friendly transit has escort priority. It never pushes/teleports a hero or
	# replaces a manual order. Enemy bodies and terrain still block the escort.
	if not space.clear(escort.position,next,_opponents(escort)):
		escort_reason = "敌人挡路 · 护卫接战"
		return
	escort.position = next
	escort_reason = "持续慢速前进"
	if escort.position.distance_to(destination) < 0.01: route_index += 1

func _travel(actor, brain: Dictionary, destination: Vector2, delta: float, exact := false) -> bool:
	brain.moving = false
	if destination == Vector2.INF:
		brain.blocked += delta
		return false
	var distance: float = actor.position.distance_to(destination)
	if distance < (0.1 if exact else 6.0):
		if _stop_free(destination,actor): return true
		brain.blocked += delta
		return false
	brain.repath -= delta
	if brain.repath <= 0 or brain.goal.distance_to(destination) > 20:
		brain.goal = destination
		brain.path = space.path(actor.position,destination,_opponents(actor))
		brain.repath = Rules.REPATH_SECONDS
	if brain.path.is_empty():
		brain.blocked += delta
		return false
	var waypoint: Vector2 = brain.path[0]
	var next: Vector2 = actor.position.move_toward(waypoint,Rules.RANGE_UNIT/actor.move_interval*delta)
	if not space.clear(actor.position,next,_opponents(actor)) or (next.distance_to(destination) < Rules.STOP_GAP and not _stop_free(destination,actor)):
		brain.blocked += delta
		return false
	actor.position = next
	actor.presentation.face(waypoint-next)
	# Restart a walk cycle only when the previous one expires; not every tick.
	if actor.presentation.move_left <= 0: actor.presentation.move_to(Vector2.ZERO)
	brain.moving = true
	brain.blocked = 0.0
	if next.distance_to(waypoint) < 0.01: brain.path.remove_at(0)
	return actor.position.distance_to(destination) < (0.1 if exact else 6.0)

func _attack_point(actor, target) -> Vector2:
	var reach := _range(actor)*0.88
	var direction: Vector2 = (actor.position-target.position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.LEFT
	for rotation in [0.0,0.45,-0.45,0.9,-0.9,1.6,-1.6,PI]:
		var point: Vector2 = target.position+direction.rotated(rotation)*reach
		if _stop_free(point,actor) and space.clear(point,target.position): return point
	return Vector2.INF

func _in_range(actor, target) -> bool:
	return actor.position.distance_to(target.position) <= _range(actor) and space.clear(actor.position,target.position)

func _return_to_guard(brain: Dictionary) -> void:
	if is_instance_valid(brain.target): brain.skip[brain.target.get_instance_id()] = battle_elapsed+Rules.RETRY_SECONDS
	brain.mode = "归队"
	brain.target = null
	brain.path = PackedVector2Array()
	brain.repath = 0.0
	brain.blocked = 0.0
	brain.return_until = battle_elapsed+1.0

func _acquire(hero, brain: Dictionary) -> void:
	var candidates := enemies.filter(func(enemy): return CombatEvents.alive(enemy))
	candidates.sort_custom(func(a,b): return hero.position.distance_squared_to(a.position) < hero.position.distance_squared_to(b.position))
	for enemy in candidates:
		if brain.skip.get(enemy.get_instance_id(),0.0) > battle_elapsed: continue
		if hero.position.distance_to(enemy.position) > Rules.AGGRO_RADIUS or enemy.position.distance_to(escort.position) > Rules.LEASH_RADIUS: continue
		var destination := _attack_point(hero,enemy)
		if _in_range(hero,enemy) or (destination != Vector2.INF and not space.path(hero.position,destination,_opponents(hero)).is_empty()):
			brain.target = enemy
			brain.mode = "接战"
			brain.chase = 0.0
			brain.repath = 0.0
			brain.blocked = 0.0
			auto_engagements += 1
			return

func _process_heroes(delta: float) -> void:
	for hero in heroes:
		if not hero.active_in_battle or hero.battle_dead:
			brains.erase(hero)
			continue
		var brain := _brain(hero)
		brain.moving = false
		hero.cooldown = maxf(0,hero.cooldown-delta)
		if brain.mode == "手动":
			if _travel(hero,brain,brain.goal,delta,true):
				brains[hero] = _new_brain()
				manual_completions += 1
				_notice("%s：已到达·自动护卫" % hero.display_name)
			elif brain.blocked >= Rules.UNREACHABLE_SECONDS:
				brains[hero] = _new_brain()
				_notice("%s：无法抵达·自动护卫" % hero.display_name)
			continue
		brain.think -= delta
		brain.follow_clock -= delta
		if brain.mode == "归队" and hero.position.distance_to(escort.position) <= Rules.RETURN_RADIUS and battle_elapsed >= brain.return_until:
			brain.mode = "跟随"
		if hero.unit_type != "herbal_spirit_child":
			if brain.mode == "接战":
				brain.chase += delta
				if not CombatEvents.alive(brain.target) or brain.chase > Rules.CHASE_SECONDS or hero.position.distance_to(escort.position) > Rules.LEASH_RADIUS or brain.target.position.distance_to(escort.position) > Rules.LEASH_RADIUS or brain.blocked > Rules.UNREACHABLE_SECONDS:
					_return_to_guard(brain)
			if brain.mode == "跟随" and brain.think <= 0:
				brain.think = 0.4
				_acquire(hero,brain)
		if brain.mode == "接战":
			var target = brain.target
			if _in_range(hero,target):
				if not _stop_free(hero.position,hero):
					_travel(hero,brain,_near_free(hero.position,hero,80),delta)
					continue
				brain.blocked = 0.0
				if hero.cooldown <= 0 and hero.presentation.pose != "basic_attack":
					hero.cooldown = hero.effective_interval()
					combat.request(hero,target,false,hero.unit_type == "foxfire_imp")
			elif hero.presentation.pose != "basic_attack": _travel(hero,brain,_attack_point(hero,target),delta)
			continue
		if hero.unit_type == "herbal_spirit_child":
			var target = _support_target(hero)
			if target != null and hero.cooldown <= 0 and hero.presentation.pose != "basic_attack":
				hero.cooldown = hero.effective_interval()
				combat.request(hero,target,true)
		if hero.presentation.pose != "basic_attack":
			# Follow goals are refreshed at most twice per second, not every pixel.
			if brain.follow_clock <= 0 or not brain.has("follow_goal"):
				brain.follow_goal = _guard_goal(hero)
				brain.follow_clock = 0.5
			_travel(hero,brain,brain.follow_goal,delta)

func _support_target(hero):
	var result = null
	var ratio := 1.0
	for ally in heroes+[escort]:
		if not CombatEvents.alive(ally) or (ally != escort and not ally.active_in_battle): continue
		if not _in_range(hero,ally): continue
		var health_ratio: float = ally.health/ally.max_health
		if health_ratio < ratio:
			ratio = health_ratio
			result = ally
	return result

func _process_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.dead: continue
		enemy.attack_cooldown = maxf(0,enemy.attack_cooldown-delta)
		if not enemy_motion.has(enemy): enemy_motion[enemy] = _new_brain()
		var brain: Dictionary = enemy_motion[enemy]
		brain.moving = false
		var target = null
		var nearest := INF
		for hero in heroes:
			if not hero.active_in_battle or hero.battle_dead: continue
			var distance: float = hero.position.distance_to(enemy.position)
			if distance < nearest and distance <= Rules.RANGE_UNIT and _in_range(enemy,hero):
				nearest = distance
				target = hero
		if target == null and _in_range(enemy,escort): target = escort
		if target == null:
			for hero in heroes:
				if hero.active_in_battle and not hero.battle_dead and _in_range(enemy,hero):
					target = hero
					break
		if target != null:
			if enemy.attack_cooldown <= 0 and enemy.presentation.pose != "basic_attack":
				enemy.attack_cooldown = enemy.attack_interval
				combat.request(enemy,target)
		elif enemy.presentation.pose != "basic_attack":
			var destination := _attack_point(enemy,escort)
			if brain.blocked > 0.8:
				var candidates := heroes.filter(func(hero): return hero.active_in_battle and not hero.battle_dead)
				candidates.sort_custom(func(a,b): return enemy.position.distance_squared_to(a.position)<enemy.position.distance_squared_to(b.position))
				if not candidates.is_empty(): destination = _attack_point(enemy,candidates[0])
			_travel(enemy,brain,destination,delta)

func _apply_combat_event(target, amount: float, healing: bool, event: Dictionary) -> void:
	if not event.has("texture") and is_instance_valid(event.source) and not _in_range(event.source,target): return
	audio_feedback.resolved_attack(event)
	if healing:
		target.heal(amount)
		_float_text(target.position+Vector2(0,-130),"+%d" % int(amount),Color("75eba3"))
	else:
		var targets: Array = [target]
		if event.splash:
			for enemy in enemies:
				if enemy != target and CombatEvents.alive(enemy) and target.position.distance_to(enemy.position) <= Rules.RANGE_UNIT and space.clear(target.position,enemy.position): targets.append(enemy)
		for recipient in targets:
			recipient.take_damage(amount)
			audio_feedback.hit(recipient,event.has("texture"),recipient == escort)
			_float_text(recipient.position+Vector2(0,-130),str(int(amount)),Color("ffd28a"))

func _enter_wave_preparation() -> void:
	if state != GameState.BATTLE_RUNNING: return
	brains.clear()
	enemy_motion.clear()
	for hero in heroes:
		if hero.board_row < 0: continue
		if hero.battle_dead:
			var revive := _near_free(escort.position,hero,200)
			if revive != Vector2.INF: hero.position = revive
			hero.battle_dead = false
		hero.home_position = hero.position
	pointer_hero = null
	pointer_was_selected = false
	super._enter_wave_preparation()
	_notice("营地抵达 · +%d金｜可购买、合成、升级与自由部署" % last_wave_reward)

func _finish_battle(victory: bool) -> void:
	if state != GameState.BATTLE_RUNNING: return
	brains.clear()
	enemy_motion.clear()
	pointer_hero = null
	pointer_was_selected = false
	super._finish_battle(victory)
	result_label.text += "\n无格子半自动试验 · 非最终平衡"

func _restart_demo() -> void:
	brains.clear()
	enemy_motion.clear()
	route_index = 0
	pointer_hero = null
	pointer_was_selected = false
	manual_completions = 0
	auto_engagements = 0
	command_note = ""
	note_time = 0
	super._restart_demo()
	escort.position = Map.center(Map.ROUTE[0])

func _tick(delta: float) -> void:
	super._tick(delta)
	note_time = maxf(0,note_time-delta)
	queue_redraw()

func _update_ui() -> void:
	super._update_ui()
	if not is_instance_valid(route_label): return
	if is_instance_valid(selected_hero):
		info_label.text = info_label.text.replace("攻击距离  %d格" % selected_hero.attack_range_cells,"攻击距离  %.0f像素（试验）" % _range(selected_hero))
	route_label.text = "A 林口 → B 山门\n无格子 · 半自动试验\n%s" % ("营地整备" if state == GameState.PREPARING else escort_reason)
	wave_label.text = "路段 %d / 4" % clampi(wave_index+(2 if state == GameState.PREPARING else 1),1,4)
	if state == GameState.PREPARING:
		start_button.text = "出发 · 第%d段" % (wave_index+2)
		status_label.text = command_note if note_time > 0 else "招募后部署在唐僧附近陆地 · 落点自由，需保持间距"
	elif state == GameState.BATTLE_RUNNING:
		start_button.text = "自动护卫中"
		status_label.text = "战术暂停 · 可下令，继续后执行" if battle_paused else (command_note if note_time > 0 else "自动护卫 / 主动接敌 · 手动移动途中绝不抢令")
	if state == GameState.BATTLE_RUNNING and is_instance_valid(selected_hero) and selected_hero.active_in_battle and not selected_hero.battle_dead:
		var brain := _brain(selected_hero)
		info_label.text = "%s\n\n当前：%s\n生命 %d / %d\n射程 %.0f 像素\n\n点击陆地：手动优先\n到达：恢复自动护卫\nEsc：取消并恢复自动\n\n绿：跟随 / 蓝：归队\n红：接战 / 金：手动\n\n距离与速度均为试验参数" % [selected_hero.display_name,brain.mode,int(selected_hero.health),int(selected_hero.max_health),_range(selected_hero)]
	elif not is_instance_valid(selected_hero):
		info_label.text = "无格子半自动 · 试验\n\n唐僧活着到达 B，清除威胁\n近战上前，远程到射程停步\n药灵留在队伍后侧\n追击超时 / 超界会归队\n\n手动指令始终优先\n到达后自动恢复护卫\n\n营地可招募 / 合成 / 升人口\n英雄恢复，唐僧血量保留"

func _draw() -> void:
	if debug_navigation:
		for edge in space.edges: draw_line(edge.a,edge.b,Color("76ffae"),2,true)
	for i in range(Map.ROUTE.size()-1):
		draw_line(Map.center(Map.ROUTE[i]),Map.center(Map.ROUTE[i+1]),Color(0.93,0.77,0.39,0.45),3,true)
	for index in [0]+Map.CHECKPOINTS:
		var point := Map.center(Map.ROUTE[index])
		draw_circle(point,14,Color("d2b570"),false,2,true)
		draw_string(ThemeDB.fallback_font,point+Vector2(-10,35),"A" if index == 0 else ("B" if index == Map.CHECKPOINTS[-1] else str(Map.CHECKPOINTS.find(index)+1)),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("fff1b6"))
	if not spawn_entries.is_empty():
		var warning := Map.center(spawn_entries[0])
		draw_circle(warning,20,Color("e77c5b"),false,3,true)
		draw_string(ThemeDB.fallback_font,warning+Vector2(-6,8),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("ffe2bd"))
	for hero in heroes:
		if hero.board_row < 0 or hero.battle_dead: continue
		var mode := str(brains[hero].mode) if brains.has(hero) else "整备"
		var color: Color = {"跟随":Color("9ed492"),"整备":Color("9ed492"),"归队":Color("90badf"),"接战":Color("ed9375"),"手动":Color("f2d56b")}[mode]
		draw_arc(hero.position,16,0,TAU,24,color,2,true)
		draw_string(ThemeDB.fallback_font,hero.position+Vector2(-18,25),mode,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
		if mode == "手动":
			draw_line(hero.position,brains[hero].goal,color,1.5,true)
			draw_arc(brains[hero].goal,10,0,TAU,20,color,2,true)
	if is_instance_valid(selected_hero) and selected_hero.board_row >= 0:
		draw_arc(selected_hero.position,_range(selected_hero),0,TAU,80,Color(0.95,0.87,0.55,0.25),1,true)
	if not shop_open and state != GameState.RESULT:
		var mouse := get_global_mouse_position()
		if space.valid(mouse): draw_arc(mouse,8,0,TAU,16,Color("f4e7ba"),1.5,true)
