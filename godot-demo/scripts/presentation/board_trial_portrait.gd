extends Control
## Crops the actual production idle image; never uses concept faces or edits PNGs.
const REGIONS := {
	"tangseng":Rect2(102,103,55,64),"guard_monk":Rect2(107,107,62,64),
	"wild_hunter":Rect2(95,111,62,60),"sparrow_spirit":Rect2(108,128,50,61),
	"herbal_spirit_child":Rect2(103,119,57,60),"foxfire_imp":Rect2(104,113,50,60),
	"mountain_wolf":Rect2(73,144,70,61),"boar":Rect2(91,113,65,68),"gray_rat":Rect2(92,143,65,64)}
var texture: Texture2D
var cropped: AtlasTexture
var region := Rect2()
var mirrored := false
var role := ""

static func idle_source_left(key: String, manifest: Dictionary) -> bool:
	# Actual idle pixels are the oracle for this one erroneous shared metadata tag.
	return key=="herbal_spirit_child" or manifest.get("source_facing","right")=="left"

func setup(key: String, source_left: bool, friendly: bool) -> void:
	var next_role: String = {"wolf":"mountain_wolf","rat":"gray_rat"}.get(key,key)
	var next_mirror := source_left if friendly else not source_left
	if next_role==role and next_mirror==mirrored and texture!=null: return
	role = next_role
	texture = load("res://art/production/%s/nine_sols_v1/idle.png" % role)
	region = REGIONS[role]
	cropped = AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = region
	cropped.filter_clip = true
	mirrored = next_mirror
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if texture==null: return
	if mirrored: draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
	draw_texture_rect(cropped,Rect2(Vector2.ZERO,size),false)
	draw_set_transform(Vector2.ZERO)
