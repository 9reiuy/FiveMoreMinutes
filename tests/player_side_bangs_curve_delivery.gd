extends "res://tests/phone_tab_delivery.gd"
var hair:Node
var samples:Dictionary={}
const CURRENT_HAIR=preload("res://scripts/entities/player_side_bangs.gd")
var previous_script:Script
var compare_layers:=false
func switch_source(script:Script)->void:
	if is_instance_valid(hair.curve):hair.curve.free()
	if is_instance_valid(hair.overlay_curve):hair.overlay_curve.free()
	hair.set_script(script)
	hair._ready()
	hair.set_physics_process(false)
func render_pose()->void:
	world.player_depth_bridge._process(0.0)
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
func record(label:String,curved:bool)->void:
	hair.bend=0.0;hair.bend_velocity=0.0;hair.initialized=false
	hair.set_segmented_enabled(curved)
	if previous_script!=null and label=="rigid":
		# Static UV/topology differ between versions: give the passive copy a
		# distinct identity rather than reusing the old mesh's fixed attributes.
		hair.curve.name="PreviousCurvedStrand"
		if is_instance_valid(hair.overlay_curve):hair.overlay_curve.name="PreviousCurvedStrand"
	world.player.walk_animation_time=0.0;world.player.idle_animation_time=0.0
	samples[label]=[]
	for index in 96:
		var t:=float(index)/30.0
		var motion:=Vector2(290,0) if t>=.3 and t<1.0 else Vector2(-290,0) if t>=1.6 and t<2.3 else Vector2.ZERO
		var aim:=Vector2.RIGHT if t>=1.6 and t<2.6 else Vector2.LEFT
		world.player.velocity=motion
		world.player.set_meta(&"aim_direction_override",aim)
		world.player._update_direction_animation(motion,1.0/30.0)
		hair.step(1.0/30.0,motion,aim.angle(),world.player.character_facing_right,world.player.character_facing_back,false,false)
		await render_pose()
		var file:="%s_%03d.png"%[label,index]
		root.get_texture().get_image().save_png(output+"/"+file)
		samples[label].append({"file":file,"seconds":t,"motion":motion,"angles":hair.segment_angles,"bend":hair.bend})
	check(not curved or hair.curve.visible,"Curved sample remains visible in production actor capture")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	output="res://.runtime/bangs_curve_20261020/camera"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):output=argument.trim_prefix("--artifact-dir=")
		if argument.begins_with("--comparison-script="):previous_script=load(argument.trim_prefix("--comparison-script="))
		if argument=="--compare-layers":compare_layers=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
	main._show_dream("basic");await ready_main();world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+45000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:await wait(.05)
	check(not world.floor_transition_in_progress,"Actual Main entrance finishes before sample")
	hair=world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	check(hair.segmented_enabled and is_instance_valid(hair.curve) and hair.curve.visible,"Formal Main enables approved curve without preview setup")
	check(is_instance_valid(hair.overlay_curve) and hair.z_index==1 and hair.overlay.z_index==1,"Formal curve and healing overlay retain foreground layering")
	world.player.global_position=Vector2(world.get_room_center_cell(world.current_room_id))*world.CELL_PIXELS
	world.player.invulnerability_left=0.0;world.player.visual.visible=true;world.player.visual.modulate=Color.WHITE
	world._update_camera_and_actor_projection(0.0)
	world.room_visibility._update_outside_mask()
	world.office_art_root.get_child(0).city._sync_render_snapshot()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var foot:Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(world.player.global_position,0.0))
	if previous_script!=null:switch_source(previous_script)
	if compare_layers:
		hair.z_index=0;hair.overlay.z_index=0
	await record("rigid",previous_script!=null or compare_layers)
	if compare_layers:
		hair.z_index=1;hair.overlay.z_index=1
	if previous_script!=null:switch_source(CURRENT_HAIR)
	await record("curved",true)
	var captured_polygons:Array=[]
	for node in world.player_depth_bridge.render_root.find_children("CurvedStrand","Polygon2D",true,false):captured_polygons.append(node)
	check(not captured_polygons.is_empty(),"Real production 3D bridge contains textured three-section hair")
	check(captured_polygons.any(func(node:Polygon2D)->bool:return node.is_visible_in_tree() and node.polygon==hair.curve.polygon),"Visible 3D capture receives the latest curve, not a frozen duplicate")
	check(captured_polygons.any(func(node:Polygon2D)->bool:return node.texture==hair.curve.texture and node.uv==hair.curve.uv and node.polygons==hair.curve.polygons),"Production copy uses the current clamped pixels and smooth topology rather than old static UVs")
	if compare_layers:
		check(captured_polygons.any(func(node:Polygon2D)->bool:return node.get_parent().z_index==1 and node.get_parent().z_as_relative),"Actual 3D capture inherits the foreground hair layer")
	check(hair.segmented_enabled,"Approved continuous curve remains enabled after production capture")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"All frames recorded minimized and without focus")
	var result:={"checks":checks,"failures":failures,"samples":samples,"foot_logical":foot,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Actual Main Camera, controlled in-place motion/stop/turn; identical 30Hz simulation steps and original texture; normal-speed playback, not measured live FPS"}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("BANGS_CURVE_GPU checks=",checks," failures=",failures.size())
	main.free();quit(0 if failures.is_empty() else 1)
