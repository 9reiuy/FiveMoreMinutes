extends SceneTree
## Real production-art Camera, original actors/collision/combat. Every sampled
## interval is retained, including first FX and synchronous door/breach work.
const SCENE := "res://scenes/preview/hellkind_purple_sample.tscn"
const OUT := "res://.runtime/hellkind_purple_sample_20261103/revision_woo_polygon/performance"
const RECORDER = preload("res://scripts/testing/lab_recorder.gd")
const BREACH = preload("res://scripts/dream/shared_wall_breach.gd")
var lab
var phases: Array[Dictionary] = []
var failures: Array[String] = []
var done := false
var draw_timers: Array[Dictionary] = []
var callback_rows: Array[Array] = []
var native_collector: Node
var output_path := OUT

func _profile_draw_callbacks() -> void:
	# Diagnostic only. Keep the native callback order and call each exactly once.
	for connection in RenderingServer.get_signal_connection_list(&"frame_pre_draw"):
		var callback: Callable = connection.callable
		var object := callback.get_object()
		var label := str(object.get_path()) if object is Node and object.is_inside_tree() else str(object)
		label += ":" + str(callback.get_method())
		var timer := {"label": label, "us": 0}
		draw_timers.append(timer)
		RenderingServer.frame_pre_draw.disconnect(callback)
		RenderingServer.frame_pre_draw.connect(func():
			if not callback.is_valid(): return
			var started := Time.get_ticks_usec()
			callback.call()
			timer.us = Time.get_ticks_usec() - started
		)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index in count: await process_frame

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key; event.physical_keycode = key; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key; event.physical_keycode = key
	Input.parse_input_event(event)
	await process_frame

func _set_ai(value: bool) -> void:
	lab.checks.ai.button_pressed = value
	lab.world.lab_ai = value
	for enemy in lab.world.enemy_root.get_children():
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func _release_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack"]:
		if InputMap.has_action(action): Input.action_release(action)
	if is_instance_valid(lab) and is_instance_valid(lab.world):
		lab.world.player.remove_meta(&"force_weapon_attack")
		lab.world.player.remove_meta(&"aim_direction_override")
		lab.automation = false

func _fresh() -> void:
	_release_input()
	if is_instance_valid(lab):
		await lab.retire_drawing()
		lab.free()
		await frames(4)
	lab = load(SCENE).instantiate()
	root.add_child(lab)
	while not lab.sample_ready or lab.busy: await process_frame
	lab.apply_style(3)
	lab.toggle_lamps()
	lab.sample_ui.hide(); lab.hud.hide(); lab.panel.hide()
	await frames(90)

func _near_door() -> Dictionary:
	for door in lab.world.door_root.get_children():
		if door.is_destroyed or door.is_locked() or door._collision_bodies.is_empty(): continue
		var body: StaticBody2D = door._collision_bodies[0]
		var normal := Vector2.from_angle(body.global_rotation + PI * 0.5)
		var center: Vector2 = door.get_leaf_center_2d(0)
		for sign_value in [1.0, -1.0]:
			var point: Vector2 = center - normal * sign_value * 64.0
			if lab.world._is_blood_ground_allowed(point): return {"door":door,"point":point}
	return {}

func _breach() -> bool:
	lab.world.set_meta(&"test_profile_shared_wall_breach", true)
	var keys: Array = lab.world.wall_edges.keys()
	var position: Vector2 = lab.world.player.global_position
	keys.sort_custom(func(a,b): return lab.world._edge_gameplay_position(lab.world.wall_edges[a]).distance_squared_to(position) < lab.world._edge_gameplay_position(lab.world.wall_edges[b]).distance_squared_to(position))
	for key in keys:
		if BREACH.wall_for_key(lab.world, key) == null: continue
		var was_movement_enabled: bool = lab.world.player.movement_enabled
		lab.world.player.movement_enabled = true
		var count: int = lab.world._commit_dash_wall_breaches([key], lab.world.get_current_floor_token(), Vector2.RIGHT)
		lab.world.player.movement_enabled = was_movement_enabled
		lab.recorder.mark("native_breach_cpu", lab.world.last_shared_wall_breach_profile)
		return count == 1
	return false

