extends "res://scripts/game.gd"

const ArtActor = preload("res://art/reviews/six-role-battle/actor.gd")
const LINEUP := [
	["guard_monk", "护寺棍僧", [500, 16, 1], Vector2i(2, 4)],
	["wild_hunter", "山野猎户", [260, 26, 1], Vector2i(3, 4)],
	["herbal_spirit_child", "药灵童子", [190, 26, 3], Vector2i(3, 3)],
	["sparrow_spirit", "山雀精", [190, 20, 3], Vector2i(1, 5)],
	["foxfire_imp", "狐火小妖", [200, 24, 3], Vector2i(1, 4)],
]
var actors: Array = []
var strikes: Array = []
var missiles: Array = []
var marks: Array = []
var elapsed := 0.0
var result_delay := -1.0
var anchors_enabled := true
var motion_frames_enabled := true
var motion_toggle: Button
var summary: Label
var counts := {"attacks": 0, "projectiles": 0, "hits": 0, "heals": 0, "cancelled": 0}

func _ready() -> void:
	DisplayServer.window_set_title("六角色 · 动作优化试玩")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_background()
	_create_escort()
	escort.set_process(false)
	escort.process_mode = Node.PROCESS_MODE_PAUSABLE
	escort.z_index = int(escort.position.y + 35)
	_create_review_ui()
	reset_trial()

func _create_review_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 100
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var panel := ColorRect.new()
	panel.position = Vector2(28, 24); panel.size = Vector2(1864, 162)
	panel.color = Color("182831")
	ui.add_child(panel)
	var title := Label.new()
	title.position = Vector2(52, 35)
	title.text = "六角色 · 动作优化试玩"
	title.add_theme_font_size_override("font_size", 30)
	ui.add_child(title)
	summary = Label.new(); summary.position = Vector2(52, 85)
	summary.add_theme_font_size_override("font_size", 20); ui.add_child(summary)
	var note := Label.new(); note.position = Vector2(52, 125)
	note.text = "五名初始英雄迎战熊山君 · 基础动作与美术试接入 · 数值为测试值，技能暂不展开"
	note.add_theme_font_size_override("font_size", 19); ui.add_child(note)
	for item in [["开始 / 重开", 1010, reset_trial], ["暂停 / 继续", 1190, _toggle_pause], ["切换 1× / 2×", 1370, _toggle_speed], ["退场检查", 1550, retreat_check]]:
		var button := Button.new(); button.text = item[0]
		button.position = Vector2(item[1], 63); button.size = Vector2(165, 47)
		button.pressed.connect(item[2]); ui.add_child(button)
	motion_toggle = Button.new(); motion_toggle.text = "补帧：开"
	motion_toggle.position = Vector2(1740, 63); motion_toggle.size = Vector2(130, 47)
	motion_toggle.pressed.connect(_toggle_motion_frames); ui.add_child(motion_toggle)
	var toggle := CheckButton.new(); toggle.text = "显示落脚点"; toggle.button_pressed = true
	toggle.position = Vector2(1570, 122)
	toggle.toggled.connect(func(on: bool):
		anchors_enabled = on
		for actor in actors: actor.show_anchor = on
	)
	ui.add_child(toggle)
	var bottom := ColorRect.new(); bottom.position = Vector2(28, 917); bottom.size = Vector2(1864, 139)
	bottom.color = Color("182831"); ui.add_child(bottom)
	var instructions := Label.new(); instructions.position = Vector2(52, 937)
	instructions.text = "观察：落脚点是否稳定 · 前排是否遮住后排 · 飞弹是否从手边发出 · 命中后才扣血 · 退场是否淡出\n药灵童子优先治疗受伤队友或唐僧；未受伤时待机。空格暂停，R 重开，M 切换补帧。\n棍僧、猎户、熊山君各增加 4 个移动与 4 个攻击姿势；点击补帧开关可对比。其他三名角色沿用现有施法动作。"
	instructions.add_theme_font_size_override("font_size", 20); ui.add_child(instructions)

