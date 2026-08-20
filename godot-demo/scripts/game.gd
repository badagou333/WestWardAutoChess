extends Node2D

const FoodUnitScene = preload("res://scripts/unit.gd")
const RatEnemyScene = preload("res://scripts/enemy.gd")
const ProjectileScene = preload("res://scripts/projectile.gd")
const MergeEffectScene = preload("res://scripts/merge_effect.gd")
const BATTLEFIELD_TEXTURE = preload("res://art/environment/battlefield.png")

enum GameState { PREPARING, WAVE_RUNNING, WAVE_CLEARED, GAME_WON, GAME_LOST }

const BOARD_ORIGIN := Vector2(285, 120)
const CELL_SIZE := Vector2(110, 128)
const ROWS := 3
const COLS := 6
const BASE_X := 145.0
const ENEMY_SPAWN_X := 1175.0
const BENCH_Y := 665.0
const BENCH_START_X := 542.0
const BENCH_STEP := 82.0

var coins := 100
var base_health := 10
var current_wave := 0
var state := GameState.PREPARING
var units: Array = []
var enemies: Array = []
var shop_types: Array[String] = []
var selected_unit
var dragged_unit
var drag_origin := {}
var dragging := false
var spawned_this_wave := 0
var enemies_to_spawn := 0
var spawn_cooldown := 0.0
var wave_clear_delay := 0.0
var rng := RandomNumberGenerator.new()

var coins_label: Label
var health_label: Label
var wave_label: Label
var status_label: Label
var unit_info_label: Label
var shop_buttons: Array[Button] = []
var refresh_button: Button
var next_wave_button: Button
var sell_button: Button
var restart_button: Button
var overlay: ColorRect
var result_label: Label
var background: TextureRect

const UNIT_ROLES := {
	"corn": "稳定远程",
	"chili": "范围爆发",
	"potato": "高血阻挡",
	"coffee": "邻近加速"
}

const UNIT_ACCENTS := {
	"corn": Color("dba928"),
	"chili": Color("c84b36"),
	"potato": Color("a86b36"),
	"coffee": Color("71503b")
}

func _ready() -> void:
	rng.randomize()
	_create_background()
	_create_interface()
	_refresh_shop(false)
	_update_ui()
	queue_redraw()

func _create_background() -> void:
	background = TextureRect.new()
	background.texture = BATTLEFIELD_TEXTURE
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)

