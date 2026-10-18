extends SceneTree
func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	root.unfocusable = true
	root.position = Vector2i(-30000,-30000)
	root.size = Vector2i(32,32)
	root.mode = Window.MODE_MINIMIZED
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new(); camera.position=Vector3(0,0,3); viewport.add_child(camera)
	var mesh := MeshInstance3D.new(); mesh.mesh=BoxMesh.new()
	var material := StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color.ORANGE
	mesh.material_override=material; viewport.add_child(mesh)
	for index in 5:
		await process_frame
		RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	var valid := image.get_size()==Vector2i(1920,1080) and image.get_pixel(960,540).r>0.5 and image.get_pixel(960,540).g>0.1
	print("BACKGROUND_GPU_PROBE ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"actual_window_position":DisplayServer.window_get_position(),"window_size":DisplayServer.window_get_size(),"minimized":root.mode==Window.MODE_MINIMIZED,"focused":DisplayServer.window_is_focused(),"viewport_size":image.get_size(),"nonempty_3d":valid}))
	viewport.queue_free(); await process_frame; quit(0 if valid else 1)