func phase(label: String, seconds: float, visibility: bool, workload: String) -> void:
	lab.set_vision_enabled(visibility)
	if not visibility and workload == "mixed": lab.visibility_surfaces.restore()
	var door_record := _near_door() if workload == "doors" else {}
	if workload == "doors":
		if door_record.is_empty(): failures.append(label + ": missing door fixture"); return
		lab.world.player.global_position = door_record.point
		lab.world.player.velocity = Vector2.ZERO
		lab.world._update_camera_and_actor_projection(0.0)
	if workload == "mixed":
		lab.station.select(2); lab.teleport(2)
		lab.world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
		lab.automation = true
	await frames(90)
	var config: Dictionary = lab.configuration()
	config["enemy_ai"] = true if workload == "mixed" else lab.checks.ai.button_pressed
	config.merge({"benchmark_label":label,"workload":workload,"vsync_actual":DisplayServer.window_get_vsync_mode(),"fps_cap_actual":Engine.max_fps,"threshold_ms":1000.0/60.0,"first_effects_included":true,"no_content_exclusions":true})
	lab._run_duration = seconds + 100.0
	lab._run_scenario = 0
	lab.elapsed = 0.0; lab.next_event = 0
	lab.recorder.begin(config)
	if is_instance_valid(native_collector):
		native_collector.stages.clear(); native_collector.calls.clear(); native_collector.active = true
	if workload == "mixed": _set_ai(true)
	var source_rows: Array[Array] = []
	var start := Time.get_ticks_usec()
	var next_action := 0
	var event_index := 0
	var max_move := 0.0
	var start_position: Vector2 = lab.world.player.global_position
	while float(Time.get_ticks_usec() - start) / 1000000.0 < seconds:
		await RenderingServer.frame_post_draw
		if is_instance_valid(native_collector): native_collector.sample()
		var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
		if not draw_timers.is_empty():
			var callback_row: Array = [Engine.get_process_frames(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
			for timer in draw_timers: callback_row.append(timer.us)
			callback_rows.append(callback_row)
		source_rows.append([Engine.get_process_frames(),lab.visibility_field.last_update_usec if visibility else 0,lab.visibility_surfaces.last_update_usec if visibility else 0,lab.primitive_visibility.last_update_usec if visibility else 0,lab.visibility_field.sparse_queries if visibility else 0,lab.visibility_surfaces.parameter_writes if visibility else 0,lab.visibility_field.rebuilds,lab.visibility_surfaces.full_scans,lab.primitive_visibility.scans,lab.world.enemy_root.get_child_count(),lab.actor_visibility.last_update_usec if visibility else 0,lab.actor_visibility.reflection_refreshes,lab.actor_visibility.paused_captures,Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),lab.world._owned_black_blood_stains.size()])
		max_move = maxf(max_move, start_position.distance_to(lab.world.player.global_position))
		if workload == "navigation" and elapsed >= float(next_action):
			for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
			Input.action_press(["move_right","move_down","move_left","move_up"][next_action % 4])
			if next_action > 0 and next_action % 4 == 0:
				lab.cycle_station()
				# The lab protects configuration changes during a recording. Apply
				# its exact teleport operation explicitly for this room-entry load.
				lab.world.player.global_position = lab.world.station_position(lab.station.selected)
				lab.world.player.velocity = Vector2.ZERO
				lab.world._update_camera_and_actor_projection(0.0)
				lab.recorder.mark("room_cycle",{"station":lab.station.selected})
			next_action += 1
		elif workload == "doors" and elapsed >= float(next_action) * 3.5:
			door_record.door.prepare_enemy_passage(lab.world.player.global_position)
			lab.recorder.mark("real_door_passage",{"index":next_action})
			next_action += 1
		elif workload == "mixed":
			lab.world.player.set_meta(&"force_weapon_attack", true)
			if event_index < 6 and elapsed >= 1.0 + float(event_index) * 3.0:
				var kind: String = ["breach", "blood", "smoke", "fire", "smoke", "breach"][mini(event_index,5)]
				var success := true
				if kind == "breach": success = _breach()
				elif kind == "fire":
					var burning := preload("res://scripts/dream/burning_effects.gd").install(lab.world)
					success = false
					for target in lab.world.furniture_root.get_children() + lab.world.enemy_root.get_children():
						if burning.ignite(target): success = true; break
				else:
					lab.trigger(kind)
					if not lab.recorder.events.is_empty(): success = bool(lab.recorder.events.back().get("details",{}).get("success",false))
				lab.recorder.mark("mixed_" + kind,{"index":event_index,"success":success,"shots":lab.shot_count})
				if not success: failures.append(label + ": failed " + kind)
				event_index += 1
	_release_input()
	var summary: Dictionary = lab.recorder.summary()
	var path: String = lab.recorder.finish(output_path, label)
	if is_instance_valid(native_collector): native_collector.finish(path)
	var sources := FileAccess.open(path.path_join("visibility_cpu.csv"),FileAccess.WRITE)
	sources.store_csv_line(PackedStringArray(["engine_frame","polygon_us","materials_us","primitive_us","sparse_rays","parameter_writes","mask_rebuilds","material_full_scans","primitive_full_scans","enemy_nodes","actor_us","reflection_refreshes","paused_captures","pipelines_canvas","pipelines_mesh","pipelines_draw","blood_stains"]))
	for row in source_rows:
		var strings := PackedStringArray()
		for value in row: strings.append(str(value))
		sources.store_csv_line(strings)
	sources.close()
	if not callback_rows.is_empty():
		var profile := FileAccess.open(path.path_join("draw_callbacks.csv"), FileAccess.WRITE)
		var header := PackedStringArray(["engine_frame", "process_ms", "physics_ms"])
		for timer in draw_timers: header.append(timer.label)
		profile.store_csv_line(header)
		for row in callback_rows:
			var strings := PackedStringArray()
			for value in row: strings.append(str(value))
			profile.store_csv_line(strings)
		profile.close()
		callback_rows.clear()
	var result := {"label":label,"workload":workload,"visibility":visibility,"path":path,"summary":summary,"max_movement_pixels":max_move,"event_count":lab.recorder.events.size(),"shots_fired":lab.shot_count,"native_size":lab.display.world_viewport.size,"actor_pixels":lab.measure_player_body_pixels(),"mask_triangles":lab.visibility_field.shadow_triangles,"shader_rejections":lab.visibility_surfaces.shader_rejections}
	var sampled_rooms: Dictionary = {}
	for row in lab.recorder.rows: sampled_rooms[int(row[10])] = true
	result["actual_sampled_rooms"] = sampled_rooms.keys()
	phases.append(result)
	print("WOO_POLYGON_PERF ", label, " ", JSON.stringify(summary.all_sampled))
	if workload == "navigation" and max_move < 24.0: failures.append(label + ": no real movement")
	if workload == "navigation" and sampled_rooms.size() < 4: failures.append(label + ": did not enter all four real rooms")
	if workload == "mixed" and lab.shot_count < 8: failures.append(label + ": no real fire")
	if int(summary.all_sampled.over_16_667) > 0: failures.append(label + ": over 16.667ms")

func run() -> void:
	create_timer(300.0,true,false,true).timeout.connect(func(): if not done: finish(2))
	if DisplayServer.get_name() == "headless": failures.append("Native GPU renderer required"); finish(1); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _fresh()
	if "--diagnostic-mixed" in OS.get_cmdline_user_args() or "--diagnostic-native" in OS.get_cmdline_user_args():
		if "--diagnostic-callbacks" in OS.get_cmdline_user_args(): _profile_draw_callbacks()
		if "--diagnostic-native-stages" in OS.get_cmdline_user_args():
			native_collector = preload("res://tests/woo_native_stage_collector.gd").new()
			root.add_child(native_collector)
			preload("res://scripts/app/performance_markers.gd")._reference = weakref(native_collector)
		var original := "--diagnostic-native" in OS.get_cmdline_user_args()
		await phase("off_mixed_diagnostic" if original else "on_mixed_diagnostic",19.0,not original,"mixed")
		finish(0 if failures.is_empty() else 1)
		return
	await phase("off_stationary_A",3.0,false,"stationary")
	await phase("on_stationary",6.0,true,"stationary")
	await phase("off_stationary_B",3.0,false,"stationary")
	await phase("on_navigation",16.0,true,"navigation")
	await phase("on_doors",8.0,true,"doors")
	await _fresh()
	await phase("off_native_mixed",19.0,false,"mixed")
	await _fresh()
	await phase("on_mixed",19.0,true,"mixed")
	finish(0 if failures.is_empty() else 1)

func finish(code: int) -> void:
	if done: return
	done = true
	_release_input()
	var metadata := {"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"engine":Engine.get_version_info(),"threshold_ms":1000.0/60.0,"rendering":"real production-art Camera, 640x360 world, original actor path","measurement":"all adjacent process-frame wall intervals; uncapped and vsync disabled identically in all phases to measure 60Hz headroom; includes event work and first effect frames; no screenshots or exports inside sampled windows; delayed viewport counters are not same-frame GPU timestamps","scope":"Independent four-room sample only; no Main/campaign or other-computer performance certification"}
	metadata["rendering_method"] = RenderingServer.get_current_rendering_method()
	metadata["instrumentation"] = "Native F3 monitor available on demand; dormant by default. Sample wall-interval recorder makes no synchronous render-time queries. GPU/info columns are -1, not GPU measurements."
	var file := FileAccess.open(output_path.path_join("summary.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"metadata":metadata,"phases":phases,"failures":failures,"passed":failures.is_empty()},"\t")); file.close()
	if is_instance_valid(lab):
		await lab.retire_drawing()
		lab.queue_free()
	await frames(4)
	await create_timer(.3).timeout
	print("WOO_POLYGON_PERF_RESULT ",JSON.stringify(failures))
	quit(code)
