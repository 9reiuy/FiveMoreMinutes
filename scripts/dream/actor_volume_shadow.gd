extends Node3D
## Passive, shared low-poly volume: never runs gameplay or participates in physics.
## World points come from the depth bridge, including its formal weapon plane.
const PIXELS_PER_CELL := 32.0
static var box_mesh: BoxMesh
static var limb_mesh: CylinderMesh
static var head_mesh: SphereMesh
var parts: Dictionary = {}
var foot_rest: Dictionary = {}
var body: Node3D
var weapon: MeshInstance3D
var source: Node2D
var part_bounds: Dictionary = {}
var _cached_visual: Node2D
var _cached_left_foot: Node2D
var _cached_right_foot: Node2D
var _last_left_step: Vector2 = Vector2(INF, INF)
var _last_right_step: Vector2 = Vector2(INF, INF)
var _part_list: Array[MeshInstance3D] = []
var _bound_list: Array[AABB] = []

func configure(actor: Node2D, caster_layers: int, include_weapon: bool = true) -> void:
	source = actor
	_part_list.clear()
	_bound_list.clear()
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		box_mesh.size = Vector3.ONE
		limb_mesh = CylinderMesh.new()
		limb_mesh.top_radius = 0.5
		limb_mesh.bottom_radius = 0.5
		limb_mesh.height = 1.0
		limb_mesh.radial_segments = 6
		limb_mesh.rings = 1
		head_mesh = SphereMesh.new()
		head_mesh.radius = 0.5
		head_mesh.height = 1.0
		head_mesh.radial_segments = 8
		head_mesh.rings = 3
	body = Node3D.new()
	body.name = "BodyVolume"
	add_child(body)
	for part in ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		var mesh := _make_caster(part, head_mesh if part == "Head" else (box_mesh if part == "Torso" else limb_mesh), caster_layers)
		body.add_child(mesh)
		parts[part] = mesh
		var aabb := mesh.mesh.get_aabb()
		part_bounds[part] = aabb
		_part_list.append(mesh)
		_bound_list.append(aabb)
	_set_fixed_body_pose()
	if include_weapon:
		weapon = _make_caster("WeaponVolume", box_mesh, caster_layers)
		add_child(weapon)
	_cached_visual = source.get_node_or_null(^"CharacterVisual") as Node2D
	if _cached_visual != null:
		_cached_left_foot = _cached_visual.get_node_or_null(^"LeftFoot") as Node2D
		if _cached_left_foot != null:
			foot_rest["Left"] = _cached_left_foot.position
		_cached_right_foot = _cached_visual.get_node_or_null(^"RightFoot") as Node2D
		if _cached_right_foot != null:
			foot_rest["Right"] = _cached_right_foot.position

