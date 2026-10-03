extends RefCounted
## Shared free-mode UI palette; no game state or input ownership.
const INK := Color("e8dfc9")
const MUTED := Color("b4b09f")
const EDGE := Color("665f4b")
const GOLD := Color("d8b366")
const FILL := Color(0.133,0.149,0.137,0.94)

static func box(fill := FILL, edge := EDGE, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	return style

static func button(control: Button) -> void:
	control.add_theme_color_override("font_color",INK)
	control.add_theme_color_override("font_hover_color",INK)
	control.add_theme_color_override("font_pressed_color",INK)
	control.add_theme_color_override("font_disabled_color",MUTED.darkened(0.22))
	control.add_theme_stylebox_override("normal",box())
	control.add_theme_stylebox_override("hover",box(Color("30352f"),GOLD,2))
	control.add_theme_stylebox_override("pressed",box(Color("3b3b2e"),GOLD,2))
	control.add_theme_stylebox_override("disabled",box(Color("242823"),EDGE.darkened(0.35)))
