extends SceneTree
## Compare against the original eight-corner volume construction below.
## No viewport capture or gameplay modification is involved in this CPU test.
const SHADOW = preload("res://scripts/dream/actor_volume_shadow.gd")
class ReferenceVolume extends Node3D:
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
	
	func configure(actor: Node2D, caster_layers: int) -> void:
		source = actor
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
		weapon = _make_caster("WeaponVolume", box_mesh, caster_layers)
		add_child(weapon)
		var visual := source.get_node_or_null(^"CharacterVisual")
		if visual != null:
			for side in ["Left", "Right"]:
				var foot := visual.get_node_or_null(NodePath(side + "Foot")) as Node2D
				if foot != null:
					foot_rest[side] = foot.position
	
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
		var visual := source.get_node_or_null(^"CharacterVisual") as Node2D
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
		parts.Head.position = Vector3(0, 1.07, 0)
		parts.Head.scale = Vector3(0.34, 0.36, 0.32)
		parts.Torso.position = Vector3(0, 0.68, 0)
		parts.Torso.scale = Vector3(0.37, 0.48, 0.25)
		for side in ["Left", "Right"]:
			var sign_x := -1.0 if side == "Left" else 1.0
			var step := Vector2.ZERO
			var foot := visual.get_node_or_null(NodePath(side + "Foot")) as Node2D if visual != null else null
			if foot != null and foot_rest.has(side):
				step = (foot.position - foot_rest[side]) / PIXELS_PER_CELL
			var toe := Vector3(sign_x * 0.115, 0.07 + clampf(-step.y, 0.0, 0.12), clampf(step.x, -0.16, 0.16))
			_segment(parts[side + "Leg"], Vector3(sign_x * 0.10, 0.49, 0), toe, 0.15)
			_segment(parts[side + "Arm"], Vector3(sign_x * 0.235, 0.84, 0), Vector3(sign_x * 0.20, 0.55, -0.15), 0.13)
		# Keep every pose above its formal ground/Fake Height without lifting owner.
		var lowest := INF
		for part: MeshInstance3D in parts.values():
			var bounds := part.mesh.get_aabb()
			for corner in 8:
				lowest = minf(lowest, (body.basis * (part.transform * bounds.get_endpoint(corner))).y)
		body.position = Vector3.UP * -lowest
		weapon.visible = grip is Vector3 and muzzle is Vector3 and not bool(source.get("dead"))
		if weapon.visible:
			var start: Vector3 = grip
			var finish: Vector3 = muzzle
			var axis := finish - start
			weapon.visible = axis.length_squared() > 0.001
			if weapon.visible:
				weapon.global_position = (start + finish) * 0.5
				weapon.global_basis = Basis.looking_at(axis.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.09, 0.10, axis.length()))
	
	func _segment(mesh: MeshInstance3D, start: Vector3, finish: Vector3, width: float) -> void:
		var axis := finish - start
		mesh.position = (start + finish) * 0.5
		var y := axis.normalized()
		var x := y.cross(Vector3.FORWARD).normalized()
		mesh.basis = Basis(x, y, x.cross(y)).scaled(Vector3(width, axis.length(), width))
class Actor extends Node2D:
	var last_aim_direction := Vector2.RIGHT
	var dead := false
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	var visual := Node2D.new()
	visual.name = "CharacterVisual"
	actor.add_child(visual)
	for side in ["Left", "Right"]:
		var foot := Node2D.new()
		foot.name = side + "Foot"
		foot.position = Vector2(1.5 if side == "Left" else -1.5, 0)
		visual.add_child(foot)
	var stage := Node3D.new()
	root.add_child(stage)
	var current := SHADOW.new()
	var reference := ReferenceVolume.new()
	stage.add_child(current)
	stage.add_child(reference)
	current.configure(actor, 4)
	reference.configure(actor, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	for pose in 512:
		visual.rotation = rng.randf_range(-PI, PI)
		visual.scale = Vector2(rng.randf_range(-2, 2), rng.randf_range(.3, 2.5))
		visual.get_node("LeftFoot").position = Vector2(rng.randf_range(-9, 9), rng.randf_range(-5, 5))
		visual.get_node("RightFoot").position = Vector2(rng.randf_range(-9, 9), rng.randf_range(-5, 5))
		actor.last_aim_direction = Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		actor.dead = pose % 3 == 0
		actor.visible = pose % 5 != 0
		var ground := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		var map_basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		var height := rng.randf_range(0, 2)
		var grip: Variant = ground + Vector3(.2, 1, .1) if pose % 7 else null
		var muzzle: Variant = ground + Vector3(.9, 1, .2) if pose % 7 else null
		current.sync_pose(ground, map_basis, height, grip, muzzle)
		reference.sync_pose(ground, map_basis, height, grip, muzzle)
		check(current.visible == reference.visible, "Visibility parity %d" % pose)
		check(current.body.transform.is_equal_approx(reference.body.transform), "Ground contact and body parity %d" % pose)
		check(current.global_transform.is_equal_approx(reference.global_transform), "Global placement parity %d" % pose)
		check(current.weapon.transform.is_equal_approx(reference.weapon.transform) and current.weapon.visible == reference.weapon.visible, "Weapon parity %d" % pose)
		for key in current.parts:
			check(current.parts[key].transform.is_equal_approx(reference.parts[key].transform), "Part parity %d %s" % [pose, key])
	actor.visible = true
	for round_index in 5:
		for caster: Node3D in [reference, current]:
			var started := Time.get_ticks_usec()
			for iteration in 4096:
				caster.sync_pose(Vector3.ZERO, Basis.IDENTITY, .4, null, null)
			print("VOLUME_POSE_CPU baseline=", caster == reference, " round=", round_index, " elapsed_us=", Time.get_ticks_usec() - started)
	stage.free()
	actor.free()
	print("Volume pose parity: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