func reset_trial() -> void:
	get_tree().paused = false; battle_paused = false; battle_speed = 1
	for actor in actors: actor.queue_free()
	actors.clear(); heroes.clear(); enemies.clear(); strikes.clear(); missiles.clear(); marks.clear()
	counts = {"attacks": 0, "projectiles": 0, "hits": 0, "heals": 0, "cancelled": 0}
	elapsed = 0; result_delay = -1
	escort.reset()
	state = GameState.BATTLE_RUNNING
	for entry in LINEUP:
		var hero = ArtActor.new(); hero.setup_role(entry[0], entry[1], entry[2])
		hero.board_row = entry[3].x; hero.board_col = entry[3].y
		hero.battle_cell = entry[3]; hero.home_cell = entry[3]
		hero.position = _cell_center(entry[3]); hero.cooldown = 0.24 + heroes.size() * 0.11
		add_child(hero); heroes.append(hero); actors.append(hero)
	var boss = ArtActor.new(); boss.setup_role("bear_lord", "熊山君", [1500, 38, 1], true)
	boss.battle_cell = Vector2i(2, 6); boss.home_cell = boss.battle_cell
	boss.position = _cell_center(boss.battle_cell); boss.facing = -1; boss.attack_interval = 1.15
	boss.defeated.connect(_on_enemy_defeated)
	add_child(boss); enemies.append(boss); actors.append(boss)
	for actor in actors:
		actor.show_anchor = anchors_enabled
		actor.use_motion_frames = motion_frames_enabled
		actor.tick(0)
	_update_ui(); queue_redraw()

func _process(delta: float) -> void:
	step(minf(delta, 0.05) * battle_speed)

func step(delta: float) -> void:
	if battle_paused:
		return
	# Bound each integration step so doubled speed cannot skip the release instant.
	var remaining := delta
	while remaining > 0.000001:
		var slice := minf(remaining, 1.0 / 120)
		_step(slice)
		remaining -= slice

func _step(delta: float) -> void:
	for actor in actors: actor.tick(delta)
	if state == GameState.BATTLE_RUNNING:
		elapsed += delta
		_resolve_strikes(delta)
		_process_heroes(delta)
		_process_enemies(delta)
		if enemies.is_empty() or escort.dead:
			if result_delay < 0: result_delay = 0.8
			result_delay -= delta
			if result_delay <= 0: _finish_battle(not escort.dead)
	for mark in marks: mark.time -= delta
	marks = marks.filter(func(mark): return mark.time > 0)
	_update_ui(); queue_redraw()

func _process_heroes(delta: float) -> void:
	for hero in heroes:
		if hero.dead: continue
		hero.cooldown = maxf(0, hero.cooldown - delta)
		hero.move_cooldown = maxf(0, hero.move_cooldown - delta)
		var healing: bool = hero.role == "herbal_spirit_child"
		var target = _healing_target(hero) if healing else _nearest_enemy_to_cell(hero.battle_cell)
		if target == null: continue
		var cell: Vector2i = CENTER_CELL if target == escort else target.battle_cell
		if _cell_distance(hero.battle_cell, cell) <= hero.attack_range_cells:
			if hero.cooldown <= 0 and hero.move_left <= 0 and hero.pose != "basic_attack":
				hero.cooldown = hero.attack_interval
				queue_attack(hero, target, healing)
		elif hero.move_cooldown <= 0 and hero.pose != "basic_attack":
			_move_hero_toward(hero, cell)

func _healing_target(hero):
	var result = null
	var ratio := 1.0
	for ally in heroes + [escort]:
		if ally.dead: continue
		var candidate: float = ally.health / ally.max_health
		if candidate < ratio:
			ratio = candidate; result = ally
	return result

func _process_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if enemy.dead: continue
		enemy.attack_cooldown = maxf(0, enemy.attack_cooldown - delta)
		enemy.move_cooldown = maxf(0, enemy.move_cooldown - delta)
		var target = _adjacent_blocking_hero(enemy.battle_cell)
		if target == null and _cell_distance(enemy.battle_cell, CENTER_CELL) <= 1: target = escort
		if target != null:
			if enemy.attack_cooldown <= 0 and enemy.move_left <= 0 and enemy.pose != "basic_attack":
				enemy.attack_cooldown = enemy.attack_interval
				queue_attack(enemy, target, false)
		elif enemy.move_cooldown <= 0 and enemy.pose != "basic_attack":
			_move_enemy_toward_center(enemy)

func queue_attack(actor, target, healing: bool) -> void:
	actor.face(target.position); actor.play_attack(); counts.attacks += 1
	strikes.append({"source": actor, "target": target, "serial": actor.attack_serial, "healing": healing, "amount": actor.damage})

func _target_alive(target) -> bool:
	return is_instance_valid(target) and not target.dead

