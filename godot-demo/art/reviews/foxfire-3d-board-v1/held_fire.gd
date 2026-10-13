extends Node3D

## One small foxfire. The caller attaches each instance to its own palm and
## controls uniform world scale explicitly; never inherit the actor scale twice.
## The unscaled outer radius is approximately 0.125 world units.
## No autonomous process, TIME shader uniform or ParticleProcessMaterial clock.

const FLAME_SHADER = preload("res://held_fire.gdshader")
const SPARK_COUNT := 7
var _configured := false
var _flames: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _sparks: Array[MeshInstance3D] = []
var _spark_materials: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var last_elapsed := 0.0

func _ready() -> void:
	configure()

func configure() -> void:
	if _configured:
		return
	_configured = true
	name = "HeldFoxfire"
	# Closed 3-D volumes remain volumetric from every camera, unlike a crossed
	# pair of textured cards. Keep the colour shell translucent and the hot core
	# compact; this must light the palms, not erase the fox's face.
	_add_flame("OuterEmber", Vector3(0.125, 0.115, 0.125), Vector3.ZERO,
		Color(1.0, 0.20, 0.018), Color(0.82, 0.035, 0.003), 0.20, 0.16, 1.55, 0.0)
	_add_flame("GoldenBody", Vector3(0.101, 0.097, 0.101), Vector3(0, -0.001, 0),
		Color(1.0, 0.63, 0.105), Color(1.0, 0.19, 0.012), 0.53, 0.20, 1.7, 2.0)
	_add_flame("WhiteGoldCore", Vector3(0.058, 0.065, 0.058), Vector3(0, -0.008, 0),
		Color(1.0, 0.94, 0.61), Color(1.0, 0.67, 0.17), 0.90, 0.09, 1.35, 3.4)
	_add_flame("RisingTongueA", Vector3(0.032, 0.072, 0.031), Vector3(-0.037, 0.091, 0.003),
		Color(1.0, 0.43, 0.046), Color(1.0, 0.09, 0.009), 0.34, 0.40, 1.72, 1.8)
	_add_flame("RisingTongueB", Vector3(0.028, 0.058, 0.032), Vector3(0.037, 0.069, -0.018),
		Color(1.0, 0.50, 0.075), Color(1.0, 0.115, 0.008), 0.28, 0.36, 1.62, 4.1)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 1.0
	spark_mesh.height = 2.0
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	for index in range(SPARK_COUNT):
		var spark := MeshInstance3D.new()
		spark.name = "Ember%02d" % index
		spark.mesh = spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.no_depth_test = false
		material.albedo_color = Color(1.0, 0.55, 0.1, 0.8)
		spark.material_override = material
		add_child(spark)
		_sparks.append(spark)
		_spark_materials.append(material)
	_light = OmniLight3D.new()
	_light.name = "PalmWarmth"
	_light.light_color = Color(1.0, 0.40, 0.075)
	_light.light_energy = 0.09
	_light.omni_range = 0.65
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	add_child(_light)
	update_effect(0.0, 0.0, false)

func _add_flame(title: String, dimensions: Vector3, offset: Vector3,
		lower: Color, upper: Color, opacity: float, wobble: float,
		stretch: float, seed: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var flame := MeshInstance3D.new()
	flame.name = title
	flame.mesh = mesh
	flame.scale = dimensions
	flame.position = offset
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("lower_color", lower)
	material.set_shader_parameter("upper_color", upper)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("wobble", wobble)
	material.set_shader_parameter("tip_stretch", stretch)
	material.set_shader_parameter("seed", seed)
	flame.material_override = material
	add_child(flame)
	_flames.append(flame)
	_materials.append(material)

func update_effect(elapsed: float, _delta: float, moving: bool) -> void:
	if not _configured:
		configure()
	last_elapsed = elapsed
	for index in range(_materials.size()):
		_materials[index].set_shader_parameter("effect_time", elapsed)
	# Tiny whole-volume pulsation, not translational drift away from the palms.
	var pulse := 1.0 + 0.025 * sin(elapsed * 6.7) + 0.012 * sin(elapsed * 11.3)
	_flames[0].scale = Vector3(0.125, 0.115, 0.125) * pulse
	_flames[1].rotation.y = 0.22 * sin(elapsed * 1.8)
	_flames[3].rotation.y = elapsed * 0.28
	_flames[4].rotation.y = -elapsed * 0.21
	for index in range(SPARK_COUNT):
		var phase := fposmod(elapsed * (0.82 + index * 0.047) + index * 0.381966, 1.0)
		var angle := index * 2.39996 + phase * 0.8
		var radius := 0.030 + phase * (0.036 if moving else 0.028)
		_sparks[index].position = Vector3(cos(angle) * radius, 0.055 + phase * 0.24, sin(angle) * radius)
		var size := (0.0037 + 0.0014 * sin(index * 1.7 + 0.3)) * (1.0 - phase * 0.50)
		_sparks[index].scale = Vector3(size, size * 1.8, size)
		var opacity := sin(phase * PI) * pow(1.0 - phase, 0.7) * 0.72
		_spark_materials[index].albedo_color = Color(1.0, 0.54 - phase * 0.22, 0.055, opacity)
	_light.light_energy = 0.09 + 0.008 * sin(elapsed * 6.7) + 0.004 * sin(elapsed * 11.3)

func diagnostic_state() -> Dictionary:
	return {
		"configured": _configured,
		"elapsed": last_elapsed,
		"closed_flame_meshes": _flames.size(),
		"embers": _sparks.size(),
		"independent_clock": false,
		"light_casts_shadows": _light.shadow_enabled if _light else false,
		"radius_world_units": 0.125,
	}
