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
	print("\n=== RUNNING PERFORMANCE MONITOR FLOW GPU VERIFICATION ===")
	
	preload("res://tests/support/background_gpu.gd").start(get_tree())
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

	var main = MAIN_SCENE.instantiate()
	add_child(main)
	
	# 1. Boot up Main scene
	for i in range(12):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	var perf: Node = get_node_or_null("/root/PerformanceMonitor")
	_check(perf != null, "PerformanceMonitor Autoload exists in tree")
	_check(int(perf.get("current_mode")) == 1, "Initial mode is MINI (1)")
	var mini_bar: Control = perf.get("mini_bar") as Control
	_check(mini_bar != null and mini_bar.visible, "Mini HUD bar is visible on screen")
	
	await _capture_gpu_frame("capture_perf_01_mini_hud.png")
	
	# 2. Cycle mode to DETAILED (simulating F3)
	print("Toggling F3 (Detailed Mode)...")
	perf.call("cycle_display_mode")
	for i in range(5):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	_check(int(perf.get("current_mode")) == 2, "Mode switched to DETAILED (2)")
	var detailed_panel: Control = perf.get("detailed_panel") as Control
	_check(detailed_panel != null and detailed_panel.visible, "Detailed Diagnostic Panel visible")
	
	await _capture_gpu_frame("capture_perf_02_detailed_hud.png")
	
	# 3. Fast jump to 3D Dream Dungeon to simulate actual gameplay
	print("Entering 3D Dream Dungeon via gotodream...")
	main.debug_console._execute_command("gotodream")
	
	var transitioned := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if is_instance_valid(main._supported_dream_world) and not main.transition_running:
			transitioned = true
			break
			
	_check(transitioned, "Direct jump to dream level completed")
	
	var world = main._supported_dream_world
	while is_instance_valid(world) and world.floor_transition_in_progress:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	# 4. Simulate combat gameplay, aiming, and movement
	print("Simulating gameplay movement, aim, and resource consumption...")
	var player = world.player
	for step in range(40):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if is_instance_valid(player):
			player.global_position += Vector2(1.5, 0.5)
			get_viewport().warp_mouse(Vector2(500 + sin(step * 0.2) * 80, 260 + cos(step * 0.2) * 50))
			
	var tot_f: int = int(perf.get("total_frames"))
	var pk_dc: int = int(perf.get("peak_draw_calls"))
	var pk_tex: int = int(perf.get("peak_texture_vram_bytes"))
	var pk_nodes: int = int(perf.get("peak_node_count"))
	_check(tot_f > 40, "Recorded frames accumulated in gameplay: %d" % tot_f)
	_check(pk_dc > 0, "DrawCalls recorded: peak %d" % pk_dc)
	_check(pk_tex > 0, "Texture VRAM recorded: %.1f MB" % [float(pk_tex) / 1048576.0])
	_check(pk_nodes > 100, "Node count recorded: peak %d" % pk_nodes)
	
	await _capture_gpu_frame("capture_perf_03_in_dungeon_monitoring.png")
	
	# 5. Open Diagnostic Report (simulating F4)
	print("Opening Diagnostic Report Dialog (F4)...")
	perf.call("open_report_dialog")
	for i in range(8):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		
	_check(bool(perf.get("is_report_open")), "Diagnostic Report Dialog opened")
	var report_dialog: Control = perf.get("report_dialog") as Control
	_check(report_dialog != null and report_dialog.visible, "Report Dialog is visible")
	
	var report_text: String = String(perf.call("generate_report_text"))
	_check(report_text.contains("整局运行概况"), "Report contains Section 1: Session Summary")
	_check(report_text.contains("什么资源占用最大"), "Report contains Section 2: Top Resource Consumers")
	_check(report_text.contains("为什么导致卡顿延迟"), "Report contains Section 3: Why Stutter Happened")
	
	await _capture_gpu_frame("capture_perf_04_diagnostic_report.png")
	
	# 6. Test exporting report to file
	print("Testing Export Report to file...")
	var exported_path: String = String(perf.call("export_report_to_file"))
	_check(FileAccess.file_exists("user://perf_run_report.txt"), "Report file exists on disk: user://perf_run_report.txt")
	if FileAccess.file_exists("user://perf_run_report.txt"):
		var f := FileAccess.open("user://perf_run_report.txt", FileAccess.READ)
		var content := f.get_as_text()
		f.close()
		_check(content.length() > 500, "Exported report file has substantial content (%d bytes)" % content.length())
		print("\n--- PREVIEW OF GENERATED REPORT ---\n", content.substr(0, 1000), "\n...\n")
		
	# 7. Close report dialog and return to main menu
	print("Closing report dialog and verifying return to menu...")
	perf.call("close_report_dialog")
	for i in range(5):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	_check(not bool(perf.get("is_report_open")), "Report Dialog closed cleanly")
	
	main._show_main_menu(false)
	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	_check(main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn", "Return to Main Menu clean")
	
	main.queue_free()
	await get_tree().process_frame
	
	print("\n=== PERFORMANCE MONITOR VERIFICATION FINISHED ===")
	if failures.is_empty():
		print("ALL CHECKS PASSED (0 failures)!")
		get_tree().quit(0)
	else:
		printerr("FAILURES (", failures.size(), "): ", failures)
		get_tree().quit(1)
