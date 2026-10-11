extends "res://scripts/unit.gd"
## Board-only HUD/per-role presentation; production gameplay stays inherited.
const HealerView = preload("res://scripts/presentation/board_trial_healer_view.gd")
const MonkView = preload("res://scripts/presentation/board_trial_monk_view.gd")
func setup(key: String, level := 1) -> void:
	super.setup(key,level)
	if unit_type not in ["herbal_spirit_child","guard_monk"]: return
	presentation.free()
	presentation = MonkView.new() if unit_type=="guard_monk" else HealerView.new()
	presentation.setup_visual(unit_type,"nine_sols_v1")
	presentation.foot_anchor = Vector2.ZERO
	presentation.show_anchor = false
	presentation.show_status = false
	presentation.z_index = -1
	add_child(presentation)

func tick_visual(delta: float) -> void:
	if unit_type=="guard_monk":
		var controller=get_parent()
		if controller!=null and controller.has_method("_record"):
			var advancing: bool=controller.phase==controller.Phase.BATTLE and not controller.paused
			presentation.sync_board_step(controller._by_node(self),delta,advancing)
	super.tick_visual(delta)
	if unit_type=="guard_monk": presentation.end_board_tick()

func _draw() -> void: pass
