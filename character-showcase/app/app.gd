extends Node
## D-20261110-005 entry: character selection, then the shared player.
## User arg --character=<id> opens that character directly (tests/launch.bat).
const INDEX_FILE := "res://characters/index.json"
const BOARD_PATH := "res://shared/forest-board.png"
const Player := preload("res://app/player.gd")

var entries: Array = []
var selector: Control
var player: Node2D
var font: Font

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Heiti SC", "Noto Sans CJK SC", "Arial Unicode MS"])
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_FILE))
	if raw is Dictionary and raw.get("characters") is Array: entries = raw.characters
	_build_selector()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="): open_character(arg.trim_prefix("--character="))

func _build_selector() -> void:
	selector = Control.new()
	selector.size = Vector2(1440, 810)
	add_child(selector)
	var image := Image.new()
	if image.load(BOARD_PATH) == OK:
		var background := TextureRect.new()
		background.texture = ImageTexture.create_from_image(image)
		background.size = Vector2(1440, 810)
		selector.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.07, 0.06, 0.55)
	shade.size = Vector2(1440, 810)
	selector.add_child(shade)
	var title := Label.new()
	title.text = "角色攻击展示 · 选择角色"
	title.position = Vector2(0, 150)
	title.size = Vector2(1440, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)
	selector.add_child(title)
	var column := VBoxContainer.new()
	column.position = Vector2(470, 260)
	column.custom_minimum_size = Vector2(500, 0)
	column.add_theme_constant_override("separation", 18)
	selector.add_child(column)
	for i in entries.size():
		var item: Dictionary = entries[i]
		var button := Button.new()
		button.name = "Character_" + str(item.id)
		button.text = "%d  %s\n%s" % [i + 1, item.name, item.get("summary", "")]
		button.custom_minimum_size = Vector2(500, 92)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(open_character.bind(str(item.id)))
		column.add_child(button)
	var hint := Label.new()
	hint.text = "点击或按数字键进入；进入后按 Esc 或“返回选择”回到这里"
	hint.position = Vector2(0, 640)
	hint.size = Vector2(1440, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 20)
	selector.add_child(hint)

func character_ids() -> Array:
	return entries.map(func(e): return str(e.id))

func open_character(id: String) -> void:
	if id not in character_ids(): return
	close_character()
	player = Player.new()
	player.name = "Player"
	player.character_id = id
	player.back_requested.connect(close_character, CONNECT_DEFERRED)
	selector.visible = false
	add_child(player)

func close_character() -> void:
	if is_instance_valid(player):
		remove_child(player)
		player.free()
	player = null
	selector.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(player) or not event is InputEventKey or not event.pressed or event.echo: return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < entries.size():
		open_character(str(entries[index].id))
		get_viewport().set_input_as_handled()
