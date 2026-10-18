extends SceneTree

const PACK = preload("res://scripts/dream/office_level_pack_generator.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var seeds := {}
	for seed in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var layout: Dictionary = PACK.generate(rng)
		if not seeds.has(layout.floor_shape):
			seeds[layout.floor_shape] = seed
		if seeds.size() == 5:
			break
	for shape in PACK.SHAPES:
		var world = WORLD.instantiate()
		world.generate_on_ready = false
		world.persist_profile = false
		world.enable_game_start_cab_exit = false
		root.add_child(world)
		verify(world.regenerate(int(seeds[shape])), "formal generation " + shape)
		verify(world.floor_shape == shape, "formal silhouette " + shape)
		verify(world.elevator_floor_door != null, "formal elevator " + shape)
		for room in world.rooms:
			verify(not bool(room.get("authored_sample", false)), "random identity")
			verify(String(room.get("office_visual_style", "")).begins_with("approved_"), "approved room style")
			if room.archetype in ["corridor", "elevator_lobby"]:
				continue
			var plan: Dictionary = world.room_layout_plans.get(int(room.id), {})
			verify(bool(plan.get("success", false)), "%s room %d plan" % [shape, room.id])
			var actual := 0
			for furniture in world.furniture_root.get_children():
				if int(furniture.get_meta("dream_room_id", -1)) == int(room.id):
					actual += 1
					verify(String(furniture.get_meta("office_visual_style", "")).begins_with("approved_"), "actual approved furniture")
			verify(actual == plan.get("furniture_placements", []).size(), "%s room %d spawn completeness actual=%d planned=%d" % [shape, room.id, actual, plan.get("furniture_placements", []).size()])
			var encounter: Dictionary = world.room_encounters.get(int(room.id), {})
			verify(int(encounter.get("resolved_enemy_count", 0)) == int(encounter.get("planned_enemy_count", 0)), "%s room %d enemy budget preserved" % [shape, room.id])
		world.queue_free()
		await process_frame
	print("RANDOM FORMAL checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