func _create_interface() -> void:
	var title_label := _make_label(Vector2(22, 10), Vector2(220, 54), 27, Color("ffe083"))
	title_label.text = "今晚别偷粮"
	title_label.add_theme_color_override("font_shadow_color", Color(0.18, 0.08, 0.02, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	coins_label = _make_label(Vector2(250, 18), Vector2(165, 42), 22, Color("ffe375"))
	health_label = _make_label(Vector2(425, 18), Vector2(175, 42), 22, Color("ffb09b"))
	wave_label = _make_label(Vector2(610, 18), Vector2(170, 42), 22, Color("eaf6d2"))
	status_label = _make_label(Vector2(790, 17), Vector2(455, 46), 19, Color("fff5d4"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var instructions := _make_label(Vector2(25, 541), Vector2(335, 70), 15, Color("e8dfc4"))
	instructions.text = "购买后拖入棋盘｜3个同类同星自动升星\n拖动可换位，点击单位查看并出售\n快捷键：1/2/3购买｜R刷新｜空格开战"

	for i in range(3):
		var button := Button.new()
		button.position = Vector2(25 + i * 150, 615)
		button.size = Vector2(140, 76)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_shop_pressed.bind(i))
		_style_button(button, Color("8e693d"))
		add_child(button)
		shop_buttons.append(button)

	refresh_button = Button.new()
	refresh_button.text = "刷新商店  5金币"
	refresh_button.position = Vector2(365, 552)
	refresh_button.size = Vector2(100, 48)
	refresh_button.visible = true
	refresh_button.tooltip_text = "花费5金币重新抽取三张商店卡牌（R）"
	refresh_button.pressed.connect(_on_refresh_pressed)
	_style_button(refresh_button, Color("55734a"))
	add_child(refresh_button)

	next_wave_button = Button.new()
	next_wave_button.position = Vector2(1030, 615)
	next_wave_button.size = Vector2(220, 72)
	next_wave_button.add_theme_font_size_override("font_size", 22)
	next_wave_button.text = "开始第 1 波"
	next_wave_button.tooltip_text = "准备完成后开始下一波敌人（空格）"
	next_wave_button.pressed.connect(_start_next_wave)
	_style_button(next_wave_button, Color("b7792a"))
	add_child(next_wave_button)

	unit_info_label = _make_label(Vector2(965, 116), Vector2(280, 205), 17, Color("fff4cf"))
	unit_info_label.text = "点击一个守卫\n查看详细属性"
	unit_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	sell_button = Button.new()
	sell_button.text = "出售选中单位"
	sell_button.position = Vector2(1010, 300)
	sell_button.size = Vector2(190, 42)
	sell_button.disabled = true
	sell_button.visible = false
	sell_button.pressed.connect(_sell_selected)
	_style_button(sell_button, Color("8e493e"))
	add_child(sell_button)

	overlay = ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.08, 0.06, 0.04, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	result_label = Label.new()
	result_label.position = Vector2(340, 205)
	result_label.size = Vector2(600, 190)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 42)
	overlay.add_child(result_label)

	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.position = Vector2(510, 430)
	restart_button.size = Vector2(260, 70)
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.pressed.connect(_restart_game)
	_style_button(restart_button, Color("b7792a"))
	overlay.add_child(restart_button)

func _style_button(button: Button, accent: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("fff5d8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff0b0"))
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.73, 0.62, 0.55))
	button.add_theme_stylebox_override("normal", _make_button_box(accent, Color("5b381f"), 4))
	button.add_theme_stylebox_override("hover", _make_button_box(accent.lightened(0.12), Color("ffe08a"), 4))
	button.add_theme_stylebox_override("pressed", _make_button_box(accent.darkened(0.12), Color("ffe08a"), 2))
	button.add_theme_stylebox_override("disabled", _make_button_box(Color(0.22, 0.22, 0.19, 0.82), Color(0.35, 0.31, 0.25, 0.8), 0))

func _make_button_box(color: Color, border_color: Color, shadow_size: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0.13, 0.07, 0.03, 0.55)
	box.shadow_size = shadow_size
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _process(delta: float) -> void:
	if state == GameState.GAME_WON or state == GameState.GAME_LOST:
		return
	_process_units(delta)
	_process_enemies(delta)
	if state == GameState.WAVE_RUNNING:
		_process_wave(delta)
	_update_ui()

func _process_units(delta: float) -> void:
	for unit in units.duplicate():
		if not is_instance_valid(unit) or unit.lane < 0:
			continue
		unit.cooldown = max(0.0, unit.cooldown - delta)
		if unit.cooldown > 0.0:
			continue
		var target = _find_target_for(unit)
		if target == null:
			continue
		var interval: float = unit.attack_interval
		if _has_coffee_buff(unit):
			interval *= 0.78
		unit.cooldown = interval
		unit.play_attack()
		if unit.unit_type == "potato":
			target.take_damage(unit.damage)
			_show_damage(target.global_position, unit.damage)
		else:
			_fire_projectile(unit, target)

func _find_target_for(unit):
	var best = null
	var best_x := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.lane != unit.lane:
			continue
		var distance_x: float = enemy.position.x - unit.position.x
		if distance_x >= -20.0 and distance_x <= unit.attack_range and enemy.position.x < best_x:
			best = enemy
			best_x = enemy.position.x
	return best

