extends SceneTree

const WALL = preload("res://scripts/dream/wall_segment_3d.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Wall Segment 3D Surface & UV Verification ---")
	WALL.clear_mesh_cache()

	var wall = WALL.new()
	var root_node = Node3D.new()
	root.add_child(root_node)

	# Setup a mock WallMesh child
	var wall_mesh_inst := MeshInstance3D.new()
	wall_mesh_inst.name = "WallMesh"
	wall.add_child(wall_mesh_inst)
	root_node.add_child(wall)

	wall.wall_height = 2.6
	wall.wall_thickness = 0.5
	wall._apply_height()

	var base_mesh: ArrayMesh = wall.wall_mesh.mesh
	assert(base_mesh != null, "base_mesh should not be null")
	assert(base_mesh.get_surface_count() == 3, "base_mesh should have 3 surfaces, got: %d" % base_mesh.get_surface_count())

	# Inspect Surface 0 (Front + Right + Left)
	var surf0_arrays = base_mesh.surface_get_arrays(0)
	var v0: PackedVector3Array = surf0_arrays[Mesh.ARRAY_VERTEX]
	var n0: PackedVector3Array = surf0_arrays[Mesh.ARRAY_NORMAL]
	var uv0: PackedVector2Array = surf0_arrays[Mesh.ARRAY_TEX_UV]

	print("Surface 0 vertex count: ", v0.size())
	assert(v0.size() == 12, "Surface 0 should have 12 vertices (4 front + 4 right + 4 left)")

	var has_back_norm := false
	var has_right_norm := false
	var has_left_norm := false
	for norm in n0:
		if norm.dot(Vector3.BACK) > 0.99:
			has_back_norm = true
		elif norm.dot(Vector3.RIGHT) > 0.99:
			has_right_norm = true
		elif norm.dot(Vector3.LEFT) > 0.99:
			has_left_norm = true
		else:
			push_error("Unexpected normal in Surface 0: %s" % str(norm))

	assert(has_back_norm, "Surface 0 must contain front face (Vector3.BACK)")
	assert(has_right_norm, "Surface 0 must contain right face (Vector3.RIGHT)")
	assert(has_left_norm, "Surface 0 must contain left face (Vector3.LEFT)")
	print("Surface 0 normals verified: BACK, RIGHT, LEFT all present.")

	# Check Right face UVs (indices 4..7)
	# Front face is 0..3, Right is 4..7, Left is 8..11
	var expected_side_u_span: float = (1.0 / 3.0) * (float(wall.wall_thickness) / 1.0)
	print("Expected side_u_span: ", expected_side_u_span)
	var front_right_u = uv0[1].x
	var right_face_start_u = uv0[4].x
	var right_face_end_u = uv0[5].x
	assert(absf(front_right_u - right_face_start_u) < 0.001, "Right face start U must match front face right edge U")
	assert(absf(right_face_end_u - (right_face_start_u + expected_side_u_span)) < 0.001, "Right face end U must wrap continuously by side_u_span")

	var front_left_u = uv0[0].x
	var left_face_end_u = uv0[9].x
	var left_face_start_u = uv0[8].x
	assert(absf(front_left_u - left_face_end_u) < 0.001, "Left face end U must match front face left edge U")
	assert(absf(left_face_start_u - (front_left_u - expected_side_u_span)) < 0.001, "Left face start U must wrap continuously by side_u_span")
	print("Surface 0 UV continuous wrapping verified.")

	# Inspect Surface 1 (Back face)
	var surf1_arrays = base_mesh.surface_get_arrays(1)
	var v1: PackedVector3Array = surf1_arrays[Mesh.ARRAY_VERTEX]
	var n1: PackedVector3Array = surf1_arrays[Mesh.ARRAY_NORMAL]
	print("Surface 1 vertex count: ", v1.size())
	assert(v1.size() == 4, "Surface 1 should have 4 vertices (back face)")
	for norm in n1:
		assert(norm.dot(Vector3.FORWARD) > 0.99, "Surface 1 normal must be FORWARD")
	print("Surface 1 normals verified: FORWARD.")

	# Inspect Surface 2 (Top cap only)
	var surf2_arrays = base_mesh.surface_get_arrays(2)
	var v2: PackedVector3Array = surf2_arrays[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = surf2_arrays[Mesh.ARRAY_NORMAL]
	print("Surface 2 vertex count: ", v2.size())
	assert(v2.size() == 4, "Surface 2 should have 4 vertices (top cap)")
	for norm in n2:
		assert(norm.dot(Vector3.UP) > 0.99, "Surface 2 normal must be UP")
		assert(norm.y > 0.8, "Surface 2 must NOT have vertical normals (norm.y > 0.8 required)")
	print("Surface 2 normals verified: UP only (no vertical normals to be discarded by cap shader).")

	# Test Cutaway Mesh
	var cutaway_mesh: ArrayMesh = wall._build_cutaway_beam_mesh(2.6, 0.5, 0)
	var c_s2_arrays = cutaway_mesh.surface_get_arrays(2)
	var c_n2: PackedVector3Array = c_s2_arrays[Mesh.ARRAY_NORMAL]
	for norm in c_n2:
		assert(norm.dot(Vector3.UP) > 0.99 or norm.dot(Vector3.DOWN) > 0.99, "Cutaway Surface 2 normals must be UP or DOWN only, got: %s" % str(norm))
	print("Cutaway mesh surface 2 verified: UP and DOWN only.")

	# Test Window Mesh
	var window_mesh: ArrayMesh = wall._build_window_mesh(2.6, 0.5, 0)
	var w_s2_arrays = window_mesh.surface_get_arrays(2)
	var w_n2: PackedVector3Array = w_s2_arrays[Mesh.ARRAY_NORMAL]
	for norm in w_n2:
		assert(norm.dot(Vector3.UP) > 0.99 or norm.dot(Vector3.DOWN) > 0.99, "Window mesh Surface 2 normals must be UP or DOWN only, got: %s" % str(norm))
	print("Window mesh surface 2 verified: UP and DOWN only.")

	# Test Materials Assignment
	wall._update_wall_materials()
	var mat0 = wall.wall_mesh.get_surface_override_material(0)
	var mat1 = wall.wall_mesh.get_surface_override_material(1)
	var mat2 = wall.wall_mesh.get_surface_override_material(2)
	assert(mat0 != null, "Surface 0 material should not be null")
	assert(mat1 != null, "Surface 1 material should not be null")
	assert(mat2 != null, "Surface 2 material should not be null")
	assert(mat2 == WALL.architecture_cap, "Surface 2 material should be architecture_cap")
	print("Material assignment in standard mode verified.")

	# Test Cutaway Mode Material Assignment
	wall.set_cutaway_mode(true)
	var cmat0 = wall.wall_mesh.get_surface_override_material(0)
	var cmat1 = wall.wall_mesh.get_surface_override_material(1)
	var cmat2 = wall.wall_mesh.get_surface_override_material(2)
	assert(cmat0 is ShaderMaterial, "Cutaway Surface 0 material must be ShaderMaterial")
	assert(cmat1 is ShaderMaterial, "Cutaway Surface 1 material must be ShaderMaterial")
	assert(cmat0.get_shader_parameter("architecture_cutaway") == true, "Surface 0 must have architecture_cutaway = true")
	assert(cmat1.get_shader_parameter("architecture_cutaway") == true, "Surface 1 must have architecture_cutaway = true")
	assert(cmat2 == WALL.architecture_cap, "Surface 2 must still receive architecture_cap")
	print("Material assignment in cutaway mode verified.")

	print("ALL VERIFICATIONS PASSED SUCCESSFULLY!")
	quit(0)
