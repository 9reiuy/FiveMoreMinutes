extends SceneTree
class QueryFixtureBridge extends Node3D:
	var source_actor: Node2D
	var actor_sprite: MeshInstance3D
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display)
	check(world.regenerate(120),"Generate sample")
	for index in 30: await process_frame
	var dressing: Node=world.get_node("SampleWallAndDesktopReview")
	dressing.refresh_assets()
	var window: Node3D=dressing.windows[0].wall.get_ref()
	var origin:=Vector2(window.position.x,window.position.z)*32.0
	for offset in [window.window_inward_normal*80.0,Vector2(0,80),Vector2(0,-80),Vector2(80,0),Vector2(-80,0)]:
		if world._content_position_is_clear(origin+offset,12.0): world.player.global_position=origin+offset; break
	world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	display._process(0.0); world.room_visibility._update_outside_mask()
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	paused=true
	var shine_materials: Dictionary = {}
	for node in world.find_children("*", "CanvasItem", true, false):
		var material := node.material as ShaderMaterial
		if material != null and material.shader != null and "uniform bool shine_enabled" in material.shader.code:
			if not shine_materials.has(material): shine_materials[material] = material.get_shader_parameter("shine_enabled")
			material.set_shader_parameter("shine_enabled", false)
	var scan_only := "--wall-scan-ab" in OS.get_cmdline_user_args()
	var furniture_only := "--furniture-scan-ab" in OS.get_cmdline_user_args()
	var test_key: StringName = &"test_legacy_furniture_scan" if furniture_only else (&"test_legacy_wall_scan" if scan_only else &"test_legacy_occlusion_query")
	var random:=RandomNumberGenerator.new(); random.seed=5501
	var hits:=0; var misses:=0
	var furniture_hits := 0
	var furniture_misses := 0
	# Most approved sample models do not expose a direct actor_sprite mesh.
	# Add one passive query-contract fixture so null/miss-only models cannot
	# falsely certify the positive furniture path. No physics or AI is added.
	var fixture := QueryFixtureBridge.new()
	fixture.source_actor = Node2D.new()
	world.furniture_root.add_child(fixture.source_actor)
	fixture.source_actor.add_to_group(&"damageable_props")
	fixture.actor_sprite = MeshInstance3D.new()
	fixture.actor_sprite.mesh = BoxMesh.new()
	fixture.add_child(fixture.actor_sprite)
	world.actor_depth_bridges_root.add_child(fixture)
	fixture.global_position=world.camera_3d.global_position-Vector3(0,2,0)
	for phase in 3:
		if phase>0:
			world.door_root.rotation.y+=0.13
			for bridge in world.actor_depth_bridges_root.get_children():
				var source: Variant=bridge.get("source_actor")
				var visual: Variant=bridge.get("actor_sprite")
				if is_instance_valid(source) and source.is_in_group(&"damageable_props") and is_instance_valid(visual):
					visual.global_position+=Vector3(0.1,0.0,0.2)
					visual.rotation.y+=0.17
					visual.visible=phase!=1 or visual.get_instance_id()%3!=0
		var points: Array[Vector3]=[]
		var expected: Array[bool]=[]
		var furniture_expected: Array[bool]=[]
		fixture.actor_sprite.visible=true
		var probe_from := fixture.actor_sprite.global_position+Vector3(0,4,0)
		var probe_to := fixture.actor_sprite.global_position-Vector3(0,4,0)
		var expected_hit: bool = world._segment_hits_furniture_visual(probe_from,probe_to)
		var expected_miss: bool = world._segment_hits_furniture_visual(probe_from+Vector3(1000,0,0),probe_to+Vector3(1000,0,0))
		check(expected_hit and not expected_miss,"Independent furniture fixture must exercise a real hit and miss")
		for index in 200:
			var cell: Vector2i=world.floor_cells.keys()[random.randi_range(0,world.floor_cells.size()-1)]
			var point: Vector3=world.to_global(Vector3(cell.x,random.randf_range(0.1,1.4),cell.y))
			points.append(point)
			expected.append(world._actor_is_occluded_by_occluder(point))
			furniture_expected.append(world._segment_hits_furniture_visual(world.camera_3d.global_position, point))
		world._begin_cutout_query_snapshot()
		var actual_hit: bool = world._segment_hits_furniture_visual(probe_from,probe_to)
		var actual_miss: bool = world._segment_hits_furniture_visual(probe_from+Vector3(1000,0,0),probe_to+Vector3(1000,0,0))
		check(actual_hit==expected_hit and actual_miss==expected_miss,"Furniture positive/negative probes changed in batch")
		if actual_hit: furniture_hits+=1
		if not actual_miss: furniture_misses+=1
		for index in points.size():
			var result: bool=world._actor_is_occluded_by_occluder(points[index])
			check(result==expected[index],"Snapshot differs phase %d ray %d" % [phase,index])
			if result: hits+=1
			else: misses+=1
			var furniture_result: bool=world._segment_hits_furniture_visual(world.camera_3d.global_position, points[index])
			check(furniture_result==furniture_expected[index],"Furniture snapshot differs phase %d ray %d" % [phase,index])
			if furniture_result: furniture_hits+=1
			else: furniture_misses+=1
		world._end_cutout_query_snapshot()
		check(not world._cutout_query_snapshot_active and world._cutout_query_walls.is_empty() and world._cutout_query_aabbs.is_empty() and world._cutout_wall_positions.is_empty() and world._cutout_furniture_visuals.is_empty() and world._cutout_furniture_positions.is_empty(),"Query state survives batch")
	check(hits>0 and misses>0,"Test must cover both blocked and unblocked rays")
	check(furniture_hits>0 and furniture_misses>0,"Furniture ray checks must include real hits, not be masked by walls")
	fixture.source_actor.free()
	fixture.free()
	for index in 18:
		var bullet: Node2D=load("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.process_mode=Node.PROCESS_MODE_DISABLED
		bullet.position=world.player.get_projectile_origin()+Vector2(index%6,index/6)*16
		bullet.setup(Vector2.RIGHT,1.0)
		world.add_projectile(bullet,world.player)
	for legacy in [true,false,true]:
		world.set_meta(test_key,legacy)
		var samples: Array[float]=[]
		for index in 100:
			var started:=Time.get_ticks_usec()
			world._update_occlusion_cutouts()
			if index>=20: samples.append(float(Time.get_ticks_usec()-started)/1000.0)
		samples.sort()
		print("OCCLUSION_QUERY_COST ",JSON.stringify({"legacy":legacy,"median_ms":samples[40],"p95_ms":samples[76],"rays_checked":600}))
	world.remove_meta(test_key)
	# Exercise at least one active hole; all-zero slots would be weak evidence.
	var initial_slot: Dictionary = world._get_actor_cutout_slot(world.player)
	var centre_offset: Vector2 = Vector2(world.to_local(initial_slot.world).x, world.to_local(initial_slot.world).z)*32.0-world.player.global_position
	var found_target := false
	for cell in world.floor_cells:
		var point: Vector3=world.to_global(Vector3(cell.x,.48,cell.y))
		if world._project_occlusion_cutout(point,.24).w>.5 and world._actor_is_occluded_by_occluder(point):
			world.player.global_position=Vector2(cell.x,cell.y)*32.0-centre_offset
			world.player_depth_bridge._process(0.0)
			found_target=true; break
	check(found_target,"No visible occluded actor to verify active shader slots")
	world.set_meta(&"test_cutout_slots", [])
	for pixelation in [false,true]:
		for palette in [false,true]:
			display.set_selective_enabled(pixelation); display.set_palette_enabled(palette); display._process(0.0)
			world.room_visibility._update_outside_mask()
			var slot_results: Array = []
			var images: Array[PackedByteArray] = []
			for legacy_scan in [true,false,true]:
				world.set_meta(test_key if furniture_only else &"test_legacy_wall_scan",legacy_scan)
				world._update_occlusion_cutouts()
				var slots: Array = world.get_meta(&"test_cutout_slots").duplicate()
				check(slots.size()==world.OCCLUSION_CUTOUT_SLOT_COUNT and slots.all(func(value: Variant)->bool:return value is Vector4),"Capture actual shader slots, not unsupported renderer getters")
				check(slots.any(func(value: Vector4)->bool:return value.w>.5),"Shader slot comparison has no active cutouts")
				slot_results.append(slots)
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image().get_data())
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/wall_scan_p%d_c%d_%d.png"%[int(pixelation),int(palette),slot_results.size()])
			check(slot_results[0]==slot_results[1] and slot_results[0]==slot_results[2],"Numeric scan changes actual shader cutout slots")
			check(images[0]==images[1] and images[0]==images[2],"Numeric scan changes camera pixels or reference repeat is unstable")
	world.remove_meta(test_key)
	world.remove_meta(&"test_legacy_wall_scan")
	world.remove_meta(&"test_cutout_slots")
	if "--frame-perf" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=0
		world.night_lighting.set_process(false)
		for legacy in [true,false,true]:
			world.set_meta(test_key,legacy)
			var started:=Time.get_ticks_usec()
			while Time.get_ticks_usec()-started<2000000:
				world._update_occlusion_cutouts()
				await RenderingServer.frame_post_draw
			var samples: Array[float]=[]
			started=Time.get_ticks_usec(); var previous:=started
			while Time.get_ticks_usec()-started<15000000:
				world._update_occlusion_cutouts()
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				samples.append(float(now-previous)/1000.0); previous=now
			samples.sort()
			print("OCCLUSION_FIXED_FRAME_PERF ",JSON.stringify({"legacy":legacy,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"samples":samples.size(),"seconds":15,"warmup_seconds":2,"frozen_gameplay":true,"bullets":18,"output":root.get_texture().get_size(),"gpu":RenderingServer.get_video_adapter_name()}))
		world.remove_meta(test_key)
	for material in shine_materials: material.set_shader_parameter("shine_enabled", shine_materials[material])
	paused=false; display.queue_free()
	for index in 4: await process_frame
	print("OCCLUSION_QUERY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures>0 else 0)
