extends SceneTree
const FREEZE=preload("res://tests/support/frozen_render_comparison.gd")
var directory:="user://blood_ground_prepare_camera_test"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):directory=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.size=Vector2i(1280,720)
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
	var frozen:=FREEZE.freeze(self)
	for index in 3: await RenderingServer.frame_post_draw
	var empty: PackedByteArray=root.get_texture().get_image().get_data()
	var images: Array[PackedByteArray]=[]; var shapes: Array=[]
	var reports:Array=[]
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_ground_merge",false)
		var a:=BlackBloodEffect.new(); var b:=BlackBloodEffect.new()
		a.set_meta(&"test_legacy_ground_prepare_order",legacy);a.set_meta(&"test_legacy_compact_ground_cache",legacy)
		a.set_meta(&"test_legacy_ground_commit_loop",legacy)
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
		# Prime the precise local compact atlas, then let the real world merge
		# callback absorb the next source through the reused path.
		var prime:=BlackBloodEffect.new();prime.position=a.position;prime.settled=true;prime.surface_room_id=a.surface_room_id
		prime.set_meta(&"blood_floor_visual",true);prime.set_meta(&"blood_floor_token",a.get_meta(&"blood_floor_token",-1));prime.surface_world=a.surface_world
		prime.ground_pixels.assign([Vector2.ZERO]);prime.ground_pixel_types.assign([4]);world.world_effects_root.add_child(prime);prime.set_process(false)
		check(a.absorb_ground_effect(prime),"prime unchanged dense target");prime.free()
		var incoming_ref: WeakRef=weakref(b)
		world._on_blood_effect_settled(weakref(a)); world._on_blood_effect_settled(weakref(b))
		var reference: WeakRef=a.get_meta(&"depth_visual_bridge")
		var bridge: Node=reference.get_ref()
		bridge._process(0.0)
		for index in 3: await RenderingServer.frame_post_draw
		check(incoming_ref.get_ref()==null,"incoming source consumed exactly once")
		check(bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(),"blood capture is nonempty")
		var picture:Image=root.get_texture().get_image();picture.convert(Image.FORMAT_RGBA8)
		picture.save_png(directory.path_join("camera_%d.png"%images.size()))
		images.append(picture.get_data())
		check(images.back()!=empty,"blood actually visible in formal camera")
		shapes.append([a.ground_pixels.duplicate(),a.ground_pixel_types.duplicate(),a.ground_visual_scale,a.content_version])
		reports.append({"legacy":legacy,"cache_hits":a._compact_merge_hits,"pixels":a.ground_pixels.size()})
		a.queue_free()
		for index in 3: await process_frame
		world._settled_blood_buckets.clear()
	check(images[0]==images[1] and images[0]==images[2],"old/new/old camera pixels identical")
	check(var_to_bytes(shapes[0])==var_to_bytes(shapes[1]) and var_to_bytes(shapes[0])==var_to_bytes(shapes[2]),"ordered blood data, float bits and versions identical")
	check(int(reports[1].cache_hits)>0,"candidate actual world merge uses compact cache")
	var report:Dictionary={"checks":checks,"failures":failures,"camera_pixels_equal":images[0]==images[1] and images[0]==images[2],"states_equal":var_to_bytes(shapes[0])==var_to_bytes(shapes[1]) and var_to_bytes(shapes[0])==var_to_bytes(shapes[2]),"arms":reports,"scope":"formal generated world, actual final Camera with pixelation/palette, frozen A/B/A and real world merge callback; not live combat FPS"}
	var file:=FileAccess.open(directory.path_join("parity.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	FREEZE.restore(self,frozen);settings.values=saved;display.queue_free()
	for index in 4: await process_frame
	print("BLOOD_PREPARE_CAMERA ",JSON.stringify(report))
	quit(1 if failures else 0)
