extends SceneTree
## Muted formal-camera comparison. --perf is a static rendering diagnostic;
## --route-perf records real locomotion / live AI combat for 60 seconds each.
## --route-baseline must satisfy the same shooter check; a lighter AI outcome
## is deliberately rejected as an invalid paired comparison.
const WORLD = preload("res://scenes/dream/preview/FurnitureTextureReview.tscn")
const DISPLAY_PATH = "res://scenes/dream/preview/SelectivePixelPreview.tscn"
var checks := 0
var failures := 0
var world: Node3D
var display: Control
var city: Node
var route_shots := {"player":0,"enemy":0}
var route_enemy_shooters: Dictionary={}
var phase_probe: Node
func _slow_frame_context() -> Dictionary:
	var lights: Array=[]
	for light in world.shadow_manager.selected:
		lights.append({"id":light.get_instance_id(),"name":str(light.name),"position":str(light.global_position),"opacity":light.shadow_opacity})
	return {"camera":str(world.camera_3d.global_position),"interior_shadows":lights,"sources":world.world_effects_root.get_child_count(),"bridges":world.actor_depth_bridges_root.get_child_count(),"shots":route_shots.duplicate()}
func _count_route_projectile(node: Node) -> void:
	if not node.is_in_group(&"dream_projectiles"): return
	var shooter: int=node.get("shooter_instance_id")
	if shooter==world.player.get_instance_id(): route_shots.player+=1
	else: route_shots.enemy+=1; route_enemy_shooters[shooter]=true

func _drive_route(elapsed: float) -> void:
	# Camera-relative locomotion uses the real player input branch and collisions.
	if fmod(elapsed,1.0)<.5:
		Input.action_release("move_down"); Input.action_press("move_up")
	else:
		Input.action_release("move_up"); Input.action_press("move_down")

