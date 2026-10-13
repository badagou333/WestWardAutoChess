extends CanvasLayer

var controller: Node3D
var state_label: Label
var camera_buttons: Array[Button] = []
var pause_button: Button
var auto_button: Button
var grid_button: Button
var coordinate_label: Label
var font: SystemFont
const INK := Color("152b2d")
const GOLD := Color("dbb36e")
const CREAM := Color("e9e5d6")
const MUTED := Color("a0b9b4")

func build(owner_node: Node3D) -> void:
	controller = owner_node
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "Arial Unicode MS"])
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("ffe0a7"))
	theme.set_stylebox("normal", "Button", _box(Color("1b3438"), Color("40605b"), 8))
	theme.set_stylebox("hover", "Button", _box(Color("28484a"), GOLD, 8))
	theme.set_stylebox("pressed", "Button", _box(Color("344741"), GOLD, 8))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 8))
	root.theme = theme
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 30
	header.offset_top = 22
	header.offset_right = -30
	header.offset_bottom = 80
	header.add_theme_stylebox_override("panel", _box(Color(0.045, 0.10, 0.11, 0.92), Color(0.36, 0.49, 0.45, 0.6), 10, 20, 6))
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	header_row.add_theme_constant_override("separation", 30)
	var title_group := VBoxContainer.new()
	title_group.add_theme_constant_override("separation", 1)
	header_row.add_child(title_group)
	var title := _label("西游护送", 22, CREAM)
	title_group.add_child(title)
	title_group.add_child(_label("松庭 · 狐火试场", 12, MUTED))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_child(right)
	state_label = _label("静候指令", 17, CREAM)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(state_label)
	coordinate_label = _label("点击石庭，指引狐火前往", 12, MUTED)
	coordinate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(coordinate_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 30
	bottom.offset_right = -30
	bottom.offset_top = -99
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", _box(Color(0.045, 0.10, 0.11, 0.94), Color(0.36, 0.49, 0.45, 0.55), 10, 18, 9))
	root.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)
	var label_group := VBoxContainer.new()
	label_group.alignment = BoxContainer.ALIGNMENT_CENTER
	label_group.custom_minimum_size.x = 128
	row.add_child(label_group)
	label_group.add_child(_label("狐火小妖", 21, CREAM))
	label_group.add_child(_label("左键指引前往", 13, MUTED))
	row.add_child(VSeparator.new())
	for index in range(4):
		var camera_button := _button(["1  沉浸", "2  战术", "3  俯瞰", "4  近景"][index])
		camera_button.pressed.connect(controller.set_camera.bind(index + 1))
		row.add_child(camera_button)
		camera_buttons.append(camera_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	grid_button = _button("G  格线")
	grid_button.pressed.connect(controller.toggle_grid)
	row.add_child(grid_button)
	pause_button = _button("空格  暂停")
	pause_button.pressed.connect(func(): controller.set_paused(not controller.paused))
	row.add_child(pause_button)
	var reset_button := _button("R  归位")
	reset_button.pressed.connect(controller.reset_actor)
	row.add_child(reset_button)
	auto_button = _button("自动漫游")
	auto_button.custom_minimum_size.x = 132
	auto_button.add_theme_stylebox_override("normal", _box(Color("725d37"), GOLD, 8))
	auto_button.pressed.connect(func(): controller.set_auto(not controller.auto_demo))
	row.add_child(auto_button)
	refresh()

func _label(text: String, size: int, tint: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(105, 44)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.focus_mode = Control.FOCUS_NONE
	return node

func _box(fill: Color, border: Color, radius: int, horizontal: int = 12, vertical: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

func refresh() -> void:
	if not state_label:
		return
	state_label.text = "已暂停" if controller.paused else ("漫游中" if controller.auto_demo else ("奔向所指" if controller.moving else "静候指令"))
	coordinate_label.text = "第 %d 列 · 第 %d 行" % [controller.current_cell.x + 1, controller.current_cell.y + 1]
	pause_button.text = "空格  继续" if controller.paused else "空格  暂停"
	auto_button.text = "停止漫游" if controller.auto_demo else "自动漫游"
	grid_button.modulate = GOLD if controller.grid and controller.grid.visible else Color.WHITE
	for index in range(camera_buttons.size()):
		camera_buttons[index].modulate = GOLD if controller.camera_mode == index + 1 else Color.WHITE
