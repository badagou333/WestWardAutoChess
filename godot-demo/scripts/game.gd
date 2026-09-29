extends Node2D

const HeroScene = preload("res://scripts/unit.gd")
const EnemyScene = preload("res://scripts/enemy.gd")
const EscortScene = preload("res://scripts/escort.gd")
const BATTLEFIELD_PATH := "res://art/reviews/style-unification-v1/battlefield-candidate.png"
const BoardGeometry = preload("res://scripts/presentation/board_geometry.gd")
var painted_board := false

enum GameState { PREPARING, BATTLE_RUNNING, RESULT }

const SCREEN_SIZE := Vector2(1920, 1080)
const BOARD_ORIGIN := Vector2(398, 294)
const CELL_SIZE := Vector2(162, 113)
const ROWS := 5
const COLS := 7
const CENTER_CELL := Vector2i(2, 3)
# Demo tuning, not final balance: defend the escort rather than the spawn cell.
const DEFENSE_RADIUS := 3
const BENCH_SIZE := 8
const BENCH_START := Vector2(790, 1000)
const BENCH_STEP := 83.0
const REFRESH_COST := 2
const COMBAT_TIME_SCALE := 1.0
const CombatEvents = preload("res://scripts/combat/attack_events.gd")
const DemoUnits = preload("res://scripts/data/demo_units.gd")
const LEVEL_COSTS := [10, 16, 24, 34, 48, 65, 85]
const QUALITY_COLORS := {
	"white": Color("e9e5db"), "green": Color("72d681"), "blue": Color("69b8ff"),
	"purple": Color("bd82ff"), "gold": Color("ffd45f")
}
const QUALITY_NAMES := {"white": "白", "green": "绿", "blue": "蓝", "purple": "紫", "gold": "金"}
const WAVES = preload("res://scripts/data/demo_encounter.gd").WAVES

var state := GameState.PREPARING
var coins := 10
var population := 3
var max_population := 10
var refresh_token := 1
var heroes: Array = []
var enemies: Array = []
var shop_types: Array[String] = []
var escort
var selected_hero
var dragged_hero
var drag_origin := {}
var dragging := false
var press_position := Vector2.ZERO
var pending_loot := 0
var wave_index := -1
var intermission := 0.0
var spawn_queue: Array[String] = []
var spawn_entries: Array[Vector2i] = []
var spawn_cooldown := 0.0
var battle_paused := false
var battle_speed := 1.0
var rng := RandomNumberGenerator.new()
var combat
var audio_feedback
var moving: Array = []
var retiring: Array = []
var floating: Array = []
var accumulator := 0.0
var battle_elapsed := 0.0

var coins_label: Label
var population_label: Label
var escort_label: Label
var loot_label: Label
var wave_label: Label
var status_label: Label
var info_label: Label
var tip_label: Label
var shop_buttons: Array[Button] = []
var refresh_button: Button
var level_button: Button
var start_button: Button
var sell_button: Button
var lock_button: Button
var pause_button: Button
var speed_button: Button
var overlay: ColorRect
var result_label: Label
var replay_button: Button
var background: TextureRect

func _ready() -> void:
	painted_board = true
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "Arial Unicode MS"])
	ThemeDB.fallback_font = font
	rng.seed = 20260825
	audio_feedback = preload("res://scripts/presentation/audio_feedback.gd").new()
	add_child(audio_feedback)
	_create_background()
	_create_interface()
	_create_escort()
	_initial_shop()
	escort.set_process(false)
	combat = CombatEvents.new()
	combat.z_index = 1900
	combat.resolved.connect(_apply_combat_event)
	combat.projectile_released.connect(audio_feedback.released)
	add_child(combat)
	# UI stays above the foot-sorted battlefield.
	for child in get_children():
		if child is Control and child != background:
			child.z_index += 2000
	_update_ui()
	queue_redraw()

func _create_background() -> void:
	background = TextureRect.new()
	var path := BATTLEFIELD_PATH if painted_board else "res://art/demo/temple_battlefield.png"
	background.texture = preload("res://scripts/presentation/character_presentation.gd")._texture(path)
	background.position = Vector2.ZERO
	background.size = SCREEN_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)

func _create_escort() -> void:
	escort = EscortScene.new()
	escort.position = _cell_center(CENTER_CELL)
	escort.z_index = 7
	add_child(escort)