func _has_coffee_buff(unit) -> bool:
	if unit.unit_type == "coffee":
		return false
	for other in units:
		if is_instance_valid(other) and other.lane == unit.lane and other.unit_type == "coffee" and abs(other.column - unit.column) <= 1:
			return true
	return false

func _fire_projectile(unit, target) -> void:
	var projectile = ProjectileScene.new()
	projectile.add_to_group("game_transient")
	projectile.global_position = unit.global_position + Vector2(24, -4)
	var splash := 72.0 if unit.unit_type == "chili" else 0.0
	projectile.setup(target, unit.damage, unit.unit_type, splash)
	projectile.impact.connect(_on_projectile_impact)
	add_child(projectile)

func _on_projectile_impact(target, damage: float, splash: float, hit_position: Vector2) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	target.take_damage(damage)
	_show_damage(hit_position, damage)
	if splash > 0.0:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy != target and not enemy.dead and enemy.global_position.distance_to(hit_position) <= splash:
				enemy.take_damage(damage * 0.55)
				_show_damage(enemy.global_position, damage * 0.55)

func _process_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		enemy.attack_cooldown = max(0.0, enemy.attack_cooldown - delta)
		var blocker = _find_blocker(enemy)
		if blocker != null:
			if enemy.attack_cooldown <= 0.0:
				enemy.attack_cooldown = enemy.attack_interval
				enemy.play_attack()
				if blocker.take_damage(enemy.damage):
					_remove_unit(blocker)
		else:
			enemy.position.x -= enemy.speed * delta
			if enemy.position.x <= BASE_X:
				base_health = max(0, base_health - enemy.base_damage)
				enemy.dead = true
				enemies.erase(enemy)
				enemy.queue_free()
				_shake_board()
				if base_health <= 0:
					_finish_game(false)

func _find_blocker(enemy):
	var closest = null
	var closest_distance := INF
	for unit in units:
		if not is_instance_valid(unit) or unit.lane != enemy.lane:
			continue
		var distance_x: float = enemy.position.x - unit.position.x
		if distance_x >= -5.0 and distance_x < 56.0 and distance_x < closest_distance:
			closest = unit
			closest_distance = distance_x
	return closest

func _process_wave(delta: float) -> void:
	if spawned_this_wave < enemies_to_spawn:
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			_spawn_enemy()
			spawned_this_wave += 1
			spawn_cooldown = max(0.52, 1.25 - current_wave * 0.075)
		return
	if enemies.is_empty():
		wave_clear_delay += delta
		if wave_clear_delay >= 0.9:
			_complete_wave()

func _spawn_enemy() -> void:
	var enemy_type := "small"
	if current_wave >= 8 and spawned_this_wave == enemies_to_spawn - 1:
		enemy_type = "king"
	else:
		var roll := rng.randf()
		if current_wave >= 4 and roll < 0.24:
			enemy_type = "thief"
		elif current_wave >= 2 and roll < 0.54:
			enemy_type = "fat"
	var enemy = RatEnemyScene.new()
	enemy.setup(enemy_type, rng.randi_range(0, ROWS - 1), 0.88 + current_wave * 0.14)
	enemy.position = Vector2(ENEMY_SPAWN_X + rng.randf_range(0, 45), _cell_center(enemy.lane, 0).y)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.reached_base.connect(_on_enemy_reached_base)
	add_child(enemy)
	enemies.append(enemy)

func _on_enemy_defeated(enemy) -> void:
	if not enemies.has(enemy):
		return
	coins += enemy.reward
	enemies.erase(enemy)
	_show_floating_text(enemy.global_position + Vector2(0, -25), "+%d 金币" % enemy.reward, Color("ffe477"))
	enemy.play_death()

func _on_enemy_reached_base(enemy) -> void:
	# 预留给后续特殊敌人的到达事件。
	pass

