extends Node3D

# One deterministic presentation-only projectile. No damage, autonomous clock,
# shader TIME, physics, or growing lists of spawned particle nodes.
const HeldFire = preload("res://held_fire.gd")
const SPEED := 6.0
const IMPACT_DURATION := 0.38
var configured := false
var active := false
var age := 0.0
var flight_duration := 0.0
var origin := Vector3.ZERO
var target := Vector3.ZERO
var launch_count := 0
var projectile: Node3D
var tail: Array[MeshInstance3D] = []
var impact: Node3D
var flash: MeshInstance3D
var sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	configure()

func configure() -> void:
	if configured:
		return
	configured = true
	name = "FireAttackEffects"
	projectile = HeldFire.new()
	add_child(projectile)
	projectile.configure()
	projectile.scale = Vector3.ONE * 0.70
	for index in range(5):
		var dot := _glow("Trail%d" % index, Color(1.0, 0.30, 0.035, 0.28 - index * 0.04))
		add_child(dot)
		tail.append(dot)
	impact = Node3D.new()
	impact.name = "FireImpact"
	add_child(impact)
	flash = _glow("SmallFlare", Color(1.0, 0.73, 0.22, 0.58))
	impact.add_child(flash)
	for index in range(8):
		var spark := _glow("ImpactSpark%d" % index, Color(1.0, 0.42, 0.055, 0.8))
		impact.add_child(spark)
		sparks.append(spark)
	reset()

func _glow(title: String, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.no_depth_test = false
	node.material_override = material
	return node

func launch(from: Vector3, to: Vector3) -> void:
	configure()
	origin = from
	target = to
	age = 0.0
	flight_duration = maxf(origin.distance_to(target) / SPEED, 0.06)
	active = true
	launch_count += 1
	_render_state()

func step(delta: float) -> void:
	if not active or delta < 0.0:
		return
	age += delta
	active = age < flight_duration + IMPACT_DURATION
	_render_state()

func _flight_position(at: float) -> Vector3:
	var t := clampf(at / flight_duration, 0.0, 1.0)
	return origin.lerp(target, t) + Vector3.UP * sin(t * PI) * 0.045

func _render_state() -> void:
	var flying := active and age < flight_duration
	projectile.visible = flying
	impact.visible = active and not flying
	if flying:
		projectile.global_position = _flight_position(age)
		projectile.update_effect(age, 0.0, true)
	for index in range(tail.size()):
		var mesh: MeshInstance3D = tail[index]
		mesh.visible = flying and age > (index + 1) * 0.018
		if mesh.visible:
			var sample_time := age - (index + 1) * 0.018
			mesh.global_position = _flight_position(sample_time)
			var tangent := _flight_position(sample_time + 0.009) - _flight_position(sample_time)
			# Overlapping narrow flame wisps, not a string of detached round beads.
			var direction := tangent.normalized() if tangent.length_squared() > 0.000001 else Vector3.FORWARD
			var width := 0.026 - index * 0.003
			mesh.basis = Basis(Quaternion(Vector3.UP, direction)) * Basis.from_scale(Vector3(width, 0.078 - index * 0.006, width))
	if impact.visible:
		impact.global_position = target
		var t := clampf((age - flight_duration) / IMPACT_DURATION, 0.0, 1.0)
		flash.scale = Vector3.ONE * (0.065 + 0.19 * t)
		flash.material_override.albedo_color = Color(1.0, 0.65, 0.15, 0.64 * pow(1.0 - t, 2.0))
		for index in range(sparks.size()):
			var angle := index * TAU / sparks.size()
			var direction := Vector3(cos(angle), 0.35 + 0.20 * sin(index * 1.7), sin(angle)).normalized()
			sparks[index].position = direction * (0.05 + 0.48 * t) + Vector3.DOWN * (0.14 * t * t)
			sparks[index].scale = Vector3.ONE * (0.014 * (1.0 - t) + 0.003)
			sparks[index].material_override.albedo_color = Color(1.0, 0.40, 0.035, 0.8 * (1.0 - t))

func reset() -> void:
	active = false
	age = 0.0
	flight_duration = 0.0
	origin = Vector3.ZERO
	target = Vector3.ZERO
	launch_count = 0
	if configured:
		projectile.hide()
		impact.hide()
		for mesh in tail:
			mesh.hide()

func is_active() -> bool:
	return active

func diagnostic_state() -> Dictionary:
	return {"active": active, "age": age, "launch_count": launch_count,
		"origin": origin, "target": target, "flight_duration": flight_duration,
		"projectile_active": active and age < flight_duration,
		"projectile_position": _flight_position(age) if flight_duration > 0.0 else Vector3.ZERO,
		"impact_active": active and age >= flight_duration,
		"impact_age": maxf(0.0, age - flight_duration), "impact_duration": IMPACT_DURATION,
		"autonomous_clock": false, "trail_count": tail.size(), "impact_spark_count": sparks.size()}
