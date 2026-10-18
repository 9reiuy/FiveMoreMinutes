extends SceneTree
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/dream/preview/OfficeFlankPreview.tscn").instantiate()
	world.generate_on_ready = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	var checked := 0
	for value in range(50):
		if not world.generate_layout_only(value):
			failures += 1
			print("FLANK layout failure ", value)
			continue
		for room in world.rooms:
			if String(room.archetype) == "corridor":
				continue
			checked += 1
			var plan: Dictionary = world._plan_otxo_room_layout(int(room.id))
			if not bool(plan.get("success", false)) or plan.get("furniture_placements", []).is_empty():
				failures += 1
				print("FLANK furniture failure seed=", value, " role=", room.archetype, " reason=", plan.get("failure_reason", ""))
			elif not PLANNER._office_wide_routes(room.shape_cells, plan.furniture_placements, world._get_room_doors(int(room.id)), 32):
				failures += 1
				print("FLANK route failure seed=", value, " role=", room.archetype)
	print("FLANK LAYOUT seeds=50 rooms=", checked, " failures=", failures)
	world.queue_free()
	for frame in 3:
		await process_frame
	quit(1 if failures else 0)
