extends Panel
## A small raised stone tile. The actor remains a separate animated Node2D above it.
var occupied := false
func set_occupied(value: bool) -> void:
	if occupied != value:
		occupied = value
		queue_redraw()
func _draw() -> void:
	var w := size.x
	var top := PackedVector2Array([Vector2(12,80),Vector2(w-12,80),Vector2(w,133),Vector2(0,133)])
	var front := PackedVector2Array([Vector2(0,133),Vector2(w,133),Vector2(w,151),Vector2(0,151)])
	draw_style_box(_shadow_box(),Rect2(2,145,w,12))
	draw_colored_polygon(front,Color("3e3a30"))
	draw_colored_polygon(top,Color("77715c") if occupied else Color("625f4f"))
	var rim := top.duplicate()
	rim.append(top[0])
	draw_polyline(rim,Color("d4bd80") if occupied else Color("969077"),2,true)
	draw_line(Vector2(0,151),Vector2(w,151),Color("201f1b"),3)
	draw_line(Vector2(4,137),Vector2(w-4,137),Color("57513f"),2)
	# Modest stone seams; avoid decorative detail behind the unit silhouette.
	draw_line(Vector2(20,83),Vector2(16,100),Color("4e4d40"),1)
	draw_line(Vector2(w-23,116),Vector2(w-14,129),Color("4e4d40"),1)
func _shadow_box() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(0,0,0,.35)
	box.set_corner_radius_all(6)
	return box
