extends SceneTree

const SAMPLE = preload("res://scripts/dream/office_sample_floor.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DETAIL_KINDS := ["workstation", "table", "dining_table", "counter", "sink", "coffee_table", "cabinet", "cabinet_open", "whiteboard", "washbasin", "shelf", "server", "reception"]
var failures := 0

func check_chair_facing(key: String) -> void:
	var specs: Array = SAMPLE.furniture_specs(key)
	for chair in specs:
		if String(chair[0]) != "chair":
			continue
		var chair_point := Vector2(float(chair[1]), float(chair[2]))
		var theta := deg_to_rad(float(chair[3]))
		# chairDesk's seat fronts local +Z; Furniture3DVisual negates the 2D
		# rotation when placing it into X/Z world space.
		var facing := Vector2(-sin(theta), cos(theta))
		var closest := Vector2.ZERO
		var distance := INF
		for furniture in specs:
			var kind: String = String(furniture[0])
			if kind not in ["workstation", "table", "dining_table", "reception"]:
				continue
			var center := Vector2(float(furniture[1]), float(furniture[2]))
			var size: Vector3 = CATALOG.size_of(kind)
			var target := Vector2(
				clampf(chair_point.x, center.x - size.x * .5, center.x + size.x * .5),
				clampf(chair_point.y, center.y - size.z * .5, center.y + size.z * .5)
			)
			var d := chair_point.distance_squared_to(target)
			if d < distance:
				distance = d
				closest = target
		check(distance < INF and facing.dot((closest - chair_point).normalized()) >= .75, key + " chair faces its nearest work surface")

func has_clear_lane(room: Dictionary, placements: Array, width_cells: float, length_cells: float) -> bool:
	var room_rect: Rect2 = Rect2(room.grid_rect)
	var usable := room_rect.grow(-1.0)
	var occupied: Array[Rect2] = []
	for placement in placements:
		var rect: Rect2 = placement.collision_rect
		occupied.append(Rect2((placement.position + rect.position) / CATALOG.SCALE, rect.size / CATALOG.SCALE).grow(.18))
	for cell in room.usable_cells:
		var point := Vector2(cell)
		for vertical in [false, true]:
			var lane := Rect2(point - (Vector2(width_cells * .5, 0) if vertical else Vector2(0, width_cells * .5)), Vector2(width_cells, length_cells) if vertical else Vector2(length_cells, width_cells))
			if not usable.encloses(lane):
				continue
			var clear := true
			for obstacle in occupied:
				if lane.intersects(obstacle):
					clear = false
					break
			if clear:
				return true
	return false

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(120), "authored floor generated")
	for chair_room in ["office", "conference", "manager", "pantry", "reception"]:
		check_chair_facing(chair_room)
	for room in world.rooms:
		var key: String = String(room.get("sample_key", ""))
		if key not in SAMPLE.ART_REVIEW_ROOMS:
			continue
		var plan: Dictionary = world.room_layout_plans.get(int(room.id), {})
		if key == "lift":
			check(not bool(room.get("combat_room", true)) and SAMPLE.enemy_specs(key).is_empty(), "lift remains safe")
			world.player.global_position = Vector2(room.center_cell) * CATALOG.SCALE
			world.activate_room(int(room.id))
			for frame in 3:
				await process_frame
			var lift_decor := 0
			for node in world.floor_root.find_children("AuthoredOfficeDecorations_*", "MeshInstance3D", true, false):
				if int(node.get_meta(&"dream_room_id", -1)) == int(room.id):
					lift_decor += 1
			check(lift_decor == 1, "lift wayfinding belongs to active room")
			continue
		check(bool(plan.get("success", false)), key + " plan exists")
		var furniture: Array = plan.get("furniture_placements", [])
		var reservations: Array = plan.get("door_reservation_rects", [])
		check(furniture.size() == SAMPLE.furniture_specs(key).size(), key + " furniture count")
		var occupied := 0.0
		for placement in furniture:
			var rect: Rect2 = placement.collision_rect
			var footprint := Rect2(placement.position + rect.position, rect.size)
			occupied += footprint.get_area()
			for door_rect in reservations:
				if footprint.intersects(door_rect):
					print("DOOR OVERLAP ", key, " kind=", placement.office_kind, " footprint=", footprint, " door=", door_rect)
				check(not footprint.intersects(door_rect), key + " furniture clear of door")
		var total := float(room.grid_rect.size.x * room.grid_rect.size.y) * CATALOG.SCALE * CATALOG.SCALE
		check(occupied / total <= .40, key + " >=60% raw floor open")
		check(PLANNER.validate_room_walkability(room.usable_cells, furniture, world.call("_get_room_doors", int(room.id))), key + " walkable")
		check(has_clear_lane(room, furniture, 3.0, 5.25), key + " three-cell-wide full dash lane")
		var specs: Array = SAMPLE.decoration_specs(key)
		check(float(specs.size()) / float(room.grid_rect.size.x * room.grid_rect.size.y) <= .08, key + " decorative area <=8%")
		var origin := Vector2(room.grid_rect.position) * CATALOG.SCALE
		for spec in specs:
			var position := origin + Vector2(spec[1], spec[2]) * CATALOG.SCALE
			for door_rect in reservations:
				if door_rect.has_point(position):
					print("DECOR OVERLAP ", key, " position=", position / CATALOG.SCALE, " door=", door_rect.position / CATALOG.SCALE)
				check(not door_rect.has_point(position), key + " floor decoration clear of doorway")
		world.player.global_position = Vector2(room.center_cell) * CATALOG.SCALE
		world.activate_room(int(room.id))
		for frame in 3:
			await process_frame
		var detail_count := 0
		var expected_details := 0
		for spec in SAMPLE.furniture_specs(key):
			if String(spec[0]) in DETAIL_KINDS:
				expected_details += 1
		for node in world.find_children("*", "Furniture3DVisual", true, false):
			var adapter := node as Furniture3DVisual
			if adapter.target_furniture == null or int(adapter.target_furniture.get_meta(&"dream_room_id", -1)) != int(room.id):
				continue
			if adapter.visual_instance != null and adapter.visual_instance.get_node_or_null("OfficeDetailAttachments") != null:
				detail_count += 1
		check(detail_count == expected_details, key + " furniture-specific pixel art")
		var room_decor := 0
		for node in world.floor_root.find_children("AuthoredOfficeDecorations_*", "MeshInstance3D", true, false):
			if int(node.get_meta(&"dream_room_id", -1)) == int(room.id):
				room_decor += 1
		check(room_decor == 1, key + " room-specific floor details")
		print("ART REVIEW ", key, " furniture=", furniture.size(), " decor=", specs.size(), " occupied=", snappedf(occupied / total, .001), " details=", detail_count)
	check(world.regenerate(121), "new floor regenerated")
	await process_frame
	var decor_count := world.find_children("AuthoredOfficeDecorations_*", "MeshInstance3D", true, false).size()
	print("ART REVIEW regenerated decorations=", decor_count)
	check(decor_count == SAMPLE.ART_REVIEW_ROOMS.size(), "one decoration batch per room after regeneration")
	world.queue_free()
	await process_frame
	print("ART REVIEW failures=", failures)
	quit(1 if failures > 0 else 0)
