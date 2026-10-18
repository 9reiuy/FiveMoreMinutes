extends RefCounted
## Tests only: retain real GPU viewports while the native window is minimized.
## Ordinary headless uses the dummy renderer on this installed Windows build.
static func start(tree: SceneTree) -> void:
	if DisplayServer.get_name()=="headless": return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	# Minimized windows suppress the automatic render loop. Request actual
	# frames, including SubViewports, through the engine's rendering API.
	tree.process_frame.connect(func() -> void: RenderingServer.force_draw(false))
	print("BACKGROUND_GPU native_window_minimized=",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED," gpu=",RenderingServer.get_video_adapter_name())
