extends Node3D
## Presentation follows the same front/rear axis as the actual damage filter.
const SHIELD_SHADER := preload("res://shaders/dream3d/h06_shield.gdshader")
const FIELD_CENTER := Vector3(0.0, 1.02, 0.0)
const FIELD_RADII := Vector3(4.20, 2.72, 4.32)
const IMPACT_SLOTS := 4
const EXPIRED_IMPACT := Vector4(0.0, 0.0, 0.0, -2.0)

var model: Node3D
var material: ShaderMaterial
var field: MeshInstance3D
var field_time := 0.0
var impacts := PackedVector4Array()
var next_impact := 0

func configure(chassis: Node3D) -> void:
	model = chassis
	name = "H06FrontAndSideShield"
	material = ShaderMaterial.new()
	material.shader = SHIELD_SHADER
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	field = MeshInstance3D.new()
	field.name = "EnergyField"
	field.mesh = sphere
	field.position = FIELD_CENTER
	field.scale = FIELD_RADII
	field.material_override = material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.hide()
	add_child(field)
	impacts.resize(IMPACT_SLOTS)
	impacts.fill(EXPIRED_IMPACT)
	material.set_shader_parameter("impacts", impacts)

	var socket := StandardMaterial3D.new()
	socket.albedo_color = Color("172429")
	var emitter := StandardMaterial3D.new()
	emitter.albedo_color = Color("57e5d9")
	emitter.emission_enabled = true
	emitter.emission = Color("33bdb1")
	emitter.emission_energy_multiplier = 1.15
	_plate("RearVent", Vector3(0, 1.47, -1.94), Vector3(1.30, .28, .16), socket)
	for i in 5:
		_plate("OpenVent%d" % i, Vector3((i-2)*.225, 1.5, -2.025), Vector3(.145,.13,.075), emitter)
	_follow_model()

func set_shield_active(enabled: bool) -> void:
	if field.visible == enabled: return
	field.visible = enabled
	field_time = 0.0
	next_impact = 0
	impacts.fill(EXPIRED_IMPACT)
	material.set_shader_parameter("impacts", impacts)
	material.set_shader_parameter("field_time", field_time)

func is_shield_active() -> bool:
	return field.visible

func _plate(label: String, at: Vector3, size: Vector3, surface: Material) -> void:
	var plate := MeshInstance3D.new()
	plate.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	plate.mesh = mesh
	plate.material_override = surface
	plate.position = at
	plate.rotation.x = -.22
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)

func flash(at: Vector3, incoming: Vector3) -> void:
	_follow_model()
	var point := field.to_local(at)
	# Backtrack from the real armor hit to the surface of the energy field.
	var backward := field.global_basis.inverse() * -incoming
	var ray_length_squared := backward.length_squared()
	var toward_surface := point.dot(backward)
	var discriminant := toward_surface * toward_surface - ray_length_squared * (point.length_squared() - 1.0)
	if ray_length_squared > 0.00001 and discriminant >= 0.0:
		var distance := (-toward_surface + sqrt(discriminant)) / ray_length_squared
		point += backward * maxf(distance, 0.0)
	var normal := point.normalized()
	impacts[next_impact] = Vector4(normal.x, normal.y, normal.z, field_time)
	next_impact = (next_impact + 1) % IMPACT_SLOTS
	material.set_shader_parameter("impacts", impacts)

func _follow_model() -> void:
	position = model.position
	rotation.y = model.rotation.y

func _process(delta: float) -> void:
	if not is_instance_valid(model): return
	_follow_model()
	if field.visible:
		field_time += delta
		material.set_shader_parameter("field_time", field_time)
