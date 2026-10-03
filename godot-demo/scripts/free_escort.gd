extends "res://scripts/game.gd"
## Opt-in continuous-space experiment; legacy scenes do not use this controller.
const Map = preload("res://scripts/data/escort_map.gd")
const Rules = preload("res://scripts/data/free_escort_rules.gd")
const RosterStyle = preload("res://scripts/presentation/roster_style.gd")
const BenchPortraits = preload("res://scripts/presentation/shop_card.gd")
var space = preload("res://scripts/combat/continuous_space.gd").new()
var brains := {}
var enemy_motion := {}
var route_index := 0
var escort_reason := ""
var command_note := ""
var note_expires_at_msec := 0 # UI wall-clock, independent of pause/battle speed.
var route_label: Label
var order_label: Label
var pointer_hero = null
var pointer_start := Vector2.ZERO
var pointer_was_selected := false
var manual_completions := 0
var auto_engagements := 0
var debug_navigation := false # QA-only coast overlay, never an actor grid.
var guard_anchors := {}
var hero_slots: Array = [] # Stable 1..9,0 slots; holes are reused on deployment only.
var bench_open: bool:
	get: return state != GameState.RESULT # Always visible during preparation/combat.
var roster_hud: Control
var management_back: Panel
var bench_back: Panel
var withdraw_button: Button
var swap_button: Button
var action_hint: Label
var carry_hero = null
var carry_preview: Node2D
var carry_star := 0
var carry_pressed := false
var carry_first_press := false
var carry_dragged := false
var carry_origin := Vector2.ZERO
var carry_mouse := Vector2.ZERO
var camp_positions = preload("res://scripts/data/camp_positions.gd").new()
var swap_source = null
var swap_star := 0

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
			if "拖" in child.text: child.text = "点选拿起 / 拖放 · 三个同名同星自动合成"
	for control in shop_controls:
		if control is Label and "1—3" in control.text:
			control.text = "招募商店     点击购买 · 按钮刷新（2金）· 空格收起"
		elif control is Label and "替补席" in control.text:
			control.text = "招募进入下方后备区\n战斗中仅查看，不可经营"
	for card in shop_buttons: card.show_hotkey = false
	_layout_management()
	var back := ColorRect.new()
	back.position = Vector2(8,175)
	back.size = Vector2(282,565)
	back.color = Color(0.06,0.09,0.08,0.88)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.z_index = 24
	add_child(back)
	route_label = _make_label(Vector2(22,185),Vector2(260,110),22,Color("eddbaf"),25)
	order_label = _make_label(Vector2(22,305),Vector2(260,420),18,Color("d4ddce"),25)
	order_label.text = "驻守试验 · 非最终玩法\n\n英雄不跟随唐僧，附近接敌\n药灵原地治疗，不追伤员\n1—9 / 0 选人 · 右键移动\n右键下令后取消选中\nQ / W / E 技能未配置\nP 暂停，暂停时可下令\n\n整备 R 下场 · F 原位互换\nF后点击场上或后备英雄\n左键放置成功后取消选中\n后备拿起后 · 右键取消\nEsc 取消操作 / 移动指令\n空格 只开关商店 · B停用\n\n关间既有位置只能换人\n新增名额可在唐僧附近落位\n后备常显 · 开战只收起商店"
	var switch := _make_button(Vector2(22,755),Vector2(250,46),"切换格子版（重新开局）",Color("697758"),25)
	switch.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/escort_route.tscn"))

