extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const BLOOD := preload("res://scripts/entities/black_blood_effect.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	_check(world.regenerate(42001), "Fixed-seed office floor generated")
	var doorway: Array[Vector2i] = []
	for cell_variant in world.floor_cells.keys():
		var cell: Vector2i = cell_variant
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if not world.floor_cells.has(neighbor):
				continue
			if int(world.room_cells.get(cell, -1)) == int(world.room_cells.get(neighbor, -1)):
				continue
			if not world._can_cross_floor_edge(cell, neighbor):
				continue
			var start := Vector2(cell) * 32.0
			var finish := Vector2(neighbor) * 32.0
			if not world._is_blood_ground_allowed(start) or not world._is_blood_ground_allowed(finish):
				continue
			var ray := PhysicsRayQueryParameters2D.create(start, finish, world.WORLD_WALL_LAYER)
			if not world.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			doorway = [cell, neighbor]
			break
		if not doorway.is_empty():
			break
	_check(doorway.size() == 2, "An unobstructed room-to-room or room-to-corridor opening exists")
	if doorway.size() == 2:
		var start := Vector2(doorway[0]) * 32.0
		var finish := Vector2(doorway[1]) * 32.0
		var blood := BLOOD.new() as BlackBloodEffect
		blood.position = start
		world.world_effects_root.add_child(blood)
		blood.set_surface_context(world, int(world.room_cells.get(doorway[0], -1)))
		blood.wall_collision_mask = world.WORLD_WALL_LAYER
		blood._append_ground_pixel_clipped(finish - start)
		_check(not blood.ground_bounds_enabled, "3D blood has no source-room rectangle")
		_check(blood.ground_pixels.has(finish - start), "Open doorway accepts blood on the other side")
		var floor_pixel_count := blood.ground_pixels.size()
		var void_position := Vector2(-5000.0, -5000.0)
		blood._append_ground_pixel_clipped(void_position - start)
		_check(blood.ground_pixels.size() == floor_pixel_count or not blood.ground_pixels.has(void_position - start), "Outside-floor blood cannot land in the void")
		blood.free()
		world.spawn_death_blood_pool(start, int(world.room_cells.get(doorway[0], -1)))
		var pool: BlackBloodEffect = null
		for child in world.world_effects_root.get_children():
			if child is BlackBloodEffect and child.office_pool_core:
				pool = child
		_check(pool != null, "Real 3D death pool spawned by a doorway")
		if pool != null:
			_check(not pool.ground_bounds_enabled, "Death pool uses complete floor footprint")
			var bridge_ref: Variant = pool.get_meta(&"depth_visual_bridge", null)
			var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
			var capture := bridge.get_node_or_null("ActorDepthViewport") as SubViewport if bridge != null else null
			_check(capture != null and capture.size.x >= 224, "Death pool capture contains final growth rim")
	var blocked_edge: Array[Vector2i] = []
	for cell_variant in world.floor_cells.keys():
		var cell: Vector2i = cell_variant
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if not world.floor_cells.has(neighbor) or world._can_cross_floor_edge(cell, neighbor):
				continue
			var origin := Vector2(cell) * 32.0
			var target := Vector2(neighbor) * 32.0
			if not world._is_blood_ground_allowed(origin) or not world._is_blood_ground_allowed(target):
				continue
			var ray := PhysicsRayQueryParameters2D.create(origin, target, world.WORLD_WALL_LAYER)
			if world.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			blocked_edge = [cell, neighbor]
			break
		if not blocked_edge.is_empty():
			break
	_check(blocked_edge.size() == 2, "A real wall between two floor cells exists")
	if blocked_edge.size() == 2:
		var origin := Vector2(blocked_edge[0]) * 32.0
		var target := Vector2(blocked_edge[1]) * 32.0
		var blocked_blood := BLOOD.new() as BlackBloodEffect
		blocked_blood.position = origin
		world.world_effects_root.add_child(blocked_blood)
		blocked_blood.set_surface_context(world, int(world.room_cells.get(blocked_edge[0], -1)))
		blocked_blood.wall_collision_mask = world.WORLD_WALL_LAYER
		blocked_blood._append_ground_pixel_clipped(target - origin)
		_check(not blocked_blood.ground_pixels.has(target - origin), "Solid wall stops blood before adjacent room")
		blocked_blood.free()
	var old_effect := BLOOD.new() as BlackBloodEffect
	root.add_child(old_effect)
	_check(old_effect.surface_world == null and not old_effect.ground_bounds_enabled, "Old 2D effect has no 3D floor validator")
	old_effect.free()
	world.free()
	await process_frame
	print("OFFICE_BLOOD_CROSS_ROOM_CHECKS=", checks, " FAILURES=", failures.size())
	quit(1 if not failures.is_empty() else 0)
