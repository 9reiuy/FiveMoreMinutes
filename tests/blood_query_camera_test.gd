extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	var settings: Node = root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(42001),"formal floor generation")
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	for index in 3: await RenderingServer.frame_post_draw
	var empty: PackedByteArray = display.world_viewport.get_texture().get_image().get_data()
	var all_images: Array = []; var all_shapes: Array = []
	for legacy in [true,false,true]:
		var capture_comparison := "--capture-ab" in OS.get_cmdline_user_args()
		world.set_meta(&"test_legacy_blood_queries",legacy and not capture_comparison)
		world.set_meta(&"test_legacy_blood_ground_capture",legacy and capture_comparison)
		world._content_rng.seed = 8746
		world.spawn_death_blood_pool(world.player.global_position+Vector2(0,-24),world.current_room_id,1.5)
		var blood: BlackBloodEffect = null
		for child in world.world_effects_root.get_children():
			if child is BlackBloodEffect and child.office_pool_core: blood=child
		check(blood!=null,"actual world death pool spawned")
		if blood==null: break
		blood.set_process(false)
		var bridge: Node = (blood.get_meta(&"depth_visual_bridge") as WeakRef).get_ref()
		var images: Array = []; var shapes: Array = []
		for step in [0.0,0.08,0.4,1.2]:
			blood._process(step); bridge._process(0.0)
			for index in 3: await RenderingServer.frame_post_draw
			var bytes: PackedByteArray = display.world_viewport.get_texture().get_image().get_data()
			check(bytes!=empty,"real pool visible in formal camera")
			check(bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(),"capture not empty")
			images.append(bytes)
			shapes.append([blood.ground_pixels.duplicate(),blood.ground_pixel_types.duplicate(),blood._pool_growth_cells.duplicate(),blood.pool_growth_elapsed])
		all_images.append(images); all_shapes.append(shapes)
		blood.queue_free()
		for index in 4: await process_frame
		world._settled_blood_buckets.clear()
	if all_images.size()==3:
		check(all_images[0]==all_images[1] and all_images[0]==all_images[2],"old/new/old exact image parity at four growth times")
		check(all_shapes[0]==all_shapes[1] and all_shapes[0]==all_shapes[2],"growth data parity")
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("BLOOD_QUERY_CAMERA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
