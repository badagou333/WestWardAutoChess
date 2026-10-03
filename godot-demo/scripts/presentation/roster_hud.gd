extends Control
## Read-only view model: never owns heroes, issues commands or advances cooldowns.
const Portraits = preload("res://scripts/presentation/shop_card.gd")
const Style = preload("res://scripts/presentation/roster_style.gd")
const SHORT_NAMES := {"guard_monk":"棍僧","wild_hunter":"猎户","herbal_spirit_child":"药灵","sparrow_spirit":"山雀","foxfire_imp":"狐火"}
var slots: Array = []
var skills_text := "Q —    W —    E —\n技能未配置"

func present(values: Array) -> void:
	slots = values
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_style_box(Style.box(),Rect2(Vector2.ZERO,size))
	for i in range(10):
		var origin := Vector2(300+i*130,12)
		var slot: Dictionary = slots[i] if i < slots.size() else {}
		var filled := not slot.is_empty()
		var dead: bool = slot.get("dead",false)
		var selected: bool = slot.get("selected",false)
		var ink := Style.MUTED if dead else Style.INK
		var edge := Style.GOLD if selected else (Style.EDGE if filled else Color("3f463c"))
		draw_style_box(Style.box(Color("2b2e29") if filled else Color(0,0,0,0),edge,2 if selected else 1),Rect2(origin,Vector2(124,148)))
		draw_string(font,origin+Vector2(8,24),str((i+1)%10),HORIZONTAL_ALIGNMENT_LEFT,22,20,Style.GOLD if selected else Style.MUTED)
		if selected:
			draw_colored_polygon(PackedVector2Array([origin+Vector2(55,0),origin+Vector2(69,0),origin+Vector2(62,7)]),Style.GOLD)
		if not filled:
			draw_string(font,origin+Vector2(0,83),"空位",HORIZONTAL_ALIGNMENT_CENTER,124,19,Color("777d70"))
			continue
		draw_string(font,origin+Vector2(30,24),"★".repeat(slot.star),HORIZONTAL_ALIGNMENT_RIGHT,86,17,Style.MUTED if dead else Style.GOLD)
		var portrait := Portraits.portrait_for(slot.unit)
		if portrait:
			# Upper-body crop of existing idle art; no separate portrait asset.
			var crop_width := minf(portrait.get_width(),portrait.get_height()*0.64)
			var crop := Rect2((portrait.get_width()-crop_width)/2,0,crop_width,minf(portrait.get_height(),crop_width*1.12))
			draw_texture_rect_region(portrait,Rect2(origin+Vector2(7,34),Vector2(54,60)),crop,Color("797e76") if dead else Color.WHITE)
		draw_string(font,origin+Vector2(66,55),SHORT_NAMES.get(slot.unit,slot.name),HORIZONTAL_ALIGNMENT_LEFT,54,19,ink)
		draw_string(font,origin+Vector2(66,82),slot.status,HORIZONTAL_ALIGNMENT_LEFT,54,18,Color("c69786") if dead else Style.MUTED)
		var ratio: float = clampf(float(slot.hp)/maxf(1.0,float(slot.max_hp)),0,1)
		var low := not dead and ratio <= 0.25
		var hp_color := Color("e2a68d") if low else ink
		draw_string(font,origin+Vector2(0,117),"%s%d / %d" % ["! " if low else "",int(slot.hp),int(slot.max_hp)],HORIZONTAL_ALIGNMENT_CENTER,124,19,hp_color)
		draw_rect(Rect2(origin+Vector2(8,130),Vector2(108,6)),Color("151a15"))
		draw_rect(Rect2(origin+Vector2(8,130),Vector2(108*ratio,6)),Color("7b8077") if dead else (Color("d29372") if low else Color("9eb88a")))
		if dead:
			draw_line(origin+Vector2(43,76),origin+Vector2(55,88),Style.MUTED,2)
			draw_line(origin+Vector2(55,76),origin+Vector2(43,88),Style.MUTED,2)
	for i in range(3):
		var at := Vector2(1640+i*52,134)
		draw_style_box(Style.box(Color("30352d")),Rect2(at,Vector2(26,26)))
		draw_string(font,at+Vector2(0,19),["Q","W","E"][i],HORIZONTAL_ALIGNMENT_CENTER,26,18,Style.MUTED)
		draw_string(font,at+Vector2(30,19),"—",HORIZONTAL_ALIGNMENT_LEFT,22,18,Style.MUTED)
	# One compact row leaves 8 actual pixels below the keycaps at 720p.
	draw_string(font,Vector2(1804,153),"技能未配置",HORIZONTAL_ALIGNMENT_LEFT,96,18,Style.MUTED)
