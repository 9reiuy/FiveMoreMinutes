extends SceneTree
## Actual production burst constructors, fixed Camera, process-cold comparison.
var failures:=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.add_child(preload("res://tests/support/render_progress_watchdog.gd").new())
	var family:="glass"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--family="): family=argument.trim_prefix("--family=")
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(42001): quit(2); return
	for frame in 20: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0; paused=true
	var source: Node3D
	var focus: Vector3=world.player_depth_bridge.actor_sprite.global_position
	if family=="glass":
		var window:=BreakableGlassWindow3D.new(); world.add_child(window)
		window.global_position=focus+Vector3(0,.3,0)
		var pane:=MeshInstance3D.new(); window.add_child(pane); window.glass_pane=pane; source=window
	elif family.begins_with("door"):
		var door:=PhysicalDoor3D.new(); door.set_meta(&"office_metal_door",family=="door_metal"); world.add_child(door)
		door.global_position=focus-Vector3(0,door.door_height*.5,0)
		for child in door.get_children():
			if child is Node3D: child.hide()
		source=door
	elif not family.begins_with("furniture") and family not in ["blood_airborne","impact"]:
		push_error("Unknown family"); quit(2); return
	for frame in 4: await RenderingServer.frame_post_draw
	if "--prepared" in OS.get_cmdline_user_args():
		var result: Dictionary=await preload("res://tests/support/destruction_parallel_variant_probe.gd").run(self,world)
		print("DESTRUCTION_FAMILY_PREP ",JSON.stringify(result))
		for frame in 4: await process_frame
		if result.release_ref.get_ref()!=null: failures+=1
	var texture_image:=Image.create(4,4,false,Image.FORMAT_RGBA8); texture_image.fill(Color(.5,.4,.3))
	var texture:=ImageTexture.create_from_image(texture_image)
	var times: Array=[]; var hashes: Array=[]; var counts: Array=[]; var pipeline_rows: Array=[]
	var retained_impact_mesh: Mesh
	for repeat in 3:
		for frame in 4: await RenderingServer.frame_post_draw
		seed(54001)
		var pipeline_before: Dictionary=preload("res://tests/support/render_state_snapshot.gd").pipelines()
		var started:=Time.get_ticks_usec()
		var burst: Node3D
		var effect: BlackBloodEffect
		if family=="glass": source._spawn_shards(Vector2.RIGHT); burst=source.get_node("GlassShards")
		elif family.begins_with("door"): source._spawn_wood_shards(Vector2.RIGHT); burst=source.get_node("DoorShards")
		elif family=="blood_airborne":
			effect=BlackBloodEffect.new(); effect.process_mode=Node.PROCESS_MODE_DISABLED; world.world_effects_root.add_child(effect)
			effect.global_position=world.player.global_position
			for particle_index in 8: effect.airborne_pixels.append({"position":Vector2((particle_index%4-1.5)*4,particle_index/4*4),"height":16.0,"size":2.0,"velocity":Vector2.ZERO,"vertical":0.0,"visible":true})
			var carrier:=BloodAirborneCarrier3D.new(); world.actor_depth_bridges_root.add_child(carrier)
			carrier.configure(effect,world,world.current_room_id,world.camera_3d,32.0,.02); burst=carrier
		elif family=="impact":
			var impact: Node3D=(preload("res://tests/support/legacy_impact_mesh_probe.gd") if "--legacy-impact-mesh" in OS.get_cmdline_user_args() else preload("res://scripts/dream/firearm_impact_visual_3d.gd")).new()
			world.add_child(impact); impact.global_position=focus; impact.setup(Vector3.UP,&"metal")
			impact._emitter.process_mode=Node.PROCESS_MODE_ALWAYS
			if "--retain-impact-material" in OS.get_cmdline_user_args():
				if retained_impact_mesh==null: retained_impact_mesh=impact._emitter.mesh
				else: impact._emitter.mesh=retained_impact_mesh
			burst=impact
		else:
			var debris:=Furniture3DDebris.new(); debris.set_meta(&"test_debris_seed",54001); world.add_child(debris)
			debris.global_position=focus; debris._setup(texture if family=="furniture_textured" else null,6,Vector3.RIGHT); burst=debris
		# Freeze actual tweens explicitly. Tree pause alone does not guarantee
		# a newly created tween cannot consume the current frame's first step.
		for tween in get_processed_tweens(): tween.pause()
		await RenderingServer.frame_post_draw
		times.append((Time.get_ticks_usec()-started)/1000.0)
		if family=="impact":
			# Particle emission starts on a physics step, not necessarily its
			# birth draw. Cover that first step without conflating GPU readback.
			var previous:=Time.get_ticks_usec()
			for frame in 12:
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				times[-1]=maxf(float(times[-1]),float(now-previous)/1000.0); previous=now
		pipeline_rows.append({"before":pipeline_before,"after":preload("res://tests/support/render_state_snapshot.gd").pipelines()})
		counts.append(burst.multi_mesh.visible_instance_count if family=="blood_airborne" else burst._emitter.amount if family=="impact" else burst.get_child_count())
		var image: Image=display.world_viewport.get_texture().get_image(); hashes.append(hash(image.get_data()))
		if family=="impact" and repeat==0 and "--verify-impact-mesh-isolation" in OS.get_cmdline_user_args():
			burst._emitter.speed_scale=0.0
			for frame in 4: await RenderingServer.frame_post_draw
			var before: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			burst._emitter.mesh=burst._create_particle_mesh()
			for frame in 4: await RenderingServer.frame_post_draw
			var after: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			burst.hide()
			for frame in 4: await RenderingServer.frame_post_draw
			var hidden: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			if before!=after or hidden==after: failures+=1
			print("IMPACT_MESH_PIXEL_PARITY ",JSON.stringify({"same_emitter_pixels_equal":before==after,"emitter_has_visible_pixels":hidden!=after}))
		image.save_png("res://.runtime/furniture_face_review/family_%s_%s_%d.png"%[family,"prepared" if "--prepared" in OS.get_cmdline_user_args() else "original",repeat])
		if repeat==0 and "--verify-private-isolation" in OS.get_cmdline_user_args():
			for frame in 4: await RenderingServer.frame_post_draw
			var before: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			var prep: Dictionary=await preload("res://tests/support/destruction_parallel_variant_probe.gd").run(self,world)
			for frame in 4: await RenderingServer.frame_post_draw
			var after: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			if before!=after or prep.release_ref.get_ref()!=null: failures+=1
			print("DESTRUCTION_PRIVATE_ISOLATION ",JSON.stringify({"same_mesh_pixels_equal":before==after,"viewport_released":prep.release_ref.get_ref()==null,"family":family}))
		burst.queue_free()
		if effect!=null: effect.queue_free()
		for frame in 4: await process_frame
	var expected:=8 if family in ["glass","blood_airborne"] else 10 if family.begins_with("door") else 6
	for count in counts:
		if count!=expected: failures+=1
	print("DESTRUCTION_FAMILY_RESULT ",JSON.stringify({"family":family,"prepared":"--prepared" in OS.get_cmdline_user_args(),"first_draw_ms":times,"counts":counts,"pixel_hashes":hashes,"pipelines":pipeline_rows,"failures":failures,"gpu":RenderingServer.get_video_adapter_name(),"frozen_gameplay":true}))
	paused=false; display.queue_free()
	for frame in 4: await process_frame
	quit(1 if failures else 0)
