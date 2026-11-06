extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	print("TERMINAL_ASPECT PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
		push_error("Private muted settings were not active before scene entry")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("This test requires the real renderer")
		quit(2)
		return
	root.size = Vector2i(1280, 800)
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	var review: Node = load("res://scenes/preview/terminal_menu_review.tscn").instantiate()
	root.add_child(review)
	for _i in 50:
		await process_frame
	var menu: Node = review.game.current_screen
	var chrome: Control = menu.get_node("TerminalMainSample")
	var inside := true
	for button: Button in chrome.option_buttons:
		inside = inside and root.get_visible_rect().encloses(button.get_global_rect())
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := "res://.runtime/terminal_menu_sample_20261106/main_actual_16_10.png"
	var saved := image.save_png(output) == OK
	var native_size := DisplayServer.window_get_size()
	print("TERMINAL_ASPECT native=", native_size, " root=", root.size, " image=", image.get_size(), " visible=", root.get_visible_rect(), " inside=", inside, " saved=", saved)
	# The project uses a fixed 16:9 canvas; a 16:10 window letterboxes the
	# 1280x720 render instead of stretching it to the window's full height.
	var ok := inside and saved and native_size == Vector2i(1280, 800) and image.get_size() == Vector2i(1280, 720)
	review.queue_free()
	for _i in 5:
		await process_frame
	quit(0 if ok else 1)