func _create_interface() -> void:
	var top_panel := ColorRect.new()
	top_panel.position = Vector2.ZERO
	top_panel.size = Vector2(1920, 86)
	top_panel.color = Color(0.10, 0.07, 0.035, 0.88)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.z_index = 30
	add_child(top_panel)

	var title := _make_label(Vector2(28, 12), Vector2(310, 58), 30, Color("ffe294"), 31)
	title.text = "西游护送 · 四波试玩"
	coins_label = _make_label(Vector2(365, 17), Vector2(190, 50), 25, Color("ffe16e"), 31)
	population_label = _make_label(Vector2(550, 17), Vector2(200, 50), 25, Color("cfeeb9"), 31)
	escort_label = _make_label(Vector2(750, 17), Vector2(280, 50), 25, Color("ffa99c"), 31)
	loot_label = _make_label(Vector2(1030, 17), Vector2(220, 50), 24, Color("86d9ff"), 31)
	wave_label = _make_label(Vector2(1250, 17), Vector2(230, 50), 23, Color("fff2cf"), 31)

	pause_button = _make_button(Vector2(1504, 15), Vector2(112, 52), "暂停", Color("617796"), 32)
	pause_button.pressed.connect(_toggle_pause)
	speed_button = _make_button(Vector2(1627, 15), Vector2(112, 52), "1×", Color("607b55"), 32)
	speed_button.pressed.connect(_toggle_speed)
	var sound_button := _make_button(Vector2(1750,15),Vector2(140,52),"音效：开",Color("607b55"),32)
	sound_button.pressed.connect(func():
		audio_feedback.enabled = not audio_feedback.enabled
		sound_button.text = "音效：开" if audio_feedback.enabled else "音效：关"
	)
	var volume := HSlider.new()
	volume.position = Vector2(1750,70)
	volume.size = Vector2(140,15)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = 0.35
	volume.z_index = 32
	volume.tooltip_text = "音效音量"
	volume.value_changed.connect(func(value): audio_feedback.level = value)
	add_child(volume)

	status_label = _make_label(Vector2(520, 92), Vector2(880, 58), 27, Color("fff2c8"), 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.01, 0.9))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 3)

	var bottom_panel := ColorRect.new()
	bottom_panel.position = Vector2(0, 868)
	bottom_panel.size = Vector2(1920, 212)
	bottom_panel.color = Color(0.09, 0.06, 0.03, 0.92)
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_panel.z_index = 25
	add_child(bottom_panel)

	var shop_title := _make_label(Vector2(20, 878), Vector2(630, 35), 22, Color("ffe3a1"), 31)
	shop_title.text = "招募商店  ·  数字键 1—5 购买"
	for i in range(5):
		var button := _make_button(Vector2(20 + i * 142, 920), Vector2(132, 132), "", Color("765b3d"), 31)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_shop_pressed.bind(i))
		shop_buttons.append(button)

	refresh_button = _make_button(Vector2(730, 882), Vector2(176, 64), "", Color("55734a"), 31)
	refresh_button.pressed.connect(_on_refresh_pressed)
	level_button = _make_button(Vector2(916, 882), Vector2(176, 64), "", Color("536c91"), 31)
	level_button.pressed.connect(_on_level_pressed)

	var bench_title := _make_label(Vector2(1110, 882), Vector2(360, 35), 21, Color("d9d4c7"), 31)
	bench_title.text = "候选区 8格 · 拖动队员上阵"
	tip_label = _make_label(Vector2(715, 1048), Vector2(760, 28), 15, Color("d8ccb3"), 31)
	tip_label.text = "准备期可拖动或先点击队员再点击格子；中央唐僧格不可放置。三个同名同星自动合成。"
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var info_back := ColorRect.new()
	info_back.position = Vector2(1630, 122)
	info_back.size = Vector2(280, 372)
	info_back.color = Color(0.08, 0.05, 0.025, 0.72)
	info_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_back.z_index = 24
	add_child(info_back)
	info_label = _make_label(Vector2(1640, 132), Vector2(260, 350), 18, Color("fff1cf"), 25)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	sell_button = _make_button(Vector2(1640, 510), Vector2(260, 54), "出售选中队员", Color("924e42"), 31)
	sell_button.pressed.connect(_sell_selected)
	lock_button = _make_button(Vector2(1640, 574), Vector2(260, 54), "合成锁定：关", Color("765d90"), 31)
	lock_button.pressed.connect(_toggle_selected_lock)
	start_button = _make_button(Vector2(1640, 735), Vector2(260, 98), "开始战斗", Color("bd7627"), 31)
	start_button.add_theme_font_size_override("font_size", 27)
	start_button.pressed.connect(_start_battle)

	overlay = ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = SCREEN_SIZE
	overlay.color = Color(0.055, 0.035, 0.018, 0.90)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 100
	add_child(overlay)
	result_label = Label.new()
	result_label.position = Vector2(500, 205)
	result_label.size = Vector2(920, 500)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.add_theme_color_override("font_color", Color("fff0c4"))
	overlay.add_child(result_label)
	replay_button = Button.new()
	replay_button.position = Vector2(785, 745)
	replay_button.size = Vector2(350, 82)
	replay_button.text = "重新体验这一战"
	replay_button.add_theme_font_size_override("font_size", 25)
	_style_button(replay_button, Color("b9792d"))
	replay_button.pressed.connect(_restart_demo)
	overlay.add_child(replay_button)

func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color, layer := 1) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_color_override("font_color", color)
	label.z_index = layer
	add_child(label)
	return label

func _make_button(pos: Vector2, button_size: Vector2, text_value: String, accent: Color, layer := 1) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.text = text_value
	button.z_index = layer
	_style_button(button, accent)
	add_child(button)
	return button

