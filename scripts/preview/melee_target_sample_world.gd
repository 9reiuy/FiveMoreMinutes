extends "res://scripts/testing/lab_world.gd"
## The lab uses the same melee presentation as the formal game.

var sample_anchor := Vector2.ZERO
var sample_door: Node3D
var sample_enemies: Array[Node2D] = []

func prepare_melee_sample() -> void:
	sample_anchor = station_position(1)
	# The fixed lab's east office door has real 2D collision and a 3D leaf.
	for door in door_root.get_children():
		if not door is PhysicalDoor3D:
			continue
		var center: Vector2 = door.get_leaf_center_2d(0)
		if absf(center.x - 432.0) > 16.0 or center.y < 72.0 or center.y > 200.0:
			continue
		sample_door = door
		sample_anchor = center - Vector2(34.0, 0.0)
		door.set_locked(true)
		break

	player.global_position = sample_anchor
	player.velocity = Vector2.ZERO
	activate_room(_room_id_at_position(sample_anchor))
	for offset in [Vector2(17.0, -27.0), Vector2(17.0, 30.0)]:
		_add_sample_enemy(sample_anchor + offset)
	if is_instance_valid(sample_door):
		_add_sample_enemy(sample_anchor + Vector2(60.0, 0.0))
	_update_camera_and_actor_projection(0.0)

func _add_sample_enemy(point: Vector2) -> void:
	var room := _room_id_at_position(point)
	if room < 0:
		return
	var enemy := _spawn_regular_employee(room, point, &"employee", false, "basic")
	if not is_instance_valid(enemy):
		return
	enemy.set_room_runtime_active(true)
	if enemy.sky_drop_active:
		enemy._update_sky_drop(2.0)
	enemy.maximum_health = 1000.0
	enemy.current_health = 1000.0
	enemy.set_physics_process(false)
	sample_enemies.append(enemy)
