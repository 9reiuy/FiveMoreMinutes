extends Node3D
## Opt-in presentation sample. No shared mesh, collision, shadow caster or
## production material resource is modified. Attach only after floor dressing.
const CAP_SHADER = preload("res://shaders/dream3d/preview_wall_cap.gdshader")
const OLD_INCLUDE := "res://shaders/dream3d/architecture_cutaway.gdshaderinc"
const CLEAN_INCLUDE := "res://shaders/dream3d/preview_clean_cutaway.gdshaderinc"
const PIXELS := 32.0
var world: Node
var selected_room_id := -1
var selected_walls: Array[Node3D] = []
var selected_actors: Array[Node3D] = []
var _signature := ""
var _surface_root: Node3D
var _material_cache: Dictionary = {}
var _shader_cache: Dictionary = {}
var _invisible_cap: ShaderMaterial
var _cap_material: ShaderMaterial
var cap_vertex_count := 0
var cap_batch_count := 0
var cap_raster_cells := 0
var _original_visuals: Dictionary = {}

func apply(source: Node, room_id: int) -> void:
	if is_instance_valid(world): restore()
	world = source
	selected_room_id = room_id
	process_priority = 1000
	if _surface_root != null: _surface_root.queue_free()
	_surface_root = Node3D.new()
	_surface_root.name = "ContinuousWallTopSample"
	add_child(_surface_root)
	selected_walls.clear()
	selected_actors.clear()
	for root_name in ["wall_root", "door_root", "floor_root"]:
		var root: Node = world.get(root_name)
		if root == null: continue
		for actor in root.get_children():
			if not actor is Node3D: continue
			var edge: Dictionary = actor.get_meta(&"edge", actor.get_meta(&"door_edge", {}))
			if edge.is_empty() or not _belongs(edge): continue
			selected_actors.append(actor)
			if actor.get_node_or_null("WallMesh") != null: selected_walls.append(actor)
	_invisible_cap = ShaderMaterial.new()
	var invisible := Shader.new()
	invisible.code = "shader_type spatial; void fragment(){discard;}"
	_invisible_cap.shader = invisible
	_cap_material = ShaderMaterial.new()
	_cap_material.shader = CAP_SHADER
	_signature = ""
	_process(0.0)

func restore() -> void:
	for record: Dictionary in _original_visuals.values():
		var visual: MeshInstance3D = record.node.get_ref()
		if not is_instance_valid(visual): continue
		_copy_cut_flags(visual.material_override, record.override)
		visual.material_override = record.override
		for surface in record.surfaces.size():
			if visual.mesh != null and surface < visual.mesh.get_surface_count():
				_copy_cut_flags(visual.get_surface_override_material(surface), record.surfaces[surface])
				visual.set_surface_override_material(surface, record.surfaces[surface])
	_original_visuals.clear()
	selected_walls.clear()
	selected_actors.clear()
	if is_instance_valid(_surface_root):
		for child in _surface_root.get_children():
			_surface_root.remove_child(child)
			child.queue_free()
	world = null
	cap_vertex_count = 0
	cap_batch_count = 0
	cap_raster_cells = 0

func _copy_cut_flags(source: Material, target: Material) -> void:
	if not source is ShaderMaterial or not target is ShaderMaterial: return
	for uniform in ["architecture_cutaway", "architecture_wall_height", "architecture_floor_y"]:
		var value: Variant = source.get_shader_parameter(uniform)
		if value != null: target.set_shader_parameter(uniform, value)

func _remember(visual: MeshInstance3D) -> void:
	var id := visual.get_instance_id()
	if _original_visuals.has(id): return
	var surfaces: Array[Material] = []
	if visual.mesh != null:
		for surface in visual.mesh.get_surface_count():
			surfaces.append(visual.get_surface_override_material(surface))
	_original_visuals[id] = {"node": weakref(visual), "override": visual.material_override, "surfaces": surfaces}

func _belongs(edge: Dictionary) -> bool:
	for cell in world.call("_edge_side_cells", edge):
		if int(world.room_cells.get(cell, -1)) == selected_room_id: return true
	return false

func _process(_delta: float) -> void:
	if not is_instance_valid(world): return
	var state := ""
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var mesh := wall.get_node("WallMesh") as MeshInstance3D
		_remember(mesh)
		state += "%d:%s:%s;" % [wall.get_instance_id(), wall.cutaway_mode, mesh.is_visible_in_tree()]
		if mesh.mesh.get_surface_count() > 2:
			mesh.set_surface_override_material(2, _invisible_cap)
	for actor in selected_actors:
		if not is_instance_valid(actor): continue
		_patch_visuals(actor)
	if state != _signature:
		_signature = state
		_rebuild_caps()

func _clean_material(source: ShaderMaterial) -> ShaderMaterial:
	if source == null or source.shader == null: return source
	var code: String = source.shader.code
	if not code.contains(OLD_INCLUDE): return source
	var id := source.get_instance_id()
	if not _material_cache.has(id):
		if not _shader_cache.has(code):
			var clean := Shader.new()
			clean.code = code.replace(OLD_INCLUDE, CLEAN_INCLUDE)
			_shader_cache[code] = clean
		var material := source.duplicate() as ShaderMaterial
		material.shader = _shader_cache[code]
		_material_cache[id] = material
	var result: ShaderMaterial = _material_cache[id]
	# Original controls still own the cutaway choice and floor-relative plane.
	for uniform in ["architecture_cutaway", "architecture_wall_height", "architecture_floor_y"]:
		var value: Variant = source.get_shader_parameter(uniform)
		if value != null: result.set_shader_parameter(uniform, value)
	return result

