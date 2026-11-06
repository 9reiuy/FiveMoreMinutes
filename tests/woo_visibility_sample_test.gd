extends SceneTree
## Native-GPU acceptance of the independent player's wall visibility sample.
## Only this sample is instantiated. Never changes campaign data or production files.
const SCENE := "res://scenes/preview/hellkind_purple_sample.tscn"
const OUT := "res://.runtime/hellkind_purple_sample_20261103/revision_woo_polygon/validation"
const BREACH = preload("res://scripts/dream/shared_wall_breach.gd")
const ORANGE := Color(0.8509804, 0.4196078, 0.0941176)
var lab
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var evidence: Dictionary = {}
var _done := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("WOO_CHECK ", label, " ", ok)
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for i in count: await process_frame

func physics_ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func picture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return lab.display.world_viewport.get_texture().get_image()

func save_picture(name: String, image: Image) -> void:
	var path := OUT.path_join(name + ".png")
	check(image.save_png(path) == OK, "Actual main-Camera capture " + name)
	captures.append(path)

func capture(name: String) -> Image:
	var image: Image = await picture()
	save_picture(name, image)
	return image

func hide_ui() -> void:
	lab.panel.hide()
	lab.hud.hide()
	lab.sample_ui.hide()
	var monitor := root.get_node_or_null("PerformanceMonitor")
	if monitor is CanvasLayer: monitor.hide()

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func is_orange(color: Color) -> bool:
	return absf(color.r - ORANGE.r) < 0.035 and absf(color.g - ORANGE.g) < 0.035 and absf(color.b - ORANGE.b) < 0.035

func orange_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if is_orange(image.get_pixel(x, y)): count += 1
	return count

func differences(a: Image, b: Image) -> Dictionary:
	if a.get_size() != b.get_size(): return {"changed": -1, "new_black": -1}
	var changed := 0
	var new_black := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.04: changed += 1
			if maxf(cb.r, maxf(cb.g, cb.b)) < 0.025 and maxf(ca.r, maxf(ca.g, ca.b)) > 0.10: new_black += 1
	return {"changed": changed, "new_black": new_black}

## This oracle independently queries the live Physics2D world. It never samples
## the visibility field's distance texture or calls its private ray implementation.
func physics_hit(from: Vector2, to: Vector2, transparent_glass: bool = true) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, int(lab.world.get_vision_occluder_collision_mask()))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = true
	var excluded: Array[RID] = []
	if lab.world.player is CollisionObject2D: excluded.append(lab.world.player.get_rid())
	for iteration in 32:
		query.exclude = excluded
		var hit: Dictionary = lab.world.player.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return {}
		var collider: Object = hit.get("collider")
		if transparent_glass and collider is Node and (collider.is_in_group(&"glass_windows") or collider.is_in_group(&"breakable_glass_windows")):
			excluded.append(hit.rid)
			continue
		return hit
	return {"position": from, "exhausted": true}

func floor_valid(point: Vector2) -> bool:
	return bool(lab.world._is_blood_ground_allowed(point))

func gameplay_snapshot() -> Dictionary:
	var actors: Dictionary = {}
	var all: Array = lab.world.enemy_root.get_children()
	all.append(lab.world.player)
	for actor in all:
		if actor is CollisionObject2D:
			actors[str(actor.get_instance_id())] = [actor.process_mode, actor.is_processing(), actor.is_physics_processing(), actor.collision_layer, actor.collision_mask, actor.visible, actor.get("dead")]
	var collisions: Dictionary = {}
	for node in lab.world.collision_root.get_children():
		if node is CollisionObject2D: collisions[str(node.get_instance_id())] = [node.collision_layer, node.collision_mask]
	return {"actors": actors, "collisions": collisions, "player_position": lab.world.player.global_position}

func viewport_ids() -> Array[int]:
	var result: Array[int] = []
	for node in lab.find_children("*", "SubViewport", true, false): result.append(node.get_instance_id())
	result.sort()
	return result

func check_native_path(label: String) -> void:
	check(lab.display.world_viewport.size == Vector2i(640, 360), label + " keeps the whole world at 640x360")
	check(lab.style_index == 3 and absf(lab.world.camera_3d.fov - lab.camera_zoom_fov) < 0.02, label + " retains the calibrated main Camera")
	check(lab.world.player_depth_bridge.actor_sprite.no_depth_test == false, label + " retains original actor depth testing")
	var unexpected: Array[String] = []
	for node in lab.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if (script != null and script.resource_path.ends_with("hellkind_actor_resolution.gd")) or node.name in [&"ActorColor640", &"ActorWhite640", &"ActorBlack640", &"PurpleActorComposite", &"UnlitActorMaskCarriers"]:
			unexpected.append(str(node.get_path()))
	check(unexpected.is_empty(), label + " adds no actor render/composite layer")

func projected_body_height() -> float:
	var bridge = lab.world.player_depth_bridge
	var image: Image = bridge.render_viewport.get_texture().get_image()
	var bounds: Rect2i = image.get_used_rect()
	if not bounds.has_area(): return 0.0
	var half_size := Vector2(image.get_size()) * 0.5
	var lo := INF
	var hi := -INF
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			var local: Vector3 = Vector3(float(x) - half_size.x, half_size.y - float(y), 0) * bridge.actor_sprite.pixel_size
			var screen: Vector2 = lab.world.camera_3d.unproject_position(bridge.actor_sprite.to_global(local))
			lo = minf(lo, screen.y)
			hi = maxf(hi, screen.y)
	return hi - lo

func move_player(point: Vector2) -> void:
	lab.world.player.global_position = point
	lab.world.player.velocity = Vector2.ZERO
	lab.world._clear_camera_shake()
	lab.world._update_camera_and_actor_projection(0.0)
	await physics_ticks(3)
	lab.update_visibility()
	await frames(3)

## PROCESS_MODE_DISABLED removes descendant CollisionObject2D bodies from the
## physics space. Pause only motion callbacks so frozen screenshots still have
## the exact live wall/door collision geometry used by the visibility field.
func pause_motion_callbacks() -> Dictionary:
	var state := {"world_process": lab.world.is_processing(), "world_physics": lab.world.is_physics_processing(),
		"player_process": lab.world.player.is_processing(), "player_physics": lab.world.player.is_physics_processing()}
	lab.world.set_process(false)
	lab.world.set_physics_process(false)
	lab.world.player.set_process(false)
	lab.world.player.set_physics_process(false)
	return state

