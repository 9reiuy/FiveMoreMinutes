extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var preview := Control.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	container.add_child(vp)
	
	# Test A: custom_viewport = null
	var layer_a := CanvasLayer.new()
	layer_a.layer = 20
	preview.add_child(layer_a)
	var btn_a := Button.new()
	btn_a.text = "Button A"
	btn_a.position = Vector2(50, 50)
	btn_a.size = Vector2(100, 30)
	var clicked_a := false
	btn_a.pressed.connect(func(): clicked_a = true)
	layer_a.add_child(btn_a)

	# Test B: custom_viewport = root
	var layer_b := CanvasLayer.new()
	layer_b.layer = 30
	layer_b.custom_viewport = root
	preview.add_child(layer_b)
	var btn_b := Button.new()
	btn_b.text = "Button B"
	btn_b.position = Vector2(200, 50)
	btn_b.size = Vector2(100, 30)
	var clicked_b := false
	btn_b.pressed.connect(func(): clicked_b = true)
	layer_b.add_child(btn_b)

	await process_frame
	await process_frame

	# Click btn_a
	var ev_a := InputEventMouseButton.new()
	ev_a.position = Vector2(100, 65)
	ev_a.global_position = Vector2(100, 65)
	ev_a.button_index = MOUSE_BUTTON_LEFT
	ev_a.pressed = true
	root.push_input(ev_a)
	ev_a.pressed = false
	root.push_input(ev_a)
	
	# Click btn_b
	var ev_b := InputEventMouseButton.new()
	ev_b.position = Vector2(250, 65)
	ev_b.global_position = Vector2(250, 65)
	ev_b.button_index = MOUSE_BUTTON_LEFT
	ev_b.pressed = true
	root.push_input(ev_b)
	ev_b.pressed = false
	root.push_input(ev_b)

	await process_frame
	print("Clicked A (custom_viewport null):", clicked_a)
	print("Clicked B (custom_viewport root):", clicked_b)
	quit(0)
