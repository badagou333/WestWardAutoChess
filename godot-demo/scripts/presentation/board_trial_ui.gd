extends Control
## Trial UI reads live actors/reports, and calls only the existing game actions.
const Style = preload("res://scripts/presentation/board_trial_style.gd")
const Portrait = preload("res://scripts/presentation/board_trial_portrait.gd")
const Meter = preload("res://scripts/presentation/board_trial_meter.gd")
var game
var title_label: Label
var status_label: Label
var info_label: Label
var enemies_label: Label
var phase_label: Label
var timer_label: Label
var core_hp: Label
var core_bar
var start_button: Button
var retry_button: Button
var pause_button: Button
var speed_button: Button
var withdraw_button: Button
var help_button: Button
var help_close: Button
var help_layer: Control
var result_panel: Panel
var result_label: Label
var result_close: Button
var selected_name: Label
var selected_role: Label
var selected_hp: Label
var selected_bar
var selected_portrait
var roster_buttons: Array[Button] = []
var formation_buttons: Array[Button] = []
var card_names: Array[Label] = []
var card_hp: Array[Label] = []
var card_states: Array[Label] = []
var card_bars: Array = []
var card_portraits: Array = []
var enemy_names: Array[Label] = []
var enemy_counts: Array[Label] = []
var enemy_buttons: Array[Button] = []
var enemy_portraits: Array = []
var notice_timer := 0.0
var last_notice := ""
var last_phase := -1

