extends "res://scripts/presentation/board_trial_ui.gd"
## Dedicated noncommercial sound-test UI. No placement, combat or audio policy.
## Normal controls stay outside Rect2(220,190,1320,714); only explicit help is modal.

const KIND_NAMES := {
	"tangseng":"唐僧", "guard_monk":"护寺棍僧", "wild_hunter":"山野猎户",
	"sparrow_spirit":"山雀精", "herbal_spirit_child":"药灵童子", "foxfire_imp":"狐火小妖",
	"wolf":"山狼", "boar":"山猪", "rat":"灰鼠喽啰", "bear_lord":"熊山君"}

# Public handles for production callbacks / headless tests, not GUI acceptance.
var friend_kind: OptionButton
var enemy_kind: OptionButton
var friend_count: SpinBox
var enemy_count: SpinBox
var friend_add: Button
var enemy_add: Button
var unit_choice: OptionButton
var remove_button: Button
var clear_button: Button
var return_button: Button
var filter_friendly: CheckButton
var filter_enemy: CheckButton
var volume: HSlider
var volume_label: Label
var mute_button: Button
var listen_all_button: Button
var default_button: Button
var healing_button: Button
var half_health_button: Button
var full_health_button: Button
var cancel_button: Button
var credits_button: Button
var friend_count_label: Label
var enemy_count_label: Label
var initial_health_label: Label
var help_window: Panel
var _choice_ids: Array[String] = []

func _small_button(rect: Rect2, text: String, action: Callable, parent: Node = self) -> Button:
	var control: Button=button(rect,text,action,parent)
	control.add_theme_font_size_override("font_size",18)
	return control

