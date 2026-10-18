extends SceneTree

const DUNGEON_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CELL_PIXELS := 32.0
const WALK_SEEDS := [41001, 41002, 41003, 41004, 41005]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for test_seed in WALK_SEEDS:
		var dungeon: Node3D = DUNGEON_SCENE.instantiate()
		dungeon.persist_profile = false
		dungeon.generate_on_ready = false
		# This test validates the generated topology and wall/door collision.  The
		# playable scene enables formal furniture/enemy content; disable it here so
		# incidental prop bodies do not turn a route check into a furniture test.
		dungeon.spawn_content = false
		get_root().add_child(dungeon)
		await physics_frame

		if not dungeon.regenerate(test_seed):
			failures.append("seed %d could not generate" % test_seed)
			dungeon.free()
			continue

		await physics_frame
		var player := dungeon.get_node("GameplayCanvas/GameplayWorld/DreamPlayer") as CharacterBody2D
		if dungeon.get_node_or_null("ForegroundOcclusionCanvas") != null:
			failures.append("seed %d still has the removed gray foreground occlusion layer" % test_seed)
		var depth_bridge := dungeon.get_node_or_null("PlayerDepthVisual3D")
		if depth_bridge == null or depth_bridge.get("actor_sprite") == null:
			failures.append("seed %d did not create the depth-tested 2D actor bridge" % test_seed)
		if bool(dungeon.get_node("GameplayCanvas").visible):
			failures.append("seed %d left the source Canvas actor visible alongside the depth bridge" % test_seed)
		if absf(float(dungeon.wall_height) - 3.0) > 0.001:
			failures.append("seed %d does not use the permanent 3x wall height" % test_seed)
		if float(dungeon.door_height) + 0.001 < float(dungeon.wall_height):
			failures.append("seed %d door does not fill the full tall-wall opening" % test_seed)
		if dungeon.get_node_or_null("PlayerPhysicsProxy3D/CollisionShape3D") == null:
			failures.append("seed %d is missing the PlayerPhysicsProxy3D collision proxy" % test_seed)
		player.set_physics_process(false)
		for wall in dungeon.get_node("GeneratedBuildingRoot/WallRoot").get_children():
			if bool(wall.get_meta("door_upper_segment", false)):
				failures.append("seed %d still generated a wall/lintel above a door" % test_seed)
				break
			if absf(float(wall.get("wall_height")) - float(dungeon.wall_height)) > 0.001:
				failures.append("seed %d wall height is not permanently tall" % test_seed)
				break
		for door in dungeon.get_node("GeneratedBuildingRoot/DoorRoot").get_children():
			if String(door.name).contains("Frame") or String(door.name).contains("DoorWall"):
				failures.append("seed %d still generated a legacy Door frame node" % test_seed)
			if door.get_node_or_null("HingeAnchor") == null or door.get_node_or_null("DoorLeaf") == null or door.get_node_or_null("HingeJoint3D") == null:
				failures.append("seed %d generated a Door without a physical hinge/leaf" % test_seed)
			if door.get_node_or_null("DoorLeaf/DoorVisual") == null:
				failures.append("seed %d generated a Door without a leaf visual" % test_seed)
			if door.has_method("set_gameplay_collision_enabled"):
				# Logical route validation traverses door edges; disable only this
				# test bridge after verifying the physical leaf was created.
				door.call("set_gameplay_collision_enabled", false)
		player.position = dungeon.get_player_root_position_for_cell(dungeon.spawn_cell)
		for _frame in range(4):
			await process_frame
		# The formal Player is placed just inside the external main entrance.
		# Start the route from that actual ground cell rather than assuming the
		# spawn room centre is the physical spawn point.
		var current_cell: Vector2i = dungeon.spawn_cell
		var visited_rooms := 0
		var seed_failed := false

		# Visiting every center exercises branches and loops, not only the direct
		# Spawn-to-Boss route.  The final leg always ends in the Boss room.
		var visit_order: Array[int] = []

		for room_id in range(dungeon.rooms.size()):
			if room_id != dungeon.spawn_room_id and room_id != dungeon.boss_room_id:
				visit_order.append(room_id)

		visit_order.append(dungeon.boss_room_id)

		for room_id in visit_order:
			var target_cell: Vector2i = dungeon.get_room_center_cell(room_id)
			var path: Array[Vector2i] = dungeon.find_floor_path(current_cell, target_cell)

			if path.is_empty():
				failures.append("seed %d room %d has no floor path" % [test_seed, room_id])
				seed_failed = true
				break

			for index in range(1, path.size()):
				var target_position: Vector2 = dungeon.get_player_root_position_for_cell(path[index])
				var motion := target_position - player.position
				var collision := player.move_and_collide(motion)

				if collision != null:
					failures.append(
						"seed %d blocked from %s to %s by %s"
						% [
							test_seed,
							path[index - 1],
							path[index],
							collision.get_collider(),
						]
					)
					seed_failed = true
					break

				player.position = target_position

			if seed_failed:
				break

			current_cell = target_cell
			visited_rooms += 1

		if not seed_failed:
			print(
				"WALK PASS seed=%d visited_rooms=%d final_boss=%d"
				% [test_seed, visited_rooms + 1, dungeon.boss_room_id]
			)

		dungeon.free()
		await physics_frame

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return

	print("PASS: formal DreamPlayer collision-walked every building room in %d seeds." % WALK_SEEDS.size())
	for _frame in 20:
		await physics_frame
		await process_frame
	quit(0)