func _layout_management() -> void:
	# Reuse existing shop/bench controls; legacy scenes keep their own layout.
	for child in get_children():
		if child is ColorRect and child.position == Vector2(0,868):
			child.position.y = 908
			child.size.y = 172
		elif child is Label and child.text == "备战操作": child.hide()
	management_back = shop_controls[0]
	for control in shop_controls: control.position.y += 276
	management_back.position.x = 680
	management_back.size = Vector2(924,242)
	management_back.add_theme_stylebox_override("panel",RosterStyle.box())
	shop_controls[1].position.x = 700
	shop_controls[1].size.x = 820
	shop_controls[1].add_theme_font_size_override("font_size",20)
	shop_controls[2].position.x = 1544
	for index in range(shop_buttons.size()):
		shop_buttons[index].position.x = 700+232*index
		shop_buttons[index].size.x = 218
	refresh_button.position.x = 1410
	refresh_button.size.x = 176
	shop_controls.back().position.x = 1400
	shop_controls.back().size.x = 194
	shop_controls.back().add_theme_font_size_override("font_size",15)
	bench_back = Panel.new()
	bench_back.position = Vector2(330,720)
	bench_back.size = Vector2(1280,180)
	bench_back.z_index = 34
	bench_back.add_theme_stylebox_override("panel",RosterStyle.box())
	bench_back.mouse_filter = Control.MOUSE_FILTER_STOP
	bench_back.add_to_group("bench_controls")
	add_child(bench_back)
	bench_back.gui_input.connect(_bench_input)
	for child in get_children():
		if child is Control and child.is_in_group("bench_controls") and child != bench_back:
			child.position.y -= 170
			child.z_index = 36 if child is Label else 35
			if child is Label and child != bench_label and child != tip_label: child.position.y -= 8
	for slot in range(bench_panels.size()):
		var panel = bench_panels[slot]
		for child in get_children():
			if child is Label and child.is_in_group("bench_controls") and child.text == str(slot+1):
				child.hide() # Flat tiles draw their own quiet seat number.
				child.remove_from_group("bench_controls")
		panel.position = Vector2(349+156*slot,739)
		panel.size = Vector2(142,152)
		panel.flat_mode = true
		panel.seat_number = slot+1
	bench_label.position = Vector2(350,724)
	bench_label.size.x = 380
	bench_label.add_theme_font_size_override("font_size",21)
	bench_label.add_theme_color_override("font_color",RosterStyle.INK)
	tip_label.position = Vector2(850,727)
	tip_label.size.x = 720
	tip_label.text = "点选 / 拖放 · 右键取消 · 同星三合一"
	tip_label.add_theme_font_size_override("font_size",18)
	tip_label.add_theme_color_override("font_color",RosterStyle.MUTED)
	shop_toggle.position = Vector2(24,959)
	shop_toggle.size = Vector2(250,62)
	shop_toggle.add_theme_font_size_override("font_size",18)
	level_button.position = Vector2(1640,841)
	level_button.size = Vector2(260,52)
	roster_hud = preload("res://scripts/presentation/roster_hud.gd").new()
	roster_hud.position = Vector2(0,908)
	roster_hud.size = Vector2(1920,172)
	roster_hud.z_index = 29 # Toggle remains above it; the full strip swallows map input.
	roster_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(roster_hud)
	move_child(roster_hud,background.get_index()+1)
	roster_hud.gui_input.connect(_roster_input)
	withdraw_button = _make_button(Vector2(1640,922),Vector2(124,44),"下场 [R]",Color("57513a"),32)
	withdraw_button.pressed.connect(_withdraw_selected)
	swap_button = _make_button(Vector2(1776,922),Vector2(124,44),"互换 [F]",Color("67517c"),32)
	swap_button.toggle_mode = true
	swap_button.pressed.connect(_begin_swap)
	for button in [shop_toggle,level_button,withdraw_button,swap_button]: RosterStyle.button(button)
	action_hint = _make_label(Vector2(1640,975),Vector2(260,48),18,RosterStyle.MUTED,32)

func _bench_position(slot: int) -> Vector2:
	return Vector2(420+156*slot,840)

func _bench_slot_at(pos: Vector2) -> int:
	if not bench_open or pos.y < 760 or pos.y > 896: return -1
	var slot := int(round((pos.x-420)/156))
	return slot if slot >= 0 and slot < BENCH_SIZE and absf(pos.x-_bench_position(slot).x) <= 71 else -1

func _roster_input(event: InputEvent) -> void:
	if state == GameState.RESULT or event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var index := int(floor((event.position.x-300)/130))
	if index < 0 or index >= max_population or event.position.y < 12 or event.position.y > 160: return
	if fmod(event.position.x-300,130) > 124: return
	if is_instance_valid(swap_source):
		var target = _seat_hero(index)
		if target != null: _swap_heroes(target)
	else: _select_number(index)
	roster_hud.accept_event()

func _bench_input(event: InputEvent) -> void:
	# The panel blocks map input. Only the bench subregion routes to inventory.
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return
	if state != GameState.PREPARING: return
	var point: Vector2 = event.position+bench_back.position
	if event.pressed:
		if _bench_slot_at(point) < 0: return
		_begin_pointer_action(point,true)
	elif _bench_slot_at(point) >= 0 or _map_input_allowed(point):
		# GUI mouse capture delivers a bench-origin drag release back here even
		# outside the panel. Forward only exposed map ground, never another UI.
		_end_pointer_action(point)
	bench_back.accept_event()

func _map_input_allowed(point: Vector2) -> bool:
	for control in get_children():
		if control is Control and control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point): return false
	return true

func _update_roster_hud() -> void:
	var values: Array = []
	for index in range(max_population):
		var hero = _seat_hero(index)
		if hero == null:
			values.append({})
			continue
		var mode := "整备" if state == GameState.PREPARING else "驻守"
		if brains.has(hero): mode = brains[hero].mode
		if hero.battle_dead: mode = "阵亡"
		values.append({"unit":hero.unit_type,"name":hero.display_name,"star":hero.star,"status":mode,
			"hp":hero.health,"max_hp":hero.max_health,"dead":hero.battle_dead,"selected":hero == selected_hero})
	roster_hud.present(values)