func _start_next_wave() -> void:
	if state == GameState.WAVE_RUNNING or current_wave >= 8:
		return
	current_wave += 1
	state = GameState.WAVE_RUNNING
	spawned_this_wave = 0
	enemies_to_spawn = 4 + current_wave * 3
	spawn_cooldown = 0.25
	wave_clear_delay = 0.0
	_show_banner("第 %d 波来袭！" % current_wave)
	_update_ui()

func _complete_wave() -> void:
	var bonus := 18 + current_wave * 4
	coins += bonus
	if current_wave >= 8:
		_finish_game(true)
		return
	state = GameState.WAVE_CLEARED
	_refresh_shop(false)
	_show_banner("守住了！波次奖励 +%d" % bonus)
	_update_ui()

func _finish_game(won: bool) -> void:
	state = GameState.GAME_WON if won else GameState.GAME_LOST
	overlay.visible = true
	result_label.text = "粮仓保住啦！\n你击退了全部老鼠" if won else "粮仓失守……\n调整阵容再试一次"
	result_label.add_theme_color_override("font_color", Color("ffe67a") if won else Color("ff9b8d"))
	next_wave_button.disabled = true

func _restart_game() -> void:
	for transient in get_tree().get_nodes_in_group("game_transient"):
		if is_instance_valid(transient):
			transient.queue_free()
	for unit in units.duplicate():
		if is_instance_valid(unit):
			unit.queue_free()
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	units.clear()
	enemies.clear()
	coins = 100
	base_health = 10
	current_wave = 0
	spawned_this_wave = 0
	enemies_to_spawn = 0
	spawn_cooldown = 0.0
	wave_clear_delay = 0.0
	state = GameState.PREPARING
	selected_unit = null
	dragged_unit = null
	overlay.visible = false
	next_wave_button.disabled = false
	_refresh_shop(false)
	_update_ui()
	queue_redraw()

func _on_shop_pressed(index: int) -> void:
	if index >= shop_types.size() or state == GameState.GAME_WON or state == GameState.GAME_LOST:
		return
	var unit_type: String = shop_types[index]
	var cost: int = FoodUnitScene.UNIT_DATA[unit_type].cost
	var slot := _first_empty_bench_slot()
	if coins < cost:
		_show_banner("金币不够")
		return
	if slot < 0:
		_show_banner("备战区满了")
		return
	coins -= cost
	var unit = FoodUnitScene.new()
	unit.setup(unit_type)
	unit.bench_slot = slot
	add_child(unit)
	units.append(unit)
	_move_unit_visual(unit)
	shop_types[index] = _random_unit_type()
	_update_shop_buttons()
	_try_merge(unit)
	_update_ui()

func _on_refresh_pressed() -> void:
	if coins < 5:
		_show_banner("金币不够")
		return
	coins -= 5
	_refresh_shop(false)

func _refresh_shop(free := true) -> void:
	if not free and shop_types.size() > 0:
		pass
	shop_types.clear()
	for i in range(3):
		shop_types.append(_random_unit_type())
	_update_shop_buttons()

func _random_unit_type() -> String:
	var types := ["corn", "chili", "potato", "coffee"]
	return types[rng.randi_range(0, types.size() - 1)]

func _update_shop_buttons() -> void:
	if shop_buttons.is_empty() or shop_types.size() < 3:
		return
	for i in range(3):
		var data: Dictionary = FoodUnitScene.UNIT_DATA[shop_types[i]]
		shop_buttons[i].text = "%s\n%d金币｜%s" % [data.name, data.cost, UNIT_ROLES[shop_types[i]]]
		shop_buttons[i].tooltip_text = "%s：%s（快捷键%d）" % [data.name, UNIT_ROLES[shop_types[i]], i + 1]
		_style_button(shop_buttons[i], UNIT_ACCENTS[shop_types[i]])

