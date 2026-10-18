extends "res://tests/floor_reflection_sample_delivery.gd"
var mode:=""
func ready_world()->bool:
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await wait(.05)
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and (not world.has_method("get_current_floor_token") or not world.floor_transition_in_progress): return true
	return false
func still_clip(label:String)->void:
	begin(label); await wait(.45); finish()
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func pair(label:String)->void:
	reflection.set_enabled(false); await wait(.25); await still_clip(label+"_before")
	reflection.set_enabled(true); await wait(.25); await still_clip(label+"_after")
func run()->void:
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	main._show_reception("basic")
	check(await ready_world(),"Actual Main enters tarot hall")
	reflection=world.get_node_or_null("FloorReflections")
	check(reflection!=null and not reflection.restored,"Hall reflection survives real pixel-viewport handoff")
	if reflection==null: quit(1); return
	var controller:Node=root.get_node_or_null("DreamTimeController")
	if controller!=null: controller.set_process(false)
	Engine.time_scale=1; Engine.max_fps=60
	var pointer:=InputEventMouseMotion.new(); pointer.position=root.get_visible_rect().size*.5; pointer.global_position=pointer.position; Input.parse_input_event(pointer)
	world.player.global_position=Vector2(12.5,8.5)*32
	await wait(.6); await pair("hall")
	var before_count:int=reflection.renders
	Engine.time_scale=.1; await wait(.4)
	check(reflection.renders-before_count>=3,"Slow game time does not throttle reflection to 1.5Hz")
	Engine.time_scale=1
	begin("hall_walk"); world.player.set_scripted_locomotion(Vector2.LEFT,42); await wait(.8)
	world.player.set_scripted_locomotion(Vector2.RIGHT,42); await wait(.8)
	world.player.clear_scripted_locomotion(); await wait(.25); finish()
	await benchmark("hall_off",false); await benchmark("hall_on",true)
	var hall_view:WeakRef=weakref(reflection.viewport)
	main._show_dream("basic"); world=null
	check(await ready_world(),"Actual Main enters formal gameplay")
	check(hall_view.get_ref()==null,"Main scene change releases hall reflection viewport")
	Engine.max_fps=60
	# Main's real first cab has completed. Direct regeneration below compares
	# four independent layouts; the ten-minute Main run covers actual rides.
	world.enable_game_start_cab_exit=false
	var skeletons:Array=["A1","B2","C3","V3"]
	for skeleton in skeletons:
		world.native_skeleton_type=skeleton
		check(world.regenerate(42001),"Production generation "+skeleton)
		# The non-flashing immunity field protects this visual fixture without
		# the ordinary hurt/spawn timer blinking the body out of its own capture.
		world.player.invulnerability_left=0; world.player.invulnerability_reason=&""
		world.player.hurt_flash_left=0; world.player.revive_flash_left=0
		world.player.dash_invulnerability_left=3600
		world.player._update_visual_feedback()
		await wait(.3)
		reflection=world.get_node("FloorReflections")
		check(not reflection.restored and reflection.viewport.world_3d==world.get_world_3d(),"Production reflection bound to current world "+skeleton)
		var chosen:Dictionary={}
		for room in world.rooms:
			if String(room.get("archetype",""))=="reception": chosen=room; break
		if chosen.is_empty(): chosen=world.rooms[world.spawn_room_id]
		world.activate_room(chosen.id)
		var point:Vector2=Vector2(chosen.grid_rect.get_center())*32
		var candidates:Array=chosen.get("usable_cells",[]).duplicate()
		candidates.sort_custom(func(a:Variant,b:Variant)->bool:return (Vector2(a)*32).distance_squared_to(point)<(Vector2(b)*32).distance_squared_to(point))
		var clear:=false
		for radius in [36,24,18]:
			for cell in candidates:
				if world._content_position_is_clear(Vector2(cell)*32,radius): point=Vector2(cell)*32; clear=true; break
			if clear: break
		world.player.global_position=point
		world.player.set_attacking_enabled(false)
		await wait(1.0); await pair("floor_"+skeleton)
		check(not world.floor_transition_in_progress and world.player_depth_bridge.actor_sprite.is_visible_in_tree(),"Four-layout comparison remains in actual gameplay "+skeleton)
		check(world.player.visual.visible and is_equal_approx(world.player.visual.modulate.a,1.0),"Visual fixture keeps the normal opaque player without hurt blinking "+skeleton)
		if skeleton=="A1":
			var walking_start:Vector2=world.player.global_position
			begin("floor_walk"); world.player.set_scripted_locomotion(Vector2.RIGHT,42); await wait(.8)
			check(world.player.global_position.distance_to(walking_start)>6,"Formal walking clip contains real character displacement")
			world.player.set_scripted_locomotion(Vector2.LEFT,42); await wait(.8)
			world.player.clear_scripted_locomotion(); await wait(.25); finish()
		await benchmark(skeleton+"_off",false); await benchmark(skeleton+"_on",true)
		var count:int=reflection.renders
		paused=true; await wait(.15); check(reflection.renders==count,"Pause stops reflection "+skeleton); paused=false
		metrics[skeleton+"_reflection"]={"floor_surfaces":reflection.surfaces.size(),"unique_floor_materials":reflection.floor_materials.size(),"actor_materials":reflection.actor_materials.size(),"mean_submit_ms":float(reflection.cpu_usec)/maxi(1,reflection.renders)/1000,"update_hz":reflection.update_hz}
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Delivery stayed minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"metrics":metrics,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Real Main hall and four actual generated floors; original materials and original lights. Off/on timing is short sequential frame sampling, excludes PNG readback and is not full combat acceptance."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLOOR_REFLECTION_ROLLOUT_GPU ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	main.free(); quit(1 if failures.size() else 0)