func restore_motion_callbacks(state: Dictionary) -> void:
	lab.world.set_process(bool(state.world_process))
	lab.world.set_physics_process(bool(state.world_physics))
	lab.world.player.set_process(bool(state.player_process))
	lab.world.player.set_physics_process(bool(state.player_physics))

func count_physical_blocking_rays() -> int:
	var origin: Vector2 = lab.world.player.global_position
	var blocked := 0
	for i in 24:
		var target: Vector2 = origin + Vector2.from_angle(TAU * float(i) / 24.0) * float(lab.visibility_field.range_pixels)
		if not physics_hit(origin, target).is_empty(): blocked += 1
	return blocked

func choose_wall() -> Dictionary:
	var keys: Array = lab.world.wall_edges.keys()
	var start: Vector2 = lab.world.player.global_position
	var diagnostics := {"edges": keys.size(), "breachable": 0, "two_floor_sides": 0, "camera_facing": 0, "legal_standing_points": 0, "expected_wall_hit": 0}
	var camera_direction: Vector3 = lab.world.global_basis.inverse() * lab.world.camera_3d.global_basis.z
	var toward_camera := Vector2(camera_direction.x, camera_direction.z).normalized()
	keys.sort_custom(func(a, b): return lab.world._edge_gameplay_position(lab.world.wall_edges[a]).distance_squared_to(start) < lab.world._edge_gameplay_position(lab.world.wall_edges[b]).distance_squared_to(start))
	for key in keys:
		if BREACH.wall_for_key(lab.world, str(key)) == null: continue
		diagnostics.breachable += 1
		var edge: Dictionary = lab.world.wall_edges[key]
		var sides: Array = lab.world._edge_side_cells(edge)
		if sides.size() != 2 or not lab.world.floor_cells.has(sides[0]) or not lab.world.floor_cells.has(sides[1]): continue
		diagnostics.two_floor_sides += 1
		var body: StaticBody2D = lab.world.collision_root.get_node_or_null("WallCollision_" + str(key).replace(":", "_")) as StaticBody2D
		if body == null: continue
		# Use the actual live collider center, not the rendered wall profile or
		# the 3D map's rotated/translated scene coordinates.
		var center: Vector2 = body.global_position
		var normal := Vector2.DOWN if str(edge.axis) == "H" else Vector2.RIGHT
		var signs: Array = [1.0, -1.0] if normal.dot(toward_camera) >= 0.0 else [-1.0, 1.0]
		for sign_value in signs:
			var direction: Vector2 = normal * sign_value
			# Prefer looking across the room's near-Camera wall: its existing
			# architectural cut exposes a far-side blood patch in the OFF picture.
			if direction.dot(toward_camera) < 0.25: continue
			diagnostics.camera_facing += 1
			var origin := center - direction * 48.0
			var target := center + direction * 48.0
			if not floor_valid(origin) or not floor_valid(target): continue
			diagnostics.legal_standing_points += 1
			var hit := physics_hit(origin, target)
			if hit.is_empty() or not hit.get("collider") is Node: continue
			if str(hit.collider.get_meta(&"generated_wall_edge", "")) != str(key): continue
			diagnostics.expected_wall_hit += 1
			evidence["wall_selection"] = diagnostics
			return {"key": str(key), "center": center, "direction": direction, "origin": origin, "near": center - direction * 20.0, "far": target}
	evidence["wall_selection"] = diagnostics
	return {}

func check_field_oracle(label: String) -> void:
	lab.update_visibility()
	var origin: Vector2 = lab.visibility_field.origin_pixels
	var total := 0
	var mismatches := 0
	var blocked := 0
	var clear := 0
	for i in 32:
		var direction := Vector2.from_angle((float(i) + 0.31) * TAU / 32.0)
		for distance in [48.0, 112.0, 224.0]:
			if distance + 16.0 >= float(lab.visibility_field.range_pixels): continue
			var target: Vector2 = origin + direction * distance
			var hit := physics_hit(origin, target + direction * 12.0)
			var hit_distance: float = origin.distance_to(hit.position) if not hit.is_empty() else INF
			if absf(hit_distance - distance) < 5.0: continue # Do not score an angular/edge tolerance as a room leak.
			var expected: bool = hit_distance > distance
			var actual: bool = lab.visibility_field.is_point_visible(target, 0.0)
			total += 1
			if expected: clear += 1
			else: blocked += 1
			if expected != actual: mismatches += 1
	evidence[label + "_oracle"] = {"points": total, "clear": clear, "blocked": blocked, "mismatches": mismatches}
	check(total >= 48 and clear > 0 and blocked > 0, label + " independently samples both clear and blocked Physics2D rays")
	check(mismatches == 0, label + " visibility agrees with live wall/door collision away from edge tolerance")
	var image: Image = lab.visibility_field.texture.get_image()
	var raster_samples := 0
	var raster_mismatches := 0
	var raster_rows: Array[Dictionary] = []
	for i in 32:
		var direction := Vector2.from_angle((float(i) + 0.31) * TAU / 32.0)
		for distance in [48.0, 112.0, 224.0]:
			var target: Vector2 = origin + direction * distance
			var hit := physics_hit(origin, target + direction * 12.0)
			var hit_distance: float = origin.distance_to(hit.position) if not hit.is_empty() else INF
			if absf(hit_distance - distance) < 6.0: continue
			# A caster is deliberately not covered by its own shadow. Test empty
			# floor beyond/around it, rather than the interior of a solid collider.
			if not physics_hit(target, target + direction * 0.1).is_empty(): continue
			var expected: bool = hit_distance > distance
			var actual := mask_visible(image, target)
			raster_samples += 1
			if expected != actual:
				raster_mismatches += 1
				raster_rows.append({"point": target, "expected": expected, "actual": actual})
	evidence[label + "_polygon_mask"] = {"samples": raster_samples, "mismatches": raster_mismatches, "rows": raster_rows}
	check(raster_samples >= 48 and raster_mismatches == 0, label + " actual GPU silhouette mask independently agrees with wall/door physics on empty floor")

