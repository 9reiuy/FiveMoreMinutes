extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	var player: CharacterBody2D = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var camera_rig: Node3D = scene.get_node("CameraRig")
	var laser_beam: CSGBox3D = scene.get_node("TutorialGeometry/Laser_Sightline_Beam")
	var out_dir := "C:/Users/Administrator/.gemini/antigravity/brain/44da030f-7883-4975-aaac-7fa4192cb9e5"
	var vp: Viewport = root.get_viewport()

	# --- Shot 1: Standoff at Spawn (Zone 1) ---
	player.global_position = Vector2(192.0, 1120.0) # Z: 35.0m
	scene.camera_base_ground_position = Vector3(6.0, 0.0, 35.0)
	camera_rig.global_position = Vector3(6.0, 0.0, 35.0)
	for i in range(15):
		await process_frame
	var img1: Image = vp.get_texture().get_image()
	img1.save_png(out_dir + "/combat_standoff.png")

	# --- Shot 2: Tactical Corridor with Melee Patrols (Zone 2) ---
	player.global_position = Vector2(192.0, 680.0) # Z: 21.25m
	scene.camera_base_ground_position = Vector3(6.0, 0.0, 21.25)
	camera_rig.global_position = Vector3(6.0, 0.0, 21.25)
	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	if enemy_root.get_child_count() > 1:
		var patrol_enemy = enemy_root.get_child(1) # corridor enemy at y=600 or 780
		patrol_enemy.take_damage(6.0, patrol_enemy.global_position, 150.0, &"player_projectile")
	for i in range(15):
		await process_frame
	var img2: Image = vp.get_texture().get_image()
	img2.save_png(out_dir + "/combat_corridor.png")

	# --- Shot 3: North Barricade with Armed Shooter & Laser Sightline (Zone 3) ---
	player.global_position = Vector2(192.0, 260.0) # Z: 8.1m
	scene.camera_base_ground_position = Vector3(6.0, 0.0, 8.1)
	camera_rig.global_position = Vector3(6.0, 0.0, 8.1)
	laser_beam.visible = true
	laser_beam.transform.origin = Vector3(6.0, 0.85, 17.5)
	laser_beam.size = Vector3(0.08, 0.08, 23.0)
	for i in range(15):
		await process_frame
	var img3: Image = vp.get_texture().get_image()
	img3.save_png(out_dir + "/combat_arena.png")

	# --- Composite Side-by-Side ---
	var w: int = img1.get_width()
	var h: int = img1.get_height()
	var combined: Image = Image.create(w * 3, h, false, img1.get_format())
	combined.blit_rect(img1, Rect2i(0, 0, w, h), Vector2i(0, 0))
	combined.blit_rect(img2, Rect2i(0, 0, w, h), Vector2i(w, 0))
	combined.blit_rect(img3, Rect2i(0, 0, w, h), Vector2i(w * 2, 0))

	var composite_path := out_dir + "/combat_preview.png"
	combined.save_png(composite_path)
	print("[CAPTURE] Successfully captured combat preview montage!")
	quit(0)
