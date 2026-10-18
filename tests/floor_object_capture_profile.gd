extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func make_bridge(world: Node3D,source: Node2D,kind: StringName) -> Node3D:
	if kind==&"weapon": return world._spawn_depth_bridge(source,[^"WeaponSprite"])
	var height := 0.02 if kind==&"debris" else 0.015
	return world._spawn_depth_bridge(source,[^"Sprite2D"] if kind==&"debris" else [^"Shadow"],Vector2(64,64),BaseMaterial3D.BILLBOARD_DISABLED,height,0.0,Vector3(-PI/2,0,0),true)
func detach(pool: Node3D,bridge: Node3D,source: Node2D) -> void:
	if source.tree_exiting.is_connected(bridge._on_source_tree_exiting): source.tree_exiting.disconnect(bridge._on_source_tree_exiting)
	bridge.suspend_projectile()
	if bridge.has_meta(&"floor_object_capture_kind"): pool.release(bridge)
	else: bridge.queue_free()
func pose(sources: Array[Node2D],stage: int) -> void:
	for index in sources.size():
		var source:=sources[index]
		source.fake_height=12.0 if stage==1 else 0.0
		var sprite: Sprite2D=source.get_node("Sprite2D" if index<16 else "WeaponSprite")
		sprite.position.y=-source.fake_height if index<16 else -7.0-source.fake_height
		sprite.rotation=float(index%4)*PI/2+float(stage)*0.2
		sprite.scale=Vector2(0.5,0.5) if stage==2 and index<16 else Vector2.ONE
		sprite.modulate.a=0.5 if stage==2 and index<16 else 1.0
		source.show()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager"); var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(42001): quit(2); return
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	var sources: Array[Node2D]=[]
	for index in 24:
		var source: Node2D=(world.ENVIRONMENT_DEBRIS_SCENE if index<16 else world.WORLD_WEAPON_SCENE).instantiate()
		(world.ground_debris_root if index<16 else world.world_weapon_root).add_child(source)
		source.global_position=world.player.global_position+Vector2((index%6-2)*28,(index/6-2)*28)
		if index<16:
			source.monitoring=false; source.sprite.frame=index; source.set_physics_process(false)
		else:
			source.freeze=true; source.set_weapon_id(["basic","shotgun","assault_rifle","books"][index%4],index%2)
			source.pickup_shine_material.set_shader_parameter(&"shine_enabled",false)
		source.hide(); sources.append(source)
	for index in 3: await RenderingServer.frame_post_draw
	var empty: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var pool: Node3D=world._get_floor_object_capture_pool()
	var images: Array[PackedByteArray]=[]
	var rng_state: int=world._content_rng.state
	for group in 3:
		world.set_meta(&"test_legacy_floor_object_capture",group!=1)
		var times: Array[float]=[]
		for iteration in 12:
			pose(sources,0)
			var current: Array[Node3D]=[]; var owners: Array[Node2D]=[]
			var started:=Time.get_ticks_usec()
			for index in sources.size():
				current.append(make_bridge(world,sources[index],&"debris" if index<16 else &"weapon")); owners.append(sources[index])
				if index>=16: current.append(make_bridge(world,sources[index],&"shadow")); owners.append(sources[index])
			if iteration>=2: times.append((Time.get_ticks_usec()-started)/1000.0)
			await RenderingServer.frame_post_draw
			if iteration==11:
				var nonempty:=0
				for bridge in current:
					if bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(): nonempty+=1
				print("FLOOR_OBJECT_NONEMPTY group=",group," count=",nonempty)
				# The eight top-level weapon Shadow captures are also empty in the
				# original implementation at this world position. Require all 24
				# actual objects; do not invent extra shadows as an optimization.
				if nonempty!=24: failures+=1
				for stage in 3:
					pose(sources,stage)
					for bridge in current: bridge.request_capture_refresh(); bridge._process(0.0)
					await RenderingServer.frame_post_draw
					images.append(display.world_viewport.get_texture().get_image().get_data())
			for index in current.size(): detach(pool,current[index],owners[index])
			for source in sources: source.hide()
			for index in 3: await process_frame
		times.sort()
		print("FLOOR_OBJECT_CREATION group=",group," median_ms=",times[5]," max_ms=",times.back())
	for stage in 3:
		for group in [1,2]:
			var same: bool=images[stage]==images[group*3+stage]
			print("FLOOR_OBJECT_IMAGE stage=",stage," group=",group," same=",same)
			if not same: failures+=1
		if images[stage]==empty: failures+=1; push_error("No object contribution in formal camera")
	# Compare the time-driven shine with BOTH captures rendered in one frame.
	for index in range(16,24):
		var source:=sources[index]; source.show(); source.pickup_shine_material.set_shader_parameter(&"shine_enabled",true)
		world.set_meta(&"test_legacy_floor_object_capture",true)
		var old:=make_bridge(world,source,&"weapon")
		world.set_meta(&"test_legacy_floor_object_capture",false)
		var reused:=make_bridge(world,source,&"weapon")
		await RenderingServer.frame_post_draw
		if old.render_viewport.get_texture().get_image().get_data()!=reused.render_viewport.get_texture().get_image().get_data(): failures+=1; push_error("Same-frame shine capture mismatch")
		detach(pool,old,source); detach(pool,reused,source); source.hide()
	if world._content_rng.state!=rng_state: failures+=1; push_error("Capture binding consumed gameplay RNG")
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("FLOOR_OBJECT_CAPTURE_RESULT failures=",failures)
	quit(1 if failures else 0)
