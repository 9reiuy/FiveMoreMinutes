extends Object

## Floor visual batching: generated FloorTile meshes are grouped into small
## spatial chunks.  A single map-wide mesh has an origin at (0, 0, 0), so the
## Compatibility renderer can cull a SpotLight based on that origin even when
## the light cone intersects a distant tile.  Keeping each chunk local to its
## own center gives SpotLight3D/flashlight and ceiling lights a correct,
## perspective-safe receiver without changing floor gameplay topology.

const FLOOR_TILE_SCRIPT := preload("res://scripts/dream/floor_tile_3d.gd")
const THEME_SCRIPT := preload("res://scripts/dream/dream_room_environment_theme.gd")
const FLOOR_CHUNK_SIZE := 8
const FLOOR_BRICKS_PER_TEXTURE := 6


static func build(world: Node) -> void:
	var floor_root: Node3D = world.floor_root
	if floor_root == null:
		return
	# Keep one mesh per spatial chunk. The chunk mesh still bakes every cell's
	# 6x6 texture phase, so visual UVs remain identical to the old per-phase
	# batches while the light culling origin stays close to the rendered tiles.
	var buckets: Dictionary = {}
	# The logical floor map still contains the authored corridor graph so room
	# selection/path diagnostics remain deterministic. Presentation uses room
	# cells plus the explicitly authored transition stubs; the old end-to-end
	# corridor floor is intentionally not rendered.
	var source_cells: Dictionary = world.floor_cells
	var presentation_variant: Variant = world.get("presentation_floor_cells")
	var lazy_presentation := bool(world.get("lazy_room_presentation"))
	if presentation_variant is Dictionary:
		# In lazy mode an empty active-room selection must stay empty rather than
		# silently falling back to the full logical map. The fallback is retained
		# only for legacy/non-lazy callers that do not provide a presentation map.
		if lazy_presentation or not presentation_variant.is_empty():
			source_cells = presentation_variant
	var stub_variant: Variant = world.get("transition_stub_floor_cells")
	if stub_variant is Dictionary:
		if source_cells == world.floor_cells:
			source_cells = source_cells.duplicate(true)
		for stub_cell_variant in stub_variant.keys():
			source_cells[stub_cell_variant] = &"transition_stub"
	var elevator_id: int = int(world.get("elevator_room_id")) if world.get("elevator_room_id") != null else -1
	var reception_entry := world.has_method("_has_elevator_reception") and bool(world.call("_has_elevator_reception"))
	var room_cells_map: Dictionary = world.get("room_cells") if world.get("room_cells") is Dictionary else {}
	for cell_variant in source_cells.keys():
		var cell: Vector2i = cell_variant
		if elevator_id >= 0 and not reception_entry and int(room_cells_map.get(cell, -1)) == elevator_id:
			continue
		var chunk := Vector2i(
			floori(float(cell.x) / float(FLOOR_CHUNK_SIZE)),
			floori(float(cell.y) / float(FLOOR_CHUNK_SIZE))
		)
		if not buckets.has(chunk):
			buckets[chunk] = []
		buckets[chunk].append(cell)
	for chunk_variant in buckets.keys():
		var chunk: Vector2i = chunk_variant
		var cells: Array = buckets[chunk]
		var instance := MeshInstance3D.new()
		instance.name = "FloorBatch_%d_%d" % [chunk.x, chunk.y]
		instance.mesh = _build_chunk_mesh(chunk, cells, world)
		instance.position = _chunk_center(chunk)
		# Surface materials are assigned on each mesh surface; do not override globally.
		instance.material_override = null
		# Floor is a world receiver (layer 1), matching ceiling and flashlight
		# cull masks. Collision/LOS/navigation remain 2D authority.
		instance.layers = 1
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floor_root.add_child(instance)


static func _chunk_center(chunk: Vector2i) -> Vector3:
	return Vector3(
		float(chunk.x * FLOOR_CHUNK_SIZE) + float(FLOOR_CHUNK_SIZE) * 0.5,
		0.0,
		float(chunk.y * FLOOR_CHUNK_SIZE) + float(FLOOR_CHUNK_SIZE) * 0.5
	)


static func _build_chunk_mesh(chunk: Vector2i, cells: Array, world: Node) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var center := _chunk_center(chunk)
	var room_cells: Dictionary = world.get("room_cells") if world != null and world.get("room_cells") != null else {}
	var rooms: Array = world.get("rooms") if world != null and world.get("rooms") is Array else []
	var room_plans: Dictionary = world.get("room_layout_plans") if world != null and world.get("room_layout_plans") is Dictionary else {}

	var cells_by_mat: Dictionary = {}
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		var mat: Material = THEME_SCRIPT.FLOOR_B_MATERIAL
		var room_id := int(room_cells.get(cell, -1))
		if room_id >= 0 and room_id < rooms.size():
			var room: Dictionary = rooms[room_id]
			var archetype := String(room.get("archetype", ""))
			var plan: Dictionary = room_plans.get(room_id, {})
			var func_areas: Variant = plan.get("functional_areas", [])
			if THEME_SCRIPT.is_accent_cell(cell, room, func_areas):
				mat = THEME_SCRIPT.get_sample_accent_floor_material(room)
			else:
				mat = THEME_SCRIPT.get_sample_base_floor_material(room)
		if not cells_by_mat.has(mat):
			cells_by_mat[mat] = []
		cells_by_mat[mat].append(cell)

	var surface_idx := 0
	for mat_variant in cells_by_mat.keys():
		var mat: Material = mat_variant
		var mat_cells: Array = cells_by_mat[mat]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()

		for cell_variant in mat_cells:
			var cell: Vector2i = cell_variant
			var base_index: int = vertices.size()
			var cell_x := float(cell.x)
			var cell_z := float(cell.y)
			vertices.append(Vector3(cell_x - 0.5, 0.0, cell_z - 0.5) - center)
			vertices.append(Vector3(cell_x + 0.5, 0.0, cell_z - 0.5) - center)
			vertices.append(Vector3(cell_x + 0.5, 0.0, cell_z + 0.5) - center)
			vertices.append(Vector3(cell_x - 0.5, 0.0, cell_z + 0.5) - center)
			for _corner in 4:
				normals.append(Vector3.UP)
			var phase := Vector2i(
				posmod(cell.x, FLOOR_BRICKS_PER_TEXTURE),
				posmod(cell.y, FLOOR_BRICKS_PER_TEXTURE)
			)
			var uv_origin := Vector2(phase) / float(FLOOR_BRICKS_PER_TEXTURE)
			var uv_step := 1.0 / float(FLOOR_BRICKS_PER_TEXTURE)
			uvs.append(uv_origin)
			uvs.append(uv_origin + Vector2(uv_step, 0.0))
			uvs.append(uv_origin + Vector2(uv_step, uv_step))
			uvs.append(uv_origin + Vector2(0.0, uv_step))
			indices.append(base_index)
			indices.append(base_index + 1)
			indices.append(base_index + 2)
			indices.append(base_index)
			indices.append(base_index + 2)
			indices.append(base_index + 3)

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface_idx, mat)
		surface_idx += 1

	return mesh