func _style_button(button: Button, accent: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_color_override("font_color", Color("fff4d5"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.68, 0.59, 0.5))
	button.add_theme_stylebox_override("normal", _button_box(accent, Color("4c321e")))
	button.add_theme_stylebox_override("hover", _button_box(accent.lightened(0.13), Color("ffe28c")))
	button.add_theme_stylebox_override("pressed", _button_box(accent.darkened(0.14), Color("ffe28c")))
	button.add_theme_stylebox_override("disabled", _button_box(Color(0.22, 0.21, 0.18, 0.9), Color(0.34, 0.31, 0.26)))

func _button_box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0.06, 0.035, 0.015, 0.8)
	box.shadow_size = 4
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _initial_shop() -> void:
	shop_types.assign(DemoUnits.SHOP)

func _process(delta: float) -> void:
	step(delta)
	_update_ui()

func step(delta: float) -> void:
	if battle_paused: return
	accumulator += delta * battle_speed
	# Fixed clock preserves all elapsed time; no min(delta, 0.05) time loss.
	while accumulator + 0.00000001 >= 1.0 / 120.0:
		accumulator -= 1.0 / 120.0
		_tick(1.0 / 120.0)

func _tick(delta: float) -> void:
	for hero in heroes: hero.tick_visual(delta)
	for enemy in enemies + retiring:
		if is_instance_valid(enemy): enemy.tick_visual(delta)
	retiring = retiring.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	escort._process(delta)
	for move in moving.duplicate():
		if not CombatEvents.alive(move.node):
			moving.erase(move)
			continue
		move.time += delta
		move.node.position = move.from.lerp(move.to,smoothstep(0,1,minf(1,move.time/move.duration)))
		if move.time + 0.00000001 >= move.duration:
			move.node.position = move.to
			moving.erase(move)
	for hero in heroes:
		if hero.board_row >= 0: hero.z_index = int(hero.position.y)
		else: hero.z_index = 2030
	for enemy in enemies:
		enemy.z_index = int(enemy.position.y)
	escort.z_index = int(escort.position.y + 35)
	if state == GameState.BATTLE_RUNNING:
		battle_elapsed += delta
		combat.tick(delta)
		if escort.dead:
			_finish_battle(false)
		else:
			_process_wave(delta)
			if state == GameState.BATTLE_RUNNING:
				_process_heroes(delta)
				_process_enemies(delta)
	for item in floating.duplicate():
		item.time += delta
		item.label.position.y = item.y - item.time * 60
		item.label.modulate.a = maxf(0,1-item.time/0.7)
		if item.time >= 0.7:
			item.label.queue_free()
			floating.erase(item)

func _is_moving(node) -> bool:
	for move in moving:
		if move.node == node: return true
	return false

func _process_wave(delta: float) -> void:
	if intermission > 0.0:
		intermission = max(0.0, intermission - delta)
		if intermission <= 0.0:
			_begin_wave()
		return
	if not spawn_queue.is_empty():
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			_spawn_enemy(spawn_queue.pop_front(), spawn_entries.pop_front())
			spawn_cooldown = 0.55
		return
	if enemies.is_empty():
		if wave_index >= WAVES.size() - 1:
			_finish_battle(true)
		else:
			wave_index += 1
			intermission = 3.0

func _begin_wave() -> void:
	var wave: Dictionary = WAVES[wave_index]
	spawn_queue.assign(wave.units)
	spawn_entries.assign(wave.entries)
	spawn_cooldown = 0.0

func _spawn_enemy(enemy_type: String, cell: Vector2i) -> void:
	var enemy = EnemyScene.new()
	enemy.setup(enemy_type)
	enemy.battle_cell = cell
	enemy.position = _cell_center(cell)
	enemy.z_index = 8 + cell.x
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	enemies.append(enemy)

func _process_heroes(delta: float) -> void:
	for hero in heroes:
		if not hero.active_in_battle or hero.battle_dead: continue
		hero.cooldown = maxf(0,hero.cooldown-delta)
		hero.move_cooldown = maxf(0,hero.move_cooldown-delta)
		if _is_moving(hero) or hero.presentation.pose == "basic_attack": continue
		var healing: bool = hero.unit_type == "herbal_spirit_child"
		var target = _healing_target(hero) if healing else _reachable_enemy(hero)
		if target == null: continue
		var cell: Vector2i = CENTER_CELL if target == escort else target.battle_cell
		if _cell_distance(hero.battle_cell,cell) <= hero.attack_range_cells:
			if hero.cooldown <= 0:
				hero.cooldown = hero.effective_interval()
				combat.request(hero,target,healing,hero.unit_type == "foxfire_imp")
		elif hero.move_cooldown <= 0:
			_move_hero_toward(hero,cell)

func _healing_target(_hero):
	var result = null
	var ratio := 1.0
	for ally in heroes + [escort]:
		if not CombatEvents.alive(ally): continue
		if ally != escort and not ally.active_in_battle: continue
		var current: float = ally.health / ally.max_health
		var target_cell: Vector2i = CENTER_CELL if ally == escort else ally.battle_cell
		if _combat_path(_hero, target_cell, _hero.attack_range_cells, true).is_empty(): continue
		if current < ratio:
			ratio = current
			result = ally
	return result

