extends SceneTree
## Diagnostic: identical glass shards, per-burst versus retained material.
var failures := 0
var checks := 0
func check_pixels(actual: PackedByteArray, expected: PackedByteArray,label: String) -> void:
	if actual!=expected:
		var count:=0; var maximum:=0
		for index in mini(actual.size(),expected.size()):
			var delta:=absi(int(actual[index])-int(expected[index]))
			if delta>0: count+=1; maximum=maxi(maximum,delta)
		print("DESTRUCTION_VISUAL_DIFF ",label," bytes=",count," max_channel_delta=",maximum)
	check(actual==expected,label)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)],"max":values.back()}
func _initialize() -> void: call_deferred("run")
func isolated_warm(texture: Texture2D) -> void:
	var started:=Time.get_ticks_usec()
	BreakableGlassWindow3D._init_materials()
	if BreakableGlassWindow3D.shard_material==null:
		BreakableGlassWindow3D.shard_material=BreakableGlassWindow3D.glass_material.duplicate() as StandardMaterial3D
		BreakableGlassWindow3D.shard_material.albedo_color=Color(.4,.8,1.0,.6)
	var materials: Array[Material]=[BreakableGlassWindow3D.shard_material]
	for textured in [false,true]:
		var source:=Furniture3DDebris.new()
		source._setup(texture if textured else null,0,Vector3.ZERO)
		materials.append(Furniture3DDebris.shader_variant_anchors[textured])
		source.free()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(16,16); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var space:=Node3D.new(); viewport.add_child(space)
	var camera:=Camera3D.new(); space.add_child(camera)
	camera.position=Vector3(0,1,5); camera.look_at(Vector3.ZERO); camera.current=true
	var sun:=DirectionalLight3D.new(); space.add_child(sun)
	var shadows := "--simple-warm" not in OS.get_cmdline_user_args()
	sun.rotation_degrees=Vector3(-35,45,0); sun.shadow_enabled=shadows
	var point:=OmniLight3D.new(); space.add_child(point)
	point.position=Vector3(2,2,2); point.shadow_enabled=shadows
	var spot:=SpotLight3D.new(); space.add_child(spot)
	spot.position=Vector3(-2,2,3); spot.look_at(Vector3.ZERO); spot.shadow_enabled=shadows
	for index in materials.size():
		var mesh:=MeshInstance3D.new(); mesh.mesh=BoxMesh.new(); mesh.material_override=materials[index]
		mesh.position=Vector3(index-1,0,0)
		if index==0: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		space.add_child(mesh)
	for index in 4: await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	for index in 4: await process_frame
	print("ISOLATED_MATERIAL_WARM ms=",(Time.get_ticks_usec()-started)/1000.0)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(42001),"Formal floor generated")
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	paused=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var pixel_image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	pixel_image.fill(Color(0.5,0.4,0.3))
	var texture:=ImageTexture.create_from_image(pixel_image)
	var prewarm: bool="--isolated-warm" in OS.get_cmdline_user_args()
	var windows: Array[BreakableGlassWindow3D]=[]
	for candidate in [false,true]:
		var window := BreakableGlassWindow3D.new()
		window.set_meta(&"test_legacy_shard_material",not candidate)
		world.add_child(window)
		window.global_position=world.player_depth_bridge.actor_sprite.global_position+Vector3(0,0.3,0)
		var pane:=MeshInstance3D.new(); window.add_child(pane); window.glass_pane=pane
		windows.append(window)
	var geometry: Array=[]; var images: Array[PackedByteArray]=[]
	var release_control := "--release-control" in OS.get_cmdline_user_args()
	for candidate in [false,true,false]:
		if candidate and prewarm: await isolated_warm(texture)
		if release_control and not candidate and images.size()==2:
			BreakableGlassWindow3D.shard_material=null
			for index in 8: await process_frame
		var window: BreakableGlassWindow3D=windows[int(candidate)]
		var creation: Array[float]=[]; var first_draw: Array[float]=[]
		for iteration in 32:
			for index in 4: await RenderingServer.frame_post_draw
			seed(1120+iteration)
			var start:=Time.get_ticks_usec()
			window._spawn_shards(Vector2.RIGHT)
			var created:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var drawn:=Time.get_ticks_usec()
			creation.append((created-start)/1000.0); first_draw.append((drawn-start)/1000.0)
			var carrier: Node3D=window.get_node("GlassShards")
			check(carrier.get_child_count()==8,"Preserves eight shards")
			if iteration==31:
				var shapes: Array=[]
				for shard in carrier.get_children():
					var size: Vector3=shard.mesh.size*shard.scale
					shapes.append({"size":size,"position":shard.position,"rotation":shard.rotation,"material":shard.material_override.albedo_color})
				geometry.append(shapes)
				images.append(display.world_viewport.get_texture().get_image().get_data())
				display.world_viewport.get_texture().get_image().save_png("res://.runtime/destruction_group_%d.png" % (images.size()-1))
			carrier.queue_free()
			for index in 4: await process_frame
		print("DESTRUCTION_MESH_PROFILE ",JSON.stringify({"shared":candidate,"samples":32,"synchronous_ms":stats(creation),"first_draw_ms":stats(first_draw),"gpu":RenderingServer.get_video_adapter_name(),"gameplay_paused":true}))
	for i in 8:
		check(geometry[0][i].size.is_equal_approx(geometry[1][i].size),"Same shard dimensions")
		check(geometry[0][i].position==geometry[1][i].position and geometry[0][i].rotation==geometry[1][i].rotation,"Same seeded pose")
	for group in [1,2]:
		var different:=0
		for index in images[0].size():
			if images[0][index]!=images[group][index]: different+=1
		print("DESTRUCTION_PIXEL_DIFF group=",group," bytes=",different)
	check(images[0]==images[1],"Formal camera original versus retained-material exact shard pixels")
	if not release_control: check(images[0]==images[2],"Warm original repeat exact shard pixels")
	# Actual furniture carrier: separate per-burst fade, bounded retained variants.
	for textured in [false,true]:
		Furniture3DDebris.shader_variant_anchors.clear()
		for candidate in [false,true,false]:
			if not candidate: Furniture3DDebris.shader_variant_anchors.clear()
			if candidate and prewarm: await isolated_warm(texture)
			var first_draw: Array[float]=[]
			for iteration in 24:
				for index in 4: await RenderingServer.frame_post_draw
				var debris:=Furniture3DDebris.new()
				debris.set_meta(&"test_legacy_debris_material_lifetime",not candidate)
				debris.position=windows[0].position
				var start:=Time.get_ticks_usec()
				world.add_child(debris)
				debris._setup(texture if textured else null,6,Vector3.RIGHT)
				await RenderingServer.frame_post_draw
				first_draw.append((Time.get_ticks_usec()-start)/1000.0)
				check(debris.pieces.size()==6 and debris.material_override.albedo_color.a==1.0,"Furniture count and initial opacity unchanged")
				debris._process(1.4)
				check(is_equal_approx(debris.material_override.albedo_color.a,0.5),"Per-burst fade unchanged")
				if candidate and iteration>0:
					check(debris.material_override!=Furniture3DDebris.shader_variant_anchors[textured],"Fresh mutable fade material per later burst")
				debris.queue_free()
				for index in 4: await process_frame
			print("FURNITURE_MATERIAL_PROFILE ",JSON.stringify({"retained":candidate,"textured":textured,"samples":24,"first_draw_ms":stats(first_draw),"gameplay_paused":true}))
	check(Furniture3DDebris.shader_variant_anchors.size()<=2,"Bounded material-variant retention")
	if "--visual-matrix" in OS.get_cmdline_user_args():
		var visual_material_anchors: Array[Material]=[]
		var original_control := "--visual-control" in OS.get_cmdline_user_args()
		for mode in [[true,true],[true,false],[false,true],[false,false]]:
			display.set_selective_enabled(mode[0]); display.set_palette_enabled(mode[1]); display._process(0.0)
			for index in 4: await RenderingServer.frame_post_draw
			var empty: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
			var reference: Array[PackedByteArray]=[]
			for candidate in [false,true]:
				var window: BreakableGlassWindow3D=windows[int(candidate)]
				window.set_meta(&"test_legacy_shard_material",not candidate or original_control)
				seed(65012)
				window._spawn_shards(Vector2.RIGHT)
				var tween: Tween=get_processed_tweens().back()
				var carrier: Node3D=window.get_node("GlassShards")
				visual_material_anchors.append(carrier.get_child(0).material_override)
				for pose in [0.0,0.1,0.2,0.15]:
					tween.custom_step(pose)
					await RenderingServer.frame_post_draw
					var pixels: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
					if candidate: check_pixels(pixels,reference.pop_front(),"Glass animation camera parity mode=%s step=%s" % [mode,pose])
					else: reference.append(pixels)
					if pose==0.0: check(pixels!=empty,"Visible actual glass shards")
					tween.pause()
				carrier.queue_free(); tween.kill()
				for index in 4: await process_frame
			for textured in [false,true]:
				var references: Array[PackedByteArray]=[]
				var reference_state: Array=[]
				for candidate in [false,true]:
					var debris:=Furniture3DDebris.new()
					debris.set_meta(&"test_legacy_debris_material_lifetime",not candidate or original_control)
					debris.set_meta(&"test_debris_seed",5170)
					debris.position=windows[0].position
					world.add_child(debris); debris._setup(texture if textured else null,6,Vector3.RIGHT)
					visual_material_anchors.append(debris.material_override)
					var state: Array=[]
					for piece in debris.pieces:
						state.append([piece.mesh.position,piece.velocity,piece.rot_axis,piece.rot_speed,piece.mesh.mesh.size])
					if candidate: check(state==reference_state,"Identical furniture seeded geometry and kinematics")
					else: reference_state=state
					for step in [0.0,0.05,1.2,0.15]:
						debris._process(step)
						await RenderingServer.frame_post_draw
						var pixels: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
						if candidate: check_pixels(pixels,references.pop_front(),"Furniture animation and fade camera parity mode=%s textured=%s step=%s" % [mode,textured,step])
						else: references.append(pixels)
						if step==0.0: check(pixels!=empty,"Visible actual furniture shards")
					debris.queue_free()
					for index in 4: await process_frame
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("DESTRUCTION_MESH_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
