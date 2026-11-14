extends SceneTree
var lab: Control
var sample: Control
var out := "res://.runtime/character_rim_promotion_20261113/native"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func rim(active: bool) -> void:
	for bridge in sample.role_bridges:
		bridge.lit_material.set_shader_parameter("actor_pixel_rim_enabled",active)
		bridge.weapon_material.set_shader_parameter("actor_pixel_rim_enabled",active)
func shot(name: String, viewport: Viewport = null) -> Image:
	await frames(12); await RenderingServer.frame_post_draw
	var vp: Viewport=sample.display.world_viewport if viewport==null else viewport
	var image: Image=vp.get_texture().get_image(); image.save_png(out.path_join(name+".png")); return image
func delta_rgb(a: Image, b: Image) -> Vector3:
	var result:=Vector3.ZERO
	for y in range(65,184):
		for x in range(278,412):
			var ca:=a.get_pixel(x,y); var cb:=b.get_pixel(x,y)
			var d:=Vector3(maxf(cb.r-ca.r,0),maxf(cb.g-ca.g,0),maxf(cb.b-ca.b,0))
			if maxf(d.x,maxf(d.y,d.z))>3.1/255.0: result+=d
	return result
func pair(name: String) -> Vector3:
	rim(false); var before:=await shot(name+"_before")
	rim(true); var after:=await shot(name+"_after")
	return delta_rgb(before,after)
func masks(world: Node) -> Dictionary:
	var state: Dictionary={}
	for light in world.find_children("*","Light3D",true,false): state[str(light.get_instance_id())]=light.light_cull_mask
	return state
func active_lights(world: Node) -> Array:
	var result: Array=[]
	for light in world.find_children("*","Light3D",true,false):
		if light.is_visible_in_tree() and light.light_energy>0.01 and light.light_cull_mask&2:
			result.append({"name":str(light.name),"energy":light.light_energy,"mask":light.light_cull_mask,"shadow":light.shadow_enabled})
	return result