func _apply_combat_event(target, amount: float, healing: bool, event: Dictionary) -> void:
	audio_feedback.resolved_attack(event)
	if healing:
		target.heal(amount)
		_float_text(target.position+Vector2(0,-130),"+%d" % int(amount),Color("75eba3"))
	else:
		var targets: Array = [target]
		if event.splash:
			for enemy in enemies:
				if enemy != target and CombatEvents.alive(enemy) and _cell_distance(target.battle_cell,enemy.battle_cell) <= 1:
					targets.append(enemy)
		for recipient in targets:
			recipient.take_damage(amount)
			audio_feedback.hit(recipient,event.has("texture"),recipient == escort)
			_float_text(recipient.position+Vector2(0,-130),str(int(amount)),Color("ffd28a"))

func _process_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if enemy.dead: continue
		enemy.attack_cooldown = maxf(0,enemy.attack_cooldown-delta)
		enemy.move_cooldown = maxf(0,enemy.move_cooldown-delta)
		if _is_moving(enemy) or (enemy.presentation != null and enemy.presentation.pose == "basic_attack"): continue
		var target = _adjacent_blocking_hero(enemy.battle_cell)
		if target == null and _cell_distance(enemy.battle_cell,CENTER_CELL) <= 1: target = escort
		if target != null:
			if enemy.attack_cooldown <= 0:
				enemy.attack_cooldown = enemy.attack_interval
				combat.request(enemy,target)
		elif enemy.move_cooldown <= 0:
			_move_enemy_toward_center(enemy)

# Paths end at a free attack/healing position, never on the target.
# Both ends of an in-flight move are reserved until the actor arrives.
func _cell_blocked(cell: Vector2i, mover) -> bool:
	if _hero_at_cell(cell, mover) != null: return true
	var enemy = _enemy_at_cell(cell)
	if enemy != null and enemy != mover: return true
	for move in moving:
		if move.node != mover and _screen_to_cell(move.from) == cell: return true
	return false

func _combat_path(mover, target: Vector2i, reach: int, limited: bool) -> Array[Vector2i]:
	var start: Vector2i = mover.battle_cell
	var frontier: Array[Vector2i] = [start]
	var parents := {start: start}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if _cell_distance(cell, target) <= reach:
			var path: Array[Vector2i] = [cell]
			while cell != start:
				cell = parents[cell]
				path.push_front(cell)
			return path
		for direction in [Vector2i(0,1),Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1)]:
			var next: Vector2i = cell + direction
			if not _valid_cell(next) or next == CENTER_CELL or parents.has(next): continue
			if limited and not _defense_step_allowed(cell, next): continue
			if _cell_blocked(next, mover): continue
			parents[next] = cell
			frontier.append(next)
	return []

func _defense_step_allowed(current: Vector2i, next: Vector2i) -> bool:
	var distance := _cell_distance(next, CENTER_CELL)
	if distance <= DEFENSE_RADIUS: return true
	# Edge deployments may enter the zone, but cannot chase farther outward.
	return _cell_distance(current, CENTER_CELL) > DEFENSE_RADIUS and distance < _cell_distance(current, CENTER_CELL)

func _reachable_enemy(hero):
	var result = null
	var best := 999
	for enemy in enemies:
		if not CombatEvents.alive(enemy): continue
		var path := _combat_path(hero, enemy.battle_cell, hero.attack_range_cells, true)
		if not path.is_empty() and path.size() < best:
			result = enemy
			best = path.size()
	return result

func _move_hero_toward(hero, target: Vector2i) -> void:
	var path := _combat_path(hero, target, hero.attack_range_cells, true)
	if path.size() > 1:
		hero.battle_cell = path[1]
		hero.move_cooldown = hero.move_interval
		_tween_to_cell(hero, path[1])

func _move_enemy_toward_center(enemy) -> void:
	var path := _combat_path(enemy, CENTER_CELL, 1, false)
	if path.size() > 1:
		enemy.battle_cell = path[1]
		enemy.move_cooldown = enemy.move_interval
		_tween_to_cell(enemy, path[1])

func _tween_to_cell(node: Node2D, cell: Vector2i) -> void:
	var visual = node.get("presentation")
	var duration: float = node.move_interval
	if visual != null:
		visual.face(_cell_center(cell)-node.position)
		visual.move_to(Vector2.ZERO)
		duration = visual.motion.walk
	moving.append({"node":node,"from":node.position,"to":_cell_center(cell),"time":0.0,"duration":duration})

func _on_enemy_defeated(enemy) -> void:
	if enemy in enemies:
		enemies.erase(enemy)
		pending_loot += enemy.reward
		_float_text(enemy.position + Vector2(0, -110), "+%d 战利品" % enemy.reward, Color("ffe36d"))
		retiring.append(enemy)
		audio_feedback.play_cue(enemy.enemy_type+"_death")
		enemy.play_death()

func _nearest_enemy_to_cell(cell: Vector2i):
	var result = null
	var best := 999
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := _cell_distance(cell, enemy.battle_cell)
		if distance < best:
			best = distance
			result = enemy
	return result