func _new_brain() -> Dictionary:
	return {"mode":"驻守", "target":null, "goal":Vector2.ZERO, "path":PackedVector2Array(),
		"repath":0.0, "think":0.0, "blocked":0.0, "chase":0.0, "skip":{}, "moving":false}

func _brain(hero) -> Dictionary:
	if not brains.has(hero):
		brains[hero] = _new_brain()
		brains[hero].anchor = guard_anchors.get(hero,hero.position)
		brains[hero].last_legal = hero.position
		if hero.position.distance_to(brains[hero].anchor) >= Rules.RETURN_TOLERANCE: brains[hero].mode = "归位"
	return brains[hero]

func _notice(message: String) -> void:
	command_note = message
	note_expires_at_msec = Time.get_ticks_msec()+3000
	_update_ui()

func _clear_notice() -> void:
	command_note = ""
	note_expires_at_msec = 0

func _toggle_pause() -> void:
	var was_paused := battle_paused
	super._toggle_pause()
	if battle_paused != was_paused:
		_clear_notice()
		_update_ui()

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

func _establish_guard(hero, message: String) -> void:
	var brain := _brain(hero)
	var point: Vector2 = hero.position
	# Cancellation while traversing a friend must never teleport or overlap-stop.
	if not _stop_free(point,hero):
		point = brain.last_legal if _stop_free(brain.last_legal,hero) else _near_free(hero.position,hero)
		if point == Vector2.INF: point = brain.anchor
	guard_anchors[hero] = point
	hero.presentation.reset_visual()
	combat.strikes = combat.strikes.filter(func(strike): return strike.source != hero)
	brains.erase(hero)
	brain = _brain(hero)
	if hero.position.distance_to(point) >= Rules.RETURN_TOLERANCE: brain.mode = "归位"
	_notice("%s：%s" % [hero.display_name,message])

func _assign_hero_slot(hero) -> void:
	if hero in hero_slots: return
	for i in range(hero_slots.size()):
		if not is_instance_valid(hero_slots[i]) or hero_slots[i] not in heroes or hero_slots[i].board_row < 0:
			hero_slots[i] = hero
			return
	if hero_slots.size() < max_population: hero_slots.append(hero)

func _camp_locked() -> bool:
	return state == GameState.PREPARING and wave_index >= 0

func _seat_hero(index: int):
	if index < 0 or index >= hero_slots.size(): return null
	var hero = hero_slots[index]
	return hero if is_instance_valid(hero) and hero in heroes and hero.board_row >= 0 else null

func _deploy_at(hero, point: Vector2, index := -1) -> void:
	# Only called after validation; swap has no fallible step after ownership changes.
	hero.board_row = 0 # Roster flag only, not a grid location.
	hero.board_col = heroes.find(hero)
	hero.bench_slot = -1
	hero.position = point
	hero.home_position = point
	hero.active_in_battle = false
	hero.dragging = false
	hero.presentation.reset_visual()
	hero.set_bench_mode(false)
	hero.visible = true
	guard_anchors[hero] = point
	brains.erase(hero)
	if index >= 0:
		while hero_slots.size() <= index: hero_slots.append(null)
		hero_slots[index] = hero
	else:
		_assign_hero_slot(hero)
	if _camp_locked(): camp_positions.record(hero_slots.find(hero),point)

func _place_free(hero, point: Vector2) -> bool:
	if state != GameState.PREPARING or not is_instance_valid(hero) or hero not in heroes: return false
	var seat := -1
	if _camp_locked():
		if hero.board_row >= 0:
			_notice("关间站位已锁定 · R下场 / F原位互换，开战后再移动")
			return false
		var occupied: Array = camp_positions.points.keys().filter(func(index): return _seat_hero(index) != null)
		seat = camp_positions.at_point(point,occupied)
		if seat >= 0:
			if _seat_hero(seat) != null:
				_notice("原位已有英雄 · 选中场上英雄按F互换")
				return false
			if _deployed_count() >= population: return false
			# This is an exact replacement, not new ground deployment. Preserve
			# even distant end-of-wave seats, including transient friendly overlap.
			_deploy_at(hero,camp_positions.points[seat],seat)
			_notice("%s：已接替原位 [%d]" % [hero.display_name,(seat+1)%10])
			queue_redraw()
			return true
		if not camp_positions.may_add(population):
			_notice("只能填补原位空槽 · 下场不会增加新落位名额")
			return false
		if camp_positions.near_reserved(point,Rules.STOP_GAP):
			_notice("新落点太靠近保留位置 · 请留出间距")
			return false
		seat = camp_positions.next_index(max_population)
	if point.distance_to(escort.position) > Rules.DEPLOY_RADIUS or not _stop_free(point,hero):
		_notice("无法部署：选择唐僧附近陆地，并与队员留出间距")
		return false
	if space.path(escort.position,point).is_empty():
		_notice("无法部署：该位置不可达")
		return false
	if hero.board_row < 0 and _deployed_count() >= population:
		_notice("人口已满，请先升级人口")
		return false
	_deploy_at(hero,point,seat)
	_notice("%s：已部署 · 驻守点已设置" % hero.display_name)
	queue_redraw()
	return true

