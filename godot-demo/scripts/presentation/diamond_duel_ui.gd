extends "res://scripts/presentation/board_trial_ui.gd"
## Two fixed cards and live controls for the independent D002 prototype.
## Presentation only: the controller owns selection, placement and combat rules.

const MONK_IDLE = preload("res://art/runtime/diamond_duel_v1/frames/monk_se_idle.png")
const WOLF_IDLE = preload("res://art/runtime/diamond_duel_v1/frames/wolf_se_idle.png")

var monk_button: Button
var wolf_button: Button
var cards: Dictionary = {}
var return_button: Button
var cancel_button: Button
var monk_hp_label: Label
var wolf_hp_label: Label
var result_summary: Label
var selection_label: Label
var monk_state_label: Label
var wolf_state_label: Label
var _normal_card: StyleBoxFlat
var _selected_card: StyleBoxFlat

func _blocking_panel(rect: Rect2) -> Panel:
	var control: Panel = panel(rect)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	return control

func _small_button(rect: Rect2, text: String, action: Callable) -> Button:
	var control: Button = button(rect, text, action)
	control.add_theme_font_size_override("font_size", 20)
	return control

func _card(rect: Rect2, id: String, name_text: String, side: String, image: Texture2D) -> Button:
	var control: Button = button(rect, "", func(): game.select(id))
	control.toggle_mode = false
	control.tooltip_text = "战前选择%s，再点完整菱形格放置；战中只能查看。" % name_text
	var image_rect := TextureRect.new()
	image_rect.position = Vector2(13, 9)
	image_rect.size = Vector2(rect.size.x - 26, 132)
	image_rect.texture = image
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(image_rect)
	label(Rect2(12, 143, rect.size.x - 24, 31), 24, control).text = name_text
	label(Rect2(12, 177, rect.size.x - 24, 25), 17, control).text = side
	var state_label: Label = label(Rect2(12, 207, rect.size.x - 24, 27), 18, control)
	if id == "monk": monk_state_label = state_label
	else: wolf_state_label = state_label
	return control

