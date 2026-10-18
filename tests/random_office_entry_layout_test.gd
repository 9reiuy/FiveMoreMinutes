extends SceneTree

const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	var failures := 0
	var checks := 0
	for seed in range(1, 51):
		world.regenerate(seed)
		for room in world.rooms:
			if room.archetype in ["corridor", "elevator_lobby"]:
				continue
			var plan: Dictionary = world.room_layout_plans.get(int(room.id), {})
			checks += 1
			if not bool(plan.get("success", false)):
				print("ENTRY FAIL seed=", seed, " room=", room.id, " kind=", room.archetype, " encounter=", world.room_encounters.get(room.id), " rejected=", plan.get("rejected_candidates"), " doors=", world._get_room_doors(room.id))
				failures += 1
				continue
			var actual := 0
			for furniture in world.furniture_root.get_children():
				if int(furniture.get_meta("dream_room_id", -1)) == int(room.id):
					actual += 1
			if actual != plan.furniture_placements.size():
				print("ENTRY SPAWN FAIL seed=", seed, " room=", room.id, " actual=", actual, " planned=", plan.furniture_placements.size())
				failures += 1
		print("ENTRY SEED ", seed, " checked")
		await process_frame
	world.queue_free()
	await process_frame
	print("RANDOM ENTRY rooms=", checks, " failures=", failures)
	quit(1 if failures else 0)
