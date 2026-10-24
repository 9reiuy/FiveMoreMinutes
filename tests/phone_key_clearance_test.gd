extends SceneTree
## Geometry oracle: reads the rendered triangle meshes, never actuator formulas.
const RAY := Vector3(0.831, 0.367, 0.419)
const EPS := 0.00001
var checks := 0
var failures: Array[String] = []
var shell: Control
var space: Node3D
var fixed: Array[Dictionary] = []
var moving: Dictionary = {}
var mesh_cache: Dictionary = {}
var output := "res://.runtime/phone_key_clearance/final"
var sample_count := 0
var worst: Array = []
var fit_metrics: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		if failures.size() <= 16: push_error(message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("phone_settings_sample"):
		push_error("Use isolated phone_settings_sample profile"); quit(2); return
	var script_path := "res://scripts/ui/flip_phone_shell.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shell-script="): script_path = arg.trim_prefix("--shell-script=")
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	var script: GDScript = load(script_path)
	shell = script.new(); root.add_child(shell); shell.open_phone(false)
	shell.set_process(false)
	for i in 3: await process_frame
	space = shell._key_plane
	moving = {"ring": shell._ring_mesh, "centre": shell._centre_mesh, "home": shell._keys[&"home"].mesh, "back": shell._keys[&"back"].mesh}
	for mesh: MeshInstance3D in shell._stage.find_children("*", "MeshInstance3D", true, false):
		var is_moving := false
		for root_mesh: MeshInstance3D in moving.values():
			if root_mesh == mesh or root_mesh.is_ancestor_of(mesh): is_moving = true
		if not is_moving and mesh.mesh != null: fixed.append(record(mesh))
	check(fixed.size() > 8, "Collision oracle inventories all fixed stage meshes, including original full panels")
	var cases: Array[Dictionary] = [{}, {&"confirm": 1.02}, {&"confirm": -0.12}, {&"home": 1.02}, {&"back": 1.02}, {&"home": 1.02, &"back": 1.02}, {&"home": -0.12, &"back": -0.12}]
	for directions in [[&"up"], [&"down"], [&"left"], [&"right"], [&"up", &"left"], [&"up", &"right"], [&"down", &"left"], [&"down", &"right"]]:
		for amount in [1.02, -0.12]:
			for centre in [0.0, 1.02, -0.12]:
				var pose := {&"confirm": centre}
				for direction in directions: pose[direction] = amount
				cases.append(pose)
	cases.append({&"up": 1.02, &"right": 1.02, &"confirm": 1.02, &"home": 1.02, &"back": 1.02})
	for pose in cases:
		for action in shell._keys: shell._feedback_amounts[action] = float(pose.get(action, 0.0))
		shell._apply_feedback()
		validate_pose(pose)
	_validate_holes()
	_validate_close_fit()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "failures": failures, "poses": sample_count, "fixed_meshes": fixed.size(), "source": script_path, "oracle": "transformed triangles, triangle intersections, bidirectional solid containment and label support rays", "witnesses": worst, "close_fit": fit_metrics}, "\t"))
	shell.free()
	for i in 3: await process_frame
	print("PHONE_KEY_CLEARANCE poses=%d fixed_meshes=%d checks=%d failures=%d" % [sample_count, fixed.size(), checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func record(mesh: MeshInstance3D) -> Dictionary:
	var id := mesh.mesh.get_instance_id()
	if not mesh_cache.has(id): mesh_cache[id] = mesh.mesh.get_faces()
	var transform := space.global_transform.affine_inverse() * mesh.global_transform
	var points := PackedVector3Array()
	var triangles: Array[Dictionary] = []
	var vertices: Array[Vector3] = []
	var unique: Dictionary = {}
	var bounds := AABB()
	for local: Vector3 in mesh_cache[id]:
		var point := transform * local
		points.append(point)
		if points.size() == 1: bounds = AABB(point, Vector3.ZERO)
		else: bounds = bounds.expand(point)
		var key := Vector3i(roundi(point.x * 100000), roundi(point.y * 100000), roundi(point.z * 100000))
		if not unique.has(key): unique[key] = true; vertices.append(point)
	for index in range(0, points.size(), 3):
		var a := points[index]; var b := points[index + 1]; var c := points[index + 2]
		if (b - a).cross(c - a).length_squared() < 0.000000000001: continue
		triangles.append({"a": a, "b": b, "c": c, "bounds": AABB(a, Vector3.ZERO).expand(b).expand(c)})
	return {"name": String(mesh.name), "triangles": triangles, "bounds": bounds, "vertices": vertices}

func validate_pose(pose: Dictionary) -> void:
	sample_count += 1
	var records: Dictionary = {}
	for key: String in moving:
		var mesh: MeshInstance3D = moving[key]
		var actual := record(mesh)
		records[key] = actual
		var collision := ""
		for obstacle in fixed:
			if intersects(actual, obstacle):
				collision = obstacle.name; break
		check(collision.is_empty(), "Pose %s: actual %s triangles clear fixed %s" % [str(pose), key, collision])
		if not collision.is_empty() and worst.size() < 12: worst.append({"pose": pose.duplicate(), "moving": key, "fixed": collision})
	var keys := records.keys()
	for index in keys.size():
		for other in range(index + 1, keys.size()):
			check(not intersects(records[keys[index]], records[keys[other]]), "Pose %s: moving %s clears %s including real centre aperture" % [str(pose), keys[index], keys[other]])
	for label: Label3D in space.find_children("*", "Label3D", true, false):
		var parent := label.get_parent()
		while parent != null and parent != space and not parent is MeshInstance3D: parent = parent.get_parent()
		var supported := parent is MeshInstance3D
		if supported:
			var backing := record(parent)
			var label_to_space := space.global_transform.affine_inverse() * label.global_transform
			var normal := space.global_basis.inverse() * label.global_basis.z.normalized()
			var glyph: AABB = label.get_aabb()
			supported = glyph.size.x > 0.0001 and glyph.size.y > 0.0001
			for local in [Vector3.ZERO, glyph.position, glyph.position + Vector3(glyph.size.x, 0, 0), glyph.position + Vector3(glyph.size.x, glyph.size.y, 0), glyph.position + Vector3(0, glyph.size.y, 0)]:
				var gap := support_gap(label_to_space * local, -normal, backing)
				if gap < 0.0005 or gap > 0.015: supported = false
		check(supported, "Pose %s: label '%s' follows its actual key and stays just above its real surface" % [str(pose), label.text])

func intersects(a: Dictionary, b: Dictionary) -> bool:
	if not a.bounds.grow(EPS).intersects(b.bounds.grow(EPS)): return false
	for first: Dictionary in a.triangles:
		if not first.bounds.grow(EPS).intersects(b.bounds.grow(EPS)): continue
		for second: Dictionary in b.triangles:
			if not first.bounds.grow(EPS).intersects(second.bounds.grow(EPS)): continue
			if triangle_intersection(first, second): return true
	for point: Vector3 in a.vertices:
		if inside(point, b): return true
	for point: Vector3 in b.vertices:
		if inside(point, a): return true
	return false

func triangle_intersection(a: Dictionary, b: Dictionary) -> bool:
	for edge in [[a.a, a.b], [a.b, a.c], [a.c, a.a]]:
		if Geometry3D.segment_intersects_triangle(edge[0], edge[1], b.a, b.b, b.c) != null: return true
	for edge in [[b.a, b.b], [b.b, b.c], [b.c, b.a]]:
		if Geometry3D.segment_intersects_triangle(edge[0], edge[1], a.a, a.b, a.c) != null: return true
	return false

func inside(point: Vector3, shape: Dictionary) -> bool:
	var box: AABB = shape.bounds
	if not box.grow(-EPS).has_point(point): return false
	var hits: Array[float] = []
	for triangle: Dictionary in shape.triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(point, point + RAY * 10.0, triangle.a, triangle.b, triangle.c)
		if hit == null: continue
		var distance: float = point.distance_to(hit)
		if distance < EPS: return false
		if not hits.any(func(value: float): return absf(value - distance) < EPS): hits.append(distance)
	return hits.size() % 2 == 1

func support_gap(point: Vector3, direction: Vector3, backing: Dictionary) -> float:
	var nearest := INF
	for triangle: Dictionary in backing.triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(point, point + direction * 0.05, triangle.a, triangle.b, triangle.c)
		if hit != null: nearest = minf(nearest, point.distance_to(hit))
	return nearest

func _validate_holes() -> void:
	# Continuous front covers and recessed sockets are both valid. The actual
	# front surface must remain behind the moving mesh throughout its travel.
	for key: String in ["home", "back", "centre", "ring"]:
		var mesh: MeshInstance3D = moving[key]
		var actual := record(mesh)
		var midpoint: Vector3 = actual.bounds.get_center()
		var point := Vector3(midpoint.x, midpoint.y, 0.20)
		var front := -INF
		for obstacle in fixed:
			for triangle: Dictionary in obstacle.triangles:
				var hit: Variant = Geometry3D.segment_intersects_triangle(point, point + Vector3(0, 0, -0.5), triangle.a, triangle.b, triangle.c)
				if hit != null: front = maxf(front, hit.z)
		check(front < actual.bounds.position.z - 0.0005, "Actual fixed front surface stays behind moving %s bottom without requiring a deep socket" % key)
	# The annulus centre must remain empty even while the independent button is
	# down; this catches convex/solid discs disguised with a central decoration.
	var ring := record(moving.ring)
	var ring_centre: Vector3 = (moving.ring as MeshInstance3D).global_position
	ring_centre = space.global_transform.affine_inverse() * ring_centre
	var through := false
	for triangle: Dictionary in ring.triangles:
		if Geometry3D.segment_intersects_triangle(ring_centre + Vector3(0, 0, 0.3), ring_centre - Vector3(0, 0, 0.3), triangle.a, triangle.b, triangle.c) != null: through = true
	check(not through, "Directional key mesh has a real open centre, not a capped solid disc")

func _project(point: Vector3) -> Vector2:
	var camera: Camera3D = shell._camera
	var render: SubViewport = shell._render
	var view: TextureRect = shell._view
	return camera.unproject_position(space.global_transform * point) * view.size.x / float(render.size.x)

func _validate_close_fit() -> void:
	for action in shell._keys: shell._feedback_amounts[action] = 0.0
	shell._apply_feedback()
	var deck: MeshInstance3D = space.get_node_or_null("KeyDeck/DeckTile_00")
	check(deck != null, "Close-fit design keeps a real white front cover")
	if deck == null: return
	var panel := record(deck)
	for item in [["ring", "DpadSupportSeat"], ["home", "HomeSupportSeat"], ["back", "BackSupportSeat"]]:
		var seat := space.get_node_or_null(item[1]) as MeshInstance3D
		check(seat != null, "Close-fit support is a real mesh: " + item[0])
		if seat == null: continue
		var support := record(seat)
		var key := record(moving[item[0]])
		var key_centre: Vector3 = key.bounds.get_center()
		var front: float = support.bounds.end.z
		var side_exposure := _project(Vector3(support.bounds.end.x, key_centre.y, front)).distance_to(_project(Vector3(key.bounds.end.x, key_centre.y, front)))
		var end_exposure := _project(Vector3(key_centre.x, support.bounds.end.y, front)).distance_to(_project(Vector3(key_centre.x, key.bounds.end.y, front)))
		check(maxf(side_exposure, end_exposure) <= 2.0, "Actual projected support exposure stays within a narrow two-pixel seam: " + item[0])
		var pixels_per_unit := _project(key_centre + Vector3.RIGHT).distance_to(_project(key_centre))
		fit_metrics.append({"moving": item[0], "projected_seam_px": maxf(side_exposure, end_exposure), "seat_step_px_at_local_pixel_density": absf(front - panel.bounds.end.z) * pixels_per_unit, "same_front_material": seat.material_override == deck.material_override})
		check(absf(front - panel.bounds.end.z) * pixels_per_unit < 1.0, "Support remains near-flush with actual front cover instead of a raised platform: " + item[0])
		check(seat.material_override == deck.material_override, "Support shares actual white front-cover material rather than dark socket paint: " + item[0])
		if item[0] == "ring":
			# Sample actual side-wall intersections around the contour. Checking only
			# vertex radii would mistake a square's equidistant corners for a circle.
			var radii: Array[float] = []
			var centre: Vector3 = support.bounds.get_center()
			for index in 16:
				var direction := Vector3(cos(float(index) * TAU / 16.0), sin(float(index) * TAU / 16.0), 0)
				var distance := 0.0
				for triangle: Dictionary in support.triangles:
					var hit: Variant = Geometry3D.segment_intersects_triangle(centre, centre + direction, triangle.a, triangle.b, triangle.c)
					if hit != null: distance = maxf(distance, centre.distance_to(hit))
				radii.append(distance)
			check(radii.min() > 0.0 and float(radii.max()) - float(radii.min()) < 0.003, "Actual circular support contour has no square pedestal corners")
