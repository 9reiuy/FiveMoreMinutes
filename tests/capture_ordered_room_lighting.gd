extends SceneTree
## Focused visual evidence: actual Main-owned final pass and normal Dream entry.
## Normal gameplay views plus explicitly labeled diagnostic overview/closeup views.
## Production materials and light parameters are retained during final captures.
## Run without --headless; images go to the user-supplied absolute output folder.
var output := ""
var app: Node
var world: Node
var caption: Label
var failures := 0
var saved_plans: Dictionary = {}
var static_counts: Array[int] = []

func _init() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func run() -> void:
	output = OS.get_environment("LIGHTING_CAPTURE_DIR")
	if output.is_empty():
		push_error("LIGHTING_CAPTURE_DIR must be an absolute output directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	seed(14092026)
	app = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	seed(7777)
	app.call("_show_dream", "basic")
	await frames(3)
	while app.get("transition_running"):
		await process_frame
	world = app.get("current_screen")
	if not is_instance_valid(world) or not world.has_method("_commit_room_transition"):
		push_error("Normal Main entry did not reach Random Dream")
		quit(1)
		return
	world.get("night_lighting").call("set_flashlight_enabled", false)
	static_counts = presentation_counts()
	# Progress through the real key pickup authority rather than bypassing the
	# boss-door guard, so the large lounge can be reached in this fixed sample.
	if await visit(int(world.get("key_room_id"))):
		var key: Node = world.get("key_pickup")
		if is_instance_valid(key):
			world.call("collect_boss_key", key)
			await frames(3)
	var layer := CanvasLayer.new()
	layer.layer = 101
	app.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 10)
	layer.add_child(caption)
	var targets: Dictionary = {}
	for room: Dictionary in world.get("rooms"):
		var archetype := String(room.get("archetype", ""))
		if archetype == "open_office":
			archetype = "office"
		print("ROOM_METADATA ", room.get("id"), " ", archetype, " center=", room.get("center_cell"))
		if archetype not in ["office", "conference", "storage", "lounge"]:
			continue
		var id := int(room["id"])
		var tier := String(room.get("size_class", "small"))
		print("ACTUAL_ROOM ", id, " ", archetype, " ", tier)
		var plans: Dictionary = world.get("ceiling_light_root").get("room_light_plans")
		var wall_count := 0
		for item: Dictionary in plans.get(id, []):
			if item["kind"] == &"wall": wall_count += 1
		print("PLANNED_WALLS ", id, " ", wall_count)
		if archetype == "lounge":
			var usable: Array = room.get("usable_cells", [])
			var full: Array[Vector2i] = []
			for cell: Vector2i in world.get("floor_cells"):
				if int(world.get("room_cells").get(cell,-1)) == id: full.append(cell)
			print("LOUNGE_BOUNDS ", id, " usable=", usable.size(), " full=", full.size(), " grid=", room.get("grid_rect"))
			var solid_adjacent := 0
			for key in world.get("wall_edges"):
				var edge: Dictionary = world.get("wall_edges")[key]
				var cell := Vector2i(edge["x"], edge["y"])
				var before := cell - (Vector2i.DOWN if edge["axis"] == "H" else Vector2i.RIGHT)
				if full.has(cell) == full.has(before): continue
				if world.get("window_wall_edges").has(key) or world.get("glass_wall_edges").has(key): continue
				solid_adjacent += 1
			print("LOUNGE_SOLID_ADJACENT ", id, " ", solid_adjacent)
		if not targets.has(archetype) or tier == "large":
			targets[archetype] = id
	print("CAPTURE_SEED ", world.get("seed"), " TARGETS ", targets)
	for archetype: String in ["office", "conference", "storage", "lounge"]:
		var only_archetype := OS.get_environment("LIGHTING_CAPTURE_ONLY")
		if not only_archetype.is_empty() and archetype != only_archetype:
			continue
		if not targets.has(archetype):
			print("MISSING_ARCHETYPE ", archetype)
			failures += 1
			continue
		var target := int(targets[archetype])
		if not await visit(target):
			failures += 1
			continue
		var room: Dictionary = world.get("rooms")[target]
		var player: Node2D = world.get("player")
		player.global_position = Vector2(room["center_cell"]) * float(world.get("CELL_PIXELS"))
		player.set("velocity", Vector2.ZERO)
		Input.warp_mouse(Vector2(DisplayServer.window_get_size()) * 0.5)
		world.call("_update_camera_and_actor_projection", 0.0)
		await frames(10)
		var manager: Node3D = world.get("ceiling_light_root")
		print("CURRENT_FOR_CAPTURE target=", target, " current=", world.get("current_room_id"), " visibility=", world.get("room_visibility").get("current_room_id"))
		for holder in manager.get_children():
			if int(holder.get_meta("dream_room_id", -1)) == target:
				print("FIXTURE_VISIBLE ", holder.name, " ", holder.visible, " ", holder.get_node_or_null("RoomLight"))
		var plan: Array = manager.get("room_light_plans").get(target, [])
		saved_plans[target] = plan.duplicate(true)
		var tops := 0
		var walls := 0
		for item: Dictionary in plan:
			if item["kind"] == &"wall": walls += 1
			else: tops += 1
		print("ACTUAL_FIXTURES room=", target, " archetype=", archetype, " ceilings=", tops, " walls=", walls, " plan=", plan)
		var previous_mode: int = world.process_mode
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.set("camera_aim_offset", Vector3.ZERO)
		world.call("_update_camera_and_actor_projection", 0.0)
		for enabled: bool in [true, false]:
			# Exercise Main's existing final material without changing saved preferences.
			app.call("_apply_palette_enabled", enabled)
			caption.text = "%s | ROOM %d | PALETTE %s | FLASHLIGHT OFF\nCEILING %d / WALL %d" % [archetype.to_upper(), target, "1" if enabled else "OFF", tops, walls]
			await frames(3)
			await RenderingServer.frame_post_draw
			var path := output.path_join("%s_palette_%s.png" % [archetype, "1" if enabled else "off"])
			root.get_texture().get_image().save_png(path)
			print("SCREENSHOT ", path)
		await capture_overview(room, archetype, tops, walls)
		if walls > 0:
			await capture_sconce_ab(manager, target, archetype)
		if walls > 0:
			await capture_sconce_detail(plan)
		world.process_mode = previous_mode
	# Leave and re-enter one recorded room through the production transition API.
	if not saved_plans.is_empty():
		var revisit := int(saved_plans.keys()[0])
		var neighbor := int(world.get("rooms")[revisit]["connections"][0])
		await visit(neighbor)
		if await visit(revisit):
			var manager: Node3D = world.get("ceiling_light_root")
			if saved_plans[revisit] != manager.get("room_light_plans").get(revisit, []):
				failures += 1
				push_error("Light positions changed on reentry")
			else:
				print("REENTRY_PLAN_IDENTICAL room=", revisit)
	print("CAPTURE_FAILURES=", failures)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	app.queue_free()
	await frames(5)
	quit(1 if failures else 0)

