extends SceneTree

const WORLD_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== RUNNING PIXEL CROSSHAIRS GPU VISUAL CAPTURE ===")
	
	# Mute audio
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

	# Use background_gpu to maintain rendering while native window is minimized
	preload("res://tests/support/background_gpu.gd").start(self)

	root.size = Vector2i(1280, 720)
	var world := WORLD_SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)

	if not world.regenerate(42001):
		printerr("Failed to generate dungeon seed 42001")
		quit(1)
		return

	var room_id := int(world.rooms[0].id)
	var origin: Vector2 = Vector2(world.rooms[0].center_cell) * world.CELL_PIXELS
	world.player.global_position = origin
	world.activate_room(room_id)
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false)

	for frame in range(25):
		await process_frame

	var crosshair: Control = world.run_interface.crosshair
	var player = world.player

	# Explicitly position pointer in the clear center of the screen
	# (In 640x360 logical coordinates, center is 320, 180; place at 370, 180 slightly right of player)
	var fixed_pointer_pos := Vector2(370.0, 180.0)
	player.set_meta(&"presentation_pointer_position", func(): return fixed_pointer_pos)
	
	# -------------------------------------------------------------
	# 1. CIRCLE: Handgun (basic Luger)
	# -------------------------------------------------------------
	print("Testing 1. CIRCLE (Handgun basic)...")
	player.equip_weapon("basic", world.config)
	for f in 10: await process_frame
	await _save_screenshot("capture_crosshair_circle_handgun_idle.png")
	
	crosshair._trigger_recoil(1.0)
	for f in 2: await process_frame
	await _save_screenshot("capture_crosshair_circle_handgun_recoil.png")
	for f in 15: await process_frame

	# -------------------------------------------------------------
	# 2. T_SHAPE: Assault Rifle (assault_rifle)
	# -------------------------------------------------------------
	print("Testing 2. T_SHAPE (Assault Rifle)...")
	player.equip_weapon("assault_rifle", world.config)
	for f in 10: await process_frame
	await _save_screenshot("capture_crosshair_t_shape_rifle_idle.png")

	crosshair._trigger_recoil(1.0)
	for f in 2: await process_frame
	await _save_screenshot("capture_crosshair_t_shape_rifle_recoil.png")
	for f in 15: await process_frame

	# -------------------------------------------------------------
	# 3. BRACKET: Shotgun (shotgun)
	# -------------------------------------------------------------
	print("Testing 3. BRACKET (Shotgun)...")
	player.equip_weapon("shotgun", world.config)
	for f in 10: await process_frame
	await _save_screenshot("capture_crosshair_bracket_shotgun_idle.png")

	crosshair._trigger_recoil(1.0)
	for f in 2: await process_frame
	await _save_screenshot("capture_crosshair_bracket_shotgun_recoil.png")
	for f in 15: await process_frame

	# -------------------------------------------------------------
	# 4. SQUARE: Melee (lucille bat)
	# -------------------------------------------------------------
	print("Testing 4. SQUARE (Melee Lucille Bat)...")
	player.equip_weapon("lucille", world.config)
	for f in 10: await process_frame
	await _save_screenshot("capture_crosshair_square_melee_idle.png")

	crosshair._trigger_recoil(1.0)
	for f in 2: await process_frame
	await _save_screenshot("capture_crosshair_square_melee_recoil.png")
	for f in 15: await process_frame

	# -------------------------------------------------------------
	# 5. Clean up & Exit
	# -------------------------------------------------------------
	world.free()
	print("=== PIXEL CROSSHAIRS GPU VISUAL CAPTURE COMPLETED SUCCESSFULLY ===")
	quit(0)


func _save_screenshot(filename: String) -> void:
	for frame in range(2):
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null:
		var target_path := ARTIFACT_DIR + "/" + filename
		var err := image.save_png(target_path)
		if err != OK:
			printerr("Failed to save screenshot: ", target_path, " code: ", err)
		else:
			print("Saved: ", filename)
