extends RefCounted
## Prepare native blood draw formats without registering a stain or borrowing
## a live level geometry slot. Simulation and gameplay RNG stay untouched.
static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	var pool: Node3D = world._get_blood_ground_capture_pool()
	var idle_views: Array[SubViewport] = []
	for slot in pool.small_idle + pool.large_idle:
		var view: SubViewport = slot.render_viewport
		idle_views.append(view)
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var space := Node3D.new()
	viewport.add_child(space)
	space.get_world_3d().environment = world.get_world_3d().environment
	var camera := Camera3D.new()
	space.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 2, 2)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for extent in [64, 112]:
		var source := preload("res://scripts/entities/black_blood_effect.gd").new()
		source.process_mode = Node.PROCESS_MODE_DISABLED
		source.add_to_group(&"black_blood_stains")
		source.ground_pixels.assign([Vector2.ZERO, Vector2(3, 0), Vector2(0, 3)])
		source.ground_pixel_types.assign([0, 1, 3])
		source.settled = true
		space.add_child(source)
		var bridge := preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn").instantiate()
		bridge.process_mode = Node.PROCESS_MODE_DISABLED
		space.add_child(bridge)
		var capture: SubViewport = bridge.get_node("ActorDepthViewport")
		capture.size = Vector2i(extent * 2, extent * 2)
		bridge.set_world_camera(camera)
		bridge.configure(source, capture, bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"), null, [^"."], 0.04, 0.0, Vector2(extent, extent), BaseMaterial3D.BILLBOARD_DISABLED, Vector3(-PI * 0.5, 0, 0), false, true)
		bridge._process(0.0)
	var airborne := preload("res://scripts/dream/blood_airborne_carrier_3d.gd").new()
	airborne.process_mode = Node.PROCESS_MODE_DISABLED
	space.add_child(airborne)
	airborne.pixels_per_world_cell = 32.0
	airborne._create_multimesh()
	airborne.multi_mesh.instance_count = 8
	airborne.multi_mesh.visible_instance_count = 1
	airborne.multi_mesh.set_instance_transform(0, Transform3D(camera.global_basis, Vector3(0, 0.2, 0)))
	airborne.multi_instance.visible = true
	for index in 2: await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	for view in idle_views:
		view.get_texture().get_image()
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	for index in 2: await tree.process_frame
	return {"ground_sizes": [128, 224], "airborne": true, "allocated_pool_views": idle_views.size(), "image_bytes": image.get_data().size(), "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
