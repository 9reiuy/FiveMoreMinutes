extends SceneTree
## Fresh viewport cohorts: CPU precreation versus one hidden 2D load-time draw.
## Diagnostic only; never installs prewarm behavior into production.
const POOL=preload("res://scripts/dream/floor_object_capture_pool.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)],"max":values.back()}
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
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	paused=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var sources: Array[Node2D]=[]
	for index in 32:
		var source: Node2D=world.ENVIRONMENT_DEBRIS_SCENE.instantiate()
		world.ground_debris_root.add_child(source)
		source.global_position=world.player.global_position+Vector2(index%8-4,index/8-2)*20
		source.sprite.frame=index; source.monitoring=false; source.hide()
		sources.append(source)
	for index in 3: await RenderingServer.frame_post_draw
	var empty_image: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var images: Array[PackedByteArray]=[]
	for warmed in [false,true,false]:
		var first_frames: Array[float]=[]; var acquire_times: Array[float]=[]
		for iteration in 10:
			var before: Array=world.actor_depth_bridges_root.get_children()
			var pool:=POOL.new(); world.actor_depth_bridges_root.add_child(pool)
			pool.prewarm(world.camera_3d,world.player_depth_bridge.volume_shadow_enabled)
			var carriers: Array[Node3D]=[]
			for node in world.actor_depth_bridges_root.get_children():
				if node!=pool and not before.has(node): carriers.append(node)
			check(carriers.size()==80,"Fresh complete floor-object pool")
			for carrier in carriers:
				check(not carrier.actor_sprite.visible and not carrier.configured,"Idle presentation hidden and unbound")
				if warmed:
					for copy in carrier.clone_roots: copy.show()
					carrier.render_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			for index in 3: await RenderingServer.frame_post_draw
			for carrier in carriers: carrier.suspend_projectile()
			for index in 3: await RenderingServer.frame_post_draw
			var active: Array[Node3D]=[]
			var start:=Time.get_ticks_usec()
			for source in sources:
				source.show(); active.append(pool.acquire(source,&"debris",world.camera_3d,world.player_depth_bridge.volume_shadow_enabled))
			var acquired:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var drawn:=Time.get_ticks_usec()
			if iteration>=2:
				acquire_times.append((acquired-start)/1000.0); first_frames.append((drawn-start)/1000.0)
			if iteration==9:
				var nonempty:=0
				for carrier in active:
					if carrier.render_viewport.get_texture().get_image().get_used_rect().has_area(): nonempty+=1
				check(nonempty==32,"First activation draws all 32 real sprites")
				images.append(display.world_viewport.get_texture().get_image().get_data())
			for index in active.size():
				var carrier:=active[index]; var source:=sources[index]
				if source.tree_exiting.is_connected(carrier._on_source_tree_exiting): source.tree_exiting.disconnect(carrier._on_source_tree_exiting)
			for carrier in carriers:
				carrier.projectile_pool_release=Callable(); carrier.queue_free()
			pool.queue_free()
			for source in sources: source.hide()
			for index in 8: await process_frame
		print("CAPTURE_FIRST_USE ",JSON.stringify({"hidden_load_draw":warmed,"first_draw_elapsed_ms":stats(first_frames),"synchronous_acquire_ms":stats(acquire_times),"samples":8,"sources":32,"new_slots_per_sample":80,"gameplay_paused":true,"gpu":RenderingServer.get_video_adapter_name()}))
	check(images[0]==images[1] and images[0]==images[2],"Load-time target warm-up preserves formal camera pixels")
	check(images[0]!=empty_image,"Actual sprites visible in formal camera")
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("CAPTURE_FIRST_USE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
