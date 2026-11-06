extends SceneTree
const OUT := "res://.runtime/unit_outline_alignment_20261102"
var main: Node
var world: Node
var reference: SubViewport
var ref_camera: Camera3D
var ref_quad: MeshInstance3D
var ref_records: Array=[]
var target: Node3D
var phase := "before"
var results: Array=[]
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n:=5) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func build_reference(outline: Node3D) -> void:
	if is_instance_valid(reference): reference.free()
	target=outline; ref_records.clear()
	reference=SubViewport.new(); reference.size=Vector2i(640,360); reference.world_3d=World3D.new()
	reference.transparent_bg=true; reference.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(reference)
	ref_camera=Camera3D.new(); reference.add_child(ref_camera); ref_camera.current=true
	var red:=StandardMaterial3D.new(); red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; red.albedo_color=Color.RED
	for record in target.records:
		var source: MeshInstance3D=record.source.get_ref()
		var copy:=MeshInstance3D.new(); copy.mesh=source.mesh; copy.material_override=red; reference.add_child(copy)
		ref_records.append({"source":source,"copy":copy})
	ref_quad=MeshInstance3D.new(); ref_quad.mesh=outline.border.mesh
	var material:=ShaderMaterial.new(); var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_test_disabled, depth_draw_never; uniform sampler2D mask : filter_nearest; void fragment(){ALBEDO=vec3(0.,1.,0.); ALPHA=texture(mask,UV).a;}"
	material.shader=shader; material.set_shader_parameter("mask",outline.capture.get_texture()); ref_quad.material_override=material; reference.add_child(ref_quad)
func sync_reference() -> void:
	if not is_instance_valid(target) or not is_instance_valid(ref_camera): return
	var real: Camera3D=world.camera_3d
	ref_camera.global_transform=real.get_camera_transform(); ref_camera.force_update_transform()
	ref_camera.keep_aspect=real.keep_aspect; ref_camera.projection=real.projection; ref_camera.fov=real.fov
	ref_camera.near=real.near; ref_camera.far=real.far; ref_camera.size=real.size; ref_camera.frustum_offset=real.frustum_offset
	for record in ref_records:
		record.copy.global_transform=record.source.global_transform; record.copy.force_update_transform()
		record.copy.visible=record.source.is_visible_in_tree()
	ref_quad.global_transform=target.border.global_transform; ref_quad.force_update_transform()
	ref_quad.visible=target.border.visible
func measure_image(image: Image) -> Dictionary:
	var red: Dictionary={}; var green: Dictionary={}; var rc:=Vector2.ZERO; var gc:=Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y); var p:=Vector2i(x,y)
			if c.r>.4: red[p]=true; rc+=Vector2(p)
			if c.g>.4: green[p]=true; gc+=Vector2(p)
	var unmatched:=0
	for pair in [[red,green],[green,red]]:
		for p: Vector2i in pair[0]:
			var found:=false
			for y in range(-1,2):
				for x in range(-1,2):
					if pair[1].has(p+Vector2i(x,y)): found=true
			if not found: unmatched+=1
	return {"source_pixels":red.size(),"outline_pixels":green.size(),"centroid_error_px":(rc/maxi(red.size(),1)).distance_to(gc/maxi(green.size(),1)),"outside_1px_fraction":float(unmatched)/maxi(red.size()+green.size(),1)}
func sample(label: String) -> void:
	await frames(5); await RenderingServer.frame_post_draw
	var image:=reference.get_texture().get_image(); image.save_png(OUT+"/"+phase+"_"+label+"_mask.png")
	var result:=measure_image(image); result.label=label; results.append(result)
	world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/"+phase+"_"+label+".png")
	print("MASK ",label," ",JSON.stringify(result))
	if phase!="before":
		check(result.source_pixels>80,"%s has visible actual model geometry"%label)
		check(result.centroid_error_px<0.8 and result.outside_1px_fraction<0.01,"%s rendered silhouette follows current model within one pixel"%label)
func stage(actor: Node2D, outline: Node3D, rid: int, camera_point: Vector2) -> void:
	world.set_current_room_id(rid); world.activate_room(rid)
	world.player.global_position=camera_point; world._update_camera_and_actor_projection(0.0)
	await frames(12)
	build_reference(outline)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	if not OS.get_environment("FMM_OUTLINE_PHASE").is_empty(): phase=OS.get_environment("FMM_OUTLINE_PHASE")
	DirAccess.make_dir_recursive_absolute(OUT); create_timer(240.,true,false,true).timeout.connect(func():quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); seed(424242); main._show_dream("basic")
	while main.transition_running: await frames(1)
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await frames(1)
	await frames(40); world.player.invulnerability_left=999.; world.player.set_physics_process(false)
	world.set_process(false); world.set_physics_process(false)
	for enemy in world.enemy_root.get_children():
		if enemy is Node2D: enemy.set_physics_process(false)
	for drone in world._exterior_drone_root.get_children(): drone.set_physics_process(false)
	var drone: Node3D=world._exterior_drone_root.get_child(0)
	var robot: Node3D=world._hotel_robot_visual_root.get_child(0)
	RenderingServer.frame_pre_draw.connect(sync_reference)
	await stage(drone._proxy,drone.outline,int(drone.get_meta(&"dream_room_id")),drone.boundary_2d+drone.inward_normal*72.0)
	await sample("drone")
	if phase!="before":
		DirAccess.make_dir_recursive_absolute(OUT+"/motion_drone")
		drone.set_physics_process(true)
		for i in 45:
			await frames(2); await RenderingServer.frame_post_draw
			world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/motion_drone/%03d.png"%i)
			if i%15==0: await sample("drone_move%d"%i)
		drone.set_physics_process(false)
	var rid: int=world._room_id_at_position(robot.unit.global_position)
	await stage(robot.unit,robot.outline,rid,robot.unit.global_position+Vector2(30,28))
	await sample("robot")
	if phase!="before":
		DirAccess.make_dir_recursive_absolute(OUT+"/motion_robot")
		var start: Vector2=robot.unit.global_position
		for i in 45:
			robot.unit.global_position=start+Vector2(sin(float(i)*.09)*32.,cos(float(i)*.08)*12.)
			robot.unit.facing=Vector2(sin(float(i)*.06),cos(float(i)*.06))
			await frames(2); await RenderingServer.frame_post_draw
			world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/motion_robot/%03d.png"%i)
			if i%15==0: await sample("robot_move%d"%i)
	RenderingServer.frame_pre_draw.disconnect(sync_reference)
	FileAccess.open(OUT+"/camera_"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":results},"\t"))
	print("UNIT_OUTLINE_CAMERA checks=",checks," failures=",failures)
	reference.free(); main.queue_free(); await frames(8); quit(1 if failures else 0)
