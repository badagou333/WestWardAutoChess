extends "res://scripts/presentation/board_trial_ui.gd"
## The controls/semantics stay shared; the depth board gets its own quiet skin.
func panel(rect: Rect2, parent: Node = self) -> Panel:
	var control := super.panel(rect,parent)
	var skin := Style.box(Color(0.052,0.105,0.118,0.94),Color("526560"))
	skin.shadow_color = Color(0.015,0.03,0.032,0.28)
	skin.shadow_size = 9
	skin.shadow_offset = Vector2(0,4)
	control.add_theme_stylebox_override("panel",skin)
	return control

func setup(host) -> void:
	super.setup(host)
	usage_label.text = "松风台 · 正面45°试玩"
	profile_choice.add_theme_font_override("font",ThemeDB.fallback_font)
	for state in ["normal","hover","pressed"]:
		profile_choice.get_popup().add_theme_font_override("font",ThemeDB.fallback_font)
	status_label.add_theme_font_size_override("font_size",18)
	status_label.add_theme_color_override("font_color",Color("d4d3b9"))
	animation_toggle.tooltip_text = "此入口使用全员正背面姿势；旧棍僧动作对照请打开旧矩形棋盘。"

func refresh() -> void:
	super.refresh()
	animation_toggle.text = "正背面已启用"
	animation_toggle.disabled = true
