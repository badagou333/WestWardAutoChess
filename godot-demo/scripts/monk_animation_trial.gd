extends "res://scripts/free_escort.gd"
## Explicit opt-in review entry. Ordinary free/legacy scenes retain production art.
var monk_sample_enabled := true
var animation_toggle: Button

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is Label and child.text=="无格子护送 · 试验": child.text = "棍僧动画样板 · 待审"
	# Created after the base's +2000 UI lift, so use the lifted layer explicitly.
	animation_toggle = _make_button(Vector2(22,263),Vector2(250,38),"",Color("697758"),2026)
	animation_toggle.toggle_mode = true
	RosterStyle.button(animation_toggle)
	animation_toggle.add_theme_font_size_override("font_size",18)
	animation_toggle.focus_mode = Control.FOCUS_NONE
	animation_toggle.tooltip_text = "仅切棍僧表现，不重开、不回血、不改变命令或收益；候选待05/07审核。"
	animation_toggle.pressed.connect(func(): set_monk_sample(not monk_sample_enabled))
	set_monk_sample(true)

func set_monk_sample(enabled: bool) -> void:
	monk_sample_enabled = enabled
	for hero in heroes: hero.presentation.set_motion_sample(enabled)
	if is_instance_valid(carry_preview): carry_preview.set_motion_sample(enabled)
	animation_toggle.text = "棍僧样板 · 切换旧版" if enabled else "棍僧旧版 · 切换样板"
	animation_toggle.button_pressed = enabled

func _on_shop_pressed(index: int) -> void:
	super._on_shop_pressed(index)
	for hero in heroes:
		if hero.unit_type == "guard_monk": hero.presentation.set_motion_sample(monk_sample_enabled)

func _start_carry(hero, point: Vector2) -> void:
	super._start_carry(hero,point)
	if is_instance_valid(carry_preview): carry_preview.set_motion_sample(monk_sample_enabled)
