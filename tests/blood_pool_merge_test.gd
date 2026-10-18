extends SceneTree

class MaskedBlood extends BlackBloodEffect:
	var blocked := false
	func _is_ground_world_position_valid(world_position: Vector2) -> bool:
		return world_position.x < 8.0
	func _raycast_environment(_from: Vector2, destination: Vector2) -> Dictionary:
		return {"position": destination} if blocked else {}

class BlockFloor extends Node:
	func _is_blood_ground_block_allowed(_bounds: Rect2) -> bool:
		return true
	func _is_blood_ground_allowed(_point: Vector2) -> bool:
		return true

func _effect(position_value: Vector2) -> BlackBloodEffect:
	var effect := BlackBloodEffect.new()
	root.add_child(effect)
	effect.position = position_value
	effect.set_meta(&"blood_floor_visual", true)
	effect.surface_room_id = 1
	effect.settled = true
	effect.ground_pixels.assign([Vector2.ZERO])
	effect.ground_pixel_types.assign([BlackBloodEffect.StampType.PIXEL_CELL])
	return effect

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var pool := MaskedBlood.new()
	root.add_child(pool)
	pool.office_pool_core = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	pool.setup_death_pool(rng, 1, 1.0, 0.45, 0.35, 1.0)
	var initial: Array[Vector2] = pool.ground_pixels.duplicate()
	var version := pool.content_version
	pool._process(0.001)
	assert(pool.content_version == version, "Sub-30Hz step should not recapture unchanged occupancy")
	pool._process(0.1)
	assert(pool.ground_pixels.size() > initial.size())
	for cell in initial:
		assert(pool.ground_pixels.has(cell), "Existing cells must not move during growth")
	pool._process(1.0)
	assert(pool.is_visual_settled() and is_equal_approx(pool.ground_visual_scale, 1.0))
	assert(pool.pool_growth_duration == 0.45 and pool.pool_min_scale == 0.35 and pool.pool_max_scale == 1.0)
	for cell in pool.ground_pixels:
		assert(cell == cell.round() and cell.x < 8.0, "Cells must respect fixed pixels and floor mask")
	assert(pool.ground_pixels.size() <= pool.MAX_POOL_CELLS)
	var a := _effect(Vector2(10, 10))
	var b := _effect(Vector2(11, 10))
	a.ground_pixels.assign([Vector2.ZERO, Vector2(2, 0), Vector2(1, -1)])
	a.ground_pixel_types.assign([4, 4, 4])
	assert(a.can_absorb_ground_effect(b))
	assert(a.absorb_ground_effect(b))
	assert(a.ground_pixels.has(Vector2.RIGHT), "World-to-local conversion must preserve incoming cell")
	var size := a.ground_pixels.size()
	var merge_version := a.content_version
	assert(a.absorb_ground_effect(b) and a.ground_pixels.size() == size, "Repeated absorption must deduplicate")
	assert(a.content_version == merge_version, "Identical union must not request another capture")
	b.set_meta(&"blood_floor_token", 7)
	assert(not a.can_absorb_ground_effect(b), "Different floors must not merge")
	b.remove_meta(&"blood_floor_token")
	var replica := BlackBloodEffect.new()
	replica.set_depth_replica(true)
	a.copy_depth_visual_state_to(replica)
	assert(replica.ground_pixels == a.ground_pixels and replica.ground_pixel_types == a.ground_pixel_types)
	assert(not replica.is_processing(), "Depth copy must stay passive")
	replica.free()
	b.surface_room_id = 2
	assert(not a.can_absorb_ground_effect(b), "Room boundaries must reject merging")
	b.surface_room_id = 1
	b.pool_growth_active = true
	assert(not a.can_absorb_ground_effect(b), "An active growth source must not be absorbed")
	b.pool_growth_active = false
	b.position = Vector2(119, 10)
	assert(not a.can_absorb_ground_effect(b, 108.0), "Stamp extent must stay inside capture bounds")
	b.position = Vector2(117, 10)
	b.ground_pixel_types[0] = BlackBloodEffect.StampType.CORE_SPLAT
	assert(not a.can_absorb_ground_effect(b, 108.0), "Full stamp footprint, including lobes, must fit")
	pool.set_meta(&"blood_floor_visual", true)
	pool.surface_room_id = 1
	pool.blocked = true
	assert(not pool.can_absorb_ground_effect(a), "Sources separated by a wall must not merge")
	var c := _effect(Vector2.ZERO)
	var d := _effect(Vector2.ZERO)
	c.ground_pixels.assign([Vector2.LEFT, Vector2.RIGHT, Vector2.UP])
	c.ground_pixel_types.assign([4, 4, 4])
	d.ground_pixels.assign([Vector2(5, 5)])
	assert(c.absorb_ground_effect(d))
	assert(c.ground_pixels.has(Vector2.ZERO), "Three-sided single-pixel holes should close")
	var floor_context := BlockFloor.new()
	root.add_child(floor_context)
	var guarded := BlackBloodEffect.new()
	root.add_child(guarded)
	guarded.set_surface_context(floor_context, 1)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(4.0, 1.0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(0.2, 0.2)
	collision.shape = rectangle
	wall.add_child(collision)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	var cache: Dictionary = {}
	assert(not guarded._is_pool_cell_allowed(Vector2(8, 2), cache), "Thin wall between block corner rays must reject occluded cell")
	assert(guarded._is_pool_cell_allowed(Vector2(8, 0), cache), "Unsafe blocks must fall back per pixel, retaining visible edge cells")
	assert(cache.get(Vector2i(floori(8.0 / guarded.POOL_VISIBILITY_BLOCK_SIZE), 0), true) == false, "Convex visibility hull must see the thin wall")
	wall.free()
	guarded.free()
	floor_context.free()
	for effect in [pool, a, b, c, d]:
		effect.free()
	print("BLOOD_POOL_MERGE_OK fixed-grid growth, masks, world transforms, deduplication, room/active/bounds/wall rejection, hole fill")
	quit(0)
