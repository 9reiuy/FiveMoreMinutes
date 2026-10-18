extends SceneTree

const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9"
const ElevatorFloorDoor3D = preload("res://scripts/dream/elevator_floor_door_3d.gd")
const IndependentElevatorCab3D = preload("res://scripts/dream/independent_elevator_cab_3d.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== ELEVATOR VISUAL TEST START ===")
	var scene_root := Node3D.new()
	root.add_child(scene_root)

	# World environment & directional light
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	scene_root.add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	dir_light.light_energy = 1.0
	dir_light.light_color = Color(0.95, 0.95, 1.0)
	scene_root.add_child(dir_light)

	# Camera
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	scene_root.add_child(camera)

	# -------------------------------------------------------------
	# 1. Test & Capture Independent Elevator Cab (Matching Image 1)
	# -------------------------------------------------------------
	var cab := preload("res://scripts/dream/independent_elevator_cab_3d.gd").new(1)
	scene_root.add_child(cab)
	cab.position = Vector3(0.0, 0.0, 0.0)

	# Add a simple player proxy inside cab
	var player_box := MeshInstance3D.new()
	var pb_mesh := BoxMesh.new()
	pb_mesh.size = Vector3(0.4, 1.6, 0.3)
	player_box.mesh = pb_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 0.45, 0.75)
	player_box.material_override = p_mat
	player_box.position = Vector3(0.0, 0.8, -0.2)
	cab.add_child(player_box)

	# Position camera to look down into cab from South at isometric angle
	camera.position = Vector3(0.0, 3.8, 3.2)
	camera.look_at(Vector3(0.0, 1.1, -0.4), Vector3.UP)

	for i in 8:
		await process_frame

	var img_cab := root.get_viewport().get_texture().get_image()
	img_cab.save_png(ARTIFACT_DIR + "/capture_elevator_cab_interior.png")
	print("Saved cab capture: ", ARTIFACT_DIR + "/capture_elevator_cab_interior.png")

	cab.queue_free()
	for i in 4:
		await process_frame

	# -------------------------------------------------------------
	# 2. Test & Capture Elevator Floor Door UP (Matching Image 2)
	# -------------------------------------------------------------
	var door_up := preload("res://scripts/dream/elevator_floor_door_3d.gd").new(0, 0)
	scene_root.add_child(door_up)
	door_up.position = Vector3(0.0, 0.0, 0.0)

	# Corridor floor slab under door
	var floor_slab := MeshInstance3D.new()
	var fs_mesh := BoxMesh.new()
	fs_mesh.size = Vector3(6.0, 0.04, 4.0)
	floor_slab.mesh = fs_mesh
	floor_slab.position = Vector3(0.0, -0.02, 1.5)
	var slab_mat := preload("res://scripts/dream/office_pixel_materials.gd").make(Color(0.45, 0.48, 0.50), "tile")
	floor_slab.material_override = slab_mat
	scene_root.add_child(floor_slab)

	# Wall section on left and right
	var wall_left := MeshInstance3D.new()
	var wl_mesh := BoxMesh.new()
	wl_mesh.size = Vector3(2.0, 2.6, 0.22)
	wall_left.mesh = wl_mesh
	wall_left.position = Vector3(-2.8, 1.3, 0.0)
	wall_left.material_override = slab_mat
	scene_root.add_child(wall_left)

	var wall_right := MeshInstance3D.new()
	wall_right.mesh = wl_mesh
	wall_right.position = Vector3(2.8, 1.3, 0.0)
	wall_right.material_override = slab_mat
	scene_root.add_child(wall_right)

	# Camera looking directly at the floor door from corridor (+Z)
	camera.position = Vector3(0.0, 1.8, 4.2)
	camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)

	for i in 8:
		await process_frame

	var img_door_up := root.get_viewport().get_texture().get_image()
	img_door_up.save_png(ARTIFACT_DIR + "/capture_elevator_floor_door_up.png")
	print("Saved door UP capture: ", ARTIFACT_DIR + "/capture_elevator_floor_door_up.png")

	# Test Door Open
	door_up.open_doors(0.1)
	for i in 12:
		await process_frame

	var img_door_open := root.get_viewport().get_texture().get_image()
	img_door_open.save_png(ARTIFACT_DIR + "/capture_elevator_doors_opened.png")
	print("Saved door OPEN capture: ", ARTIFACT_DIR + "/capture_elevator_doors_opened.png")

	door_up.queue_free()
	for i in 4:
		await process_frame

	# -------------------------------------------------------------
	# 3. Test & Capture Elevator Floor Door DOWN (South entrance)
	# -------------------------------------------------------------
	var door_down := preload("res://scripts/dream/elevator_floor_door_3d.gd").new(1, 2)
	scene_root.add_child(door_down)
	door_down.position = Vector3(0.0, 0.0, 0.0)

	# Camera looking at South door from inside corridor (-Z)
	camera.position = Vector3(0.0, 1.8, -4.2)
	camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)

	for i in 8:
		await process_frame

	var img_door_down := root.get_viewport().get_texture().get_image()
	img_door_down.save_png(ARTIFACT_DIR + "/capture_elevator_floor_door_down.png")
	print("Saved door DOWN capture: ", ARTIFACT_DIR + "/capture_elevator_floor_door_down.png")

	print("=== ELEVATOR VISUAL TEST COMPLETE ===")
	quit(0)