func _kind_choice(rect: Rect2, kinds: Array) -> OptionButton:
	var control:=OptionButton.new()
	control.position=rect.position
	control.size=rect.size
	control.focus_mode=Control.FOCUS_NONE
	control.add_theme_font_override("font",ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size",18)
	Style.button(control)
	add_child(control)
	for key in kinds:
		control.add_item(str(KIND_NAMES.get(key,key)))
		control.set_item_metadata(control.item_count-1,str(key))
	return control

func _quantity(rect: Rect2) -> SpinBox:
	var control:=SpinBox.new()
	control.position=rect.position
	control.size=rect.size
	control.min_value=1
	control.max_value=game.CAP_PER_SIDE
	control.step=1
	control.rounded=true
	control.value=1
	control.focus_mode=Control.FOCUS_NONE
	control.add_theme_font_override("font",ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size",18)
	add_child(control)
	return control

func _listen_check(rect: Rect2, text: String) -> CheckButton:
	var control:=CheckButton.new()
	control.position=rect.position
	control.size=rect.size
	control.text=text
	control.focus_mode=Control.FOCUS_NONE
	control.add_theme_font_override("font",ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size",18)
	Style.button(control)
	add_child(control)
	control.toggled.connect(func(_enabled): game.set_listen(filter_friendly.button_pressed,filter_enemy.button_pressed))
	return control

func setup(host) -> void:
	game=host
	size=Vector2(1920,1080)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=2100
	# No inherited setup: fixed six-card/two-enemy assumptions do not apply here.
	panel(Rect2(32,20,1856,112))
	title_label=label(Rect2(48,35,360,40),30)
	title_label.text="音效试战 · 非商业试玩"
	usage_label=label(Rect2(48,83,360,29),18)
	usage_label.text="独立试听入口 · 每方最多6人 · 唐僧可选"
	core_hp=label(Rect2(440,40,310,31),20)
	phase_label=label(Rect2(784,35,308,42),30)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	timer_label=label(Rect2(1104,47,100,34),22)
	pause_button=button(Rect2(1216,39,140,58),"暂停 P",game.toggle_pause)
	speed_button=button(Rect2(1368,39,106,58),"1×",func(): game.speed=3-game.speed)
	audio_button=button(Rect2(1486,39,124,58),"静音",func(): game.audio_feedback.enabled=not game.audio_feedback.enabled)
	mute_button=audio_button
	audio_button.add_theme_font_size_override("font_size",20)
	audio_button.tooltip_text="只切换声音，不停止试战或重置阵容。"
	help_button=button(Rect2(1622,39,252,58),"操作说明 / 许可",toggle_help)
	help_button.add_theme_font_size_override("font_size",20)
	filter_friendly=_listen_check(Rect2(438,80,130,36),"我方声")
	filter_enemy=_listen_check(Rect2(568,80,130,36),"敌方声")
	listen_all_button=_small_button(Rect2(710,80,164,36),"听双方",func(): game.set_listen(true,true))
	volume_label=label(Rect2(938,83,220,29),18)
	volume=HSlider.new()
	volume.position=Vector2(1178,87)
	volume.size=Vector2(292,24)
	volume.min_value=0
	volume.max_value=1
	volume.step=0.05
	volume.focus_mode=Control.FOCUS_NONE
	volume.value_changed.connect(func(value): game.audio_feedback.level=value)
	add_child(volume)
	audio_volume=volume # Existing controller/UI compatibility handle.

	# Both adders are outside the left board edge; counts remain explicit 1..6.
	panel(Rect2(26,176,168,728))
	friend_count_label=label(Rect2(32,184,154,28),18)
	friend_kind=_kind_choice(Rect2(32,218,154,42),game.Config.FRIENDS)
	friend_kind.select(game.Config.FRIENDS.find("guard_monk"))
	label(Rect2(32,270,51,24),17).text="数量"
	friend_count=_quantity(Rect2(85,264,101,40))
	friend_add=_small_button(Rect2(32,314,154,42),"添加我方",func(): game.add_units(true,str(friend_kind.get_selected_metadata()),int(friend_count.value)))
	enemy_count_label=label(Rect2(32,378,154,28),18)
	enemy_kind=_kind_choice(Rect2(32,412,154,42),game.ENEMY_KEYS)
	label(Rect2(32,464,51,24),17).text="数量"
	enemy_count=_quantity(Rect2(85,458,101,40))
	enemy_add=_small_button(Rect2(32,508,154,42),"添加敌方",func(): game.add_units(false,str(enemy_kind.get_selected_metadata()),int(enemy_count.value)))
	default_button=_small_button(Rect2(32,568,154,42),"恢复默认对阵",game.reset_default)
	healing_button=_small_button(Rect2(32,620,154,42),"治疗试听预设",game.healing_preset)
	clear_button=_small_button(Rect2(32,672,154,42),"清空双方",game.clear_trial)
	credits_button=_small_button(Rect2(32,732,154,44),"来源与许可",_show_credits)
	label(Rect2(32,795,154,105),16).text="底栏按实例选择\n再点棋盘格移位\n每方最多6个实例\n唐僧可不加入\n无商店 / 合成技能"

	panel(Rect2(1572,176,314,728))
	selected_name=label(Rect2(1590,190,278,36),24)
	selected_role=label(Rect2(1590,234,278,27),18)
	selected_hp=label(Rect2(1590,273,278,29),20)
	selected_bar=bar(Rect2(1590,311,278,6))
	info_label=label(Rect2(1590,333,278,199),18)
	info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	enemies_label=label(Rect2(1590,542,278,57),18)
	initial_health_label=label(Rect2(1590,613,278,38),17)
	initial_health_label.text="辅助血量：仅友方战前可设"
	half_health_button=_small_button(Rect2(1590,661,134,42),"受伤 50%",func(): _set_selected_health(0.5))
	full_health_button=_small_button(Rect2(1734,661,134,42),"满血 100%",func(): _set_selected_health(1.0))
	remove_button=button(Rect2(1590,722,278,46),"删除选中实例",func(): game.remove_selected())
	remove_button.add_theme_font_size_override("font_size",20)
	withdraw_button=remove_button
	label(Rect2(1590,787,278,89),17).text="50%便于试听药灵有效治疗。\n不是受击或播放声音的按钮。\n战中锁定阵容与初始血量；\n同阵重试保留开战前设置。"

	status_label=label(Rect2(220,917,1320,57),18)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(Rect2(220,983,106,25),20).text="场上实例"
	unit_choice=_kind_choice(Rect2(330,994,910,50),[])
	unit_choice.tooltip_text="按唯一实例ID选人；同种角色可以有多名，不按角色种类合并。"
	unit_choice.item_selected.connect(func(index): game.select(str(unit_choice.get_item_metadata(index))))
	cancel_button=button(Rect2(1252,994,288,50),"取消选择",func(): game.select(""))
	start_button=button(Rect2(1572,918,314,64),"开始音效试战",primary)
	start_button.add_theme_font_size_override("font_size",27)
	retry_button=button(Rect2(1572,994,150,54),"同阵重试",game.retry)
	retry_button.add_theme_font_size_override("font_size",20)
	retry_button.tooltip_text="恢复开战前阵容与初始血量，并直接开始下一次试战。"
	return_button=button(Rect2(1732,994,154,54),"返回布置",game.return_to_setup)
	return_button.add_theme_font_size_override("font_size",20)
	_create_modal()
	refresh()

func primary() -> void:
	# Keep this enabled even for empty setup: the controller supplies the error.
	if game.phase==game.Phase.DEPLOY: game.start_battle()

func _set_selected_health(ratio: float) -> void:
	var actor: Dictionary=game._record(str(game.selected))
	if not actor.is_empty() and bool(actor.friendly): game.set_initial_health(game.selected,ratio)

func _spec_for(id: String) -> Dictionary:
	for spec in game.setup_specs:
		if str(spec.id)==id: return spec
	return {}

func _side_count(friendly: bool) -> int:
	var count := 0
	for spec in game.setup_specs:
		if bool(spec.friendly)==friendly: count+=1
	return count

func _living_count(friendly: bool) -> int:
	var count := 0
	for actor in game.actors:
		if bool(actor.friendly)==friendly and game._hp(actor)>0: count+=1
	return count

func _instance_caption(id: String) -> String:
	var spec: Dictionary=_spec_for(id)
	var actor: Dictionary=game._record(id)
	var side := "我方" if bool(spec.get("friendly",actor.get("friendly",false))) else "敌方"
	var key: String=str(spec.get("key",actor.get("key","")))
	var name: String=str(actor.get("name",KIND_NAMES.get(key,key)))
	return "%s · %s · %s · HP %d / %d" % [side,id,name,game._hp(actor) if not actor.is_empty() else 0,actor.get("hp_max",0)]

func _refresh_instances() -> void:
	var ids: Array[String]=[]
	for spec in game.setup_specs: ids.append(str(spec.id))
	if ids!=_choice_ids or unit_choice.item_count==0:
		_choice_ids=ids
		unit_choice.clear()
		unit_choice.add_item("请选择场上实例（右键也可取消）")
		unit_choice.set_item_metadata(0,"")
		for id in ids:
			unit_choice.add_item(_instance_caption(id))
			unit_choice.set_item_metadata(unit_choice.item_count-1,id)
	else:
		# Live HP can change without rebuilding the dropdown or losing its identity.
		for index in range(ids.size()): unit_choice.set_item_text(index+1,_instance_caption(ids[index]))
	unit_choice.select(ids.find(str(game.selected))+1)
	unit_choice.disabled=ids.is_empty()

func refresh() -> void:
	if game==null or friend_kind==null: return
	var editing: bool=game.phase==game.Phase.DEPLOY
	var battle: bool=game.phase==game.Phase.BATTLE
	var friends: int=_side_count(true)
	var enemies: int=_side_count(false)
	friend_count_label.text="我方 %d / %d" % [friends,game.CAP_PER_SIDE]
	enemy_count_label.text="敌方 %d / %d" % [enemies,game.CAP_PER_SIDE]
	core_hp.text="阵容：我方 %d · 敌方 %d" % [friends,enemies]
	if editing: phase_label.text="布置对阵"
	elif battle: phase_label.text="已暂停" if game.paused else "音效试战中"
	else: phase_label.text="试战已结束"
	timer_label.text="%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60]
	status_label.text=str(game.message) # Preserve actual empty-roster / capacity errors.
	for control in [friend_kind,enemy_kind,default_button,healing_button,clear_button]: control.disabled=not editing
	friend_count.editable=editing
	enemy_count.editable=editing
	friend_add.disabled=not editing or friends>=game.CAP_PER_SIDE
	enemy_add.disabled=not editing or enemies>=game.CAP_PER_SIDE
	start_button.disabled=not editing
	start_button.text="开始音效试战" if editing else "试战进行中" if battle else "试战已结束"
	retry_button.disabled=editing
	return_button.disabled=editing
	pause_button.disabled=not battle
	pause_button.text="继续 P" if game.paused else "暂停 P"
	speed_button.disabled=not battle
	speed_button.text="%d×" % game.speed
	audio_button.text="静音" if game.audio_feedback.enabled else "恢复声音"
	filter_friendly.set_pressed_no_signal(game.listen_friendly)
	filter_enemy.set_pressed_no_signal(game.listen_enemy)
	volume.set_value_no_signal(game.audio_feedback.level)
	volume_label.text="音量 %d%%" % roundi(game.audio_feedback.level*100)
	_refresh_instances()
	var actor: Dictionary=game._record(str(game.selected))
	var spec: Dictionary=_spec_for(str(game.selected))
	var selected: bool=not actor.is_empty() and not spec.is_empty()
	remove_button.disabled=not editing or not selected
	half_health_button.disabled=not editing or not selected or not bool(actor.get("friendly",false))
	full_health_button.disabled=not editing or not selected or not bool(actor.get("friendly",false))
	cancel_button.disabled=game.selected.is_empty()
	if not selected:
		selected_name.text="选择场上实例"
		selected_role.text="使用底栏列表或点选棋盘单位"
		selected_hp.text="未选择 · 无血量修改"
		selected_bar.value=0
		info_label.text="先选类型与数量，再添加。\n自动找空格后，可选实例移位。\n同种单位按独立ID选择。\n每方至少1个实例方可开战；\n唐僧不是必选项。"
		initial_health_label.text="辅助血量：仅友方战前可设"
	else:
		selected_name.text="%s · %s" % [actor.id,actor.get("name",KIND_NAMES.get(actor.key,actor.key))]
		selected_role.text=("我方" if actor.friendly else "敌方")+" · 独立实例"
		var hp: float=game._hp(actor)
		var maximum: float=float(actor.get("hp_max",0))
		selected_hp.text="生命   %d / %d" % [hp,maximum]
		selected_bar.value=100*hp/maximum if maximum>0 else 0
		var target: Dictionary=game._record(str(actor.get("target","")))
		var cell: Vector2i=actor.get("cell",Vector2i(-1,-1))
		var target_text: String="%s · %s" % [target.id,target.get("name",target.key)] if not target.is_empty() else "无"
		var mode: String="阵亡" if hp<=0 else "可调整" if editing else str(actor.get("mode","驻留"))
		info_label.text="%s %.0f · 射程 %d格\n间隔 %.2f秒\n格位 %s\n目标 %s\n状态 %s" % ["治疗" if actor.key=="herbal_spirit_child" else "攻击",actor.get("damage",0),actor.get("reach",0),actor.get("interval",0),str(cell+Vector2i.ONE),target_text,mode]
		initial_health_label.text="布置初始血量 %d%% · 战中锁定" % roundi(float(spec.get("initial_hp_ratio",1.0))*100)
	enemies_label.text="存活：我方 %d / %d\n　　　敌方 %d / %d" % [_living_count(true),friends,_living_count(false),enemies]
	if game.phase==game.Phase.RESULT:
		# Outcome/reason comes from the real controller message, not an assumed win.
		var actual: Dictionary=game.report()
		enemies_label.text+=" · %.2f秒" % float(actual.get("seconds",game.elapsed))

func _create_modal() -> void:
	help_layer=Control.new()
	help_layer.size=size
	help_layer.mouse_filter=Control.MOUSE_FILTER_STOP
	help_layer.z_index=20
	add_child(help_layer)
	var backdrop:=ColorRect.new()
	backdrop.size=size
	backdrop.color=Color(0,0,0,0.65)
	backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	help_layer.add_child(backdrop)
	help_window=panel(Rect2(600,160,720,760),help_layer)
	help_window.mouse_filter=Control.MOUSE_FILTER_STOP
	label(Rect2(30,24,660,40),28,help_window).text="音效试战 · 操作与用途"
	var text: Label=label(Rect2(30,84,660,548),22,help_window)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.text="本入口仅供非商业音效试战，不是正式关卡。\n\n双方各选类型和1—6数量添加，每方最多6个。\n允许同种多个独立实例；唐僧可不加入。\n选底栏实例或棋盘单位，再点格移位。\n50% / 100%只改战前初始血量，不直接播声音。\n药灵需要友军真实缺血，才有有效治疗声。\n\n战中只能检查、暂停、倍速和调整听声。\n同阵重试直接开始；返回布置恢复开战前设置。\n监听我方 / 敌方不改变AI、伤害、治疗或选敌。\n死亡/战斗结果及英雄退场不新增声音。\n\n含猎户CC BY-NC素材：仅非商业试玩。\n来源、许可和修改说明可完整查看。"
	_small_button(Rect2(30,678,280,50),"查看完整音效署名",_show_credits,help_window)
	help_close=button(Rect2(330,678,360,50),"关闭说明 / Esc",toggle_help,help_window)
	credits_panel=panel(Rect2(600,160,720,760),help_layer)
	credits_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	label(Rect2(30,24,660,43),28,credits_panel).text="音效完整声明 · 仅非商业试玩"
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(30,84)
	scroll.size=Vector2(660,550)
	credits_panel.add_child(scroll)
	var credits:=RichTextLabel.new()
	credits.custom_minimum_size=Vector2(640,0)
	credits.fit_content=true
	credits.bbcode_enabled=false
	credits.selection_enabled=true
	credits.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	credits.add_theme_font_override("normal_font",ThemeDB.fallback_font)
	credits.add_theme_font_size_override("normal_font_size",18)
	credits.add_theme_color_override("default_color",Style.INK)
	credits.text=FileAccess.get_file_as_string(game.audio_feedback.RUNTIME+"ATTRIBUTION.md")
	scroll.add_child(credits)
	button(Rect2(180,678,360,50),"关闭署名 / Esc",toggle_help,credits_panel)
	credits_panel.hide()
	help_layer.hide() # Required compatibility surface; never opens automatically.

func _show_credits() -> void:
	help_window.hide()
	credits_panel.show()
	help_layer.show()

func toggle_help() -> void:
	if help_layer.visible:
		help_layer.hide()
		credits_panel.hide()
	else:
		help_window.show()
		credits_panel.hide()
		help_layer.show()
