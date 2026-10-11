extends "res://scripts/board_trial.gd"
## Separate configurable audition controller; combat/planning/audio are inherited.
const TrialUI = preload("res://scripts/presentation/audio_trial_ui.gd")
const TrialAudio = preload("res://scripts/presentation/audio_trial_feedback.gd")
const CAP_PER_SIDE := 6
const ENEMY_KEYS := ["wolf","boar","rat","bear_lord"]
var setup_specs: Array[Dictionary]=[]
var start_specs: Array[Dictionary]=[]
var next_instance := 1
var listen_friendly := true
var listen_enemy := true

func _ready() -> void:
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial Unicode MS"])
	ThemeDB.fallback_font=font
	combat=Events.new()
	add_child(combat)
	combat.resolved.connect(_resolve)
	combat.projectile_released.connect(_projectile_origin)
	audio_feedback=TrialAudio.new()
	add_child(audio_feedback)
	combat.projectile_released.connect(audio_feedback.released)
	_create_ui()
	reset_default()

func _spec(id: String) -> Dictionary:
	for spec in setup_specs:
		if spec.id==id: return spec
	return {}

func _new_spec(friendly: bool, key: String, cell: Vector2i, ratio := 1.0) -> Dictionary:
	var id := ("F" if friendly else "E")+"%04d" % next_instance
	next_instance+=1
	return {"id":id,"key":key,"friendly":friendly,"cell":cell,"initial_hp_ratio":ratio}

func _reset_roster() -> void:
	combat.clear(true)
	audio_feedback.stop_all()
	for actor in actors:
		if is_instance_valid(actor.node): actor.node.free()
	actors.clear()
	step_requests.clear()
	collecting_steps=false
	deployment.clear()
	for spec in setup_specs:
		var node
		if spec.friendly:
			node=Core.new() if spec.key=="tangseng" else Hero.new()
			if spec.key!="tangseng": node.setup(spec.key)
		else:
			node=Enemy.new()
			node.setup(spec.key)
			var stats: Dictionary=Config.enemy_stats(spec.key,"bear")
			node.max_health=stats.hp
			node.health=stats.hp
			node.damage=stats.damage
			node.attack_interval=stats.interval
			node.attack_range_cells=stats.range
		node.set_meta("audio_trial_friendly",spec.friendly)
		add_child(node)
		if spec.friendly and spec.key!="tangseng": node.set_bench_mode(false)
		_register(spec.id,spec.key,node,spec.friendly,spec.cell)
		node.health=node.max_health*float(spec.initial_hp_ratio)
		deployment[spec.id]=spec.cell
	selected=""
	pointer_drag=false
	pointer_origin=Vector2.ZERO
	paused=false
	speed=1
	elapsed=0
	accumulator=0
	result_count=0
	victory=false
	metrics={"damage":{},"healing":{},"first_engagement":{},"first_hit":{},"attack_times":{}}
	phase=Phase.DEPLOY
	_update_ui()
	queue_redraw()

func add_units(friendly: bool, key: String, count := 1) -> bool:
	if phase!=Phase.DEPLOY:
		_notice("战中/结果不可增删 · 先回到布置")
		return false
	if key not in (Config.FRIENDS if friendly else ENEMY_KEYS) or count<1 or count>CAP_PER_SIDE:
		_notice("类型或数量无效 · 每次1—6名")
		return false
	var members: Array=setup_specs.filter(func(spec): return spec.friendly==friendly)
	if members.size()+count>CAP_PER_SIDE:
		_notice("试场每方最多6名（实施默认）· 当前%d" % members.size())
		return false
	var used := {}
	for spec in setup_specs: used[spec.cell]=true
	var cells: Array[Vector2i]=[]
	var cols: Array=[4,3,2,1,0,5,6,7,8,9,10,11] if friendly else [6,7,8,9,10,11,5,4,3,2,1,0]
	for row in [3,2,4,1,5,0,6]:
		for col in cols:
			var cell:=Vector2i(col,row)
			if not used.has(cell): cells.append(cell)
	if cells.size()<count:
		_notice("没有足够合法空格")
		return false
	var added := ""
	for index in count:
		var spec:=_new_spec(friendly,key,cells[index])
		setup_specs.append(spec)
		added=spec.id
	_reset_roster()
	select(added)
	_notice("已加入%d名 · 选中后点格/拖动移位；全棋盘可布置" % count)
	return true

