extends SceneTree
## Actual Main Camera, source-atlas silhouette, framing and peaceful NPC anchoring.
var out:="user://reception_character_camera"
var main: Node
var room: Node
var checks: Array[Dictionary]=[]
var metrics: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):out=arg.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(n:=8) -> void:
	for i in n:await process_frame
func check(ok:bool,label:String) -> void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func photo(label:String) -> Image:
	await frames(10);await RenderingServer.frame_post_draw
	var im: Image=main.current_screen.world_viewport.get_texture().get_image()
	im.save_png(out.path_join(label+".png"))
	root.get_texture().get_image().save_png(out.path_join(label+"_ui.png"))
	return im
func opaque_rect(im:Image) -> Rect2i:
	var area:=Rect2i();var found:=false
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a<.1:continue
			area=area.merge(Rect2i(Vector2i(x,y),Vector2i.ONE)) if found else Rect2i(Vector2i(x,y),Vector2i.ONE)
			found=true
	return area

func visible_pixel_differences(expected: Image, drawn: Image) -> int:
	var differences := 0
	for y in expected.get_height():
		for x in expected.get_width():
			var source := expected.get_pixel(x, y)
			var actual := drawn.get_pixel(x, y)
			# The carrier discards very low alpha. Check the remaining coverage,
			# and compare the colors of fully opaque authored pixels directly.
			if (source.a > 0.05) != (actual.a > 0.05):
				differences += 1
			elif source.a > 0.05 and absf(source.a - actual.a) > 1.1 / 255.0:
				differences += 1
			elif source.a == 1.0 and source.to_rgba32() != actual.to_rgba32():
				differences += 1
	return differences

func check_npc_pixel_grid(sprite: Sprite3D, camera: Camera3D) -> void:
	var half_size := sprite.texture.get_size() * 0.5
	var texel := sprite.pixel_size
	var corner := Vector3(-half_size.x, half_size.y, 0.0) * texel
	var screen_corner := camera.unproject_position(sprite.to_global(corner))
	var screen_right := camera.unproject_position(sprite.to_global(corner + Vector3.RIGHT * texel))
	var screen_down := camera.unproject_position(sprite.to_global(corner - Vector3.UP * texel))
	var square_size := roundf(screen_right.x - screen_corner.x)
	metrics.npc_pixels_per_texel = square_size
	metrics.npc_pixel_grid_corner = str(screen_corner)
	check(square_size >= 1.0 and screen_corner.distance_to(screen_corner.round()) < 0.001
		and screen_right.distance_to(screen_corner + Vector2(square_size, 0.0)) < 0.001
		and screen_down.distance_to(screen_corner + Vector2(0.0, square_size)) < 0.001,
		"Lobby sprite draws every authored texel as a full square on the native pixel grid")
