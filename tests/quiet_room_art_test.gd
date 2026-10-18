extends SceneTree
const PREVIEW = preload("res://scenes/dream/preview/FaceShadingRoomPreview.tscn")
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	var preview = PREVIEW.instantiate()
	root.add_child(preview)
	for i in 120:
		await process_frame
		if preview.initialized: break
	check(preview.initialized,"Preview failed to initialize")
	check(preview.furniture_pairs.size() >= 6,"Missing sample furniture")
	check(preview.wall_bindings.size() > 0,"Missing wall variants")
	var snapshots := []
	for pair in preview.furniture_pairs:
		var source = pair[0].target_furniture
		snapshots.append([source,source.global_position,source.rotation,source.get_instance_id()])
		check(pair[2].find_children("*","CollisionObject3D",true,false).is_empty(),"Display model has gameplay physics")
		var original_meshes = pair[1].find_children("*","MeshInstance3D",true,false)
		var new_meshes = pair[2].find_children("*","MeshInstance3D",true,false)
		check(original_meshes.size() == new_meshes.size(),"Furniture details removed")
		for index in original_meshes.size():
			check(original_meshes[index].mesh == new_meshes[index].mesh,"Furniture geometry changed")
			check(original_meshes[index].transform == new_meshes[index].transform,"Furniture attachment moved")
	check(not preview.main_light.shadow_enabled,"Preview added real cast shadows")
	var before_direction: Vector3 = preview.ART.light_direction
	preview.set_light_angle(PI/2.0)
	check(not preview.ART.light_direction.is_equal_approx(before_direction),"Light angle has no effect")
	for mat in preview.ART.materials.values():
		check(mat.get_shader_parameter("preview_light_direction") == preview.ART.light_direction,"Light direction stale")
	preview.set_light_angle(0.0)
	for enabled in [false,true,false,true]:
		preview.set_reference_style(enabled)
		await frames(5)
		for pair in preview.furniture_pairs:
			check(pair[0].visual_instance == (pair[2] if enabled else pair[1]),"Bridge not switched")
			check(pair[1].visible != pair[2].visible,"Double furniture render")
		for snapshot in snapshots:
			check(snapshot[0].get_instance_id() == snapshot[3],"Physics object rebuilt")
			check(snapshot[0].global_position.distance_to(snapshot[1]) < .01,"Style switch moved physics")
			check(is_equal_approx(snapshot[0].rotation,snapshot[2]),"Style switch rotated physics")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.runtime/face_art")
		var settings = root.get_node("SettingsManager")
		var saved = settings.values.duplicate(true)
		settings.values["pixelation_enabled"] = true
		settings.setting_changed.emit(&"pixelation_enabled",true)
		for palette in [false,true]:
			settings.values["palette_enabled"] = palette
			settings.setting_changed.emit(&"palette_enabled",palette)
			for enabled in [false,true]:
				preview.set_reference_style(enabled)
				await frames(30)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/face_art/style_%d_palette_%d.png" % [int(enabled),int(palette)])
		settings.values = saved
		settings.values["palette_enabled"] = false
		settings.setting_changed.emit(&"palette_enabled",false)
		for angle in [0.0,PI/2.0]:
			preview.set_reference_style(true)
			preview.set_light_angle(angle)
			await frames(5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/face_art/light_%d.png" % int(angle*2.0/PI))
		preview.set_light_angle(0.0)
		preview.set_reference_style(true)
		settings.values["palette_enabled"] = false
		settings.setting_changed.emit(&"palette_enabled",false)
		Input.action_press(&"move_right")
		for i in 36:
			if i == 18:
				Input.action_release(&"move_right")
				Input.action_press(&"move_left")
			await frames(6)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/face_art/frame_%03d.png" % i)
		Input.action_release(&"move_left")
		settings.values = saved
	print("FACE_ART checks=%d failures=%d furniture=%d surface_bindings=%d" % [checks,failures,preview.furniture_pairs.size(),preview.wall_bindings.size()])
	preview.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)
