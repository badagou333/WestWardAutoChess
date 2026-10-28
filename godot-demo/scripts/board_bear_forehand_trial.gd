extends "res://scripts/board_depth.gd"
## Independent main-board trial; never changes the default board entry.
const BearForehandView = preload("res://scripts/presentation/board_bear_forehand_view.gd")
const BEAR_TRACK := "res://art/runtime/bear_forehand_trial_v1/manifest.json"
const TRIAL_WARNING := "试验版：仅右前攻击使用新动作，其他方向沿用原动作；造型切换与挥击仍待完善。"
var trial_track_ready := false
var trial_target := ""
var trial_warning: Label

func _ready() -> void:
	super._ready()
	var panel := PanelContainer.new()
	panel.position = Vector2(220,851)
	panel.size = Vector2(1320,54)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",Style.box(Color("26302d"),Color("c7a468"),2))
	ui.add_child(panel)
	trial_warning = Label.new()
	trial_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trial_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trial_warning.add_theme_font_override("font",ThemeDB.fallback_font)
	trial_warning.add_theme_color_override("font_color",Style.INK)
	trial_warning.add_theme_font_size_override("font_size",21)
	trial_warning.text = TRIAL_WARNING
	panel.add_child(trial_warning)
	_refresh_title()
	_notice("独立试验：熊从目标左侧进攻，便于观察右前向。素材未就绪时沿用旧动作。")

func _refresh_title() -> void:
	if title_label == null: return
	var state := "单方向素材已加载" if trial_track_ready else "素材未就绪 · 当前为旧动作"
	if _record("E7").is_empty(): state = "当前阵容无熊山君"
	elif trial_target.is_empty(): state += " · 未找到右侧目标"
	title_label.text = "熊正手·右前试验"
	title_label.tooltip_text = state
	if trial_warning != null: trial_warning.text = state + "。" + TRIAL_WARNING

func _register(id: String, key: String, node, friendly: bool, cell: Vector2i) -> void:
	super._register(id,key,node,friendly,cell)
	if key != "bear_lord": return
	var previous = node.presentation
	if not previous.has_method("draw_sample"): return
	var track: Dictionary = _load_bear_track()
	var view = BearForehandView.new()
	view.copy_playback(previous,_record(id),previous.direction_pack)
	node.add_child(view)
	node.presentation = view
	previous.free()
	trial_track_ready = view.configure_trial(track)

func _load_bear_track() -> Dictionary:
	return BearForehandView.load_trial(BEAR_TRACK)

func _reset_roster() -> void:
	super._reset_roster()
	trial_track_ready = false
	trial_target = ""
	var bear: Dictionary = _record("E7")
	if bear.is_empty():
		_refresh_title()
		return
	var view = bear.node.presentation
	trial_track_ready = view.get_script() == BearForehandView and not view.trial_track.is_empty()
	var original_cell: Vector2i = bear.cell
	# Place the bear immediately screen-left of an existing friendly actor; this
	# trial-only setup makes the delivered, non-mirrored direction observable.
	for key in ["wild_hunter","guard_monk","sparrow_spirit","herbal_spirit_child","foxfire_imp","tangseng"]:
		var target: Dictionary = _record(key)
		if not _active(target): continue
		var cell: Vector2i = target.cell + Vector2i.LEFT
		if not valid_cell(cell) or not _occupant(cell,bear.id).is_empty(): continue
		_set_cell(bear,cell)
		# The normal targeting rules must actually pick this actor. A different
		# adjacent unit could otherwise steal the attack and turn the bear left.
		if _best_target(bear).get("id","") != key: continue
		trial_target = key
		break
	if trial_target.is_empty(): _set_cell(bear,original_cell)
	_refresh_title()
