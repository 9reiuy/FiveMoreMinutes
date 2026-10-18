extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var preview := Control.new()
	root.add_child(preview)
	
	var container := SubViewportContainer.new()
	preview.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	container.add_child(vp)
	
	var layer := CanvasLayer.new()
	layer.layer = 20
	vp.add_child(layer) # initially in vp
	
	var ctrl := Control.new()
	layer.add_child(ctrl)
	
	print("--- Before reparent (child of SubViewport) ---")
	print("layer parent:", layer.get_parent().name)
	print("layer.get_viewport():", layer.get_viewport() == vp)
	print("ctrl.get_viewport():", ctrl.get_viewport() == vp)
	print("ctrl viewport size:", ctrl.get_viewport_rect().size)
	
	print("--- After reparent to preview (child of preview on root) ---")
	layer.reparent(preview)
	print("layer parent:", layer.get_parent().name)
	print("layer.get_viewport() == root:", layer.get_viewport() == root)
	print("ctrl.get_viewport() == root:", ctrl.get_viewport() == root)
	print("ctrl viewport size:", ctrl.get_viewport_rect().size)
	print("layer.custom_viewport:", layer.custom_viewport)
	
	print("--- If layer.custom_viewport = root ---")
	layer.custom_viewport = root
	print("layer.get_viewport() == root:", layer.get_viewport() == root)
	print("ctrl.get_viewport() == root:", ctrl.get_viewport() == root)
	print("ctrl viewport size:", ctrl.get_viewport_rect().size)
	
	quit(0)
