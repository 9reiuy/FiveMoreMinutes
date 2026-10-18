extends SceneTree
const PREPARER=preload("res://scripts/dream/floor_exit_render_preparation.gd")
const ACTOR_BRIDGE=preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
var checks:=0
var failures:=0
var task_finished:=false
var task_report: Dictionary={}
func begin_pool_test(world: Node3D) -> void:
	task_report=await PREPARER.prepare_pools(self,world,world.get_current_floor_token(),world.transition_generation_token)
	task_finished=true
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 6: await RenderingServer.frame_post_draw
func remove_idle(pool: Node3D) -> void:
	for property in ["idle","small_idle","large_idle"]:
		var slots: Variant=pool.get(property)
		if slots is Array:
			for bridge in slots: bridge.queue_free()
			slots.clear()
		elif slots is Dictionary:
			for array in slots.values():
				for bridge in array: bridge.queue_free()
				array.clear()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display); paused=true
	check(world.regenerate(41001),"Formal floor generated")
	world._update_camera_and_actor_projection(0.0)
	world.player_depth_bridge._process(0.0)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge is ACTOR_BRIDGE: bridge._process(0.0)
	var pools: Array=[world._get_projectile_capture_pool(),world._get_muzzle_capture_pool(),world._get_shell_capture_pool(),world._get_feedback_capture_pool(),world._get_blood_ground_capture_pool(),world._get_floor_object_capture_pool()]
	for pool in pools: remove_idle(pool)
	await settle()
	var before: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var position: Vector2=world.player.global_position
	var ammo: Dictionary=world.player.ammo_states.duplicate(true)
	var rng_state: int=world._content_rng.state
	var sources: int=world.world_effects_root.get_child_count()
	var enemies: Array=[]
	for enemy in world.enemy_root.get_children(): enemies.append([enemy.global_position,enemy.current_health,enemy.perception_update_left])
	var report: Dictionary=await PREPARER.prepare_pools(self,world,world.get_current_floor_token(),world.transition_generation_token)
	await settle()
	check(not report.cancelled and report.batches>1 and report.paused,"Bounded batches keep gameplay paused")
	check(before==display.world_viewport.get_texture().get_image().get_data(),"Frozen formal world pixels identical")
	check(world.player.global_position==position and world.player.ammo_states==ammo,"Player position and ammunition unchanged")
	check(world._content_rng.state==rng_state and world.world_effects_root.get_child_count()==sources,"RNG and effect sources unchanged")
	var enemies_after: Array=[]
	for enemy in world.enemy_root.get_children(): enemies_after.append([enemy.global_position,enemy.current_health,enemy.perception_update_left])
	check(enemies_after==enemies,"Enemy position health and perception clock unchanged")
	check(pools[0].idle.size()==32 and pools[1].idle.size()==12 and pools[2].idle.size()==32 and pools[3].idle.size()==18,"Projectile muzzle shell feedback capacities unchanged")
	check(pools[4].small_idle.size()==18 and pools[4].large_idle.size()==6,"Blood capacities unchanged")
	check(pools[5].idle[&"debris"].size()==64 and pools[5].idle[&"weapon"].size()==8 and pools[5].idle[&"shadow"].size()==8,"Floor object capacities unchanged")
	world.transition_generation_token+=1
	var cancelled: Dictionary=await PREPARER.prepare_pools(self,world,world.get_current_floor_token(),world.transition_generation_token-1)
	check(cancelled.cancelled,"Stale transition cannot prepare carriers")
	var created_before: Array=[]
	for pool in pools: created_before.append(pool.created)
	await PREPARER.prepare_pools(self,world,world.get_current_floor_token(),world.transition_generation_token)
	var created_after: Array=[]
	for pool in pools: created_after.append(pool.created)
	check(created_before==created_after,"Repeated preparation cannot accumulate carriers")
	remove_idle(pools[5]); await settle()
	begin_pool_test(world)
	await RenderingServer.frame_post_draw
	world.transition_generation_token+=1
	while not task_finished: await process_frame
	check(task_report.cancelled,"Changed transition cancels an in-progress batch")
	check(paused,"Batch cancellation cannot unpause gameplay owned by caller")
	paused=false
	var unsafe: Dictionary=await PREPARER.prepare_pools(self,world,world.get_current_floor_token(),world.transition_generation_token)
	check(unsafe.cancelled and unsafe.reason=="gameplay_not_paused","Never budget warmup while gameplay advances")
	paused=true
	print("FLOOR_CAPTURE_BUDGET_REPORT ",JSON.stringify(report))
	paused=false; display.queue_free(); await process_frame
	print("FLOOR_CAPTURE_BUDGET_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
