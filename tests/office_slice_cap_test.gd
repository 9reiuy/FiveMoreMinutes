extends SceneTree

const CAP = preload("res://scripts/dream/architecture_slice_cap.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cap: MeshInstance3D = CAP.make(1.0, 0.5, 2.6)
	var vertices: PackedVector3Array = (cap.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bottom := INF
	var top := -INF
	var front := -INF
	var back := INF
	for vertex in vertices:
		bottom = minf(bottom, vertex.y)
		top = maxf(top, vertex.y)
		front = maxf(front, vertex.z)
		back = minf(back, vertex.z)
	var passed := vertices.size() > 32 * 6 and is_equal_approx(bottom, -0.0625) and is_zero_approx(top) and is_equal_approx(front, 0.25) and is_equal_approx(back, -0.25)
	print("SLICE CAP vertices=", vertices.size(), " bottom=", bottom, " top=", top, " depth=", front - back, " pass=", passed)
	cap.free()
	quit(0 if passed else 1)
