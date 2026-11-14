extends SceneTree
## Import the supplied VRM, pose its rig, and bake an export-safe menu model.
const SOURCE := "C:/Users/Administrator/Desktop/Tools/Model/A/ung3.5wumao.vrm"
const WORK := "res://.runtime/screen_wall_avatar_20261107/"
const DEST := "res://art/preview/screen_wall/avatar/"
var rig: Skeleton3D
var converted_materials := {}
var converted_textures := {}
var leg_mesh := ArrayMesh.new()

func is_leg_bone(index: int) -> bool:
	while index >= 0:
		if rig.get_bone_name(index) in ["Left leg", "Right leg"]:
			return true
		index = rig.get_bone_parent(index)
	return false

func _initialize() -> void:
	run.call_deferred()

func bone_point(name: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone(name)).origin

func rotate_bone(name: String, axis: Vector3, degrees: float) -> void:
	var index := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(index)
	pose.basis = Basis(Quaternion(axis, deg_to_rad(degrees))) * pose.basis
	rig.set_bone_global_pose(index, pose)

func aim_bone(name: String, child_name: String, target: Vector3) -> void:
	var index := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(index)
	var old := (bone_point(child_name) - pose.origin).normalized()
	var wanted := (target - pose.origin).normalized()
	pose.basis = Basis(Quaternion(old, wanted)) * pose.basis
	rig.set_bone_global_pose(index, pose)

func two_bone(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, knee_hinge := false) -> void:
	var start := bone_point(upper)
	var length_a := start.distance_to(bone_point(lower))
	var length_b := bone_point(lower).distance_to(bone_point(end))
	var forward := (target - start).normalized()
	var distance := clampf(start.distance_to(target), absf(length_a - length_b) + 0.001, length_a + length_b - 0.001)
	var bend := pole - start
	bend = (bend - forward * bend.dot(forward)).normalized()
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, length_a * length_a - along * along))
	aim_bone(upper, lower, start + forward * along + bend * height)
	if knee_hinge:
		# Keep the kneecap and calf in one anatomical bending plane.
		# A shortest-arc aim alone can roll the two thighs in opposite ways.
		var index := rig.find_bone(upper)
		var pose := rig.get_bone_global_pose(index)
		var thigh := (bone_point(lower) - start).normalized()
		var calf := (target - bone_point(lower)).normalized()
		var wanted := -(calf - thigh * calf.dot(thigh)).normalized()
		var cap := pose.basis * Vector3.FORWARD
		cap = (cap - thigh * cap.dot(thigh)).normalized()
		var twist := atan2(thigh.dot(cap.cross(wanted)),cap.dot(wanted))
		pose.basis = Basis(Quaternion(thigh,twist)) * pose.basis
		rig.set_bone_global_pose(index,pose)
	aim_bone(lower, end, target)

func turn_forearm_up(lower: String, hand: String) -> void:
	var index := rig.find_bone(lower)
	var pose := rig.get_bone_global_pose(index)
	var axis := (bone_point(hand) - pose.origin).normalized()
	var dorsal := pose.basis * Vector3.UP
	dorsal = (dorsal - axis * dorsal.dot(axis)).normalized()
	var wanted := Vector3(0.0, 0.98, -0.12).normalized()
	wanted = (wanted - axis * wanted.dot(axis)).normalized()
	var angle := atan2(axis.dot(dorsal.cross(wanted)), dorsal.dot(wanted))
	pose.basis = Basis(Quaternion(axis, angle)) * pose.basis
	rig.set_bone_global_pose(index, pose)

