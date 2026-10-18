extends "res://tests/nyangeon_vfx_sample_delivery.gd"
const REFLECTION=preload("res://scripts/dream/floor_reflection_sample.gd")
var reflection:Node3D
var baseline:Dictionary={}
func occlusion_check()->void:
	var projection=preload("res://scripts/dream/character_visual_projection.gd")
	var bridge:Node=world.player_depth_bridge
	var subject:Vector3=projection.intersect_reference_plane(world.camera_3d,bridge.get_hit_feedback_world_position(),bridge.body_reference_origin,bridge.body_reference_normal)
	var wall:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(1.5,1.5,.04); wall.mesh=box
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(1,0,0); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override=material; wall.layers=REFLECTION.CAPTURE_FLAG; wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(wall); wall.global_basis=reflection.camera.global_basis
	wall.global_position=subject.lerp(reflection.camera.global_position,.025)
	await wait(.18)
	var image:Image=reflection.viewport.get_texture().get_image()
	var pixel:Vector2i=Vector2i(reflection.camera.unproject_position(subject)).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
	var covered:Color=image.get_pixelv(pixel)
	image.save_png(output+"/reflection_occluder.png")
	check(covered.r>.6 and covered.g<.15,"Real reflection depth puts an opaque foreground blocker before the character")
	wall.hide(); await wait(.18)
	image=reflection.viewport.get_texture().get_image()
	var uncovered:Color=image.get_pixelv(pixel)
	image.save_png(output+"/reflection_player.png")
	# A single texel can hit a transparent gap as the real idle animation plays.
	# Verify actual player contribution by hiding only its reflected body, while
	# keeping its main-Camera image, physics and every scene occluder intact.
	var body:Sprite3D=bridge.actor_sprite; var old_layers:int=body.layers
	body.layers=REFLECTION.EXCLUDED; await wait(.18)
	var hidden:Image=reflection.viewport.get_texture().get_image()
	body.layers=old_layers; await wait(.18)
	var revealed:Image=reflection.viewport.get_texture().get_image()
	var changed:=0
	for y in range(maxi(0,pixel.y-7),mini(image.get_height(),pixel.y+8)):
		for x in range(maxi(0,pixel.x-7),mini(image.get_width(),pixel.x+8)):
			var a:Color=hidden.get_pixel(x,y); var b:Color=revealed.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.015: changed+=1
	metrics["player_visibility"]={"target":pixel,"single_pixel":uncovered,"body_pixels":changed}
	check(changed>0,"Removing blocker reveals the actual player body in its projected neighbourhood")
	wall.queue_free()
func state()->Dictionary:
	return {"rng":world._content_rng.state,"seed":world.active_seed,"ammo":world.player.ammo_states.duplicate(true),"health":world.player.current_health,"enemies":world.enemy_root.get_child_count(),"furniture":world.furniture_root.get_child_count()}
func orange_pixels(image:Image)->int:
	var bytes:=image.get_data(); var count:=0
	for i in range(0,bytes.size(),4):
		if bytes[i]>70 and bytes[i]>bytes[i+1]*1.4+10 and bytes[i+1]>20 and bytes[i+1]>bytes[i+2]*1.8: count+=1
	return count
