extends SceneTree

const DOOR_SCENE := preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const CAP := preload("res://scripts/dream/architecture_slice_cap.gd")
const CONFIG := preload("res://resources/demo_config.tres")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAIL " + label)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var cap_mesh := CAP._closed_cut_mesh(2.0, 0.5)
	var arrays := cap_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_check(not normals.is_empty(), "cutaway cap has explicit normals")
	_check(normals[0].dot(Vector3.UP) > 0.99, "cutaway cap top is always classified as horizontal")
	_check(normals[6].dot(Vector3.BACK) > 0.99, "cutaway cap vertical skirt is classified separately")

	var map_root := Node3D.new()
	root.add_child(map_root)
	var door := DOOR_SCENE.instantiate() as PhysicalDoor3D
	door.configure(4.0, 2.2, 0.5, "left", 99, &"single")
	map_root.add_child(door)
	var collision_root := Node2D.new()
	root.add_child(collision_root)
	door.configure_gameplay_collision(collision_root)
	await _frames(2)
	door.set_architectural_cutaway(true, 2.6)
	var cap := door.left_leaf.get_node_or_null("ArchitecturalCutSurface") as MeshInstance3D
	_check(cap != null and cap.visible, "single door has one visible cut cap")
	_check(absf(cap.global_position.y - 2.6 * 0.30) < 0.001, "door cap aligns with neighbouring wall slice")
	_check(door.right_leaf.get_node_or_null("ArchitecturalCutSurface") == null, "single door has no duplicate dormant cap")
	var anchor := door.left_anchor.global_position
	var radius := door.left_leaf.global_position.distance_to(anchor)
	var hit := door.left_leaf.global_position + Vector3(0.0, 0.0, 0.03)
	_check(door.apply_door_impact(&"player_push", hit, Vector3.FORWARD, 260.0, &"", 0), "push accepted")
	_check(door._passive_swing[0], "ordinary push uses the safe passive swing")
	_check(absf(door.left_leaf.angular_velocity.y) <= door.door_passive_max_angular_velocity + 0.001, "ordinary push cannot fling its solid leaf into the player")
	var actor := Node2D.new()
	actor.add_to_group(&"dream_player")
	root.add_child(actor)
	var hinge_local := map_root.to_local(door.left_anchor.global_position)
	var hinge_2d := Vector2(hinge_local.x, hinge_local.z) * door.world_scale
	var leaf_center := door.get_leaf_center_2d(0)
	var radial := leaf_center - hinge_2d
	var sweep_direction := Vector2(radial.y, -radial.x).normalized() * signf(door.left_leaf.angular_velocity.y)
	actor.global_position = leaf_center + sweep_direction * 9.0 - CONFIG.player_collision_offset
	_check(door._passive_leaf_sweeps_into_player(0, door.left_leaf.angular_velocity.y), "door brakes when its leaf sweeps toward a nearby player")
	actor.global_position = leaf_center - sweep_direction * 9.0 - CONFIG.player_collision_offset
	_check(not door._passive_leaf_sweeps_into_player(0, door.left_leaf.angular_velocity.y), "door can swing away from the pushing player")
	actor.queue_free()
	var max_radius_error := 0.0
	var max_angle := 0.0
	for _index in 40:
		await _frames(1)
		max_radius_error = maxf(max_radius_error, absf(door.left_leaf.global_position.distance_to(anchor) - radius))
		max_angle = maxf(max_angle, door.get_open_angle())
	print("door hinge probe: max radius error=", max_radius_error, " max angle=", max_angle)
	_check(max_radius_error < 0.06, "door leaf stays on hinge circle instead of flying away")
	_check(max_angle > deg_to_rad(door.door_open_collision_angle_degrees), "one ordinary push opens the hinged doorway at walking-safe speed")
	_check(door._collision_body_2d.global_position.distance_to(door.get_leaf_center_2d()) < 0.01, "2D collision mirror follows hinged leaf")
	_check(door._combat_swing_left[0] <= 0.0, "ordinary push does not turn the leaf into an attack")
	_check(door.apply_door_impact(&"kick", hit, Vector3.FORWARD, 300.0, &"", 0), "kick impact remains accepted")
	_check(not door._passive_swing[0] and absf(door.left_leaf.angular_velocity.y) > door.door_passive_max_angular_velocity, "kick retains a stronger combat swing")
	door.shatter()
	_check(not cap.visible, "destroyed door removes cut cap from the open doorway")
	_check(door._collision_body_2d.collision_layer == 0, "destroyed door removes its gameplay blocker")
	map_root.queue_free()
	collision_root.queue_free()
	await _frames(2)
	print("PHYSICAL DOOR HINGE CUTAWAY checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