func visit(target: int) -> bool:
	var current := int(world.get("current_room_id"))
	var rooms: Array = world.get("rooms")
	var queue: Array[int] = [current]
	var parents: Dictionary = {current: -1}
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == target: break
		for neighbor in rooms[at].get("connections", []):
			var next := int(neighbor)
			if parents.has(next): continue
			var connection: Dictionary = world.call("_connection_between_rooms", at, next)
			if int(connection.get("door_id", -1)) == int(world.get("boss_door_id")) and world.call("is_boss_door_locked"):
				continue
			parents[next] = at
			queue.append(next)
	if not parents.has(target):
		print("UNREACHABLE_TARGET ", target)
		return false
	var path: Array[int] = []
	var cursor := target
	while cursor != current:
		path.push_front(cursor)
		cursor = int(parents[cursor])
	for next in path:
		var connection: Dictionary = world.call("_connection_between_rooms", current, next)
		if not world.call("_commit_room_transition", current, next, int(connection["id"])):
			print("TRANSITION_FAILED ", current, " -> ", next)
			return false
		await frames(3)
		if world.get("lazy_room_presentation") == false and presentation_counts() != static_counts:
			push_error("Static presentation accumulated during transition: %s -> %s" % [static_counts, presentation_counts()])
			failures += 1
		current = next
	return true

## Diagnostic framing only: retain the gameplay camera's perspective, FOV and
## orientation. Restore its transform before resuming; no production camera edits.
func capture_overview(room: Dictionary, archetype: String, tops: int, walls: int) -> void:
	var camera: Camera3D = world.get("camera_3d")
	var original := camera.global_transform
	var rect: Rect2i = room["grid_rect"]
	var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
	var focus := Vector3(center.x, 1.5, center.y)
	var distance := 12.0
	var corners: Array[Vector3] = []
	for x in [float(rect.position.x) - 0.5, float(rect.end.x) - 0.5]:
		for z in [float(rect.position.y) - 0.5, float(rect.end.y) - 0.5]:
			for y in [0.0, 3.5]: corners.append(Vector3(x,y,z))
	var safe := root.get_visible_rect().grow(-28.0)
	for attempt in range(30):
		camera.global_position = focus + camera.global_basis.z * distance
		var fits := true
		for corner in corners:
			if camera.is_position_behind(corner) or not safe.has_point(camera.unproject_position(corner)):
				fits = false
				break
		if fits: break
		distance *= 1.1
	for enabled: bool in [true, false]:
		app.call("_apply_palette_enabled", enabled)
		caption.text = "%s | INSPECTION OVERVIEW | PALETTE %s / FLASHLIGHT OFF\nCEILING %d / WALL %d | CAMERA PULLED BACK FOR INSPECTION ONLY" % [archetype.to_upper(), "1" if enabled else "OFF", tops, walls]
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("%s_overview_%s.png" % [archetype, "1" if enabled else "off"]))
	camera.global_transform = original

