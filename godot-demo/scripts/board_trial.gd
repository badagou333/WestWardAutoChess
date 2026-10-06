extends Node2D
## Standalone fixed-roster trial. No inherited shop, wave, escort or run ledger.
const Config = preload("res://scripts/data/board_trial_config.gd")
const Space = preload("res://scripts/combat/board_trial_space.gd")
const Hero = preload("res://scripts/unit.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Core = preload("res://scripts/board_trial_core.gd")
const Events = preload("res://scripts/combat/attack_events.gd")
const Audio = preload("res://scripts/presentation/audio_feedback.gd")
const Style = preload("res://scripts/presentation/roster_style.gd")
enum Phase { DEPLOY, BATTLE, RESULT }
var phase := Phase.DEPLOY
var actors: Array[Dictionary] = [] # Fixed IDs and update order; no freed-node ledger.
var deployment := {}
var start_deployment := {}
var selected := ""
var pointer_origin := Vector2.ZERO
var pointer_drag := false
var paused := false
var speed := 1
var elapsed := 0.0
var accumulator := 0.0
var victory := false
var result_count := 0
var metrics := {}
var combat
var audio_feedback
var status_label: Label
var info_label: Label
var enemies_label: Label
var title_label: Label
var start_button: Button
var retry_button: Button
var pause_button: Button
var speed_button: Button
var withdraw_button: Button
var roster_buttons: Array[Button] = []
var formation_buttons: Array[Button] = []
var message := "战前仅左6列部署 · 点击名单选人，再点格子；占格交换，拖动调整，右键取消"

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial Unicode MS"])
	ThemeDB.fallback_font = font
	combat = Events.new()
	add_child(combat)
	combat.resolved.connect(_resolve)
	audio_feedback = Audio.new()
	add_child(audio_feedback)
	combat.projectile_released.connect(audio_feedback.released)
	_create_ui()
	load_formation("A")

func _record(id: String) -> Dictionary:
	for actor in actors:
		if actor.id==id: return actor
	return {}

func _alive(actor: Dictionary) -> bool:
	return not actor.is_empty() and not actor.dead and is_instance_valid(actor.node) and Events.alive(actor.node)

func _active(actor: Dictionary) -> bool:
	return _alive(actor) and Config.valid(actor.cell)

func _hp(actor: Dictionary) -> float:
	return float(actor.node.health) if _alive(actor) else 0.0

func _reset_roster() -> void:
	combat.clear(true)
	audio_feedback.stop_all()
	for actor in actors:
		if is_instance_valid(actor.node): actor.node.free()
	actors.clear()
	for key in Config.FRIENDS:
		var node = Core.new() if key=="tangseng" else Hero.new()
		if key!="tangseng": node.setup(key)
		add_child(node)
		if key!="tangseng": node.set_bench_mode(false)
		_register(key,key,node,true,deployment.get(key,Vector2i(-1,-1)))
	for index in range(Config.ENEMIES.size()):
		var spec: Array = Config.ENEMIES[index]
		var node = Enemy.new()
		node.setup(spec[0])
		node.max_health *= Config.ENEMY_HP_FACTOR
		node.health = node.max_health
		node.damage *= Config.ENEMY_DAMAGE_FACTOR
		add_child(node)
		_register("E%d" % (index+1),spec[0],node,false,spec[1]-Vector2i.ONE)
	selected = ""
	pointer_drag = false
	paused = false
	speed = 1
	elapsed = 0
	accumulator = 0
	result_count = 0
	victory = false
	metrics = {"damage":{},"healing":{},"first_engagement":{},"first_hit":{},"attack_times":{}}
	phase = Phase.DEPLOY
	_update_ui()
	queue_redraw()

func _register(id: String, key: String, node, friendly: bool, cell: Vector2i) -> void:
	node.scale = Vector2.ONE*0.72
	node.visible = Config.valid(cell)
	node.position = Config.center(cell) if Config.valid(cell) else Vector2.ZERO
	node.z_index = int(node.position.y)
	if friendly and key!="tangseng":
		node.board_row = cell.y
		node.board_col = cell.x
	actors.append({"id":id,"key":key,"node":node,"friendly":friendly,"cell":cell,"anchor":cell,
		"dead":false,"target":"","mode":"驻留","think":0.0,"cooldown":0.0,"move":{},
		"hp_max":node.max_health,"damage":node.damage,"interval":node.attack_interval,
		"reach":node.attack_range_cells,"walk":node.move_interval,"name":node.display_name})

func load_formation(key: String) -> void:
	if phase!=Phase.DEPLOY or not Config.FORMATIONS.has(key): return
	deployment.clear()
	for index in range(Config.FRIENDS.size()):
		deployment[Config.FRIENDS[index]] = Config.FORMATIONS[key][index]-Vector2i.ONE
	_reset_roster()
	message = "已载入%s阵 · 敌阵和属性不变 · 本批配置 %s" % [key,Config.VERSION]

func place(id: String, cell: Vector2i) -> bool:
	if phase!=Phase.DEPLOY:
		_notice("战中/结果锁阵 · 请重试后调整")
		return false
	if not Config.deployable(cell):
		_notice("部署失败：友军仅可放在第1—6列、第1—7行 · 原位置保留")
		return false
	var actor := _record(id)
	if actor.is_empty() or not actor.friendly: return false
	var other := _occupant(cell,id)
	if not other.is_empty():
		if not other.friendly or not Config.deployable(actor.cell):
			_notice("目标格已占用 · 未部署单位请先选空格")
			return false
		deployment[other.id] = actor.cell
		_set_cell(other,actor.cell)
	deployment[id] = cell
	_set_cell(actor,cell)
	_notice("%s已部署到(%d,%d)%s" % [actor.name,cell.x+1,cell.y+1," · 原子交换" if not other.is_empty() else ""])
	return true

func _set_cell(actor: Dictionary, cell: Vector2i) -> void:
	actor.cell = cell
	actor.anchor = cell
	actor.node.position = Config.center(cell) if Config.valid(cell) else Vector2.ZERO
	actor.node.z_index = int(actor.node.position.y)
	actor.node.visible = Config.valid(cell)
	if actor.friendly and actor.key!="tangseng":
		actor.node.board_row = cell.y
		actor.node.board_col = cell.x
	queue_redraw()

func withdraw() -> void:
	if phase!=Phase.DEPLOY:
		_notice("战中不能撤下、互换或补位")
		return
	var actor := _record(selected)
	if actor.is_empty() or not actor.friendly: return
	deployment.erase(selected)
	_set_cell(actor,Vector2i(-1,-1))
	_notice("已撤下%s · 可再次部署，唐僧须落位才能开战" % actor.name)

func start_battle() -> bool:
	if phase!=Phase.DEPLOY: return false
	if not deployment.has("tangseng") or not Config.deployable(deployment.tangseng):
		_notice("不能开战：请先把唐僧放入左半合法空格")
		return false
	start_deployment = deployment.duplicate()
	for actor in actors:
		if actor.friendly and actor.key!="tangseng" and Config.valid(actor.cell): actor.node.begin_battle()
		actor.anchor = actor.cell
		actor.target = ""
		actor.cooldown = 0.0
		actor.think = 0.0
		actor.mode = "驻留"
	phase = Phase.BATTLE
	selected = ""
	pointer_drag = false
	_notice("自动战斗 · 战中仅查看/P暂停/倍速 · 左半边不限制合法AI跨线")
	return true

func retry() -> void:
	if phase==Phase.DEPLOY: return
	deployment = start_deployment.duplicate()
	_reset_roster()
	_notice("重试部署：已恢复全员和开战前站位 · 固定敌阵复原")

func _occupant(cell: Vector2i, excluded := "") -> Dictionary:
	for actor in actors:
		if actor.id==excluded or not _active(actor): continue
		if actor.cell==cell or (not actor.move.is_empty() and actor.move.to==cell): return actor
	return {}

func _path(actor: Dictionary, goal: Vector2i, reach: int) -> Array[Vector2i]:
	var limited: bool = actor.friendly and actor.key=="guard_monk"
	return Space.path(actor.cell,goal,reach,func(cell): return not _occupant(cell,actor.id).is_empty(),actor.anchor,Config.LEASH if limited else -1)

func _target_legal(actor: Dictionary, target: Dictionary) -> bool:
	if not _active(target) or actor.friendly==target.friendly: return false
	if actor.friendly and actor.key=="guard_monk":
		if Config.distance(actor.anchor,target.cell)>Config.AGGRO: return false
	elif actor.friendly:
		return Config.distance(actor.cell,target.cell)<=actor.reach
	return not _path(actor,target.cell,actor.reach).is_empty()

func _best_target(actor: Dictionary) -> Dictionary:
	var best := {}
	var score := 999
	for target in actors:
		if not _target_legal(actor,target): continue
		var distance: int = Config.distance(actor.cell,target.cell)
		if not actor.friendly or actor.key=="guard_monk": distance = _path(actor,target.cell,actor.reach).size()-1
		if distance<score or (distance==score and (best.is_empty() or target.id<best.id)):
			best = target
			score = distance
	return best

func _healing_target(actor: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for ally in actors:
		if not ally.friendly or not _active(ally) or _hp(ally)>=ally.hp_max: continue
		if Config.distance(actor.cell,ally.cell)<=actor.reach: candidates.append(ally)
	candidates.sort_custom(func(a,b):
		var ar: float = _hp(a)/a.hp_max
		var br: float = _hp(b)/b.hp_max
		if not is_equal_approx(ar,br): return ar<br
		var ad: int = Config.distance(actor.cell,a.cell)
		var bd: int = Config.distance(actor.cell,b.cell)
		return ad<bd if ad!=bd else a.id<b.id)
	return candidates[0] if not candidates.is_empty() else {}

func _attack(actor: Dictionary, target: Dictionary, healing := false) -> void:
	if actor.cooldown>0.00000001 or actor.node.presentation.pose=="basic_attack": return
	actor.cooldown = actor.interval
	combat.request(actor.node,target.node,healing,actor.key=="foxfire_imp")
	if not metrics.attack_times.has(actor.id): metrics.attack_times[actor.id] = []
	metrics.attack_times[actor.id].append(elapsed)
	if not metrics.first_engagement.has(actor.id): metrics.first_engagement[actor.id] = {"target":target.id,"time":elapsed,"healing":healing}

func _move(actor: Dictionary, next: Vector2i) -> bool:
	if not _active(actor) or not Config.valid(next) or not actor.move.is_empty(): return false
	if Config.distance(actor.cell,next)!=1 or not _occupant(next,actor.id).is_empty(): return false
	if actor.friendly and Config.distance(actor.anchor,next)>Config.LEASH: return false
	actor.move = {"from":actor.cell,"to":next,"time":0.0,"duration":actor.walk}
	actor.node.presentation.face(Config.center(next)-actor.node.position)
	actor.node.presentation.move_to(Vector2.ZERO)
	return true

func _return(actor: Dictionary) -> void:
	actor.mode = "归位"
	actor.target = ""
	if actor.cell==actor.anchor:
		actor.mode = "驻留"
		return
	var path := _path(actor,actor.anchor,0)
	if path.size()>1:
		_move(actor,path[1])
		return
	var blocker := _occupant(actor.anchor,actor.id)
	if not blocker.is_empty() and not blocker.friendly:
		path = _path(actor,blocker.cell,actor.reach)
		if Config.distance(actor.cell,blocker.cell)<=actor.reach: _attack(actor,blocker)
		elif path.size()>1: _move(actor,path[1])
	actor.mode = "归位等待" if actor.move.is_empty() else "归位"

func _brain(actor: Dictionary, delta: float) -> void:
	actor.cooldown = maxf(0,actor.cooldown-delta)
	actor.think -= delta
	if not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return
	var melee: bool = actor.friendly and actor.key=="guard_monk"
	var target := _record(actor.target)
	if melee and not actor.target.is_empty() and not _active(target):
		actor.mode = "归位"
		actor.target = ""
		actor.think = 0
	if actor.think>0.00000001:
		# SCAN throttles path/target searches, never the original attack cooldown.
		if actor.cooldown<=0.00000001:
			if actor.key=="herbal_spirit_child":
				target = _healing_target(actor)
				actor.target = target.get("id","")
				if not target.is_empty(): _attack(actor,target,true)
			elif _active(target) and target.friendly!=actor.friendly and Config.distance(actor.cell,target.cell)<=actor.reach:
				_attack(actor,target)
		return
	actor.think = Config.SCAN
	if melee and actor.mode.begins_with("归位"):
		_return(actor)
		return
	if actor.key=="herbal_spirit_child":
		target = _healing_target(actor)
		actor.target = target.get("id","")
		actor.mode = "治疗" if not target.is_empty() else "无伤员 / 超射程"
		if not target.is_empty(): _attack(actor,target,true)
		return
	if not _target_legal(actor,target):
		if melee and not actor.target.is_empty():
			_return(actor)
			return
		target = _best_target(actor)
	actor.target = target.get("id","")
	if target.is_empty():
		actor.mode = "无可达目标" if not actor.friendly else "等待 / 超射程"
		if melee and actor.cell!=actor.anchor: _return(actor)
		return
	actor.mode = "接敌 → "+target.id
	if Config.distance(actor.cell,target.cell)<=actor.reach: _attack(actor,target)
	elif not actor.friendly or melee:
		var path := _path(actor,target.cell,actor.reach)
		if path.size()>1: _move(actor,path[1])

func _process(delta: float) -> void:
	step(delta)
	if phase==Phase.RESULT:
		# Let collapse/recovery finish visually, without battle time or new effects.
		for actor in actors:
			if is_instance_valid(actor.node): actor.node.tick_visual(delta)
	_update_ui()
	queue_redraw()

func step(delta: float) -> void:
	if phase!=Phase.BATTLE or paused: return
	accumulator += delta*speed
	while accumulator+0.00000001>=Config.STEP and phase==Phase.BATTLE:
		accumulator -= Config.STEP
		_tick(Config.STEP)

func _tick(delta: float) -> void:
	elapsed += delta
	for actor in actors:
		if is_instance_valid(actor.node): actor.node.tick_visual(delta)
		if not _active(actor) or actor.move.is_empty(): continue
		actor.move.time += delta
		actor.node.position = Config.center(actor.move.from).lerp(Config.center(actor.move.to),minf(1,actor.move.time/actor.move.duration))
		if actor.move.time+0.00000001>=actor.move.duration:
			actor.cell = actor.move.to
			actor.node.position = Config.center(actor.cell)
			actor.move = {}
	# Dead sources cannot complete pending effects in this trial; legacy untouched.
	combat.strikes = combat.strikes.filter(func(event): return Events.alive(event.source) and Events.alive(event.target))
	combat.missiles = combat.missiles.filter(func(event): return Events.alive(event.source) and Events.alive(event.target))
	combat.tick(delta)
	for actor in actors:
		if actor.dead or _alive(actor): continue
		actor.dead = true
		actor.mode = "阵亡"
		actor.target = ""
		actor.move = {}
		if is_instance_valid(actor.node) and not actor.friendly:
			actor.node.play_death()
			audio_feedback.play_cue(actor.key+"_death")
	for actor in actors:
		if _active(actor):
			actor.node.z_index = int(actor.node.position.y)
			_brain(actor,delta)
	_settle()

func _by_node(node) -> Dictionary:
	for actor in actors:
		if is_instance_valid(actor.node) and actor.node==node: return actor
	return {}

func _resolve(target, amount: float, healing: bool, event: Dictionary) -> void:
	var source := _by_node(event.source)
	var recipient := _by_node(target)
	if not _active(source) or not _active(recipient): return
	audio_feedback.resolved_attack(event)
	if healing:
		var before: float = target.health
		target.heal(amount)
		metrics.healing[source.id] = metrics.healing.get(source.id,0.0)+target.health-before
	else:
		var victims: Array[Dictionary] = [recipient]
		if event.splash:
			for actor in actors:
				if actor.id!=recipient.id and not actor.friendly and _active(actor) and Config.distance(actor.cell,recipient.cell)<=1: victims.append(actor)
		for victim in victims:
			var before := _hp(victim)
			victim.node.take_damage(amount)
			metrics.damage[source.id] = metrics.damage.get(source.id,0.0)+before-_hp(victim)
			audio_feedback.hit(victim.node,event.has("texture"),victim.key=="tangseng")
			if not metrics.first_hit.has(source.id): metrics.first_hit[source.id] = {"target":victim.id,"time":elapsed}
	queue_redraw()

func _settle() -> void:
	if phase!=Phase.BATTLE: return
	if not _alive(_record("tangseng")): _finish(false)
	elif actors.filter(func(actor): return not actor.friendly and _active(actor)).is_empty(): _finish(true)

func _finish(won: bool) -> void:
	if phase!=Phase.BATTLE: return
	victory = won
	phase = Phase.RESULT
	result_count += 1
	combat.clear()
	paused = false
	audio_feedback.set_paused(false)
	if won: audio_feedback.play_cue("victory")
	var damage := 0.0
	var healing := 0.0
	var losses: Array[String] = []
	for actor in actors:
		if not actor.friendly: continue
		damage += float(metrics.damage.get(actor.id,0))
		healing += float(metrics.healing.get(actor.id,0))
		if Config.valid(actor.anchor) and not _alive(actor): losses.append(actor.name)
	_notice(("胜利：唐僧存活且全敌清除" if won else "失败：唐僧阵亡 · 同时清敌仍失败优先")+"\n友军实际伤害 %.0f · 有效治疗 %.0f · 阵亡：%s · 重试可修改开战前站位" % [damage,healing,"无" if losses.is_empty() else "、".join(losses)])

func report() -> Dictionary:
	var fallen: Array[String] = []
	for actor in actors:
		if actor.friendly and Config.valid(actor.anchor) and not _alive(actor): fallen.append(actor.id)
	return {"config":Config.VERSION,"phase":phase,"victory":victory,"seconds":elapsed,
		"tangseng_hp":_hp(_record("tangseng")),"fallen":fallen,"result_count":result_count,"metrics":metrics.duplicate(true)}

func _notice(value: String) -> void:
	message = value
	_update_ui()
	queue_redraw()

func select(id: String) -> void:
	selected = id
	pointer_drag = false
	_update_ui()
	queue_redraw()

func toggle_pause() -> void:
	if phase!=Phase.BATTLE: return
	paused = not paused
	audio_feedback.set_paused(paused)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		selected = ""
		pointer_drag = false
		_notice("已取消选择" if phase==Phase.DEPLOY else "战中锁阵 · 右键不发移动令")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		if event.keycode>=KEY_1 and event.keycode<=KEY_6: select(Config.FRIENDS[event.keycode-KEY_1])
		elif event.keycode==KEY_P: toggle_pause()
		elif event.keycode==KEY_R: withdraw()
		elif event.keycode==KEY_F: _notice("战前直接点选目标格交换 · 战中禁止互换")
		elif event.keycode==KEY_ESCAPE:
			selected = ""
			pointer_drag = false
		return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	var cell := Config.cell_at(event.position)
	if not Config.valid(cell): return
	var occupant := _occupant(cell)
	if phase!=Phase.DEPLOY:
		if event.pressed:
			if not occupant.is_empty(): select(occupant.id)
			_notice("战中/结果仅查看 · 暂停也不能改阵")
		return
	if event.pressed:
		pointer_origin = event.position
		pointer_drag = false
		if not occupant.is_empty() and occupant.friendly and (selected.is_empty() or selected==occupant.id):
			select(occupant.id)
			pointer_drag = true
		elif not selected.is_empty(): place(selected,cell)
		elif not occupant.is_empty(): select(occupant.id)
	else:
		if pointer_drag and event.position.distance_to(pointer_origin)>8: place(selected,cell)
		pointer_drag = false

func _label(at: Vector2, size: Vector2, font := 20) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_font_override("font",ThemeDB.fallback_font)
	label.add_theme_color_override("font_color",Style.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 2001
	add_child(label)
	return label

func _button(at: Vector2, size: Vector2, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.position = at
	button.size = size
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_font_override("font",ThemeDB.fallback_font)
	Style.button(button)
	button.pressed.connect(action)
	button.z_index = 2002
	add_child(button)
	return button

func _create_ui() -> void:
	title_label = _label(Vector2(22,12),Vector2(1150,38),26)
	status_label = _label(Vector2(220,73),Vector2(1330,76),19)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label = _label(Vector2(18,250),Vector2(186,654),19)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemies_label = _label(Vector2(1563,182),Vector2(342,714),19)
	enemies_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button(Vector2(1545,22),Vector2(150,52),"开始战斗",start_battle)
	retry_button = _button(Vector2(1705,22),Vector2(195,52),"重试布阵",retry)
	pause_button = _button(Vector2(1180,22),Vector2(160,52),"暂停 [P]",toggle_pause)
	speed_button = _button(Vector2(1350,22),Vector2(180,52),"速度 1×",func(): speed = 3-speed)
	for index in range(3):
		var key: String = ["A","B","C"][index]
		formation_buttons.append(_button(Vector2(18,93+index*48),Vector2(186,40),"站位样例 "+key,func(): load_formation(key)))
	for index in range(Config.FRIENDS.size()):
		var key: String = Config.FRIENDS[index]
		roster_buttons.append(_button(Vector2(220+index*220,960),Vector2(212,93),"",func(): select(key)))
	withdraw_button = _button(Vector2(1563,960),Vector2(335,45),"撤下选中 [R]",withdraw)
	_label(Vector2(1563,1015),Vector2(335,42),19).text = "本原型无技能 / 商店 / 营地"

func _update_ui() -> void:
	if not is_instance_valid(status_label) or actors.is_empty(): return
	title_label.text = "12×7 布阵对照 · %s · 唐僧 %d/300 · %.1fs" % [["部署","自动战斗","胜利" if victory else "失败"][phase],int(_hp(_record("tangseng"))),elapsed]
	status_label.text = ("已暂停 · " if paused else "")+message
	start_button.disabled = phase!=Phase.DEPLOY
	retry_button.disabled = phase==Phase.DEPLOY
	pause_button.disabled = phase!=Phase.BATTLE
	pause_button.text = "继续 [P]" if paused else "暂停 [P]"
	speed_button.disabled = phase!=Phase.BATTLE
	speed_button.text = "速度 %d×" % speed
	withdraw_button.disabled = phase!=Phase.DEPLOY or selected.is_empty() or not _record(selected).get("friendly",false)
	for button in formation_buttons: button.disabled = phase!=Phase.DEPLOY
	for index in range(roster_buttons.size()):
		var actor := _record(Config.FRIENDS[index])
		var state_text := "已部署" if Config.valid(actor.cell) else "待部署"
		if not _alive(actor): state_text = "阵亡"
		elif phase!=Phase.DEPLOY:
			state_text = "等待"
			for short in ["接敌","归位","治疗"]:
				if actor.mode.begins_with(short): state_text = short
		roster_buttons[index].text = "[%d] %s\n%d/%d · %s" % [index+1,actor.name,int(_hp(actor)),int(actor.hp_max),state_text]
		roster_buttons[index].add_theme_color_override("font_color",Style.GOLD if selected==actor.id else Style.INK)
	var actor := _record(selected)
	info_label.text = "战前布阵\n列1—6 / 行1—7\n\n选名单后点格子\n占格原子交换\n也可拖动已部署者\n右键/Esc取消\nR撤下（非出售）\n\n战中只自动战斗\nP暂停 / 1×·2×\n暂停不解除锁阵\n\n近战锚点警戒3格\n活动半径2格\n远程/药灵驻留\n无目标不会追全图"
	if not actor.is_empty():
		info_label.text = "%s [%s]\nHP %d/%d\n%s %.0f · %.2fs\n射程 %d格\n格位 %s\n目标 %s\n状态 %s\n\n曼哈顿射程\n无弹道遮挡\n近战固定锚点\n不穿任何单位\n\n战前仅左6列\n战中合法AI可跨线\n本关死亡不补位\n重试恢复全员" % [actor.name,actor.id,int(_hp(actor)),int(actor.hp_max),"治疗" if actor.key=="herbal_spirit_child" else "攻击",actor.damage,actor.interval,actor.reach,str(actor.cell+Vector2i.ONE) if Config.valid(actor.cell) else "未部署",actor.target if not actor.target.is_empty() else "无",actor.mode]
	var lines := "公开固定敌阵 · %s\n目标：最短可达攻击路径\n合法目标保持 · 同分按ID\n格位均为(列,行)，从1开始\n\n" % Config.VERSION
	for enemy in actors:
		if enemy.friendly: continue
		lines += "%s %s · (%d,%d)\nHP %d/%d · 攻%.0f · 距%d\n%.2fs · %s\n" % [enemy.id,enemy.name,enemy.anchor.x+1,enemy.anchor.y+1,int(_hp(enemy)),int(enemy.hp_max),enemy.damage,enemy.reach,enemy.interval,enemy.mode]
	enemies_label.text = lines

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1920,1080)),Color("181d19"))
	for row in range(Config.ROWS):
		for col in range(Config.COLS):
			var cell := Vector2i(col,row)
			var rect := Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL,Config.CELL)
			draw_rect(rect,Color("303d32") if col<6 else Color("3f3330"))
			draw_rect(rect,Style.EDGE,false,1)
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(6,20),"%d,%d" % [col+1,row+1],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Style.MUTED)
	draw_line(Config.ORIGIN+Vector2(Config.DEPLOY_COLS*Config.CELL.x,0),Config.ORIGIN+Vector2(Config.DEPLOY_COLS*Config.CELL.x,Config.ROWS*Config.CELL.y),Style.GOLD,3)
	var actor := _record(selected)
	if not actor.is_empty() and _active(actor):
		for row in range(Config.ROWS):
			for col in range(Config.COLS):
				var cell := Vector2i(col,row)
				if Config.distance(actor.cell,cell)<=actor.reach:
					draw_rect(Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL,Config.CELL),Color(0.8,0.75,0.4,0.12))
		draw_arc(actor.node.position,34,0,TAU,40,Style.GOLD,3)
	for entry in actors:
		if entry.friendly and _active(entry) and entry.key=="guard_monk": draw_arc(Config.center(entry.anchor),20,0,TAU,32,Color("809379"),2)