func run() -> void:
	create_timer(180.0,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps=60; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var controller:=root.get_node("DreamTimeController")
	controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false); Engine.time_scale=1.0
	lab=load("res://scenes/testing/CharacterRimLab.tscn").instantiate(); root.add_child(lab)
	await frames(2); sample=lab.presentation
	for i in 900:
		if sample.ready_world: break
		await frames(1)
	check(sample.ready_world,"production art lab ready")
	if not sample.ready_world: quit(2); return
	sample.set_process(false); sample.effect.clear()
	sample.set_frozen(true); sample.world.process_mode=Node.PROCESS_MODE_DISABLED
	controller.set_process(false); controller.set_physics_process(false); Engine.time_scale=0.0
	check(sample.scene_lighting and not sample.lamp.visible,"preview defaults to normal scene lighting, not single-light isolation")
	for bridge in sample.role_bridges:
		check(bridge.lit_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"new actual character receives rim by default")
		check(bridge.weapon_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"held weapon receives rim by default")
		var expected: Vector2=Vector2(bridge.render_viewport.size)/bridge.weapon_sprite.texture.get_size()
		check(bridge.lit_material.get_shader_parameter("actor_pixel_rim_other_uv_scale")==expected,"body/large weapon capture coordinates agree")
		check(bridge.weapon_material.get_shader_parameter("actor_pixel_rim_other_uv_scale")==Vector2.ONE/expected,"weapon/body capture inverse coordinates agree")
	var scene_masks:=masks(sample.world)
	facts["scene_active_lights"]=active_lights(sample.world)
	check(facts.scene_active_lights.size()>1,"normal scene has multiple active character-receiving lights")
	await pair("scene_lights")
	check(scene_masks==masks(sample.world),"rim on/off never edits original scene light receiver masks")
	# Two actual point lamps on opposite sides, no extra emissive character path.
	sample.set_light(1); sample.lamp.light_color=Color(1,0.03,0.02)
	var blue:=OmniLight3D.new(); blue.name="SecondRealBlueLight"
	blue.omni_range=8; blue.omni_attenuation=0.6; blue.light_energy=sample.lamp.light_energy
	blue.light_color=Color(0.02,0.12,1); blue.shadow_enabled=true
	blue.shadow_bias=0.02; blue.shadow_normal_bias=0.05
	blue.light_cull_mask=15; blue.shadow_caster_mask=1|2|8
	sample.rig.add_child(blue)
	blue.global_position=sample.center+sample.camera_right*3.0+sample.camera_back*1.5+Vector3.UP*0.4
	blue.hide(); var red_only:=await pair("red_only")
	blue.show(); sample.lamp.hide(); var blue_only:=await pair("blue_only")
	sample.lamp.show(); var both:=await pair("both_lights")
	check(red_only.x>red_only.z*3.0 and red_only.x>1.0,"left red lamp drives real red edge")
	check(blue_only.z>blue_only.x*3.0 and blue_only.z>1.0,"right blue lamp drives real blue edge")
	check(both.x>blue_only.x+5.0 and both.z>red_only.z+5.0,"simultaneous lamps retain both red AND blue contributions")
	check(both.x>red_only.x*0.5 and both.z>blue_only.z*0.5,"neither real lamp replaces the other")
	sample.set_blocker(true,true); var blocked:=await pair("red_blocked_blue_visible")
	check(blocked.x<both.x*0.25,"real blocker suppresses left red lamp rim")
	check(blocked.z>blue_only.z*0.5,"right blue lamp still lights the character behind left lamp blocker")
	sample.set_blocker(false); sample.lamp.hide(); blue.hide(); var unlit:=await pair("all_off")
	check(unlit.length()<0.1,"no constant rim remains when both sources are off")
	facts["multilight_added_rgb"]={"red":str(red_only),"blue":str(blue_only),"both":str(both),"red_blocked":str(blocked),"off":str(unlit)}
	blue.free()
	# Whitebox loading/collision contract and repeated floor ownership.
	sample.world.process_mode=Node.PROCESS_MODE_INHERIT
	sample.whitebox=true; await sample.rebuild(); sample.set_process(false); sample.effect.clear()
	check(bool(sample.world._validate_layout().valid),"whitebox floor connectivity and door-side rules pass")
	check(sample.world.player_depth_bridge.lit_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"whitebox reload retains native default")
	lab.free(); sample=null; await frames(20)
	# Real production Main entry; no preview fixtures or light suppression.
	Engine.time_scale=1.0; controller.set_process(true); controller.set_physics_process(true)
	var main: Node=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); main._show_dream("basic")
	for i in 1800:
		if not main.transition_running and is_instance_valid(main._supported_dream_world) and not main._supported_dream_world.floor_transition_in_progress: break
		await frames(1)
	var world: Node=main._supported_dream_world
	check(is_instance_valid(world),"real Main production world loads")
	if is_instance_valid(world):
		world.player.invulnerability_left=999.0
		world.player.set_physics_process(false); world.set_physics_process(false); world.set_process(false)
		for actor in world.enemy_root.get_children(): actor.set_physics_process(false); actor.set_process(false)
		var bounds: Rect2=world._room_bounds_pixels(world.current_room_id,0.0)
		var best:=-INF; var clear_point: Vector2=world.player.global_position
		for cell in world.rooms[world.current_room_id].get("usable_cells",[]):
			var candidate:=Vector2(cell)*32.0
			if not world._content_position_is_clear(candidate,24.0,false): continue
			var margin: float=minf(minf(candidate.x-bounds.position.x,bounds.end.x-candidate.x),minf(candidate.y-bounds.position.y,bounds.end.y-candidate.y))
			if margin>best: best=margin; clear_point=candidate
		world.player.global_position=clear_point
		world.camera_aim_offset=Vector3.ZERO
		world._update_camera_and_actor_projection(0.0)
		world.player_depth_bridge._process(0.0)
		var bridge: Node=world.player_depth_bridge
		check(bridge.lit_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"real Main player uses native enabled rim")
		check(bridge.weapon_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"real Main player weapon uses native enabled rim")
		check(world.find_children("RimSampleFixtures","Node3D",true,false).is_empty(),"formal world contains no preview fixture or isolation controller")
		var enemy: Node=world._spawn_regular_employee(world.current_room_id,world.player.global_position+Vector2(40,0),&"employee",false,"assault_rifle")
		enemy.set_player_vision_visible(true); enemy.set_room_runtime_active(true); enemy.set_physics_process(false); enemy.set_process(false)
		var enemy_bridge: Node=enemy.get_meta(&"depth_visual_bridge").get_ref()
		check(enemy_bridge.lit_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"real Main enemy factory enables native rim")
		check(enemy_bridge.weapon_material.get_shader_parameter("actor_pixel_rim_enabled")==true,"real Main enemy weapon enables native rim")
		facts["main_active_lights"]=active_lights(world)
		check(facts.main_active_lights.size()>1,"formal world retains multiple active character light receivers")
		await shot("formal_main",world.camera_3d.get_viewport())
		facts["main_renderer"]=RenderingServer.get_current_rendering_method()
	main.free(); Engine.time_scale=1.0; await frames(15)
	var report:={"checks":checks,"failures":failures,"facts":facts,"audio_master_muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RIM_PROMOTION_NATIVE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
