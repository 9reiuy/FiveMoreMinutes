extends SceneTree

const WALL_SCENE := preload("res://scenes/dream/3d/WallStraight3D.tscn")
const DOOR_SCENE := preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const FLOOR_BATCH_RENDERER := preload("res://scripts/dream/dream_3d_floor_batch_renderer.gd")
const REFINED := preload("res://scripts/dream/office_low_pixel_refined.gd")

func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _run() -> void:
	print("--- Running Broken Door Wall Jamb Capture Test ---")

	var world := Node3D.new()
	world.name = "CaptureWorld"
	root.add_child(world)

	# 1. Lighting & Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.44, 0.52, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = 1
	env_node.environment = env
	world.add_child(env_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	key_light.light_energy = 0.5
	key_light.shadow_enabled = true
	world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 2.5, 2.0)
	fill_light.light_energy = 1.0
	fill_light.omni_range = 8.0
	world.add_child(fill_light)

	# 2. CameraRig (Game Perspective: 45 degree tilt, perspective)
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	world.add_child(camera_rig)

	var camera := Camera3D.new()
	camera.fov = 40.0
	camera_rig.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(1.2, 5.0, 5.0), Vector3(0.0, 1.2, 0.0), Vector3.UP)

	# 3. Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.23, 0.26, 1.0)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	world.add_child(floor_mesh)

	# 4. Wall Roots & Walls
	# Left wall segment ending at x = -1.0 (door opening starts at -1.0)
	var wall_left := WALL_SCENE.instantiate() as Node3D
	wall_left.name = "WallLeft"
	wall_left.position = Vector3(-1.5, 0.0, 0.0)
	world.add_child(wall_left)
	if wall_left.has_method("configure_wall"):
		wall_left.call("configure_wall", 2.6, 0.5)

	# Right wall segment ending at x = +1.0 (door opening ends at +1.0)
	var wall_right := WALL_SCENE.instantiate() as Node3D
	wall_right.name = "WallRight"
	wall_right.position = Vector3(1.5, 0.0, 0.0)
	world.add_child(wall_right)
	if wall_right.has_method("configure_wall"):
		wall_right.call("configure_wall", 2.6, 0.5)

	# 5. Physical Door between left and right walls (width = 2.0m)
	var door_root := Node3D.new()
	door_root.name = "DoorRoot"
	world.add_child(door_root)

	var collision_root := Node2D.new()
	collision_root.name = "CollisionRoot"
	world.add_child(collision_root)

	var door := DOOR_SCENE.instantiate() as PhysicalDoor3D
	door.name = "TestDoor"
	door.configure(2.0, 2.6, 0.5, "left", 501, &"single")
	door.position = Vector3(0.0, 0.0, 0.0)
	door_root.add_child(door)
	door.configure_gameplay_collision(collision_root)

	# Settle initial layout and render intact door
	await _frames(15)

	var intact_img := root.get_viewport().get_texture().get_image()
	if intact_img != null and not intact_img.is_empty():
		intact_img.save_png("res://tests/door_intact_preview.png")
		print("Saved intact door preview: res://tests/door_intact_preview.png")

	# 6. Shatter the door completely
	print("Shattering door...")
	door.shatter(Vector2(0, 1))

	# Wait for shards animation and settle
	await _frames(30)

	# 7. Capture the broken doorway and exposed wall jamb
	var broken_img := root.get_viewport().get_texture().get_image()
	if broken_img != null and not broken_img.is_empty():
		broken_img.save_png("res://tests/broken_door_wall_jamb_fixed.png")
		print("Saved broken door wall jamb screenshot: res://tests/broken_door_wall_jamb_fixed.png")

	world.queue_free()
	collision_root.queue_free()
	await _frames(2)

	print("Capture test complete! Exiting.")
	quit(0)
