extends Node2D
## HUD clearance follows the actual alpha bounds, not a single height for all species.
var friendly := true
var caption := ""
var top := -110.0
var actor_id := ""
static var bounds_cache := {}

func setup(actor, is_friend: bool, id: String) -> void:
	friendly=is_friend
	actor_id=id
	caption="" if friendly else id
	var texture: Texture2D=actor.presentation.body
	var key:=texture.get_instance_id()
	if not bounds_cache.has(key):
		var image:=texture.get_image().get_region(Rect2i(0,0,256,256))
		bounds_cache[key]=image.get_used_rect()
	var rect: Rect2i=bounds_cache[key]
	top=float(rect.position.y)-218-13
	if id=="guard_monk": top=-121.0

func _process(_delta: float) -> void: queue_redraw()

func _draw() -> void:
	var actor=get_parent()
	if actor.health<=0: return
	var game=actor.get_parent()
	var chosen: bool=game.selected==actor_id
	var draw_top:=top
	if actor.presentation.has_method("draw_sample"):
		var sample: Dictionary=actor.presentation.draw_sample()
		draw_top=float(sample.get("hud_top",float(sample.bounds.position.y)-13.0))
	# Position follows the scaled body; bars and text retain readable canvas pixels.
	draw_top*=actor.scale.y
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE/actor.scale)
	# Full bars in deployment, in combat only when damaged/selected. A discreet
	# faction dot remains at the foot without covering the character's face.
	if game.phase==game.Phase.DEPLOY or actor.health<actor.max_health or chosen:
		var width:=47.0
		var rect:=Rect2(-width*.5,draw_top,width,5)
		draw_style_box(_box(Color(.027,.045,.043,.95)),rect.grow(1.3))
		draw_rect(Rect2(rect.position,Vector2(width*clampf(actor.health/actor.max_health,0,1),5)),Color("a9cd94") if friendly else Color("d48272"))
		draw_line(rect.position,rect.position+Vector2(width,0),Color(.89,.90,.72,.4),1,true)
	if chosen:
		draw_string(ThemeDB.fallback_font,Vector2(-38,19),actor.display_name,HORIZONTAL_ALIGNMENT_CENTER,76,14,Color("f5e7bd"))
	elif not friendly:
		draw_string(ThemeDB.fallback_font,Vector2(-12,15),caption,HORIZONTAL_ALIGNMENT_CENTER,24,12,Color(.88,.85,.72,.72))

func _box(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(2)
	return box
