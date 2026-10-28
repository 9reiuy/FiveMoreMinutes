extends SceneTree
const OUTPUT="res://.runtime/tonal_stability_20261029"
var preview: Control
var dither_materials: Array[ShaderMaterial]=[]
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func set_enhanced(value: bool) -> void:
	preview.palette_material.set_shader_parameter("tonal_sample",value)
	for material in dither_materials: material.set_shader_parameter("office_tonal_sample",value)
func draw_frame(path: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	preview.world_viewport.get_texture().get_image().save_png(path)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var manager:=root.get_node("SettingsManager")
	manager.set_setting(&"palette_enabled",true); manager.set_setting(&"palette_scheme",1)
	preview=load("res://scripts/dream/preview/selective_pixel_preview.gd").new()
	root.add_child(preview)
	for i in 16: await process_frame
	var world: Node3D=preview.world
	world.process_mode=Node.PROCESS_MODE_DISABLED
	for node in get_nodes_in_group("office_dither_lighting"):
		for material in node.materials.values():
			if material is ShaderMaterial and not dither_materials.has(material): dither_materials.append(material)
	check(dither_materials.size()>5,"actual floor lighting materials found")
	for scheme in [1,2]:
		manager.set_setting(&"palette_scheme",scheme)
		set_enhanced(false); await draw_frame(OUTPUT+"/scheme%d_before.png"%scheme)
		var before: Image=preview.world_viewport.get_texture().get_image()
		set_enhanced(true); await draw_frame(OUTPUT+"/scheme%d_after.png"%scheme)
		var after: Image=preview.world_viewport.get_texture().get_image()
		var changed:=0
		for y in 360:
			for x in 640:
				if before.get_pixel(x,y)!=after.get_pixel(x,y): changed+=1
		check(changed>100,"scheme %d enhanced without replacing palette (%d changed pixels)"%[scheme,changed])
	# Same static room and exactly the same camera route, 4s at normal speed.
	manager.set_setting(&"palette_scheme",1)
	var camera: Camera3D=world.camera_3d
	var start:=camera.global_transform
	var anchor: Vector3=world.to_global(Vector3(world.player.global_position.x/32.,0,world.player.global_position.y/32.))
	var actor_before: Vector2=world.player.global_position
	var worst:=0.
	for i in 40:
		var moved:=start
		moved.origin+=Vector3(float(i)*.012,0,float(i)*.006)
		camera.global_transform=moved; camera.h_offset=0.; camera.v_offset=0.
		set_enhanced(false)
		await draw_frame(OUTPUT+"/before_%03d.png"%i)
		set_enhanced(true)
		worst=maxf(worst,preload("res://scripts/dream/preview/pixel_camera_stability.gd").apply(camera,anchor))
		await draw_frame(OUTPUT+"/after_%03d.png"%i)
	check(worst<.01,"ground anchor remains pixel aligned along slow diagonal camera route")
	check(world.player.global_position==actor_before,"camera display stabilization never changes actor authority")
	check(preview.world_viewport.size==Vector2i(640,360),"same 640x360 rendering on both sides")
	# Scripted slow walk: both sides share the same authoritative pose per frame.
	var initial_player: Vector2=world.player.global_position
	for i in 40:
		world.player.global_position=initial_player+Vector2(.6,.3)*i
		world.player.velocity=Vector2(6,3)
		world.player._update_direction_animation(Vector2(1,.5).normalized(),.1)
		camera.h_offset=0.; camera.v_offset=0.
		world._update_camera_and_actor_projection(0.)
		world.player_depth_bridge._process(0.)
		set_enhanced(false); await draw_frame(OUTPUT+"/walk_before_%03d.png"%i)
		var same_pose: Vector2=world.player.global_position
		set_enhanced(true)
		preload("res://scripts/dream/preview/pixel_camera_stability.gd").apply(camera,anchor)
		world.player_depth_bridge._process(0.)
		await draw_frame(OUTPUT+"/walk_after_%03d.png"%i)
		if world.player.global_position!=same_pose: failures+=1
	check(world.player.global_position==initial_player+Vector2(.6,.3)*39,"paired walking captures retain exactly the same source positions")
	# Restore the original display with no enhancement: comparison is reversible.
	world.player.global_position=initial_player
	camera.global_transform=start; camera.h_offset=0.; camera.v_offset=0.
	set_enhanced(false)
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"camera_pixel_error":worst,"materials":dither_materials.size(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"same frozen formal floor and slow camera path; no walking or FPS claim"},"  "))
	preview.queue_free(); await process_frame
	print("FINAL checks=",checks," failures=",failures); quit(failures)
