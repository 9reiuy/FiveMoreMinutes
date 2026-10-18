extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING TASK-017-A/B HKM CAMERA & AIM TEST ===")

	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = true
	root.add_child(world)

	await frames(2)
	check(world.regenerate(42001), "World regenerate succeeded (seed 42001)")
	await frames(6)

	var camera: Camera3D = world.camera_3d
	var rig: Node3D = world.camera_rig

	# -------------------------------------------------------------
	# Test Suite 1: Camera Transform, Pitch, FOV, and Height
	# -------------------------------------------------------------
	print("\n--- Test Suite 1: Camera Parameters ---")
	check(camera != null, "Camera3D node exists")
	check(rig != null, "CameraRig node exists")

	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Camera is Perspective projection")
	check(is_equal_approx(camera.fov, 35.0), "Camera FOV is 35.0 degrees (got %.2f)" % camera.fov)

	# Verify 60 degree pitch: rotation around X axis is approx -60 degrees (-1.0472 rad)
	var pitch_deg := rad_to_deg(camera.rotation.x)
	check(is_equal_approx(pitch_deg, -60.0), "Camera pitch is -60 degrees (got %.2f)" % pitch_deg)

	# Verify world height and distance
	var world_cam_y := rig.scale.y * camera.position.y
	var world_cam_z := rig.scale.z * camera.position.z
	check(is_equal_approx(world_cam_y, 15.6), "Camera world height is 15.6m (got %.2f)" % world_cam_y)
	check(is_equal_approx(world_cam_z, 9.0), "Camera world Z offset is 9.0m (got %.2f)" % world_cam_z)

	var distance := Vector3(0, world_cam_y, world_cam_z).length()
	check(is_equal_approx(distance, 18.01) or absf(distance - 18.0) < 0.05, "Camera distance to ground focus is ~18.0m (got %.2f)" % distance)

	# -------------------------------------------------------------
	# Test Suite 2: Aim Ray-Plane Geometric Consistency
	# -------------------------------------------------------------
	print("\n--- Test Suite 2: Aim Ray-Plane Grid Consistency ---")
	var ground_plane := Plane(Vector3.UP, 0.0)

	# Viewport center (320, 180) should intersect ground directly below the rig
	var center_origin := camera.project_ray_origin(Vector2(320, 180))
	var center_normal := camera.project_ray_normal(Vector2(320, 180))
	var center_hit: Variant = ground_plane.intersects_ray(center_origin, center_normal)
	check(center_hit is Vector3, "Center screen ray intersects ground plane")
	if center_hit is Vector3:
		var center_hit_v := center_hit as Vector3
		var rel_x := center_hit_v.x - rig.global_position.x
		var rel_z := center_hit_v.z - rig.global_position.z
		check(absf(rel_x) < 0.05, "Center ray aligns with rig X (diff: %.4f)" % rel_x)
		check(absf(rel_z) < 0.05, "Center ray aligns with rig Z (diff: %.4f)" % rel_z)

	# 4 screen corners: ensure all project to distinct, valid ground coordinates
	var corners := {
		"TopLeft": Vector2(64, 36),
		"TopRight": Vector2(576, 36),
		"BottomLeft": Vector2(64, 324),
		"BottomRight": Vector2(576, 324),
	}

	var corner_hits: Dictionary = {}
	for c_name in corners.keys():
		var pos: Vector2 = corners[c_name]
		var orig := camera.project_ray_origin(pos)
		var norm := camera.project_ray_normal(pos)
		var hit: Variant = ground_plane.intersects_ray(orig, norm)
		check(hit is Vector3, "%s screen ray intersects ground plane" % c_name)
		if hit is Vector3:
			corner_hits[c_name] = hit as Vector3

	if corner_hits.size() == 4:
		var tl: Vector3 = corner_hits["TopLeft"]
		var tr: Vector3 = corner_hits["TopRight"]
		var bl: Vector3 = corner_hits["BottomLeft"]
		var br: Vector3 = corner_hits["BottomRight"]

		check(tr.x > tl.x, "TopRight X (%.2f) > TopLeft X (%.2f)" % [tr.x, tl.x])
		check(br.x > bl.x, "BottomRight X (%.2f) > BottomLeft X (%.2f)" % [br.x, bl.x])
		check(bl.z > tl.z, "BottomLeft Z (%.2f) > TopLeft Z (%.2f)" % [bl.z, tl.z])
		check(br.z > tr.z, "BottomRight Z (%.2f) > TopRight Z (%.2f)" % [br.z, tr.z])

	# -------------------------------------------------------------
	# Test Suite 3: Look-Ahead Math & Bounds
	# -------------------------------------------------------------
	print("\n--- Test Suite 3: Look-Ahead Bounds ---")
	var ground_pt := Vector2(0, 0)
	var right_aim := Vector2(400, 0)
	var look_offset: Vector3 = world.compute_camera_aim_offset(ground_pt, right_aim, 1.0)
	check(look_offset.x > 0.0, "Look-ahead moves in aim direction (X > 0: %.3f)" % look_offset.x)
	check(absf(look_offset.z) < 0.01, "Look-ahead pure X aim has negligible Z offset (Z: %.3f)" % look_offset.z)

	var up_aim := Vector2(0, -400) # Negative Y in 2D is North (negative Z in 3D)
	var look_up: Vector3 = world.compute_camera_aim_offset(ground_pt, up_aim, 1.0)
	check(look_up.z < 0.0, "Look-ahead North aim moves negative Z (Z < 0: %.3f)" % look_up.z)

	# -------------------------------------------------------------
	# Test Suite 4: Gameplay Canvas & Player Projection Alignment
	# -------------------------------------------------------------
	print("\n--- Test Suite 4: Projection Alignment ---")
	var player_pos: Vector2 = world.player.global_position
	var anchor_world: Vector3 = world.get_gameplay_world_position(player_pos, 0.0)
	var screen_pos := camera.unproject_position(anchor_world)
	check(screen_pos.is_finite(), "Player screen position is finite: %s" % screen_pos)
	check(screen_pos.x > 0 and screen_pos.x < 640 and screen_pos.y > 0 and screen_pos.y < 360, "Player screen position within viewport: %s" % screen_pos)

	world.free()
	await frames(4)

	print("\n==================================================")
	print("TOTAL CHECKS: ", checks)
	print("TOTAL FAILURES: ", failures.size())
	if failures.is_empty():
		print("ALL TASK-017 HKM CAMERA TESTS PASSED SUCCESSFULLY!")
	else:
		print("FAILED ASSERTIONS:")
		for f in failures:
			print("  - ", f)
	print("==================================================\n")

	quit(0 if failures.is_empty() else 1)
