extends SceneTree

const LIGHTING = preload("res://scripts/dream/dream_3d_ceiling_lighting.gd")

class WorldStub extends Node:
	var floor_cells: Dictionary = {}
	var room_cells: Dictionary = {}
	var wall_edges: Dictionary = {}
	var window_wall_edges: Dictionary = {}
	var glass_wall_edges: Dictionary = {}
	var door_edges: Dictionary = {}
	var door_opening_edges: Dictionary = {}
	var room_layout_plans: Dictionary = {}
	var rooms: Array = []
	var lazy_room_presentation := true
	var current_room_id := 0
	var wall_height := 3.0

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func make_world(size: Vector2i, archetype: String, tier: String) -> WorldStub:
	var world := WorldStub.new()
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			cells.append(cell)
			world.floor_cells[cell] = true
			world.room_cells[cell] = 0
	for x in range(size.x):
		for y in [0, size.y]:
			world.wall_edges["H:%d:%d" % [x, y]] = {"axis": "H", "x": x, "y": y}
	for y in range(size.y):
		for x in [0, size.x]:
			world.wall_edges["V:%d:%d" % [x, y]] = {"axis": "V", "x": x, "y": y}
	world.rooms = [{"id": 0, "size_class": tier, "archetype": archetype, "usable_cells": cells}]
	world.room_layout_plans[0] = {"functional_areas": [
		{"category": "conference_table", "center_cell": Vector2i(size.x / 2, size.y / 2)},
		{"category": "seating", "center_cell": Vector2i(2, size.y / 2)}
	]}
	root.add_child(world)
	return world

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var manager := LIGHTING.new()
	root.add_child(manager)
	for archetype: String in ["office", "conference", "storage", "lounge"]:
		for size: Vector2i in [Vector2i(12, 10), Vector2i(10, 12), Vector2i(20, 8)]:
			for tier: String in ["small", "medium", "large"]:
				var world := make_world(size, archetype, tier)
				manager.build_for_world(world)
				var plan: Array = manager.room_light_plans[0]
				var budget := 4 if tier == "large" else (2 if tier == "medium" else 1)
				check(plan.size() == budget, "Budget %s/%s/%s: %d" % [archetype, size, tier, plan.size()])
				var ceilings: Array[Dictionary] = []
				var sconces: Array[Dictionary] = []
				for item: Dictionary in plan:
					if item["kind"] == &"ceiling": ceilings.append(item)
					else: sconces.append(item)
				if archetype == "lounge":
					check(sconces.size() == budget / 2, "Lounge replacement budget")
				else:
					check(sconces.is_empty(), "Unexpected wall fixture")
				for item in ceilings:
					check(is_equal_approx(float(item["yaw"]), 0.0 if size.x >= size.y else PI * 0.5), "Axis mismatch")
				for item in sconces:
					check(is_equal_approx(item["position"].y, world.wall_height * 0.65), "Sconce height")
				if sconces.size() == 2:
					check(sconces[0]["position"].distance_to(sconces[1]["position"]) >= manager.WALL_PAIR_MIN_SPACING, "Sconce pair too crowded")
				if ceilings.size() == 4 and (archetype == "conference" or float(size.x) / size.y >= 1.8):
					var a: Vector3 = ceilings[1]["position"] - ceilings[0]["position"]
					var b: Vector3 = ceilings[2]["position"] - ceilings[1]["position"]
					var c: Vector3 = ceilings[3]["position"] - ceilings[2]["position"]
					check(a.is_equal_approx(b) and b.is_equal_approx(c), "Unequal row spacing")
				var before := plan.duplicate(true)
				manager.build_for_world(world)
				check(before == manager.room_light_plans[0], "Reentry placement changed")
				check(manager.get_child_count() == budget + 1, "Duplicate fixtures on rebuild")
				for holder in manager.get_children():
					var light := holder.get_node_or_null("WallLight") as SpotLight3D
					if light != null:
						check(light.shadow_enabled, "Sconce lacks wall shadows")
						check(is_equal_approx(light.light_energy, 0.25), "Sconce energy increased")
						var beam: Vector3 = -light.global_basis.z
						check(beam.y < 0.0 and -light.global_position.y / beam.y < light.spot_range, "Center beam misses local floor range")
						var inward: Vector2 = holder.get_meta("light_plan")["inward"]
						var facing: Vector3 = -holder.basis.z
						check(Vector2(facing.x, facing.z).dot(inward) > 0.99, "Sconce faces wrong room")
					var top := holder.get_node_or_null("RoomLight") as SpotLight3D
					if top != null:
						check(is_equal_approx(top.light_energy, 0.50), "Ceiling energy increased")
						check(top.spot_range < 28.0 and top.spot_angle < 90.0, "Whole-room legacy range leaked")
						check(not top.shadow_enabled, "Ceiling shadow regression")
					for mesh in holder.find_children("*", "MeshInstance3D", true, false):
						var mat: StandardMaterial3D = mesh.material_override
						check(is_equal_approx(mat.albedo_color.a, 1.0 if mat.emission_enabled else 0.30), "Incorrect housing/diffuser opacity")
				world.queue_free()
				await process_frame
		print("LAYOUT PASS ", archetype)
	# All wall segments are windows: lounge must fall back as an intact ceiling group.
	var glass_world := make_world(Vector2i(12, 10), "lounge", "large")
	glass_world.window_wall_edges = glass_world.wall_edges.duplicate(true)
	manager.build_for_world(glass_world)
	for item: Dictionary in manager.room_light_plans[0]:
		check(item["kind"] == &"ceiling", "Window-mounted sconce")
	check(manager.room_light_plans[0].size() == 4, "Fallback lost fixture budget")
	glass_world.queue_free()
	await process_frame
	# Mansion usable_cells excludes the perimeter; sconces still mount on the
	# actual architectural wall, and coverage includes the perimeter floor.
	var inset_world := make_world(Vector2i(14, 12), "lounge", "large")
	var inset: Array[Vector2i] = []
	for y in range(2, 10):
		for x in range(2, 12):
			inset.append(Vector2i(x, y))
	inset_world.rooms[0]["usable_cells"] = inset
	manager.build_for_world(inset_world)
	var inset_walls := 0
	for item: Dictionary in manager.room_light_plans[0]:
		if item["kind"] == &"wall": inset_walls += 1
	check(inset_walls == 2, "Furniture inset wrongly rejected architectural wall")
	inset_world.queue_free()
	await process_frame
	# A hole directly under a nominal light requires whole-group correction.
	var cut_world := make_world(Vector2i(12, 10), "office", "large")
	cut_world.floor_cells.erase(Vector2i(4, 3))
	cut_world.room_cells.erase(Vector2i(4, 3))
	var door_key := "H:6:0"
	cut_world.door_edges[door_key] = cut_world.wall_edges[door_key]
	manager.build_for_world(cut_world)
	var valid: Dictionary = cut_world.floor_cells
	for item: Dictionary in manager.room_light_plans[0]:
		var p: Vector3 = item["position"]
		var f: Vector2 = manager._fixture_size("office")
		check(manager._footprint_clear(Rect2(Vector2(p.x,p.z)-f*0.5,f),valid,manager._door_clearance_rects(cut_world),manager._solid_wall_segments(cut_world)), "Footprint overlaps hole/door/wall")
	cut_world.queue_free()
	manager.queue_free()
	await process_frame
	print("LIGHTING_LAYOUT_FAILURES=", failures)
	quit(1 if failures else 0)