func capture_sconce_ab(manager: Node3D, room_id: int, archetype: String) -> void:
	var sconces: Array[SpotLight3D] = []
	for holder in manager.get_children():
		if int(holder.get_meta("dream_room_id", -1)) != room_id: continue
		var light := holder.get_node_or_null("WallLight") as SpotLight3D
		if light != null:
			sconces.append(light)
			print("SCONCE_RUNTIME visible=", light.is_visible_in_tree(), " position=", light.global_position, " forward=", -light.global_basis.z, " energy=", light.light_energy)
			if not light.shadow_enabled: failures += 1
	app.call("_apply_palette_enabled", false)
	caption.text = "WALL LIGHT A/B | PALETTE OFF | FROZEN SCENE"
	var camera: Camera3D = world.get("camera_3d")
	var original_transform := camera.global_transform
	var focus := Vector3.ZERO
	for light in sconces: focus += light.global_position
	focus /= float(maxi(1, sconces.size()))
	focus.y = 0.0
	# Measurement view only: a near wall otherwise hides the light's entire
	# floor footprint from the gameplay camera. Both sides are visible here.
	camera.global_position = focus + Vector3.UP * 9.0
	camera.look_at(focus, Vector3.FORWARD)
	var shots: Array[Image] = []
	for state: int in [0, 0, 1]:
		for light in sconces:
			light.visible = state > 0
		await frames(3)
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw(false)
		shots.append(root.get_texture().get_image())
	shots[0].save_png(output.path_join(archetype + "_wall_light_off.png"))
	shots[2].save_png(output.path_join(archetype + "_wall_light_on.png"))
	var scale_factor := Vector2(shots[0].get_size()) / root.get_visible_rect().size
	var owners: Dictionary = world.get("room_cells")
	var inside := 0
	var outside := 0
	var changed_inside := 0
	var changed_outside := 0
	var unstable := 0
	var max_inside := 0.0
	# Reject rays hidden by wall meshes rather than misclassifying a lit wall
	# face as the neighboring floor behind it.
	var blockers: Array[AABB] = []
	for mesh in world.get("wall_root").find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			blockers.append(mesh.global_transform * mesh.get_aabb())
	for y in range(100, shots[0].get_height() - 50, 4):
		for x in range(0, shots[0].get_width(), 4):
			var screen := Vector2(x, y) / scale_factor
			var origin := camera.project_ray_origin(screen)
			var ray := camera.project_ray_normal(screen)
			if ray.y >= -0.001: continue
			var hit := origin + ray * (-origin.y / ray.y)
			var nearby := false
			for light in sconces:
				if hit.distance_to(light.global_position) < light.spot_range:
					nearby = true
			if not nearby: continue
			var owner := int(owners.get(Vector2i(roundi(hit.x), roundi(hit.z)), -1))
			if owner < 0: continue
			var blocked := false
			for box in blockers:
				if box.intersects_segment(origin, hit) != null:
					blocked = true
					break
			if blocked: continue
			var a := shots[0].get_pixel(x,y)
			var control := shots[1].get_pixel(x,y)
			var b := shots[2].get_pixel(x,y)
			if color_delta(a, control) > 1.0/255.0:
				unstable += 1
				continue
			var changed := color_delta(a,b) > 2.0/255.0
			if owner == room_id:
				inside += 1
				max_inside = maxf(max_inside, color_delta(a,b))
				if changed: changed_inside += 1
			else:
				outside += 1
				if changed: changed_outside += 1
	print("SCONCE_AB owner=", room_id, " inside_samples=", inside, " inside_changed=", changed_inside,
		" other_room_samples=", outside, " other_room_changed=", changed_outside, " unstable=", unstable)
	print("SCONCE_MAX_RGB_DELTA=", max_inside)
	if changed_inside == 0 or changed_outside > 0 or outside < 20:
		print("SCONCE_AB_REQUIRES_REVIEW")
		failures += 1
	camera.global_transform = original_transform

func color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))


func presentation_counts() -> Array[int]:
	return [world.get("floor_root").get_child_count(), world.get("wall_root").get_child_count(),
		world.get("ceiling_light_root").get_child_count()]

func capture_sconce_detail(plan: Array) -> void:
	var item: Dictionary = {}
	for entry: Dictionary in plan:
		if entry["kind"] == &"wall":
			item = entry
			break
	var camera: Camera3D = world.get("camera_3d")
	var original := camera.global_transform
	var p: Vector3 = item["position"]
	var inward: Vector2 = item["inward"]
	camera.global_position = p + Vector3(inward.x * 2.2, 0.7, inward.y * 2.2)
	camera.look_at(p)
	for enabled: bool in [true, false]:
		app.call("_apply_palette_enabled", enabled)
		caption.text = "LOUNGE WALL LIGHT DETAIL | PALETTE %s / FLASHLIGHT OFF\nINSPECTION CAMERA ONLY / PRODUCTION LIGHT SETTINGS" % ["1" if enabled else "OFF"]
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("lounge_wall_detail_%s.png" % ["1" if enabled else "off"]))
	camera.global_transform = original
