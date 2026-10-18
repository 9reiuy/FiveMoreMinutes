extends Control

const REFINED = preload("res://scripts/dream/office_low_pixel_refined.gd")
const USER_ART = preload("res://scripts/dream/office_low_pixel_art.gd")
const WORLD_SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var output_dir := "res://.runtime/low_pixel/showcase"
var game_view: SubViewport

func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(1280, 720)
	
	game_view = SubViewport.new()
	game_view.size = Vector2i(1280, 720)
	game_view.own_world_3d = true
	game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(game_view)
	
	call_deferred("_execute_all")

func _execute_all() -> void:
	print("=== Starting Office Low-Pixel Showcase Runner ===")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	
	# 1. Render Turntable 8-way Showcase
	print("[1/2] Generating Turntable 8-way Showcase...")
	await _render_turntable_showcase()
	
	# 2. Render Open Office Comparison
	print("[2/2] Generating Open Office Room Comparisons...")
	await _render_room_comparison()
	
	print("=== All Showcase Captures Completed Successfully! ===")
	get_tree().quit(0)

func _render_turntable_showcase() -> void:
	# Clear previous children in game_view
	for child in game_view.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	var scene_root := Node3D.new()
	game_view.add_child(scene_root)
	
	# Environment
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1e2428")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("68767e")
	env.ambient_light_energy = 0.85
	world_env.environment = env
	scene_root.add_child(world_env)
	
	# Directional Sun Light
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0)
	sun.light_color = Color("ffffff")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	scene_root.add_child(sun)
	
	# Fill Light
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-140.0), 0)
	fill.light_color = Color("9cb3c2")
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	scene_root.add_child(fill)
	
	# Floor Plane
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("2a3236")
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	scene_root.add_child(floor_mesh)
	
	# Camera (HKM Perspective: 60 deg pitch, 35 deg FOV)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.position = Vector3(0, 18.2, 10.8)
	camera.rotation = Vector3(deg_to_rad(-60.0), 0, 0)
	scene_root.add_child(camera)
	
	# 4 Rows of Furniture at 8 angles: Workstation, Chair, Cabinet, Partition
	var kinds := ["workstation", "chair", "cabinet", "partition"]
	var z_positions := [-4.6, -1.6, 1.4, 4.4]
	var x_spacing := 2.85
	
	for row in range(kinds.size()):
		var kind: String = kinds[row]
		var z_pos: float = z_positions[row]
		for col in range(8):
			var angle_deg: float = col * 45.0
			var angle_rad: float = deg_to_rad(angle_deg)
			var x_pos: float = (col - 3.5) * x_spacing
			
			var visual := REFINED.make_visual(kind)
			visual.position = Vector3(x_pos, 0, z_pos)
			visual.rotation.y = angle_rad
			scene_root.add_child(visual)
	
	# Render frames
	for frame in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img: Image = game_view.get_texture().get_image()
	var save_path: String = ProjectSettings.globalize_path(output_dir + "/turntable_8way.png")
	img.save_png(save_path)
	print("Saved Turntable 8-way to: ", save_path)

