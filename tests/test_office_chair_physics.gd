extends SceneTree

const OFFICE_CHAIR_SCENE := preload("res://scenes/dream/props/office_chair_01.tscn")
const CHAIR_REGULAR_SCENE := preload("res://scenes/dream/props/chair.tscn")
const VISUAL_3D_SCENE := preload("res://scenes/dream/3d/props/office_chair_01_visual_3d.tscn")
const FURNITURE_3D_VISUAL := preload("res://scripts/dream/furniture_3d_visual.gd")
const LOW_PIXEL_ART := preload("res://scripts/dream/office_low_pixel_art.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Starting office chair physics & visual split tests...")

	_test_chair_2d_properties()
	_test_chair_3d_hierarchy()
	await _test_swivel_spin_and_damping()
	await _test_sliding_distance_comparison()
	_test_3d_visual_rotation_sync()
	_test_procedural_pixel_chair()
	_test_bowling_damage_to_dummy()

	await process_frame

	if failures.is_empty():
		print("TEST_OFFICE_CHAIR_PHYSICS_PASSED: All 7 test suites passed successfully!")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		printerr("TEST_OFFICE_CHAIR_PHYSICS_FAILED with " + str(failures.size()) + " failures.")
		quit(1)

func _test_chair_2d_properties() -> void:
	var chair = OFFICE_CHAIR_SCENE.instantiate()
	root.add_child(chair)
	_assert(chair.get("is_swivel_chair") == true, "office_chair_01 is_swivel_chair should be true")
	_assert(absf(chair.linear_damp - 1.2) < 0.05, "office_chair_01 linear_damp should be 1.2, got: " + str(chair.linear_damp))
	_assert(chair.get("seat_angular_damp") > 1.0, "seat_angular_damp should be positive")
	chair.queue_free()

func _test_chair_3d_hierarchy() -> void:
	var vis = VISUAL_3D_SCENE.instantiate()
	root.add_child(vis)
	var base_mesh: MeshInstance3D = vis.get_node_or_null("BaseMesh") as MeshInstance3D
	_assert(base_mesh != null, "Missing BaseMesh node in office_chair_01_visual_3d")
	_assert(base_mesh != null and base_mesh.mesh != null, "BaseMesh mesh is null")

	var seat_root: Node3D = vis.get_node_or_null("SeatRoot") as Node3D
	_assert(seat_root != null, "Missing SeatRoot node in office_chair_01_visual_3d")

	var seat_mesh: MeshInstance3D = vis.get_node_or_null("SeatRoot/SeatMesh") as MeshInstance3D
	_assert(seat_mesh != null, "Missing SeatMesh under SeatRoot in office_chair_01_visual_3d")
	_assert(seat_mesh != null and seat_mesh.mesh != null, "SeatMesh mesh is null")
	vis.queue_free()

func _test_swivel_spin_and_damping() -> void:
	var chair = OFFICE_CHAIR_SCENE.instantiate()
	root.add_child(chair)
	chair.global_position = Vector2(200, 200)

	_assert(absf(chair.get("seat_angular_velocity")) < 0.001, "Initial seat angular velocity should be 0")
	_assert(absf(chair.get("seat_rotation")) < 0.001, "Initial seat rotation should be 0")

	# Simulate bullet hit with off-center contact point
	var hit_dir := Vector2(1, 0)
	var contact_pt: Vector2 = chair.global_position + Vector2(0, -8)
	chair.take_damage(10.0, hit_dir, 1.0, contact_pt)

	var spin_vel: float = chair.get("seat_angular_velocity")
	_assert(absf(spin_vel) > 1.0, "Expected significant seat_angular_velocity after hit, got: " + str(spin_vel))

	# Step physics a few frames and verify rotation progression & damp
	var prev_vel: float = spin_vel
	for i in range(10):
		await process_frame
		chair._physics_process(0.016)

	var mid_rot: float = chair.get("seat_rotation")
	var mid_vel: float = chair.get("seat_angular_velocity")
	_assert(absf(mid_rot) > 0.01, "Seat rotation should have changed during physics frames")
	_assert(absf(mid_vel) < absf(prev_vel), "Seat angular velocity should decay over time due to damping")

	chair.queue_free()