func _unhandled_input(event: InputEvent) -> void:
	if state == GameState.GAME_WON or state == GameState.GAME_LOST:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_on_shop_pressed(0)
			KEY_2:
				_on_shop_pressed(1)
			KEY_3:
				_on_shop_pressed(2)
			KEY_R:
				_on_refresh_pressed()
			KEY_SPACE:
				_start_next_wave()
			KEY_ESCAPE:
				_select_unit(null)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer_action(event.position)
		else:
			_end_pointer_action(event.position)
	elif event is InputEventMouseMotion and dragged_unit != null:
		if event.position.distance_to(drag_origin.mouse) > 6.0:
			dragging = true
			dragged_unit.dragging = true
			dragged_unit.global_position = event.position
			dragged_unit.z_index = 20
			queue_redraw()

func _begin_pointer_action(mouse_position: Vector2) -> void:
	var unit = _unit_at_point(mouse_position)
	if unit == null:
		_select_unit(null)
		return
	dragged_unit = unit
	drag_origin = {
		"mouse": mouse_position,
		"lane": unit.lane,
		"column": unit.column,
		"bench_slot": unit.bench_slot,
		"position": unit.position
	}
	dragging = false
	_select_unit(unit)

func _end_pointer_action(mouse_position: Vector2) -> void:
	if dragged_unit == null:
		return
	if dragging:
		var cell := _point_to_cell(mouse_position)
		var bench := _point_to_bench(mouse_position)
		if cell.x >= 0 and _unit_in_cell(cell.x, cell.y, dragged_unit) == null:
			dragged_unit.lane = cell.x
			dragged_unit.column = cell.y
			dragged_unit.bench_slot = -1
		elif bench >= 0 and _unit_in_bench(bench, dragged_unit) == null:
			dragged_unit.lane = -1
			dragged_unit.column = -1
			dragged_unit.bench_slot = bench
		else:
			dragged_unit.lane = drag_origin.lane
			dragged_unit.column = drag_origin.column
			dragged_unit.bench_slot = drag_origin.bench_slot
		_move_unit_visual(dragged_unit)
		_try_merge(dragged_unit)
	dragged_unit.dragging = false
	dragged_unit.z_index = 2
	dragged_unit = null
	dragging = false
	queue_redraw()

func _unit_at_point(point: Vector2):
	for i in range(units.size() - 1, -1, -1):
		var unit = units[i]
		if is_instance_valid(unit) and unit.global_position.distance_to(point) <= 44.0:
			return unit
	return null

func _point_to_cell(point: Vector2) -> Vector2i:
	var local := point - BOARD_ORIGIN
	var column := int(floor(local.x / CELL_SIZE.x))
	var lane := int(floor(local.y / CELL_SIZE.y))
	if lane >= 0 and lane < ROWS and column >= 0 and column < COLS:
		return Vector2i(lane, column)
	return Vector2i(-1, -1)

func _point_to_bench(point: Vector2) -> int:
	for i in range(6):
		if Rect2(Vector2(BENCH_START_X + i * BENCH_STEP - 34, BENCH_Y - 34), Vector2(68, 68)).has_point(point):
			return i
	return -1

func _unit_in_cell(lane: int, column: int, except = null):
	for unit in units:
		if unit != except and is_instance_valid(unit) and unit.lane == lane and unit.column == column:
			return unit
	return null

func _unit_in_bench(slot: int, except = null):
	for unit in units:
		if unit != except and is_instance_valid(unit) and unit.bench_slot == slot:
			return unit
	return null

func _first_empty_bench_slot() -> int:
	for i in range(6):
		if _unit_in_bench(i) == null:
			return i
	return -1

func _move_unit_visual(unit) -> void:
	if unit.lane >= 0:
		unit.position = _cell_center(unit.lane, unit.column)
		unit.set_bench_mode(false)
	else:
		unit.position = Vector2(BENCH_START_X + unit.bench_slot * BENCH_STEP, BENCH_Y)
		unit.set_bench_mode(true)
	unit.queue_redraw()

