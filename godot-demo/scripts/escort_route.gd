extends "res://scripts/game.gd"

# Reuses the economy, actors, timed hits and audio from the legacy encounter.
const RouteMap = preload("res://scripts/data/escort_map.gd")
var route_index := 0
var escort_tile := RouteMap.ROUTE[0]
var escort_clock := 0.0
var escort_reason := ""
var orders := {}
var command_note := ""
var note_time := 0.0
var transit = preload("res://scripts/combat/friendly_transit.gd").new(self)
var route_label: Label
var order_label: Label
var pointer_hero = null
var pointer_start := Vector2.ZERO

func _create_background() -> void:
	background = TextureRect.new()
	background.texture = preload("res://scripts/presentation/character_presentation.gd")._texture("res://art/production/escort_map/painted_route_v2/background.png")
	background.size = SCREEN_SIZE
	background.z_index = -1000
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_interface() -> void:
	super._create_interface()
	var guide_back := ColorRect.new()
	guide_back.position = Vector2(8,175)
	guide_back.size = Vector2(282,545)
	guide_back.color = Color(0.06,0.09,0.08,0.80)
	guide_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_back.z_index = 24
	add_child(guide_back)
	for child in get_children():
		if child is Label:
			if child.text == "西游护送 · 四波试玩": child.text = "西游护送 · 行路试炼"
			if "拖" in child.text: child.text = "选中队员 → 点击地块调动"
	route_label = _make_label(Vector2(22,185),Vector2(260,110),23,Color("eddbaf"),25)
	order_label = _make_label(Vector2(22,335),Vector2(260,390),19,Color("d4ddce"),25)
	order_label.text = "行路试炼 · 操作\n\n金线：唐僧行进路线\n红格：下一只敌人入口\n绿格：整备可部署范围\n\n左键选人，再点空格移动\n也可拖向目标格 / 右键下令\n途中可穿队友，落点需空闲\nEsc 取消：先抵达安全落点\n\nP 暂停，可在暂停时下令\n唐僧前格被占才等待让路\n每到营地清敌后可整备"

func _escort_cell() -> Vector2i:
	return escort_tile

func _cell_center(cell: Vector2i) -> Vector2:
	return RouteMap.center(cell)

func _screen_to_cell(pos: Vector2) -> Vector2i:
	return RouteMap.tile_at(pos)

func _valid_cell(cell: Vector2i) -> bool:
	return RouteMap.valid(cell)

func _defense_step_allowed(_current: Vector2i, _next: Vector2i) -> bool:
	return true

func _can_deploy(cell: Vector2i) -> bool:
	return _valid_cell(cell) and cell != escort_tile and _cell_distance(cell,escort_tile) <= 3

func _place_hero_on_board(hero, cell: Vector2i) -> void:
	if not _can_deploy(cell):
		_notice("只能在唐僧周围绿色地块整备；战中可走遍陆地")
		if dragging: _restore_drag_origin(hero)
		return
	super._place_hero_on_board(hero,cell)
	queue_redraw()

func _start_battle() -> void:
	if state != GameState.PREPARING or _deployed_count() == 0:
		super._start_battle()
		return
	orders.clear()
	escort_clock = 0.0
	escort_reason = ""
	command_note = ""
	super._start_battle()

func _begin_wave() -> void:
	spawn_queue.assign(WAVES[wave_index].units)
	spawn_entries.assign(RouteMap.ENTRIES[wave_index])
	spawn_cooldown = RouteMap.WARNING_SECONDS

func _process_wave(delta: float) -> void:
	if intermission > 0:
		intermission = maxf(0,intermission-delta)
		if intermission <= 0: _begin_wave()
		return
	_advance_escort(delta)
	if not spawn_queue.is_empty():
		spawn_cooldown = maxf(0,spawn_cooldown-delta)
		if spawn_cooldown <= 0:
			var cell: Vector2i = spawn_entries[0]
			# Never spawn on an actor (including the source of an in-flight move).
			if not _cell_blocked(cell,null):
				_spawn_enemy(spawn_queue.pop_front(),spawn_entries.pop_front())
				spawn_cooldown = RouteMap.WARNING_SECONDS
		return
	if enemies.is_empty() and route_index == RouteMap.CHECKPOINTS[wave_index] and moving.is_empty() and transit.flights.is_empty():
		if wave_index == WAVES.size()-1: _finish_battle(true)
		else: _enter_wave_preparation()

