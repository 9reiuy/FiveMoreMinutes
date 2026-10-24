extends SceneTree
const OUT="res://.runtime/indoor_dust_v3_20261023"
var world: Node
var display: Control
var dust: Node
var cleanup_root: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image(); image.save_png(output_directory()+"/"+label+".png"); return image
func output_directory() -> String: return OUT
func prepare_world() -> void:
	world=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false
	display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.preview_mode=false; display.world=world; root.add_child(display)
	cleanup_root=display
	check(world.regenerate(120),"Real independent furniture sample generates")
func changed(a: Image,b: Image) -> int:
	var total:=0
	for y in a.get_height():
		for x in a.get_width():
			var c:=a.get_pixel(x,y); var d:=b.get_pixel(x,y)
			if maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))>.015: total+=1
	return total
func brightest_changed(before: Image,after: Image,area: Rect2i) -> float:
	var brightness:=0.0
	for y in range(maxi(0,area.position.y),mini(after.get_height(),area.end.y)):
		for x in range(maxi(0,area.position.x),mini(after.get_width(),area.end.x)):
			var a:=before.get_pixel(x,y); var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.02:
				brightness=maxf(brightness,(b.r+b.g+b.b)/3.0)
	return brightness
func changed_centre(before: Image,after: Image,area: Rect2i) -> Vector2:
	var total:=Vector2.ZERO; var count:=0
	for y in range(maxi(0,area.position.y),mini(after.get_height(),area.end.y)):
		for x in range(maxi(0,area.position.x),mini(after.get_width(),area.end.x)):
			var a:=before.get_pixel(x,y); var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.02:
				total+=Vector2(x,y); count+=1
	return total/maxi(1,count) if count>0 else Vector2.INF
