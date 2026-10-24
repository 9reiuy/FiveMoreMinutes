extends Node3D
## Passive ink only. No collision, damage, audio, viewport or target reference.
const SHADER := preload("res://shaders/dream3d/melee_crescent_hit.gdshader")
const DURATION := 0.22
const VISUAL_SCALE := 1.5
const CAPTURE_PIXELS := 112.0
var mesh: MeshInstance3D
var material: ShaderMaterial
var camera: Camera3D
var elapsed := 0.0
var birth_pending := true
var cuts: Array[Vector4] = []
var line_count := 1

func _init() -> void:
	mesh = MeshInstance3D.new()
	mesh.name = "CrescentHitInk"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * CAPTURE_PIXELS * VISUAL_SCALE / 32.0
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("visual_scale", VISUAL_SCALE)
	material.set_shader_parameter("progress", 0.0)
	material.set_meta(&"runtime_uniform_owner", true)
	mesh.material_override = material
	add_child(mesh)
	add_to_group(&"melee_crescent_hits")

func setup(view_camera: Camera3D, anchor: Vector3, direction: Vector2, plane: Dictionary) -> void:
	camera = view_camera
	global_position = anchor
	global_basis = camera.global_basis.orthonormalized()
	material.set_shader_parameter("facing", direction.angle())
	preload("res://scripts/dream/character_visual_projection.gd").set_material_plane(material, plane.origin, plane.normal)
	# Private RNG: never alter crits, blood, loot or seeded floor generation.
	var random := RandomNumberGenerator.new()
	random.seed = get_instance_id()
	line_count = random.randi_range(1, 3)
	material.set_shader_parameter("line_count", line_count)
	for i in 3:
		var ray := Vector2.RIGHT.rotated(direction.angle() + random.randf_range(-PI, PI))
		var cut := Vector4(ray.x, ray.y, random.randf_range(64.0, 96.0), random.randf_range(-3.0, 3.0))
		cuts.append(cut)
		material.set_shader_parameter("cut_%d" % i, cut)

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		queue_free()
		return
	global_basis = camera.global_basis.orthonormalized()
	if birth_pending:
		birth_pending = false
		return
	elapsed += maxf(delta, 0.0)
	material.set_shader_parameter("progress", clampf(elapsed / DURATION, 0.0, 1.0))
	if elapsed >= DURATION: queue_free()
