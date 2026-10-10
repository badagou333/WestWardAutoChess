extends Node2D
## Standalone fixed-roster trial. No inherited shop, wave, escort or run ledger.
const Config = preload("res://scripts/data/board_trial_config.gd")
const Space = preload("res://scripts/combat/board_trial_space.gd")
const Melee = preload("res://scripts/combat/board_trial_melee.gd")
const Stepwise = preload("res://scripts/combat/board_trial_stepwise.gd")
const Hero = preload("res://scripts/presentation/board_trial_hero.gd")
const Enemy = preload("res://scripts/presentation/board_trial_enemy.gd")
const Core = preload("res://scripts/board_trial_core.gd")
const Events = preload("res://scripts/combat/attack_events.gd")
const Audio = preload("res://scripts/presentation/board_trial_audio.gd")
const Style = preload("res://scripts/presentation/board_trial_style.gd")
const UI = preload("res://scripts/presentation/board_trial_ui.gd")
const BACKGROUND = preload("res://art/boards/formation_trial_v2/board-courtyard.png")
const BACKGROUND_RECT := Rect2(0,-12,1920,1128)
const CANVAS := Rect2(0,0,1920,1080)
const BOARD_RECT := Rect2(Config.ORIGIN,Vector2(Config.COLS,Config.ROWS)*Config.CELL)
const RANGED_RULE := "ranged-step-target-20261009"
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
var collecting_steps := false
var step_requests: Array[Dictionary] = []
var victory := false
var result_count := 0
var enemy_profile := Config.DEFAULT_ENEMY_PROFILE
var monk_sample_enabled := true
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
var board_overlay: Node2D
var ui
var message := "战前仅左6列部署 · 点击名单选人，再点格子；占格交换，拖动调整，右键取消"

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial Unicode MS"])
	ThemeDB.fallback_font = font
	combat = Events.new()
	add_child(combat)
	combat.resolved.connect(_resolve)
	combat.projectile_released.connect(_projectile_origin)
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
	step_requests.clear()
	collecting_steps = false
	for key in Config.FRIENDS:
		var node = Core.new() if key=="tangseng" else Hero.new()
		if key!="tangseng": node.setup(key)
		add_child(node)
		if key!="tangseng": node.set_bench_mode(false)
		_register(key,key,node,true,deployment.get(key,Vector2i(-1,-1)))
	var enemy_specs: Array=Config.enemy_specs(enemy_profile)
	for index in range(enemy_specs.size()):
		var spec: Array = enemy_specs[index]
		var node = Enemy.new()
		node.setup(spec[0])
		var stats: Dictionary=Config.enemy_stats(spec[0],enemy_profile)
		node.max_health = stats.hp
		node.health = node.max_health
		node.damage = stats.damage
		node.attack_interval = stats.interval
		node.attack_range_cells = stats.range
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
	# Trial movement is a shared board rule, independent of legacy unit catalogs.
	node.move_interval = Config.MOVE_SECONDS_PER_CELL
	if key=="guard_monk": node.presentation.set_motion_sample(monk_sample_enabled)
	node.scale = Vector2.ONE*0.72
	node.visible = Config.valid(cell)
	node.position = Config.center(cell) if Config.valid(cell) else Vector2.ZERO
	node.z_index = int(node.position.y)
	_default_face(node,friendly)
	var hud := Style.new()
	hud.friendly = friendly
	hud.caption = ("唐" if key=="tangseng" else "★") if friendly else id
	hud.z_as_relative = false
	hud.z_index = 2000
	node.add_child(hud)
	if friendly and key!="tangseng":
		node.board_row = cell.y
		node.board_col = cell.x
	actors.append({"id":id,"key":key,"node":node,"friendly":friendly,"cell":cell,"anchor":cell,
		"dead":false,"target":"","mode":"驻留","think":0.0,"cooldown":0.0,"move":{},
		"route":[],"route_goal":Vector2i(-1,-1),"blocked":false,"blocked_elapsed":0.0,"progress_time":-1.0,
		"handoff":{},"move_serial":0,"move_completed":0,
		"step_age":-1.0,"step_hint":Vector2i(-1,-1),"step_target":"",
		"step_wait":{},"step_wait_reason":"","step_serial":0,"step_completed":0,
		"step_retarget":false,
		"visual_manifest":node.presentation.manifest,
		"hp_max":node.max_health,"damage":node.damage,"interval":node.attack_interval,
		"reach":node.attack_range_cells,"walk":node.move_interval,"name":node.display_name})