func _make_caster(label: String, mesh: Mesh, caster_layers: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.layers = caster_layers
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return instance

func sync_pose(ground: Vector3, map_basis: Basis, height: float, grip: Variant, muzzle: Variant) -> void:
	if not is_instance_valid(source):
		hide()
		return
	visible = source.visible
	global_transform = Transform3D(Basis.IDENTITY, ground + Vector3.UP * height)
	if not is_instance_valid(_cached_visual):
		_cached_visual = source.get_node_or_null(^"CharacterVisual") as Node2D
	var visual := _cached_visual
	var facing: Variant = source.get("last_aim_direction")
	if not facing is Vector2:
		facing = source.get("last_facing_direction")
	var direction: Vector2 = facing if facing is Vector2 else Vector2.RIGHT
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	var forward := (map_basis * Vector3(direction.x, 0.0, direction.y)).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var orientation := Basis(right, Vector3.UP, -forward).orthonormalized()
	var tilt := visual.rotation if visual != null else 0.0
	# The existing 2D pose rotation is the roll/knockdown authority. Rotate the
	# complete volume around its torso; do not mistake that rotation for yaw.
	body.basis = orientation * Basis(Vector3.FORWARD, tilt)
	var char_scale := clampf(absf(visual.scale.y), 0.5, 2.0) if visual != null else 1.0
	body.scale *= char_scale
	var legacy_pose := bool(source.get_meta(&"test_legacy_volume_pose", false))
	if legacy_pose:
		_set_fixed_body_pose()
		_last_left_step = Vector2(INF, INF)
		_last_right_step = Vector2(INF, INF)

	var left_step := Vector2.ZERO
	if is_instance_valid(_cached_left_foot) and foot_rest.has("Left"):
		left_step = (_cached_left_foot.position - foot_rest["Left"]) / PIXELS_PER_CELL
	if left_step != _last_left_step:
		_last_left_step = left_step
		var left_toe := Vector3(-0.115, 0.07 + clampf(-left_step.y, 0.0, 0.12), clampf(left_step.x, -0.16, 0.16))
		_segment(parts["LeftLeg"], Vector3(-0.10, 0.49, 0), left_toe, 0.15)

	var right_step := Vector2.ZERO
	if is_instance_valid(_cached_right_foot) and foot_rest.has("Right"):
		right_step = (_cached_right_foot.position - foot_rest["Right"]) / PIXELS_PER_CELL
	if right_step != _last_right_step:
		_last_right_step = right_step
		var right_toe := Vector3(0.115, 0.07 + clampf(-right_step.y, 0.0, 0.12), clampf(right_step.x, -0.16, 0.16))
		_segment(parts["RightLeg"], Vector3(0.10, 0.49, 0), right_toe, 0.15)

	# Keep every pose above its formal ground/Fake Height without lifting owner.
	var lowest := INF
	var part_count := _part_list.size()
	for idx in part_count:
		var part: MeshInstance3D = _part_list[idx]
		var bounds: AABB = _bound_list[idx]
		if legacy_pose:
			for corner in 8:
				lowest = minf(lowest, (body.basis * (part.transform * bounds.get_endpoint(corner))).y)
		else:
			# Exact minimum of the transformed AABB: a linear Y projection
			# reaches its minimum at the signed extent along each basis axis.
			var projected_basis := body.basis * part.basis
			var center := body.basis * (part.transform * bounds.get_center())
			var half_size := bounds.size * 0.5
			var radius := absf(projected_basis.x.y) * half_size.x + absf(projected_basis.y.y) * half_size.y + absf(projected_basis.z.y) * half_size.z
			lowest = minf(lowest, center.y - radius)
	body.position = Vector3.UP * -lowest
	if weapon == null:
		return
	weapon.visible = grip is Vector3 and muzzle is Vector3 and not bool(source.get("dead"))
	if weapon.visible:
		var start: Vector3 = grip
		var finish: Vector3 = muzzle
		var axis := finish - start
		weapon.visible = axis.length_squared() > 0.001
		if weapon.visible:
			weapon.global_position = (start + finish) * 0.5
			weapon.global_basis = Basis.looking_at(axis.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.09, 0.10, axis.length()))

func _set_fixed_body_pose() -> void:
	parts.Head.position = Vector3(0, 1.07, 0)
	parts.Head.scale = Vector3(0.34, 0.36, 0.32)
	parts.Torso.position = Vector3(0, 0.68, 0)
	parts.Torso.scale = Vector3(0.37, 0.48, 0.25)
	for side in ["Left", "Right"]:
		var sign_x := -1.0 if side == "Left" else 1.0
		_segment(parts[side + "Arm"], Vector3(sign_x * 0.235, 0.84, 0), Vector3(sign_x * 0.20, 0.55, -0.15), 0.13)

func _segment(mesh: MeshInstance3D, start: Vector3, finish: Vector3, width: float) -> void:
	var axis := finish - start
	mesh.position = (start + finish) * 0.5
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	mesh.basis = Basis(x, y, x.cross(y)).scaled(Vector3(width, axis.length(), width))