func _begin_pointer_action(pos: Vector2, bench_only := false) -> void:
	if state != GameState.PREPARING: return
	carry_mouse = pos
	_validate_swap()
	if is_instance_valid(swap_source):
		var incoming = _hero_in_bench(_bench_slot_at(pos)) if bench_only else _hero_at_position(pos)
		if incoming != null: _swap_heroes(incoming)
		else: _notice("请选择另一名场上或后备英雄 · Esc取消")
		return
	if is_instance_valid(carry_hero):
		carry_pressed = true
		carry_first_press = false
		carry_origin = pos
		return
	var clicked = _hero_in_bench(_bench_slot_at(pos)) if bench_only else _hero_at_position(pos)
	if clicked != null:
		_select_hero(clicked)
		if not _camp_locked() or clicked.board_row < 0: _start_carry(clicked,pos)
	elif not bench_only and is_instance_valid(selected_hero) and selected_hero.board_row >= 0:
		if _place_free(selected_hero,pos): _release_control()

func _end_pointer_action(pos: Vector2) -> void:
	if not carry_pressed or not is_instance_valid(carry_hero): return
	var commit := carry_dragged or not carry_first_press
	carry_pressed = false
	if commit:
		if _commit_carry(pos): _release_control()
	elif carry_hero.board_row >= 0:
		# A board hero click only selects it; dragging uses the same transaction.
		_cancel_carry()
	carry_dragged = false
	queue_redraw()

func _start_carry(hero, pos: Vector2) -> void:
	_cancel_carry()
	carry_hero = hero
	carry_star = hero.star
	carry_pressed = true
	carry_first_press = true
	carry_origin = pos
	carry_mouse = pos
	carry_preview = preload("res://scripts/presentation/character_presentation.gd").new()
	carry_preview.setup_visual(hero.unit_type,"nine_sols_v1")
	carry_preview.show_anchor = false
	carry_preview.show_status = false
	carry_preview.foot_anchor = Vector2.ZERO
	carry_preview.modulate.a = 0.65
	carry_preview.z_index = 1900 # Below UI, above world; not an inventory/combat actor.
	carry_preview.position = pos
	add_child(carry_preview)
	carry_preview.visible = hero.board_row < 0

func _cancel_carry() -> void:
	if is_instance_valid(carry_preview):
		carry_preview.visible = false
		carry_preview.queue_free()
	carry_preview = null
	carry_hero = null
	carry_pressed = false
	carry_first_press = false
	carry_dragged = false

func _release_control() -> void:
	# Selection/gestures are independent of accepted combat movement orders.
	_cancel_carry()
	_cancel_swap()
	_release_over_ui()
	_clear_selection()

func _validate_carry() -> void:
	if carry_hero == null: return
	if not is_instance_valid(carry_hero) or carry_hero not in heroes or state != GameState.PREPARING or (not bench_open and carry_hero.board_row < 0) or carry_hero.star != carry_star:
		_cancel_carry()

func _commit_carry(pos: Vector2) -> bool:
	_validate_carry()
	if not is_instance_valid(carry_hero): return false
	var slot := _bench_slot_at(pos) if bench_open else -1
	if slot >= 0:
		if carry_hero.board_row >= 0 and _hero_in_bench(slot) != null:
			_notice("后备位置已占用 · 保留拿起预览")
			return false
		_place_hero_on_bench(carry_hero,slot)
		return true
	return _place_free(carry_hero,pos)

func _place_hero_on_bench(hero, slot: int) -> void:
	if state != GameState.PREPARING or hero not in heroes or slot < 0 or slot >= BENCH_SIZE: return
	if hero.board_row >= 0 and _hero_in_bench(slot) != null: return
	var occupant = _hero_in_bench(slot,hero)
	super._place_hero_on_bench(hero,slot)
	# Bench-to-bench reordering must also persist the exchanged actor's home.
	if occupant != null: occupant.home_position = occupant.position
	hero.active_in_battle = false
	hero.dragging = false
	hero.visible = bench_open
	hero.presentation.reset_visual()
	guard_anchors.erase(hero)
	brains.erase(hero)
	combat.strikes = combat.strikes.filter(func(strike): return strike.source != hero)
	var index := hero_slots.find(hero)
	if index >= 0: hero_slots[index] = null
	if selected_hero == hero: _clear_selection()
	if pointer_hero == hero: _release_over_ui()

func _withdraw_selected() -> void:
	var reason := _roster_action_reason(true)
	if not reason.is_empty():
		_notice(reason)
		return
	var slot := _free_bench_slot()
	var hero = selected_hero
	_cancel_carry()
	_cancel_swap()
	_place_hero_on_bench(hero,slot)
	_notice("%s：已下场 · 原位置保留" % hero.display_name if _camp_locked() else "%s：已下场" % hero.display_name)
	queue_redraw()

