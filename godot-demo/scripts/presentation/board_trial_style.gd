extends Node2D
## Trial-only palette and actor HUD. No combat, animation or hit-test ownership.
const INK := Color("f1e5cd")
const MUTED := Color("c6bca5")
const EDGE := Color("766e56")
const GOLD := Color("f6cf71")
const FILL := Color(0.141,0.157,0.133,0.92)
const RANGE := Color("75a6b6")
var friendly := true
var caption := ""

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
	control.add_theme_stylebox_override("disabled",box(Color("242822"),EDGE.darkened(0.25)))

func _process(_delta: float) -> void: queue_redraw()

func _draw() -> void:
	var actor = get_parent()
	if actor.health<=0: return
	# Keep the existing 0.72 actor scale and all foot points; HUD size is logical.
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE/actor.scale)
	var top := -81.0
	if not friendly and actor.enemy_type in ["wolf","rat"]: top = -59.0
	var rect := Rect2(-32,top,64,8)
	draw_rect(rect,Color("252c27"))
	draw_rect(Rect2(rect.position+Vector2.ONE,Vector2(62*clampf(actor.health/actor.max_health,0,1),6)),Color("90b883") if friendly else Color("d17162"))
	draw_rect(rect,Color("d3c19a"),false,1)
	draw_string(ThemeDB.fallback_font,Vector2(-15,22),caption,HORIZONTAL_ALIGNMENT_CENTER,30,17,INK)
	draw_set_transform(Vector2.ZERO)
