extends SceneTree
const WORK := "res://.runtime/screen_wall_avatar_20261107/"
func _initialize() -> void:
	run.call_deferred()

func triangle_in_box(a: Vector3,b: Vector3,c: Vector3,box: AABB) -> bool:
	var center := box.get_center()
	var half := box.size * 0.5
	var vertices := [a-center,b-center,c-center]
	var edges := [b-a,c-b,a-c]
	var axes := [Vector3.RIGHT,Vector3.UP,Vector3.BACK,(b-a).cross(c-a)]
	for edge in edges:
		for basis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]: axes.append(edge.cross(basis))
	for axis: Vector3 in axes:
		if axis.length_squared() < 1e-14: continue
		var p := Vector3(axis.dot(vertices[0]),axis.dot(vertices[1]),axis.dot(vertices[2]))
		var radius := axis.abs().dot(half)
		if minf(p.x,minf(p.y,p.z)) > radius or maxf(p.x,maxf(p.y,p.z)) < -radius: return false
	return true

func run() -> void:
	print("AVATAR_CLEARANCE_PID=", OS.get_process_id())
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/preview/screen_wall_avatar_candidate.tscn"
	root.add_child(lab)
	var wall: Node3D = lab.presentation.wall_view
	var leg: ArrayMesh = load("res://tests/fixtures/screen_wall_avatar_leg_geometry.res")
	var contacts: Array = []
	var checked := 0
	for television in wall.model.get_node("Televisions").get_children():
		for shape in television.find_children("*", "CollisionShape3D", true, false):
			if not shape.shape is BoxShape3D: continue
			var transform: Transform3D = shape.global_transform.affine_inverse() * wall.avatar.geometry.global_transform
			var margin := Vector3(0.012, 0.012, 0.008).min(shape.shape.size * 0.12)
			var size: Vector3 = shape.shape.size - margin * 2.0
			var box := AABB(-size * 0.5, size)
			var hits := 0
			var first := Vector3.ZERO
			for surface in leg.get_surface_count():
				var arrays := leg.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var bounds: AABB = transform * leg.get_aabb()
				if not bounds.intersects(box): continue
				for triangle in indices.size() / 3:
					var a := transform * points[indices[triangle * 3]]
					var b := transform * points[indices[triangle * 3 + 1]]
					var c := transform * points[indices[triangle * 3 + 2]]
					checked += 1
					if triangle_in_box(a,b,c,box):
						hits += 1
						first = shape.global_transform * a
			if hits > 0:
				contacts.append({"tv": String(television.name), "shape": String(shape.get_parent().name), "triangles": hits, "last_world_point": [first.x,first.y,first.z]})
	var file := FileAccess.open(WORK + "leg_clearance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"tested_triangles": checked, "contacts": contacts}, "\t"))
	file.close()
	print("LEG_CLEARANCE tested=", checked, " contacts=", contacts)
	lab.queue_free()
	await process_frame
	quit(0 if contacts.is_empty() else 1)