func place(id: String, cell: Vector2i) -> bool:
	if phase!=Phase.DEPLOY or not Config.valid(cell):
		_notice("仅战前合法棋盘格可移位 · 原位置保留")
		return false
	var actor: Dictionary=_record(id)
	if actor.is_empty(): return false
	var other: Dictionary=_occupant(cell,id)
	if not other.is_empty():
		if other.friendly!=actor.friendly:
			_notice("不能覆盖另一阵营 · 请选择空格")
			return false
		_spec(other.id).cell=actor.cell
		deployment[other.id]=actor.cell
		_set_cell(other,actor.cell)
	_spec(id).cell=cell
	deployment[id]=cell
	_set_cell(actor,cell)
	_notice("已移位 · 同阵营占格原子交换")
	return true

func remove_selected() -> bool:
	if phase!=Phase.DEPLOY or _spec(selected).is_empty():
		_notice("请在布置阶段选中要删除的实例")
		return false
	setup_specs=setup_specs.filter(func(spec): return spec.id!=selected)
	_reset_roster()
	_notice("已移除所选单位")
	return true

func clear_trial() -> void:
	if phase!=Phase.DEPLOY:
		_notice("战中/结果不可清空配置 · 请先回到布置")
		return
	setup_specs.clear()
	start_specs.clear()
	_reset_roster()
	_notice("已清空并回到布置 · 双方各至少1名才可开战")

func reset_default() -> void:
	if phase!=Phase.DEPLOY:
		_notice("先回到布置再载入预设")
		return
	setup_specs.assign([_new_spec(true,"guard_monk",Vector2i(4,3)),_new_spec(false,"wolf",Vector2i(6,3))])
	start_specs.clear()
	_reset_roster()
	_notice("音效试战 · 默认棍僧1/山狼1 · 唐僧可选")

func healing_preset() -> void:
	if phase!=Phase.DEPLOY:
		_notice("先回到布置再载入治疗预设")
		return
	setup_specs.assign([_new_spec(true,"guard_monk",Vector2i(4,3),0.5),_new_spec(true,"herbal_spirit_child",Vector2i(3,3)),_new_spec(false,"rat",Vector2i(10,3))])
	start_specs.clear()
	_reset_roster()
	_notice("仅试场治疗预设 · 棍僧初始50%HP，药灵实际有效回血")

func set_initial_health(id: String, ratio: float) -> bool:
	var spec: Dictionary=_spec(id)
	if phase!=Phase.DEPLOY or spec.is_empty() or not spec.friendly or ratio not in [0.5,1.0]:
		_notice("辅助初始HP仅战前友军可设50%或100%，不改最大HP/数值")
		return false
	spec.initial_hp_ratio=ratio
	_record(id).node.health=_record(id).hp_max*ratio
	_notice("仅试场辅助 · 初始HP %d%%" % int(ratio*100))
	return true

func start_battle() -> bool:
	if phase!=Phase.DEPLOY: return false
	if setup_specs.filter(func(spec): return spec.friendly).is_empty() or setup_specs.filter(func(spec): return not spec.friendly).is_empty():
		_notice("不能开战：双方各至少放置1名单位")
		return false
	var occupied := {}
	for spec in setup_specs:
		if not Config.valid(spec.cell) or occupied.has(spec.cell):
			_notice("不能开战：存在非法或重复落点")
			return false
		occupied[spec.cell]=true
	start_specs=setup_specs.duplicate(true)
	start_deployment=deployment.duplicate(true)
	for actor in actors:
		if actor.friendly and actor.key!="tangseng": actor.node.begin_battle()
		actor.node.health=actor.hp_max*float(_spec(actor.id).initial_hp_ratio)
		actor.anchor=actor.cell
		actor.target=""
		if Melee.applies(actor): Melee.release(actor)
		actor.cooldown=0
		actor.think=0
		actor.step_retarget=false
		actor.mode="驻留"
	phase=Phase.BATTLE
	selected=""
	pointer_drag=false
	_notice("音效试战自动战斗 · 战中不能改单位/落点/辅助HP")
	return true

func return_to_setup() -> void:
	if phase!=Phase.DEPLOY and not start_specs.is_empty(): setup_specs=start_specs.duplicate(true)
	_reset_roster()
	_notice("已回到开战前布置 · 可增删与调整")

func retry() -> void:
	if start_specs.is_empty():
		_notice("尚无开战快照 · 请先布置并开始")
		return
	setup_specs=start_specs.duplicate(true)
	_reset_roster()
	start_battle()

func set_listen(friendly_on: bool, enemy_on: bool) -> void:
	listen_friendly=friendly_on
	listen_enemy=enemy_on
	audio_feedback.listen_friendly=friendly_on
	audio_feedback.listen_enemy=enemy_on
	_update_ui()

