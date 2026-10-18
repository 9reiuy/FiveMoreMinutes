extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	for i in 2:
		await process_frame
	_check(world.regenerate(42001), "3D floor generates")
	for i in 4:
		await process_frame

	var player: Node = world.player
	var camera: Camera3D = world.camera_3d
	var rig: Node3D = world.camera_rig
	var original_yaw := rig.rotation.y
	var gameplay_origin: Vector2 = player.global_position
	var screen_origin := camera.unproject_position(world.get_gameplay_world_position(gameplay_origin, 0.0))
	for yaw_degrees in [0.0, 45.0, -90.0, 135.0]:
		rig.rotation.y = original_yaw + deg_to_rad(yaw_degrees)
		screen_origin = camera.unproject_position(world.get_gameplay_world_position(gameplay_origin, 0.0))
		var north: Vector2 = player.call("_camera_relative_movement_input", Vector2.UP)
		var east: Vector2 = player.call("_camera_relative_movement_input", Vector2.RIGHT)
		var north_screen := camera.unproject_position(world.get_gameplay_world_position(gameplay_origin + north * 32.0, 0.0)) - screen_origin
		var east_screen := camera.unproject_position(world.get_gameplay_world_position(gameplay_origin + east * 32.0, 0.0)) - screen_origin
		_check(north_screen.y < -0.1 and absf(north_screen.x) < absf(north_screen.y) * 0.05, "W points screen-up at yaw %.0f: %s" % [yaw_degrees, north_screen])
		_check(east_screen.x > 0.1 and absf(east_screen.y) < absf(east_screen.x) * 0.05, "D points screen-right at yaw %.0f: %s" % [yaw_degrees, east_screen])
		_check(is_equal_approx(north.length(), 1.0) and is_equal_approx(east.length(), 1.0), "movement magnitude unchanged at yaw %.0f" % yaw_degrees)
		var diagonal: Vector2 = player.call("_camera_relative_movement_input", Vector2(0.70710678, -0.70710678))
		_check(is_equal_approx(diagonal.length(), 1.0), "diagonal movement remains normalized at yaw %.0f" % yaw_degrees)

	rig.rotation.y = original_yaw + deg_to_rad(45.0)
	var expected_north: Vector2 = player.call("_camera_relative_movement_input", Vector2.UP)
	player.movement_enabled = true
	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	_check(player.last_move_direction.dot(expected_north) > 0.999, "live WASD updates the same gameplay direction used by Dash and Kick: %s vs %s (enabled=%s scripted=%s)" % [player.last_move_direction, expected_north, player.movement_enabled, player.scripted_locomotion_active])
	Input.action_release("move_up")
	world.remove_from_group(&"dream_world")
	_check(player.call("_camera_relative_movement_input", Vector2.UP) == Vector2.UP, "legacy 2D world keeps original input direction")
	world.add_to_group(&"dream_world")

	rig.rotation.y = original_yaw
	world.free()
	print("Camera-relative movement: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
