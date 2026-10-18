extends SceneTree

const GENERATOR = preload("res://scripts/dream/office_level_pack_generator.gd")
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")
var failures := 0
var rooms_checked := 0

func _initialize() -> void:
	for shape in GENERATOR.SHAPES:
		for seed in [120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 1732026325]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var layout: Dictionary = GENERATOR.generate_shape(rng, shape)
			for room in layout.rooms:
				if room.archetype in ["corridor", "elevator_lobby"]:
					continue
				var doors: Array = []
				for connection in layout.connections:
					if connection.a == room.id:
						doors.append(connection.door_a)
					elif connection.b == room.id:
						doors.append(connection.door_b)
				var rect: Rect2i = room.grid_rect
				var bounds := Rect2((Vector2(rect.position) - Vector2.ONE * .5) * 32, Vector2(rect.size) * 32).grow(-18)
				var plan: Dictionary = PLANNER.plan_room_layout(room.id, room, doors, [], 8, 6, 2, seed, bounds)
				rooms_checked += 1
				if not plan.success:
					print("FAILED ", shape, " seed=", seed, " ", room.archetype, " ", plan.rejected_candidates)
					failures += 1
					continue
				var kinds: Array = []
				if plan.enemy_spawns.size() != 6:
					failures += 1
				if plan.drop_spawns.size() != 2:
					print("DROPS MISSING ", room.archetype)
					failures += 1
				var repeated: Dictionary = PLANNER.plan_room_layout(room.id, room, doors, [], 8, 6, 2, seed, bounds)
				if plan != repeated:
					print("NONDETERMINISTIC ", room.archetype)
					failures += 1
				for item in plan.furniture_placements:
					kinds.append(item.office_kind)
					if (room.archetype in ["archive", "storage", "server"] and item.office_kind in ["cabinet", "shelf", "server"]) or (room.archetype == "pantry" and item.office_kind in ["fridge", "sink", "appliance_counter"]) or (room.archetype in ["conference", "conference_large", "meeting_small"] and item.office_kind in ["whiteboard", "cabinet"]):
						var front := Vector2.DOWN.rotated(float(item.rotation))
						if front.dot((bounds.get_center() - Vector2(item.position)).normalized()) <= .5:
							print("FIXTURE FACES OUT ", room.archetype, " ", item.office_kind)
							failures += 1
					if item.office_kind == "chair":
						var front := Vector2.DOWN.rotated(float(item.rotation))
						var targets: Array = plan.furniture_placements.filter(func(prop: Dictionary): return prop.office_kind in ["workstation", "table", "dining_table", "reception"])
						var aligned := false
						for target in targets:
							var target_rect: Rect2 = target.collision_rect
							target_rect.position += Vector2(target.position)
							if target_rect.has_point(Vector2(item.position) + front * 32):
								aligned = true
						if not aligned:
							print("CHAIR MISALIGNED ", room.archetype, " ", item.position)
							failures += 1
				if room.archetype == "lounge" and kinds.count("coffee_table") != 1:
					failures += 1
				if room.archetype in ["conference_large", "conference", "meeting_small"] and kinds.count("chair") != 6:
					failures += 1
				if room.archetype == "restroom" and (kinds.count("stall_door") != 2 or kinds.count("toilet") != 2):
					failures += 1
	print("RANDOM FUNCTIONAL LAYOUT rooms=", rooms_checked, " failures=", failures)
	quit(1 if failures else 0)