func set_monk_sample(enabled: bool) -> void:
	monk_sample_enabled=enabled
	for actor in actors:
		if actor.key=="guard_monk" and is_instance_valid(actor.node): actor.node.presentation.set_motion_sample(enabled)
	_update_ui()

func _settle() -> void:
	if phase!=Phase.BATTLE: return
	if actors.filter(func(actor): return actor.friendly and _active(actor)).is_empty(): _finish(false)
	elif actors.filter(func(actor): return not actor.friendly and _active(actor)).is_empty(): _finish(true)

func _finish(won: bool) -> void:
	if phase!=Phase.BATTLE: return
	victory=won
	phase=Phase.RESULT
	result_count+=1
	combat.clear()
	paused=false
	audio_feedback.set_paused(false)
	_notice("试场结束 · "+("我方胜" if won else "敌方胜 / 双方同时全灭失败优先")+" · 仅试场全灭规则 · 可同阵重试或回布置")

func report() -> Dictionary:
	var roster := []
	for actor in actors:
		var spec: Dictionary=_spec(actor.id)
		roster.append({"id":actor.id,"key":actor.key,"friendly":actor.friendly,"initial_cell":[spec.cell.x+1,spec.cell.y+1],"initial_hp_ratio":spec.initial_hp_ratio,"hp_max":actor.hp_max,"hp":_hp(actor),"dead":actor.dead,"damage":actor.damage,"interval":actor.interval,"range":actor.reach})
	return {"config":"audio-trial-v1","phase":phase,"victory":victory,"seconds":elapsed,"result_count":result_count,"roster":roster,"metrics":metrics.duplicate(true)}

func _create_ui() -> void:
	board_overlay=Node2D.new()
	board_overlay.z_index=1
	board_overlay.draw.connect(_draw_overlay)
	add_child(board_overlay)
	ui=TrialUI.new()
	add_child(ui)
	ui.setup(self)
	for field in ["title_label","status_label","info_label","enemies_label","start_button","retry_button","pause_button","speed_button","withdraw_button"]:
		set(field,ui.get(field))

func _input(event: InputEvent) -> void:
	if ui.help_layer.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: ui.help_layer.hide()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		select("")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if ui.help_layer.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		var focus:=get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		if event.keycode==KEY_P: toggle_pause()
		elif event.keycode==KEY_DELETE or event.keycode==KEY_BACKSPACE: remove_selected()
		elif event.keycode==KEY_ESCAPE: select("")
		return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	var cell: Vector2i=Config.cell_at(event.position)
	if not Config.valid(cell):
		if not event.pressed: pointer_drag=false
		return
	var occupant: Dictionary=_occupant(cell)
	if phase!=Phase.DEPLOY:
		if event.pressed and not occupant.is_empty(): select(occupant.id)
		return
	if event.pressed:
		pointer_origin=event.position
		pointer_drag=false
		if not occupant.is_empty() and (selected.is_empty() or selected==occupant.id):
			select(occupant.id)
			pointer_drag=true
		elif not selected.is_empty(): _place_from_input(cell)
	else:
		if pointer_drag and event.position.distance_to(pointer_origin)>8: _place_from_input(cell)
		pointer_drag=false

func _draw() -> void:
	draw_texture_rect(BACKGROUND,BACKGROUND_RECT,false)
	for cell in range_cells():
		draw_rect(Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL,Config.CELL),Color(0.459,0.651,0.714,0.09))
	for col in range(Config.COLS+1):
		var at:=Config.ORIGIN+Vector2(col*Config.CELL.x,0)
		draw_line(at,at+Vector2(0,BOARD_RECT.size.y),Color(0.212,0.220,0.184,0.40),1.5)
	for row in range(Config.ROWS+1):
		var at:=Config.ORIGIN+Vector2(0,row*Config.CELL.y)
		draw_line(at,at+Vector2(BOARD_RECT.size.x,0),Color(0.212,0.220,0.184,0.40),1.5)
	draw_rect(BOARD_RECT,Color(0.690,0.592,0.369,0.95),false,3)

func _draw_overlay() -> void:
	for cell in range_cells():
		board_overlay.draw_rect(Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL+Vector2(2,2),Config.CELL-Vector2(4,4)),Color(0.459,0.651,0.714,0.6),false,1)
	var actor: Dictionary=_record(selected)
	if not actor.is_empty() and _active(actor):
		board_overlay.draw_rect(Rect2(Config.ORIGIN+Vector2(actor.cell)*Config.CELL+Vector2(2,2),Config.CELL-Vector2(4,4)),Style.GOLD,false,3)
