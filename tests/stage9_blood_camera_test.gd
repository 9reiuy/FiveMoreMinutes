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
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(42001),"formal floor generation")
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	for index in 3: await RenderingServer.frame_post_draw
	var empty: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var images: Array[PackedByteArray]=[]; var shapes: Array=[]
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_ground_merge",false)
		var a:=BlackBloodEffect.new(); var b:=BlackBloodEffect.new()
		a.set_meta(&"test_legacy_merge_frontier",legacy)
		a.position=world.player.global_position+Vector2(0,-24)
		b.position=a.position+Vector2(48,0)
		for y in range(-25,25):
			for x in range(-40,40):
				a.ground_pixels.append(Vector2(x,y)); a.ground_pixel_types.append(BlackBloodEffect.StampType.PIXEL_CELL)
		b.ground_pixels.assign([Vector2.ZERO,Vector2(2,2),Vector2(4,0)])
		b.ground_pixel_types.assign([0,1,3])
		for blood in [a,b]:
			blood.settled=true; blood.office_pool_core=true
			check(world._add_3d_blood_effect(blood,world.current_room_id)!=null,"blood enters formal floor")
			blood.set_process(false)
		var incoming_ref: WeakRef=weakref(b)
		world._on_blood_effect_settled(weakref(a)); world._on_blood_effect_settled(weakref(b))
		var c:=BlackBloodEffect.new();c.position=a.position+Vector2(48,0);c.ground_pixels.assign([Vector2(4,1),Vector2(5,1)]);c.ground_pixel_types.assign([4,4]);c.settled=true;c.office_pool_core=true
		check(world._add_3d_blood_effect(c,world.current_room_id)!=null,"second deposit enters formal floor")
		c.set_process(false);world._on_blood_effect_settled(weakref(c))
		var reference: WeakRef=a.get_meta(&"depth_visual_bridge")
		var bridge: Node=reference.get_ref()
		bridge._process(0.0)
		for index in 3: await RenderingServer.frame_post_draw
		check(incoming_ref.get_ref()==null,"incoming source consumed exactly once")
		check(bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(),"blood capture is nonempty")
		images.append(display.world_viewport.get_texture().get_image().get_data())
		check(images.back()!=empty,"blood actually visible in formal camera")
		shapes.append([a.ground_pixels.duplicate(),a.ground_pixel_types.duplicate(),a.ground_visual_scale,a.content_version])
		a.queue_free()
		for index in 3: await process_frame
		world._settled_blood_buckets.clear()
	check(images[0]==images[1] and images[0]==images[2],"old/new/old camera pixels identical")
	check(shapes[0]==shapes[1] and shapes[0]==shapes[2],"ordered blood data and versions identical")
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("STAGE9_BLOOD_CAMERA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