func _cancel_swap() -> void:
	swap_source = null
	swap_star = 0
	queue_redraw()

func _validate_swap() -> void:
	if swap_source == null: return
	if not is_instance_valid(swap_source) or swap_source not in heroes or state != GameState.PREPARING or not bench_open or swap_source.board_row < 0 or swap_source.battle_dead or swap_source.star != swap_star:
		_cancel_swap()

func _begin_swap() -> void:
	var reason := _roster_action_reason(false)
	if not reason.is_empty():
		_notice(reason)
		return
	_cancel_carry()
	swap_source = selected_hero
	swap_star = selected_hero.star
	_notice("%s：点击另一名场上或后备英雄互换 · Esc取消" % selected_hero.display_name)

func _roster_action_reason(withdraw: bool) -> String:
	# Keyboard and buttons share authorization and rejection text.
	var action := "下场" if withdraw else "互换"
	if state == GameState.RESULT: return "结算中不能%s · 请重新开局" % action
	if state != GameState.PREPARING: return "战斗中不能%s · 请等待营地整备" % action
	if not is_instance_valid(selected_hero) or selected_hero not in heroes or selected_hero.board_row < 0 or selected_hero.battle_dead:
		return "请先选择场上英雄，再按%s%s" % ["R" if withdraw else "F",action]
	if withdraw and _free_bench_slot() < 0: return "后备已满 · 英雄仍在场上，可按F直接互换"
	return ""

func _update_roster_actions() -> void:
	var retreat_reason := _roster_action_reason(true)
	var exchange_reason := _roster_action_reason(false)
	withdraw_button.disabled = not retreat_reason.is_empty()
	swap_button.disabled = not exchange_reason.is_empty()
	withdraw_button.tooltip_text = retreat_reason if withdraw_button.disabled else "下场 [R]：将选中的场上英雄退到空后备席"
	swap_button.tooltip_text = exchange_reason if swap_button.disabled else "互换 [F]：再点击场上或后备英雄，原位交换；Esc取消。满后备也可互换。"
	swap_button.set_pressed_no_signal(is_instance_valid(swap_source))
	if state != GameState.PREPARING:
		action_hint.text = "战斗中：下场 / 互换不可用\n等待营地 · 后备只读" if state == GameState.BATTLE_RUNNING else "结算中，不能操作\n请重新开局"
	elif is_instance_valid(swap_source):
		action_hint.text = "互换中：点场上 / 后备英雄\nEsc取消 · 原位交换"
	elif not exchange_reason.is_empty():
		action_hint.text = "请先选择场上英雄\nR退后备 · F原位交换"
	elif not retreat_reason.is_empty():
		action_hint.text = "后备已满，不能下场\n仍可F互换 · Esc取消"
	else:
		action_hint.text = "R退后备 · F原位互换\nF后点另一英雄 · Esc取消"

func _swap_heroes(incoming) -> bool:
	_validate_swap()
	if not is_instance_valid(swap_source) or not is_instance_valid(incoming) or incoming not in heroes or incoming.battle_dead: return false
	if incoming == swap_source:
		_cancel_swap()
		_notice("已取消互换 · 请选择另一名英雄")
		return false
	if incoming.board_row < 0: return _swap_with_bench(incoming)
	var outgoing = swap_source
	var first := hero_slots.find(outgoing)
	var second := hero_slots.find(incoming)
	if first < 0 or second < 0: return false
	if _camp_locked() and (not camp_positions.points.has(first) or not camp_positions.points.has(second)): return false
	var point_a: Vector2 = camp_positions.points[first] if _camp_locked() else outgoing.position
	var point_b: Vector2 = camp_positions.points[second] if _camp_locked() else incoming.position
	# All validation precedes this synchronous, non-fallible two-slot commit.
	_release_control()
	_deploy_at(outgoing,point_b,second)
	_deploy_at(incoming,point_a,first)
	combat.strikes = combat.strikes.filter(func(strike): return strike.source != outgoing and strike.source != incoming)
	_notice("已交换原位 · %s ↔ %s" % [outgoing.display_name,incoming.display_name])
	queue_redraw()
	return true

func _swap_with_bench(incoming) -> bool:
	_validate_swap()
	if not is_instance_valid(swap_source) or not is_instance_valid(incoming) or incoming not in heroes or incoming.board_row >= 0 or incoming.battle_dead: return false
	var outgoing = swap_source
	var seat := hero_slots.find(outgoing)
	var slot: int = incoming.bench_slot
	if seat < 0 or slot < 0 or slot >= BENCH_SIZE or _hero_in_bench(slot) != incoming: return false
	if _camp_locked() and not camp_positions.points.has(seat): return false
	var point: Vector2 = camp_positions.points[seat] if _camp_locked() else outgoing.position
	# A full bench is supported: trade the two ownership slots atomically, without
	# invoking shop/merge/sell or any operation that can consume gold or a copy.
	_release_control()
	incoming.bench_slot = -1
	_place_hero_on_bench(outgoing,slot)
	_deploy_at(incoming,point,seat)
	_notice("已原位互换 · %s 上场 / %s 下场" % [incoming.display_name,outgoing.display_name])
	queue_redraw()
	return true