func load_formation(key: String) -> void:
	if phase!=Phase.DEPLOY or not Config.FORMATIONS.has(key): return
	deployment.clear()
	for index in range(Config.FRIENDS.size()):
		deployment[Config.FRIENDS[index]] = Config.FORMATIONS[key][index]-Vector2i.ONE
	_reset_roster()
	message = "已载入%s阵 · 敌阵和属性不变" % key

func set_enemy_profile(profile: String) -> bool:
	if phase!=Phase.DEPLOY or profile not in Config.ENEMY_PROFILES: return false
	if profile==enemy_profile: return true
	enemy_profile=profile
	_reset_roster()
	_notice({"legacy":"原六怪对照","normal":"强化六怪","bear":"强化六怪＋熊山君"}[profile])
	return true

func set_monk_sample(enabled: bool) -> void:
	monk_sample_enabled=enabled
	var monk: Dictionary=_record("guard_monk")
	if not monk.is_empty() and is_instance_valid(monk.node): monk.node.presentation.set_motion_sample(enabled)
	if ui!=null: ui.refresh()

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
	_default_face(actor.node,actor.friendly)
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
		if Melee.applies(actor): Melee.release(actor)
		actor.cooldown = 0.0
		actor.think = 0.0
		actor.step_retarget = false
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
	return Space.path(actor.cell,goal,reach,func(cell): return not _occupant(cell,actor.id).is_empty())

func _pursuit_path(actor: Dictionary, target: Dictionary) -> Array[Vector2i]:
	var path := _path(actor,target.cell,actor.reach)
	if not path.is_empty(): return path
	# A blocked live activity is temporary, rather than an invalid combat lock.
	var options := Stepwise.candidates(self,actor,target)
	if not options.is_empty(): return options[0].path
	var empty: Array[Vector2i]=[]
	return empty

func _mobile_ranged(actor: Dictionary) -> bool:
	return actor.friendly and actor.key in ["wild_hunter","sparrow_spirit","foxfire_imp"]

func _step_mobile(actor: Dictionary) -> bool:
	return Melee.applies(actor) or _mobile_ranged(actor) or (not actor.friendly and actor.key=="rat")

func _target_legal(actor: Dictionary, target: Dictionary) -> bool:
	if not _active(target) or actor.friendly==target.friendly: return false
	if actor.friendly and not Melee.applies(actor) and not _mobile_ranged(actor):
		return Config.distance(actor.cell,target.cell)<=actor.reach
	return not _pursuit_path(actor,target).is_empty()

func _best_target(actor: Dictionary) -> Dictionary:
	var best := {}
	var score := 999
	for target in actors:
		if not _target_legal(actor,target): continue
		var distance: int = Config.distance(actor.cell,target.cell)
		if not actor.friendly or actor.key=="guard_monk" or _mobile_ranged(actor):
			var path := _pursuit_path(actor,target)
			if path.is_empty(): continue
			distance = path.size()-1
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
	_clear_step_request(actor)
	if actor.cooldown>0.00000001 or actor.node.presentation.pose=="basic_attack": return
	actor.cooldown = actor.interval
	combat.request(actor.node,target.node,healing,actor.key=="foxfire_imp")
	if not metrics.attack_times.has(actor.id): metrics.attack_times[actor.id] = []
	metrics.attack_times[actor.id].append(elapsed)
	if not metrics.first_engagement.has(actor.id): metrics.first_engagement[actor.id] = {"target":target.id,"time":elapsed,"healing":healing}