func _advance_escort(delta: float) -> void:
	escort_reason = "沿金线前进"
	if _is_moving(escort): return
	if route_index >= RouteMap.CHECKPOINTS[wave_index]:
		escort_reason = "已到营地 · 清除剩余敌人"
		return
	var next: Vector2i = RouteMap.ROUTE[route_index+1]
	if _cell_blocked(next,escort):
		escort_reason = "前路被占 · 请调走挡路队员"
		return
	escort_clock += delta
	if escort_clock < RouteMap.STEP_SECONDS: return
	escort_clock = 0.0
	route_index += 1
	escort_tile = next
	moving.append({"node":escort,"from":escort.position,"to":_cell_center(next),"time":0.0,"duration":0.75})

func _command_move(hero, cell: Vector2i) -> bool:
	if state != GameState.BATTLE_RUNNING or not is_instance_valid(hero) or not hero.active_in_battle or hero.battle_dead: return false
	if not _valid_cell(cell) or cell == escort_tile:
		_notice("目标不可通行：请选择陆地空格")
		return false
	if transit.stop_blocked(cell,hero):
		_notice("目标被占用，请先让路；不会交换或瞬移")
		return false
	if transit.path(hero,cell).is_empty():
		_notice("暂时无路可达，请先疏通通道")
		return false
	orders[hero] = cell
	_notice("%s → 金色目标格（到位后驻守）" % hero.display_name)
	return true

func _notice(message: String) -> void:
	command_note = message
	note_time = 3.0
	queue_redraw()

func _process_heroes(delta: float) -> void:
	for hero in heroes:
		if not hero.active_in_battle or hero.battle_dead:
			orders.erase(hero)
			continue
		hero.cooldown = maxf(0,hero.cooldown-delta)
		hero.move_cooldown = maxf(0,hero.move_cooldown-delta)
		if _is_moving(hero) or hero.presentation.pose == "basic_attack": continue
		if orders.has(hero):
			var destination: Vector2i = orders[hero]
			if hero.battle_cell == destination:
				orders.erase(hero)
			else:
				var path: Array[Vector2i] = transit.path(hero,destination)
				if path.size() > 1 and hero.move_cooldown <= 0:
					transit.begin(hero,path)
				# Retain orders during temporary congestion; replan every fixed tick.
				continue
		var healing: bool = hero.unit_type == "herbal_spirit_child"
		var target = _stationary_target(hero,healing)
		if target != null and hero.cooldown <= 0:
			hero.cooldown = hero.effective_interval()
			combat.request(hero,target,healing,hero.unit_type == "foxfire_imp")

func _stationary_target(hero, healing: bool):
	var result = null
	var best := INF
	var candidates: Array = heroes + [escort] if healing else enemies
	for target in candidates:
		if not CombatEvents.alive(target): continue
		if healing and target != escort and not target.active_in_battle: continue
		var cell: Vector2i = escort_tile if target == escort else target.battle_cell
		var distance := _cell_distance(hero.battle_cell,cell)
		if distance > hero.attack_range_cells: continue
		var score: float = target.health / target.max_health if healing else float(distance)
		if healing and score >= 1.0: continue
		if score < best:
			result = target
			best = score
	return result

func _move_enemy_toward_center(enemy) -> void:
	var path := _combat_path(enemy,escort_tile,enemy.attack_range_cells,false)
	if path.is_empty():
		# A sealed choke must draw enemies toward its defenders, not freeze them
		# at a distant entrance because the escort itself has no free approach.
		for hero in heroes:
			if not hero.active_in_battle or hero.battle_dead: continue
			var approach := _combat_path(enemy,hero.battle_cell,1,false)
			if not approach.is_empty() and (path.is_empty() or approach.size() < path.size()): path = approach
	if path.size() > 1:
		enemy.battle_cell = path[1]
		enemy.move_cooldown = enemy.move_interval
		_tween_to_cell(enemy,path[1])