func _set_shop_open(value: bool) -> void:
	super._set_shop_open(value)
	# Shop visibility is independent of the permanent bench and its gestures.
	# Also called by the base interface constructor, before all controls exist.
	if is_instance_valid(route_label): _update_ui()

func _input(event: InputEvent) -> void:
	# Cancel bench pickup before GUI consumption, including over shop/buttons.
	# Clear the gesture too, so a later left release cannot deploy the hero.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and state == GameState.PREPARING and is_instance_valid(carry_hero) and carry_hero.board_row < 0:
		_release_control()
		_notice("已取消拿起 · 英雄保留在后备区")
		get_viewport().set_input_as_handled()
		return
	# Motion/release are observed before GUI consumption, but only unhandled
	# releases may commit. Releasing on a button must never place through UI.
	if event is InputEventMouseMotion:
		carry_mouse = event.position
		if is_instance_valid(carry_preview):
			carry_preview.position = carry_mouse
			if carry_pressed and carry_mouse.distance_to(carry_origin) > 8:
				carry_dragged = true
				carry_preview.visible = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		call_deferred("_release_over_ui")

func _release_over_ui() -> void:
	carry_pressed = false
	carry_dragged = false
	pointer_hero = null
	pointer_was_selected = false

func _select_number(index: int) -> void:
	_cancel_carry()
	_cancel_swap()
	pointer_hero = null
	pointer_was_selected = false
	_clear_selection()
	if index < hero_slots.size():
		var hero = hero_slots[index]
		if is_instance_valid(hero) and hero in heroes and hero.board_row >= 0 and not hero.battle_dead: _select_hero(hero)
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
	if event is InputEventKey:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		if not event.pressed or event.echo or state == GameState.RESULT: return
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			_select_number(9 if event.keycode == KEY_0 else event.keycode-KEY_1)
		elif event.keycode in [KEY_Q,KEY_W,KEY_E]: pass # Reserved, deliberately no gameplay side effects.
		elif event.keycode == KEY_B: pass # Retired; the bench is permanently visible.
		elif event.keycode == KEY_R: _withdraw_selected()
		elif event.keycode == KEY_F: _begin_swap()
		elif event.keycode == KEY_ESCAPE:
			if is_instance_valid(swap_source):
				_cancel_swap()
				_notice("已取消互换")
			elif is_instance_valid(carry_hero): _cancel_carry()
			elif state == GameState.BATTLE_RUNNING and is_instance_valid(selected_hero) and selected_hero.active_in_battle and not selected_hero.battle_dead:
				_establish_guard(selected_hero,"已取消 · 当前合法位置驻守")
			else: _set_shop_open(false)
			pointer_hero = null
			pointer_was_selected = false
		else: super._unhandled_input(event)
		return
	if state == GameState.PREPARING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_pointer_action(event.position)
			else: _end_pointer_action(event.position)
		elif _camp_locked() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_notice("关间站位已锁定 · 开战后可右键移动")
			_release_control()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_release_control()
		return
	if state != GameState.BATTLE_RUNNING: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_command_free(selected_hero,event.position)
			_release_control()
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
		_cancel_carry()
		_cancel_swap()
		brains.clear()
		enemy_motion.clear()
		_clear_notice()
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
	if actor in heroes and brain.mode == "接战" and next.distance_to(brain.anchor) > Rules.LEASH_RADIUS:
		_return_to_guard(brain)
		return false
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
	brain.mode = "归位"
	brain.target = null
	brain.path = PackedVector2Array()
	brain.repath = 0.0
	brain.blocked = 0.0

