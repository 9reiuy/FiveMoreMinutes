extends SceneTree
const PREPARER=preload("res://scripts/dream/firearm_render_preparation.gd")
const ACTOR_BRIDGE=preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 6: await RenderingServer.frame_post_draw
func light_state(world: Node3D) -> Array:
	var state: Array=[]
	for light in world.night_lighting.muzzle_lights: state.append([light.visible,light.shadow_enabled,light.transform,light.light_energy])
	for light in world.shadow_manager.candidates: state.append([light.shadow_enabled,light.shadow_opacity])
	return state
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display); paused=true
	for floor_index in 3:
		if floor_index==0: check(world.regenerate(41001),"Initial floor generates")
		else:
			world.floor_transition_in_progress=true; world.transition_phase=&"CAB_RIDE"
			check(await world._regenerate_staged(41001+floor_index,floor_index,world.transition_generation_token),"Actual staged generation")
			world._set_building_exterior_visible(true)
		world.player.global_position=world.get_player_root_position_for_cell(world.spawn_cell)
		world.transition_phase=&"IDLE"; world.floor_transition_in_progress=false
		world._update_camera_and_actor_projection(0.0)
		display.set_selective_enabled(floor_index!=1); display.set_palette_enabled(floor_index!=2); display._process(0.0)
		world.begin_firearm_render_preparation()
		await settle()
		# Pausing before generation prevents the normal bridge process callback.
		# Establish the actual frozen display, not an uninitialized actor capture.
		world.player_depth_bridge._process(0.0)
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge is ACTOR_BRIDGE:
				bridge._process(0.0)
		await settle()
		var before_image: Image=display.world_viewport.get_texture().get_image()
		var before: PackedByteArray=before_image.get_data()
		before_image.save_png("res://.runtime/preparation_before_%d.png" % floor_index)
		var lights:=light_state(world)
		var smoke: Node=world.floor_root.get_node("FootstepSmoke")
		var smoke_rng: int=smoke.rng.state
		var rng_state: int=world._content_rng.state
		var position: Vector2=world.player.global_position
		var source_count: int=world.world_effects_root.get_child_count()
		var viewport_count: int=root.find_children("*","SubViewport",true,false).size()
		var report: Dictionary=await PREPARER.run(self,world)
		if "--experimental-shadow-receivers" in OS.get_cmdline_user_args():
			var camera_transform: Transform3D=world.camera_3d.transform
			var selected: Array=world.shadow_manager.selected.duplicate()
			var active: Dictionary=world.shadow_manager.active.duplicate()
			var receiver_report: Dictionary=await preload("res://tests/support/shadow_receiver_preparation_probe.gd").run(self,world)
			report["experimental_shadow_receiver"]=receiver_report
			check(not receiver_report.cancelled and receiver_report.peak_shadow_lights<=receiver_report.limit,"Experimental receiver preparation obeys actual light budget")
			check(world.camera_3d.transform==camera_transform,"Formal local camera transform restored exactly")
			check(world.shadow_manager.selected==selected and world.shadow_manager.active==active,"Shadow schedule restored without consuming time")
		await settle()
		check(not report.cancelled,"Preparation on each floor succeeds")
		check(report.destruction.viewport_released and report.destruction.states==16 and report.destruction.material_families==5,"Real destruction preparation completed and private viewport released")
		check(root.find_children("*","SubViewport",true,false).size()==viewport_count,"No private viewport accumulation across floors")
		check(world._content_rng.state==rng_state,"Content RNG unchanged")
		check(smoke.rng.state==smoke_rng and smoke.emitted==0 and smoke.tracked.is_empty(),"Preparation preserves smoke RNG, triggers and counters")
		check(smoke.get_child_count()==72 and smoke.puffs.is_empty(),"Preparation releases native duplicate and leaves bounded pool unused")
		check(world.player.global_position==position,"Player never moved to prepare landing")
		check(world.world_effects_root.get_child_count()==source_count,"No temporary sources retained")
		check(world.projectile_light_assignments.is_empty(),"No temporary projectile light")
		check(light_state(world)==lights,"All muzzle and interior shadow state restored")
		var after_image: Image=display.world_viewport.get_texture().get_image()
		after_image.save_png("res://.runtime/preparation_after_%d.png" % floor_index)
		check(after_image.get_data()==before,"Frozen world pixels restored across settings")
		print("FIREARM_PREPARATION_FLOOR ",JSON.stringify({"floor":floor_index,"report":report,"pixelation":floor_index!=1,"palette":floor_index!=2}))
	# Deliberately invalidate the floor token while the RefCounted worker waits.
	if "--experimental-shadow-receivers" in OS.get_cmdline_user_args():
		var receiver_task:=preload("res://tests/support/shadow_receiver_preparation_task.gd").new()
		root.add_child(receiver_task)
		var original_camera: Transform3D=world.camera_3d.transform
		receiver_task.begin(world)
		await process_frame
		check(world.regenerate(42001),"Replacement floor generates during receiver preparation")
		while not receiver_task.finished: await process_frame
		check(receiver_task.result.cancelled,"Receiver preparation cancels on changed floor token")
		check(world.camera_3d.transform==original_camera,"Cancelled receiver never leaves a camera offset in new floor")
		check(world.shadow_manager.active.keys().all(func(light: Light3D)->bool:return world.shadow_manager.candidates.has(light)),"No old lights restored into new floor")
		receiver_task.queue_free()
	var task:=preload("res://tests/support/firearm_preparation_task.gd").new(); root.add_child(task)
	task.begin(world)
	await process_frame
	check(world.regenerate(42001),"Replacement floor generates during cancellation")
	var replacement_rng: int=world._content_rng.state
	while not task.finished: await process_frame
	check(task.result.cancelled,"Old floor preparation cancels")
	check(world._content_rng.state==replacement_rng,"Cancellation never restores old RNG into new floor")
	for frame in 4: await process_frame
	check(world.world_effects_root.get_child_count()==0,"Cancellation leaves no old sources")
	check(root.find_children("*","SubViewport",true,false).all(func(viewport: Node)->bool: return not viewport.has_meta(&"destruction_render_preparation")),"Floor cancellation releases private destruction world")
	task.queue_free()
	var destroyed_task:=preload("res://tests/support/firearm_preparation_task.gd").new(); root.add_child(destroyed_task)
	destroyed_task.begin(world)
	await process_frame
	display.queue_free()
	while not destroyed_task.finished: await process_frame
	check(destroyed_task.result.cancelled,"Removed world cancels without resuming a freed world method")
	check(root.find_children("*","SubViewport",true,false).all(func(viewport: Node)->bool: return not viewport.has_meta(&"destruction_render_preparation")),"World removal releases private destruction world")
	destroyed_task.queue_free(); paused=false
	for frame in 4: await process_frame
	print("FIREARM_PREPARATION_LIFECYCLE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