func run() -> void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://tests/support/background_gpu.gd").start(self)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);current_scene=main
	await frames(30);main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one")
	main._show_reception("basic");await frames()
	while main.transition_running:await process_frame
	room=main._supported_dream_world;room.set_process(false);room.player.set_physics_process(false)
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual Main remains Forward+ / Vulkan")
	await frames(4)
	await RenderingServer.frame_post_draw
	var native_size: Vector2i = main.current_screen.world_viewport.size
	var displayed_size := root.get_texture().get_image().get_size()
	check(native_size == displayed_size, "World Camera renders at native display size " + str(displayed_size))
	var to_logical := 360.0 / float(native_size.y)
	# Instantiate without entering the tree: read the actual authored camera,
	# without generating a second dungeon or starting gameplay/audio.
	var reference:Node=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	var formal:Transform3D=reference.get_node("CameraRig").transform*reference.get_node("CameraRig/Camera3D").transform
	metrics.formal_camera_offset=str(formal.origin)
	reference.free()
	check(is_equal_approx(room.camera_3d.position.y,formal.origin.y),"Lobby Camera height equals the formal gameplay Camera")
	check(absf(room.camera_3d.position.length()-formal.origin.length())<.02 and absf(room.camera_3d.global_basis.z.normalized().y-formal.basis.z.normalized().y)<.001,"Lobby matches gameplay distance and pitch while preserving lobby heading")
	check(is_equal_approx(room.camera_3d.fov,35.),"Gameplay field of view is 35 degrees")
	var npc=room.waitress_npc;var bridge=npc.get_meta(&"depth_visual_bridge").get_ref()
	npc.set_process(false);npc.head.position=npc.head_base_pos;npc.body.position=npc.body_base_pos
	npc.head.texture = npc.head_frame_open
	check(not npc.is_in_group(&"dream_enemies") and not npc.is_in_group(&"dream_player"),"Peaceful receptionist stays outside combat groups")
	check(npc.character_atlas.resource_path.ends_with("enemy/npc1.png"),"Requested npc1 original atlas remains in use")
	check(npc.head.texture.region.size==Vector2(32,32) and npc.head_frame_blink.region.size==Vector2(32,32) and npc.head_frame_closed.region.size==Vector2(32,32),"Full authored head and hat survive every blink frame")
	var poses:Dictionary={}
	for pose in [["arrival",Vector2(17.5,19.2)],["counter",Vector2(7.2,19.1)],["waiting_west",Vector2(2.4,14)],["waiting_east",Vector2(21,14)],["upper_hall",Vector2(12,7)]]:
		room.player.global_position=pose[1]*32.;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0.)
		room.interaction_resolver.update_target();room._update_interaction_prompt(0.)
		await frames(10)
		var camera:Camera3D=room.camera_3d
		var p:Vector3=room._map_gameplay_to_world(room.player.global_position)
		var foot:Vector2=camera.unproject_position(p) * to_logical
		var origin:Vector3=room.player_depth_bridge.actor_sprite.global_position
		var unit:Vector2=(camera.unproject_position(origin+camera.global_basis.y*.5)-camera.unproject_position(origin-camera.global_basis.y*.5)) * to_logical
		poses[pose[0]]={"ground_screen":str(foot),"pixels_per_32_source_pixels":unit.length(),"camera_world_height":camera.global_position.y-p.y}
		check(foot.distance_to(Vector2(320,180))<1.,"Camera follows the player's ground at "+pose[0])
		check(unit.length()>31. and unit.length()<34.,"32 source pixels retain gameplay screen scale at "+pose[0])
		var capture:Image=room.player_depth_bridge.render_viewport.get_texture().get_image()
		var opaque:=opaque_rect(capture)
		var screen_rect:=Rect2()
		var corner_index:=0
		for corner in [Vector2(opaque.position),Vector2(opaque.end)]:
			var point:Vector2=camera.unproject_position(origin+camera.global_basis.orthonormalized()*Vector3(corner.x-64.,64.-corner.y,0.)/32.) * to_logical
			screen_rect=Rect2(point,Vector2.ZERO) if corner_index==0 else screen_rect.expand(point)
			corner_index+=1
		# A full, unclipped body is also reviewed in the saved Main Camera images.
		check(Rect2(8,8,624,344).encloses(screen_rect) and screen_rect.size.y>=28.,"Complete player silhouette stays inside Camera margins at "+pose[0])
		await photo(pose[0])
	metrics.poses=poses
	# Inspect the NPC at the actual service position, including its opaque capture.
	room.player.global_position=Vector2(7.2,19.1)*32;room.camera_aim_offset=Vector3.ZERO;room._update_camera_and_projection(0.)
	room.interaction_resolver.update_target();room._update_interaction_prompt(0.);await frames(12)
	var npc_capture:Image=bridge.render_viewport.get_texture().get_image()
	npc_capture.save_png(out.path_join("npc_capture.png"));metrics.npc_capture_bounds=str(opaque_rect(npc_capture))
	var source_sprite: Image = npc.character_atlas.get_image().get_region(Rect2i(0, 0, 32, 41))
	var capture_rect := Rect2i(Vector2i(bridge.viewport_offset) + Vector2i(-16, -41), Vector2i(32, 41))
	var drawn_sprite := npc_capture.get_region(capture_rect)
	metrics.npc_source_pixel_differences = visible_pixel_differences(source_sprite, drawn_sprite)
	check(metrics.npc_source_pixel_differences == 0, "The open-eyed sprite retains the visible pixels of the assembled source atlas")
	check(opaque_rect(npc_capture).size == Vector2i(29, 37), "NPC capture retains the complete hat and full body")
	check_npc_pixel_grid(bridge.actor_sprite, room.camera_3d)
	var foot_capture:Vector2=bridge.body_contact_local+bridge.viewport_offset-Vector2(bridge.render_viewport.size)*.5
	var grounded:Vector3=bridge.actor_sprite.to_global(Vector3(foot_capture.x,-foot_capture.y,0) * bridge.actor_sprite.pixel_size)
	var expected:Vector3=room._map_gameplay_to_world(npc.global_position)+Vector3.UP*.02
	metrics.npc_contact_error_px=room.camera_3d.unproject_position(grounded).distance_to(room.camera_3d.unproject_position(expected))
	check(metrics.npc_contact_error_px < 0.72,"The visual feet remain within one display pixel of floor contact")
	check(room.npc_hint_bubble.hint_text=="交谈" and not room.interaction_prompt.visible,"Near NPC shows only 交谈 in the shared dialogue bubble")
	await photo("npc_near_talk")
	var old_frame:Texture2D=npc.head.texture
	for frame in [npc.head_frame_blink,npc.head_frame_closed]:
		npc.head.texture=frame;await frames(5)
		await RenderingServer.frame_post_draw
		var blink: Image = bridge.render_viewport.get_texture().get_image()
		var expected_body := source_sprite.get_region(Rect2i(0, 30, 32, 11))
		var actual_body := blink.get_region(Rect2i(capture_rect.position + Vector2i(0, 30), Vector2i(32, 11)))
		check(opaque_rect(blink).size == Vector2i(29, 37) and visible_pixel_differences(expected_body, actual_body) == 0,
			"Blink retains the entire hat and the unchanged body from the atlas")
	npc.head.texture=old_frame
	for label in ["WaitingBench","EastWaitingBench"]:
		var sofa:Node3D=room.props_root.get_node(label)
		var table:Node3D=room.props_root.get_node("WaitingTable" if label=="WaitingBench" else "EastWaitingTable")
		var toward_table:Vector3=(table.global_position-sofa.global_position).normalized()
		check(sofa.global_basis.z.normalized().dot(toward_table)>.99,label+" seat faces its table and the lobby")
	check(room.elevator_doors.size()==6 and room.floor_cells.size()==383,"Six elevators and contracted lobby layout remain intact")
	check(AudioServer.is_bus_mute(0),"Private validation remains muted")
	var failures=checks.filter(func(c):return not c["pass"])
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("RECEPTION_CHARACTER_CAMERA checks=",checks.size()," failures=",failures.size())
	main.queue_free();room=null;main=null;bridge=null;npc=null;await frames(18)
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0.);await frames(4);quit(0 if failures.is_empty() else 1)
