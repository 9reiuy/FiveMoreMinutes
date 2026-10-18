extends SceneTree
## GPU-only diagnostic. No production loading or camera changes.
const PROBE = preload("res://tests/support/destruction_mixed_light_probe.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func count_viewports(node: Node) -> int:
	var total := 1 if node is SubViewport and not node.has_meta(&"test_destruction_warm_viewport") else 0
	for child in node.get_children(): total += count_viewports(child)
	return total
func settle() -> void:
	for frame in 6: await RenderingServer.frame_post_draw
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.add_child(preload("res://tests/support/render_progress_watchdog.gd").new())
	var settings: Node = root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false; world.persist_profile = false; world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false; root.add_child(display)
	check(world.regenerate(41001), "Initial real content generated")
	world.player.invulnerability_left = 999
	for frame in 30: await process_frame
	paused = true
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	Furniture3DDebris.shader_variant_anchors.clear()
	for floor_number in 3:
		print("DESTRUCTION_BUDGET_STAGE floor=",floor_number+1," begin")
		var generation_ms := 0.0
		var overlapping: Node
		var overlap_mode := floor_number>0 and "--overlap-stage" in OS.get_cmdline_user_args()
		var combined_started:=Time.get_ticks_usec()
		var stage_and_warm_ms := 0.0
		if floor_number > 0:
			if "--overlap-stage" in OS.get_cmdline_user_args():
				overlapping=preload("res://tests/support/destruction_warm_task.gd").new()
				root.add_child(overlapping); overlapping.begin(world)
			world.floor_transition_in_progress = true; world.transition_phase = &"CAB_RIDE"
			var started := Time.get_ticks_usec()
			check(await world._regenerate_staged(41001 + floor_number, floor_number + 1, world.transition_generation_token), "Real staged floor generation")
			generation_ms = (Time.get_ticks_usec() - started) / 1000.0
			print("DESTRUCTION_BUDGET_STAGE floor=",floor_number+1," generated warm_done=",overlapping.finished if overlapping!=null else false)
			if overlap_mode:
				while not overlapping.finished: await process_frame
				stage_and_warm_ms=(Time.get_ticks_usec()-combined_started)/1000.0
		world.player.global_position = world.get_player_root_position_for_cell(world.spawn_cell)
		world.transition_phase = &"IDLE"; world._update_camera_and_actor_projection(0.0); display._process(0.0)
		await settle()
		var camera_transform: Transform3D = world.camera_3d.global_transform
		var viewport_count := count_viewports(root)
		var environment: Environment = world.get_world_3d().environment
		var sun: DirectionalLight3D = world.shadow_manager.sun
		var sun_state := [sun.global_transform, sun.visible, sun.shadow_enabled, sun.light_energy]
		var before: PackedByteArray = display.world_viewport.get_texture().get_image().get_data()
		var warm: Dictionary
		if overlap_mode:
			warm=overlapping.result; overlapping.queue_free()
		else:
			var probe: Script=preload("res://tests/support/destruction_parallel_variant_probe.gd") if "--parallel-variants" in OS.get_cmdline_user_args() else PROBE
			warm=await probe.run(self, world)
		await settle()
		var after: PackedByteArray = display.world_viewport.get_texture().get_image().get_data()
		var released: bool=warm.viewport_released
		if warm.has("release_ref"): released=warm.release_ref.get_ref()==null
		check(released, "Temporary warm viewport released")
		check(count_viewports(root) == viewport_count, "No viewport accumulation")
		check(world.camera_3d.global_transform == camera_transform, "Formal camera untouched")
		check(world.get_world_3d().environment == environment, "Formal environment untouched")
		check([sun.global_transform, sun.visible, sun.shadow_enabled, sun.light_energy] == sun_state, "Formal sun untouched")
		var changed_bytes := 0
		if before.size() == after.size():
			for index in before.size():
				if before[index] != after[index]: changed_bytes += 1
		else: changed_bytes = -1
		check(changed_bytes == 0, "Frozen formal world pixels unchanged by private warm")
		var combined_ms: float = stage_and_warm_ms if overlap_mode else generation_ms + float(warm.elapsed_ms)
		print("DESTRUCTION_WARM_TRANSITION ", JSON.stringify({"floor":floor_number+1,"generation_ms":generation_ms,"warm_ms":warm.elapsed_ms,"combined_ms":combined_ms,"ride_budget_applies":floor_number>0,"warm_added_ride_ms":maxf(2000.0,combined_ms)-maxf(2000.0,generation_ms),"over_minimum_ride_ms":maxf(0.0,combined_ms-2000.0),"changed_bytes":changed_bytes,"viewport_count":viewport_count,"gpu":RenderingServer.get_video_adapter_name()}))
	settings.values = saved
	paused = false; display.queue_free()
	for frame in 4: await process_frame
	print("DESTRUCTION_WARM_TRANSITION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