func _cell_center(lane: int, column: int) -> Vector2:
	return BOARD_ORIGIN + Vector2((column + 0.5) * CELL_SIZE.x, (lane + 0.5) * CELL_SIZE.y)

func _select_unit(unit) -> void:
	if is_instance_valid(selected_unit):
		selected_unit.selected = false
		selected_unit.queue_redraw()
	selected_unit = unit
	if is_instance_valid(selected_unit):
		selected_unit.selected = true
		selected_unit.queue_redraw()
	_update_unit_info()
	queue_redraw()

func _sell_selected() -> void:
	if not is_instance_valid(selected_unit):
		return
	var refund := int(selected_unit.cost * 0.5 * pow(3, selected_unit.star - 1))
	coins += refund
	_show_floating_text(selected_unit.global_position, "+%d 金币" % refund, Color("ffe477"))
	_remove_unit(selected_unit)
	selected_unit = null
	_update_unit_info()

func _remove_unit(unit) -> void:
	if unit == selected_unit:
		selected_unit = null
	units.erase(unit)
	if is_instance_valid(unit):
		unit.queue_free()
	_update_unit_info()
	queue_redraw()

func _try_merge(preferred) -> void:
	if not is_instance_valid(preferred) or preferred.star >= 3:
		return
	var matches: Array = []
	for unit in units:
		if is_instance_valid(unit) and unit.unit_type == preferred.unit_type and unit.star == preferred.star:
			matches.append(unit)
	if matches.size() < 3:
		return
	var chosen = preferred if matches.has(preferred) else matches[0]
	if chosen.lane < 0:
		for candidate in matches:
			if candidate.lane >= 0:
				chosen = candidate
				break
	for unit in matches.slice(0, 3):
		if unit != chosen:
			units.erase(unit)
			unit.queue_free()
	chosen.upgrade()
	var effect = MergeEffectScene.new()
	effect.add_to_group("game_transient")
	effect.position = chosen.position
	add_child(effect)
	_show_floating_text(chosen.global_position + Vector2(0, -52), "合成！%s" % "★".repeat(chosen.star), Color("fff17a"))
	_move_unit_visual(chosen)
	_select_unit(chosen)
	_try_merge(chosen)

func _update_ui() -> void:
	coins_label.text = "金币  %d" % coins
	health_label.text = "粮仓  %d / 10" % base_health
	wave_label.text = "波次  %d / 8" % current_wave
	match state:
		GameState.PREPARING:
			status_label.text = "先购买守卫，再开始第一波"
		GameState.WAVE_RUNNING:
			status_label.text = "老鼠来袭：%d 只仍在场" % enemies.size()
		GameState.WAVE_CLEARED:
			status_label.text = "波次结束，可以调整阵容"
	next_wave_button.disabled = state == GameState.WAVE_RUNNING
	next_wave_button.text = "战斗中……" if state == GameState.WAVE_RUNNING else "开始第 %d 波" % (current_wave + 1)
	for i in range(shop_buttons.size()):
		if i < shop_types.size():
			var cost: int = FoodUnitScene.UNIT_DATA[shop_types[i]].cost
			shop_buttons[i].disabled = coins < cost or _first_empty_bench_slot() < 0
	refresh_button.disabled = coins < 5
	_update_unit_info()

func _update_unit_info() -> void:
	if not is_instance_valid(selected_unit):
		unit_info_label.visible = false
		sell_button.visible = false
		sell_button.disabled = true
		return
	unit_info_label.visible = true
	sell_button.visible = true
	unit_info_label.text = "%s  %s\n生命：%d / %d\n攻击：%d\n攻速：%.2f秒\n%s" % [
		selected_unit.display_name,
		"★".repeat(selected_unit.star),
		int(selected_unit.health), int(selected_unit.max_health),
		int(selected_unit.damage), selected_unit.attack_interval,
		"阻挡型前排" if selected_unit.is_blocker else ("邻近攻速辅助" if selected_unit.unit_type == "coffee" else "远程自动攻击")
	]
	sell_button.disabled = false