func setup(host) -> void:
	game = host
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2100
	_normal_card = Style.box(Color("182b32"), Style.EDGE, 1)
	_selected_card = Style.box(Color("30413e"), Style.GOLD, 3)
	# The root does not cover the arena; every visible HUD panel stops input.
	_blocking_panel(Rect2(24, 22, 1872, 159))
	title_label = label(Rect2(48, 35, 1820, 44), 32)
	title_label.text = "菱格对打 · 双角色原型 · 非商业试玩"
	usage_label = label(Rect2(48, 91, 1320, 30), 20)
	usage_label.text = "水平长方形场地 · 精确2:1菱格 · 仅护寺棍僧与山狼各一名"
	phase_label = label(Rect2(1460, 91, 405, 34), 26)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	monk_hp_label = label(Rect2(48, 133, 460, 30), 22)
	wolf_hp_label = label(Rect2(600, 133, 460, 30), 22)
	timer_label = label(Rect2(1140, 133, 280, 30), 22)
	label(Rect2(1502, 137, 360, 26), 18).text = "声音默认静音 · 样板默认，非最终玩法"

	_blocking_panel(Rect2(24, 226, 228, 652))
	label(Rect2(38, 238, 200, 32), 25).text = "选择角色"
	monk_button = _card(Rect2(34, 283, 208, 243), "monk", "护寺棍僧", "我方 · 独立实例 × 1", MONK_IDLE)
	wolf_button = _card(Rect2(34, 542, 208, 243), "wolf", "山狼", "敌方 · 独立实例 × 1", WOLF_IDLE)
	cards = {"monk": monk_button, "wolf": wolf_button}
	selection_label = label(Rect2(38, 802, 200, 62), 18)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_blocking_panel(Rect2(1660, 226, 236, 652))
	label(Rect2(1676, 240, 204, 32), 25).text = "对打控制"
	start_button = button(Rect2(1674, 292, 208, 62), "开始对打", primary)
	start_button.add_theme_font_size_override("font_size", 27)
	pause_button = _small_button(Rect2(1674, 370, 208, 50), "暂停 P", game.toggle_pause)
	speed_button = _small_button(Rect2(1674, 432, 208, 46), "1× 速度", func(): game.speed = 3 - game.speed)
	retry_button = _small_button(Rect2(1674, 496, 208, 50), "同阵重试", game.retry)
	retry_button.tooltip_text = "恢复本局开战前的两名角色和站位，立即重新对打。"
	return_button = _small_button(Rect2(1674, 558, 208, 50), "返回布置", game.return_to_setup)
	return_button.tooltip_text = "停止当前对打，恢复开战前站位。"
	cancel_button = _small_button(Rect2(1674, 620, 208, 46), "取消选择 · Esc", func(): game.select(""))
	withdraw_button = cancel_button # No withdrawal/deletion in the fixed 1v1 sample.
	result_summary = label(Rect2(1676, 686, 204, 154), 21)
	result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label = label(Rect2(288, 202, 1344, 65), 20)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemies_label = label(Rect2(288, 890, 1344, 29), 20)
	status_label = label(Rect2(288, 935, 1344, 55), 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(Rect2(288, 1005, 1344, 47), 19).text = "仅有限关键姿势，非完整步态；部分攻击足底未知。角色身高、棍与尾的自然外伸不作为可走格。"
	# The inherited input surface expects a modal handle. It stays hidden: this
	# small sample has no help popup or automatic result overlay over the arena.
	help_layer = Control.new()
	help_layer.size = size
	help_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	help_layer.hide()
	add_child(help_layer)
	refresh()

func primary() -> void:
	if game.phase == game.Phase.DEPLOY: game.start_battle()

func _health_text(id: String, name_text: String) -> String:
	var actor: Dictionary = game._record(id)
	if actor.is_empty(): return name_text + " · 尚未载入"
	return "%s   HP %d / %d" % [name_text, game._hp(actor), int(actor.get("hp_max", 0))]

func _state_text(id: String) -> String:
	var actor: Dictionary = game._record(id)
	if actor.is_empty(): return "尚未载入"
	if game._hp(actor) <= 0: return "已退场"
	if str(game.selected) == id: return "已选择 · 点完整格放置" if game.phase == game.Phase.DEPLOY else "正在查看"
	return "点击选择" if game.phase == game.Phase.DEPLOY else "战中锁阵 · 可查看"

func refresh() -> void:
	if game == null or monk_button == null: return
	var editing: bool = game.phase == game.Phase.DEPLOY
	var battle: bool = game.phase == game.Phase.BATTLE
	var finished: bool = game.phase == game.Phase.RESULT
	phase_label.text = "布置双方" if editing else ("已暂停" if game.paused else "自动对打中") if battle else "对打结束"
	monk_hp_label.text = _health_text("monk", "护寺棍僧")
	wolf_hp_label.text = _health_text("wolf", "山狼")
	timer_label.text = "对打时间  %.2f 秒" % game.elapsed
	start_button.disabled = not editing
	start_button.text = "开始对打" if editing else "对打进行中" if battle else "对打已结束"
	pause_button.disabled = not battle
	pause_button.text = "继续 P" if game.paused else "暂停 P"
	speed_button.disabled = not battle
	speed_button.text = "%d× 速度" % game.speed
	retry_button.disabled = editing
	return_button.disabled = editing
	cancel_button.disabled = str(game.selected).is_empty()
	monk_state_label.text = _state_text("monk")
	wolf_state_label.text = _state_text("wolf")
	for item in [{"id": "monk", "button": monk_button}, {"id": "wolf", "button": wolf_button}]:
		var card: Button = item.button
		card.add_theme_stylebox_override("normal", _selected_card if str(game.selected) == str(item.id) else _normal_card)
		card.add_theme_stylebox_override("hover", _selected_card if str(game.selected) == str(item.id) else Style.box(Color("294047"), Style.GOLD, 2))
	selection_label.text = "未选择角色" if str(game.selected).is_empty() else "已选：" + ("护寺棍僧" if str(game.selected) == "monk" else "山狼")
	info_label.text = "先点左侧角色卡，再点完整菱格布置。成功落点自动解除选择；右键 / Esc 取消。" if editing else "双方按真实AI逐格接敌与攻击；战中（包括暂停）锁定站位。"
	enemies_label.text = "残缺边角、石框和场地外均不可落子；同格不叠人。" if editing else "逻辑相邻格共享菱形边；每格0.50秒，伤害与原战斗规则不变。"
	status_label.text = str(game.message)
	if finished:
		result_summary.text = ("棍僧获胜" if game.victory else "山狼获胜") + "\n\n可同阵重试，或返回布置调整站位。"
	elif battle:
		result_summary.text = "真实自动对打\n\n不改变攻击射程、伤害或攻击间隔。"
	else:
		result_summary.text = "两名角色均已入场\n\n布置完成后点击“开始对打”。"
