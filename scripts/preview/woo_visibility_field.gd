extends RefCounted
## Presentation-only LOS field. Uses the existing gameplay collision world and
## never changes combat perception, collision layers, or scene visibility.
## Call update_now() after the player's physics movement/door collision sync.
## Texel i samples -PI + TAU * (i + 0.5) / ray_count. The shader must use
## fract((atan(delta.y, delta.x) + PI) / TAU), repeat_enable and no mipmaps.
## Each red channel is the first opaque hit distance / range_pixels.

const DEFAULT_OCCLUDER_MASK := 4
const MAX_GLASS_SKIPS := 128
const DISTANCE_EPSILON := 0.001

var origin_pixels := Vector2.ZERO
var range_pixels := 320.0
var ray_count := 2048
var texture: ImageTexture
## CPU time for the most recent complete field update, not a GPU measurement.
var last_update_usec := 0
var ready := false

var _world_ref: WeakRef
var _image: Image
var _distances := PackedFloat32Array()
var _directions := PackedVector2Array()
var _query := PhysicsRayQueryParameters2D.new()
var _exclude_rids: Array[RID] = []
var _player_rid := RID()
var _ray_origin := Vector2.ZERO


func configure(world: Node) -> void:
	_world_ref = weakref(world) if is_instance_valid(world) else null
	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	# An origin embedded in an opaque blocker must not see through its back face.
	# Glass and the player's own body are excluded explicitly below.
	_query.hit_from_inside = true
	ready = false
	last_update_usec = 0
	_ensure_storage()
	_distances.fill(1.0)
	_upload_distances()
	if is_instance_valid(world):
		var player := world.get("player") as Node2D
		if is_instance_valid(player):
			origin_pixels = player.global_position


func update_now() -> void:
	var started_usec := Time.get_ticks_usec()
	_ensure_storage()
	var space_state := _prepare_query()
	ready = space_state != null and is_finite(range_pixels) and range_pixels > 0.0
	if not ready:
		_distances.fill(0.0)
		_upload_distances()
		last_update_usec = Time.get_ticks_usec() - started_usec
		return
	origin_pixels = _ray_origin
	for index in ray_count:
		var distance := _first_opaque_distance(
			space_state, _ray_origin + _directions[index] * range_pixels, range_pixels
		)
		_distances[index] = clampf(distance / range_pixels, 0.0, 1.0)
	_upload_distances()
	last_update_usec = Time.get_ticks_usec() - started_usec


## Exact physics test for actor/prop gating, independent of the angular texture.
## margin_px tolerates an endpoint slightly beyond a wall surface, but never
## extends range_pixels. Public origin_pixels remains paired with the texture;
## this query uses the player's current position without changing that pair.
func is_point_visible(gameplay_point: Vector2, margin_px: float = 0.0) -> bool:
	if not gameplay_point.is_finite() or not is_finite(range_pixels) or range_pixels <= 0.0:
		return false
	var space_state := _prepare_query()
	if space_state == null:
		return false
	var distance := _ray_origin.distance_to(gameplay_point)
	if distance > range_pixels:
		return false
	if distance <= DISTANCE_EPSILON:
		return true
	var hit_distance := _first_opaque_distance(space_state, gameplay_point, distance)
	# A zero-distance opaque hit means the origin is embedded in a wall. Do not
	# let a positive endpoint margin turn that fail-closed case into a clear ray.
	if hit_distance <= DISTANCE_EPSILON:
		return false
	var margin := maxf(margin_px, 0.0) if is_finite(margin_px) else 0.0
	return hit_distance + margin + DISTANCE_EPSILON >= distance


func _prepare_query() -> PhysicsDirectSpaceState2D:
	if _world_ref == null:
		return null
	var world := _world_ref.get_ref() as Node
	if not is_instance_valid(world) or not world.is_inside_tree():
		return null
	var player := world.get("player") as Node2D
	if not is_instance_valid(player) or not player.is_inside_tree():
		return null
	_ray_origin = player.global_position
	if not _ray_origin.is_finite():
		return null
	var mask := DEFAULT_OCCLUDER_MASK
	if world.has_method("get_vision_occluder_collision_mask"):
		mask = int(world.call("get_vision_occluder_collision_mask"))
	if mask <= 0:
		return null
	_query.from = _ray_origin
	_query.collision_mask = mask
	_player_rid = player.get_rid() if player is CollisionObject2D else RID()
	var physics_world := player.get_world_2d()
	return physics_world.direct_space_state if physics_world != null else null


func _first_opaque_distance(
	space_state: PhysicsDirectSpaceState2D, endpoint: Vector2, max_distance: float
) -> float:
	_query.to = endpoint
	_exclude_rids.clear()
	if _player_rid.is_valid():
		_exclude_rids.append(_player_rid)
	_query.exclude = _exclude_rids
	for skip_index in MAX_GLASS_SKIPS + 1:
		var hit := space_state.intersect_ray(_query)
		if hit.is_empty():
			return max_distance
		var collider := hit.get("collider") as Node
		var hit_position: Vector2 = hit.get("position", _ray_origin)
		var distance := clampf(_ray_origin.distance_to(hit_position), 0.0, max_distance)
		if is_instance_valid(collider) and (
			collider.is_in_group(&"glass_windows")
			or collider.is_in_group(&"breakable_glass_windows")
		):
			var hit_rid: RID = hit.get("rid", RID())
			if skip_index < MAX_GLASS_SKIPS and hit_rid.is_valid() and not _exclude_rids.has(hit_rid):
				_exclude_rids.append(hit_rid)
				_query.exclude = _exclude_rids
				continue
		# Invalid/repeated glass RIDs or the skip limit fail closed at this hit.
		return distance
	return 0.0


func _ensure_storage() -> void:
	ray_count = maxi(ray_count, 8)
	if _distances.size() == ray_count and _image != null and texture != null:
		return
	_distances.resize(ray_count)
	_distances.fill(1.0)
	_directions.resize(ray_count)
	for index in ray_count:
		var angle := -PI + TAU * (float(index) + 0.5) / float(ray_count)
		_directions[index] = Vector2(cos(angle), sin(angle))
	_image = Image.create_from_data(ray_count, 1, false, Image.FORMAT_RF, _distances.to_byte_array())
	if texture == null:
		texture = ImageTexture.create_from_image(_image)
	else:
		# Keep the resource identity stable for materials already bound to it.
		texture.set_image(_image)


func _upload_distances() -> void:
	_image.set_data(ray_count, 1, false, Image.FORMAT_RF, _distances.to_byte_array())
	texture.update(_image)
