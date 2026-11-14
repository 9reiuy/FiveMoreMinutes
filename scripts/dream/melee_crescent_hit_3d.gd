extends Node3D
## Passive ink only. No collision, damage, audio, viewport or target reference.
const SHADER := preload("res://shaders/dream3d/melee_crescent_hit.gdshader")
const DURATION := 0.22
const VISUAL_SCALE := 1.5
const CAPTURE_PIXELS := 112.0
const CONTACT_INK_SCALE := 0.74
const MAX_CONTACT_SHIFT := 7.0
var mesh: MeshInstance3D
var material: ShaderMaterial
var camera: Camera3D
var elapsed := 0.0
var birth_pending := true
var cuts: Array[Vector4] = []
var line_count := 1

static func spawn(world: Node3D, actor: Node2D, direction: Vector2, effect_scale: float,
		contact: Dictionary = {}) -> Node3D:
	if not is_instance_valid(actor) or not is_instance_valid(world.camera_3d) or not is_instance_valid(world.floor_root):
		return null
	var view_camera: Camera3D = world.camera_3d
	var target_origin: Vector2 = contact.get("target_origin", actor.global_position)
	var at_torso: Vector3 = world.get_gameplay_world_position(target_origin, 0.65)
	var anchor: Vector3 = world.get_gameplay_world_position(actor.global_position, 0.65)
	var normal := Vector3(view_camera.global_basis.z.x, 0.0, view_camera.global_basis.z.z).normalized()
	var feet: Vector3 = world.get_gameplay_world_position(actor.global_position, 0.0)
	var plane := {"origin": feet + normal * 0.04, "normal": normal}
	var reference: Variant = actor.get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if is_instance_valid(bridge) and bridge.has_method("get_hit_feedback_world_position"):
		anchor = bridge.get_hit_feedback_world_position()
		var body_plane: Dictionary = bridge.get_hit_feedback_depth_plane()
		if not body_plane.is_empty():
			plane = body_plane
	elif is_instance_valid(bridge) and bridge.has_method("get_model_center"):
		anchor = bridge.get_model_center()
		plane.origin = anchor + normal * 0.04
	var along: Vector3 = world.get_gameplay_world_position(target_origin + direction, 0.65)
	var screen_direction := view_camera.unproject_position(along) - view_camera.unproject_position(at_torso)
	if not contact.is_empty():
		# Offset from the struck surface on the character's own depth plane.
		var at_contact: Vector3 = world.get_gameplay_world_position(contact.point, 0.65 - float(contact.drop))
		var screen := view_camera.unproject_position(anchor)
		var pixel_scale := view_camera.get_viewport().get_visible_rect().size.y / 360.0
		var shift := (view_camera.unproject_position(anchor + at_contact - at_torso) - screen).limit_length(MAX_CONTACT_SHIFT * pixel_scale)
		var depth := -(view_camera.get_camera_transform().affine_inverse() * anchor).z
		anchor = view_camera.project_position(screen + shift, depth)
	var effect := new()
	world.floor_root.add_child(effect)
	effect.setup(view_camera, anchor, screen_direction.normalized(), plane, effect_scale, not contact.is_empty())
	return effect

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

func setup(view_camera: Camera3D, anchor: Vector3, direction: Vector2, plane: Dictionary,
		effect_scale: float = 1.0, localized := false) -> void:
	camera = view_camera
	var motif_scale := VISUAL_SCALE * maxf(effect_scale, 0.01)
	if localized:
		motif_scale *= CONTACT_INK_SCALE
	mesh.mesh.size = Vector2.ONE * CAPTURE_PIXELS * motif_scale / 32.0
	material.set_shader_parameter("visual_scale", motif_scale)
	global_position = anchor
	global_basis = camera.global_basis.orthonormalized()
	material.set_shader_parameter("facing", direction.angle())
	preload("res://scripts/dream/character_visual_projection.gd").set_material_plane(material, plane.origin, plane.normal)
	if localized:
		var cut := Vector4(direction.x, direction.y, 46.0, 0.0)
		cuts.append(cut)
		material.set_shader_parameter("line_count", 1)
		material.set_shader_parameter("cut_0", cut)
		return
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
