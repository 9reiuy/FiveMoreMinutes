extends Node
## A single player-centred, omnidirectional visibility shadow map. All six
## cameras see ONE merged static architecture mesh, with the live door leaves.
## No per-wall projected black polygons, AABB silhouettes or character copies.
const PIXELS_PER_CELL := 32.0
const FACE_SIZE := 512
const EYE_HEIGHT := 0.95
const ORIGIN := &"hk_woo_shadow_origin"
const DEPTH_SHADER = preload("res://shaders/preview/hellkind_sample/vision_depth.gdshader")
const DIRECTIONS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
const UP_DIRECTIONS := [Vector3.UP, Vector3.UP, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.UP]
static var globals_registered := false

var world: Node3D
var origin_pixels := Vector2.ZERO
var light_position := Vector3.ZERO
var range_pixels := 1024.0
var ray_count := 0
var texture: ViewportTexture
var mask_viewport: SubViewport
var mask_rect := Rect2(Vector2.ZERO, Vector2.ONE) # legacy material metadata only
var field_ready := false
var visibility_revision := 0
var rebuilds := 0
var caster_count := 0
var shadow_triangles := 0
var last_update_usec := 0
var sparse_queries := 0
var static_builds := 0
var static_triangle_count := 0
var last_topology_profile: Dictionary = {}
var _static_dirty := true
var _last_origin := Vector3(INF, INF, INF)
var _last_world_transform := Transform3D()
var _enabled := true
var _views: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _depth_material: ShaderMaterial
var _shadow_world: World3D
var _casters: Node3D
var _static_mesh: MeshInstance3D
var _static_body: StaticBody3D
var _static_shape: CollisionShape3D
var _doors: Array[Dictionary] = []
var _los_cache: Dictionary = {}
var _query := PhysicsRayQueryParameters3D.new()
var _mesh_vertices: Dictionary = {}
var _door_shapes: Dictionary = {}
var _static_vertex_capacity := 0
var _body_anchor: Node2D

func configure(owner_world: Node3D) -> void:
	world = owner_world
	# The authored player root is at the feet, 13 map pixels below its movement
	# collider. At a south wall that root can lie inside masonry even though
	# the body is correctly stopped. Use the authoritative body centre, not an
	# animation/foot anchor, for both the optical map and sparse object rays.
	_body_anchor = world.player.get_node_or_null(^"CollisionShape2D") as Node2D
	name = "PlayerVisibilityShadow"
	_create_shadow_rig()
	world.collision_root.child_entered_tree.connect(_collision_changed)
	world.collision_root.child_exiting_tree.connect(_collision_changed)
	world.wall_root.child_entered_tree.connect(_architecture_changed)
	world.wall_root.child_exiting_tree.connect(_architecture_changed)
	world.door_root.child_entered_tree.connect(_architecture_changed)
	world.door_root.child_exiting_tree.connect(_architecture_changed)
	_query.collision_mask = 1
	_query.collide_with_areas = false
	_query.hit_back_faces = true
	_query.hit_from_inside = true
	update_now()

func _create_shadow_rig() -> void:
	if not globals_registered:
		RenderingServer.global_shader_parameter_add(ORIGIN, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, range_pixels / PIXELS_PER_CELL))
		globals_registered = true
	_depth_material = ShaderMaterial.new()
	_depth_material.shader = DEPTH_SHADER
	_shadow_world = World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.WHITE
	environment.background_energy_multiplier = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_shadow_world.environment = environment
	mask_viewport = SubViewport.new()
	mask_viewport.name = "VisibilityDepthAtlas"
	mask_viewport.disable_3d = true
	mask_viewport.use_hdr_2d = true
	mask_viewport.world_2d = World2D.new()
	mask_viewport.size = Vector2i(FACE_SIZE * 3, FACE_SIZE * 2)
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask_viewport)
	var copy_shader := Shader.new()
	copy_shader.code = "shader_type canvas_item; render_mode unshaded, blend_disabled; void fragment() { COLOR = texture(TEXTURE, UV); }"
	var copy_material := ShaderMaterial.new()
	copy_material.shader = copy_shader
	for face in 6:
		var view := SubViewport.new()
		view.name = "VisionFace%d" % face
		view.size = Vector2i(FACE_SIZE, FACE_SIZE)
		view.use_hdr_2d = true
		view.world_3d = _shadow_world
		view.positional_shadow_atlas_size = 0
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		mask_viewport.add_child(view)
		_views.append(view)
		var camera := Camera3D.new()
		camera.fov = 90.0
		camera.near = 0.025
		camera.far = range_pixels / PIXELS_PER_CELL
		view.add_child(camera)
		camera.current = true
		camera.basis = Basis.looking_at(DIRECTIONS[face], UP_DIRECTIONS[face])
		_cameras.append(camera)
		var tile := TextureRect.new()
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile.texture = view.get_texture()
		tile.position = Vector2(face % 3, face / 3) * FACE_SIZE
		tile.size = Vector2(FACE_SIZE, FACE_SIZE)
		tile.material = copy_material
		mask_viewport.add_child(tile)
	_casters = Node3D.new()
	_casters.name = "CompleteArchitecture"
	_views[0].add_child(_casters)
	_static_mesh = MeshInstance3D.new()
	_static_mesh.name = "AllStaticWalls"
	_static_mesh.material_override = _depth_material
	_static_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_casters.add_child(_static_mesh)
	_static_body = StaticBody3D.new()
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	_casters.add_child(_static_body)
	_static_shape = CollisionShape3D.new()
	_static_body.add_child(_static_shape)
	texture = mask_viewport.get_texture()