func _resolve_strikes(delta: float) -> void:
	for missile in missiles.duplicate():
		if not _target_alive(missile.target):
			missiles.erase(missile); counts.cancelled += 1; continue
		missile.time += delta
		var aim: Vector2 = missile.target.position + Vector2(0, -35)
		missile.position = missile.from.lerp(aim, minf(1, missile.time / 0.25))
		if missile.time >= 0.25:
			apply_hit(missile.target, missile.amount, missile.healing)
			missiles.erase(missile)

	for strike in strikes.duplicate():
		if not _target_alive(strike.source) or not _target_alive(strike.target) or strike.source.attack_serial != strike.serial or strike.source.pose != "basic_attack":
			strikes.erase(strike); counts.cancelled += 1; continue
		if strike.source.pose_time < strike.source.impact_delay(): continue
		strikes.erase(strike)
		var action: Dictionary = strike.source.manifest.actions.basic_attack
		if action.has("spawn_vfx"):
			var from: Vector2 = strike.source.emission_position()
			missiles.append({"target": strike.target, "from": from, "position": from, "time": 0.0, "healing": strike.healing, "amount": strike.amount, "texture": strike.source.effects[action.spawn_vfx]})
			counts.projectiles += 1
		else:
			apply_hit(strike.target, strike.amount, strike.healing)
			strike.source.impact_stop = 0.035

func apply_hit(target, amount: float, healing: bool) -> void:
	if not _target_alive(target): return
	if healing:
		target.heal(amount) if target != escort else _heal_escort(amount)
		counts.heals += 1
	else:
		target.take_damage(amount); counts.hits += 1
		if target != escort: target.impact_stop = 0.025
	marks.append({"position": target.position + Vector2(0, -35), "time": 0.20, "healing": healing})

func _heal_escort(amount: float) -> void:
	escort.health = minf(escort.max_health, escort.health + amount); escort.queue_redraw()

func _tween_to_cell(node: Node2D, cell: Vector2i) -> void:
	node.move_to(_cell_center(cell))

func _on_enemy_defeated(enemy) -> void:
	enemies.erase(enemy)

func _finish_battle(victory: bool) -> void:
	state = GameState.RESULT
	strikes.clear(); missiles.clear()
	status_label.text = "试战斗完成 · 熊山君退场" if victory else "护送失败 · 可重开调整"

func retreat_check() -> void:
	get_tree().paused = false; battle_paused = false
	strikes.clear(); missiles.clear(); state = GameState.RESULT
	for actor in actors: actor.take_damage(actor.max_health)
	status_label.text = "六角色退场检查 · 保持后淡出，可重开"

func _toggle_pause() -> void:
	battle_paused = not battle_paused
	get_tree().paused = battle_paused
	_update_ui()

func _toggle_speed() -> void:
	battle_speed = 2.0 if battle_speed == 1.0 else 1.0
	_update_ui()

func _toggle_motion_frames() -> void:
	motion_frames_enabled = not motion_frames_enabled
	motion_toggle.text = "补帧：开" if motion_frames_enabled else "补帧：关"
	for actor in actors:
		actor.use_motion_frames = motion_frames_enabled
		actor.update_frame()
		actor.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _toggle_pause()
		if event.keycode == KEY_R: reset_trial()
		if event.keycode == KEY_M: _toggle_motion_frames()

func _update_ui() -> void:
	if summary == null: return
	if status_label == null: status_label = Label.new(); add_child(status_label); status_label.hide()
	var caption := status_label.text if state == GameState.RESULT else ("已暂停" if battle_paused else "战斗中")
	summary.text = "%s · %.1f 秒 · %d× · 命中 %d · 治疗 %d · 唐僧 %d/%d" % [caption, elapsed, int(battle_speed), counts.hits, counts.heals, int(escort.health), int(escort.max_health)]

func _draw() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			draw_rect(Rect2(BOARD_ORIGIN + Vector2(col * CELL_SIZE.x, row * CELL_SIZE.y), CELL_SIZE).grow(-3), Color(0.16, 0.26, 0.26, 0.16), false, 2)
	# Projectiles are redrawn by a dedicated foreground canvas node below.

func _enter_tree() -> void:
	var foreground := Node2D.new()
	foreground.z_index = 2000
	foreground.draw.connect(func():
		for missile in missiles:
			var texture: Texture2D = missile.texture
			var heading: Vector2 = missile.target.position + Vector2(0, -35) - missile.from
			foreground.draw_set_transform(missile.position, heading.angle())
			foreground.draw_texture(texture, -Vector2(texture.get_size()) / 2)
		foreground.draw_set_transform(Vector2.ZERO)
		for mark in marks:
			foreground.draw_arc(mark.position, 15 + (0.2 - mark.time) * 30, 0, TAU, 24, Color("75eba3") if mark.healing else Color("ffd28a"), 2)
	)
	add_child(foreground)
	foreground.set_process(true)
	foreground.ready.connect(func(): get_tree().process_frame.connect(foreground.queue_redraw))
