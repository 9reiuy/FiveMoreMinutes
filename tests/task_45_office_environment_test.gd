extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OFFICE_V2 := preload("res://scripts/dream/dream_office_v2_generator.gd")
const MASK_SCRIPT := preload("res://scripts/dream/dream_3d_room_visibility.gd")

class MaskWorld extends Node3D:
	var building_rect := Rect2i()
	var floor_cells: Dictionary = {}
	func _cell_world_size() -> float:
		return 1.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	root.add_child(world)
	await process_frame
	_check(world.regenerate(42001), "office floor generates")
	await process_frame
	var camera_forward: Vector3 = world.camera_3d.global_basis.z
	_check(absf(camera_forward.x) < 0.0001 and camera_forward.z > 0.2, "camera horizontal yaw is zero")
	_check(absf(absf(world.global_basis.x.x) - absf(world.global_basis.x.z)) < 0.0001, "map root has 45-degree horizontal yaw")
	_check(absf(world.camera_3d.fov - 35.0) < 0.001, "FOV unchanged")
	var map_point := Vector2(192.0, -96.0)
	var physical_point: Vector3 = world.get_gameplay_world_position(map_point, 0.0)
	var mapped_back: Vector3 = world.to_local(physical_point)
	_check(Vector2(mapped_back.x, mapped_back.z).distance_to(map_point / world.CELL_PIXELS) < 0.001, "gameplay/world map rotation round-trips")
	world.player_physics_proxy._physics_process(0.0)
	var proxy_in_map: Vector3 = world.to_local(world.player_physics_proxy.global_position)
	_check(Vector2(proxy_in_map.x, proxy_in_map.z).distance_to(world.player.global_position / world.CELL_PIXELS) < 0.01, "player 3D contact proxy follows rotated gameplay map")

	var mask: MeshInstance3D = world.room_visibility.outside_black_gradient
	_check(mask != null, "outside-footprint mask exists")
	if mask != null:
		var material := mask.material_override as ShaderMaterial
		var texture := material.get_shader_parameter("footprint_distance") as ImageTexture
		var image := texture.get_image()
		var origin: Vector2 = material.get_shader_parameter("grid_origin")
		var floor_cell: Vector2i = world.floor_cells.keys()[0]
		var floor_xy := floor_cell - Vector2i(origin)
		_check(image.get_pixel(floor_xy.x, floor_xy.y).r < 0.001, "floor remains clear of black mask")
		_check(image.get_pixel(0, 0).r > 0.99, "outside corner is black")
		var x_axis: Vector2 = material.get_shader_parameter("map_x_axis")
		_check(x_axis.distance_to(Vector2(world.global_basis.x.x, world.global_basis.x.z)) < 0.001, "footprint mask samples the rotated map basis")
	var window_runs := 0
	var window_lights := 0
	for run_variant in world.window_wall_edges.values():
		var run_data: Dictionary = run_variant
		if bool(run_data.get("first", false)):
			window_runs += 1
		if bool(run_data.get("light", false)):
			window_lights += 1
	_check(window_runs > 0 and window_lights == window_runs, "one window light per contiguous glazed run")
	var joined_panes := 0
	var whole_pane_meshes := 0
	var built_runs := 0
	for wall in world.wall_root.get_children():
		var wall_key := String(wall.get_meta(&"edge_key", ""))
		if not world.window_wall_edges.has(wall_key):
			continue
		var run_data: Dictionary = world.window_wall_edges[wall_key]
		if bool(run_data.get("first", false)):
			built_runs += 1
		if int(run_data.get("pane_span", 0)) > 0:
			whole_pane_meshes += 1
			_check(wall.window_pane != null and absf(wall.window_pane.mesh.size.x - float(run_data["pane_span"])) < 0.001, "one glass mesh spans the full window run")
		else:
			_check(wall.window_pane == null, "internal window cells do not duplicate glass panes")
		if not bool(run_data.get("first", false)) and not bool(run_data.get("last", false)):
			_check(not wall.window_left_post and not wall.window_right_post, "interior panoramic window segment has no seam posts")
			joined_panes += 1
	_check(joined_panes > 0, "continuous panoramic glazing has interior segments")
	_check(whole_pane_meshes == built_runs and built_runs > 0, "each built panoramic run has exactly one glass mesh")
	var opening_frames := 0
	for child in world.floor_root.get_children():
		if child.name.begins_with("OfficeOpeningFrame"):
			opening_frames += 1
	_check(opening_frames == 0 and world.pillar_footprints.is_empty(), "authored open-office passages have no stray posts")

	var fixture_count := 0
	var dark_fixtures := 0
	for holder in world.ceiling_light_root.get_children():
		fixture_count += 1
		if not holder.visible:
			dark_fixtures += 1
		var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
		if spot != null and not spot.visible:
			dark_fixtures += 1
	_check(fixture_count > 0 and dark_fixtures == 0, "all room fixtures are lit before entry")
	var near_axes: Dictionary = {}
	for walls_variant in world.room_visibility.near_walls.values():
		for wall in walls_variant:
			var edge: Dictionary = wall.get_meta(&"edge", {})
			near_axes[String(edge.get("axis", ""))] = true
	_check(near_axes.has("H") and near_axes.has("V"), "both camera-facing wall axes are indexed for cutaway")

	var door_checked := false
	for child in world.door_root.get_children():
		if not child is PhysicalDoor3D:
			continue
		var door := child as PhysicalDoor3D
		if door.locked or door.is_destroyed:
			continue
		var anchor: StaticBody3D = door._anchors[0]
		var leaf: RigidBody3D = door._leaves[0]
		var point := anchor.global_position + leaf.global_basis.x * door.leaf_width * 0.4
		var direction := leaf.global_basis.z
		door.apply_door_impact(&"player_push", point, direction, 260.0, &"", 0)
		_check(door._combat_swing_left[0] == 0.0, "passive door push cannot attack")
		door.apply_door_impact(&"kick", point, direction, 260.0, &"", 0, 12345)
		_check(door._combat_swing_left[0] > 0.0 and door._combat_swing_instigator[0] == 12345, "explicit kick arms door, excluding initiator")
		door_checked = true
		break
	_check(door_checked, "a physical door was available for impact test")
	for child in world.door_root.get_children():
		if child is PhysicalDoor3D and not child._collision_bodies.is_empty():
			var map_leaf: Vector3 = world.to_local(child.left_leaf.global_position)
			var logical_leaf: Vector2 = Vector2(map_leaf.x, map_leaf.z) * world.CELL_PIXELS
			_check(logical_leaf.distance_to(child._collision_bodies[0].global_position) < 0.1, "rotated 3D door leaf matches its 2D collider")
			break
	var single_door_checked := false
	for child in world.door_root.get_children():
		if child is PhysicalDoor3D and child.door_style == &"single":
			child.set_architectural_cutaway(true, world.wall_height)
			_check(child.right_leaf.get_node_or_null("ArchitecturalCutSurface") == null, "single door has no second upper cut cap")
			single_door_checked = true
			break
	_check(single_door_checked, "a single door was available for cap test")
	var glass_checked := false
	for child in world.wall_root.get_children():
		if not child is BreakableGlassWindow3D:
			continue
		var glass := child as BreakableGlassWindow3D
		var edge_key := glass.edge_key
		glass.shatter()
		await process_frame
		_check(glass.collision_body_2d.collision_layer == 0, "broken interior glass is walk-through")
		_check(world.edge_states.get(edge_key) == &"OPEN", "broken glass opens its floor edge")
		glass_checked = true
		break
	_check(glass_checked, "a breakable interior window was available")
	for contour in ["rect", "l_shape", "t_shape", "cross", "convex"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42001
		var data: Dictionary = OFFICE_V2.generate(rng, {"contour_type": contour, "floor_index": 1})
		_check(not data.is_empty(), "%s contour generates" % contour)
		if data.is_empty():
			continue
		var fake := MaskWorld.new()
		fake.building_rect = data["building_rect"]
		fake.floor_cells = data["floor_cells"]
		root.add_child(fake)
		var mask_builder := MASK_SCRIPT.new()
		fake.add_child(mask_builder)
		mask_builder.set_process(false)
		mask_builder.world = fake
		mask_builder.cover_root = Node3D.new()
		fake.add_child(mask_builder.cover_root)
		mask_builder._build_outside_black_gradient()
		var contour_mask := mask_builder.outside_black_gradient as MeshInstance3D
		_check(contour_mask != null, "%s footprint mask builds" % contour)
		if contour_mask != null:
			var contour_material := contour_mask.material_override as ShaderMaterial
			var contour_image := (contour_material.get_shader_parameter("footprint_distance") as ImageTexture).get_image()
			var contour_origin := Vector2i(contour_material.get_shader_parameter("grid_origin"))
			var inner_gap_masked := false
			for y in range(fake.building_rect.position.y, fake.building_rect.end.y):
				for x in range(fake.building_rect.position.x, fake.building_rect.end.x):
					var cell := Vector2i(x, y)
					if fake.floor_cells.has(cell):
						continue
					var image_cell := cell - contour_origin
					if contour_image.get_pixel(image_cell.x, image_cell.y).r > 0.1:
						inner_gap_masked = true
						break
				if inner_gap_masked:
					break
			if contour != "rect":
				_check(inner_gap_masked, "%s missing corner is masked" % contour)
		fake.queue_free()

	world.queue_free()
	await process_frame
	print("TASK 45 OFFICE ENVIRONMENT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
