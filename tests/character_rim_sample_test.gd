extends SceneTree
var lab: Control
var sample: Control
var failures: Array[String] = []
var checks := 0
var captures: Dictionary = {}
var out := "res://.runtime/character_rim_20261113/native"

func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL ",label)
func capture(name: String) -> Image:
	await frames(10); await RenderingServer.frame_post_draw
	var image: Image = sample.display.world_viewport.get_texture().get_image()
	image.save_png(out.path_join(name+".png"))
	return image
func difference(a: Image, b: Image) -> Dictionary:
	var count := 0
	var total := 0.0
	var maximum := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var ac := a.get_pixel(x,y); var bc := b.get_pixel(x,y)
			var delta := Vector3(ac.r-bc.r,ac.g-bc.g,ac.b-bc.b).abs()
			var value := maxf(delta.x,maxf(delta.y,delta.z))
			# Production volumetric fog has a tiny temporal reconstruction change.
			# Keep raw maximum, but count the effect above that measured noise floor.
			if value > 3.1/255.0:
				count += 1; total += delta.x+delta.y+delta.z
			maximum = maxf(maximum,value)
	return {"pixels":count,"sum_rgb":total,"max_channel":maximum}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 60; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var controller := root.get_node_or_null("DreamTimeController")
	if controller != null:
		controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
	Engine.time_scale = 1
	lab = load("res://scenes/testing/CharacterRimLab.tscn").instantiate()
	root.add_child(lab)
	await frames(2)
	sample = lab.presentation
	for i in 600:
		if sample.ready_world: break
		await frames(1)
	check(sample.ready_world,"independent GameTestLab presentation loads")
	if not sample.ready_world: quit(2); return
	sample.set_frozen(true)
	# Freeze both source animation and shader TIME for exact same-pose A/B.
	sample.world.process_mode = Node.PROCESS_MODE_DISABLED
	if controller != null: controller.set_process(false); controller.set_physics_process(false)
	Engine.time_scale = 0.0
	if "--no-shadows" in OS.get_cmdline_user_args(): sample.lamp.shadow_enabled = false
	var receivers: Array = []
	for bridge in sample.role_bridges:
		bridge.render_viewport.get_texture().get_image().save_png(out.path_join("source_%d.png"%receivers.size()))
		receivers.append({"sprite":str(bridge.actor_sprite.global_position),"reference":str(bridge.body_reference_origin),"layers":bridge.actor_sprite.layers,"material":str(bridge.actor_sprite.material_override==bridge.lit_material),"enabled":str(bridge.lit_material.get_shader_parameter("actor_pixel_rim_enabled")),"strength":str(bridge.lit_material.get_shader_parameter("actor_pixel_rim_strength")),"size":str(bridge.render_viewport.size),"screen":str(sample.world.camera_3d.unproject_position(bridge.actor_sprite.global_position)),"visible":bridge.actor_sprite.is_visible_in_tree(),"rimcode":bridge.lit_material.shader.code.contains("actor_pixel_rim_light"),"actor":str(bridge.source_actor.global_position)})
	print("RIM_DIAG ",JSON.stringify({"lamp":str(sample.lamp.global_position),"mask":sample.lamp.light_cull_mask,"energy":sample.lamp.light_energy,"visible":sample.lamp.is_visible_in_tree(),"range":sample.lamp.omni_range,"world3d":str(sample.lamp.get_world_3d()==sample.world.camera_3d.get_world_3d()),"time_scale":Engine.time_scale,"receivers":receivers}))
	check(RenderingServer.get_current_rendering_method()=="forward_plus","production Forward+ renderer")
	check(sample.effect.bindings.size()>=2,"actual player and enemy carriers are bound")
	sample.set_blocker(false); sample.set_light(1); sample.set_enabled(false)
	var before := await capture("left_before")
	sample.set_enabled(true)
	var left := await capture("left_after")
	captures["left"] = difference(before,left)
	check(captures.left.pixels>10,"real characters have visible light-driven rim")
	sample.set_enabled(false)
	var restored := await capture("left_restored")
	captures["restore"] = difference(before,restored)
	check(captures.restore.max_channel<=3.0/255.0,"off switch restores Camera within production fog temporal noise")
	sample.set_light(2)
	var right_before := await capture("right_before")
	sample.set_enabled(true)
	var right := await capture("right_after")
	captures["right"] = difference(right_before,right)
	sample.set_light(0)
	var dark := await capture("dark_after")
	sample.set_enabled(false)
	var dark_before := await capture("dark_before")
	captures["dark"] = difference(dark,dark_before)
	check(captures.dark.max_channel<=3.0/255.0,"new edge light absent in unlit scene above production fog noise")
	sample.set_light(1); sample.set_blocker(true,true)
	var shadow_before := await capture("shadow_before")
	sample.set_enabled(true)
	var shadow_after := await capture("shadow_after")
	captures["shadow"] = difference(shadow_before,shadow_after)
	check(captures.shadow.sum_rgb < captures.left.sum_rgb*0.20,"solid real occluder suppresses rim by shadow")
	sample.set_blocker(false); sample.set_light(3); sample.set_enabled(false)
	var back_before := await capture("back_before")
	sample.set_enabled(true)
	var back_after := await capture("back_after")
	captures["back"] = difference(back_before,back_after)
	check(captures.back.pixels>5,"back light wraps character silhouette")
	var data := {"checks":checks,"failures":failures,"captures":captures,"bindings":sample.effect.bindings.size(),"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("CHARACTER_RIM_SAMPLE ",JSON.stringify(data))
	lab.free(); Engine.time_scale = 1.0
	await frames(10); quit(0 if failures.is_empty() else 1)