func mask_visible(image: Image, point: Vector2) -> bool:
	var bounds: Rect2 = lab.visibility_field.mask_rect
	var uv := (point - bounds.position) / bounds.size
	if uv.x < 0.0 or uv.x >= 1.0 or uv.y < 0.0 or uv.y >= 1.0: return false
	var pixel := Vector2i(int(uv.x * image.get_width()), int(uv.y * image.get_height()))
	return image.get_pixelv(pixel).r > 0.5

func frozen_toggle_comparison() -> void:
	var motion_state := pause_motion_callbacks()
	await physics_ticks(2)
	var blocked_rays := count_physical_blocking_rays()
	evidence["frozen_physics_blocking_rays"] = blocked_rays
	check(blocked_rays > 0, "Frozen same-pose comparison retains real wall/door bodies in Physics2D")
	var snapshot := gameplay_snapshot()
	var camera_transform: Transform3D = lab.world.camera_3d.global_transform
	var original_viewports := viewport_ids()
	lab.set_vision_enabled(false)
	lab.update_visibility()
	await frames(3)
	var off: Image = await capture("00_same_pose_visibility_off")
	lab.set_vision_enabled(true)
	lab.update_visibility()
	await frames(3)
	var on: Image = await capture("01_same_pose_visibility_on")
	var delta := differences(off, on)
	evidence["fixed_camera_off_on"] = delta
	check(delta.changed > 500 and delta.new_black > 200, "Wall visibility changes actual pixels to black in the main Camera")
	check_visible_wall_patch(off, on)
	check_visible_door_patch(off, on)
	check(gameplay_snapshot() == snapshot, "Visibility does not change player position, enemy AI modes, source visibility or collision layers")
	check(lab.world.camera_3d.global_transform == camera_transform, "Off/on comparison keeps exactly the same main Camera transform")
	check(viewport_ids() == original_viewports, "Visibility toggle does not create a render viewport")
	check(lab.world.player_depth_bridge.actor_sprite.is_visible_in_tree(), "Player's original body remains visible")
	lab.set_vision_enabled(false)
	lab.update_visibility()
	await frames(3)
	var restored: Image = await picture()
	var restored_delta := differences(off, restored)
	evidence["fixed_camera_off_restore"] = restored_delta
	check(restored_delta.changed < 2304, "Disabling visibility restores the frozen picture within 1 percent animation tolerance")
	lab.set_vision_enabled(true)
	restore_motion_callbacks(motion_state)
	await physics_ticks(2)
	await frames(3)

## Regression for a 0.25-unit visible wall inside a 0.5-unit physics blocker.
## Select only a real uncut, window-free WallSegment3D face, with the player
## and main Camera on that same face's outward side. Selection uses OFF pixels
## only, so a wrongly black ON image cannot steer us toward a passing patch.
func check_visible_wall_patch(off: Image, on: Image) -> void:
	var camera: Camera3D = lab.world.camera_3d
	var player_ground: Vector3 = lab.world.to_global(Vector3(lab.world.player.global_position.x / 32.0, 0.0, lab.world.player.global_position.y / 32.0))
	var best: Dictionary = {}
	var best_score := -INF
	for wall in lab.world.wall_root.get_children():
		var script: Script = wall.get_script()
		if script == null or not script.resource_path.ends_with("/wall_segment_3d.gd"): continue
		if wall.get("window_variant") == true or wall.get("cutaway_mode") == true: continue
		var mesh: MeshInstance3D = wall.get("wall_mesh") as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.mesh.get_aabb()
		if bounds.size.y < 1.0: continue
		for side in [-1.0, 1.0]:
			var normal: Vector3 = (mesh.global_basis * Vector3(0.0, 0.0, side)).normalized()
			var local_center: Vector3 = bounds.position + bounds.size * 0.5
			local_center.z = bounds.end.z if side > 0.0 else bounds.position.z
			var point: Vector3 = mesh.to_global(local_center)
			if camera.is_position_behind(point): continue
			if normal.dot(camera.global_position - point) <= 0.25 or normal.dot(player_ground - point) <= 0.25: continue
			# Test the empty space just outside this face, beyond its known wider
			# physical slab. Another intervening wall must reject the candidate.
			var outside: Vector3 = lab.world.to_local(point + normal * 0.35)
			if not physics_hit(lab.world.player.global_position, Vector2(outside.x, outside.z) * 32.0).is_empty(): continue
			var screen: Vector2 = camera.unproject_position(point)
			var patch := Rect2i(Vector2i(screen.floor()) - Vector2i(2, 2), Vector2i(5, 5))
			if not Rect2i(Vector2i.ZERO, off.get_size()).encloses(patch): continue
			var bright := 0
			for y in range(patch.position.y, patch.end.y):
				for x in range(patch.position.x, patch.end.x):
					var color := off.get_pixel(x, y)
					if maxf(color.r, maxf(color.g, color.b)) > 0.14: bright += 1
			if bright < 12: continue
			var score: float = float(bright) - player_ground.distance_to(point) * 0.01
			if score > best_score:
				best_score = score
				best = {"wall": str(wall.get_path()), "face_side": side, "world_center": point, "screen_center": screen, "patch": patch, "off_bright_pixels": bright, "visible_mesh_depth": bounds.size.z}
	check(not best.is_empty(), "Find a lit real wall face visible to both player and main Camera for the thin-wall regression")
	if best.is_empty():
		evidence["visible_wall_face_patch"] = {"found": false}
		return
	var patch: Rect2i = best.patch
	var retained := 0
	for y in range(patch.position.y, patch.end.y):
		for x in range(patch.position.x, patch.end.x):
			var before := off.get_pixel(x, y)
			var after := on.get_pixel(x, y)
			var before_brightness := maxf(before.r, maxf(before.g, before.b))
			if before_brightness <= 0.14: continue
			if maxf(after.r, maxf(after.g, after.b)) >= maxf(0.07, before_brightness * 0.35): retained += 1
	best["on_retained_bright_pixels"] = retained
	best["retained_fraction"] = float(retained) / float(best.off_bright_pixels)
	evidence["visible_wall_face_patch"] = best
	check(float(best.retained_fraction) >= 0.60, "Visible wall face retains at least 60 percent of its original lit pixels instead of turning black")

