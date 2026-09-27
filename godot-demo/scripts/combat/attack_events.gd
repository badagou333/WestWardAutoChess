extends Node2D

# One release per attack serial. Presentation never changes HP.
signal resolved(target, amount, healing, source)
signal released
var strikes: Array = []
var missiles: Array = []
var marks: Array = []
var counts := {"attacks":0,"projectiles":0,"hits":0,"heals":0,"cancelled":0}

static func alive(target) -> bool:
	if not is_instance_valid(target): return false
	return target.get("dead") != true and target.get("battle_dead") != true

static func visual(actor):
	var result = actor.get("presentation")
	return result if result != null else (actor if actor.has_method("impact_delay") else null)

func request(actor, target, healing := false, splash := false) -> void:
	if not alive(actor) or not alive(target): return
	var view = visual(actor)
	actor.play_attack()
	if view != null:
		view.face(target.position - actor.position if view != actor else target.position)
	strikes.append({"source":actor,"target":target,"view":view,"serial":view.attack_serial if view != null else 0,
		"time":0.0,"amount":actor.damage,"healing":healing,"splash":splash})
	counts.attacks += 1

func tick(delta: float) -> void:
	for missile in missiles.duplicate():
		if not alive(missile.target):
			missiles.erase(missile)
			counts.cancelled += 1
			continue
		missile.time += delta
		var aim: Vector2 = missile.target.position + Vector2(0,-35)
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
		if view != null:
			var action: Dictionary = view.manifest.actions.basic_attack
			if action.has("spawn_vfx"):
				texture = view.effects[action.spawn_vfx]
		if texture != null:
			var from: Vector2 = view.emission_position()
			if view != strike.source: from += strike.source.position
			strike["from"] = from
			strike["position"] = from
			strike["texture"] = texture
			strike.time = 0.0
			missiles.append(strike)
			counts.projectiles += 1
			released.emit()
		else:
			_apply(strike)
			if view != null: view.impact_stop = 0.035
	for mark in marks: mark.time -= delta
	marks = marks.filter(func(mark): return mark.time > 0)
	queue_redraw()

func _apply(event: Dictionary) -> void:
	if not alive(event.target): return
	# The host selects splash recipients and applies gameplay effects once.
	resolved.emit(event.target,event.amount,event.healing,event)
	if event.healing: counts.heals += 1
	else: counts.hits += 1
	var view = visual(event.target)
	if view != null and not event.healing: view.impact_stop = 0.025
	marks.append({"position":event.target.position+Vector2(0,-35),"time":0.2,"healing":event.healing})

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
		var heading: Vector2 = missile.target.position + Vector2(0,-35) - missile.from
		draw_set_transform(missile.position,heading.angle())
		draw_texture(missile.texture,-Vector2(missile.texture.get_size())/2)
	draw_set_transform(Vector2.ZERO)
	for mark in marks:
		var color := Color("75eba3") if mark.healing else Color("ffd28a")
		color.a = mark.time / 0.2
		draw_arc(mark.position,15+(0.2-mark.time)*30,0,TAU,24,color,2)