func _apply_combat_event(target, amount: float, healing: bool, event: Dictionary) -> void:
	# An unlaunched melee strike cannot hit a target that moved out of reach.
	# Released missiles still track their target, as in the existing combat system.
	if not event.has("texture") and is_instance_valid(event.source):
		var source_cell: Vector2i = event.source.battle_cell
		var target_cell: Vector2i = escort_tile if target == escort else target.battle_cell
		var reach: int = event.source.attack_range_cells
		if _cell_distance(source_cell,target_cell) > reach: return
	super._apply_combat_event(target,amount,healing,event)

func _enter_wave_preparation() -> void:
	if state != GameState.BATTLE_RUNNING: return
	# Keep the travelled formation; revive casualties on the nearest unoccupied land.
	var used := {escort_tile:true}
	for hero in heroes:
		if hero.board_row >= 0 and not hero.battle_dead: used[hero.battle_cell] = true
	for hero in heroes:
		if hero.board_row < 0: continue
		var cell: Vector2i = hero.battle_cell
		if hero.battle_dead:
			var nearest := 999
			for candidate in RouteMap.cells():
				if used.has(candidate): continue
				var distance := _cell_distance(candidate,escort_tile)
				if distance < nearest:
					nearest = distance
					cell = candidate
			used[cell] = true
		hero.board_row = cell.x
		hero.board_col = cell.y
		hero.home_position = _cell_center(cell)
	orders.clear()
	pointer_hero = null
	super._enter_wave_preparation()
	status_label.text = "营地%d抵达 · +%d金｜整备后继续护送，唐僧血量保留" % [wave_index+1,last_wave_reward]

func _finish_battle(victory: bool) -> void:
	if state != GameState.BATTLE_RUNNING: return
	orders.clear()
	super._finish_battle(victory)
	if victory:
		result_label.text = "护送成功 · A → B\n\n唐僧抵达山门，四段敌人全部击退\n剩余生命 %d / %d\n累计战利品 %d 金（已结算）\n\n不规则地图与实时调度原型\n具体难度、路线与行进速度仍待试玩调整" % [int(escort.health),int(escort.max_health),earned_loot]

func _restart_demo() -> void:
	orders.clear()
	pointer_hero = null
	route_index = 0
	escort_tile = RouteMap.ROUTE[0]
	escort_clock = 0
	transit.clear()
	command_note = ""
	note_time = 0
	super._restart_demo()
	escort.position = _cell_center(escort_tile)

func _is_moving(node) -> bool:
	return transit.flights.has(node) or super._is_moving(node)

