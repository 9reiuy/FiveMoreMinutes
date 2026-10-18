extends RefCounted
const PIXEL=preload("res://scripts/ui/pixel_transition.gd")
## Owns a root-viewport cover and pause while the new floor submits its real
## first-use rendering. Scene setup remains the world's existing transition.
class InputCover extends CanvasLayer:
	func _input(_event: InputEvent) -> void:
		get_viewport().set_input_as_handled()

static func run(tree: SceneTree,world: Node3D,setup: Callable,transition_token: int,prepare_rendering: bool=true) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
	# Headless regression runs cannot emit frame_post_draw. Keep the original
	# scene setup/exit flow without starting a render-only wait or global pause.
	if DisplayServer.get_name()=="headless":
		var valid: bool=world.transition_generation_token==transition_token and setup.is_valid()
		if valid: valid=bool(setup.call())
		return {"cancelled":not valid,"skipped":"headless","cover_released":true,"pause_restored":true}
	var was_paused:=tree.paused
	var floor_token: int=world.get_current_floor_token()
	var cover:=InputCover.new()
	cover.name="FloorExitRenderPreparationCover"; cover.layer=1000
	cover.process_mode=Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(cover)
	var black:=ColorRect.new(); black.color=Color.BLACK
	black.material=PIXEL.material(); black.material.set_shader_parameter("progress",1.0)
	black.mouse_filter=Control.MOUSE_FILTER_STOP
	black.size=tree.root.get_visible_rect().size; cover.add_child(black)
	tree.paused=true
	var started:=Time.get_ticks_usec()
	# Cover must reach the real output before floor visibility/pose changes.
	for frame in 2: await RenderingServer.frame_post_draw
	var cancelled: bool=not is_instance_valid(world) or not world.is_inside_tree()
	if not cancelled: cancelled=world.get_current_floor_token()!=floor_token or world.transition_generation_token!=transition_token
	var report: Dictionary={"cancelled":true}
	if not cancelled and setup.is_valid() and bool(setup.call()):
		if prepare_rendering:
			var pools: Dictionary=await prepare_pools(tree,world,floor_token,transition_token)
			cancelled=bool(pools.get("cancelled",true))
			if not cancelled:
				world.begin_firearm_render_preparation()
				report=await preload("res://scripts/dream/firearm_render_preparation.gd").run(tree,world)
				cancelled=bool(report.get("cancelled",true))
			report["capture_pools"]=pools
		else:
			# Floor, pools and first-use variants were already submitted before
			# the visible cab ride. Only submit the final camera/mask handoff.
			for frame in 3: await RenderingServer.frame_post_draw
			report={"cancelled":false,"prewarmed":true,"temporary_sources":0}
	else:
		cancelled=true
	if not cancelled:
		cancelled=not is_instance_valid(world) or not world.is_inside_tree()
		if not cancelled: cancelled=world.get_current_floor_token()!=floor_token or world.transition_generation_token!=transition_token
	report["covered_elapsed_ms"]=(Time.get_ticks_usec()-started)/1000.0
	if not cancelled:
		# A short arrival dissolve replaces part of the original chime hold;
		# the floor has already rendered and the regular door animation follows.
		var guard: Callable=func()->bool:
			return is_instance_valid(world) and world.is_inside_tree() and world.get_current_floor_token()==floor_token and world.transition_generation_token==transition_token
		cancelled=not await PIXEL.animate(black,1,0,0.12,guard)
	# Never leave a global pause or cover behind when its world is replaced.
	if is_instance_valid(cover): cover.queue_free()
	tree.paused=was_paused
	for frame in 2: await tree.process_frame
	report["cancelled"]=cancelled
	report["transition_elapsed_ms"]=(Time.get_ticks_usec()-started)/1000.0
	report["cover_released"]=not is_instance_valid(cover)
	report["pause_restored"]=tree.paused==was_paused
	return report

static func prepare_pools(tree: SceneTree,world: Node3D,floor_token: int,transition_token: int) -> Dictionary:
	if not tree.paused: return {"cancelled":true,"reason":"gameplay_not_paused"}
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
	if world.get_current_floor_token()!=floor_token or world.transition_generation_token!=transition_token: return {"cancelled":true}
	var started:=Time.get_ticks_usec()
	var peak_ms:=0.0
	var batches:=0
	# This work is covered and paused. Keep every slot and every native draw;
	# compare the old budget through metadata without changing pool capacities.
	var batch_budget_usec: int=maxi(1,int(world.get_meta(&"test_capture_pool_batch_usec",8000)))
	var draw_wait_usec:=0
	var job_cpu_usec: Array[int]=[0,0,0,0,0,0]
	var job_calls: Array[int]=[0,0,0,0,0,0]
	var job_names: Array[String]=["projectile","muzzle","shell","feedback","blood_ground","floor_object"]
	var jobs: Array=[
		[world._get_projectile_capture_pool().prewarm,[world.camera_3d,1]],
		[world._get_muzzle_capture_pool().prewarm,[world.camera_3d,1]],
		[world._get_shell_capture_pool().prewarm,[world.camera_3d,1]],
		[world._get_feedback_capture_pool().prewarm,[world.camera_3d,1]],
		[world._get_blood_ground_capture_pool().prewarm,[world.camera_3d,world.BLOOD_FLOOR_WORLD_Y,1]],
		[world._get_floor_object_capture_pool().prewarm,[world.camera_3d,world.dynamic_shadows_enabled,1]]]
	var job_index:=0
	while job_index<jobs.size():
		if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
		if world.get_current_floor_token()!=floor_token or world.transition_generation_token!=transition_token: return {"cancelled":true}
		var batch_started:=Time.get_ticks_usec()
		while job_index<jobs.size():
			var job: Array=jobs[job_index]
			if not job[0].is_valid(): return {"cancelled":true}
			var call_started:=Time.get_ticks_usec()
			var completed: bool=bool(job[0].callv(job[1]))
			job_cpu_usec[job_index]+=Time.get_ticks_usec()-call_started
			job_calls[job_index]+=1
			if completed: job_index+=1
			# Bound work between draws, not total capacity. One indivisible carrier
			# may exceed the budget; report the actual peak rather than a guarantee.
			if Time.get_ticks_usec()-batch_started>=batch_budget_usec: break
		peak_ms=maxf(peak_ms,(Time.get_ticks_usec()-batch_started)/1000.0)
		batches+=1
		var draw_started:=Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		draw_wait_usec+=Time.get_ticks_usec()-draw_started
	var pool_timings: Dictionary={}
	for index in jobs.size():
		pool_timings[job_names[index]]={"cpu_ms":job_cpu_usec[index]/1000.0,"calls":job_calls[index]}
	return {"cancelled":false,"batches":batches,"batch_budget_ms":batch_budget_usec/1000.0,"draw_wait_ms":draw_wait_usec/1000.0,"pool_timings":pool_timings,"peak_cpu_ms":peak_ms,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"paused":tree.paused}