func _adjacent_blocking_hero(cell: Vector2i):
	var result = null
	var best_to_escort := 999
	for hero in heroes:
		if not is_instance_valid(hero) or not hero.active_in_battle or hero.battle_dead:
			continue
		if _cell_distance(cell, hero.battle_cell) <= 1:
			var dist := _cell_distance(hero.battle_cell, CENTER_CELL)
			if dist < best_to_escort:
				best_to_escort = dist
				result = hero
	return result

func _start_battle() -> void:
	if state != GameState.PREPARING:
		return
	if _deployed_count() == 0:
		status_label.text = "请至少部署一名队员再开始"
		return
	state = GameState.BATTLE_RUNNING
	combat.clear(true)
	moving.clear()
	accumulator = 0.0
	battle_elapsed = 0.0
	pending_loot = 0
	wave_index = 0
	intermission = 3.0
	battle_paused = false
	battle_speed = 1.0
	escort.reset()
	_clear_selection()
	for hero in heroes:
		hero.begin_battle()
	start_button.text = "自动战斗中"
	queue_redraw()

func _finish_battle(victory: bool) -> void:
	if state != GameState.BATTLE_RUNNING:
		return
	state = GameState.RESULT
	combat.clear()
	moving.clear()
	battle_paused = false
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	var percent: float = escort.health / escort.max_health
	if victory:
		audio_feedback.play_cue("victory")
		var stars := 3 if percent >= 0.999 else (2 if percent >= 0.5 else 1)
		var multiplier := 1.0 if stars == 3 else (0.9 if stars == 2 else 0.8)
		var payout := int(ceil(float(pending_loot) * multiplier))
		coins += payout
		var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
		result_label.text = "%s\n\n护送成功 · 唐僧剩余生命 %d%%\n击杀战利品：%d\n星级结算倍率：%d%%\n本关获得金币：%d\n\n击败熊山君 · 单场试玩完成\n（章节解锁与存档后续接入）" % [star_text, int(round(percent * 100.0)), pending_loot, int(multiplier * 100.0), payout]
	else:
		result_label.text = "护送失败\n\n唐僧生命归零\n本次战利品不结算\n\n调整阵型、招募或合成英雄后再试一次"
	overlay.visible = true

func _restart_demo() -> void:
	audio_feedback.stop_all()
	combat.clear(true)
	moving.clear()
	for item in floating: item.label.queue_free()
	floating.clear()
	for enemy in enemies + retiring:
		if is_instance_valid(enemy): enemy.queue_free()
	retiring.clear()
	battle_paused = false
	battle_speed = 1.0
	accumulator = 0.0
	battle_elapsed = 0.0
	for hero in heroes.duplicate():
		if is_instance_valid(hero):
			hero.queue_free()
	heroes.clear()
	enemies.clear()
	coins = 10
	population = 3
	refresh_token = 1
	pending_loot = 0
	wave_index = -1
	intermission = 0.0
	state = GameState.PREPARING
	overlay.visible = false
	start_button.text = "开始战斗"
	escort.reset()
	_initial_shop()
	_clear_selection()
	_update_ui()
	queue_redraw()

func _on_shop_pressed(index: int) -> void:
	if state != GameState.PREPARING or index < 0 or index >= shop_types.size():
		return
	var unit_type := shop_types[index]
	if unit_type.is_empty():
		return
	var data: Dictionary = HeroScene.UNIT_DATA[unit_type]
	var quality: String = data.quality
	var cost: int = HeroScene.QUALITY_DATA[quality].cost
	var slot := _free_bench_slot()
	if coins < cost:
		status_label.text = "金币不足"
		return
	if slot < 0:
		status_label.text = "候选区已满"
		return
	coins -= cost
	audio_feedback.play_cue("ui")
	var hero = HeroScene.new()
	hero.setup(unit_type)
	hero.bench_slot = slot
	hero.board_row = -1
	hero.board_col = -1
	hero.position = _bench_position(slot)
	hero.home_position = hero.position
	hero.set_bench_mode(true)
	hero.z_index = 1500
	add_child(hero)
	heroes.append(hero)
	shop_types[index] = ""
	_try_auto_merge(unit_type, 1)
	_update_ui()
	queue_redraw()

func _try_auto_merge(unit_type: String, target_star: int) -> void:
	if target_star >= 3:
		return
	var matches: Array = []
	for hero in heroes:
		if is_instance_valid(hero) and hero.unit_type == unit_type and hero.star == target_star and not hero.merge_locked:
			matches.append(hero)
	if matches.size() < 3:
		return
	var keeper = matches[0]
	for i in range(1, 3):
		var consumed = matches[i]
		if consumed == selected_hero:
			selected_hero = null
		heroes.erase(consumed)
		consumed.queue_free()
	keeper.upgrade()
	_float_text(keeper.position + Vector2(0, -95), "自动合成 · %d星" % keeper.star, Color("ffe266"))
	_try_auto_merge(unit_type, target_star + 1)

func _on_refresh_pressed() -> void:
	if state != GameState.PREPARING:
		return
	if refresh_token > 0:
		refresh_token -= 1
	elif coins >= REFRESH_COST:
		coins -= REFRESH_COST
	else:
		status_label.text = "刷新需要2金币"
		return
	shop_types.clear()
	for i in range(5):
		shop_types.append(_roll_shop_unit())