func measure_pool_bursts() -> void:
	paused = true
	var snapshot_only := "--snapshot-burst" in OS.get_cmdline_user_args()
	var prefix := "snapshot_burst_" if snapshot_only else "pool_burst_"
	var images: Array[Image] = []
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_shot_snapshot" if snapshot_only else &"test_legacy_projectile_capture", legacy)
		var samples: Array[float] = []
		for iteration in 12:
			var bullets: Array[Node2D] = []
			world.set_meta(&"test_shot_snapshot_count",0)
			var started := Time.get_ticks_usec()
			for index in 18:
				var bullet := preload("res://scenes/entities/basic_projectile.tscn").instantiate() as Node2D
				bullet.process_mode = Node.PROCESS_MODE_DISABLED
				bullet.position = world.player.get_projectile_origin()
				# Separate the test heads so coincident transparent quads cannot
				# change tie-breaking order merely because slots have older RIDs.
				bullet.position += Vector2(index%6, index/6) * 12.0
				bullet.setup(Vector2.from_angle(index*TAU/18.0), 1.0)
				world.add_projectile(bullet, world.player)
				bullets.append(bullet)
			var elapsed := float(Time.get_ticks_usec()-started)/1000.0
			if snapshot_only: check(int(world.get_meta(&"test_shot_snapshot_count"))==(36 if legacy else 18),"Snapshot resolutions per volley")
			world.remove_meta(&"test_shot_snapshot_count")
			if iteration >= 2: samples.append(elapsed)
			await RenderingServer.frame_post_draw
			if iteration == 11: images.append(await snapshot(prefix+str(images.size())))
			for bullet in bullets: bullet.queue_free()
			await frames(3)
		samples.sort()
		print("SNAPSHOT_BURST " if snapshot_only else "POOL_BURST ", JSON.stringify({"legacy":legacy,"count":18,"median_ms":samples[samples.size()/2],"max_ms":samples.back(),"samples":samples.size()}))
	check(images[0].get_data()==images[1].get_data(),"Pooled versus original capture changes frozen volley pixels")
	var pool: Node3D=world._get_projectile_capture_pool()
	check(pool.created==32 and pool.idle.size()==32,"Volleys allocate new captures or fail to return slots")
	check(pool.idle.all(func(bridge: Node3D)->bool: return not bridge.is_processing() and not bridge.actor_sprite.visible and bridge.render_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Idle pooled captures remain active")
	world.remove_meta(&"test_legacy_projectile_capture")
	if world.has_meta(&"test_legacy_shot_snapshot"): world.remove_meta(&"test_legacy_shot_snapshot")
	var overflow_bullets: Array[Node2D] = []
	for index in 70:
		var bullet := preload("res://scenes/entities/basic_projectile.tscn").instantiate() as Node2D
		bullet.process_mode=Node.PROCESS_MODE_DISABLED
		bullet.position=world.player.get_projectile_origin()
		bullet.setup(Vector2.RIGHT,1.0)
		world.add_projectile(bullet,world.player)
		overflow_bullets.append(bullet)
	check(overflow_bullets.all(func(bullet: Node2D)->bool: return bullet.get_meta(&"depth_visual_bridge").get_ref().source_actor==bullet),"Pool overflow drops or aliases projectiles")
	for bullet in overflow_bullets: bullet.queue_free()
	await frames(4)
	check(pool.idle.size()==64,"Overflow pool does not bound retained idle slots")
	for seed_value in [121,122,120]:
		var old_pool: WeakRef=weakref(pool)
		check(world.regenerate(seed_value),"Pool regeneration failed")
		await frames(3)
		pool=world._get_projectile_capture_pool()
		check(old_pool.get_ref()==null and pool.created==32 and pool.idle.size()==32,"Old floor pool survives regeneration")
	paused=false

func isolate_combat_rendering() -> void:
	# One identical, frozen combat state. Diagnostic hiding never affects
	# gameplay, damage or the production visual settings.
	world.player.set_meta(&"force_weapon_attack", true)
	var deadline := Time.get_ticks_usec() + 2000000
	while get_nodes_in_group(&"dream_projectiles").is_empty() and Time.get_ticks_usec() < deadline:
		await physics_frame
	world.player.remove_meta(&"force_weapon_attack")
	paused = true
	var states: Array[Dictionary] = []
	var counts := {"blood": 0, "projectiles": 0, "lights": 0, "shadow_lights": 0}
	for bridge in world.actor_depth_bridges_root.get_children():
		var source: Variant = bridge.get("source_actor")
		if not is_instance_valid(source): continue
		var category := ""
		if source.is_in_group(&"black_blood_stains"): category = "blood"
		elif source.is_in_group(&"dream_projectiles"): category = "projectiles"
		if category.is_empty(): continue
		counts[category] += 1
		var sprite: Variant = bridge.get("actor_sprite")
		if is_instance_valid(sprite): states.append({"node": sprite, "property": "visible", "value": sprite.visible, "category": category})
		var viewport: Variant = bridge.get("render_viewport")
		if is_instance_valid(viewport): states.append({"node": viewport, "property": "render_target_update_mode", "value": viewport.render_target_update_mode, "category": category})
	for carrier in get_nodes_in_group(&"blood_airborne_carriers"):
		states.append({"node": carrier, "property": "visible", "value": carrier.visible, "category": "blood"})
	for light in world.find_children("*", "Light3D", true, false):
		if not light.visible: continue
		counts.lights += 1
		if light.shadow_enabled: counts.shadow_lights += 1
		states.append({"node": light, "property": "visible", "value": light.visible, "category": "lights"})
		states.append({"node": light, "property": "shadow_enabled", "value": light.shadow_enabled, "category": "shadows"})
	print("COMBAT_ISOLATE_COUNTS ", JSON.stringify(counts))
	check(counts.projectiles > 0, "Projectile isolation must contain an actual live projectile")
	for mode in ["all", "blood", "projectiles", "shadows", "lights", "all"]:
		for state in states:
			state.node.set(state.property, state.value)
			if state.category == mode:
				state.node.set(state.property, SubViewport.UPDATE_DISABLED if state.property == "render_target_update_mode" else false)
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 2000000: await RenderingServer.frame_post_draw
		var samples: Array[float] = []; var draws: Array[float] = []
		start = Time.get_ticks_usec(); var previous := start
		while Time.get_ticks_usec() - start < 5000000:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0); previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.sort(); draws.sort()
		print("COMBAT_ISOLATE ", JSON.stringify({"disabled": mode, "median_ms": samples[samples.size()/2], "p95_ms": samples[floori(samples.size()*.95)], "draw_calls": draws[draws.size()/2], "seconds": 5, "frozen_gameplay": true}))
	for state in states: state.node.set(state.property, state.value)
	paused = false

func measure_route(combat: bool,center: Vector2,city_active := true,legacy_optimization := false) -> Dictionary:
	Input.action_release("move_up"); Input.action_release("move_down")
	for key in [&"test_legacy_projectile_capture",&"test_legacy_muzzle_capture",&"test_legacy_occlusion_query",&"test_legacy_shot_snapshot"]:
		world.set_meta(key,legacy_optimization)
	seed(120)
	check(world.regenerate(120),"Route sample regeneration failed")
	var review_ab := "--review-refresh-ab" in OS.get_cmdline_user_args()
	if "--legacy-review-refresh" in OS.get_cmdline_user_args() or review_ab:
		var review: Node=world.get_node("SampleWallAndDesktopReview")
		var saved_review: Dictionary={}
		for property in [&"world",&"walls",&"windows",&"doors",&"props",&"wall_materials",&"enabled",&"elapsed"]:
			saved_review[property]=review.get(property)
		var legacy_review:=GDScript.new()
		var code:=FileAccess.get_file_as_string("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
		for pair in [["wall_ids.has(wall.get_instance_id())","walls.any(func(r: Dictionary) -> bool: return r.node.get_ref()==wall)"],["window_ids.has(wall.get_instance_id())","windows.any(func(r: Dictionary) -> bool: return r.wall.get_ref()==wall)"],["door_ids.has(door.get_instance_id())","doors.any(func(r: Dictionary) -> bool: return r.door.get_ref()==door)"]]:
			code=code.replace(pair[0],"("+pair[1]+" if diagnostic_use_legacy else "+pair[0]+")" if review_ab else pair[1])
		if review_ab:
			code=code.replace("func refresh_assets() -> void:","var diagnostic_use_legacy := false\nvar diagnostic_refresh_rows: Array=[]\nfunc _diagnostic_original_refresh() -> void:")
			code+="\nfunc refresh_assets() -> void:\n\tdiagnostic_use_legacy=diagnostic_refresh_rows.size()%2==0\n\tvar began:=Time.get_ticks_usec()\n\t_diagnostic_original_refresh()\n\tdiagnostic_refresh_rows.append({\"frame\":Engine.get_process_frames(),\"legacy\":diagnostic_use_legacy,\"refresh_ms\":(Time.get_ticks_usec()-began)/1000.0})\n"
		legacy_review.source_code=code
		check(legacy_review.reload()==OK,"Legacy review diagnostic parses")
		review.set_script(legacy_review)
		for property in saved_review: review.set(property,saved_review[property])
	var enemy_index := 0
	for enemy in world.enemy_root.get_children():
		# Diagnostic reproducibility only; formal AI still uses its normal RNG.
		var rng: Variant = enemy.get("random")
		if rng is RandomNumberGenerator: rng.seed = 12000 + enemy_index
		if "--canonical-identities" in OS.get_cmdline_user_args():
			enemy.set_meta(&"test_steering_identity",10000+enemy_index)
			for property in [&"enemy_blink_time_left",&"neutral_emoji_cooldown",&"neutral_room_travel_cooldown_left",&"separation_query_left",&"perception_update_left"]:
				enemy.set(property,0.0)
		enemy_index += 1
	var capture_cache := not "--uncached-characters" in OS.get_cmdline_user_args()
	for node in world.actor_depth_bridges_root.get_children():
		if node.get("character_projection") == true:
			node.set_meta(&"disable_character_capture_cache", not capture_cache)
	city.enabled=city_active
	await frames(30)
	city=world.get_node("SampleNeonCity"); city.enabled=city_active
	if "--prepare-destruction-materials" in OS.get_cmdline_user_args():
		var was_paused:=paused
		paused=true
		var preparation: Dictionary=await preload("res://scripts/dream/destruction_render_preparation.gd").run(self,world)
		await frames(4)
		check(preparation.viewport_released,"Destruction preparation releases private viewport")
		print("CITY_DESTRUCTION_PREPARATION ",JSON.stringify(preparation))
		paused=was_paused
	world.player.global_position=center
	world.player.invulnerability_left=999.0
	world.player.equip_weapon("assault_rifle",world.config)
	for enemy in world.enemy_root.get_children():
		enemy.process_mode=Node.PROCESS_MODE_INHERIT if combat else Node.PROCESS_MODE_DISABLED
	var aim := center+Vector2(-160,0)
	world.player.set_meta(&"presentation_pointer_position",func() -> Vector2:
		return world.camera_3d.unproject_position(world.to_global(Vector3(aim.x/32.0,.8,aim.y/32.0))))
	world.player.set_meta(&"force_weapon_attack",combat)
	route_shots={"player":0,"enemy":0}; route_enemy_shooters.clear()
	world.world_effects_root.child_entered_tree.connect(_count_route_projectile)
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<10000000:
		_drive_route(float(Time.get_ticks_usec()-start)/1000000.0)
		await RenderingServer.frame_post_draw
	# Warm-up projectiles do not count toward the measured workload.
	route_shots={"player":0,"enemy":0}; route_enemy_shooters.clear()
	var samples: Array[float]=[]; var draws: Array[float]=[]
	var capture_updates: Array[int] = []
	var distance := 0.0; var peak_projectiles := 0; var peak_lights := 0
	var last_position: Vector2=world.player.global_position
	start=Time.get_ticks_usec(); var previous := start
	var review_frame_times: Dictionary={}
	if phase_probe!=null: phase_probe.begin()
	var engine_profile := "--engine-profile" in OS.get_cmdline_user_args()
	if engine_profile:
		check(EngineDebugger.is_active(),"Engine profile requires the local diagnostic receiver")
		if EngineDebugger.is_active(): EngineDebugger.profiler_enable(&"servers",true,[2048,true])
	while Time.get_ticks_usec()-start<60000000:
		_drive_route(float(Time.get_ticks_usec()-start)/1000000.0)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if review_ab: review_frame_times[Engine.get_process_frames()]=float(now-previous)/1000.0
		samples.append(float(now-previous)/1000.0); previous=now
		draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var updating_layers := 0
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge.get("character_projection") != true: continue
			for viewport in bridge.layer_viewports:
				if viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED: updating_layers += 1
		capture_updates.append(updating_layers)
		var position: Vector2=world.player.global_position
		distance+=last_position.distance_to(position); last_position=position
		peak_projectiles=maxi(peak_projectiles,get_nodes_in_group(&"dream_projectiles").size())
		peak_lights=maxi(peak_lights,city.window_lights.filter(func(light: OmniLight3D) -> bool: return light.visible).size())
	Input.action_release("move_up"); Input.action_release("move_down")
	world.player.remove_meta(&"force_weapon_attack")
	world.world_effects_root.child_entered_tree.disconnect(_count_route_projectile)
	if review_ab:
		var review: Node=world.get_node("SampleWallAndDesktopReview")
		var arms: Dictionary={true:{"refresh":[],"frame":[]},false:{"refresh":[],"frame":[]}}
		for row in review.diagnostic_refresh_rows:
			if not review_frame_times.has(row.frame): continue
			arms[row.legacy].refresh.append(row.refresh_ms)
			arms[row.legacy].frame.append(review_frame_times[row.frame])
		for legacy in arms:
			check(arms[legacy].refresh.size()>=30,"Same-world refresh arm has enough live samples")
			var result: Dictionary={"legacy":legacy,"calls":arms[legacy].refresh.size(),"same_live_world":true}
			for key in ["refresh","frame"]:
				var rows: Array=arms[legacy][key]; rows.sort()
				if not rows.is_empty(): result[key+"_ms"]={"median":rows[rows.size()/2],"p95":rows[floori(rows.size()*.95)]}
			print("CITY_REVIEW_REFRESH_AB ",JSON.stringify(result))
		check(arms[false].refresh[arms[false].refresh.size()/2]<arms[true].refresh[arms[true].refresh.size()/2]*.5,"Indexed refresh removes the same-world CPU spike")
	if engine_profile and EngineDebugger.is_active():
		EngineDebugger.profiler_enable(&"servers",false)
		EngineDebugger.send_message(&"diagnostic:profile_finished",[])
	samples.sort(); draws.sort(); capture_updates.sort()
	if phase_probe!=null: print("CITY_ROUTE_PHASE_PROFILE ",JSON.stringify(phase_probe.finish()))
	check(distance>500.0,"Performance route did not exercise actual movement")
	check(peak_lights<=4 and city.scene_root.get_child_count()==4,"Movement or combat exceeds the exterior light/node budget")
	if combat:
		check(route_shots.player>10 and route_shots.enemy>10 and route_enemy_shooters.size()>=2,"Measured workload did not contain genuine multiplayer gunfire")
	if "--combat-isolate" in OS.get_cmdline_user_args(): await isolate_combat_rendering()
	await snapshot("city_route_"+("combat" if combat else "walk")+("" if city_active else "_without_city"))
	return {"legacy_optimization":legacy_optimization,"workload":"live_AI_combat" if combat else "controlled_walk_AI_disabled","character_capture_cache":capture_cache,"character_layers_updating_median":capture_updates[capture_updates.size()/2],"city":city_active,"seconds":60,"warmup_seconds":10,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"draw_calls_median":draws[draws.size()/2],"distance_pixels":distance,"shots":route_shots.duplicate(),"enemy_shooters":route_enemy_shooters.size(),"peak_projectiles":peak_projectiles,"peak_exterior_lights":peak_lights,"output":root.get_texture().get_image().get_size(),"world_viewport":display.world_viewport.size,"gpu":RenderingServer.get_video_adapter_name(),"player_invulnerable":true}

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func frames(count: int) -> void:
	for index in count: await process_frame
func snapshot(name: String) -> Image:
	city._sync_render_snapshot(); await frames(4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.runtime/furniture_face_review/"+name+".png")
	return image

func changed_regions(before: Image,after: Image) -> Dictionary:
	var interior := 0; var exterior := 0
	var from_physical := root.get_final_transform().affine_inverse()
	# Skip HUD at the top and use the same formal ray/mapping as the outside mask.
	for y in range(260,before.get_height()-45,4):
		for x in range(0,before.get_width(),4):
			var old := before.get_pixel(x,y); var current := after.get_pixel(x,y)
			if maxf(absf(old.r-current.r),maxf(absf(old.g-current.g),absf(old.b-current.b)))<.02: continue
			var screen: Vector2=display.window_to_content(from_physical*Vector2(x,y))
			if not screen.is_finite(): continue
			var origin: Vector3=world.camera_3d.project_ray_origin(screen)
			var direction: Vector3=world.camera_3d.project_ray_normal(screen)
			var ground: Vector3=world.to_local(origin+direction*(-origin.y/direction.y))
			if world.floor_cells.has(Vector2i(roundi(ground.x),roundi(ground.z))): interior+=1
			else: exterior+=1
	return {"interior":interior,"exterior":exterior}

func measure(active: bool) -> Dictionary:
	city.enabled=active; city._sync_render_snapshot()
	# Warm the actual shaders, shadow atlas and viewport before timing.
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<10000000: await RenderingServer.frame_post_draw
	var samples: Array[float]=[]
	var draws: Array[float]=[]
	start=Time.get_ticks_usec(); var previous := start
	while Time.get_ticks_usec()-start<15000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0); previous=now
		draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	samples.sort(); draws.sort()
	return {"city":active,"seconds":15,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"draw_calls_median":draws[draws.size()/2],"output":root.get_texture().get_image().get_size(),"world_viewport":display.world_viewport.size,"gpu":RenderingServer.get_video_adapter_name(),"exterior_lights":4 if active else 0,"city_meshes":3 if active else 0}

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	if "--output-1080" in OS.get_cmdline_user_args():
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1920,1080)
		await frames(3)
		await RenderingServer.frame_post_draw
		var actual_output: Vector2i=root.get_texture().get_image().get_size()
		print("CITY_OUTPUT_CONFIGURATION ",JSON.stringify({"requested":Vector2i(1920,1080),"actual":actual_output,"image":root.get_texture().get_image().get_size(),"window":root.size,"logical":root.get_visible_rect(),"scale_size":root.content_scale_size,"scale_factor":root.content_scale_factor,"stretch":root.get_final_transform()}))
		check(actual_output==Vector2i(1920,1080),"1080p output must be measured, not inferred from OS window size")
		if actual_output!=Vector2i(1920,1080): quit(2); return
	if "--phase-profile" in OS.get_cmdline_user_args():
		phase_probe=preload("res://tests/support/frame_phase_probe.gd").new()
		root.add_child(phase_probe)
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	settings.values["pixelation_enabled"]=false; settings.values["palette_enabled"]=false
	settings.values["palette_scheme"]=1
	world=WORLD.instantiate(); world.generate_on_ready=false
	if phase_probe!=null:
		phase_probe.watched_root=world
		phase_probe.context_provider=_slow_frame_context
	display=load(DISPLAY_PATH).instantiate(); display.world=world; display.preview_mode=false
	root.add_child(display)
	check(world.regenerate(120),"Sample failed to generate")
	await frames(30)
	city=world.get_node("SampleNeonCity")
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.invulnerability_left=0.0
	var dressing := world.get_node("SampleWallAndDesktopReview")
	dressing.refresh_assets()
	check(not dressing.windows.is_empty(),"No sample window to inspect")
	var window: Node3D=dressing.windows[0].wall.get_ref()
	var origin := Vector2(window.position.x,window.position.z)*32.0
	for offset in [window.window_inward_normal*80.0,Vector2(0,80),Vector2(0,-80),Vector2(80,0),Vector2(-80,0)]:
		if world._content_position_is_clear(origin+offset,12.0): world.player.global_position=origin+offset; break
	await frames(30)
	world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_actor_projection(0.0)
	city._select_window_lights()
	paused=true
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection") == true:
			bridge.set_meta(&"disable_character_capture_cache", true)
			bridge._set_character_layer_activity(true)
	var uncached_image: Image = await snapshot("character_capture_uncached")
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection") == true:
			bridge.set_meta(&"disable_character_capture_cache", false)
			bridge._set_character_layer_activity(true)
	var cached_image: Image = await snapshot("character_capture_cached")
	check(uncached_image.get_data() == cached_image.get_data(), "Character capture cache changes frozen formal-camera pixels")
	city.window_lights_enabled=false
	var no_light: Image=await snapshot("city_frozen_light_off")
	city.window_lights_enabled=true
	var with_light: Image=await snapshot("city_frozen_light_on")
	var light_diff := changed_regions(no_light,with_light)
	check(light_diff.exterior>5,"Window lights do not visibly illuminate exterior geometry")
	check(light_diff.interior==0,"Window lights change indoor pixels")
	city.height_fog_enabled=false
	var no_fog: Image=await snapshot("city_frozen_fog_off")
	city.height_fog_enabled=true
	var fog: Image=await snapshot("city_frozen_fog_on")
	var fog_diff := changed_regions(no_fog,fog)
	check(fog_diff.exterior>100,"Height haze has no visible effect")
	check(fog_diff.interior==0,"Height haze changes indoor pixels")
	print("CITY_PIXEL_CHECK light=",light_diff," height_haze=",fog_diff)
	for pixelation in [false,true]:
		for palette in [false,true]:
			display.set_selective_enabled(pixelation); display.set_palette_enabled(palette)
			await snapshot("city_pixel%d_palette%d" % [int(pixelation),int(palette)])
			check(city.scene_root.visible and city.window_lights.size()==4,"Display switch loses the exterior city")
	var selected: Array=city.window_lights.map(func(light: OmniLight3D) -> int: return int(light.get_meta(&"candidate_tower",-1)))
	display.set_selective_enabled(false); await frames(3); city._select_window_lights()
	check(city.window_lights.map(func(light: OmniLight3D) -> int: return int(light.get_meta(&"candidate_tower",-1)))==selected,"Pixelation changes window-light priority at the same camera")
	display.set_selective_enabled(true); await frames(3); city._select_window_lights()
	# The transition hides city geometry and all exterior lights, not just its meshes.
	var phase: String=world.transition_phase
	world.transition_phase="CAB_RIDE"; city._sync_render_snapshot()
	check(not city.scene_root.visible and city.window_lights.all(func(light: OmniLight3D) -> bool: return not light.visible),"Cab transition retains exterior lighting")
	world.transition_phase=phase; city._sync_render_snapshot()
	if "--pool-burst" in OS.get_cmdline_user_args() or "--snapshot-burst" in OS.get_cmdline_user_args(): await measure_pool_bursts()
	if "--capture-perf" in OS.get_cmdline_user_args():
		var old_max := Engine.max_fps; Engine.max_fps=0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for cache in [false,true]:
			for bridge in world.actor_depth_bridges_root.get_children():
				if bridge.get("character_projection") == true:
					bridge.set_meta(&"disable_character_capture_cache", not cache)
					bridge._set_character_layer_activity(true)
			var result: Dictionary=await measure(true)
			result["character_capture_cache"] = cache
			result.output=root.get_texture().get_image().get_size()
			print("CHARACTER_FROZEN_PERF ",JSON.stringify(result))
		Engine.max_fps=old_max
	if "--perf" in OS.get_cmdline_user_args():
		var old_max := Engine.max_fps; Engine.max_fps=0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for active in [false,true]:
			var result: Dictionary=await measure(active)
			result.output=root.get_texture().get_image().get_size()
			print("CITY_STATIC_PERF ",JSON.stringify(result))
		Engine.max_fps=old_max
	city.enabled=true; city._sync_render_snapshot(); paused=false
	if "--optimization-ab" in OS.get_cmdline_user_args():
		var old_max := Engine.max_fps; Engine.max_fps=0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var center: Vector2=world.player.global_position
		for legacy in [true,false,true]:
			print("OPTIMIZATION_AB_BEGIN legacy=",legacy)
			print("OPTIMIZATION_AB_PERF ",JSON.stringify(await measure_route(true,center,true,legacy)))
		for key in [&"test_legacy_projectile_capture",&"test_legacy_muzzle_capture",&"test_legacy_occlusion_query",&"test_legacy_shot_snapshot"]: world.remove_meta(key)
		Engine.max_fps=old_max
	if "--route-perf" in OS.get_cmdline_user_args() or "--route-baseline" in OS.get_cmdline_user_args() or "--combat-isolate" in OS.get_cmdline_user_args() or "--pool-combat" in OS.get_cmdline_user_args():
		var old_max := Engine.max_fps; Engine.max_fps=0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var route_center: Vector2=world.player.global_position
		var city_active: bool=not "--route-baseline" in OS.get_cmdline_user_args()
		for combat in ([false,true] if city_active and not "--combat-only" in OS.get_cmdline_user_args() and not "--combat-isolate" in OS.get_cmdline_user_args() and not "--pool-combat" in OS.get_cmdline_user_args() else [true]):
			print("CITY_ROUTE_BEGIN ","combat" if combat else "walk")
			var result: Dictionary=await measure_route(combat,route_center,city_active)
			result.output=root.get_texture().get_image().get_size()
			print("CITY_ROUTE_PERF ",JSON.stringify(result))
		Engine.max_fps=old_max
		# Restore the display adapter after the temporary wall-target shooting fixture.
		world.player.set_meta(&"presentation_pointer_position",Callable(display,"_pointer_content"))
		world.player.invulnerability_left=0.0
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		city.enabled=true; city._sync_render_snapshot()
	var start: Vector2=world.player.global_position
	# Normal movement drives both the formal camera and light selection.
	for index in 40:
		if index==0: Input.action_press("move_up")
		if index==20: Input.action_release("move_up"); Input.action_press("move_down")
		await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/city_motion_%03d.png" % index)
	Input.action_release("move_down")
	check(world.player.global_position.distance_to(start)>1.0,"City scenery blocked normal player movement")
	settings.values=saved
	display.queue_free(); await frames(5)
	print("CITY_RUNTIME_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
