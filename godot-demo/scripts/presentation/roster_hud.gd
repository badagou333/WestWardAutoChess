extends Control
## Read-only view model: never owns heroes, issues commands or advances cooldowns.
const Portraits = preload("res://scripts/presentation/shop_card.gd")
var slots: Array = []
var skills_text := "技能未配置\nQ —    W —    E —"

func present(values: Array) -> void:
	slots = values
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in range(10):
		var origin := Vector2(300+i*130,12)
		var box := Rect2(origin,Vector2(124,148))
		var slot: Dictionary = slots[i] if i < slots.size() else {}
		var filled := not slot.is_empty()
		var dead: bool = slot.get("dead",false)
		var ink := Color("958e83") if dead else Color("eee5cf")
		draw_style_box(_box(Color("353330") if dead else Color("24271f"),Color("f2d56b") if slot.get("selected",false) else Color("665c43")),box)
		draw_string(font,origin+Vector2(8,21),"[%d] %s" % [(i+1)%10,"★".repeat(slot.get("star",0))],HORIZONTAL_ALIGNMENT_LEFT,112,18,ink)
		if not filled:
			draw_string(font,origin+Vector2(0,79),"空位",HORIZONTAL_ALIGNMENT_CENTER,124,18,Color("847e6c"))
			continue
		var portrait := Portraits.portrait_for(slot.unit)
		if portrait:
			var extent := portrait.get_size()*minf(38.0/portrait.get_width(),48.0/portrait.get_height())
			draw_texture_rect(portrait,Rect2(origin+Vector2(8,30)+Vector2((38-extent.x)/2,48-extent.y),extent),false,Color("777777") if dead else Color.WHITE)
		draw_string(font,origin+Vector2(48,47),slot.name,HORIZONTAL_ALIGNMENT_LEFT,72,14,ink)
		draw_string(font,origin+Vector2(48,71),slot.status,HORIZONTAL_ALIGNMENT_LEFT,72,17,ink)
		draw_string(font,origin+Vector2(0,104),"%d / %d" % [int(slot.hp),int(slot.max_hp)],HORIZONTAL_ALIGNMENT_CENTER,124,18,ink)
		draw_rect(Rect2(origin+Vector2(8,115),Vector2(108,7)),Color("12150f"))
		var ratio: float = clampf(float(slot.hp)/maxf(1.0,float(slot.max_hp)),0,1)
		draw_rect(Rect2(origin+Vector2(8,115),Vector2(108*ratio,7)),Color("676460") if dead else Color("89bf76"))
		draw_string(font,origin+Vector2(0,140),"等待复归" if dead else "场上英雄",HORIZONTAL_ALIGNMENT_CENTER,124,13,Color("a89e83"))
	var row := 0
	for line in skills_text.split("\n"):
		draw_string(font,Vector2(1640,140+row*24),line,HORIZONTAL_ALIGNMENT_LEFT,258,18,Color("bcb5a4"))
		row += 1

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