func _roll_shop_unit() -> String:
	return DemoUnits.SHOP[rng.randi_range(0,DemoUnits.SHOP.size()-1)]

func _on_level_pressed() -> void:
	if state != GameState.PREPARING or population >= max_population:
		return
	var cost: int = LEVEL_COSTS[population - 3]
	if coins < cost:
		status_label.text = "升人口需要%d金币" % cost
		return
	coins -= cost
	population += 1

func _sell_selected() -> void:
	if state != GameState.PREPARING or not is_instance_valid(selected_hero):
		return
	var copies := int(pow(3, selected_hero.star - 1))
	var raw_value: int = selected_hero.cost * copies
	var refund := raw_value if selected_hero.star == 1 else maxi(1, int(floor(raw_value * 0.7)))
	coins += refund
	heroes.erase(selected_hero)
	selected_hero.queue_free()
	selected_hero = null
	_update_ui()
	queue_redraw()

func _toggle_selected_lock() -> void:
	if state != GameState.PREPARING or not is_instance_valid(selected_hero):
		return
	selected_hero.merge_locked = not selected_hero.merge_locked
	selected_hero.queue_redraw()
	if not selected_hero.merge_locked:
		_try_auto_merge(selected_hero.unit_type, selected_hero.star)

func _toggle_pause() -> void:
	if state != GameState.BATTLE_RUNNING:
		return
	battle_paused = not battle_paused
	audio_feedback.set_paused(battle_paused)

func _toggle_speed() -> void:
	if state != GameState.BATTLE_RUNNING:
		return
	battle_speed = 2.0 if battle_speed < 1.5 else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_on_shop_pressed(int(event.keycode - KEY_1))
		elif event.keycode == KEY_R:
			_on_refresh_pressed()
		elif event.keycode == KEY_E:
			_on_level_pressed()
		elif event.keycode == KEY_SPACE:
			if state == GameState.PREPARING:
				_start_battle()
			else:
				_toggle_pause()
	if state != GameState.PREPARING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer_action(event.position)
		else:
			_end_pointer_action(event.position)
	elif event is InputEventMouseMotion and dragged_hero != null:
		if not dragging and event.position.distance_to(press_position) > 8.0:
			dragging = true
			dragged_hero.dragging = true
		if dragging:
			dragged_hero.position = event.position
			dragged_hero.z_index = 60

func _begin_pointer_action(pos: Vector2) -> void:
	var clicked = _hero_at_position(pos)
	if clicked != null:
		_select_hero(clicked)
		dragged_hero = clicked
		press_position = pos
		drag_origin = {"row": clicked.board_row, "col": clicked.board_col, "bench": clicked.bench_slot, "position": clicked.position, "z": clicked.z_index}
		return
	if is_instance_valid(selected_hero):
		var cell := _screen_to_cell(pos)
		if _valid_cell(cell) and cell != CENTER_CELL:
			_place_hero_on_board(selected_hero, cell)
			return
	_clear_selection()

func _end_pointer_action(pos: Vector2) -> void:
	if dragged_hero == null:
		return
	if dragging:
		var cell := _screen_to_cell(pos)
		if _valid_cell(cell) and cell != CENTER_CELL:
			_place_hero_on_board(dragged_hero, cell)
		else:
			var slot := _bench_slot_at(pos)
			if slot >= 0:
				_place_hero_on_bench(dragged_hero, slot)
			else:
				_restore_drag_origin(dragged_hero)
	dragged_hero.dragging = false
	dragging = false
	dragged_hero = null
	queue_redraw()

func _place_hero_on_board(hero, cell: Vector2i) -> void:
	if state != GameState.PREPARING or not _valid_cell(cell) or cell == CENTER_CELL:
		return
	var occupant = _hero_at_cell(cell, hero)
	if occupant != null:
		var origin_row: int = hero.board_row
		var origin_col: int = hero.board_col
		var origin_bench: int = hero.bench_slot
		if origin_row >= 0:
			occupant.board_row = origin_row
			occupant.board_col = origin_col
			occupant.bench_slot = -1
			occupant.position = _cell_center(Vector2i(origin_row, origin_col))
			occupant.set_bench_mode(false)
		elif origin_bench >= 0:
			occupant.board_row = -1
			occupant.board_col = -1
			occupant.bench_slot = origin_bench
			occupant.position = _bench_position(origin_bench)
			occupant.set_bench_mode(true)
		else:
			_restore_drag_origin(hero)
			return
	elif hero.board_row < 0 and _deployed_count() >= population:
		status_label.text = "已达到%d人口上限" % population
		_restore_drag_origin(hero)
		return
	hero.board_row = cell.x
	hero.board_col = cell.y
	hero.bench_slot = -1
	hero.position = _cell_center(cell)
	hero.home_position = hero.position
	hero.z_index = 7 + cell.x
	hero.set_bench_mode(false)