func set_pose() -> void:
	# Let the pelvis face the seated legs; counter-turn the torso toward the CRT.
	rotate_bone("Hips", Vector3.UP, 55.0)
	rotate_bone("Spine", Vector3.UP, -55.0)
	rotate_bone("Spine", Vector3.RIGHT, -12.0)
	rotate_bone("Chest", Vector3.RIGHT, -10.0)
	rotate_bone("Neck", Vector3.RIGHT, 1.0)
	var neck_index := rig.find_bone("Neck")
	var neck_pose := rig.get_bone_global_pose(neck_index)
	neck_pose.origin += Vector3(0.0, -0.035, -0.015)
	rig.set_bone_global_pose(neck_index, neck_pose)
	rotate_bone("Head", Vector3.RIGHT, 4.0)
	rotate_bone("Head", Vector3.BACK, 17.0)
	rotate_bone("Head", Vector3.UP, -7.0)
	# Stacked forearms, elbows low and wide; the upper wrist supports the chin.
	two_bone("Left arm", "Left elbow", "Left wrist", Vector3(-0.005, 1.065, -0.360), Vector3(-0.35, 0.94, -0.18))
	two_bone("Right arm", "Right elbow", "Right wrist", Vector3(0.020, 1.115, -0.305), Vector3(0.35, 0.99, -0.18))
	# Expose actual upper hand/forearm surfaces to the screens above and behind.
	# Twisting around the forearm keeps both wrists at their support targets.
	turn_forearm_up("Left elbow", "Left wrist")
	turn_forearm_up("Right elbow", "Right wrist")
	for side in ["L", "R"]:
		var sign_value := 1.0 if side == "L" else -1.0
		for digit in ["IndexFinger", "MiddleFinger", "RingFinger", "LittleFinger"]:
			for part in [1, 2, 3]:
				var index := rig.find_bone(digit + str(part) + "_" + side)
				if index >= 0:
					rig.set_bone_pose_rotation(index, Quaternion(Vector3.BACK, deg_to_rad(sign_value * [8.0, 18.0, 12.0][part - 1])))
	# A relaxed seated base with unequal knee/foot positions, rather than a standing T-pose.
	# Both legs fold to the character's side before coming forward. They
	# pass around the supporting CRT, rather than through its back/glass.
	two_bone("Left leg", "Left knee", "Left ankle", Vector3(-0.40385, 0.58538, -0.51923), Vector3(-0.28846, 0.73346, -0.25000), true)
	two_bone("Right leg", "Right knee", "Right ankle", Vector3(-0.25000, 0.58538, -0.34615), Vector3(-0.25000, 0.79115, -0.09615), true)
	# Keep soles flat while allowing the feet to follow the side-facing pelvis.
	# A front-facing rest ankle here would counter-twist the turned shins.
	for ankle in ["Left ankle", "Right ankle"]:
		var index := rig.find_bone(ankle)
		var pose := rig.get_bone_global_pose(index)
		pose.basis = Basis(Vector3.UP, deg_to_rad(55.0)) * rig.get_bone_global_rest(index).basis
		rig.set_bone_global_pose(index, pose)

func resize_texture(texture: Texture2D) -> Texture2D:
	if texture == null: return null
	var id := texture.get_instance_id()
	if converted_textures.has(id): return converted_textures[id]
	var picture := texture.get_image()
	if picture.is_compressed(): picture.decompress()
	var largest := maxi(picture.get_width(), picture.get_height())
	if largest > 1024:
		picture.resize(roundi(picture.get_width() * 1024.0 / largest), roundi(picture.get_height() * 1024.0 / largest), Image.INTERPOLATE_LANCZOS)
	var result := ImageTexture.create_from_image(picture)
	converted_textures[id] = result
	return result

func lit_material(original: Material) -> StandardMaterial3D:
	var id := original.get_instance_id()
	if converted_materials.has(id): return converted_materials[id]
	var result := original.duplicate() as StandardMaterial3D
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.emission_enabled = false
	result.emission = Color.BLACK
	result.rim_enabled = false
	result.roughness = 0.97
	result.metallic = 0.0
	result.metallic_specular = 0.0
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.albedo_texture = resize_texture(result.albedo_texture)
	converted_materials[id] = result
	return result

func cpu_bake(node: MeshInstance3D) -> ArrayMesh:
	var matrices: Array[Transform3D] = []
	var leg_bindings: Array[bool] = []
	for index in node.skin.get_bind_count():
		var bone := rig.find_bone(node.skin.get_bind_name(index))
		if bone < 0: bone = node.skin.get_bind_bone(index)
		matrices.append(rig.get_bone_global_pose(bone) * node.skin.get_bind_pose(index))
		leg_bindings.append(is_leg_bone(bone))
	var baked := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var influence_count := joints.size() / positions.size()
		var leg_weights: Array[float] = []
		for vertex in positions.size():
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			var tangent := Vector3.ZERO
			var old_tangent := Vector3.ZERO
			var leg_weight := 0.0
			if not tangents.is_empty(): old_tangent = Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
			for influence in influence_count:
				var offset: int = vertex * influence_count + influence
				if weights[offset] <= 0.0: continue
				var transform := matrices[joints[offset]]
				if leg_bindings[joints[offset]]: leg_weight += weights[offset]
				point += (transform * positions[vertex]) * weights[offset]
				normal += (transform.basis * normals[vertex]) * weights[offset]
				tangent += (transform.basis * old_tangent) * weights[offset]
			positions[vertex] = point
			leg_weights.append(leg_weight)
			normals[vertex] = normal.normalized()
			if not tangents.is_empty():
				tangent = tangent.normalized()
				tangents[vertex * 4] = tangent.x
				tangents[vertex * 4 + 1] = tangent.y
				tangents[vertex * 4 + 2] = tangent.z
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		baked.surface_set_material(surface, node.get_active_material(surface))
		var leg_indices := PackedInt32Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in indices.size() / 3:
			var a := indices[triangle * 3]
			var b := indices[triangle * 3 + 1]
			var c := indices[triangle * 3 + 2]
			if maxf(leg_weights[a], maxf(leg_weights[b], leg_weights[c])) > 0.35:
				leg_indices.append_array(PackedInt32Array([a, b, c]))
		if not leg_indices.is_empty():
			var qa := arrays.duplicate()
			var qa_points := positions.duplicate()
			for vertex in qa_points.size(): qa_points[vertex] = node.transform * qa_points[vertex]
			qa[Mesh.ARRAY_VERTEX] = qa_points
			qa[Mesh.ARRAY_INDEX] = leg_indices
			leg_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, qa)
	return baked

