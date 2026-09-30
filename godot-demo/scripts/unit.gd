class_name EscortHero
extends Node2D

const Catalog = preload("res://scripts/data/demo_units.gd")
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
const UNIT_DATA = Catalog.HEROES
const QUALITY_DATA := {"white": {"name": "白色", "color": Color("e9e5db"), "cost": 1}}
var unit_type := "guard_monk"
var display_name := ""
var quality := "white"
var star := 1
var cost := 1
var board_row := -1
var board_col := -1
var bench_slot := -1
var battle_cell := Vector2i(-1,-1)
var home_cell := Vector2i(-1,-1)
var home_position := Vector2.ZERO
var max_health := 100.0
var health := 100.0
var damage := 10.0
var attack_interval := 1.0
var move_interval := 0.5
var attack_range_cells := 1
var cooldown := 0.0
var move_cooldown := 0.0
var mana := 0.0
var max_mana := 100.0
var skill_casts := 0
var active_in_battle := false
var battle_dead := false
var selected := false
var dragging := false
var merge_locked := false
var presentation

func setup(key: String, level := 1) -> void:
	unit_type = Catalog.ALIASES.get(key, key)
	star = clampi(level, 1, 3)
	_apply_stats()
	presentation = Presentation.new()
	presentation.setup_visual(unit_type,"nine_sols_v1")
	presentation.show_anchor = false
	presentation.show_status = false
	presentation.z_index = -1
	add_child(presentation)

func _apply_stats() -> void:
	var data: Dictionary = UNIT_DATA[unit_type]
	display_name = data.name
	var factor: float = [1.0,1.8,3.2][star-1]
	max_health = data.hp * factor
	health = max_health
	damage = data.damage * factor
	attack_interval = data.interval
	move_interval = data.move
	attack_range_cells = data.range
	queue_redraw()

func set_bench_mode(on_bench: bool) -> void:
	presentation.scale = Vector2.ONE * (0.62 if on_bench else 1.0)
	presentation.foot_anchor = presentation.FOOT if on_bench else Vector2.ZERO
	queue_redraw()

func upgrade() -> void:
	if star < 3:
		star += 1
		_apply_stats()

func begin_battle() -> void:
	home_position = position
	home_cell = Vector2i(board_row, board_col)
	battle_cell = home_cell
	health = max_health
	cooldown = 0.0
	move_cooldown = 0.0
	mana = 0.0
	skill_casts = 0
	active_in_battle = board_row >= 0
	battle_dead = false
	visible = true
	presentation.reset_visual()
	queue_redraw()

func end_battle() -> void:
	active_in_battle = false
	battle_dead = false
	health = max_health
	position = home_position
	battle_cell = Vector2i(board_row,board_col)
	presentation.reset_visual()
	queue_redraw()

func tick_visual(delta: float) -> void:
	presentation.tick(delta)
	presentation.z_index = -1
	queue_redraw()

func effective_interval() -> float:
	return attack_interval

func play_attack() -> void:
	presentation.play_attack()

func take_damage(amount: float) -> bool:
	if battle_dead: return true
	health = maxf(0, health - amount)
	if health == 0:
		battle_dead = true
		active_in_battle = false
		presentation.play_retreat()
	else:
		presentation.play_hit()
	queue_redraw()
	return battle_dead

func heal(amount: float) -> void:
	if not battle_dead:
		health = minf(max_health, health + amount)
		queue_redraw()

func skill_data() -> Dictionary:
	return UNIT_DATA[unit_type]

func quality_data() -> Dictionary:
	return QUALITY_DATA.white

func _draw() -> void:
	if board_row >= 0 and not battle_dead:
		draw_rect(Rect2(-28,-113,56,7), Color("40262b"))
		draw_rect(Rect2(-26,-111,52 * health / max_health,3), Color("66dc75"))
	if not battle_dead:
		draw_string(ThemeDB.fallback_font, Vector2(-15*star,25 if board_row >= 0 else 43), "★".repeat(star), HORIZONTAL_ALIGNMENT_CENTER, 30*star,19,Color("ffe56f"))
	if merge_locked:
		draw_string(ThemeDB.fallback_font, Vector2(22,-45), "锁", HORIZONTAL_ALIGNMENT_LEFT,26,18,Color.WHITE)
	if selected:
		draw_arc(Vector2.ZERO if board_row >= 0 else Vector2(0,17),40,0,TAU,48,Color("fff2a3"),3)