func _move(actor: Dictionary, next: Vector2i) -> bool:
	if not _active(actor) or not Config.valid(next) or not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return false
	if Config.distance(actor.cell,next)!=1 or not _occupant(next,actor.id).is_empty(): return false
	if actor.friendly and not Melee.applies(actor) and not _mobile_ranged(actor) and Config.distance(actor.anchor,next)>Config.LEASH: return false
	actor.move = {"from":actor.cell,"to":next,"time":0.0,"duration":actor.walk}
	actor.step_serial += 1
	if Melee.applies(actor):
		actor.move_serial += 1
		actor.handoff = {}
	actor.node.presentation.face(Config.center(next)-actor.node.position)
	actor.node.presentation.move_to(Vector2.ZERO)
	return true

func _clear_step_request(actor: Dictionary) -> void:
	actor.step_age = -1.0
	actor.step_wait = {}
	actor.step_wait_reason = ""

func _refresh_landed_target(actor: Dictionary) -> void:
	# Consume one actual landing event. Valid old locks are only replaced by a
	# strictly cheaper reachable attack position; equal cost keeps the target.
	actor.step_retarget = false
	var previous: Dictionary=_record(actor.target)
	var valid: bool=_target_legal(actor,previous)
	var candidate: Dictionary=_best_target(actor)
	var old_path: Array=_pursuit_path(actor,previous) if valid else []
	var new_path: Array=_pursuit_path(actor,candidate) if not candidate.is_empty() else []
	if valid and (new_path.is_empty() or new_path.size()>=old_path.size()): return
	actor.target=candidate.get("id","")
	_clear_step_request(actor)
	actor.step_target=""
	actor.step_hint=Vector2i(-1,-1)

func _request_step(actor: Dictionary) -> void:
	if not _active(actor) or not _step_mobile(actor) or not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return
	var target: Dictionary=_record(actor.target)
	if not _active(target) or Config.distance(actor.cell,target.cell)<=actor.reach: return
	if actor.step_target!=target.id:
		_clear_step_request(actor)
		actor.step_hint=Vector2i(-1,-1)
		actor.step_target=target.id
	if actor.step_age<0: actor.step_age=elapsed
	for pending in step_requests:
		if pending.actor.id==actor.id: return
	step_requests.append({"actor":actor,"target":target,"options":Stepwise.candidates(self,actor,target)})
	if not collecting_steps: _dispatch_steps() # Explicit single-brain boundary calls.

func _dispatch_steps() -> void:
	step_requests.sort_custom(func(a,b):
		return a.actor.step_age<b.actor.step_age if a.actor.step_age!=b.actor.step_age else a.actor.id<b.actor.id)
	# Mutual waiting must see activities that existed before THIS batch, not a
	# new segment just committed by an earlier winner in the request order.
	for request in step_requests:
		request.handoff=Melee.applies(request.actor) and Melee.boundary_wait(self,request.actor,request.target)
	for request in step_requests:
		var actor: Dictionary=request.actor
		var target: Dictionary=request.target
		if not _active(actor) or not _step_mobile(actor) or not _active(target) or actor.target!=target.id or not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": continue
		if Config.distance(actor.cell,target.cell)<=actor.reach:
			_attack(actor,target)
			continue
		# All target intents have been formed before deciding mutual handoffs.
		if request.handoff:
			actor.step_wait_reason="接战格段交接"
			continue
		var committed := false
		var wait := {}
		for option in request.options:
			if not _occupant(option.cell,actor.id).is_empty():
				if wait.is_empty() and not option.wait.is_empty(): wait=option.wait
				continue
			if not _move(actor,option.cell): continue
			actor.step_hint=option.path[2] if option.path.size()>2 else Vector2i(-1,-1)
			_clear_step_request(actor)
			committed=true
			break
		if not committed:
			actor.step_wait=wait
			actor.step_wait_reason="等待在途源格释放" if not wait.is_empty() else ("下一格竞争" if not request.options.is_empty() else "当前无通路")
			actor.mode=actor.step_wait_reason+" → "+actor.target
	step_requests.clear()

