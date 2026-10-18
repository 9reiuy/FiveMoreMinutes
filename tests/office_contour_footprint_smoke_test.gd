extends SceneTree

const GENERATOR := preload("res://scripts/dream/dream_office_v2_generator.gd")

var failures := 0


func _initialize() -> void:
	for contour in ["rect", "l_shape", "t_shape", "cross", "convex"]:
		for seed_value in [42001, 1337, 7777, 99999, 24680]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var generated: Dictionary = GENERATOR.generate(rng, {"contour_type": contour, "floor_index": 1})
			var cells: Dictionary = generated.get("floor_cells", {})
			var room_cells: Dictionary = generated.get("room_cells", {})
			var elevator_id: int = int(generated.get("elevator_room_id", -1))
			if generated.is_empty() or cells.is_empty() or elevator_id < 0:
				failures += 1
				printerr("FAIL: contour %s seed %d failed to generate" % [contour, seed_value])
				continue
			var playable := 0
			var cab := 0
			for cell in cells.keys():
				if int(room_cells.get(cell, -1)) == elevator_id:
					cab += 1
				else:
					playable += 1
			if playable <= 0 or cab <= 0:
				failures += 1
				printerr("FAIL: contour %s seed %d missing playable/cab distinction" % [contour, seed_value])
	print("OFFICE CONTOUR FOOTPRINT 25 layouts; failures=", failures)
	quit(0 if failures == 0 else 1)
