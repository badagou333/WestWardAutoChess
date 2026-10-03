extends Button
## Native UI card, reusing the current runtime idle art rather than new portraits.
const Presentation = preload("res://scripts/presentation/character_presentation.gd")
var offer := ""
var caption := ""
var price := 0
var hotkey_number := 1
var show_hotkey := true # Legacy cards retain numeric purchase hints.
var portrait: Texture2D
static var portraits := {}
static var idle_bounds := {}

func set_offer(key: String, title: String, cost: int, index: int) -> void:
	offer = key
	caption = title
	price = cost
	hotkey_number = index + 1
	portrait = portrait_for(key)
	queue_redraw()

static func portrait_for(key: String) -> Texture2D:
	if not key.is_empty():
		if not portraits.has(key):
			var base := "res://art/production/%s/nine_sols_v1/" % key
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
			if manifest.has("atlas"):
				manifest["atlases"] = {"body":manifest.atlas.file}
				manifest.actions.idle["body_frames"] = manifest.actions.idle.frames
			var atlas := Presentation._texture(base + manifest.atlases.body)
			var frame: int = manifest.actions.idle.body_frames[0]
			var columns := atlas.get_width() / 256
			var sprite := atlas.get_image().get_region(Rect2i((frame % columns)*256,(frame / columns)*256,256,256))
			idle_bounds[key] = sprite.get_used_rect()
			portraits[key] = ImageTexture.create_from_image(sprite.get_region(idle_bounds[key]))
		return portraits[key]
	return null

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if offer.is_empty():
		draw_string(font,Vector2(0,87),"已招募",HORIZONTAL_ALIGNMENT_CENTER,size.x,21,Color("958a72"))
		return
	var shade := Color(0.65,0.65,0.65,1) if disabled else Color.WHITE
	if portrait:
		var fit := minf(122.0/portrait.get_width(),87.0/portrait.get_height())
		var extent := portrait.get_size()*fit
		draw_texture_rect(portrait,Rect2(Vector2((size.x-extent.x)/2,9+(87-extent.y)),extent),false,shade)
	if show_hotkey: draw_string(font,Vector2(10,24),str(hotkey_number),HORIZONTAL_ALIGNMENT_LEFT,20,16,Color("b6a785"))
	draw_line(Vector2(14,101),Vector2(size.x-14,101),Color("645941"),1)
	draw_string(font,Vector2(0,123),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,20,Color("eee5cf"))
	draw_string(font,Vector2(0,146),"%d 金币" % price,HORIZONTAL_ALIGNMENT_CENTER,size.x,18,Color("ddbd71"))
