extends SceneTree
var out := "res://.runtime/surface_blood_20261114/promotion/rollback_camera"
var world: Node3D
var display: Control
var checks: Dictionary = {}
func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw
func check(name: String, passed: bool) -> void:
	checks[name] = passed; print("PASS " if passed else "FAIL ",name)
func run() -> void:
	create_timer(120.0,true,false,true).timeout.connect(func(): quit(3))
	if not OS.get_environment("FORKLIFT_EVIDENCE").is_empty(): out = OS.get_environment("FORKLIFT_EVIDENCE").path_join("rollback-camera")
	DirAccess.make_dir_recursive_absolute(out)
	var clock: Node = root.get_node("DreamTimeController")
	clock.set_lifecycle_enabled(false); clock.set_process(false); Engine.time_scale = 1.0
	world = load("res://scenes/testing/LabWorld.tscn").instantiate()
	world.generate_on_ready = false; world.lab_ai = false; world.lab_enemy_count = 0
	world.lab_furniture = true; world.lab_whitebox = false; world.persist_profile = false
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false; root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		quit(1)
		return
	check("production_floor_generated",world.regenerate(71432))
	world.populate_lab(); world.player.global_position = Vector2(6,6)*32
	world.player.set_physics_process(false); world.current_room_id = 1
	world.run_interface.hud.hide(); world._update_camera_and_actor_projection(0.0)
	clock.set_lifecycle_enabled(false); clock.set_process(false); Engine.time_scale = 1.0
	var blood: Node3D = world.office_art_root.get_node("SurfaceBlood")
	blood.set_surface_meshes(true)
	await frames(8)
	var origin: Vector2 = world.station_position(1)
	var accepted := 0
	for i in 3:
		if world.spawn_black_blood(origin,Vector2(1,.4),false,1): accepted += 1
	check("valid_floor_accepts_spray",accepted==3)
	await create_timer(1.5,true,false,true).timeout
	await frames(8)
	check("production_surface_blood_settles",blood.hit_count>0 and not blood.faces.is_empty())
	# Staged generation deliberately resets camera aim and relocates the player.
	# Compare the restored stains from the same actual Camera, at native size.
	world.set_process(false)
	var captured_camera: Transform3D = world.camera_3d.global_transform
	var captured_rig: Transform3D = world.camera_rig.global_transform
	var captured_player: Vector2 = world.player.global_position
	var captured_room: int = world.current_room_id
	var face_images: Array[int] = []
	for face in blood.faces: face_images.append(hash(face.image.get_data()))
	Engine.time_scale = 0.0
	var before := await visible_pixels(blood,"before")
	check("actual_camera_shows_blood_before_stash",before>30)
	Engine.time_scale = 1.0
	world.transition_generation_token += 1
	var token: int = world.transition_generation_token
	check("production_staged_generation",await world._regenerate_staged(71433,1,token,true))
	check("old_blood_preserved_in_stash",is_instance_valid(blood) and not blood.faces.is_empty())
	world._rollback_failed_transition(token,0)
	clock.set_lifecycle_enabled(false); clock.set_process(false); Engine.time_scale = 0.0
	world.player.set_physics_process(false)
	world.set_process(false)
	world.player.global_position = captured_player
	world.current_room_id = captured_room
	world.camera_rig.global_transform = captured_rig
	world.camera_3d.global_transform = captured_camera
	if is_instance_valid(world.room_visibility):
		world.room_visibility.current_room_id = captured_room
		world.room_visibility.reveal_room(captured_room)
	await frames(12)
	check("same_host_restored",world.office_art_root.get_node_or_null("SurfaceBlood")==blood)
	check("identical_camera_restored",world.camera_3d.global_transform.is_equal_approx(captured_camera))
	var images_match: bool = blood.faces.size() == face_images.size()
	for i in mini(face_images.size(), blood.faces.size()): images_match = images_match and hash(blood.faces[i].image.get_data()) == face_images[i]
	check("unchanged_blood_images_after_rollback",images_match)
	var textures_match := true
	for face in blood.faces:
		var mark: MeshInstance3D = face.ref.get_ref()
		textures_match = textures_match and mark.material_override.get_shader_parameter(&"blood_texture") == face.texture
	check("live_blood_textures_restored",textures_match)
	var layers_ok := true
	for receiver in blood.receivers:
		for original in receiver.originals:
			var mesh: VisualInstance3D = original.ref.get_ref()
			if is_instance_valid(mesh): layers_ok = layers_ok and (mesh.layers & blood.RECEIVER_LAYER)!=0
	check("reflection_rebind_preserves_blood_receiver_bit",layers_ok)
	var after := await visible_pixels(blood,"after")
	check("actual_camera_shows_blood_after_rollback",after>30 and after>=before*.8)
	var result := {"pid":OS.get_process_id(),"checks":checks,"orange_decal_pixels_before":before,"orange_decal_pixels_after":after,"blood":blood.stats(),"origin":str(origin)}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	Engine.time_scale = 1.0; display.free(); await frames(8)
	var passed: bool = checks.values().all(func(value: bool)->bool: return value)
	print("BLOOD_ROLLBACK_CAMERA ",JSON.stringify(result))
	quit(0 if passed else 2)
func visible_pixels(blood: Node3D, label: String) -> int:
	for face in blood.faces:
		var decal: Node3D = face.ref.get_ref()
		if is_instance_valid(decal): decal.show()
	await frames(4)
	var on: Image = display.world_viewport.get_texture().get_image()
	on.save_png(out.path_join(label+"_on.png"))
	for face in blood.faces:
		var decal: Node3D = face.ref.get_ref()
		if is_instance_valid(decal): decal.hide()
	await frames(4)
	var off: Image = display.world_viewport.get_texture().get_image()
	off.save_png(out.path_join(label+"_off.png"))
	var count := 0
	for y in on.get_height():
		for x in on.get_width():
			var a := on.get_pixel(x,y); var b := off.get_pixel(x,y)
			if a.r-b.r>.06 and a.r>a.g*1.3 and a.g>a.b*1.2: count += 1
	for face in blood.faces:
		var decal: Node3D = face.ref.get_ref()
		if is_instance_valid(decal): decal.show()
	return count