func _brain(actor: Dictionary, delta: float) -> void:
	actor.cooldown = maxf(0,actor.cooldown-delta)
	actor.think -= delta
	if Melee.applies(actor):
		Melee.tick(self,actor)
		return
	if not actor.move.is_empty() or actor.node.presentation.pose=="basic_attack": return
	if actor.step_retarget and _step_mobile(actor): _refresh_landed_target(actor)
	var target := _record(actor.target)
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
	if actor.key=="herbal_spirit_child":
		target = _healing_target(actor)
		actor.target = target.get("id","")
		actor.mode = "治疗" if not target.is_empty() else "无伤员 / 超射程"
		if not target.is_empty(): _attack(actor,target,true)
		return
	if not _target_legal(actor,target):
		target = _best_target(actor)
	actor.target = target.get("id","")
	if target.is_empty():
		_clear_step_request(actor)
		actor.step_target=""
		actor.step_hint=Vector2i(-1,-1)
		actor.mode = "无可达目标" if not actor.friendly else "等待 / 超射程"
		return
	actor.mode = "接敌 → "+target.id
	if Config.distance(actor.cell,target.cell)<=actor.reach: _attack(actor,target)
	elif not actor.friendly or _mobile_ranged(actor):
		_request_step(actor)

func _process(delta: float) -> void:
	step(delta)
	if phase==Phase.RESULT:
		# Let collapse/recovery finish visually, without battle time or new effects.
		for actor in actors:
			if is_instance_valid(actor.node): actor.node.tick_visual(delta)
	_update_ui()
	queue_redraw()
	board_overlay.queue_redraw()
	for actor in actors:
		if _active(actor) and actor.target.is_empty() and actor.move.is_empty() and actor.node.presentation.pose=="idle": _default_face(actor.node,actor.friendly)

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
			actor.step_completed = actor.step_serial
			actor.think = 0.0 # Every mobile role re-evaluates on its own landing.
			actor.step_retarget = _step_mobile(actor) and not Melee.applies(actor)
			if Melee.applies(actor):
				actor.move_completed = actor.move_serial
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
		_clear_step_request(actor)
		actor.step_retarget = false
		if Melee.applies(actor): Melee.release(actor)
		if is_instance_valid(actor.node) and not actor.friendly:
			actor.node.play_death()
	collecting_steps = true
	for actor in actors:
		if _active(actor):
			if not actor.handoff.is_empty():
				var opponent: Dictionary=_record(actor.handoff.target)
				if not _active(opponent) or opponent.move.is_empty() or opponent.move_completed>=actor.handoff.segment or opponent.target!=actor.id:
					actor.think=0.0
			if not actor.step_wait.is_empty():
				var holder: Dictionary=_record(actor.step_wait.blocker)
				if not _active(holder) or holder.move.is_empty() or holder.step_completed>=actor.step_wait.serial:
					actor.step_wait={}
					actor.think=0.0
			actor.node.z_index = int(actor.node.position.y)
			_brain(actor,delta)
			if actor.target.is_empty() and actor.move.is_empty() and actor.node.presentation.pose=="idle": _default_face(actor.node,actor.friendly)
	collecting_steps = false
	_dispatch_steps()
	_settle()

func _default_face(node, friendly: bool) -> void:
	node.presentation.facing = 1.0 if friendly else -1.0
	node.presentation.attack_direction = Vector2.RIGHT if friendly else Vector2.LEFT

func _projectile_origin(event: Dictionary) -> void:
	# Local visual-only adapter: scale the existing parent-space socket to the
	# combat canvas. It never changes release, aim, contact time or damage.
	var view = event.view
	if view==null: return
	var point: Vector2 = combat.to_local(view.get_parent().to_global(view.emission_position()))
	event.from = point
	event.position = point

