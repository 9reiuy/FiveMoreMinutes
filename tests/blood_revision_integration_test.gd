extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func mark(world: Node, origin: Vector2, room_id: int, floor_visual := true) -> BlackBloodEffect:
	var blood := BlackBloodEffect.new()
	blood.position = origin
	blood.wall_collision_mask = world.WORLD_WALL_LAYER
	world._add_3d_blood_effect(blood, room_id, floor_visual)
	blood.ground_pixels.assign([Vector2.ZERO, Vector2(2, 0), Vector2(0, 2)])
	blood.ground_pixel_types.assign([BlackBloodEffect.StampType.STANDARD_DROP, BlackBloodEffect.StampType.STANDARD_DROP, BlackBloodEffect.StampType.STANDARD_DROP])
	blood.settled = true
	blood._enter_static_presentation()
	return blood

func bridge_of(blood: Node) -> Node:
	var ref: Variant = blood.get_meta(&"depth_visual_bridge", null)
	return ref.get_ref() if ref is WeakRef else null

func floor_marks(world: Node) -> Array:
	return world.world_effects_root.get_children().filter(func(n: Node) -> bool: return n is BlackBloodEffect and bool(n.get_meta(&"blood_floor_visual", false)) and not n.is_queued_for_deletion())

func _run() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001), "fixed seed generation")
	world.player.set_physics_process(false)
	var origin: Vector2 = world.player.global_position
	var room_id: int = world.get_current_room_id()
	var first := mark(world, origin, room_id)
	await frames(6)
	var source_bridge := bridge_of(first)
	var second := mark(world, origin + Vector2(8, 0), room_id)
	var second_ref: WeakRef = weakref(second)
	var second_bridge_ref: WeakRef = weakref(bridge_of(second))
	await frames(12)
	check(floor_marks(world).size() == 1, "near settled marks share one authority")
	check(second_ref.get_ref() == null, "absorbed blood authority is freed")
	var released_bridge: Node = second_bridge_ref.get_ref()
	check(released_bridge==null or (not released_bridge.configured and released_bridge.source_actor==null),"absorbed carrier is destroyed or ownerless")
	if released_bridge!=null:
		check(not released_bridge.actor_sprite.visible and released_bridge.render_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"idle absorbed carrier cannot display stale blood")
		var pool: Node3D=world._get_blood_ground_capture_pool()
		check(pool.small_idle.has(released_bridge) or pool.large_idle.has(released_bridge),"absorbed carrier belongs exclusively to idle pool")
	check(first.ground_pixels.has(Vector2(8, 0)), "absorbed stamps preserve world position")
	check(first.ground_pixels.size() == first.ground_pixel_types.size(), "merged stamp types remain aligned")
	check(bridge_of(first) == source_bridge, "surviving capture bridge reused")
	if is_instance_valid(source_bridge):
		var capture: SubViewport = source_bridge.get("render_viewport")
		check(capture.size == Vector2i(224, 224), "bounded merged capture is 224 squared")
		var sprite: Sprite3D = source_bridge.get("actor_sprite")
		check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "pixel nearest sampling retained")
		check(source_bridge.get("static_visual_frozen") and not source_bridge.is_processing(), "merged bridge freezes after refresh")
	check(not first.is_processing(), "merged static simulation stops processing")
	var far := mark(world, origin + Vector2(256, 0), room_id)
	var other_room := mark(world, origin + Vector2(4, 0), room_id + 100)
	var wall := mark(world, origin + Vector2(4, 0), room_id, false)
	await frames(8)
	check(is_instance_valid(far) and floor_marks(world).size() == 3, "distant and other-room marks remain separate")
	check(is_instance_valid(other_room), "room ownership prevents cross-room compaction")
	check(is_instance_valid(wall) and wall.ground_pixels.size() == 3, "wall effects are never floor-compacted")
	# Real wall collision must also block consolidation when ownership matches.
	var wall_pair: Array[Vector2] = []
	for cell_variant in world.floor_cells:
		var cell: Vector2i = cell_variant
		for step in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + step
			if not world.floor_cells.has(neighbor):
				continue
			var a := Vector2(cell) * 32.0
			var b := Vector2(neighbor) * 32.0
			if not world._is_blood_ground_allowed(a) or not world._is_blood_ground_allowed(b):
				continue
			var query := PhysicsRayQueryParameters2D.create(a, b, world.WORLD_WALL_LAYER)
			if not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				wall_pair.assign([a, b])
				break
		if not wall_pair.is_empty():
			break
	check(wall_pair.size() == 2, "real wall separator fixture exists")
	if wall_pair.size() == 2:
		var separated_a := mark(world, wall_pair[0], 9001)
		var separated_b := mark(world, wall_pair[1], 9001)
		check(not separated_a.can_absorb_ground_effect(separated_b), "wall blocks compaction despite matching room ownership")
		await frames(6)
		check(is_instance_valid(separated_a) and is_instance_valid(separated_b), "wall-separated authorities both survive")
	first.elapsed = first.lifetime_seconds + 100.0
	first._process(1.0)
	await frames(4)
	check(is_instance_valid(first) and not first.fade_started, "stains persist past former lifetime in current floor")
	var stale := mark(world, origin + Vector2(4, 4), room_id)
	stale.set_meta(&"blood_floor_token", -1)
	await frames(4)
	check(is_instance_valid(stale), "stale floor token cannot enter current merge registry")
	var preserved: Array[Vector2] = first.ground_pixels.duplicate()
	world._settled_blood_buckets.clear()
	first.set_meta(&"blood_floor_token", -2)
	world._rebuild_settled_blood_registry()
	await frames(8)
	check(first.get_meta(&"blood_floor_token") == world.get_current_floor_token(), "failed transition restore refreshes blood floor token")
	check(preserved.all(func(p: Vector2) -> bool: return first.ground_pixels.has(p)), "registry rebuild retains restored blood pixels")
	var restored_addition := mark(world, origin + Vector2(12, 0), room_id)
	var restored_ref: WeakRef = weakref(restored_addition)
	await frames(8)
	check(restored_ref.get_ref() == null and first.ground_pixels.has(Vector2(12, 0)), "restored settled blood can absorb new marks")
	var first_ref: WeakRef = weakref(first)
	check(world.regenerate(42002), "next floor generation")
	await frames(4)
	check(first_ref.get_ref() == null, "regeneration clears persistent old-floor stains")
	check(world._settled_blood_buckets.is_empty(), "regeneration clears weak merge registry")
	world.free()
	print("BLOOD_REVISION_INTEGRATION_CHECKS=", checks, " FAILURES=", failures.size())
	quit(1 if not failures.is_empty() else 0)
