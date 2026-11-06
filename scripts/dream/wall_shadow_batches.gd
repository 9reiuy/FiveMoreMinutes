class_name WallShadowBatches
extends Node3D

## Batches individual WallSegment3D shadow meshes into chunked MultiMeshInstance3Ds.
## Yields zero pixel difference while dramatically reducing CPU draw call submission.

const CHUNK := 8.0

var originals: Array[MeshInstance3D] = []
var original_visibility: Array[bool] = []
var batches: Array[MultiMeshInstance3D] = []
var geometry_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
## Runtime destruction needs to remove the copied caster as well as its source.
var edge_instances: Dictionary = {}
var local_originals: Dictionary = {}

func shadow_geometry(mesh: Mesh) -> Mesh:
	if mesh_cache.has(mesh):
		return mesh_cache[mesh]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return mesh
		var arrays := mesh.surface_get_arrays(surface)
		var offset := vertices.size()
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)
	var key := [vertices, normals, indices]
	if not geometry_cache.has(key):
		var geometry := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geometry_cache[key] = geometry
	mesh_cache[mesh] = geometry_cache[key]
	return mesh_cache[mesh]

func build(walls: Node3D) -> void:
	name = "WallShadowBatches"
	walls.add_child(self)
	var groups: Dictionary = {}
	for wall in walls.get_children():
		if wall.get_node_or_null("ExteriorBreakablePane") != null:
			continue # Destructible panes keep their individually removable shadow.
		if wall == self or not wall.has_method("set_wall_shadow_visible"):
			continue
		var mesh: MeshInstance3D = wall.get("shadow_mesh")
		if mesh == null or mesh.mesh == null:
			continue
		if not mesh.material_override is StandardMaterial3D:
			continue
		var local := walls.global_transform.affine_inverse() * mesh.global_transform
		var geometry := shadow_geometry(mesh.mesh)
		var chunk := Vector2i(floori(local.origin.x / CHUNK), floori(local.origin.z / CHUNK))
		var key := "%s:%s:%s" % [chunk, geometry.get_instance_id(), mesh.layers]
		if not groups.has(key):
			groups[key] = {"chunk": chunk, "mesh": geometry, "layers": mesh.layers, "instances": []}
		groups[key].instances.append({"transform": local, "visible": mesh.visible, "edge_key": String(wall.get_meta(&"edge_key", ""))})
		originals.append(mesh)
		original_visibility.append(mesh.visible)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for data in groups.values():
		var batch := MultiMeshInstance3D.new()
		batch.position = Vector3((data.chunk.x + 0.5) * CHUNK, 0, (data.chunk.y + 0.5) * CHUNK)
		batch.layers = data.layers
		batch.layers |= 1 << 12 # Architectural indirect-light caster.
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		batch.material_override = material
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = data.mesh
		multi.instance_count = data.instances.size()
		for index in data.instances.size():
			var pose: Transform3D = data.instances[index].transform
			pose.origin -= batch.position
			if not data.instances[index].visible:
				pose.basis = Basis.from_scale(Vector3.ZERO)
			multi.set_instance_transform(index, pose)
			var edge_key: String = data.instances[index].edge_key
			if not edge_key.is_empty(): edge_instances[edge_key] = {"multi": multi, "index": index}
		batch.multimesh = multi
		add_child(batch)
		batches.append(batch)
	set_batched(true)

func remove_edge(key: String) -> void:
	if not edge_instances.has(key): return
	var record: Dictionary = edge_instances[key]
	var pose: Transform3D = record.multi.get_instance_transform(int(record.index))
	pose.basis = Basis.from_scale(Vector3.ZERO)
	record.multi.set_instance_transform(int(record.index), pose)
	edge_instances.erase(key)

func restore_local_edge(key: String, wall: Node3D) -> void:
	# A changed joint gets its immutable copied caster retired. Its existing
	# source mesh now owns the locally rebuilt full profile, without a floor upload.
	remove_edge(key)
	var mesh := wall.get("shadow_mesh") as MeshInstance3D
	if not is_instance_valid(mesh): return
	local_originals[mesh.get_instance_id()] = true
	mesh.visible = bool(wall.get("wall_shadow_visible"))

func set_batched(enabled: bool) -> void:
	for index in originals.size():
		if is_instance_valid(originals[index]):
			originals[index].visible = false if enabled and not local_originals.has(originals[index].get_instance_id()) else original_visibility[index]
	for batch in batches:
		batch.visible = enabled