func _render_room_comparison() -> void:
	# Clear previous scene
	for child in game_view.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	# ------------------------------------------------------------
	# A. Render User's Current Version
	# ------------------------------------------------------------
	print("  Rendering User Version...")
	game_view.size = Vector2i(1280, 720)
	USER_ART.enabled = true
	var world_a := WORLD_SCENE.instantiate() as Node3D
	world_a.set("generate_on_ready", false)
	world_a.set("persist_profile", false)
	game_view.add_child(world_a)
	world_a.call("regenerate", 120)
	
	var office_a: Dictionary = {}
	for room in world_a.get("rooms"):
		if String(room.get("sample_key", "")) == "office":
			office_a = room
			break
	var cell_px_a: float = float(world_a.get("CELL_PIXELS"))
	var player_a: Node2D = world_a.get("player")
	player_a.global_position = Vector2(office_a.center_cell) * cell_px_a
	world_a.call("activate_room", office_a.id)
	world_a.get("night_lighting").flashlight.visible = false
	
	for enemy in world_a.get("enemy_root").get_children():
		enemy.set_physics_process(false)
	player_a.set_physics_process(false)
	
	for frame in range(60):
		await get_tree().process_frame
	world_a.set_process(false)
	world_a.set("camera_aim_offset", Vector3.ZERO)
	world_a.call("_update_camera_and_actor_projection", 0.0)
	
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_user_native := game_view.get_texture().get_image()
	img_user_native.save_png(ProjectSettings.globalize_path(output_dir + "/room_user_native.png"))
	
	# 640x360 User Version
	game_view.size = Vector2i(640, 360)
	for frame in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_user_640 := game_view.get_texture().get_image()
	img_user_640.save_png(ProjectSettings.globalize_path(output_dir + "/room_user_640.png"))
	
	world_a.queue_free()
	await get_tree().process_frame
	
	# ------------------------------------------------------------
	# B. Render Refined Prototype Version
	# ------------------------------------------------------------
	print("  Rendering Refined Prototype Version...")
	game_view.size = Vector2i(1280, 720)
	var world_b := WORLD_SCENE.instantiate() as Node3D
	world_b.set("generate_on_ready", false)
	world_b.set("persist_profile", false)
	game_view.add_child(world_b)
	world_b.call("regenerate", 120)
	
	var office_b: Dictionary = {}
	for room in world_b.get("rooms"):
		if String(room.get("sample_key", "")) == "office":
			office_b = room
			break
	var cell_px_b: float = float(world_b.get("CELL_PIXELS"))
	var player_b: Node2D = world_b.get("player")
	player_b.global_position = Vector2(office_b.center_cell) * cell_px_b
	world_b.call("activate_room", office_b.id)
	world_b.get("night_lighting").flashlight.visible = false
	
	for enemy in world_b.get("enemy_root").get_children():
		enemy.set_physics_process(false)
	player_b.set_physics_process(false)
	
	# In-memory swap of 3D visual instances to REFINED assets
	var bridges_root := world_b.get("actor_depth_bridges_root") as Node3D
	if bridges_root != null:
		for bridge in bridges_root.get_children():
			var target = bridge.get("target_furniture")
			if target != null and is_instance_valid(target):
				var kind: String = String(target.get_meta(&"office_furniture_kind", ""))
				if kind.is_empty():
					kind = preload("res://scripts/dream/office_furniture_catalog.gd").resolved_kind(target)
				
				# Remove old visual and replace with refined visual
				var old_vis = bridge.get("visual_instance") as Node3D
				if old_vis != null:
					old_vis.queue_free()
				
				var new_vis: Node3D = REFINED.make_visual(kind)
				bridge.set("visual_instance", new_vis)
				bridge.add_child(new_vis)
				bridge.call("_sync_transform")
				
	# In-memory swap of floor material to REFINED floor surface (ONLY for open office, corridors remain untouched!)
	var floor_root_b := world_b.get("floor_root") as Node3D
	if floor_root_b != null:
		var office_floor_mat: Material = USER_ART.surface("floor")
		var refined_floor_mat: Material = REFINED.surface("floor")
		for child in floor_root_b.get_children():
			var mesh_inst := child as MeshInstance3D
			if mesh_inst != null and mesh_inst.mesh != null:
				for s in range(mesh_inst.mesh.get_surface_count()):
					var surf_mat: Material = mesh_inst.mesh.surface_get_material(s)
					if surf_mat == office_floor_mat:
						mesh_inst.set_surface_override_material(s, refined_floor_mat)
				
	for frame in range(60):
		await get_tree().process_frame
	world_b.set_process(false)
	world_b.set("camera_aim_offset", Vector3.ZERO)
	world_b.call("_update_camera_and_actor_projection", 0.0)
	
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_refined_native := game_view.get_texture().get_image()
	img_refined_native.save_png(ProjectSettings.globalize_path(output_dir + "/room_refined_native.png"))
	
	# 640x360 Refined Version
	game_view.size = Vector2i(640, 360)
	for frame in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_refined_640 := game_view.get_texture().get_image()
	img_refined_640.save_png(ProjectSettings.globalize_path(output_dir + "/room_refined_640.png"))
	
	world_b.queue_free()
	await get_tree().process_frame
	print("Saved all room comparison renders!")
