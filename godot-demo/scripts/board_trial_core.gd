extends Node2D
## Local weak ranged adapter; does not alter the old stationary escort actor.
const View = preload("res://scripts/presentation/character_presentation.gd")
const Config = preload("res://scripts/data/board_trial_config.gd")
var unit_type := "tangseng"
var display_name := "唐僧"
var max_health: float = Config.CORE.hp
var health := max_health
var damage: float = Config.CORE.damage
var attack_interval: float = Config.CORE.interval
var attack_range_cells: int = Config.CORE.range
var move_interval := 0.5
var dead := false
var battle_dead := false
var presentation

func _ready() -> void:
	presentation = View.new()
	presentation.setup_visual("tangseng","nine_sols_v1")
	presentation.foot_anchor = Vector2.ZERO
	presentation.show_anchor = false
	presentation.show_status = false
	# Local copy only: reuse the existing code-drawn wind projectile, no new art.
	presentation.manifest = presentation.manifest.duplicate(true)
	presentation.manifest.actions.basic_attack.projectile = "wind"
	presentation.motion = {"windup":0.14,"strike":0.08,"recover":0.22,"walk":0.5,"lift":0.0,"reach":0.0,"lean":0.0}
	add_child(presentation)

func tick_visual(delta: float) -> void:
	presentation.tick(delta)
	queue_redraw()

func play_attack() -> void:
	if not dead: presentation.play_attack()

func take_damage(amount: float) -> bool:
	if dead: return true
	health = maxf(0,health-amount)
	if health==0:
		dead = true
		battle_dead = true
		presentation.play_retreat()
	else: presentation.play_hit()
	queue_redraw()
	return dead

func heal(amount: float) -> void:
	if not dead: health = minf(max_health,health+amount)

func _draw() -> void:
	pass # Trial-only HUD is a separate top layer; body and foot anchor are unchanged.
