extends Control
## Thin logical-size meter without theme-enforced ProgressBar minimum height.
var value := 100.0:
	set(next):
		value = clampf(next,0,100)
		queue_redraw()
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("304548"))
	draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*value/100,size.y)),Color("99c5ac"))
