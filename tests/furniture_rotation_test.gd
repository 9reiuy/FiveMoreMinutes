extends SceneTree

const BOX := preload("res://scenes/dream/props/parcel_box_01.tscn")
const DESK := preload("res://scenes/dream/props/desk.tscn")
const CATALOG := preload("res://scripts/dream/office_furniture_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var box := BOX.instantiate() as RigidBody2D
	root.add_child(box)
	await physics_frame
	_check(not box.lock_rotation, "movable prop rotation must be unlocked")
	box.apply_player_kick_impulse(Vector2.RIGHT, 36.0, box.global_position + Vector2(0.0, 5.0))
	await physics_frame
	_check(absf(box.angular_velocity) > 0.01, "off-centre kick must generate angular velocity")
	_check(box.linear_velocity.x > 0.0, "off-centre kick must still translate the 2D body")
	var visual := preload("res://scripts/dream/furniture_3d_visual.gd").new() as Node3D
	root.add_child(visual)
	visual.configure(box, null)
	visual.call("_sync_transform")
	_check(absf(visual.rotation.y + box.global_rotation) < 0.001, "3D yaw must follow authoritative 2D rotation")
	box.queue_free()
	visual.queue_free()
	await process_frame

	for kind in ["counter", "appliance_counter", "reception", "sink", "washbasin", "toilet"]:
		var fixture := DESK.instantiate() as RigidBody2D
		CATALOG.configure(fixture, kind)
		root.add_child(fixture)
		await physics_frame
		_check(fixture.freeze and fixture.lock_rotation, "%s must remain fixed" % kind)
		_check(not fixture.is_in_group(&"pushable_prop"), "%s must not accept player pushes" % kind)
		fixture.queue_free()
		await process_frame

	if failures.is_empty():
		print("FURNITURE ROTATION TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
