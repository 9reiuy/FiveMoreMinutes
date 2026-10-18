extends SceneTree

const DUNGEON_SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = DUNGEON_SCENE.instantiate()
	world.generate_on_ready = false
	root.add_child(world)
	world.regenerate(42001)
	for i in range(10):
		await process_frame

	print("Elevator room id: ", world.elevator_room_id)
	print("Spawn room id: ", world.spawn_room_id)
	print("Elevator anchor cell: ", world.elevator_anchor_cell)
	print("Elevator door pos 2d: ", world.elevator_door_pos_2d)
	print("Total rooms: ", world.rooms.size())
	for r in world.rooms:
		print("  Room ", r.id, " type: ", r.room_type, " arch: ", r.archetype, " rect: ", r.grid_rect)

	print("\nFurniture count: ", world.furniture_root.get_child_count())
	for f in world.furniture_root.get_children():
		var rid = f.get_meta("dream_room_id", -1)
		var fpos = f.global_position
		var cell = world._cell_for_gameplay_position(fpos)
		var dist_to_door = fpos.distance_to(world.elevator_door_pos_2d)
		if dist_to_door < 400.0:
			print("  Furniture ", f.name, " in room ", rid, " pos: ", fpos, " cell: ", cell, " dist_to_door: ", dist_to_door)

	quit()