func _place_hero_on_bench(hero, slot: int) -> void:
	var occupant = _hero_in_bench(slot, hero)
	if occupant != null:
		var origin_slot: int = hero.bench_slot
		if origin_slot < 0:
			status_label.text = "该候选格已有队员"
			_restore_drag_origin(hero)
			return
		occupant.bench_slot = origin_slot
		occupant.position = _bench_position(origin_slot)
	hero.board_row = -1
	hero.board_col = -1
	hero.bench_slot = slot
	hero.position = _bench_position(slot)
	hero.home_position = hero.position
	hero.z_index = 35
	hero.set_bench_mode(true)

func _restore_drag_origin(hero) -> void:
	if drag_origin.is_empty():
		return
	hero.board_row = drag_origin.row
	hero.board_col = drag_origin.col
	hero.bench_slot = drag_origin.bench
	hero.position = drag_origin.position
	hero.z_index = drag_origin.z

func _select_hero(hero) -> void:
	if is_instance_valid(selected_hero):
		selected_hero.selected = false
		selected_hero.queue_redraw()
	selected_hero = hero
	selected_hero.selected = true
	selected_hero.queue_redraw()

func _clear_selection() -> void:
	if is_instance_valid(selected_hero):
		selected_hero.selected = false
		selected_hero.queue_redraw()
	selected_hero = null

func _hero_at_position(pos: Vector2):
	var result = null
	var best := INF
	for hero in heroes:
		if is_instance_valid(hero) and hero.visible and not hero.battle_dead:
			var on_board: bool = hero.board_row >= 0
			var bounds := Rect2(hero.position + Vector2(-48,-180),Vector2(96,205)) if on_board else Rect2(hero.position + Vector2(-38,-75),Vector2(76,110))
			if not bounds.has_point(pos): continue
			var distance: float = (hero.position+Vector2(0,-50 if on_board else -25)).distance_to(pos)
			if distance < best:
				best = distance
				result = hero
	return result

func _hero_at_cell(cell: Vector2i, excluded = null):
	for hero in heroes:
		if hero == excluded or not is_instance_valid(hero) or hero.battle_dead:
			continue
		if state == GameState.BATTLE_RUNNING:
			if hero.active_in_battle and hero.battle_cell == cell:
				return hero
		elif hero.board_row == cell.x and hero.board_col == cell.y:
			return hero
	return null

func _hero_in_bench(slot: int, excluded = null):
	for hero in heroes:
		if hero != excluded and is_instance_valid(hero) and hero.bench_slot == slot:
			return hero
	return null

func _enemy_at_cell(cell: Vector2i):
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.battle_cell == cell:
			return enemy
	return null

func _free_bench_slot() -> int:
	for slot in range(BENCH_SIZE):
		if _hero_in_bench(slot) == null:
			return slot
	return -1

func _deployed_count() -> int:
	var count := 0
	for hero in heroes:
		if is_instance_valid(hero) and hero.board_row >= 0:
			count += 1
	return count

func _bench_position(slot: int) -> Vector2:
	return BENCH_START + Vector2(BENCH_STEP * slot, 0)

func _bench_slot_at(pos: Vector2) -> int:
	if abs(pos.y - BENCH_START.y) > 55.0:
		return -1
	var slot := int(round((pos.x - BENCH_START.x) / BENCH_STEP))
	return slot if slot >= 0 and slot < BENCH_SIZE and abs(pos.x - _bench_position(slot).x) <= 40.0 else -1

func _cell_center(cell: Vector2i) -> Vector2:
	if painted_board: return BoardGeometry.center(cell)
	return BOARD_ORIGIN + Vector2((float(cell.y) + 0.5) * CELL_SIZE.x, (float(cell.x) + 0.5) * CELL_SIZE.y)

func _screen_to_cell(pos: Vector2) -> Vector2i:
	if painted_board: return BoardGeometry.cell_at(pos)
	var col := int(floor((pos.x - BOARD_ORIGIN.x) / CELL_SIZE.x))
	var row := int(floor((pos.y - BOARD_ORIGIN.y) / CELL_SIZE.y))
	return Vector2i(row, col)

func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < ROWS and cell.y >= 0 and cell.y < COLS

func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _navigation_distance(start: Vector2i, goal: Vector2i) -> int:
	if start == goal:
		return 0
	var frontier: Array[Vector2i] = [start]
	var distances := {start: 0}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var next_distance: int = distances[current] + 1
		for direction in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var candidate: Vector2i = current + direction
			if not _valid_cell(candidate) or candidate == CENTER_CELL or distances.has(candidate):
				continue
			if candidate == goal:
				return next_distance
			distances[candidate] = next_distance
			frontier.append(candidate)
	return 999

func _float_text(pos: Vector2, content: String, color: Color) -> void:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos - Vector2(100, 20)
	label.size = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.9))
	label.z_index = 1950
	add_child(label)
	floating.append({"label":label,"time":0.0,"y":label.position.y})

