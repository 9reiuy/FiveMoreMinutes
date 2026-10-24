extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9"

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run_flow")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] ", label)
	else:
		failures.append(label)
		printerr("  [FAIL] ", label)

func _capture_gpu_frame(file_name: String) -> Image:
	for i in range(3):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var dest_path := ARTIFACT_DIR.path_join(file_name)
	img.save_png(dest_path)
	print("Captured GPU frame: ", dest_path)
	return img

func _run_flow() -> void:
	print("\n=== RUNNING GOTODREAM FLOW GPU VERIFICATION ===")
	
	preload("res://tests/support/background_gpu.gd").start(get_tree())
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

	var main = MAIN_SCENE.instantiate()
	add_child(main)
	
	# 1. Boot up Main scene
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	_check(main.current_screen != null, "Main initial screen loaded")
	_check(main.debug_console != null, "DebugConsole exists on Main")
	await _capture_gpu_frame("capture_gotodream_01_main_menu.png")
	
	# 2. Open DebugConsole and enter gotodream
	var console = main.debug_console
	console._open_console()
	console.command_line.text = "gotodream"
	console.command_line.caret_column = 9
	for i in range(5):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	_check(console.is_open(), "DebugConsole opened successfully")
	await _capture_gpu_frame("capture_gotodream_02_console_input.png")
	
	# 3. Execute command
	print("Submitting 'gotodream' command...")
	console._execute_command("gotodream")
	_check(not console.is_open(), "Console automatically closed on gotodream execution")
	
	# 4. Wait for dream level generation and transition
	var transitioned := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if is_instance_valid(main._supported_dream_world) and not main.transition_running:
			transitioned = true
			break
			
	_check(transitioned, "Direct jump to dream level completed within timeout")
	
	var world = main._supported_dream_world
	_check(world != null and world.is_in_group("dream_world"), "Active world is 3D Dream Dungeon")
	_check(main.current_screen != null and main.current_screen.get("world") == world, "World wrapped in SelectivePixelPreview")
	
	# Check display settings are preserved and active
	var sm = get_node_or_null("/root/SettingsManager")
	_check(sm != null, "SettingsManager accessible")
	if sm != null:
		_check(main.current_screen.get("palette_enabled") == sm.get_palette_enabled(), "Palette setting applied to display viewport")
		_check(main.current_screen.get("selective_enabled") == bool(sm.get_setting(&"pixelation_enabled", true)), "Pixelation setting applied to display viewport")

	# Wait for floor transition
	while is_instance_valid(world) and world.floor_transition_in_progress:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	# 5. Check in-dungeon visual elements
	for i in range(15):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	var player = world.player
	_check(player != null, "Player exists in dungeon")
	var crosshair = get_tree().get_first_node_in_group("custom_crosshairs")
	_check(crosshair != null and crosshair.visible, "Pixel Crosshair active and visible in custom_crosshairs group")
	
	await _capture_gpu_frame("capture_gotodream_03_in_dungeon.png")
	
	# 6. Simulate gameplay interaction & crosshair aim
	get_viewport().warp_mouse(Vector2(450, 260))
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	await _capture_gpu_frame("capture_gotodream_04_combat_aim.png")
	
	# 7. Test Pause Menu & Settings
	print("Testing Pause Menu (ESC) inside dream...")
	main.pause_menu.open_pause()
	main.pause_menu.call("_open_settings")
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	_check(main.pause_menu.is_open(), "Pause Menu opened in dream")
	var settings_panel = main.pause_menu.get_node_or_null("Root/Panel/Layout/SettingsPanel")
	_check(settings_panel != null and settings_panel.visible, "Settings Panel visible inside Pause Menu")
	
	await _capture_gpu_frame("capture_gotodream_05_pause_settings.png")
	
	main.pause_menu.close_pause()
	for i in range(5):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	_check(not main.pause_menu.is_open(), "Pause Menu resumed cleanly")
	
	# 8. Test clean exit back to main menu
	print("Testing clean return to Main Menu...")
	main._show_main_menu(false)
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	_check(main.current_screen != null and main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn", "Clean return to Main Menu verified")

	# 9. Clean up
	main.queue_free()
	await get_tree().process_frame
	
	print("\n=== GOTODREAM VERIFICATION FINISHED ===")
	if failures.is_empty():
		print("ALL CHECKS PASSED (0 failures)!")
		get_tree().quit(0)
	else:
		printerr("FAILURES (", failures.size(), "): ", failures)
		get_tree().quit(1)
