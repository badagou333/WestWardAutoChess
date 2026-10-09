extends "res://scripts/enemy.gd"
## Board-only HUD and bear frame0 orientation; gameplay stays inherited.
const BearView = preload("res://scripts/presentation/board_trial_bear_view.gd")

func setup(new_type: String) -> void:
	super.setup(new_type)
	if enemy_type!="bear_lord": return
	presentation.free()
	presentation=BearView.new()
	presentation.setup_visual("bear_lord","nine_sols_v1")
	presentation.foot_anchor=Vector2.ZERO
	presentation.show_anchor=false
	presentation.show_status=false
	presentation.z_index=-1
	add_child(presentation)

func _draw() -> void: pass