func _test_sliding_distance_comparison() -> void:
	var office_chair = OFFICE_CHAIR_SCENE.instantiate()
	var regular_chair = CHAIR_REGULAR_SCENE.instantiate()
	root.add_child(office_chair)
	root.add_child(regular_chair)

	office_chair.global_position = Vector2(100, 100)
	regular_chair.global_position = Vector2(100, 300)

	var impulse := Vector2(300, 0)
	office_chair.linear_velocity = impulse / office_chair.mass
	regular_chair.linear_velocity = impulse / regular_chair.mass

	# Simulate 1.0 second of motion
	var dt := 0.02
	for step in range(50):
		office_chair.linear_velocity += -office_chair.linear_velocity * office_chair.linear_damp * dt
		regular_chair.linear_velocity += -regular_chair.linear_velocity * regular_chair.linear_damp * dt
		office_chair.global_position += office_chair.linear_velocity * dt
		regular_chair.global_position += regular_chair.linear_velocity * dt

	var office_dist: float = office_chair.global_position.x - 100.0
	var regular_dist: float = regular_chair.global_position.x - 100.0
	print("Slide distance comparison: OfficeChair=", office_dist, "px, RegularChair=", regular_dist, "px")

	_assert(office_dist > regular_dist * 2.0, "Office chair should slide at least 2x further than regular chair")
	_assert(office_dist >= 60.0, "Office chair should slide at least 60 pixels under standard impulse")

	office_chair.queue_free()
	regular_chair.queue_free()

func _test_3d_visual_rotation_sync() -> void:
	var chair = OFFICE_CHAIR_SCENE.instantiate()
	root.add_child(chair)

	var visual: Node3D = FURNITURE_3D_VISUAL.new()
	root.add_child(visual)
	visual.call("configure", chair, VISUAL_3D_SCENE)

	chair.set("seat_rotation", 1.234)
	visual.call("_sync_transform")

	var seat_root: Node3D = visual.get_node_or_null("OfficeChair01_Visual3D/SeatRoot") as Node3D
	_assert(seat_root != null, "SeatRoot should exist inside visual instance")
	if seat_root != null:
		_assert(absf(seat_root.rotation.y - (-1.234)) < 0.001, "SeatRoot rotation.y should match -seat_rotation, got: " + str(seat_root.rotation.y))

	visual.queue_free()
	chair.queue_free()

func _test_procedural_pixel_chair() -> void:
	var proc_chair := LOW_PIXEL_ART.make_visual("chair")
	root.add_child(proc_chair)
	var base_mesh: MeshInstance3D = proc_chair.get_node_or_null("BaseMesh") as MeshInstance3D
	_assert(base_mesh != null, "Procedural chair missing BaseMesh")
	var seat_root: Node3D = proc_chair.get_node_or_null("SeatRoot") as Node3D
	_assert(seat_root != null, "Procedural chair missing SeatRoot")
	var seat_mesh: MeshInstance3D = proc_chair.get_node_or_null("SeatRoot/SeatMesh") as MeshInstance3D
	_assert(seat_mesh != null, "Procedural chair missing SeatMesh under SeatRoot")
	proc_chair.queue_free()

func _test_bowling_damage_to_dummy() -> void:
	var chair = OFFICE_CHAIR_SCENE.instantiate()
	root.add_child(chair)

	var dummy := MockEnemy.new()
	dummy.add_to_group("dream_enemies")
	root.add_child(dummy)

	# High-speed bowling impact (speed = 180 > furniture_impact_minimum_speed)
	chair._deal_impact_damage(dummy, Vector2(1, 0), 180.0)

	_assert(dummy.damage_received > 0.0, "Mock enemy should receive bowling impact damage, got: " + str(dummy.damage_received))
	_assert(dummy.knockdown_triggered == true, "Mock enemy should be knocked down by bowling impact")

	dummy.queue_free()
	chair.queue_free()

class MockEnemy extends CharacterBody2D:
	var damage_received: float = 0.0
	var knockdown_triggered: bool = false
	var dead: bool = false

	func take_damage(amount: float, _pos: Vector2 = Vector2.ZERO, _force: float = 0.0, _src: Variant = null) -> void:
		damage_received += amount

	func start_knockdown(_dir: Vector2, _src: Variant = null, _force: float = 0.0) -> void:
		knockdown_triggered = true

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("ASSERTION FAILED: ", message)

