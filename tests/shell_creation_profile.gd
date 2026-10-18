extends SceneTree
## Same source creation/setup/bridge sequence as spawn_shell_ejection.
## Frozen formal world diagnostic; not a live-combat FPS benchmark.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings:=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	world.set_meta(&"test_legacy_shell_atlas","--no-atlas" in OS.get_cmdline_user_args())
	display.set_selective_enabled(not OS.get_cmdline_user_args().has("--no-pixel"))
	display.set_palette_enabled(not OS.get_cmdline_user_args().has("--no-palette"))
	if not world.regenerate(120): quit(1); return
	for index in 30: await process_frame
	for room in world.rooms:
		if String(room.get("sample_key",""))=="office": world.player.global_position=Vector2(room.grid_rect.get_center())*32.0; break
	world.camera_aim_offset=Vector3.ZERO; world.transition_phase=&"IDLE"
	world._update_camera_and_actor_projection(0.0); world.room_visibility._update_outside_mask()
	paused=true
	await RenderingServer.frame_post_draw
	var empty_image:=world.get_viewport().get_texture().get_image()
	var samples: Dictionary={"source_us":[],"tree_us":[],"setup_us":[],"bridge_us":[],"total_us":[]}
	var ab := OS.get_cmdline_user_args().has("--ab")
	var failures := 0
	var pool: Node3D = world._get_shell_capture_pool()
	var rng_state: int = world._content_rng.state
	var images: Array[Image] = []
	var source_states: Array = []
	for group in (3 if ab else 1):
		samples={"source_us":[],"tree_us":[],"setup_us":[],"bridge_us":[],"total_us":[]}
		for iteration in 12:
			world._content_rng.state=rng_state
			var current: Array[Node2D]=[]
			var totals: Dictionary={"source_us":0,"tree_us":0,"setup_us":0,"bridge_us":0}
			var burst_start:=Time.get_ticks_usec()
			for index in 18:
				var started:=Time.get_ticks_usec()
				var effect: Node2D=world.SHELL_EFFECT_SCENE.instantiate()
				totals.source_us+=Time.get_ticks_usec()-started
				started=Time.get_ticks_usec()
				world.world_effects_root.add_child(effect)
				effect.global_position=world.player.global_position+(Vector2.ZERO if "--overlap" in OS.get_cmdline_user_args() else Vector2(index%6,index/6)*24.0)
				totals.tree_us+=Time.get_ticks_usec()-started
				started=Time.get_ticks_usec()
				effect.setup(world.WEAPON_VISUALS.get_shell(["pistol","assault_rifle","shotgun"][index%3]),Vector2.RIGHT.rotated(index*TAU/8.0),world._content_rng,world.EMPLOYEE_CONFIG.shell_effect_lifetime,world.EMPLOYEE_CONFIG.shell_effect_fake_gravity)
				totals.setup_us+=Time.get_ticks_usec()-started
				started=Time.get_ticks_usec()
				if group==1:
					pool.acquire(effect,world.camera_3d)
				else:
					world._spawn_depth_bridge(effect,[^"ShellSprite"],Vector2(64,64),BaseMaterial3D.BILLBOARD_ENABLED,0.1,0.0,Vector3.ZERO,true,true)
				totals.bridge_us+=Time.get_ticks_usec()-started
				current.append(effect)
			if iteration>=2:
				for key in totals: samples[key].append(totals[key])
				samples.total_us.append(Time.get_ticks_usec()-burst_start)
			await RenderingServer.frame_post_draw
			if iteration==11:
				for stage in 3:
					if stage>0:
						for step in (12 if stage==1 else 48):
							for effect in current: effect._process(1.0/60.0)
						for effect in current:
							var reference: WeakRef=effect.get_meta(&"depth_visual_bridge")
							reference.get_ref()._process(0.0)
						await RenderingServer.frame_post_draw
					var state: Array=[world._content_rng.state]
					for effect in current:
						state.append([effect.position,effect.shell_sprite.position,effect.shell_sprite.rotation,effect.height,effect.ground_velocity,effect.lifetime])
					source_states.append(state)
					images.append(world.get_viewport().get_texture().get_image())
			for effect in current: effect.queue_free()
			for index in 3: await process_frame
		var output: Dictionary={"group":group,"pooled":group==1,"shells_per_burst":18,"samples":10,"frozen_gameplay":true,"gpu":RenderingServer.get_video_adapter_name()}
		for key in samples:
			samples[key].sort()
			output[key]={"median":samples[key][5],"max":samples[key].back()}
		print("SHELL_CREATE_PROFILE ",JSON.stringify(output))
	if ab:
		if empty_image.get_data()==images[0].get_data(): failures+=1; print("FAIL shells not visible")
		for stage in 3:
			for group in [1,2]:
				if source_states[stage]!=source_states[group*3+stage]: failures+=1; print("FAIL shell state ",group," stage ",stage)
				if images[stage].get_data()!=images[group*3+stage].get_data(): failures+=1; print("FAIL shell image ",group," stage ",stage)
		images[0].save_png("res://.runtime/furniture_face_review/shell_pool_old.png")
		images[3].save_png("res://.runtime/furniture_face_review/shell_pool_new.png")
		if pool.created!=32 or pool.idle.size()!=32: failures+=1
		print("SHELL_POOL_COMPARE ",JSON.stringify({"failures":failures,"created":pool.created,"idle":pool.idle.size(),"reused":pool.reused}))
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	quit(1 if failures else 0)
