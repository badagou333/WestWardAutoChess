extends Panel
## A small raised stone tile. The actor remains a separate animated Node2D above it.
var occupied := false
var flat_mode := false # Opt-in; old grid mode keeps its stone platforms.
var seat_number := 1
var star := 0
var highlighted := false
var merge_locked := false
const Style = preload("res://scripts/presentation/roster_style.gd")

func present(hero, number: int) -> void:
	seat_number = number
	star = hero.star if hero != null else 0
	highlighted = hero.selected if hero != null else false
	merge_locked = hero.merge_locked if hero != null else false
	queue_redraw()

func set_occupied(value: bool) -> void:
	if occupied != value:
		occupied = value
		queue_redraw()
func _draw() -> void:
	if flat_mode:
		_draw_flat()
		return
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

func _draw_flat() -> void:
	var font := ThemeDB.fallback_font
	if highlighted:
		draw_style_box(Style.box(Color(0.3,0.29,0.19,0.25),Style.GOLD,2),Rect2(0,6,size.x,size.y-8))
		draw_colored_polygon(PackedVector2Array([Vector2(size.x/2-5,7),Vector2(size.x/2+5,7),Vector2(size.x/2,13)]),Style.GOLD)
	draw_line(Vector2(10,123),Vector2(size.x-10,123),Style.GOLD if occupied else Color("454a41"),1)
	draw_string(font,Vector2(9,27),str(seat_number),HORIZONTAL_ALIGNMENT_LEFT,24,18,Style.MUTED if occupied else Color("777d70"))
	if occupied:
		draw_string(font,Vector2(0,146),"★".repeat(star),HORIZONTAL_ALIGNMENT_CENTER,size.x,19,Style.GOLD)
	else:
		draw_line(Vector2(size.x/2-5,83),Vector2(size.x/2+5,83),Color("626858"),1)
		draw_line(Vector2(size.x/2,78),Vector2(size.x/2,88),Color("626858"),1)
	if merge_locked:
		var at := Vector2(size.x-24,16)
		draw_style_box(Style.box(Color("32382f"),Style.EDGE),Rect2(at-Vector2(4,4),Vector2(24,28)))
		draw_arc(at+Vector2(8,7),5,PI,TAU,12,Style.MUTED,1.5,true)
		draw_rect(Rect2(at+Vector2(2,7),Vector2(12,10)),Style.MUTED,false,1.5)
func _shadow_box() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(0,0,0,.35)
	box.set_corner_radius_all(6)
	return box
