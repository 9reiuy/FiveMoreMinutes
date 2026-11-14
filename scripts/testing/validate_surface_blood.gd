extends SceneTree
const OUTPUT := "res://.runtime/surface_blood_20261114/promotion/lab"
const METRICS := preload("res://scripts/testing/lab_recorder.gd")
var sample: Control
var checks: Dictionary = {}
var rows: Array[Array] = []
var report: Dictionary = {}

func _initialize() -> void:
	root.size = Vector2i(640,360)
	create_timer(125.0,true,false,true).timeout.connect(func(): print("BLOOD_VALIDATION_TIMEOUT"); quit(3))
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	AudioServer.set_bus_mute(0,true)
	check("private_audio_muted",AudioServer.is_bus_mute(0))
	sample = load("res://scenes/testing/BloodSurfacePreview.tscn").instantiate(); root.add_child(sample)
	while not sample.ready_world: await process_frame
	sample.set_drag_style(false)
	var controller := root.get_node_or_null("DreamTimeController")
	if controller != null:
		controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
		controller.set_process(false); controller.set_physics_process(false)
	Engine.time_scale = 1.0
	sample.world.player.set_physics_process(false)
	sample.hide_hud = true; sample._update_label()
	await _frames(12)
	check("forward_plus",RenderingServer.get_current_rendering_method()=="forward_plus")
	check("four_surface_receivers",sample.blood.receivers.size()==4)
	check("production_pixel_camera",sample.display.world_viewport.size==Vector2i(640,360))
	check("blood_has_no_lights",sample.blood.find_children("*","Light3D",true,false).is_empty())
	var isolation := true
	for receiver in sample.blood.receivers:
		var body: StaticBody3D = receiver.body.get_ref()
		isolation = isolation and body.collision_layer==sample.blood.QUERY_LAYER and body.collision_mask==0
	check("blood_query_bodies_isolated",isolation)
	var events_before: int = sample.world.accepted_blood_events
	sample.set_preset(3); await _frames(4)
	for i in 3:
		sample.world.player._execute_tactical_attack(sample.enemy.global_position)
		await _frames(16)
	check("real_player_projectile_produces_spray",sample.world.accepted_blood_events>events_before)
	sample.blood.clear_blood()
	# Accepted damage events, real receiver geometry, fixed seed.
	for mode in 4:
		sample.set_preset(mode); await _frames(4)
		for i in 3:
			sample.hit_target(); await _seconds(.13)
		await _seconds(1.15)
		_capture("surface_%d.png" % mode)
	var stats: Dictionary = sample.blood.stats()
	report["surfaces"] = stats
	check("mixed_irregular_impact_spots",int(stats.get("mixed_splatters",0))>0)
	check("includes_large_airborne_drops",int(stats.get("emitted_large_drops",0))>0)
	var min_radius := INF; var max_radius := 0.0; var min_angle := INF; var max_angle := -INF
	for shape in sample.blood.stamp_shapes:
		min_radius = minf(min_radius,shape.radius); max_radius = maxf(max_radius,shape.radius)
		min_angle = minf(min_angle,shape.angle); max_angle = maxf(max_angle,shape.angle)
	check("varied_spot_sizes_and_angles",max_radius>min_radius*2.0 and max_angle-min_angle>.8)
	var heavy_travel: Array[float] = []; var pointed_travel: Array[float] = []
	var sharp_angles: Array[float] = []; var sharp_lengths: Array[float] = []
	var tapered_shapes := true
	for shape in sample.blood.stamp_shapes:
		if shape.kind=="heavy": heavy_travel.append(shape.travel)
		elif shape.kind=="pointed":
			pointed_travel.append(shape.travel); sharp_angles.append(shape.angle); sharp_lengths.append(shape.length)
			tapered_shapes = tapered_shapes and shape.length>shape.width*3.0
	check("heavy_drops_and_pointed_splashes_coexist",not heavy_travel.is_empty() and not pointed_travel.is_empty() and pointed_travel.size()<sample.blood.stamp_shapes.size())
	check("sharp_splashes_are_narrow",not pointed_travel.is_empty() and tapered_shapes)
	heavy_travel.sort(); pointed_travel.sort(); sharp_angles.sort(); sharp_lengths.sort()
	check("pointed_splashes_farther_than_heavy_drops",not pointed_travel.is_empty() and not heavy_travel.is_empty() and pointed_travel[pointed_travel.size()/2]>heavy_travel[heavy_travel.size()/2])
	check("pointed_splashes_not_repeated_parallel_lanes",sharp_angles.size()>3 and sharp_angles.back()-sharp_angles.front()>.6 and sharp_lengths.back()>sharp_lengths.front()*1.5)
	var near_only := true; var outer_small := true; var outer_short := true
	var outer_count := 0; var outer_sharp_count := 0; var outer_radius_max := 0.0
	for shape in sample.blood.stamp_shapes:
		if shape.kind=="heavy": near_only = near_only and shape.travel<sample.blood.NEAR_SPLASH_LIMIT
		if shape.travel<sample.blood.FAR_SPLASH_START: continue
		outer_count += 1; outer_radius_max = maxf(outer_radius_max,shape.radius)
		outer_small = outer_small and shape.kind!="heavy" and shape.radius<=.951
		if shape.kind=="pointed":
			outer_sharp_count += 1; outer_short = outer_short and shape.length<=4.201 and shape.width<=.551
	check("heavy_impacts_confined_to_near_zone",not heavy_travel.is_empty() and near_only)
	check("outer_impacts_use_first_sample_small_scale",outer_count>0 and outer_small)
	check("outer_pointed_marks_are_short_and_fine",outer_sharp_count>0 and outer_short)
	report["size_zones"] = {"near_limit_m":sample.blood.NEAR_SPLASH_LIMIT,"outer_start_m":sample.blood.FAR_SPLASH_START,"outer_impacts":outer_count,"outer_pointed":outer_sharp_count,"max_outer_radius_px":outer_radius_max}
	var radial := true; var straight_pixels := true; var visible_rays := 0
	var max_convergence_error := 0.0; var max_pixel_deviation := 0.0
	var max_screen_error := 0.0; var source_matches_wound := true
	for shape in sample.blood.stamp_shapes:
		if shape.kind!="pointed": continue
		var from_source: Vector2 = Vector2(shape.center)-Vector2(shape.source_uv)
		var expected := from_source.normalized()
		var direction := Vector2.from_angle(shape.angle)
		var error := absf(from_source.cross(direction))
		max_convergence_error = maxf(max_convergence_error,error)
		radial = radial and error<.05 and direction.dot(expected)>.9999
		source_matches_wound = source_matches_wound and shape.source_screen_error_px>=0.0 and shape.source_screen_error_px<.05
		max_screen_error = maxf(max_screen_error,shape.source_screen_error_px)
		if not shape.pixels.is_empty(): visible_rays += 1
		for pixel in shape.pixels:
			var deviation := absf((Vector2(pixel)-Vector2(shape.source_uv)).cross(expected))
			max_pixel_deviation = maxf(max_pixel_deviation,deviation)
			straight_pixels = straight_pixels and deviation<=float(shape.width)+1.05
	check("sharp_axes_converge_on_wound",visible_rays>0 and radial)
	check("painted_sharp_pixels_follow_straight_rays",visible_rays>0 and straight_pixels)
	check("visible_radial_centre_matches_wound",visible_rays>0 and source_matches_wound)
	report["radial_geometry"] = {"visible_rays":visible_rays,"max_source_axis_error_px":max_convergence_error,"max_painted_pixel_deviation_px":max_pixel_deviation,"max_wound_screen_error_px":max_screen_error}
	report["impact_shapes"] = sample.blood.stamp_shapes.duplicate(true)
	for name in ["墙壁","地面","家具:workstation","家具:cabinet"]:
		check("impact_"+name,int(stats.receiver_hits.get(name,0))>0)
	var top_hits := 0; var side_hits := 0
	for impact in sample.blood.impacts:
		if String(impact.receiver).begins_with("家具:"):
			if Vector3(impact.normal).dot(Vector3.UP)>.8: top_hits += 1
			if absf(Vector3(impact.normal).y)<.3: side_hits += 1
	check("furniture_top_received",top_hits>0)
	check("furniture_side_received",side_hits>0)
	check("settled_drops_removed",sample.blood.drops.is_empty())
	check("bounded_merged_atlases",sample.blood.faces.size()<=sample.blood.MAX_FACES and sample.blood.faces.size()<stats.impacts)
	var pixel_density := true
	for face in sample.blood.faces:
		var decal: Decal = face.ref.get_ref()
		pixel_density = pixel_density and absf(face.dimensions.x/decal.size.x-32.0)<.001
	check("surface_32_texels_per_metre",pixel_density)
	# Swept path must meet the partition before reaching its far side.
	var wall_hit: Dictionary = sample.blood.trace(sample.world.get_gameplay_world_position(Vector2(5.5,2.0)*32,1.0),sample.world.get_gameplay_world_position(Vector2(5.5,0.0)*32,1.0))
	check("continuous_wall_contact",not wall_hit.is_empty() and String(sample.blood.receivers[int(wall_hit.collider.get_meta(&"blood_receiver"))].name)=="墙壁")
	# Camera changes cannot rotate the physical spray direction.
	var from: Vector3 = sample.world.get_gameplay_world_position(Vector2(7,7)*32,.8)
	var heading: Vector3 = sample.world.global_basis*Vector3(1,0,0)
	sample.blood.emit_spray(from,heading,false,1.0,71432)
	var along := 0
	var common_origin := true
	for drop in sample.blood.drops:
		var horizontal := Vector3(drop.v.x,0,drop.v.z).normalized()
		if horizontal.dot(heading)>.9: along += 1
		common_origin = common_origin and Vector3(drop.origin).is_equal_approx(from)
	check("jet_uses_world_hit_heading",along==sample.blood.drops.size())
	check("burst_droplets_share_wound_origin",not sample.blood.drops.is_empty() and common_origin)
	# Inspect the actual particle batch: a heavy drop carried to the outer zone
	# must use the original fine atlas row and a visibly smaller quad.
	var inspected: Dictionary = sample.blood.drops[0]
	var saved_position: Vector3 = inspected.p
	sample.blood._draw_drops()
	var near_width: float = sample.blood.batch.multimesh.get_instance_transform(0).basis.y.length()
	var near_row: float = sample.blood.batch.multimesh.get_instance_custom_data(0).g
	inspected.p = Vector3(inspected.origin)+heading*(sample.blood.FAR_SPLASH_START+.2)
	sample.blood._draw_drops()
	var far_width: float = sample.blood.batch.multimesh.get_instance_transform(0).basis.y.length()
	var far_row: float = sample.blood.batch.multimesh.get_instance_custom_data(0).g
	check("outer_airborne_drop_uses_original_fine_frame",near_row>.5 and far_row<.5 and far_width<near_width*.5)
	inspected.p = saved_position; sample.blood._draw_drops()
	var paused_at: float = sample.blood.elapsed
	paused = true; await create_timer(.2,true,false,true).timeout
	check("pause_stops_visual_simulation",is_equal_approx(sample.blood.elapsed,paused_at))
	paused = false; await _seconds(1.1)
	# Compare dark emission ON/OFF at unaffected world surfaces.
	sample.set_dark(true); await _frames(12)
	Engine.time_scale = 0.0
	await _frames(4)
	var lit := _capture("dark_blood_on.png")
	for face in sample.blood.faces:
		var decal: Decal = face.ref.get_ref()
		if is_instance_valid(decal): decal.visible = false
	await _frames(4)
	var unlit := _capture("dark_blood_off.png")
	var max_probe_difference := 0.0
	var probes: Array = []
	for position in [Vector3(9,.05,11),Vector3(8,.05,10),Vector3(10.65,1.6,4),Vector3(3.9,.74,4),Vector3(5,2.0,1.1)]:
		var screen: Vector2 = sample.world.camera_3d.unproject_position(sample.world.to_global(position))
		var point := Vector2i(screen)
		if not Rect2i(3,3,634,354).has_point(point): continue
		var delta_max := 0.0
		for y in range(-1,2):
			for x in range(-1,2):
				var a := lit.get_pixelv(point+Vector2i(x,y)); var b := unlit.get_pixelv(point+Vector2i(x,y))
				delta_max = maxf(delta_max,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
		probes.append({"pixel":point,"max_channel_delta":delta_max})
		max_probe_difference = maxf(max_probe_difference,delta_max)
	var orange_difference := 0
	for y in 360:
		for x in 640:
			var a := lit.get_pixel(x,y); var b := unlit.get_pixel(x,y)
			if a.r>.22 and a.r>a.g*1.5 and a.g>a.b*1.25 and a.r-b.r>.08: orange_difference += 1
	check("orange_blood_visible_with_all_lights_off",orange_difference>100)
	check("strict_dark_all_actual_lights_hidden",sample.world.find_children("*","Light3D",true,false).all(func(n:Light3D)->bool: return not n.is_visible_in_tree()))
	check("strict_dark_zero_ambient",sample.environment.ambient_light_energy==0.0)
	check("unpainted_surfaces_not_illuminated",probes.size()>=4 and max_probe_difference<=3.0/255.0)
	report["darkness"] = {"orange_pixels":orange_difference,"unpainted_probes":probes,"max_delta_255":max_probe_difference*255.0}
	Engine.time_scale = 1.0
	for face in sample.blood.faces:
		var decal: Decal = face.ref.get_ref()
		if is_instance_valid(decal): decal.visible = true
	sample.set_dark(false)
	# A receiver-local Decal must move with its actual prop source.
	var owned_faces: Array[Dictionary] = []
	for face in sample.blood.faces:
		if sample.blood.receivers[face.receiver].owner.get_ref()==sample.moved_prop:
			var decal: Decal = face.ref.get_ref()
			owned_faces.append({"ref":weakref(decal),"local":decal.transform,"global":decal.global_transform})
	check("movable_prop_has_attached_blood",not owned_faces.is_empty())
	sample.toggle_prop_motion(); await _seconds(.55); sample.moving = false
	var attached := true
	for face in owned_faces:
		var decal: Decal = face.ref.get_ref()
		attached = attached and decal.transform.is_equal_approx(face.local) and not decal.global_transform.is_equal_approx(face.global)
	check("blood_follows_prop_translation_rotation",attached)
	var moved_hit: Dictionary = sample.blood.trace(sample.moved_prop.to_global(Vector3(0,2,0)),sample.moved_prop.to_global(Vector3(0,.1,0)))
	check("surface_queries_follow_moved_prop",not moved_hit.is_empty() and sample.blood.receivers[int(moved_hit.collider.get_meta(&"blood_receiver"))].owner.get_ref()==sample.moved_prop)
	_capture("prop_moved.png")
	_verify_original_drag()
	report["pixel_drag_art"] = preload("res://scripts/testing/pixel_drag_validation.gd").verify(sample,check,"art" )
	sample.world.clear_preview_blood(); await _frames(4)
	var cleared := true
	for effect in sample.world.world_effects_root.get_children():
		if effect is BlackBloodEffect: cleared = false
	check("clear_removes_original_drag",cleared)
	# Performance: same Camera/art/lights, same accepted hit schedule, no capture.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(sample.display.world_viewport.get_viewport_rid(),true)
	report["performance"] = []
	for candidate in [false,true]:
		sample.blood.clear_blood(); sample.blood.active = candidate; sample.blood.rng.seed = 813615
		sample.moved_prop.source_actor.global_position = Vector2(3,4)*32
		sample.moved_prop.source_actor.rotation = 0; sample.moved_prop._sync_transform()
		await _seconds(.6)
		report.performance.append(await _measure(candidate))
	sample.blood.active = true
	report["drag_performance"] = []
	for pixel_style in [false,true]:
		report.drag_performance.append(await preload("res://scripts/testing/pixel_drag_validation.gd").measure(sample,pixel_style))
	sample.world.clear_preview_blood(); sample.set_drag_style(false)
	# Receiver destruction cannot leave a floating stain or collision receiver.
	sample.set_preset(1); sample.hit_target(); await _seconds(1.0)
	var destroy_refs: Array[WeakRef] = []
	for face in sample.blood.faces:
		if sample.blood.receivers[face.receiver].owner.get_ref()==sample.moved_prop: destroy_refs.append(face.ref)
	sample.moved_prop.source_actor.queue_free(); await _frames(5)
	var removed := not destroy_refs.is_empty()
	for ref in destroy_refs: removed = removed and not is_instance_valid(ref.get_ref())
	check("destroyed_prop_removes_blood",removed)
	sample.blood.clear_blood()
	check("explicit_clear_empties_blood",sample.blood.faces.is_empty() and sample.blood.drops.is_empty())
	# Full reload and the independent whitebox/art gate.
	var previous_world: WeakRef = weakref(sample.world)
	sample.whitebox = true; await sample.rebuild()
	await _frames(8)
	check("old_floor_released",not is_instance_valid(previous_world.get_ref()))
	check("rebuild_has_no_carried_stains",sample.blood.faces.is_empty() and sample.blood.drops.is_empty())
	sample.world.player.set_physics_process(false)
	for mode in 4:
		sample.set_preset(mode); await _frames(2); sample.hit_target(); await _seconds(1.0)
	_capture("whitebox.png")
	var white_stats: Dictionary = sample.blood.stats()
	check("whitebox_surface_contacts",white_stats.receiver_hits.has("家具:workstation") and white_stats.receiver_hits.has("家具:cabinet") and white_stats.receiver_hits.has("墙壁") and white_stats.receiver_hits.has("地面"))
	report["whitebox"] = white_stats
	report["pixel_drag_whitebox"] = preload("res://scripts/testing/pixel_drag_validation.gd").verify(sample,check,"whitebox" )
	# Actual lethal damage still produces one accepted immediate spray.
	var before_lethal: int = sample.world.accepted_blood_events
	sample.set_preset(3); sample.hit_target(true); await _seconds(.5)
	check("lethal_hit_has_immediate_spray",sample.enemy.dead and sample.world.accepted_blood_events>before_lethal)
	var legacy_blood := 0
	var legacy_pixel_smears := true
	sample.world.spawn_corpse_drag_trail(Vector2(6,8)*32,Vector2(6.7,8)*32,1,1.0,24.0)
	for effect in sample.world.world_effects_root.get_children():
		if effect is BlackBloodEffect:
			legacy_blood += 1
			for type in effect.ground_pixel_types: legacy_pixel_smears = legacy_pixel_smears and type==BlackBloodEffect.StampType.PIXEL_CELL
	check("corpse_drag_uses_original_pixel_smear",legacy_blood>0 and legacy_pixel_smears)
	sample.free(); await _frames(5)
	check("sample_world_cleanup",root.find_children("SurfaceBloodCandidate","",true,false).is_empty())
	check("audio_remains_muted",AudioServer.is_bus_mute(0))
	_save_report()
	var failed := 0
	for value in checks.values(): if not value: failed += 1
	print("BLOOD_VALIDATION ",JSON.stringify({"passed":checks.size()-failed,"total":checks.size(),"failed":failed}))
	quit(0 if failed==0 else 2)

func _measure(candidate: bool) -> Dictionary:
	var times: Array = []; var queries: Array = []; var gpu_times: Array = []
	var start := Time.get_ticks_usec(); var previous := start
	var event := 0; var sample_rows: Array[Array] = []
	while Time.get_ticks_usec()-start < 6000000:
		await process_frame
		var now := Time.get_ticks_usec(); var elapsed := (now-start)/1000000.0
		if elapsed >= event*.3 and event < 20:
			sample.set_preset(event%4); sample.hit_target(); event += 1
		var dt := (now-previous)/1000.0; previous = now
		var vp: SubViewport = sample.display.world_viewport
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		times.append(dt); queries.append(sample.blood.query_usec/1000.0); gpu_times.append(gpu)
		sample_rows.append([int(candidate),elapsed,dt,gpu,sample.blood.query_usec/1000.0,sample.blood.drops.size(),sample.blood.faces.size(),vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)])
	rows.append_array(sample_rows)
	return {"candidate":candidate,"duration_s":(Time.get_ticks_usec()-start)/1000000.0,"accepted_hits":event,"frame_wall":METRICS.stats(times),"blood_query_cpu":METRICS.stats(queries),"world_gpu_delayed":METRICS.stats(gpu_times),"blood":sample.blood.stats(),"window_focused":DisplayServer.window_is_focused(),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}