func benchmark(value: bool) -> Dictionary:
	dust.set_enabled(value)
	var times: Array[float]=[]; var draws: Array[int]=[]
	var last:=Time.get_ticks_usec()
	for i in 70:
		await process_frame
		var now:=Time.get_ticks_usec()
		if i>=15:
			times.append((now-last)/1000.0); draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		last=now
	times.sort(); draws.sort()
	return {"enabled":value,"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"max_ms":times.back(),"draws":draws[draws.size()/2]}
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720); Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory()))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true); settings.set_palette_enabled(false)
	await prepare_world()
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false); enemy.set_process(false)
	world.player.set_physics_process(false); world.player.set_attacking_enabled(false)
	world.player.dash_invulnerability_left=9999
	var office: Dictionary={}
	for room in world.rooms:
		if room.get("archetype","")=="open_office": office=room; break
	world.player.global_position=Vector2(office.center_cell)*32.0
	world.activate_room(office.id)
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	await create_timer(.7).timeout; await frames(8)
	world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_actor_projection(0)
	world.set_process(false); dust=world.get_node_or_null("SampleIndoorDust")
	if dust==null: dust=world.floor_root.get_node("IndoorDust")
	dust.set_process(false)
	for animation in world.find_children("*","AnimationPlayer",true,false): animation.active=false
	# activate_room may wake AI; disable every sample timer/tween authority for
	# identical A/B pixels and draw workloads. The real renderer/camera stay live.
	for child in world.find_children("*","Node",true,false): child.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(8)
	check(dust.pool.get_viewport()==world.get_viewport(),"Dust renders in world, not crisp HUD overlay")
	for palette in [false,true]:
		settings.set_palette_enabled(palette); dust.material.set_shader_parameter("dust_clock",3.1)
		dust.set_enabled(false); await frames(); var before:=await shot("palette_%d_off"%int(palette))
		dust.set_enabled(true); await frames(); var after:=await shot("palette_%d_on"%int(palette))
		var pixels:=changed(before,after)
		print("INDOOR_DUST_SCENE_AB_DELTA palette=",palette," changed=",pixels)
		check(pixels>10,"Dust changes actual final pixels, palette="+str(palette))
	# Isolated diagnostic through the SAME material: opaque object must hide motes.
	settings.set_palette_enabled(false)
	var batches: Array=dust.pool.get_children()
	for batch in batches: batch.hide()
	var probe:=MultiMeshInstance3D.new(); dust.pool.add_child(probe)
	var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
	var quad:=QuadMesh.new(); quad.size=Vector2.ONE; mm.mesh=quad; mm.instance_count=1
	probe.multimesh=mm; probe.material_override=dust.material
	probe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	probe.global_position=world.get_gameplay_world_position(world.player.global_position+Vector2(0,50),1.2)
	mm.set_instance_transform(0,Transform3D(Basis(Vector3.RIGHT,Vector3.UP,Vector3.BACK*.24),Vector3.ZERO)); mm.set_instance_custom_data(0,Color(.45,.5,1,.3))
	mm.custom_aabb=AABB(-Vector3.ONE,Vector3.ONE*2); dust.material.set_shader_parameter("dust_clock",0)
	var probe_record: Dictionary={"custom":Color(.45,.5,1,.3),"point":probe.global_position,"trail":probe.global_basis.x,"side":probe.global_basis.z*.24}
	var initial: Dictionary=dust.mote_state(probe_record,0)
	var centre: Vector2=world.player.get_presentation_hud_position(world.camera_3d.unproject_position(initial.position))
	probe.hide(); await frames(); var no_probe:=await shot("depth_baseline")
	# HiDPI texture.size may report a different backing size than get_image().
	# Test the actual screenshot pixels, not a logical/physical mixed rectangle.
	var pixel: Vector2=centre*Vector2(no_probe.get_size())/root.get_visible_rect().size
	var area:=Rect2i(pixel-Vector2(14,14),Vector2(28,28))
	probe.show(); await frames(); var open_probe:=await shot("depth_open")
	var fleck_pixels:=changed(no_probe.get_region(area),open_probe.get_region(area))
	print("INDOOR_DUST_PROBE_PIXELS native_palette_off=",fleck_pixels)
	check(fleck_pixels>0,"Actual small lit dust fleck is visible in its own projected neighbourhood")
	settings.set_palette_enabled(true); probe.hide(); await frames(); no_probe=await shot("probe_palette_off")
	probe.show(); await frames(); open_probe=await shot("probe_palette_on")
	fleck_pixels=changed(no_probe.get_region(area),open_probe.get_region(area))
	print("INDOOR_DUST_PROBE_PIXELS palette1=",fleck_pixels)
	check(fleck_pixels>0,"The same projected mote survives final Palette 1 processing")
	settings.set_palette_enabled(false)
	var blocker:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.6,.6,.12); blocker.mesh=box
	var black:=StandardMaterial3D.new(); black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; black.albedo_color=Color("161c29")
	blocker.material_override=black; blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(blocker); blocker.global_basis=world.camera_3d.global_basis
	blocker.global_position=Vector3(initial.position).lerp(world.camera_3d.global_position,.02)
	await frames(); var covered:=await shot("depth_blocked")
	probe.hide(); await frames(); var hidden:=await shot("depth_blocked_off")
	check(changed(covered.get_region(area),hidden.get_region(area))==0,"Opaque foreground geometry fully hides dust in its projected neighbourhood")
	blocker.free()
	# Verify actual rendered glints, not just shader parameters or old monitor animation.
	var custom:=Color(.45,.5,1,.3)
	var period:=lerpf(3.2,7.5,custom.a)
	var peak_time:=fposmod(period*.55-custom.a*11.31,period)
	for palette in [false,true]:
		settings.set_palette_enabled(palette)
		var levels: Array[float]=[]
		for bright in [false,true]:
			var time: float=peak_time if bright else peak_time-.35
			dust.material.set_shader_parameter("dust_clock",time)
			probe.hide(); await frames(); var before:=await shot("glint_%d_%d_off"%[int(palette),int(bright)])
			probe.show(); await frames(); var after:=await shot("glint_%d_%d_on"%[int(palette),int(bright)])
			var state: Dictionary=dust.mote_state(probe_record,time)
			var at: Vector2=world.player.get_presentation_hud_position(world.camera_3d.unproject_position(state.position))*Vector2(after.get_size())/root.get_visible_rect().size
			levels.append(brightest_changed(before,after,Rect2i(at-Vector2(14,14),Vector2(28,28))))
		print("DUST_GLINT_LEVELS palette=",palette," dim=",levels[0]," peak=",levels[1])
		check(levels[1]>levels[0]+.20,"Single mote actually flashes substantially brighter, including Palette 1")
	var early: Dictionary=dust.mote_state(probe_record,peak_time-.4)
	var late: Dictionary=dust.mote_state(probe_record,peak_time+.3)
	var screen_a: Vector2=world.camera_3d.unproject_position(early.position)
	var screen_b: Vector2=world.camera_3d.unproject_position(late.position)
	check(screen_a.distance_to(screen_b)>2,"Same particle travels several world-viewport pixels within 0.7 seconds")
	var centres: Array[Vector2]=[]
	for time in [peak_time-.4,peak_time+.3]:
		dust.material.set_shader_parameter("dust_clock",time)
		probe.hide(); await frames(); var before:=await shot("travel_%d_off"%centres.size())
		probe.show(); await frames(); var after:=await shot("travel_%d_on"%centres.size())
		var state: Dictionary=dust.mote_state(probe_record,time)
		var at: Vector2=world.player.get_presentation_hud_position(world.camera_3d.unproject_position(state.position))*Vector2(after.get_size())/root.get_visible_rect().size
		centres.append(changed_centre(before,after,Rect2i(at-Vector2(14,14),Vector2(28,28))))
	var actual_travel: float=centres[0].distance_to(centres[1])
	print("DUST_ACTUAL_TRAVEL physical_pixels_0_7s=",actual_travel)
	check(centres[0].is_finite() and centres[1].is_finite() and actual_travel>4,"Final rendered mote moves over four physical pixels in 0.7s, not only its analytic projection")
	probe.free()
	for batch in batches: batch.show()
	settings.set_palette_enabled(true)
	var review:=world.get_node_or_null("FurnitureTextureReviewCoordinator")
	if review!=null: review.label.hide()
	# Deterministic effect time, actual sample camera; not realtime FPS footage.
	for i in 150:
		dust.material.set_shader_parameter("dust_clock",float(i)*.04)
		await frames(1); await shot("motion_%03d"%i)
		if i==70: await shot("sample_dust")
	settings.set_setting(&"pixelation_enabled",false); await frames(6)
	await shot("native_on")
	check(dust.pool.visible,"Dust also displays without world pixelation")
	settings.set_palette_enabled(false); await frames(); await shot("native_palette_off")
	check(not display.selective_enabled and not display.palette_enabled,"Native unfiltered comparison uses actual settings")
	settings.set_palette_enabled(true)
	settings.set_setting(&"pixelation_enabled",true); await frames(8)
	var measurements: Array=[]
	for value in [false,true,false]: measurements.append(await benchmark(value))
	print("INDOOR_DUST_STATIC_PERF ",JSON.stringify(measurements))
	dust.set_enabled(true); dust.update_samples=0; dust.update_total_usec=0
	for i in 1000: dust._process(1.0/60.0)
	print("INDOOR_DUST_CPU avg_update_usec=",float(dust.update_total_usec)/maxi(1,dust.update_samples)," motes=",dust.records.size()," batches=",dust.pool.get_child_count())
	settings.set_palette_enabled(false)
	cleanup_root.free(); await frames()
	print("SAMPLE_INDOOR_DUST_CAMERA checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
