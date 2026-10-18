extends SceneTree
class TimedBlood extends BlackBloodEffect:
	var measured_draw_us:=0
	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		super._draw()
		measured_draw_us=Time.get_ticks_usec()-started
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager"); var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(42001),"Generate formal floor")
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	for index in 3: await RenderingServer.frame_post_draw
	var empty_image: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var blood:=TimedBlood.new(); world.world_effects_root.add_child(blood)
	blood.set_process(false); blood.set_meta(&"blood_floor_visual",true); blood.office_pool_core=true
	blood.position=world.player.global_position; blood.surface_world=world
	for y in range(-48,49):
		for x in range(-48,49):
			if x*x+y*y>2304: continue
			blood.ground_pixels.append(Vector2(x,y)); blood.ground_pixel_types.append(BlackBloodEffect.StampType.PIXEL_CELL)
	# Use a fresh display carrier for this diagnostic subclass: pooled carriers
	# intentionally retain the exact production BlackBloodEffect replica script.
	var bridge: Node3D=world._spawn_depth_bridge(blood,[^"."],Vector2(112,112),BaseMaterial3D.BILLBOARD_DISABLED,world.BLOOD_FLOOR_WORLD_Y,0.0,Vector3(-PI*.5,0,0),false,true)
	var copy: TimedBlood=bridge.clone_roots[0]
	check(copy!=null,"Passive measured blood copy")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var images: Array[PackedByteArray]=[]
	for legacy in [true,false,true]:
		copy.set_meta(&"test_legacy_pixel_draw_hash",legacy)
		var times: Array[float]=[]; var frames: Array[float]=[]
		var previous:=Time.get_ticks_usec()
		for iteration in 140:
			copy.queue_redraw(); bridge.render_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if iteration>=20: times.append(copy.measured_draw_us/1000.0); frames.append((now-previous)/1000.0)
			previous=now
		times.sort(); frames.sort()
		print("BLOOD_PIXEL_DRAW ",JSON.stringify({"legacy":legacy,"pixels":copy.ground_pixels.size(),"draw_median_ms":times[60],"draw_p95_ms":times[114],"fixed_frame_median_ms":frames[60],"fixed_frame_p95_ms":frames[114],"samples":120,"gpu":RenderingServer.get_video_adapter_name(),"forced_one_stain_redraw_each_frame":true,"gameplay_paused":true}))
		images.append(display.world_viewport.get_texture().get_image().get_data())
	check(images[0]==images[1] and images[0]==images[2],"Dense stain camera pixels unchanged")
	check(images[0]!=empty_image,"Blood actually contributes to formal camera")
	check(bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(),"Nonempty stain capture")
	for phase in 5:
		copy.ground_pixels.clear(); copy.ground_pixel_types.clear()
		for index in 80:
			copy.ground_pixels.append(Vector2((index%10-5)*5,index/10*5-20))
			copy.ground_pixel_types.append(index%5)
		copy.ground_visual_scale=.65+phase*.2
		copy.ground_bounds_enabled=phase%2==1; copy.ground_bounds_local=Rect2(-20,-20,40,40)
		copy.pool_growth_active=phase==3; copy._pool_growth_cells.clear()
		if phase==3: copy._pool_growth_cells.append(Vector2.ZERO)
		copy.pool_growth_elapsed=.1; copy.pool_growth_duration=.3
		var poses: Array[PackedByteArray]=[]
		for legacy in [true,false,true]:
			copy.set_meta(&"test_legacy_pixel_draw_hash",legacy)
			copy.queue_redraw(); bridge.render_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			poses.append(display.world_viewport.get_texture().get_image().get_data())
		check(poses[0]==poses[1] and poses[0]==poses[2],"Mixed stamps, scale, clipping and growth phase %d"%phase)
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("BLOOD_PIXEL_DRAW_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