func _collision_changed(node: Node) -> void:
	if node.has_meta(&"generated_wall_edge") or node.is_in_group(&"physical_doors"):
		_static_dirty = true

func _architecture_changed(_node: Node) -> void:
	_static_dirty = true

func update_now() -> void:
	var started := Time.get_ticks_usec()
	sparse_queries = 0
	if not is_instance_valid(world) or not is_instance_valid(world.player): return
	if world.global_transform != _last_world_transform:
		_last_world_transform = world.global_transform
		_static_dirty = true
	var changed := _static_dirty
	if _static_dirty: _collect_architecture()
	origin_pixels = _body_anchor.global_position if is_instance_valid(_body_anchor) else world.player.global_position
	light_position = world.to_global(Vector3(origin_pixels.x / PIXELS_PER_CELL, EYE_HEIGHT, origin_pixels.y / PIXELS_PER_CELL))
	changed = _sync_doors() or changed or not light_position.is_equal_approx(_last_origin)
	if changed:
		_los_cache.clear()
		var origin_range := Vector4(light_position.x, light_position.y, light_position.z, range_pixels / PIXELS_PER_CELL)
		_depth_material.set_shader_parameter("vision_origin_range", origin_range)
		RenderingServer.global_shader_parameter_set(ORIGIN, origin_range)
		for camera in _cameras:
			camera.position = light_position
			# The sample updates at frame_pre_draw, after the normal Node3D
			# transform flush. Submit this pose now, not on the following frame.
			camera.force_update_transform()
		if _enabled: _request_draw()
		_last_origin = light_position
		visibility_revision += 1
		rebuilds += 1
	field_ready = true
	last_update_usec = Time.get_ticks_usec() - started

func _request_draw() -> void:
	for view in _views: view.render_target_update_mode = SubViewport.UPDATE_ONCE
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _collect_architecture() -> void:
	var started := Time.get_ticks_usec()
	_static_dirty = false
	var vertices := PackedVector3Array()
	caster_count = 0
	# Use complete shadow geometry, independent of the main Camera's cutaway.
	# Appending all triangles into one mesh lets depth testing choose the nearest
	# surface across wall joins, front/back/side faces and true window openings.
	for wall in world.wall_root.get_children():
		if wall.is_queued_for_deletion(): continue
		var mesh := wall.get_node_or_null(^"ShadowCasterMesh") as MeshInstance3D
		if mesh == null or mesh.mesh == null: continue
		_append_mesh(mesh.mesh, mesh.global_transform, vertices)
		caster_count += 1
	last_topology_profile = {"assemble_usec":Time.get_ticks_usec()-started}
	_install_static_vertices(vertices)
	var doors_started := Time.get_ticks_usec()
	var retained: Dictionary = {}
	for record in _doors:
		var source: Object = record.source.get_ref()
		if is_instance_valid(source): retained[source.get_instance_id()] = record
	var updated: Array[Dictionary] = []
	for door in world.door_root.get_children():
		if not door is PhysicalDoor3D or door.is_queued_for_deletion(): continue
		for source: MeshInstance3D in door._visuals:
			if not is_instance_valid(source) or source.mesh == null: continue
			var source_id := source.get_instance_id()
			if retained.has(source_id):
				updated.append(retained[source_id])
				retained.erase(source_id)
				caster_count += 1
				continue
			var proxy := MeshInstance3D.new()
			proxy.mesh = source.mesh
			proxy.material_override = _depth_material
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_casters.add_child(proxy)
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			_casters.add_child(body)
			var shape := CollisionShape3D.new()
			var faces := PackedVector3Array()
			_append_mesh(source.mesh, Transform3D.IDENTITY, faces)
			if not _door_shapes.has(source.mesh):
				var collision := ConcavePolygonShape3D.new()
				collision.backface_collision = true
				collision.set_faces(faces)
				_door_shapes[source.mesh] = collision
			shape.shape = _door_shapes[source.mesh]
			body.add_child(shape)
			updated.append({"source": weakref(source), "owner": weakref(door), "proxy": proxy, "body": body, "shape": shape,
				"transform": Transform3D(), "active": false, "triangles": faces.size() / 3})
			caster_count += 1
	for record in _doors:
		if record in updated: continue
		if is_instance_valid(record.proxy): record.proxy.free()
		if is_instance_valid(record.body): record.body.free()
	_doors = updated
	last_topology_profile["doors_usec"] = Time.get_ticks_usec()-doors_started
	last_topology_profile["total_usec"] = Time.get_ticks_usec()-started
	static_builds += 1
	_sync_doors()