func panel(rect: Rect2, parent: Node = self) -> Panel:
	var control := Panel.new()
	control.position = rect.position
	control.size = rect.size
	control.add_theme_stylebox_override("panel",Style.box())
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func label(rect: Rect2, font := 22, parent: Node = self) -> Label:
	var control := Label.new()
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_override("font",ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size",font)
	control.add_theme_color_override("font_color",Style.INK)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.z_index = 2
	parent.add_child(control)
	return control

func button(rect: Rect2, text: String, action: Callable, parent: Node = self) -> Button:
	var control := Button.new()
	control.position = rect.position
	control.size = rect.size
	control.text = text
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_override("font",ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size",22)
	Style.button(control)
	control.pressed.connect(action)
	control.z_index = 3
	parent.add_child(control)
	return control

func bar(rect: Rect2, parent: Node = self):
	var control := Meter.new()
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.z_index = 2
	parent.add_child(control)
	return control

func portrait(rect: Rect2, parent: Node = self):
	var control := Portrait.new()
	control.position = rect.position
	control.size = rect.size
	control.z_index = 1
	parent.add_child(control)
	return control

func setup(host) -> void:
	game = host
	size = Vector2(1920,1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2100
	panel(Rect2(32,20,1856,112))
	portrait(Rect2(44,30,74,82)).setup("tangseng",false,true)
	title_label = label(Rect2(139,33,250,40),32)
	title_label.text = "西游护送"
	label(Rect2(139,81,250,30),20).text = "松庭 · 单关试炼"
	core_hp = label(Rect2(422,45,236,32))
	core_bar = bar(Rect2(422,89,216,7))
	phase_label = label(Rect2(738,32,390,45),34)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var objective := label(Rect2(738,83,390,30),20)
	objective.text = "保护唐僧 · 清除全部敌人"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label = label(Rect2(1320,55,118,34),24)
	pause_button = button(Rect2(1450,43,155,57),"暂停 P",game.toggle_pause)
	speed_button = button(Rect2(1617,43,115,57),"1×",func(): game.speed = 3-game.speed)
	help_button = button(Rect2(1744,43,130,57),"帮助 ?",toggle_help)
	panel(Rect2(26,179,168,238))
	label(Rect2(32,188,156,34),24).text = "布阵样例"
	for index in range(3):
		var key: String = ["A","B","C"][index]
		formation_buttons.append(button(Rect2(32,237+index*62,154,50),key+"  样例",func(): game.load_formation(key)))
	panel(Rect2(26,740,168,171))
	label(Rect2(32,748,160,109),20).text = "1—6 选择队员\n左键放置 / 拖动\nR 撤下\n右键 / Esc 取消"
	button(Rect2(32,863,154,40),"布阵规则",toggle_help)
	panel(Rect2(1572,176,314,274))
	enemies_label = label(Rect2(1590,188,278,34),24)
	for index in range(3):
		var key: String = ["wolf","boar","rat"][index]
		var row := button(Rect2(1588,233+index*68,282,60),"",func(): inspect_type(key))
		enemy_portraits.append(portrait(Rect2(5,4,52,52),row))
		enemy_names.append(label(Rect2(66,3,127,27),22,row))
		enemy_counts.append(label(Rect2(66,32,134,24),18,row))
		for member in range(2):
			var id := "E%d" % (1+index*2+member)
			var specific := button(Rect2(200+member*39,15,36,30),id,func(): game.select(id),row)
			specific.add_theme_font_size_override("font_size",18)
			enemy_buttons.append(specific)
	panel(Rect2(1572,467,314,437))
	selected_portrait = portrait(Rect2(1590,481,72,72))
	selected_name = label(Rect2(1674,486,194,35),24)
	selected_role = label(Rect2(1674,525,194,28),18)
	selected_hp = label(Rect2(1590,559,278,29),20)
	selected_bar = bar(Rect2(1590,591,278,6))
	info_label = label(Rect2(1590,613,278,231),22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	withdraw_button = button(Rect2(1710,851,158,38),"撤下 R",game.withdraw)
	status_label = label(Rect2(220,918,1320,31),20)
	for index in range(game.Config.FRIENDS.size()):
		var key: String = game.Config.FRIENDS[index]
		var card := button(Rect2(220+index*(1320.0+10)/6,958,(1320.0-50)/6,94),"",func(): game.select(key))
		roster_buttons.append(card)
		card_portraits.append(portrait(Rect2(5,5,69,69),card))
		label(Rect2(5,4,30,23),18,card).text = str(index+1)
		card_names.append(label(Rect2(80,8,126,25),20,card))
		card_hp.append(label(Rect2(80,35,126,25),18,card))
		card_bars.append(bar(Rect2(80,64,121,5),card))
		card_states.append(label(Rect2(12,74,190,22),18,card))
	start_button = button(Rect2(1572,918,314,72),"开始战斗",primary)
	for state in ["normal","hover","pressed"]:
		start_button.add_theme_stylebox_override(state,Style.box(Color("c7a468") if state=="normal" else Color("dec18a"),Style.GOLD,2))
		start_button.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),Color("25312a"))
	start_button.add_theme_font_size_override("font_size",28)
	retry_button = button(Rect2(1572,1003,314,45),"重试布阵",game.retry)
	create_help()
	create_result()

func inspect_type(key: String) -> void:
	var members: Array = game.actors.filter(func(actor): return not actor.friendly and actor.key==key)
	var index := members.find(game._record(game.selected))
	game.select(members[(index+1)%members.size()].id)

func primary() -> void:
	if game.phase==game.Phase.RESULT: result_panel.show()
	else: game.start_battle()

func create_help() -> void:
	help_layer = Control.new()
	help_layer.size = size
	help_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	help_layer.z_index = 20
	add_child(help_layer)
	var window := panel(Rect2(660,170,600,724),help_layer)
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	label(Rect2(30,24,540,43),30,window).text = "布阵与战斗规则"
	var text := label(Rect2(30,87,540,535),22,window)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "战前：1—6或头像选人；左半6列可部署。\n左键放置、拖动调整；已部署友军可交换。\nR撤下（不是出售）；右键 / Esc取消。\n唐僧必须部署，其他队员可选择不上场。\n\n战中：自动战斗；P暂停、1× / 2×。\n暂停也不能移动、交换、撤下或补阵亡位。\n唐僧、药灵驻留；远程输出自动接敌。\n棍僧警戒3格、活动2格，锁定近敌。\n四向寻路，不穿单位，曼哈顿射程无弹道遮挡。\n短堵等原目标，无可接敌才归位。\n无目标朝向对侧，行动按实际目标转身。\n\n唐僧存活且全敌清除才胜利；唐僧死亡失败。\n同一步双方全灭也失败。本场死亡不可复活。\n重试恢复双方全员及上次开战前站位。\n本关无商店 / 人口限制 / 主动技能。"
	help_close = button(Rect2(180,640,240,52),"知道了 / Esc",toggle_help,window)
	help_layer.hide()

func toggle_help() -> void: help_layer.visible = not help_layer.visible

func create_result() -> void:
	result_panel = panel(Rect2(555,278,820,550))
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.z_index = 10
	result_label = label(Rect2(30,26,760,425),24,result_panel)
	result_close = button(Rect2(270,467,280,52),"查看棋盘",func(): result_panel.hide(),result_panel)
	result_panel.hide()

func _process(delta: float) -> void: notice_timer = maxf(0,notice_timer-delta)

func refresh() -> void:
	if game.actors.is_empty(): return
	var core: Dictionary = game._record("tangseng")
	core_hp.text = "唐僧  %d / %d" % [game._hp(core),core.hp_max]
	core_bar.value = 100*game._hp(core)/core.hp_max
	phase_label.text = ["战前布阵","已暂停" if game.paused else "自动战斗","胜利" if game.victory else "失败"][game.phase]
	timer_label.text = "%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60]
	start_button.text = "查看战果" if game.phase==game.Phase.RESULT else ("战斗进行中" if game.phase==game.Phase.BATTLE else "开始战斗")
	start_button.disabled = game.phase==game.Phase.BATTLE
	retry_button.disabled = game.phase==game.Phase.DEPLOY
	pause_button.disabled = game.phase!=game.Phase.BATTLE
	pause_button.text = "继续 P" if game.paused else "暂停 P"
	speed_button.disabled = game.phase!=game.Phase.BATTLE
	speed_button.text = "%d×" % game.speed
	for control in formation_buttons: control.disabled = game.phase!=game.Phase.DEPLOY
	if last_notice!=game.message:
		last_notice = game.message
		notice_timer = 4
	status_label.text = game.message.split("\n")[0] if notice_timer>0 else ("我方队伍 · 1—6选择，左键放置或拖动" if game.phase==game.Phase.DEPLOY else "我方队伍 · 战中锁阵，点选查看实时状态")
	for index in range(roster_buttons.size()):
		var actor: Dictionary = game._record(game.Config.FRIENDS[index])
		card_names[index].text = actor.name
		card_hp[index].text = "%d / %d" % [game._hp(actor),actor.hp_max]
		card_bars[index].value = 100*game._hp(actor)/actor.hp_max
		card_states[index].text = state(actor)
		roster_buttons[index].add_theme_stylebox_override("normal",Style.box(Style.FILL,Style.GOLD if game.selected==actor.id else Style.EDGE,2 if game.selected==actor.id else 1))
		if card_portraits[index].role.is_empty(): card_portraits[index].setup(actor.key,Portrait.idle_source_left(actor.key,actor.node.presentation.manifest),true)
	var alive_count := 0
	for index in range(3):
		var key: String = ["wolf","boar","rat"][index]
		var members: Array = game.actors.filter(func(actor): return not actor.friendly and actor.key==key)
		var living := members.filter(func(actor): return game._alive(actor)).size()
		alive_count += living
		enemy_names[index].text = ["山狼","山猪","灰鼠"][index]
		enemy_counts[index].text = "存活 %d / %d" % [living,members.size()]
		if enemy_portraits[index].role.is_empty(): enemy_portraits[index].setup(key,members[0].node.presentation.manifest.get("source_facing","right")=="left",false)
	enemies_label.text = "敌情 · 存活 %d / 6" % alive_count
	var actor: Dictionary = game._record(game.selected)
	withdraw_button.visible = not actor.is_empty() and actor.friendly
	withdraw_button.disabled = game.phase!=game.Phase.DEPLOY or actor.is_empty() or not game.Config.valid(actor.get("cell",Vector2i(-1,-1)))
	selected_portrait.visible = not actor.is_empty()
	selected_hp.visible = not actor.is_empty()
	selected_bar.visible = not actor.is_empty()
	if actor.is_empty():
		selected_name.text = "选择队员"
		selected_role.text = "或点选上方敌情"
		info_label.text = "点选队员或敌情\n查看实时属性与状态。"
	else:
		selected_portrait.setup(actor.key,Portrait.idle_source_left(actor.key,actor.node.presentation.manifest),actor.friendly)
		selected_name.text = actor.name
		selected_role.text = "友军 · "+("治疗" if actor.key=="herbal_spirit_child" else "近战" if actor.reach==1 else "远程") if actor.friendly else "敌军 · "+actor.id
		selected_hp.text = "生命   %d / %d" % [game._hp(actor),actor.hp_max]
		selected_bar.value = 100*game._hp(actor)/actor.hp_max
		var target: Dictionary = game._record(actor.target)
		var target_text := "%s [%s]" % [target.name,target.id if not target.friendly else str(game.Config.FRIENDS.find(target.id)+1)] if not target.is_empty() else "无"
		info_label.text = "%s %.0f    射程 %d格\n间隔 %.2f秒\n格位 %s\n目标 %s\n状态 %s" % ["治疗" if actor.key=="herbal_spirit_child" else "攻击",actor.damage,actor.reach,actor.interval,str(actor.cell+Vector2i.ONE) if game.Config.valid(actor.cell) else "未部署",target_text,state(actor)]
	if last_phase!=game.phase:
		last_phase = game.phase
		result_panel.visible = game.phase==game.Phase.RESULT
	if game.phase==game.Phase.RESULT:
		var total_damage := 0.0
		var total_healing := 0.0
		var lines := "胜利 · 唐僧存活且全敌清除" if game.victory else "失败 · 唐僧阵亡（同时清敌也失败）"
		lines += "\n用时 %.2f秒 · 唐僧 %d / %d\n\n队员统计（实际伤害 / 有效治疗）\n" % [game.elapsed,game._hp(core),core.hp_max]
		for key in game.Config.FRIENDS:
			var member: Dictionary = game._record(key)
			var damage: float = game.metrics.damage.get(key,0)
			var healing: float = game.metrics.healing.get(key,0)
			total_damage += damage
			total_healing += healing
			lines += "%s · 伤害%.0f · 治疗%.0f · %s\n" % [member.name,damage,healing,"阵亡" if not game._alive(member) else "存活" if game.Config.valid(member.anchor) else "未上场"]
		result_label.text = lines+"\n合计伤害 %.0f · 治疗 %.0f · 阵亡 %d人\n重试恢复全员与开战前布阵" % [total_damage,total_healing,game.report().fallen.size()]

func state(actor: Dictionary) -> String:
	if not game._alive(actor): return "阵亡"
	if not game.Config.valid(actor.cell): return "待部署"
	if game.phase==game.Phase.DEPLOY: return "已部署"
	if actor.mode.begins_with("接敌"): return "接敌"
	return actor.mode
