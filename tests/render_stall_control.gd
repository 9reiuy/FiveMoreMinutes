extends SceneTree
## Diagnostic control only: same application/output renderer without combat.
## Not a gameplay benchmark or an alternative production scene.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=120
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(640,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene:=Node3D.new(); viewport.add_child(scene)
	var camera:=Camera3D.new(); scene.add_child(camera)
	camera.position=Vector3(5,5,5); camera.look_at(Vector3.ZERO)
	camera.current=true
	var cube:=MeshInstance3D.new(); cube.mesh=BoxMesh.new(); scene.add_child(cube)
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.3,.45,.6)
	cube.material_override=material
	var light:=DirectionalLight3D.new(); scene.add_child(light)
	light.rotation_degrees=Vector3(-50,-30,0); light.shadow_enabled=true
	var view:=TextureRect.new(); view.texture=viewport.get_texture()
	view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(view)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var started:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<10000000: await RenderingServer.frame_post_draw
	var samples: Array[float]=[]; var slow: Array=[]
	started=Time.get_ticks_usec(); var previous:=started
	while Time.get_ticks_usec()-started<60000000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec(); var elapsed: float=(now-previous)/1000.0; previous=now
		samples.append(elapsed)
		if elapsed>=40.0:
			slow.append({"seconds":(now-started)/1000000.0,"elapsed_ms":elapsed,
				"last_world_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),
				"last_world_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())})
	samples.sort()
	print("RENDER_STALL_CONTROL ",JSON.stringify({"scenario":"single_cube_no_combat_120fps_cap",
		"gpu":RenderingServer.get_video_adapter_name(),"output":root.get_texture().get_size(),
		"world":viewport.size,"warmup_seconds":10,"sample_seconds":60,"frames":samples.size(),
		"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],
		"p99_ms":samples[floori(samples.size()*.99)],"max_ms":samples.back(),"slow":slow,
		"semantics":"resolved render queries can lag; control does not attribute stalls to OS or driver"}))
	view.queue_free(); viewport.queue_free()
	for index in 4: await process_frame
	quit(0)
