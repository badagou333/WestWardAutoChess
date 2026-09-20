extends "res://scripts/presentation/character_presentation.gd"

# Isolated trial model. Shared presentation owns no health or damage.
signal defeated(actor)
var display_name := ""
var board_row := -1
var board_col := -1
var battle_cell := Vector2i(-1, -1)
var home_cell := Vector2i(-1, -1)
var health := 100.0
var max_health := 100.0
var damage := 20.0
var attack_range_cells := 1
var attack_interval := 1.1
var move_interval := 0.6
var cooldown := 0.0
var attack_cooldown := 0.0
var move_cooldown := 0.0
var active_in_battle := true
var battle_dead := false
var enemy_side := false

func setup_role(key: String, title: String, stats: Array, enemy := false) -> void:
	setup_visual(key)
	move_interval = motion.walk + 0.03
	display_name = title
	enemy_side = enemy
	max_health = float(stats[0])
	health = max_health
	damage = float(stats[1])
	attack_range_cells = int(stats[2])

func take_damage(amount: float) -> bool:
	if dead: return true
	health = maxf(0.0, health - amount)
	if health <= 0:
		battle_dead = true
		active_in_battle = false
		play_retreat()
		defeated.emit(self)
	else:
		play_hit()
	return dead

func heal(amount: float) -> void:
	if not dead: health = minf(max_health, health + amount)

func _draw() -> void:
	super._draw()
	if not dead and show_status:
		var y := -148.0 if enemy_side else -120.0
		if show_name:
			draw_rect(Rect2(-65, y - 27, 130, 23), Color(0.08, 0.13, 0.16, 0.82))
			draw_string(ThemeDB.fallback_font, Vector2(-62, y - 7), display_name, HORIZONTAL_ALIGNMENT_CENTER, 124, 17, Color("fff5df"))
		draw_rect(Rect2(-37, y, 74, 7), Color("302921"))
		draw_rect(Rect2(-35, y + 2, 70 * health / max_health, 3), Color("ed7574") if enemy_side else Color("6bd58a"))
