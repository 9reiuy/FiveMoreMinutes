extends Node
## Woo-style convex caster silhouettes. The mask contains geometry only: no
## character capture, screen/depth reconstruction, or dense physics ray field.
const PIXELS_PER_CELL := 32.0
const MAX_GLASS_SKIPS := 128
const MASK_UNITS_PER_TEXEL := 2.0

var world: Node3D
var origin_pixels := Vector2.ZERO
var range_pixels := 1024.0
var ray_count := 0 # Diagnostic compatibility: dense angular rays are retired.
var texture: ViewportTexture
var mask_viewport: SubViewport
var mask_rect := Rect2()
var field_ready := false
var visibility_revision := 0
var rebuilds := 0
var caster_count := 0
var shadow_triangles := 0
var last_update_usec := 0
var sparse_queries := 0
var _static_polygons: Array[PackedVector2Array] = []
var _doors: Array[Dictionary] = []
var _static_dirty := true
var _last_origin := Vector2(INF, INF)
var _shadow_mesh: ArrayMesh
var _shadow_instance: MeshInstance2D
var _query := PhysicsRayQueryParameters2D.new()
var _excludes: Array[RID] = []
var _los_cache: Dictionary = {}
var _space_state: PhysicsDirectSpaceState2D
var _player_rid := RID()
var _vertex_capacity := 0

func configure(owner_world: Node3D) -> void:
	world = owner_world
	name = "WooPolygonVisibility"
	var bounds := Rect2()
	var first := true
	for cell: Vector2i in world.floor_cells:
		var point := Vector2(cell) * PIXELS_PER_CELL
		if first: bounds = Rect2(point, Vector2.ZERO); first = false
		else: bounds = bounds.expand(point)
	# Include the visible city beyond the windows, not only walkable floor.
	mask_rect = bounds.grow(range_pixels)
	mask_rect.size = Vector2(ceilf(mask_rect.size.x), ceilf(mask_rect.size.y))
	mask_viewport = SubViewport.new()
	mask_viewport.name = "WallSilhouetteMask"
	mask_viewport.disable_3d = true
	mask_viewport.world_2d = World2D.new()
	mask_viewport.transparent_bg = false
	mask_viewport.size = Vector2i(ceilf(mask_rect.size.x / MASK_UNITS_PER_TEXEL), ceilf(mask_rect.size.y / MASK_UNITS_PER_TEXEL))
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(mask_viewport)
	var canvas := Node2D.new()
	mask_viewport.add_child(canvas)
	var background := Polygon2D.new()
	var canvas_size := Vector2(mask_viewport.size)
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(canvas_size.x, 0), canvas_size, Vector2(0, canvas_size.y)])
	background.color = Color.WHITE
	canvas.add_child(background)
	_shadow_mesh = ArrayMesh.new()
	_shadow_instance = MeshInstance2D.new()
	_shadow_instance.mesh = _shadow_mesh
	_shadow_instance.modulate = Color.BLACK
	canvas.add_child(_shadow_instance)
	texture = mask_viewport.get_texture()
	world.collision_root.child_entered_tree.connect(_collision_changed)
	world.collision_root.child_exiting_tree.connect(_collision_changed)
	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	_query.hit_from_inside = true
	_space_state = world.player.get_world_2d().direct_space_state
	_player_rid = world.player.get_rid()
	_query.collision_mask = world.get_vision_occluder_collision_mask()
	update_now()

func _collision_changed(node: Node) -> void:
	if node.has_meta(&"generated_wall_edge") or node.is_in_group(&"physical_doors"):
		_static_dirty = true

func update_now() -> void:
	var started := Time.get_ticks_usec()
	sparse_queries = 0
	if not is_instance_valid(world) or not is_instance_valid(world.player): return
	var changed := _static_dirty
	if _static_dirty: _collect_casters()
	origin_pixels = world.player.global_position
	_query.from = origin_pixels
	changed = changed or not origin_pixels.is_equal_approx(_last_origin)
	for record: Dictionary in _doors:
		var shape := record.shape.get_ref() as CollisionShape2D
		var body := record.body.get_ref() as CollisionObject2D
		if not is_instance_valid(shape) or not is_instance_valid(body):
			_static_dirty = true
			continue
		var active: bool = not shape.disabled and (body.collision_layer & world.get_vision_occluder_collision_mask()) != 0
		var rectangle := shape.shape as RectangleShape2D
		var transform := shape.global_transform
		if active != record.active or transform != record.transform or rectangle.size != record.size:
			record.active = active
			record.transform = transform
			record.size = rectangle.size
			record.polygon = _rectangle_polygon(transform, rectangle.size)
			changed = true
	if changed:
		_los_cache.clear()
		_build_shadows()
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_last_origin = origin_pixels
		visibility_revision += 1
		rebuilds += 1
	field_ready = true
	last_update_usec = Time.get_ticks_usec() - started