func _install_static_vertices(vertices: PackedVector3Array) -> void:
	var started := Time.get_ticks_usec()
	static_triangle_count = vertices.size() / 3
	# Reuse the same GPU surface when breaking walls. Empty slots become
	# degenerate triangles; they cannot occlude, and need no new render layout.
	var merged := _static_mesh.mesh as ArrayMesh
	if merged == null: merged = ArrayMesh.new(); _static_mesh.mesh = merged
	var draw_vertices := vertices.duplicate()
	if vertices.size() > _static_vertex_capacity or merged.get_surface_count()==0:
		_static_vertex_capacity = maxi(3,vertices.size())
		draw_vertices.resize(_static_vertex_capacity)
		merged.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = draw_vertices
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	else:
		draw_vertices.resize(_static_vertex_capacity)
		merged.surface_update_vertex_region(0,0,draw_vertices.to_byte_array())
	# Room geometry can be anywhere in the generated floor, not around (0,0).
	if not vertices.is_empty():
		var bounds := AABB(vertices[0],Vector3.ZERO)
		for point in vertices: bounds = bounds.expand(point)
		merged.custom_aabb = bounds.grow(.1)
	last_topology_profile["upload_usec"] = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	if vertices.is_empty():
		_static_shape.shape = null
	else:
		var collision := _static_shape.shape as ConcavePolygonShape3D
		if collision == null:
			collision = ConcavePolygonShape3D.new()
			collision.backface_collision = true
			_static_shape.shape = collision
		collision.set_faces(vertices)
	last_topology_profile["physics_usec"] = Time.get_ticks_usec()-started
	shadow_triangles = static_triangle_count

func _append_mesh(mesh: Mesh, transform: Transform3D, vertices: PackedVector3Array) -> void:
	# Authored architecture meshes are immutable. Pull each local triangle
	# stream once; surface_get_arrays() may otherwise sync/read GPU buffers.
	if not _mesh_vertices.has(mesh): _mesh_vertices[mesh] = _read_mesh_vertices(mesh)
	for vertex: Vector3 in _mesh_vertices[mesh]: vertices.append(transform * vertex)

func _read_mesh_vertices(mesh: Mesh) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := mesh.surface_get_arrays(surface)
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not indices.is_empty():
			for index: int in indices: vertices.append(source[index])
		else:
			for vertex in source: vertices.append(vertex)
	return vertices

func _sync_doors() -> bool:
	var changed := false
	shadow_triangles = static_triangle_count
	for record in _doors:
		var source := record.source.get_ref() as MeshInstance3D
		var owner: Node = record.owner.get_ref()
		var active: bool = is_instance_valid(source) and is_instance_valid(owner) and not source.is_queued_for_deletion() and not owner.is_destroyed and source.visible
		var transform: Transform3D = source.global_transform if active else Transform3D.IDENTITY
		if active != record.active or transform != record.transform:
			record.proxy.visible = active
			record.proxy.transform = transform
			record.proxy.force_update_transform()
			record.body.transform = transform
			record.body.force_update_transform()
			record.body.collision_layer = 1 if active else 0
			record.transform = transform
			record.active = active
			changed = true
		if active: shadow_triangles += int(record.triangles)
	return changed

func is_point_visible(point: Vector2, margin_px: float = 0.0) -> bool:
	# Sparse object culling uses the same optical architecture at eye height.
	# It never treats a transparent pane as an opaque movement collider.
	if not field_ready or not is_instance_valid(world): return false
	var cache_key := Vector3(point.x, point.y, margin_px)
	if _los_cache.has(cache_key): return bool(_los_cache[cache_key])
	var target := world.to_global(Vector3(point.x / PIXELS_PER_CELL, EYE_HEIGHT, point.y / PIXELS_PER_CELL))
	var distance := light_position.distance_to(target)
	var visible := distance <= range_pixels / PIXELS_PER_CELL
	if visible and distance > 0.001:
		_query.from = light_position
		_query.to = target
		sparse_queries += 1
		var hit := _shadow_world.direct_space_state.intersect_ray(_query)
		visible = hit.is_empty() or light_position.distance_to(hit.position) + maxf(margin_px, 0.0) / PIXELS_PER_CELL + 0.001 >= distance
	_los_cache[cache_key] = visible
	return visible

func set_enabled(value: bool) -> void:
	_enabled = value
	if value: _request_draw()
	else:
		for view in _views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	field_ready = false
	texture = null
	world = null