func check(name: String, value: bool) -> void:
	checks[name] = value
	if not value: print("BLOOD_CHECK_FAILED ",name)

func _verify_original_drag() -> void:
	var start := Vector2(6,8)*32
	var finish := start+Vector2(24,3)
	var before_faces: int = sample.blood.faces.size()
	var before_impacts: int = sample.blood.hit_count
	var original_state: int = sample.world._content_rng.state
	var accepted: bool = sample.world.spawn_corpse_drag_trail(start,finish,1,1.0,24.0)
	var actual: BlackBloodEffect
	for effect in sample.world.world_effects_root.get_children():
		if effect is BlackBloodEffect: actual = effect
	check("original_drag_source_created",accepted and is_instance_valid(actual) and not actual.ground_pixels.is_empty())
	if not is_instance_valid(actual): return
	var reference := BlackBloodEffect.new()
	reference.visible = false
	sample.world.world_effects_root.add_child(reference)
	reference.global_position = start; reference.set_surface_context(sample.world,1)
	var reference_rng := RandomNumberGenerator.new(); reference_rng.state = original_state
	reference.setup_drag_smear(reference_rng,4,start,finish,1.0,24.0)
	check("original_drag_pixel_parity",actual.ground_pixels==reference.ground_pixels and actual.ground_pixel_types==reference.ground_pixel_types)
	check("drag_bypasses_new_surface_stamps",sample.blood.faces.size()==before_faces and sample.blood.hit_count==before_impacts)
	check("drag_preserves_content_rng",sample.world._content_rng.state==original_state)
	report["legacy_drag"] = {"source":"production BlackBloodEffect.setup_drag_smear","pixels":actual.ground_pixels.size(),"pixel_parity":actual.ground_pixels==reference.ground_pixels,"width_argument":24.0,"floor_token":actual.get_meta(&"blood_floor_token",-1)}
	reference.free()

func _frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func _seconds(value: float) -> void:
	await create_timer(value,true,false,true).timeout
	await RenderingServer.frame_post_draw

func _capture(name: String) -> Image:
	var image: Image = sample.display.world_viewport.get_texture().get_image()
	image.save_png(OUTPUT+"/"+name); return image

func _save_report() -> void:
	report["checks"] = checks
	report["scope"] = "Independent fixed 4-room production-art and whitebox lab; Forward+/Vulkan 640x360 offscreen; real audio driver, private master muted. Two 6-second matched accepted-hit schedules, no capture/file writes within timing windows. Wall intervals and delayed viewport GPU values are not whole-game certification or per-event GPU attribution."
	var file := FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	file = FileAccess.open(OUTPUT+"/frames.csv",FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["candidate","seconds","frame_wall_ms","world_gpu_ms_delayed","blood_query_cpu_ms","active_drops","atlases","draw_calls_delayed"]))
	for row in rows:
		var strings := PackedStringArray()
		for value in row: strings.append(str(value))
		file.store_csv_line(strings)
	file.close()