func _collect_casters() -> void:
	_static_dirty = false
	_static_polygons.clear()
	_doors.clear()
	var inverse_map := world.global_transform.affine_inverse()
	for body in world.collision_root.get_children():
		if not body is CollisionObject2D or body.is_queued_for_deletion(): continue
		if body.is_in_group(&"glass_windows") or body.is_in_group(&"breakable_glass_windows"): continue
		var key := String(body.get_meta(&"generated_wall_edge", ""))
		if not key.is_empty():
			if (body.collision_layer & world.get_vision_occluder_collision_mask()) == 0: continue
			var wall := world.wall_root.get_node_or_null("Wall_" + key.replace(":", "_")) as Node3D
			if wall == null or wall.is_queued_for_deletion(): continue
			var mesh := wall.get_node_or_null("WallMesh") as MeshInstance3D
			if mesh == null or mesh.mesh == null: continue
			# Project the visible footprint. The game's movement blocker can be
			# thicker; a caster must not blacken its own thinner displayed face.
			var box := mesh.mesh.get_aabb()
			var to_map := inverse_map * mesh.global_transform
			var points := PackedVector2Array()
			for corner in [Vector3(box.position.x, 0, box.position.z), Vector3(box.end.x, 0, box.position.z), Vector3(box.end.x, 0, box.end.z), Vector3(box.position.x, 0, box.end.z)]:
				var mapped: Vector3 = to_map * corner
				points.append(Vector2(mapped.x, mapped.z) * PIXELS_PER_CELL)
			var area := 0.0
			for index in points.size(): area += points[index].cross(points[(index + 1) % points.size()])
			if area < 0.0: points.reverse()
			_static_polygons.append(points)
		elif body.is_in_group(&"physical_doors"):
			for child in body.get_children():
				if not child is CollisionShape2D or not child.shape is RectangleShape2D: continue
				_doors.append({"shape": weakref(child), "body": weakref(body), "transform": Transform2D(), "size": Vector2.ZERO, "active": false, "polygon": PackedVector2Array()})
	caster_count = _static_polygons.size() + _doors.size()

func _rectangle_polygon(transform: Transform2D, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([transform * -half, transform * Vector2(half.x, -half.y), transform * half, transform * Vector2(-half.x, half.y)])

func _build_shadows() -> void:
	var vertices := PackedVector3Array()
	var extrusion := mask_rect.size.length() * 2.0
	for polygon in _static_polygons: _append_shadow(polygon, extrusion, vertices)
	for record: Dictionary in _doors:
		if record.active: _append_shadow(record.polygon, extrusion, vertices)
	shadow_triangles = vertices.size() / 3
	# Keep one dynamic vertex buffer. Clearing/recreating a render surface on
	# every step needlessly allocates driver objects and invalidates draw state.
	# An empty caster set must erase the preceding shadow, too.
	var wanted := maxi(1, caster_count) * 24
	if wanted > _vertex_capacity:
		_vertex_capacity = wanted
		_shadow_mesh.clear_surfaces()
	vertices.resize(_vertex_capacity) # spare triangles are degenerate at (0,0)
	if _shadow_mesh.get_surface_count() == 0:
		var colors := PackedColorArray()
		colors.resize(_vertex_capacity); colors.fill(Color.BLACK)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		_shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		var margin := extrusion / MASK_UNITS_PER_TEXEL
		_shadow_mesh.custom_aabb = AABB(Vector3(-margin,-margin,-1),Vector3(mask_viewport.size.x+margin*2.0,mask_viewport.size.y+margin*2.0,2))
	else:
		_shadow_mesh.surface_update_vertex_region(0, 0, vertices.to_byte_array())

func _append_shadow(polygon: PackedVector2Array, extrusion: float, vertices: PackedVector3Array) -> void:
	# CCW convex footprints. Only edges facing away from the player cast an
	# adjacent shadow; the caster itself stays available for normal 3D drawing.
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var outside := Vector2(edge.y, -edge.x)
		if outside.dot(origin_pixels - a) >= -0.001: continue
		var away_a := (a - origin_pixels).normalized()
		var away_b := (b - origin_pixels).normalized()
		var near_a := a + away_a * 0.75 - mask_rect.position
		var near_b := b + away_b * 0.75 - mask_rect.position
		var far_a := a + away_a * extrusion - mask_rect.position
		var far_b := b + away_b * extrusion - mask_rect.position
		for point in [near_a, near_b, far_b, near_a, far_b, far_a]:
			vertices.append(Vector3(point.x / MASK_UNITS_PER_TEXEL, point.y / MASK_UNITS_PER_TEXEL, 0))

func is_point_visible(point: Vector2, margin_px: float = 0.0) -> bool:
	# Woo also keeps sparse object LOS separate from geometric shadow drawing.
	# These are the only physics rays: actual actors/props, never a radial grid.
	if not is_instance_valid(world) or not is_instance_valid(world.player): return false
	var origin: Vector2 = world.player.global_position
	if not origin.is_equal_approx(origin_pixels):
		origin_pixels = origin
		_query.from = origin
		_los_cache.clear()
	var distance := origin.distance_to(point)
	if distance > range_pixels: return false
	if distance < 0.001: return true
	var cache_key := Vector3(point.x, point.y, margin_px)
	if _los_cache.has(cache_key): return bool(_los_cache[cache_key])
	_query.to = point
	_excludes.clear()
	_excludes.append(_player_rid)
	for iteration in MAX_GLASS_SKIPS + 1:
		_query.exclude = _excludes
		sparse_queries += 1
		var hit: Dictionary = _space_state.intersect_ray(_query)
		if hit.is_empty():
			_los_cache[cache_key] = true
			return true
		var node := hit.get("collider") as Node
		if is_instance_valid(node) and (node.is_in_group(&"glass_windows") or node.is_in_group(&"breakable_glass_windows")):
			_excludes.append(hit.rid)
			continue
		var hit_distance := origin.distance_to(hit.position)
		var visible := hit_distance > 0.001 and hit_distance + maxf(margin_px, 0.0) + 0.001 >= distance
		_los_cache[cache_key] = visible
		return visible
	return false

func set_enabled(value: bool) -> void:
	if is_instance_valid(mask_viewport):
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if value else SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	field_ready = false
	texture = null
	world = null
