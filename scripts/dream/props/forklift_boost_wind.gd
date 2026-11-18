extends Node3D
## Vehicle-local wind shell. Visual only: no lights, collisions or screen copy.

const SHADER := preload("res://shaders/dream3d/forklift_boost_wind.gdshader")
const MASK := preload("res://art/Dream/VFX/VefectsWind/T_VFX_Wind_Shape_Mask_03.png")
const CUTOUT := preload("res://art/Dream/VFX/VefectsWind/T_VFX_Cutout_RGB_Pack_01.png")
const NOISE := preload("res://art/Dream/VFX/VefectsWind/T_VFX_Noise_Perlin_03.png")
const RINGS := 18
const SIDES := 20

var strength := 0.0
var flow_time := 0.0
var speed_fraction := 0.0
var layers: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
static var _shell: ArrayMesh


func _init() -> void:
	name = "BoostWind"
	if _shell == null:
		_shell = _build_shell()
	for index in 2:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("wind_mask", MASK)
		material.set_shader_parameter("cutout_mask", CUTOUT)
		material.set_shader_parameter("flow_noise", NOISE)
		material.set_shader_parameter("layer_offset", float(index) * 0.37)
		material.set_shader_parameter("wind_color", Color(0.88, 0.95, 1.0, 0.56 if index == 0 else 0.36))
		material.set_meta(&"runtime_uniform_owner", true)
		var mesh := MeshInstance3D.new()
		mesh.name = "WindShell%d" % index
		mesh.set_meta(&"vehicle_visual_effect", true)
		mesh.set_meta(&"surface_blood_excluded", true)
		mesh.mesh = _shell
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if index == 1:
			mesh.scale = Vector3(0.91, 0.91, 0.91)
			mesh.position.y = 0.10
		add_child(mesh)
		layers.append(mesh)
		materials.append(material)
	visible = false


func sync_motion(speed_mps: float, boosting: bool, delta: float) -> void:
	speed_fraction = clampf(speed_mps / 18.0, 0.0, 1.0)
	var target := smoothstep(0.4, 7.0, speed_mps) * lerpf(0.35, 1.0, speed_fraction) if boosting else 0.0
	strength = move_toward(strength, target, maxf(delta, 0.0) * (10.0 if target > strength else 14.0))
	visible = strength > 0.001
	if not visible:
		return
	flow_time = fmod(flow_time + maxf(delta, 0.0) * lerpf(0.7, 1.8, speed_fraction), 100.0)
	for material in materials:
		material.set_shader_parameter("strength", strength)
		material.set_shader_parameter("flow_time", flow_time)
		material.set_shader_parameter("tail_stretch", lerpf(0.72, 1.15, speed_fraction))


func clear() -> void:
	strength = 0.0
	speed_fraction = 0.0
	visible = false
	for material in materials:
		material.set_shader_parameter("strength", 0.0)


static func _point(u: float, angle: float) -> Vector3:
	var radius := 0.10 + 1.48 * pow(sin(u * PI * 0.5), 0.72)
	return Vector3(2.55 - u * 6.1, 1.42 + sin(angle) * radius * 0.82, cos(angle) * radius)


static func _build_shell() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in RINGS:
		for side in SIDES:
			var a := Vector2(float(ring) / RINGS, float(side) / SIDES)
			var b := Vector2(float(ring + 1) / RINGS, float(side) / SIDES)
			var c := Vector2(float(ring + 1) / RINGS, float(side + 1) / SIDES)
			var d := Vector2(float(ring) / RINGS, float(side + 1) / SIDES)
			for uv: Vector2 in [a, b, c, a, c, d]:
				var angle := uv.y * TAU
				tool.set_uv(uv)
				tool.set_normal(Vector3(0.25, sin(angle) / 0.82, cos(angle)).normalized())
				tool.add_vertex(_point(uv.x, angle))
	tool.index()
	return tool.commit()