func _update_ui() -> void:
	coins_label.text = "金币  %d" % coins
	population_label.text = "人口  %d / %d" % [_deployed_count(), population]
	escort_label.text = "唐僧  %d / %d" % [int(escort.health), int(escort.max_health)] if is_instance_valid(escort) else "唐僧"
	loot_label.text = "待结算  %d" % pending_loot
	wave_label.text = "波次  %d / %d" % [clampi(wave_index + 1, 0, WAVES.size()), WAVES.size()]
	pause_button.text = "继续" if battle_paused else "暂停"
	speed_button.text = "%d×" % int(battle_speed)
	pause_button.disabled = state != GameState.BATTLE_RUNNING
	speed_button.disabled = state != GameState.BATTLE_RUNNING

	if state == GameState.PREPARING:
		if status_label.text.is_empty() or status_label.text.begins_with("第"):
			status_label.text = "布置阵型后开始：唐僧位于中央，队员将自动战斗"
	elif state == GameState.BATTLE_RUNNING:
		if battle_paused:
			status_label.text = "战斗已暂停"
		elif intermission > 0.0:
			var wave: Dictionary = WAVES[wave_index]
			status_label.text = "第%d波将在 %.1f 秒后到达｜%s" % [wave_index + 1, intermission, wave.preview]
		else:
			status_label.text = "第%d波 · %s" % [wave_index + 1, WAVES[wave_index].name]

	refresh_button.text = "免费刷新 ×%d" % refresh_token if refresh_token > 0 else "刷新商店  2金"
	refresh_button.disabled = state != GameState.PREPARING or (refresh_token == 0 and coins < REFRESH_COST)
	if population < max_population:
		var level_cost: int = LEVEL_COSTS[population - 3]
		level_button.text = "升至%d人口  %d金" % [population + 1, level_cost]
		level_button.disabled = state != GameState.PREPARING or coins < level_cost
	else:
		level_button.text = "已达最大人口"
		level_button.disabled = true
	start_button.disabled = state != GameState.PREPARING or _deployed_count() == 0

	for i in range(shop_buttons.size()):
		var button := shop_buttons[i]
		if i >= shop_types.size() or shop_types[i].is_empty():
			button.text = "已售出"
			button.disabled = true
			continue
		var unit_type := shop_types[i]
		var data: Dictionary = HeroScene.UNIT_DATA[unit_type]
		var quality: String = data.quality
		var cost: int = HeroScene.QUALITY_DATA[quality].cost
		button.text = "%d\n%s\n[%s色]  %d金币\n%s" % [i + 1, data.name, QUALITY_NAMES[quality], cost, data.skill1]
		button.disabled = state != GameState.PREPARING or coins < cost or _free_bench_slot() < 0
		button.add_theme_stylebox_override("normal", _button_box(QUALITY_COLORS[quality].darkened(0.48), QUALITY_COLORS[quality]))

	var has_selection := is_instance_valid(selected_hero)
	sell_button.visible = has_selection and state == GameState.PREPARING
	lock_button.visible = has_selection and state == GameState.PREPARING
	if has_selection:
		var hero = selected_hero
		var data: Dictionary = hero.skill_data()
		var location := "上场" if hero.board_row >= 0 else "候选区"
		var skill2: String = data.skill2
		var skill3: String = data.skill3
		info_label.text = "%s  %s\n%s品质 · %d星 · %s\n\n生命  %d    攻击  %d\n攻击距离  %d格\n\n技能：%s\n%s\n%s" % ["★".repeat(hero.star), hero.display_name, QUALITY_NAMES[hero.quality], hero.star, location, int(hero.max_health), int(hero.damage), hero.attack_range_cells, data.skill1, skill2, skill3]
		var copies := int(pow(3, hero.star - 1))
		var raw_value: int = hero.cost * copies
		var refund := raw_value if hero.star == 1 else maxi(1, int(floor(raw_value * 0.7)))
		sell_button.text = "出售：返还 %d 金币" % refund
		lock_button.text = "合成锁定：%s" % ("开" if hero.merge_locked else "关")
	else:
		info_label.text = "选择一名队员查看详情\n\n自动战斗规则\n敌人进攻唐僧\n围绕唐僧3格内走位\n边缘队员可向内靠拢\n最小技能试玩\n击杀金币战后再结算"

func _draw() -> void:
	if state == GameState.PREPARING:
		for row in range(ROWS):
			for col in range(COLS):
				var cell := Vector2i(row, col)
				var rect := Rect2(BOARD_ORIGIN + Vector2(col * CELL_SIZE.x, row * CELL_SIZE.y), CELL_SIZE)
				var color := Color(0.25, 0.75, 0.45, 0.055)
				if cell == CENTER_CELL:
					color = Color(1.0, 0.67, 0.12, 0.14)
				if painted_board:
					var points := BoardGeometry.polygon(cell)
					draw_colored_polygon(points,color)
					points.append(points[0])
					draw_polyline(points,Color(0.82,0.75,0.57,0.32),1.5,true)
				else:
					draw_rect(rect.grow(-5), color, true)
	for slot in range(BENCH_SIZE):
		var center := _bench_position(slot)
		draw_style_box(_button_box(Color(0.18, 0.16, 0.13, 0.92), Color(0.48, 0.43, 0.34)), Rect2(center - Vector2(37, 45), Vector2(74, 90)))