func _show_damage(world_position: Vector2, amount: float) -> void:
	_show_floating_text(world_position + Vector2(0, -24), "-%d" % int(amount), Color("fff2de"))

func _show_floating_text(world_position: Vector2, text_value: String, color: Color) -> void:
	var label := Label.new()
	label.add_to_group("game_transient")
	label.text = text_value
	label.position = world_position - Vector2(45, 12)
	label.size = Vector2(90, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	label.z_index = 50
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 38, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)

func _show_banner(text_value: String) -> void:
	var label := Label.new()
	label.add_to_group("game_transient")
	label.text = text_value
	label.position = Vector2(370, 300)
	label.size = Vector2(540, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("fff0a1"))
	label.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.02, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.z_index = 60
	add_child(label)
	label.scale = Vector2(0.7, 0.7)
	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

func _shake_board() -> void:
	var original := position
	var tween := create_tween()
	tween.tween_property(self, "position", original + Vector2(7, 0), 0.04)
	tween.tween_property(self, "position", original + Vector2(-7, 0), 0.05)
	tween.tween_property(self, "position", original, 0.05)

func _draw() -> void:
	# 背景使用完整插画，这里只叠加半透明HUD带与战术棋盘。
	draw_rect(Rect2(0, 0, 1280, 76), Color(0.10, 0.08, 0.035, 0.78), true)
	draw_rect(Rect2(0, 528, 1280, 192), Color(0.11, 0.075, 0.035, 0.84), true)
	draw_line(Vector2(0, 76), Vector2(1280, 76), Color(1.0, 0.83, 0.37, 0.45), 2)
	draw_line(Vector2(0, 528), Vector2(1280, 528), Color(1.0, 0.83, 0.37, 0.38), 2)

	# 3×6棋盘
	for lane in range(ROWS):
		for column in range(COLS):
			var rect := Rect2(BOARD_ORIGIN + Vector2(column * CELL_SIZE.x, lane * CELL_SIZE.y), CELL_SIZE - Vector2(5, 5))
			var color := Color(0.41, 0.58, 0.20, 0.30) if (lane + column) % 2 == 0 else Color(0.66, 0.72, 0.25, 0.24)
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0.92, 0.84, 0.43, 0.64), false, 2)

	# 备战区
	draw_string(ThemeDB.fallback_font, Vector2(530, 608), "备战区", HORIZONTAL_ALIGNMENT_LEFT, 120, 18, Color("eadcb7"))
	for i in range(6):
		var slot_rect := Rect2(Vector2(BENCH_START_X + i * BENCH_STEP - 34, BENCH_Y - 34), Vector2(68, 68))
		draw_rect(slot_rect, Color(0.20, 0.23, 0.15, 0.90), true)
		draw_rect(slot_rect, Color("b9a56b"), false, 2)

	# 选中信息区域
	if is_instance_valid(selected_unit):
		draw_rect(Rect2(955, 105, 300, 255), Color(0.16, 0.105, 0.055, 0.88), true)
		draw_rect(Rect2(955, 105, 300, 255), Color("d1b76b"), false, 3)

	# 拖放时突出目标格。
	if dragging and dragged_unit != null:
		var mouse_pos := get_viewport().get_mouse_position()
		var cell := _point_to_cell(mouse_pos)
		if cell.x >= 0:
			var highlight := Rect2(BOARD_ORIGIN + Vector2(cell.y * CELL_SIZE.x, cell.x * CELL_SIZE.y), CELL_SIZE - Vector2(5, 5))
			var valid := _unit_in_cell(cell.x, cell.y, dragged_unit) == null
			draw_rect(highlight, Color(0.35, 1.0, 0.45, 0.35) if valid else Color(1.0, 0.25, 0.25, 0.4), true)
