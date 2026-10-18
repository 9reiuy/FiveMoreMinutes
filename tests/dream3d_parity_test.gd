extends SceneTree
const DUNGEON = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DOOR = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const PROJECTILE = preload("res://scenes/entities/basic_projectile.tscn")
var failures: Array[String] = []
var checks := 0
var dungeon: Node3D

func _init() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: ", label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	dungeon = DUNGEON.instantiate()
	dungeon.persist_profile = false
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	root.add_child(dungeon)
	await frames(2)
	check(dungeon.regenerate(41001), "generation")
	await frames(4)
	var player: Node2D = dungeon.player
	player.set_physics_process(false)
	dungeon.target_highlight.set_physics_process(false)
	var camera: Camera3D = dungeon.camera_3d
	var rotation := camera.rotation
	var fov := camera.fov
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(fov, 35.0), "accepted perspective camera")
	check(dungeon.get_node_or_null("GameplayUI") != null, "UI crosshair")
	var base_scale: Vector2 = player.get_node("CharacterVisual").scale
	check(base_scale.abs().is_equal_approx(Vector2.ONE * 1.5), "unchanged player visual scale")
	for wall in dungeon.wall_root.get_children():
		check(is_equal_approx(wall.wall_height, 3.0), "wall stays tall")
		check(wall.get_node("WallMesh").mesh.get_surface_count() == 1, "wall mesh built")
	for door in dungeon.door_root.get_children():
		var edge: Dictionary = door.get_meta("door_edge")
		check(door.global_position.is_equal_approx(dungeon.call("_door_opening_center_world_position", edge)), "door root at edge centre")
		check(door.get_node("DoorLeaf").position.is_equal_approx(Vector3(0, 1.5, 0)), "leaf above floor/centre")
		check(door.find_children("*Frame*", "", true, false).is_empty(), "no frame nodes")
	# The current renderer batches six-by-six UV phases directly under FloorRoot;
	# keep the invariant assertion against the first batch's authored mesh.
	var floor_batch: MultiMeshInstance3D = dungeon.floor_root.get_child(0) as MultiMeshInstance3D
	var floor_mesh: ArrayMesh = floor_batch.multimesh.mesh as ArrayMesh
	var uv: PackedVector2Array = floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(is_equal_approx(uv[1].x-uv[0].x, 1.0/6), "one brick per cell static UV")
	player.position += Vector2(40, 40)
	await frames(5)
	check(camera.rotation.is_equal_approx(rotation) and is_equal_approx(camera.fov, fov), "camera orientation/fov unchanged")
	check(uv == floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV], "UV invariant after follow")
	var low: int = 0
	for wall in dungeon.wall_root.get_children():
		if is_equal_approx(float(wall.get("wall_opacity")), 0.3):
			low += 1
	print("near-wall material instances ", low)
	check(low > 0, "only near walls faded")
	# Isolated physical hinges keep generated topology intact and test all axes.
	for angle in [0.0, PI/2, PI, -PI/2]:
		var door: Node3D = DOOR.instantiate()
		door.configure(1.84, 3, 0.1, "left", 9000)
		door.position = Vector3(-20,0,-20)
		door.rotation.y = angle
		dungeon.add_child(door)
		door.configure_gameplay_collision(dungeon.collision_root, 32, 4)
		await frames(3)
		var centre: Vector3 = door.door_leaf.global_position
		var normal: Vector3 = door.global_basis.z
		door.push_from_proxy(centre-normal, normal, 1.0/60)
		await frames(8)
		check(door.latched and absf(door.get_open_angle()) < 0.001, "passive contact closed "+str(angle))
		check(door.apply_door_impact(&"player_push", centre, normal, 260), "E accepted "+str(angle))
		await frames(55)
		print("door E angle ", angle, ": ", rad_to_deg(door.get_open_angle()), " omega ", door.door_leaf.angular_velocity)
		check(absf(door.get_open_angle()) > deg_to_rad(18), "real E hinge opens "+str(angle))
		check(door.hinge_anchor.global_position.distance_to(door.door_leaf.to_global(Vector3(-0.92,0,0))) < 0.04, "hinge does not translate")
		check(door._collision_body_2d.collision_layer == 4, "open leaf remains solid")
		check(door._collision_body_2d.global_position.distance_to(door.get_leaf_center_2d()) < 1, "open collision tracks leaf")
		door.set_locked(true)
		check(not door.apply_door_impact(&"kick", centre, normal, 3000), "locked rejects kick")
		door.free()
		await frames(2)
	# The real projectile must move past the aim point and release its carrier.
	player.global_position = Vector2(-400,-400)
	for spec in [["basic",1800.0], ["shotgun",1600.0], ["assault_rifle",2200.0]]:
		var bullet: Node2D = PROJECTILE.instantiate()
		bullet.position = Vector2(-400,-400)
		bullet.setup(Vector2.RIGHT, 10.0, 240, spec[1], &"player", player, StringName(spec[0]))
		dungeon.add_projectile(bullet)
		bullet.set_physics_process(false)
		var bridge: Node3D = bullet.get_meta("depth_visual_bridge").get_ref()
		bullet._physics_process(1.0/60.0)
		bridge._process(0)
		check(is_instance_valid(bullet) and bullet.position.x > -400, str(spec[0])+" moves")
		check(is_instance_valid(bridge) and bridge.source_actor == bullet, str(spec[0])+" one visual owner")
		check(is_equal_approx(bullet.penetration_chance, 0.1) and bullet.max_penetrations == 1, str(spec[0])+" shared penetration")
		bullet.set_physics_process(true)
		await frames(30)
		check(not is_instance_valid(bullet) and not is_instance_valid(bridge), str(spec[0])+" range cleanup incl visual")
	if "--render" in OS.get_cmdline_user_args():
		player.position = dungeon.get_player_root_position_for_cell(dungeon.spawn_cell) + Vector2(0, -70)
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/parity_environment.png")
		print("RENDER FPS ", Engine.get_frames_per_second())
	print("PARITY CHECKS ", checks, " failures ", failures.size())
	for failure in failures:
		print("FAIL ", failure)
	dungeon.free()
	await frames(20)
	quit(0 if failures.is_empty() else 1)