func _acquire(hero, brain: Dictionary) -> void:
	var candidates := enemies.filter(func(enemy): return CombatEvents.alive(enemy))
	candidates.sort_custom(func(a,b): return hero.position.distance_squared_to(a.position) < hero.position.distance_squared_to(b.position))
	for enemy in candidates:
		if brain.skip.get(enemy.get_instance_id(),0.0) > battle_elapsed: continue
		if enemy.position.distance_to(brain.anchor) > Rules.AGGRO_RADIUS: continue
		var destination := _attack_point(hero,enemy)
		if destination != Vector2.INF and destination.distance_to(brain.anchor) > Rules.LEASH_RADIUS: continue
		if _in_range(hero,enemy) or (destination != Vector2.INF and not space.path(hero.position,destination,_opponents(hero)).is_empty()):
			brain.target = enemy
			brain.mode = "接战"
			# The whole excursion shares one timer; only a completed return resets it.
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
		if _stop_free(hero.position,hero): brain.last_legal = hero.position
		hero.cooldown = maxf(0,hero.cooldown-delta)
		if brain.mode == "手动":
			if _travel(hero,brain,brain.goal,delta,true):
				manual_completions += 1
				_establish_guard(hero,"已到达 · 更新驻守点")
			elif brain.blocked >= Rules.UNREACHABLE_SECONDS:
				_establish_guard(hero,"无法抵达 · 当前合法位置驻守")
			continue
		brain.think -= delta
		if brain.mode == "归位":
			if _travel(hero,brain,brain.anchor,delta,true):
				brain.mode = "驻守"
				brain.chase = 0.0
				brain.think = 0.4
			# An occupied/unreachable anchor waits/repaths, never walks to Tang or
			# acquires another target to chain an excursion across the map.
			continue
		if hero.unit_type != "herbal_spirit_child":
			if brain.mode == "接战":
				brain.chase += delta
				if not CombatEvents.alive(brain.target) or brain.chase > Rules.CHASE_SECONDS or hero.position.distance_to(brain.anchor) > Rules.LEASH_RADIUS or brain.target.position.distance_to(brain.anchor) > Rules.LEASH_RADIUS or brain.blocked > Rules.UNREACHABLE_SECONDS:
					_return_to_guard(brain)
					continue
			if brain.mode == "驻守" and brain.think <= 0:
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
	_cancel_carry()
	_cancel_swap()
	_clear_notice()
	brains.clear()
	enemy_motion.clear()
	for hero in heroes:
		if hero.board_row < 0: continue
		if hero.battle_dead:
			var revive := _near_free(escort.position,hero,200)
			if revive != Vector2.INF: hero.position = revive
			hero.battle_dead = false
		guard_anchors[hero] = hero.position
		hero.home_position = hero.position
	camp_positions.capture(hero_slots,heroes)
	pointer_hero = null
	pointer_was_selected = false
	super._enter_wave_preparation()
	_notice("营地抵达 · +%d金｜R下场 / F原位互换 · 新增名额可落位" % last_wave_reward)

func _finish_battle(victory: bool) -> void:
	if state != GameState.BATTLE_RUNNING: return
	_cancel_carry()
	_cancel_swap()
	_clear_notice()
	brains.clear()
	enemy_motion.clear()
	pointer_hero = null
	pointer_was_selected = false
	super._finish_battle(victory)
	result_label.text += "\n无格子半自动试验 · 非最终平衡"

func _restart_demo() -> void:
	_cancel_carry()
	_cancel_swap()
	camp_positions.reset()
	hero_slots.clear()
	guard_anchors.clear()
	brains.clear()
	enemy_motion.clear()
	route_index = 0
	pointer_hero = null
	pointer_was_selected = false
	manual_completions = 0
	auto_engagements = 0
	_clear_notice()
	super._restart_demo()
	escort.position = Map.center(Map.ROUTE[0])

func _tick(delta: float) -> void:
	super._tick(delta)
	for hero in heroes:
		if hero.board_row < 0: hero.z_index = 2038
	queue_redraw()