func _by_node(node) -> Dictionary:
	for actor in actors:
		if is_instance_valid(actor.node) and actor.node==node: return actor
	return {}

func _resolve(target, amount: float, healing: bool, event: Dictionary) -> void:
	var source := _by_node(event.source)
	var recipient := _by_node(target)
	if not _active(source) or not _active(recipient): return
	if healing:
		var before: float = target.health
		target.heal(amount)
		var effective: float=target.health-before
		metrics.healing[source.id] = metrics.healing.get(source.id,0.0)+effective
		audio_feedback.role_applied(event,effective)
	else:
		var victims: Array[Dictionary] = [recipient]
		if event.splash:
			for actor in actors:
				if actor.id!=recipient.id and not actor.friendly and _active(actor) and Config.distance(actor.cell,recipient.cell)<=1: victims.append(actor)
		var effective := 0.0
		for victim in victims:
			var before := _hp(victim)
			victim.node.take_damage(amount)
			metrics.damage[source.id] = metrics.damage.get(source.id,0.0)+before-_hp(victim)
			effective+=before-_hp(victim)
			audio_feedback.hit_event(victim.node,event.has("texture"),victim.key=="tangseng",event,before-_hp(victim))
			if not metrics.first_hit.has(source.id): metrics.first_hit[source.id] = {"target":victim.id,"time":elapsed}
		audio_feedback.role_applied(event,effective)
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
	var parameters := []
	var specs: Array=Config.enemy_specs(enemy_profile)
	for index in specs.size():
		var stats: Dictionary=Config.enemy_stats(specs[index][0],enemy_profile)
		parameters.append({"id":"E%d" % (index+1),"key":specs[index][0],"hp":stats.hp,"damage":stats.damage,
			"interval":stats.interval,"range":stats.range,"walk":Config.MOVE_SECONDS_PER_CELL,"initial_cell":[specs[index][1].x,specs[index][1].y]})
	return {"config":Config.version_for(enemy_profile),"enemy_profile":enemy_profile,"enemy_parameters":parameters,"melee_rule":Melee.RULE,"ranged_rule":RANGED_RULE,"phase":phase,"victory":victory,"seconds":elapsed,
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

func _place_from_input(cell: Vector2i) -> void:
	# Data-level place remains selection-neutral; only a successful user drop
	# releases control. Clearing here also prevents release from committing twice.
	if place(selected,cell):
		pointer_origin = Vector2.ZERO
		select("")

func toggle_pause() -> void:
	if phase!=Phase.BATTLE: return
	paused = not paused
	audio_feedback.set_paused(paused)

func _input(event: InputEvent) -> void:
	if is_instance_valid(ui) and ui.help_layer.visible:
		if event is InputEventKey:
			if event.pressed and event.keycode==KEY_ESCAPE: ui.toggle_help()
			get_viewport().set_input_as_handled()
		# Let the modal GUI receive mouse gestures, including its close button.
		# Never run global cancel/selection before the STOP-filtered help layer.
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		selected = ""
		pointer_drag = false
		_notice("已取消选择" if phase==Phase.DEPLOY else "战中锁阵 · 右键不发移动令")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(ui) and ui.help_layer.visible:
		get_viewport().set_input_as_handled()
		return # Defensive fallback: no modal event may reach the board actions.
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
	if not Config.valid(cell):
		if not event.pressed: pointer_drag = false # Failed off-board drop ends gesture, not selection.
		return
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
		elif not selected.is_empty(): _place_from_input(cell)
		elif not occupant.is_empty(): select(occupant.id)
	else:
		if pointer_drag and event.position.distance_to(pointer_origin)>8: _place_from_input(cell)
		pointer_drag = false

func _create_ui() -> void:
	board_overlay = Node2D.new()
	board_overlay.z_index = 1
	board_overlay.draw.connect(_draw_overlay)
	add_child(board_overlay)
	ui = UI.new()
	add_child(ui)
	ui.setup(self)
	for field in ["title_label","status_label","info_label","enemies_label","start_button","retry_button","pause_button","speed_button","withdraw_button","roster_buttons","formation_buttons"]:
		set(field,ui.get(field))

func _update_ui() -> void:
	if is_instance_valid(ui): ui.refresh()

func range_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var actor := _record(selected)
	if actor.is_empty() or not _active(actor): return result
	for row in range(Config.ROWS):
		for col in range(Config.COLS):
			var cell := Vector2i(col,row)
			if Config.distance(actor.cell,cell)<=actor.reach: result.append(cell)
	return result

func hover_cell() -> Vector2i:
	return Config.cell_at(get_global_mouse_position())

func _draw() -> void:
	draw_texture_rect(BACKGROUND,BACKGROUND_RECT,false)
	if phase==Phase.DEPLOY:
		draw_rect(Rect2(Config.ORIGIN,Vector2(Config.DEPLOY_COLS*Config.CELL.x,BOARD_RECT.size.y)),Color(0.267,0.451,0.420,0.047))
		draw_rect(Rect2(Config.ORIGIN+Vector2(Config.DEPLOY_COLS*Config.CELL.x,0),Vector2((Config.COLS-Config.DEPLOY_COLS)*Config.CELL.x,BOARD_RECT.size.y)),Color(0.537,0.282,0.216,0.035))
	for cell in range_cells():
		draw_rect(Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL,Config.CELL),Color(0.459,0.651,0.714,0.09))
	var hovered := hover_cell()
	if Config.valid(hovered):
		draw_rect(Rect2(Config.ORIGIN+Vector2(hovered)*Config.CELL,Config.CELL),Color(0.925,0.882,0.725,0.10))
	for col in range(Config.COLS+1):
		var at := Config.ORIGIN+Vector2(col*Config.CELL.x,0)
		draw_line(at,at+Vector2(0,BOARD_RECT.size.y),Color(0.212,0.220,0.184,0.40),1.5)
	for row in range(Config.ROWS+1):
		var at := Config.ORIGIN+Vector2(0,row*Config.CELL.y)
		draw_line(at,at+Vector2(BOARD_RECT.size.x,0),Color(0.212,0.220,0.184,0.40),1.5)
	draw_rect(BOARD_RECT,Color(0.690,0.592,0.369,0.95),false,3)
	var mid := Config.ORIGIN+Vector2(Config.DEPLOY_COLS*Config.CELL.x,0)
	draw_dashed_line(mid,mid+Vector2(0,BOARD_RECT.size.y),Color(0.855,0.722,0.408,0.75 if phase==Phase.DEPLOY else 0.18),3,9)

