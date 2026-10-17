extends Node2D

# One release per attack serial. Presentation never changes HP.
signal resolved(target, amount, healing, source)
signal released
signal projectile_released(event: Dictionary)
var strikes: Array = []
var missiles: Array = []
var marks: Array = []
var respect_run_casualties := false # Only free mode opts into run-wide losses.
var visual_target := Callable() # Optional display adapters; never affect timing/HP.
var visual_scale := Callable()
var counts := {"attacks":0,"projectiles":0,"hits":0,"heals":0,"cancelled":0}

static func alive(target) -> bool:
	if not is_instance_valid(target): return false
	return target.get("dead") != true and target.get("battle_dead") != true and target.get("run_fallen") != true

static func visual(actor):
	var result = actor.get("presentation")
	return result if result != null else (actor if actor.has_method("impact_delay") else null)

func target_point(actor) -> Vector2:
	return visual_target.call(actor) if visual_target.is_valid() else actor.position+Vector2(0,-35)

func effect_scale(actor) -> float:
	return float(visual_scale.call(actor)) if visual_scale.is_valid() else 1.0

func request(actor, target, healing := false, splash := false) -> void:
	if not alive(actor) or not alive(target): return
	var view = visual(actor)
	var source_key = actor.get("unit_type")
	if source_key == null: source_key = actor.get("enemy_type")
	if source_key == null: source_key = actor.get("role")
	actor.play_attack()
	if view != null:
		view.face(target.position - actor.position if view != actor else target.position)
	strikes.append({"source":actor,"target":target,"view":view,"serial":view.attack_serial if view != null else 0,
		"source_key":source_key,"time":0.0,"amount":actor.damage,"healing":healing,"splash":splash})
	counts.attacks += 1

func tick(delta: float) -> void:
	for missile in missiles.duplicate():
		if not alive(missile.target) or _fallen_source(missile):
			missiles.erase(missile)
			counts.cancelled += 1
			continue
		missile.time += delta
		var aim: Vector2 = target_point(missile.target)
		missile.position = missile.from.lerp(aim, minf(1,missile.time / 0.25))
		if missile.time + 0.0000001 >= 0.25:
			missiles.erase(missile)
			_apply(missile)
	for strike in strikes.duplicate():
		var view = strike.view
		if not alive(strike.source) or not alive(strike.target) or (view != null and (view.attack_serial != strike.serial or view.pose != "basic_attack")):
			strikes.erase(strike)
			counts.cancelled += 1
			continue
		strike.time += delta
		if view != null:
			if view.pose_time + 0.0000001 < view.impact_delay(): continue
		elif strike.time < 0.16: continue
		strikes.erase(strike)
		var texture = null
		var projectile := ""
		if view != null:
			var action: Dictionary = view.manifest.actions.basic_attack
			projectile = str(action.get("projectile", ""))
			if action.has("spawn_vfx"):
				texture = view.effects[action.spawn_vfx]
		if texture != null or not projectile.is_empty():
			var from: Vector2 = view.emission_position()
			if view != strike.source: from += strike.source.position
			strike["from"] = from
			strike["position"] = from
			strike["texture"] = texture
			strike["projectile_kind"] = projectile
			strike.time = 0.0
			if visual_scale.is_valid(): strike["visual_scale_from"]=effect_scale(strike.source)
			missiles.append(strike)
			counts.projectiles += 1
			released.emit()
			projectile_released.emit(strike)
		else:
			_apply(strike)
			if view != null: view.impact_stop = 0.035
	for mark in marks: mark.time -= delta
	marks = marks.filter(func(mark): return mark.time > 0)
	queue_redraw()

func _apply(event: Dictionary) -> void:
	if not alive(event.target) or _fallen_source(event): return
	# The host selects splash recipients and applies gameplay effects once.
	resolved.emit(event.target,event.amount,event.healing,event)
	if event.healing: counts.heals += 1
	else: counts.hits += 1
	var view = visual(event.target)
	if view != null and not event.healing: view.impact_stop = 0.025
	marks.append({"position":target_point(event.target),"time":0.2,"healing":event.healing,"visual_scale":effect_scale(event.target)})

func _fallen_source(event: Dictionary) -> bool:
	return respect_run_casualties and is_instance_valid(event.source) and event.source.get("run_fallen") == true

func clear(reset_counts := false) -> void:
	strikes.clear()
	missiles.clear()
	marks.clear()
	if reset_counts:
		counts = {"attacks":0,"projectiles":0,"hits":0,"heals":0,"cancelled":0}
	queue_redraw()

func _draw() -> void:
	for missile in missiles:
		if not alive(missile.target): continue
		var heading: Vector2 = target_point(missile.target) - missile.from
		var size:=lerpf(float(missile.get("visual_scale_from",1.0)),effect_scale(missile.target),minf(1.0,missile.time/0.25))
		draw_set_transform(missile.position,heading.angle(),Vector2.ONE*size)
		if missile.texture != null:
			draw_texture(missile.texture,-Vector2(missile.texture.get_size())/2)
		else:
			match missile.get("projectile_kind", ""):
				"arrow":
					draw_line(Vector2(-19,0),Vector2(17,0),Color("d7ba79"),2.5,true)
					draw_colored_polygon(PackedVector2Array([Vector2(22,0),Vector2(13,-4),Vector2(13,4)]),Color("e9e5d3"))
					draw_line(Vector2(-19,-4),Vector2(-12,0),Color("d9d4bb"),2,true)
					draw_line(Vector2(-19,4),Vector2(-12,0),Color("d9d4bb"),2,true)
				"stone":
					draw_colored_polygon(PackedVector2Array([Vector2(-5,-3),Vector2(2,-5),Vector2(6,0),Vector2(3,5),Vector2(-5,3)]),Color("aaa58d"))
				"wind": draw_arc(Vector2.ZERO,12,-1.2,1.2,16,Color("acd9ed"),4,true)
				"flame":
					draw_circle(Vector2.ZERO,10,Color("dd653f"))
					draw_circle(Vector2(3,0),5,Color("ffdda2"))
				"heal":
					draw_circle(Vector2.ZERO,9,Color(0.4,0.85,0.65,0.65))
					draw_circle(Vector2.ZERO,4,Color("dcffdf"))
	draw_set_transform(Vector2.ZERO)
	for mark in marks:
		var color := Color("75eba3") if mark.healing else Color("ffd28a")
		color.a = mark.time / 0.2
		draw_arc(mark.position,(15+(0.2-mark.time)*30)*float(mark.get("visual_scale",1.0)),0,TAU,24,color,2)