## Keep the actual opaque DoorVisual mesh, excluding its ReviewPixelGlass child.
## SurfaceTool frames can be non-indexed; ARRAY_INDEX is legitimately null.
func door_mesh_triangles(visual: MeshInstance3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for surface in visual.mesh.get_surface_count():
		if visual.mesh is ArrayMesh and (visual.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays: Array = visual.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array: normals = arrays[Mesh.ARRAY_NORMAL]
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for offset in range(0, count - 2, 3):
			var ia: int = indices[offset] if not indices.is_empty() else offset
			var ib: int = indices[offset + 1] if not indices.is_empty() else offset + 1
			var ic: int = indices[offset + 2] if not indices.is_empty() else offset + 2
			var a := visual.to_global(vertices[ia])
			var b := visual.to_global(vertices[ib])
			var c := visual.to_global(vertices[ic])
			var normal: Vector3 = (b - a).cross(c - a).normalized()
			if normals.size() == vertices.size():
				normal = (visual.global_basis.inverse().transposed() * (normals[ia] + normals[ib] + normals[ic])).normalized()
			if normal.length_squared() < 0.5: continue
			result.append({"a": a, "b": b, "c": c, "normal": normal, "surface": surface, "triangle": int(offset / 3)})
	return result

func door_pixel_triangle_hit(camera: Camera3D, pixel: Vector2, triangles: Array[Dictionary]) -> Dictionary:
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	var nearest: Dictionary = {}
	var distance := INF
	for triangle in triangles:
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, triangle.a, triangle.b, triangle.c)
		if not hit is Vector3: continue
		var hit_distance := origin.distance_squared_to(hit)
		if hit_distance >= distance: continue
		distance = hit_distance
		nearest = {"point": hit, "normal": triangle.normal, "surface": triangle.surface, "triangle": triangle.triangle}
	return nearest

## Choose a real triangle on the opaque leaf/frame, then independently ray-test
## every scored native pixel. Glass-door AABB centers are holes, not surfaces.
## A 15x15 search region accommodates 1-2px-wide frames without counting any
## glass/background pixels. The >=12 bright samples and >=60% retention remain.
func check_visible_door_patch(off: Image, on: Image) -> void:
	var camera: Camera3D = lab.world.camera_3d
	var player_ground: Vector3 = lab.world.to_global(Vector3(lab.world.player.global_position.x / 32.0, 0.0, lab.world.player.global_position.y / 32.0))
	var best: Dictionary = {}
	var best_score := -INF
	for door in lab.world.door_root.get_children():
		var script: Script = door.get_script()
		if script == null or not script.resource_path.ends_with("/physical_door_3d.gd") or door.get("is_destroyed") == true: continue
		var visuals: Array = door.get("_visuals")
		for leaf_index in visuals.size():
			var mesh: MeshInstance3D = visuals[leaf_index] as MeshInstance3D
			if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
			var triangles := door_mesh_triangles(mesh)
			for triangle in triangles:
				var normal: Vector3 = triangle.normal
				var point: Vector3 = (triangle.a + triangle.b + triangle.c) / 3.0
				if camera.is_position_behind(point): continue
				if normal.dot(camera.global_position - point) <= 0.25 or normal.dot(player_ground - point) <= 0.25: continue
				var outside: Vector3 = lab.world.to_local(point + normal * (float(door.wall_thickness) * 0.5 + 0.15))
				if not physics_hit(lab.world.player.global_position, Vector2(outside.x, outside.z) * 32.0).is_empty(): continue
				var screen: Vector2 = camera.unproject_position(point)
				var patch := Rect2i(Vector2i(screen.floor()) - Vector2i(7, 7), Vector2i(15, 15))
				if not Rect2i(Vector2i.ZERO, off.get_size()).encloses(patch): continue
				var bright_pixels: Array[Vector2i] = []
				var geometry_pixels := 0
				for y in range(patch.position.y, patch.end.y):
					for x in range(patch.position.x, patch.end.x):
						var hit := door_pixel_triangle_hit(camera, Vector2(x + 0.5, y + 0.5), triangles)
						if hit.is_empty(): continue
						var hit_normal: Vector3 = hit.normal
						var hit_point: Vector3 = hit.point
						if hit_normal.dot(camera.global_position - hit_point) <= 0.001 or hit_normal.dot(player_ground - hit_point) <= 0.001: continue
						geometry_pixels += 1
						var color := off.get_pixel(x, y)
						if maxf(color.r, maxf(color.g, color.b)) > 0.14: bright_pixels.append(Vector2i(x, y))
				if bright_pixels.size() < 12: continue
				var score: float = float(bright_pixels.size()) - player_ground.distance_to(point) * 0.01
				if score > best_score:
					best_score = score
					best = {"door": str(door.get_path()), "leaf": leaf_index, "visual": str(mesh.get_path()), "normal": normal,
						"world_center": point, "screen_center": screen, "patch": patch, "off_bright_pixels": bright_pixels.size(), "door_angle": door.get_open_angle(),
						"opaque_triangle_count": triangles.size(), "triangle_hit_pixels": geometry_pixels, "scored_pixels": bright_pixels,
						"source_surface": triangle.surface, "source_triangle": triangle.triangle}
	check(not best.is_empty(), "Find a lit real door leaf face visible to both player and main Camera")
	if best.is_empty():
		evidence["visible_door_face_patch"] = {"found": false}
		return
	var retained := 0
	for pixel: Vector2i in best.scored_pixels:
		var before := off.get_pixelv(pixel)
		var after := on.get_pixelv(pixel)
		var before_brightness := maxf(before.r, maxf(before.g, before.b))
		if maxf(after.r, maxf(after.g, after.b)) >= maxf(0.07, before_brightness * 0.35): retained += 1
	best["on_retained_bright_pixels"] = retained
	best["retained_fraction"] = float(retained) / float(best.off_bright_pixels)
	evidence["visible_door_face_patch"] = best
	check(float(best.retained_fraction) >= 0.60, "Visible door leaf retains at least 60 percent of its original lit pixels instead of self-occluding black")

func check_enemy_bridge(wall: Dictionary) -> void:
	var candidate
	for bridge in lab.world.actor_depth_bridges_root.get_children():
		var actor = bridge.get("source_actor")
		if is_instance_valid(actor) and lab.world.enemy_root.is_ancestor_of(actor) and not bool(actor.get("dead")) and bridge.get("character_projection") == true:
			candidate = bridge
			break
	check(is_instance_valid(candidate), "An existing enemy bridge is available for wall concealment")
	if not is_instance_valid(candidate): return
	var actor = candidate.source_actor
	var old_position: Vector2 = actor.global_position
	actor.global_position = wall.far
	candidate._process(0.0)
	await frames(3)
	var snapshot := gameplay_snapshot()
	lab.set_vision_enabled(false)
	lab.update_visibility()
	await frames(2)
	check(candidate.actor_sprite.is_visible_in_tree(), "Existing wall-side enemy body is restored when visibility is disabled")
	lab.set_vision_enabled(true)
	lab.update_visibility()
	await frames(2)
	check(not candidate.visible and not candidate.actor_sprite.is_visible_in_tree(), "Wall-hidden enemy uses its original bridge root visibility gate")
	if is_instance_valid(candidate.weapon_sprite): check(not candidate.weapon_sprite.is_visible_in_tree(), "Wall-hidden held weapon cannot leak above the wall")
	if is_instance_valid(candidate.volume_shadow): check(not candidate.volume_shadow.is_visible_in_tree(), "Wall-hidden actor volume shadow is also concealed")
	if is_instance_valid(candidate.character_local_light): check(not candidate.character_local_light.is_visible_in_tree(), "Wall-hidden actor local light is also concealed")
	check(gameplay_snapshot() == snapshot, "Concealing enemy bridge leaves its AI and 2D collisions intact")
	check(candidate.process_mode == Node.PROCESS_MODE_DISABLED and candidate.render_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden enemy pauses only its original presentation and capture viewport")
	actor.global_position = lab.world.player.global_position + Vector2(12, 0)
	lab.update_visibility()
	check(candidate.visible and candidate.process_mode != Node.PROCESS_MODE_DISABLED, "Revealing an enemy resumes its existing presentation immediately")
	var current_origin: Vector3 = candidate._character_colour_origin(lab.world.camera_3d, candidate._source_fake_height_pixels())
	check(candidate.actor_sprite.global_position.distance_to(current_origin) < 0.01, "Revealed enemy synchronizes its current pose rather than retaining the hidden position")
	lab.set_vision_enabled(false)
	check(candidate.process_mode != Node.PROCESS_MODE_DISABLED, "Disabling visibility restores the native presentation process mode")
	lab.set_vision_enabled(true)
	actor.global_position = old_position
	candidate._process(0.0)
	lab.update_visibility()

func check_native_sprite_pool(wall: Dictionary) -> void:
	var manager: Node = lab.world.floor_root.get_node_or_null("FootstepSmoke")
	check(manager != null and manager.get_child_count() > 0, "Original native footstep pool is present")
	if manager == null or manager.get_child_count() == 0: return
	var sprite := manager.get_child(0) as Sprite3D
	var old_transform := sprite.global_transform
	var old_visible := sprite.visible
	var old_layers: int = lab.primitive_visibility._records[sprite.get_instance_id()].base_layers
	sprite.global_position = lab.world.get_gameplay_world_position(wall.far, 0.12)
	sprite.visible = true
	lab.update_visibility()
	check(sprite.visible and sprite.layers == 0, "Concealing a native puff preserves its live pool flag and only removes render layers")
	sprite.global_position = lab.world.get_gameplay_world_position(lab.world.player.global_position, 0.12)
	lab.update_visibility()
	check(sprite.visible and sprite.layers == old_layers, "Visible native puff resumes its original render layers without reallocating its pool slot")
	sprite.global_position = lab.world.get_gameplay_world_position(wall.far, 0.12)
	lab.update_visibility()
	lab.set_vision_enabled(false)
	check(sprite.visible and sprite.layers == old_layers, "Disabling visibility restores the native puff layers and leaves its lifetime owner intact")
	sprite.global_transform = old_transform
	sprite.visible = old_visible
	lab.set_vision_enabled(true)

func check_furniture_visibility(wall: Dictionary) -> void:
	lab.set_vision_enabled(false)
	var carrier: Node3D
	for child in lab.world.actor_depth_bridges_root.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == "res://scripts/dream/furniture_3d_visual.gd" and is_instance_valid(child.source_actor) and child.source_actor.visible:
			carrier = child
			break
	check(carrier != null, "A native furniture carrier is available for wall concealment")
	if carrier == null:
		lab.set_vision_enabled(true)
		return
	var source: RigidBody2D = carrier.source_actor
	var old_transform := source.global_transform
	var old_freeze := source.freeze
	var state := [source.visible, source.collision_layer, source.collision_mask, source.process_mode]
	source.freeze = true
	source.global_position = wall.far
	carrier._sync_transform()
	var masked := false
	for mesh: MeshInstance3D in carrier.find_children("*", "MeshInstance3D", true, false):
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as ShaderMaterial
			if material != null and material.shader.code.contains("woo_polygon_material_variant"): masked = true
	check(masked, "Furniture shader surfaces receive the shared mask while original actor captures remain protected")
	lab.set_vision_enabled(true)
	lab.update_visibility()
	check(not carrier.visible, "Wall-hidden native furniture is culled as a whole object")
	check(state == [source.visible, source.collision_layer, source.collision_mask, source.process_mode], "Concealing furniture leaves its source visibility, collisions and processing intact")
	lab.set_vision_enabled(false)
	check(carrier.visible, "Disabling vision restores the same native furniture carrier")
	source.global_transform = old_transform
	source.freeze = old_freeze
	carrier._sync_transform()
	lab.set_vision_enabled(true)

func check_empty_caster_raster() -> void:
	var field = lab.visibility_field
	var before: Image = field.texture.get_image()
	var black := Vector2i(-1, -1)
	for y in range(0, before.get_height(), 16):
		for x in range(0, before.get_width(), 16):
			if before.get_pixel(x, y).r < 0.1: black = Vector2i(x, y); break
		if black.x >= 0: break
	check(black.x >= 0, "Nonempty caster raster contains a real black sample before empty-set cleanup")
	field._static_polygons.clear()
	field._doors.clear()
	field.caster_count = 0
	field._build_shadows()
	field.mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var empty: Image = field.texture.get_image()
	check(field.shadow_triangles == 0 and black.x >= 0 and empty.get_pixelv(black).r > 0.9, "Removing the last caster erases its preceding GPU shadow")
	field._static_dirty = true
	lab.update_visibility()
	check(field.caster_count > 0 and field.shadow_triangles > 0, "Restoring topology rebuilds the original caster raster")

func check_smoke_edge_cache() -> void:
	var smoke: Node3D = lab.world.floor_root.get_node(^"FireExtinguisherSystem")
	smoke.validate_edges = true
	smoke.refresh_doors()
	for cell: Vector2i in lab.world.floor_cells:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			smoke.can_cross(cell, cell + direction)
			smoke.can_cross(cell, cell + direction)
	check(smoke.validated_edges > 1000 and smoke.edge_mismatches == 0, "Smoke edge decisions match the original rule across the actual floor")
	lab.trigger("smoke")
	await physics_ticks(30)
	check(not smoke.sources.is_empty() and smoke.cache_hits > 0 and smoke.edge_mismatches == 0, "Actual smoke coverage and fusion keep native edge decisions while active")
	smoke.invalidate_topology()
	check(smoke._edge_results.is_empty(), "Native topology invalidation clears the smoke edge cache immediately")
	smoke.validate_edges = false

func ground_at_pixel(pixel: Vector2) -> Vector2:
	var camera: Camera3D = lab.world.camera_3d
	var ray_origin := camera.project_ray_origin(pixel)
	var ray_direction := camera.project_ray_normal(pixel)
	var floor_plane := Plane(lab.world.global_basis.y.normalized(), lab.world.global_position)
	var point: Variant = floor_plane.intersects_ray(ray_origin, ray_direction)
	if not point is Vector3: return Vector2(INF, INF)
	var local: Vector3 = lab.world.to_local(point)
	return Vector2(local.x, local.z) * 32.0

func check_blood(wall: Dictionary) -> void:
	lab.set_vision_enabled(true)
	lab.update_visibility()
	var before_visible: Image = await picture()
	var visible_point: Vector2 = wall.origin - wall.direction * 20.0
	if not floor_valid(visible_point): visible_point = wall.origin
	lab.world.spawn_death_blood_pool(visible_point, -1, 4.0, false, Vector2.ZERO)
	await physics_ticks(100)
	var visible: Image = await capture("02_visible_orange_blood")
	var before_count := orange_count(before_visible)
	var visible_count := orange_count(visible)
	evidence["orange_visible"] = {"before": before_count, "after": visible_count, "point": visible_point}
	check(visible_count >= before_count + 4, "Visible actual blood retains orange #D96B18")
	lab.set_vision_enabled(false)
	await frames(3)
	var before_hidden: Image = await picture()
	lab.world.spawn_death_blood_pool(wall.far, -1, 4.0, false, Vector2.ZERO)
	await physics_ticks(100)
	var motion_state := pause_motion_callbacks()
	await physics_ticks(2)
	check(count_physical_blocking_rays() > 0, "Frozen blood comparison retains live wall blockers")
	var off: Image = await capture("03_hidden_blood_visibility_off")
	lab.set_vision_enabled(true)
	lab.update_visibility()
	await frames(3)
	var on: Image = await capture("04_hidden_blood_visibility_on")
	var hidden_pixels := 0
	var orange_leaks := 0
	var nonblack_leaks := 0
	for y in off.get_height():
		for x in off.get_width():
			if not is_orange(off.get_pixel(x, y)) or is_orange(before_hidden.get_pixel(x, y)): continue
			var point := ground_at_pixel(Vector2(x + 0.5, y + 0.5))
			if not point.is_finite() or point.distance_to(wall.far) > 52.0: continue
			var hit := physics_hit(wall.origin, point)
			if hit.is_empty() or wall.origin.distance_to(point) - wall.origin.distance_to(hit.position) < 12.0: continue
			hidden_pixels += 1
			var color := on.get_pixel(x, y)
			if is_orange(color): orange_leaks += 1
			if maxf(color.r, maxf(color.g, color.b)) > 0.04: nonblack_leaks += 1
	evidence["orange_hidden"] = {"independently_blocked_new_blood_pixels": hidden_pixels, "orange_leaks": orange_leaks, "nonblack_leaks": nonblack_leaks}
	check(hidden_pixels >= 4, "Off image exposes real new orange blood behind a Physics2D wall for a meaningful leak test")
	check(hidden_pixels >= 4 and orange_leaks == 0 and nonblack_leaks <= 2, "Wall-hidden orange blood pixels are covered rather than recolored or leaked")
	restore_motion_callbacks(motion_state)
	await physics_ticks(2)

func choose_door() -> Dictionary:
	for door in lab.world.door_root.get_children():
		if not door.has_method("prepare_enemy_passage") or door.is_destroyed or door.is_locked(): continue
		if float(door.get_open_angle()) > deg_to_rad(5.0): continue
		if door._collision_bodies.is_empty(): continue
		var body: StaticBody2D = door._collision_bodies[0]
		var center: Vector2 = door.get_leaf_center_2d(0)
		var normal := Vector2.from_angle(body.global_rotation + PI * 0.5)
		for side in [1.0, -1.0]:
			var origin: Vector2 = center - normal * side * 64.0
			var target: Vector2 = center + normal * side * 64.0
			if not floor_valid(origin) or not floor_valid(target): continue
			var hit := physics_hit(origin, target)
			if not hit.is_empty() and hit.get("collider") is Node and int(hit.collider.get_meta(&"physical_door_instance_id", 0)) == door.get_instance_id():
				return {"door": door, "origin": origin, "target": target}
	return {}

func check_door() -> void:
	var record := choose_door()
	check(not record.is_empty(), "Find an existing closed physical door with floor on both sides")
	if record.is_empty(): return
	var door = record.door
	await move_player(record.origin)
	check(not lab.visibility_field.is_point_visible(record.target, 0.0), "Closed real door blocks the player's view")
	var original_bodies: Array[int] = []
	var initial_transforms: Array[Transform2D] = []
	for body in door._collision_bodies:
		original_bodies.append(body.get_instance_id())
		initial_transforms.append(body.global_transform)
	var samples: Array[Dictionary] = []
	var mismatches := 0
	var opened := false
	for i in 300:
		door.prepare_enemy_passage(record.origin)
		await physics_ticks(1)
		if i % 6 != 0: continue
		lab.update_visibility()
		var expected := physics_hit(record.origin, record.target).is_empty()
		var actual: bool = lab.visibility_field.is_point_visible(record.target, 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var raster_clear := mask_visible(lab.visibility_field.texture.get_image(), record.target)
		if raster_clear != expected: mismatches += 1
		samples.append({"tick": i, "angle": rad_to_deg(door.get_open_angle()), "physics_clear": expected, "field_clear": actual, "gpu_mask_clear": raster_clear})
		if expected != actual: mismatches += 1
		if expected and actual and float(door.get_open_angle()) > deg_to_rad(30.0):
			opened = true
			break
	check(opened, "The original passage API physically swings a door open and reveals the point behind it")
	check(mismatches <= 1, "Moving-door field follows independently queried leaf collision (one edge sample tolerance)")
	var moved := false
	for i in door._collision_bodies.size():
		var body: StaticBody2D = door._collision_bodies[i]
		check(body.get_instance_id() == original_bodies[i] and (body.collision_layer & 4) != 0, "Door leaf %d remains the same active solid during opening" % i)
		if not body.global_transform.is_equal_approx(initial_transforms[i]): moved = true
	check(moved, "Door collision geometry actually changes transform rather than being disabled")
	await capture("05_real_door_open")
	var closed := false
	for i in 600:
		await physics_ticks(1)
		if i % 6 != 0: continue
		lab.update_visibility()
		if float(door.get_open_angle()) < deg_to_rad(8.0) and not physics_hit(record.origin, record.target).is_empty() and not lab.visibility_field.is_point_visible(record.target, 0.0):
			closed = true
			break
	check(closed, "The same live door returns closed and conceals the point again")
	evidence["door_motion"] = {"samples": samples, "opened": opened, "closed": closed, "mismatches": mismatches}

func check_glass() -> void:
	var record: Dictionary = {}
	for body in lab.world.collision_root.get_children():
		if not body is StaticBody2D or not (body.is_in_group(&"glass_windows") or body.is_in_group(&"breakable_glass_windows")): continue
		var shape: CollisionShape2D = body.get_child(0) as CollisionShape2D if body.get_child_count() > 0 else null
		if shape == null or not shape.shape is RectangleShape2D: continue
		var size: Vector2 = shape.shape.size
		var normal := Vector2.RIGHT if size.x < size.y else Vector2.DOWN
		normal = normal.rotated(body.global_rotation)
		var a: Vector2 = body.global_position - normal * 24.0
		var b: Vector2 = body.global_position + normal * 24.0
		if not floor_valid(a) or not floor_valid(b): continue
		var solid := physics_hit(a, b, false)
		if solid.get("collider") != body or not physics_hit(a, b, true).is_empty(): continue
		record = {"origin": a, "target": b, "body": body}
		break
	check(not record.is_empty(), "Find actual intact transparent glass with a clear route beyond it")
	if record.is_empty(): return
	await move_player(record.origin)
	check(lab.visibility_field.is_point_visible(record.target, 0.0), "Intact glass transmits sight while its original movement collision remains active")
	check((record.body.collision_layer & 4) != 0, "Transparent glass sight test keeps the physical pane intact")

func check_breach(wall: Dictionary) -> void:
	await move_player(wall.origin)
	check(not lab.visibility_field.is_point_visible(wall.far, 0.0), "Original wall still conceals the point before breach")
	var wall_node = BREACH.wall_for_key(lab.world, wall.key)
	var wall_id: int = wall_node.get_instance_id() if is_instance_valid(wall_node) else 0
	var removed: int = lab.world._commit_dash_wall_breaches([wall.key], lab.world.get_current_floor_token(), wall.direction)
	await physics_ticks(3)
	lab.update_visibility()
	check(removed == 1 and not is_instance_id_valid(wall_id), "Authoritative shared-wall commit removes the real wall")
	check(lab.world.edge_states.get(wall.key) == &"OPEN" and not lab.world.wall_edges.has(wall.key), "Breach changes the authoritative topology to OPEN")
	check(physics_hit(wall.origin, wall.far).is_empty(), "Independent Physics2D ray sees the actual new opening")
	check(lab.visibility_field.is_point_visible(wall.far, 0.0), "Visibility refresh immediately reveals the physically breached opening")
	await process_frame
	await RenderingServer.frame_post_draw
	check(mask_visible(lab.visibility_field.texture.get_image(), wall.far), "GPU silhouette mask reveals the authoritative breach on its next drawn frame")
	await capture("06_after_real_wall_breach")

func report_and_quit(code: int) -> void:
	if _done: return
	_done = true
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	await create_timer(0.25, true, false, true).timeout
	var result := {"checks": checks, "failures": failures, "captures": captures, "evidence": evidence,
		"gpu": RenderingServer.get_video_adapter_name(), "native_camera": DisplayServer.get_name() != "headless",
		"scope": "Standalone wall-visibility sample only: native 640 main Camera, original approximately 32px actor path, independent Physics2D oracle, same-pose off/on pixels, intact glass, real moving door and authoritative wall destruction, actual orange blood, enemy presentation-only concealment, movement/F2/F9/rebuild/exit. Frozen world only for paired image comparison. No performance or whole-game acceptance claim."}
	var file := FileAccess.open(OUT.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("WOO_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(code)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT.path_join("walk"))
	create_timer(300.0, true, false, true).timeout.connect(func():
		if not _done:
			check(false, "Wall-visibility validation timeout")
			report_and_quit(2))
	check(DisplayServer.get_name() != "headless", "Native GPU renderer is required")
	if DisplayServer.get_name() == "headless":
		report_and_quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	AudioServer.set_bus_mute(0, true)
	lab = load(SCENE).instantiate()
	root.add_child(lab)
	while not lab.sample_ready or lab.busy: await process_frame
	lab.apply_style(3)
	lab.toggle_lamps()
	await frames(40)
	hide_ui()
	var monitor: Node = root.get_node_or_null(^"PerformanceMonitor")
	check(monitor != null and not monitor.is_processing(), "Unused native GPU profiler is dormant during ordinary sample play")
	await press_key(KEY_F3)
	await frames(2)
	check(monitor.is_processing() and monitor.current_mode != 0, "Real F3 wakes the complete original native performance monitor")
	monitor.current_mode = 0
	monitor._update_display_mode()
	await frames(2)
	check(lab.vision_enabled and is_instance_valid(lab.visibility_field), "Player wall visibility is enabled by default")
	check(not lab.world.persist_profile, "Independent sample never persists campaign state")
	check_native_path("Initial sample")
	var body_height := projected_body_height()
	evidence["native_body_height"] = body_height
	check(body_height >= 30.0 and body_height <= 34.0, "Original player body remains approximately 32 native pixels high")
	lab.update_visibility()
	var field_image: Image = lab.visibility_field.texture.get_image()
	evidence["field"] = {"range_pixels": lab.visibility_field.range_pixels, "ray_count": lab.visibility_field.ray_count, "image_size": field_image.get_size(), "format": field_image.get_format()}
	check(lab.visibility_field.ray_count == 0 and field_image.get_size() == lab.visibility_field.mask_viewport.size and field_image.get_height() > 1 and lab.visibility_field.shadow_triangles > 0, "Visibility uses a real 2D silhouette raster and zero dense angular physics rays")
	check(lab.visibility_field.origin_pixels.distance_to(lab.world.player.global_position) < 1.0, "Visibility origin follows the authoritative player position")
	check(not lab.world.lab_cutout, "Sample suppresses Camera holes that could reveal wall-hidden actors")
	await frozen_toggle_comparison()
	await press_key(KEY_F9)
	check(not lab.vision_enabled, "Real F9 key disables the sample's wall visibility")
	await press_key(KEY_F9)
	check(lab.vision_enabled, "Real F9 key enables the sample's wall visibility again")
	hide_ui()
	var original_player_process: int = lab.world.player.process_mode
	lab.world.player.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_ticks(2)
	var wall := choose_wall()
	check(not wall.is_empty(), "Find a real generated masonry wall with valid floor on both sides")
	if not wall.is_empty():
		evidence["wall_probe"] = wall
		await move_player(wall.origin)
		check(physics_hit(wall.origin, wall.near).is_empty() and not physics_hit(wall.origin, wall.far).is_empty(), "Independent physics establishes clear near and blocked far sides of the wall")
		check(lab.visibility_field.is_point_visible(wall.near, 0.0), "Player can see the near side of the real wall")
		check(not lab.visibility_field.is_point_visible(wall.far, 0.0), "Player cannot see the far side of the real wall")
		check_field_oracle("Wall station")
		await check_enemy_bridge(wall)
		check_native_sprite_pool(wall)
		check_furniture_visibility(wall)
		await check_blood(wall)
	await check_glass()
	await check_door()
	await check_empty_caster_raster()
	if not wall.is_empty(): await check_breach(wall)
	lab.world.player.process_mode = original_player_process
	lab.teleport(3)
	await frames(8)
	var walk_start: Vector2 = lab.world.player.global_position
	var max_walk := 0.0
	for i in 12:
		var direction := "move_right" if i < 6 else "move_down"
		if i == 6: Input.action_release("move_right")
		Input.action_press(direction)
		await physics_ticks(4)
		max_walk = maxf(max_walk, lab.world.player.global_position.distance_to(walk_start))
		lab.update_visibility()
		var image: Image = await picture()
		check(image.save_png(OUT.path_join("walk/%03d.png" % i)) == OK, "Live main-Camera visibility movement frame %02d" % i)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(max_walk > 4.0, "Recorded visibility frames include real input-driven player movement")
	evidence["movement_distance"] = max_walk
	for i in 4:
		var previous: int = lab.station.selected
		await press_key(KEY_F2)
		await frames(5)
		check(lab.station.selected != previous, "Real F2 changes station %d" % i)
		lab.update_visibility()
		check(lab.visibility_field.origin_pixels.distance_to(lab.world.player.global_position) < 1.0, "Visibility origin follows F2 station %d" % i)
		check_native_path("F2 station %d" % i)
	var old_world_id: int = lab.world.get_instance_id()
	var old_field_ref: WeakRef = weakref(lab.visibility_field)
	await lab.rebuild()
	while not lab.sample_ready or lab.busy: await process_frame
	await frames(20)
	hide_ui()
	check(not is_instance_id_valid(old_world_id), "Rebuild releases the previous world")
	check(old_field_ref.get_ref() == null, "Rebuild releases the old visibility field")
	check(lab.vision_enabled and is_instance_valid(lab.visibility_field), "Rebuild installs an enabled fresh visibility field")
	check_native_path("Rebuilt sample")
	lab.update_visibility()
	check(lab.visibility_field.origin_pixels.distance_to(lab.world.player.global_position) < 1.0, "Rebuilt visibility uses the new player position")
	await capture("07_rebuilt_visibility")
	lab.sample_ui.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var controls: Image = root.get_texture().get_image()
	save_picture("08_controls", controls)
	await check_smoke_edge_cache()
	var last_world_id: int = lab.world.get_instance_id()
	var last_field_ref: WeakRef = weakref(lab.visibility_field)
	await lab.retire_drawing()
	lab.free()
	await frames(3)
	check(not is_instance_id_valid(last_world_id), "Exit releases the world and its sample visibility presentation")
	check(last_field_ref.get_ref() == null, "Exit releases the visibility field without an external owner")
	report_and_quit(0 if failures.is_empty() else 1)
