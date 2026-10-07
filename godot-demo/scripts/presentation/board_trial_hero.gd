extends "res://scripts/unit.gd"
## Only replace the legacy HUD; production body/motion and gameplay stay inherited.
const HealerView = preload("res://scripts/presentation/board_trial_healer_view.gd")
func setup(key: String, level := 1) -> void:
	super.setup(key,level)
	if unit_type!="herbal_spirit_child": return
	presentation.free()
	presentation = HealerView.new()
	presentation.setup_visual(unit_type,"nine_sols_v1")
	presentation.show_anchor = false
	presentation.show_status = false
	presentation.z_index = -1
	add_child(presentation)
func _draw() -> void: pass