func _patch_visuals(actor: Node3D) -> void:
	for visual in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := visual as MeshInstance3D
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		_remember(mesh)
		if String(mesh.name).begins_with("ArchitecturalCutSurface"):
			if mesh.material_override == null or not mesh.material_override.get_meta(&"sample_cap", false):
				var material := ShaderMaterial.new()
				material.shader = CAP_SHADER
				material.set_shader_parameter("slice", true)
				material.set_shader_parameter("wall_height", float(world.wall_height))
				material.set_meta(&"sample_cap", true)
				mesh.material_override = material
		elif mesh.material_override is ShaderMaterial:
			mesh.material_override = _clean_material(mesh.material_override)
		elif mesh.material_override == null and mesh.mesh != null:
			for surface in mini(mesh.mesh.get_surface_count(), 2):
				var material: Material = mesh.get_active_material(surface)
				if material is ShaderMaterial:
					mesh.set_surface_override_material(surface, _clean_material(material))

func _rebuild_caps() -> void:
	cap_vertex_count = 0
	cap_batch_count = 0
	cap_raster_cells = 0
	for child in _surface_root.get_children():
		_surface_root.remove_child(child)
		child.queue_free()
	var groups: Dictionary = {}
	var endpoints: Dictionary = {}
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		for sign_x in [-1.0, 1.0]:
			var p: Vector3 = world.to_local(wall.to_global(Vector3(sign_x * 0.5, 0, 0)))
			var key := Vector2i(roundi(p.x * PIXELS), roundi(p.z * PIXELS))
			endpoints[key] = int(endpoints.get(key, 0)) + 1
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var visual := wall.get_node("WallMesh") as MeshInstance3D
		if not visual.is_visible_in_tree(): continue
		var height: float = wall.wall_height * (0.3 if wall.cutaway_mode else 1.0)
		var level := roundi(height * 10000.0)
		if not groups.has(level): groups[level] = {}
		var half: float = wall.wall_thickness * 0.5
		var ends: Array[Vector3] = []
		for sign_x in [-1.0, 1.0]:
			var p: Vector3 = world.to_local(wall.to_global(Vector3(sign_x * 0.5, 0, 0)))
			var key := Vector2i(roundi(p.x * PIXELS), roundi(p.z * PIXELS))
			# Connected L/T/cross junctions overlap into a single raster union;
			# free ends stop at the real segment boundary.
			var extension: float = half if int(endpoints.get(key, 0)) > 1 else 0.0
			ends.append(world.to_local(wall.to_global(Vector3(sign_x * (0.5 + extension), 0, 0))))
		# The floor root rotates -45 degrees in the real game. Rasterise in its
		# architectural axes, never the world AABB of a rotated wall rectangle.
		var transverse: Vector3 = (world.global_basis.inverse() * wall.global_basis).z * half
		var low := Vector2(minf(ends[0].x, ends[1].x) - absf(transverse.x), minf(ends[0].z, ends[1].z) - absf(transverse.z))
		var high := Vector2(maxf(ends[0].x, ends[1].x) + absf(transverse.x), maxf(ends[0].z, ends[1].z) + absf(transverse.z))
		for z in range(roundi(low.y * PIXELS), roundi(high.y * PIXELS)):
			for x in range(roundi(low.x * PIXELS), roundi(high.x * PIXELS)):
				groups[level][Vector2i(x, z)] = true
	for level in groups:
		_make_union_mesh(groups[level], float(level) / 10000.0 + 0.002)

func _make_union_mesh(cells: Dictionary, height: float) -> void:
	cap_raster_cells += cells.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var rows: Dictionary = {}
	for cell: Vector2i in cells:
		if not rows.has(cell.y): rows[cell.y] = []
		rows[cell.y].append(cell.x)
	for z: int in rows:
		var xs: Array = rows[z]
		xs.sort()
		var start: int = xs[0]
		var previous := start
		var shade := _shade(Vector2i(start, z), cells)
		for index in range(1, xs.size() + 1):
			var next: int = xs[index] if index < xs.size() else previous + 2
			var next_shade := _shade(Vector2i(next, z), cells)
			if next != previous + 1 or next_shade != shade:
				var a := Vector3(float(start) / PIXELS, height, float(z) / PIXELS)
				var b := Vector3(float(previous + 1) / PIXELS, height, float(z + 1) / PIXELS)
				var quad := PackedVector3Array([a, Vector3(a.x, height, b.z), b, a, b, Vector3(b.x, height, a.z)])
				for p in quad:
					vertices.append(to_local(world.to_global(p))); normals.append(Vector3.UP); colors.append(shade)
				start = next
				shade = next_shade
			previous = next
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	cap_vertex_count += vertices.size()
	cap_batch_count += 1
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "JoinedCap_%s" % height
	visual.mesh = mesh
	visual.material_override = _cap_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface_root.add_child(visual)

func _shade(cell: Vector2i, cells: Dictionary) -> Color:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not cells.has(cell + direction): return Color("e0e2d8")
	# Sparse 2-world-unit staggered construction joints; never unit-tile borders.
	if posmod(cell.x, 64) == 0 or posmod(cell.y, 64) == 0: return Color("737f7b")
	return Color("a3afa8")