func own_tree(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		child.scene_file_path = ""
		own_tree(child, owner_node)

func run() -> void:
	print("AVATAR_BUILD_PID=", OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(DEST)
	DirAccess.make_dir_recursive_absolute(WORK)
	if not FileAccess.file_exists(WORK + "source.glb") or FileAccess.get_sha256(WORK + "source.glb") != FileAccess.get_sha256(SOURCE):
		var copy := FileAccess.open(WORK + "source.glb", FileAccess.WRITE)
		copy.store_buffer(FileAccess.get_file_as_bytes(SOURCE))
		copy.close()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(WORK + "source.glb", state)
	if error != OK:
		quit(1)
		return
	var source := document.generate_scene(state)
	source.name = "Ung35EditableRig"
	root.add_child(source)
	rig = source.find_children("*", "Skeleton3D", true, false)[0]
	set_pose()
	var baked_root := Node3D.new()
	baked_root.name = "Ung35FoldedPose"
	var anchors := {}
	for bone in ["Hips", "Chest", "Head", "Left elbow", "Left wrist", "Right elbow", "Right wrist", "Left knee", "Right knee"]:
		var point := bone_point(bone)
		anchors[bone] = [point.x, point.y, point.z]
	for item in source.find_children("*", "MeshInstance3D", true, false):
		for surface in item.mesh.get_surface_count():
			item.set_surface_override_material(surface, lit_material(item.get_active_material(surface)))
		var mesh := MeshInstance3D.new()
		mesh.name = item.name
		mesh.mesh = cpu_bake(item)
		mesh.transform = item.transform
		baked_root.add_child(mesh)
		print("BAKED ", item.name, " box=", mesh.mesh.get_aabb())
	root.add_child(baked_root)
	own_tree(source, source)
	own_tree(baked_root, baked_root)
	var packed := PackedScene.new()
	packed.pack(source)
	var save_flags := ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES
	var editable_error := ResourceSaver.save(packed, DEST + "ung35_editable_pose.scn", save_flags)
	var static_scene := PackedScene.new()
	static_scene.pack(baked_root)
	var static_error := ResourceSaver.save(static_scene, DEST + "ung35_folded_pose.scn", save_flags)
	var exporter := GLTFDocument.new()
	var export_state := GLTFState.new()
	# Export the same posed, textured geometry without runtime-only state.
	var portable := Node3D.new()
	portable.name = "Ung35FoldedPose"
	for item in baked_root.get_children():
		var mesh := ArrayMesh.new()
		for surface in item.mesh.get_surface_count():
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			arrays[Mesh.ARRAY_COLOR] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(surface,item.mesh.surface_get_material(surface))
		var copy := MeshInstance3D.new()
		copy.name = item.name
		copy.transform = item.transform
		copy.mesh = mesh
		portable.add_child(copy)
	root.add_child(portable)
	own_tree(portable,portable)
	var glb_error := exporter.append_from_scene(portable, export_state)
	if glb_error == OK: glb_error = exporter.write_to_filesystem(export_state, DEST + "ung35_folded_pose.glb")
	var manifest := FileAccess.open(DEST + "pose_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"source_path": SOURCE, "source_sha256": FileAccess.get_sha256(SOURCE), "bones": rig.get_bone_count(), "anchors": anchors, "material_count": converted_materials.size(), "texture_count": converted_textures.size(), "editable": editable_error, "static": static_error, "glb": glb_error}, "\t"))
	manifest.close()
	ResourceSaver.save(leg_mesh, "res://tests/fixtures/screen_wall_avatar_leg_geometry.res", ResourceSaver.FLAG_COMPRESS)
	print("AVATAR_BUILD_RESULT editable=", editable_error, " static=", static_error, " glb=", glb_error)
	source.queue_free()
	baked_root.queue_free()
	portable.queue_free()
	rig = null
	await process_frame
	quit(0 if editable_error == OK and static_error == OK and glb_error == OK else 1)
