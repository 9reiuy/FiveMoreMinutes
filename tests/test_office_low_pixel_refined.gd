extends SceneTree

func _init() -> void:
	print("--- Testing office_low_pixel_refined.gd ---")
	var refined = preload("res://scripts/dream/office_low_pixel_refined.gd")
	var tex = refined.texture()
	assert(tex != null, "Texture must not be null")
	print("Refined Texture size: ", tex.get_size())
	
	for kind in ["desk", "workstation", "chair", "cabinet", "cabinet_open", "partition"]:
		var vis: Node3D = refined.make_visual(kind)
		assert(vis != null, "Visual must not be null")
		var mesh_instance: MeshInstance3D = vis.get_node("MeshInstance3D") as MeshInstance3D
		assert(mesh_instance != null, "MeshInstance3D must exist")
		var aabb: AABB = mesh_instance.mesh.get_aabb()
		var tri_count: int = mesh_instance.mesh.surface_get_array_index_len(0) / 3
		print("Kind: %-12s | Triangles: %-4d | AABB: %s" % [kind, tri_count, str(aabb)])
		if kind in ["desk", "workstation"]:
			assert(is_equal_approx(aabb.size.x, 2.2), "Desk width must be 2.2m")
			assert(is_equal_approx(aabb.size.z, 1.1), "Desk depth must be 1.1m")
		elif kind == "chair":
			assert(is_equal_approx(aabb.position.y, 0.0), "Chair casters must touch the ground (y=0)")
		
	print("--- All office_low_pixel_refined tests PASSED! ---")
	quit(0)