func _draw_overlay() -> void:
	# Edge-only highlights above bodies, never an opaque fill over the art/actors.
	for cell in range_cells():
		board_overlay.draw_rect(Rect2(Config.ORIGIN+Vector2(cell)*Config.CELL+Vector2(2,2),Config.CELL-Vector2(4,4)),Color(0.459,0.651,0.714,0.6),false,1)
	var actor := _record(selected)
	if not actor.is_empty() and _active(actor):
		board_overlay.draw_rect(Rect2(Config.ORIGIN+Vector2(actor.cell)*Config.CELL+Vector2(2,2),Config.CELL-Vector2(4,4)),Style.GOLD,false,3)
	var hovered := hover_cell()
	if Config.valid(hovered):
		var rect := Rect2(Config.ORIGIN+Vector2(hovered)*Config.CELL+Vector2(3,3),Config.CELL-Vector2(6,6))
		var invalid: bool = phase==Phase.DEPLOY and not actor.is_empty() and actor.friendly and hovered.x>=Config.DEPLOY_COLS
		board_overlay.draw_rect(rect,Color("c96653") if invalid else Color("ece1b9"),false,2)
		if invalid:
			board_overlay.draw_line(rect.position+Vector2(8,8),rect.position+Vector2(22,22),Color("c96653"),2)
			board_overlay.draw_line(rect.position+Vector2(22,8),rect.position+Vector2(8,22),Color("c96653"),2)
