extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func frames(count: int = 3) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var world = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(41002), "rotated office floor generated")
	await frames(8)
	var player: Node2D = world.player
	player.set_physics_process(false)
	var camera: Camera3D = world.camera_3d
	var bridge_ref: Variant = player.get_meta(&"depth_visual_bridge", null)
	var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	check(bridge != null, "formal player weapon bridge exists")
	check(absf(world.global_rotation.y) > 0.5, "office map has its authored 45-degree yaw")
	var muzzle: Vector2 = player.projectile_origin.global_position
	var snapshot: Dictionary = bridge.get_weapon_visual_snapshot(muzzle)
	check(snapshot.has("world_origin"), "formal muzzle snapshot exists")
	var muzzle_world: Vector3 = snapshot.get("world_origin", Vector3.ZERO)
	for i in 8:
		var before_muzzle: Dictionary = bridge.get_weapon_visual_snapshot(player.projectile_origin.global_position)
		var before_world: Vector3 = before_muzzle["world_origin"]
		var expected_dir := Vector2.from_angle(float(i) * TAU / 8.0)
		var target_world: Vector3 = before_world + world.global_basis * Vector3(expected_dir.x, 0.0, expected_dir.y) * 8.0
		var target_screen := camera.unproject_position(target_world)
		var aim_dir: Vector2 = player._camera_muzzle_aim_direction_at(target_screen)
		check(aim_dir.dot(expected_dir) > 0.999, "camera muzzle aim maps direction %d" % i)
		var shot_world: Vector3 = before_world + world.global_basis * Vector3(aim_dir.x, 0.0, aim_dir.y) * 8.0
		check(camera.unproject_position(shot_world).distance_to(target_screen) < 0.1, "shot projects onto cursor %d" % i)
		player._update_held_weapon_aim_at(target_screen)
		var current_muzzle: Dictionary = bridge.get_weapon_visual_snapshot(player.projectile_origin.global_position)
		var weapon_root := player.get_node(^"WeaponRoot") as Node2D
		var weapon_axis := Vector2.RIGHT.rotated(weapon_root.global_rotation)
		var axis_world: Vector3 = world.global_basis * Vector3(weapon_axis.x, 0.0, weapon_axis.y)
		var projected_axis: Vector2 = (camera.unproject_position(current_muzzle["world_origin"] + axis_world)
			- camera.unproject_position(current_muzzle["world_origin"])).normalized()
		var captured_axis := Vector2.RIGHT.rotated(weapon_root.global_rotation + bridge.weapon_capture_rotation_delta)
		check(captured_axis.dot(projected_axis) > 0.998, "captured weapon axis follows projected shot %d" % i)
		var current_aim: Vector2 = player._aim_direction_at(target_screen)
		var current_shot_world: Vector3 = current_muzzle["world_origin"] + world.global_basis * Vector3(current_aim.x, 0.0, current_aim.y) * 8.0
		var current_screen_dir := (camera.unproject_position(current_shot_world) - camera.unproject_position(current_muzzle["world_origin"])).normalized()
		var cursor_screen_dir := (target_screen - camera.unproject_position(current_muzzle["world_origin"])).normalized()
		check(current_screen_dir.dot(cursor_screen_dir) > 0.998, "current pose and current muzzle project toward cursor %d" % i)
	var last_muzzle: Dictionary = bridge.get_weapon_visual_snapshot(player.projectile_origin.global_position)
	var muzzle_screen := camera.unproject_position(last_muzzle["world_origin"])
	player.last_aim_direction = Vector2.UP
	check(player._camera_muzzle_aim_direction_at(muzzle_screen).dot(Vector2.UP) > 0.999, "cursor on muzzle keeps stable prior heading")

	var overlay: Node = player.tactical_preview_overlay
	var point := player.global_position + Vector2(96.0, -64.0)
	var expected_ground: Vector3 = world.get_gameplay_world_position(point, 0.0)
	check(overlay._world_to_screen(point).distance_to(camera.unproject_position(expected_ground)) < 0.1, "Space overlay includes map yaw")
	var path: Dictionary = player.resolve_tactical_dash_path(point)
	check(path.has("end"), "Space gameplay path resolved")
	overlay.start_preview(player.visual, player.dash_distance * 2.0)
	overlay.update_destination(path, false)
	var actual_end: Vector2 = path.get("end", player.global_position)
	check(overlay.ghost_container.position.distance_to(camera.unproject_position(world.get_gameplay_world_position(actual_end, 0.0))) < 0.1, "Space ghost and gameplay landing agree")
	check(overlay._world_to_screen(player.global_position).distance_to(camera.unproject_position(world.get_gameplay_world_position(player.global_position, 0.0))) < 0.1, "Space route starts at actual player ground")
	overlay.end_preview()
	world.queue_free()
	await frames(4)
	print("AIM PREVIEW PROJECTION checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