func benchmark(label:String,value:bool)->void:
	reflection.set_enabled(value)
	var times:Array=[]; var draws:Array=[]; var last:=Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now:=Time.get_ticks_usec()
		if i>=30: times.append((now-last)/1000.0); draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		last=now
	times.sort(); draws.sort()
	metrics[label]={"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"peak_ms":times.back(),"median_draw_calls":draws[draws.size()/2],"peak_draw_calls":draws.back()}
func run()->void:
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	node_added.connect(func(node:Node)->void:
		if node.get_script()==preload("res://scripts/dream/office_skeleton_world_base.gd"): node.set_meta(&"test_floor_reflections_disabled",true))
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Formal Main entry ready")
	if not is_instance_valid(world): quit(1); return
	var controller:Node=root.get_node_or_null("DreamTimeController")
	if controller!=null: controller.set_process(false)
	Engine.time_scale=1
	Engine.max_fps=60
	var origin:=Vector2.ZERO; var room_id:=-1
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32
			if world._content_position_is_clear(point,75): origin=point; room_id=room.id; break
		if room_id>=0: break
	check(room_id>=0,"Controlled comparison uses a clear natural office")
	if room_id<0: main.free(); quit(1); return
	world.activate_room(room_id)
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	var enemy:Node=world._spawn_regular_employee(room_id,origin+Vector2(25,15),&"employee",false,"basic")
	enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE; enemy.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.process_mode=Node.PROCESS_MODE_DISABLED; enemy.sky_drop_active=false; enemy.sky_drop_height=0; enemy.knockdown_height=0
	enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
	actors=[enemy]; walkers=Walkers.new(); walkers.actors=actors; world.add_child(walkers)
	world.player.global_position=origin+Vector2(-35,25); world.player.set_attacking_enabled(false)
	await wait(.6)
	# One local warm fixture helps compare the same light on every material;
	# existing room lights, exposure, palette and main Camera remain unchanged.
	var lamp:=OmniLight3D.new(); lamp.name="SampleWarmWallLight"; lamp.light_color=Color(1,.78,.45)
	lamp.light_energy=1.0; lamp.omni_range=5; lamp.omni_attenuation=1.4; lamp.shadow_enabled=true; lamp.light_cull_mask=7
	world.add_child(lamp); lamp.global_position=world.get_gameplay_world_position(origin+Vector2(0,-18),1.9)
	baseline=state()
	var camera_mask:int=world.camera_3d.cull_mask
	var original_materials:Array=[]
	for node in world.floor_root.get_children():
		if node is MeshInstance3D and node.name.begins_with("FloorBatch_"):
			original_materials.append([node,node.layers,node.get_surface_override_material(0)])
	reflection=REFLECTION.new(); reflection.name="FloorReflectionSample"; world.add_child(reflection); reflection.configure(world)
	check(reflection.surfaces.size()>0 and reflection.actor_materials.size()>0,"Approved materials and live actor carriers bound")
	check(reflection.viewport.world_3d==world.get_world_3d(),"Reflection shares world without duplicating actors or physics")
	check(reflection.viewport.size==Vector2i(256,144),"One bounded low-resolution scene render")
	check(REFLECTION.profile("office").x==0 and REFLECTION.profile("office").z==0,"Carpet has no recognizable reflection or gloss")
	for key in ["restroom","reception","corridor","conference","office"]:
		reflection.set_preview_style(key)
		reflection.set_enabled(false); await wait(.25)
		begin(key+"_before"); await wait(.35); finish()
		reflection.set_enabled(true)
		for record in reflection.surfaces: record.material.set_shader_parameter("sample_highlight_revision",false)
		await wait(.25); begin(key+"_previous"); await wait(.35); finish()
		for record in reflection.surfaces: record.material.set_shader_parameter("sample_highlight_revision",true)
		reflection.set_enabled(true); await wait(.25)
		begin(key+"_after"); await wait(.35); finish()
		root.get_texture().get_image().save_png(output+"/"+key+"_after.png")
		if key=="reception":
			reflection.viewport.get_texture().get_image().save_png(output+"/reflection_raw.png")
			begin("moving_reflection")
			walkers.running=true; world.player.set_scripted_locomotion(Vector2.RIGHT,42); await wait(.65)
			world.player.set_scripted_locomotion(Vector2.LEFT,42); await wait(.65)
			world.player.clear_scripted_locomotion(); walkers.running=false; await wait(.35); finish()
	# No PNG readback in the timing windows. Two real movers, unchanged rules.
	reflection.set_preview_style("reception"); walkers.running=true
	await benchmark("off",false); await benchmark("on",true)
	walkers.running=false
	metrics["reflection"]={"size":reflection.viewport.size,"update_hz":reflection.update_hz,"renders":reflection.renders,"mean_submit_ms":float(reflection.cpu_usec)/maxi(1,reflection.renders)/1000,"surface_materials":reflection.surfaces.size(),"actor_materials":reflection.actor_materials.size(),"fps_cap":Engine.max_fps,"world_size":world.camera_3d.get_viewport().size}
	check(state()==baseline,"Presentation preserves RNG, ammo, health, actor/furniture counts and floor seed")
	await occlusion_check()
	world.spawn_death_blood_pool(origin+Vector2(0,35),room_id,.8)
	await wait(1.8)
	reflection.set_enabled(true); await wait(.15)
	var blood_on:Image=root.get_texture().get_image(); var orange_on:=orange_pixels(blood_on)
	blood_on.save_png(output+"/blood_reflection_on.png")
	reflection.set_enabled(false); await wait(.15)
	var blood_off:Image=root.get_texture().get_image(); var orange_off:=orange_pixels(blood_off)
	check(orange_on>100 and orange_on==orange_off,"Opaque orange blood coverage is preserved over reflective floor")
	metrics["blood"]={"orange_on":orange_on,"orange_off":orange_off}
	reflection.set_enabled(true)
	var count:int=reflection.renders
	paused=true; await wait(.12); check(reflection.renders==count,"Pause freezes reflection submission")
	paused=false
	var reference:WeakRef=weakref(reflection.viewport)
	reflection.restore(); reflection.queue_free(); await wait(.08)
	check(reference.get_ref()==null,"Sample teardown releases the extra rendering viewport")
	check(world.camera_3d.cull_mask==camera_mask,"Sample restores main Camera mask")
	check(original_materials.all(func(r:Array)->bool:return r[0].layers==r[1] and r[0].get_surface_override_material(0)==r[2]),"Floor layers and overrides restored")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Delivery stays minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"metrics":metrics,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Actual Main Camera. One natural office uses five approved floor materials to isolate differences; one temporary warm fixture and two controlled real actors. Sample opt-in only. Native 1920x1080 output, actual world viewport settings unchanged. Timing excludes readback."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLOOR_REFLECTION_SAMPLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	main.free(); quit(1 if failures.size() else 0)