func _cell_blocked(cell: Vector2i, mover) -> bool:
	return transit.blocks_enemy(cell) or super._cell_blocked(cell,mover)

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.BATTLE_RUNNING:
		super._unhandled_input(event)
		return
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			orders.erase(selected_hero)
			_clear_selection()
			pointer_hero = null
			_set_shop_open(false)
		else: super._unhandled_input(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_command_move(selected_hero,_screen_to_cell(event.position))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked = _hero_at_position(event.position)
				if clicked != null and clicked.active_in_battle:
					_select_hero(clicked)
					pointer_hero = clicked
					pointer_start = event.position
				else:
					_command_move(selected_hero,_screen_to_cell(event.position))
			elif pointer_hero != null:
				if event.position.distance_to(pointer_start) > 12:
					_command_move(pointer_hero,_screen_to_cell(event.position))
				pointer_hero = null

func _tick(delta: float) -> void:
	if state == GameState.BATTLE_RUNNING: transit.tick(delta)
	super._tick(delta)
	note_time = maxf(0,note_time-delta)
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	# Hover and pending orders stay visible while the simulation is paused.
	queue_redraw()

func _update_ui() -> void:
	super._update_ui()
	if not is_instance_valid(route_label): return
	route_label.text = "A 林口 → B 山门\n行程 %d / %d 格\n%s" % [route_index,RouteMap.ROUTE.size()-1,"营地整备" if state == GameState.PREPARING else escort_reason]
	wave_label.text = "路段 %d / 4" % clampi(wave_index+(2 if state == GameState.PREPARING else 1),1,4)
	if state == GameState.PREPARING:
		start_button.text = "出发 · 第%d段" % (wave_index+2)
		if note_time > 0: status_label.text = command_note
		elif wave_index < 0: status_label.text = "3金币招募队员 → 部署到绿色地块 → 出发护送"
	elif state == GameState.BATTLE_RUNNING:
		start_button.text = "护送进行中"
		if battle_paused: status_label.text = "战术暂停 · 可下达移动令，继续后执行"
		elif note_time > 0: status_label.text = command_note
		elif intermission > 0: status_label.text = "%s · %.1f秒后遭遇｜选中队员，点击空格调动" % [RouteMap.NAMES[wave_index],intermission]
		elif not spawn_queue.is_empty():
			status_label.text = "%s · 红色入口 %.1f秒后出现敌人%s" % [RouteMap.NAMES[wave_index],spawn_cooldown,"（入口被占，等待腾空）" if spawn_cooldown <= 0 else ""]
		else: status_label.text = "%s · %s" % [RouteMap.NAMES[wave_index],escort_reason]
		if orders.has(selected_hero) and not _is_moving(selected_hero) and transit.path(selected_hero,orders[selected_hero]).is_empty():
			status_label.text = "移动路线暂被占用 · 等待让路，或重新指定目标"
	if not is_instance_valid(selected_hero):
		info_label.text = "护送目标\n\n唐僧活着到达 B，并清敌\n\n队员驻守指定格，不自动追敌\n实时调度前排拦截、远程支援\n别把队伍留在出发点\n\n营地可招募 / 合成 / 升人口\n英雄恢复，唐僧血量保留"

func _draw() -> void:
	for cell in RouteMap.cells():
		var tile := RouteMap.rect(cell).grow(-2)
		# Subtle calibrated boundaries identify full playable stones; no painted
		# blockout hides the expanded terrain and no baked route is drawn twice.
		draw_rect(tile,Color(0.95,0.88,0.67,0.13),false,1.0)
		if state == GameState.PREPARING and _can_deploy(cell):
			draw_rect(tile.grow(-3),Color(0.4,0.82,0.5,0.15))
		if is_instance_valid(selected_hero) and selected_hero.board_row >= 0:
			var origin: Vector2i = selected_hero.battle_cell if state == GameState.BATTLE_RUNNING else Vector2i(selected_hero.board_row,selected_hero.board_col)
			if _cell_distance(origin,cell) <= selected_hero.attack_range_cells:
				draw_rect(tile.grow(-5),Color(0.95,0.87,0.55,0.3),false,2)
		if cell == _screen_to_cell(get_global_mouse_position()) and not shop_open:
			draw_rect(tile.grow(-2),Color(0.95,0.94,0.8,0.8),false,2)
	for i in range(RouteMap.ROUTE.size()-1):
		draw_line(_cell_center(RouteMap.ROUTE[i]),_cell_center(RouteMap.ROUTE[i+1]),Color(0.93,0.77,0.39,0.5),4,true)
	for index in [0]+RouteMap.CHECKPOINTS:
		var point := _cell_center(RouteMap.ROUTE[index])
		draw_circle(point,14,Color("d2b570"),false,2,true)
		draw_string(ThemeDB.fallback_font,point+Vector2(-12,36),"A" if index == 0 else ("B" if index == RouteMap.CHECKPOINTS[-1] else str(RouteMap.CHECKPOINTS.find(index)+1)),HORIZONTAL_ALIGNMENT_CENTER,24,22,Color("fff1b6"))
	var warning: Vector2i = Vector2i(-1,-1)
	if state == GameState.PREPARING:
		for cell in RouteMap.ENTRIES[mini(wave_index+1,3)]:
			draw_rect(RouteMap.rect(cell).grow(-9),Color(0.86,0.37,0.25,0.5),false,3)
	elif state == GameState.BATTLE_RUNNING:
		if not spawn_entries.is_empty(): warning = spawn_entries[0]
		elif intermission > 0: warning = RouteMap.ENTRIES[wave_index][0]
	if _valid_cell(warning):
		draw_rect(RouteMap.rect(warning).grow(-5),Color(0.96,0.36,0.24,0.3+0.12*sin(battle_elapsed*7)))
		draw_string(ThemeDB.fallback_font,_cell_center(warning)+Vector2(-10,8),"!",HORIZONTAL_ALIGNMENT_CENTER,20,32,Color("ffe2bd"))
	for hero in orders:
		if not is_instance_valid(hero): continue
		var destination := _cell_center(orders[hero])
		draw_line(hero.position,destination,Color(0.96,0.82,0.38,0.7),2,true)
		draw_arc(destination,22,0,TAU,24,Color("ffe6a0"),3,true)
