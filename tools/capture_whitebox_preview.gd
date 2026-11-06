extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)
	
	var player: CharacterBody2D = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var camera_rig: Node3D = scene.get_node("CameraRig")
	var out_dir := "C:/Users/Administrator/.gemini/antigravity/brain/44da030f-7883-4975-aaac-7fa4192cb9e5"
	var vp: Viewport = root.get_viewport()
	
	# --- Shot 1: Standoff at Spawn (Zone 1) ---
	player.global_position = Vector2(192.0, 1100.0) # Z: ~34.4m
	camera_rig.global_position = Vector3(6.0, 0.0, 34.4)
	for i in range(25):
		await process_frame
	var img1: Image = vp.get_texture().get_image()
	img1.save_png(out_dir + "/whitebox_standoff.png")
	
	# --- Shot 2: Tactical Corridor with Alcoves & Laser Beam (Zone 2) ---
	player.global_position = Vector2(192.0, 680.0) # Z: 21.25m
	camera_rig.global_position = Vector3(6.0, 0.0, 21.25)
	for i in range(25):
		await process_frame
	var img2: Image = vp.get_texture().get_image()
	img2.save_png(out_dir + "/whitebox_corridor.png")

	# --- Shot 3: North Chamber Flanking Arena & Barricade (Zone 3) ---
	player.global_position = Vector2(192.0, 240.0) # Z: 7.5m
	camera_rig.global_position = Vector3(6.0, 0.0, 7.5)
	for i in range(25):
		await process_frame
	var img3: Image = vp.get_texture().get_image()
	img3.save_png(out_dir + "/whitebox_arena.png")
	
	# --- Composite Side-by-Side (3 shots) ---
	var w: int = img1.get_width()
	var h: int = img1.get_height()
	var combined: Image = Image.create(w * 3, h, false, img1.get_format())
	combined.blit_rect(img1, Rect2i(0, 0, w, h), Vector2i(0, 0))
	combined.blit_rect(img2, Rect2i(0, 0, w, h), Vector2i(w, 0))
	combined.blit_rect(img3, Rect2i(0, 0, w, h), Vector2i(w * 2, 0))
	
	var composite_path := out_dir + "/whitebox_preview.png"
	combined.save_png(composite_path)
	print("[CAPTURE] Saved standoff to: whitebox_standoff.png")
	print("[CAPTURE] Saved corridor to: whitebox_corridor.png")
	print("[CAPTURE] Saved arena to: whitebox_arena.png")
	print("[CAPTURE] Saved composite preview to: ", composite_path)
	quit(0)