func _update_ui() -> void:
	super._update_ui()
	if not is_instance_valid(route_label): return
	_validate_carry()
	_validate_swap()
	for child in get_children():
		if child is Control and child.is_in_group("bench_controls"): child.visible = bench_open
	for hero in heroes:
		hero.compact_bench = hero.board_row < 0
		hero.presentation.show_shadow = hero.board_row >= 0
		if hero.board_row < 0:
			hero.visible = bench_open
			var portrait = BenchPortraits.portrait_for(hero.unit_type)
			var bounds: Rect2i = BenchPortraits.idle_bounds[hero.unit_type]
			var fit: float = minf(98.0/portrait.get_height(),122.0/portrait.get_width())
			hero.presentation.scale = Vector2.ONE*fit
			# Visible feet, not transparent atlas padding, share one baseline.
			hero.presentation.foot_anchor = Vector2(0,(862-hero.position.y)/fit-(bounds.end.y-218))
	for slot in range(bench_panels.size()): bench_panels[slot].present(_hero_in_bench(slot),slot+1)
	shop_toggle.text = ("收起商店 [空格]" if shop_open else "招募商店 [空格]")
	shop_toggle.disabled = state == GameState.RESULT
	_update_roster_hud()
	_update_roster_actions()
	for card in shop_buttons: card.tooltip_text = "点击购买 · 数字键选择上场英雄"
	if note_expires_at_msec <= Time.get_ticks_msec(): _clear_notice()
	if is_instance_valid(selected_hero):
		info_label.text = info_label.text.replace("攻击距离  %d格" % selected_hero.attack_range_cells,"攻击距离  %.0f像素（试验）" % _range(selected_hero))
	route_label.text = "A 林口 → B 山门\n无格子 · 驻守试验\n%s" % ("营地整备" if state == GameState.PREPARING else escort_reason)
	wave_label.text = "路段 %d / 4" % clampi(wave_index+(2 if state == GameState.PREPARING else 1),1,4)
	if state == GameState.PREPARING:
		start_button.text = "出发 · 第%d段" % (wave_index+2)
		var preparation_hint := "关间锁位 · R下场 / F原位互换 · 仅新增名额可另选落点" if _camp_locked() else "招募后部署在唐僧附近陆地 · R下场 / F互换"
		if is_instance_valid(swap_source): preparation_hint = "%s：点击场上或后备英雄原位互换 · Esc取消" % swap_source.display_name
		status_label.text = command_note if not command_note.is_empty() else preparation_hint
	elif state == GameState.BATTLE_RUNNING:
		start_button.text = "驻守接敌中"
		if battle_paused:
			status_label.text = "已暂停 · " + (command_note if not command_note.is_empty() else "可下令，继续后执行")
		else:
			status_label.text = command_note if not command_note.is_empty() else "驻守点附近接敌 · 不跟随唐僧 · 数字选人，右键移动"
	if state == GameState.BATTLE_RUNNING and is_instance_valid(selected_hero) and selected_hero.active_in_battle and not selected_hero.battle_dead:
		var brain := _brain(selected_hero)
		info_label.text = "%s\n当前：%s\n生命 %d / %d · 射程 %.0f\n\n右键 / 点地：手动优先\n到达：设新驻守点\nEsc：当前合法位置驻守\nQ / W / E：技能空槽\n\n绿：驻守 / 蓝：归位\n红：接战 / 金：手动\n归位点被占：等待，不追敌" % [selected_hero.display_name,brain.mode,int(selected_hero.health),int(selected_hero.max_health),_range(selected_hero)]
	elif not is_instance_valid(selected_hero):
		info_label.text = "无格子驻守 · 试验\n\n唐僧活着到达 B，清除威胁\n英雄不会跟随，需手动调队\n药灵原地支援\n追击超时 / 超界返回驻守点\n\n1—9 / 0 选人 · 右键移动\n下令后取消选中，移动继续\n空格 商店 · 后备始终可见\n底栏显示英雄状态和血量\n\n营地可招募 / 合成 / 升人口\n英雄恢复，唐僧血量保留"
	if state == GameState.PREPARING and is_instance_valid(selected_hero):
		info_label.text = "%s\n生命 %d / %d · %d星\n\nR：下场（后备须有空位）\nF：与场上 / 后备英雄互换\n后备满也可直接互换\nEsc：取消选择操作\n\n%s\n\nQ / W / E：未配置" % [selected_hero.display_name,int(selected_hero.health),int(selected_hero.max_health),selected_hero.star,"关间只能交换既有位置\n空圈：可替换的原位\n新增名额可在唐僧附近落位" if _camp_locked() else "首次布阵可自由调整\n部署在唐僧附近陆地"]

func _draw() -> void:
	if _camp_locked():
		for index in camp_positions.points:
			if _seat_hero(index) != null: continue
			var point: Vector2 = camp_positions.points[index]
			draw_arc(point,24,0,TAU,32,Color("b7d6ed"),2.5,true)
			draw_string(ThemeDB.fallback_font,point+Vector2(-25,40),"[%d] 空位" % ((index+1)%10),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d7eaff"))
	if is_instance_valid(swap_source):
		draw_arc(swap_source.position,23,0,TAU,32,Color("cca5ed"),3,true)
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
		var color: Color = {"驻守":Color("9ed492"),"整备":Color("9ed492"),"归位":Color("90badf"),"接战":Color("ed9375"),"手动":Color("f2d56b")}[mode]
		draw_arc(hero.position,16,0,TAU,24,color,2,true)
		var index := hero_slots.find(hero)
		var number := str((index+1)%10) if index >= 0 else "—"
		draw_string(ThemeDB.fallback_font,hero.position+Vector2(-26,25),"[%s] %s" % [number,mode],HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
		if mode == "手动":
			draw_line(hero.position,brains[hero].goal,color,1.5,true)
			draw_arc(brains[hero].goal,10,0,TAU,20,color,2,true)
	if is_instance_valid(selected_hero) and selected_hero.board_row >= 0:
		draw_arc(selected_hero.position,_range(selected_hero),0,TAU,80,Color(0.95,0.87,0.55,0.25),1,true)
		if guard_anchors.has(selected_hero):
			draw_arc(guard_anchors[selected_hero],11,0,TAU,24,Color("9ed492"),2,true)
	if not shop_open and state != GameState.RESULT:
		var mouse := get_global_mouse_position()
		if space.valid(mouse): draw_arc(mouse,8,0,TAU,16,Color("f4e7ba"),1.5,true)
