extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _ready() -> void:
	call_deferred("_run")

func _save_shot(filename: String) -> Image:
	for i in range(4):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ARTIFACT_DIR + filename)
	return img

func _count_mesh_instances(node: Node) -> int:
	var c := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		c += _count_mesh_instances(child)
	return c

func _run() -> void:
	print("\n=== STARTING POST-OPTIMIZATION BENCHMARK & VISUAL PARITY VERIFICATION ===")
	preload("res://tests/support/background_gpu.gd").start(get_tree())
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)

	for i in range(10):
		await get_tree().process_frame
		RenderingServer.force_draw(false)

	seed(54321)
	main.debug_console._execute_command("gotodream")

	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if is_instance_valid(main._supported_dream_world) and not main.transition_running:
			break

	var world: Node3D = main._supported_dream_world as Node3D
	while is_instance_valid(world) and bool(world.get("floor_transition_in_progress")):
		await get_tree().process_frame
		RenderingServer.force_draw(false)

	world.set_meta(&"test_trace_floor_generation", true)
	world.set("_startup_profile_enabled", true)
	var t_regen0 := Time.get_ticks_usec()
	world.regenerate(54321)
	var regen_ms := float(Time.get_ticks_usec() - t_regen0) / 1000.0
	var tf0 := Time.get_ticks_usec()
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var post_regen_frame0_ms := float(Time.get_ticks_usec() - tf0) / 1000.0

	for i in range(24):
		await get_tree().process_frame
		RenderingServer.force_draw(false)

	var total_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mesh_count := _count_mesh_instances(world)
	await _save_shot("ref_after_spawn.png")
	var dc_spawn := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var player: Node2D = world.get("player") as Node2D
	var cutaway = world.get("office_wall_cutaway")
	var last_cutaway_count := int(cutaway.get("refresh_count")) if cutaway != null else 0

	var frame_times: Array[float] = []
	var draw_calls: Array[int] = []
	var max_cutaway_ms := 0.0
	var max_cutout_ms := 0.0
	var sum_cutout_ms := 0.0

	for step in range(120):
		if is_instance_valid(player):
			player.global_position += Vector2(3.5, 1.5 * sin(float(step) * 0.1))
			get_viewport().warp_mouse(Vector2(640 + cos(step * 0.15) * 160, 360 + sin(step * 0.15) * 120))
			if step == 20 or step == 50 or step == 85:
				player.set("dash_charges", 1)
				player.set("dash_cooldown_left", 0.0)
				if player.has_method("_start_dash"):
					player.call("_start_dash", Vector2.RIGHT)
			if step % 12 == 0 and player.has_method("_try_attack"):
				player.call("_try_attack")

		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var t_proc := Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		var t_draw := Time.get_ticks_usec()

		var total_ms := float(t_draw - t0) / 1000.0
		var wall_proc_ms := float(t_proc - t0) / 1000.0
		var draw_ms := float(t_draw - t_proc) / 1000.0
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		frame_times.append(total_ms)
		draw_calls.append(dc)

		var cur_cutaway_count := int(cutaway.get("refresh_count")) if cutaway != null else 0
		var cutaway_triggered := cur_cutaway_count != last_cutaway_count
		var cutaway_ms := float(cutaway.get("last_refresh_usec")) / 1000.0 if cutaway_triggered else 0.0
		if cutaway_ms > max_cutaway_ms:
			max_cutaway_ms = cutaway_ms
		last_cutaway_count = cur_cutaway_count

		var tc0 := Time.get_ticks_usec()
		world.call("_update_occlusion_cutouts")
		var cutout_ms := float(Time.get_ticks_usec() - tc0) / 1000.0
		sum_cutout_ms += cutout_ms
		if cutout_ms > max_cutout_ms:
			max_cutout_ms = cutout_ms

		if step % 20 == 0 or cutaway_triggered:
			print("  [Step %3d] Total=%.2fms (Proc=%.2fms Draw=%.2fms) | DC=%d | Cutaway=%.2fms | Cutout=%.2fms" % [
				step, total_ms, wall_proc_ms, draw_ms, dc, cutaway_ms, cutout_ms
			])

	# Move player to same room as ref_before_room.png after the 120-frame loop
	for room in world.rooms:
		if int(room.id) != int(world.elevator_room_id) and int(room.id) != int(world.spawn_room_id):
			world.player.global_position = Vector2(room.center_cell) * 32.0
			world.activate_room(int(room.id))
			break
	for i in range(20):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var cur_cutaway_count2 := int(cutaway.get("refresh_count")) if cutaway != null else 0
	if cur_cutaway_count2 != last_cutaway_count:
		var cm2 := float(cutaway.get("last_refresh_usec")) / 1000.0
		if cm2 > max_cutaway_ms:
			max_cutaway_ms = cm2
	await _save_shot("ref_after_room.png")
	var dc_room := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	print("\n[POST-OPTIMIZATION FLOOR METRICS]")
	print("  regenerate(54321) Total Time: %.2f ms" % regen_ms)
	print("  Post-Regen Frame 0 Time:      %.2f ms" % post_regen_frame0_ms)
	print("  SceneTree Total Nodes:        %d" % total_nodes)
	print("  World MeshInstance3D Count:   %d" % mesh_count)
	print("  Spawn Room Draw Calls:        %d" % dc_spawn)
	print("  Interior Room Draw Calls:     %d" % dc_room)

	var sorted_ft := frame_times.duplicate()
	sorted_ft.sort()
	var sum_ft := 0.0
	for v in frame_times:
		sum_ft += v
	var sum_dc := 0
	var min_dc := 999999
	var max_dc := 0
	for d in draw_calls:
		sum_dc += d
		min_dc = mini(min_dc, d)
		max_dc = maxi(max_dc, d)

	print("\n[POST-OPTIMIZATION 120-FRAME GAMEPLAY SUMMARY]")
	print("  Avg Frame Time: %.2f ms | P95: %.2f ms | Max: %.2f ms" % [
		sum_ft / float(frame_times.size()),
		sorted_ft[int(sorted_ft.size() * 0.95)],
		sorted_ft.back()
	])
	print("  Draw Calls:     Avg %d | Min %d | Max %d" % [
		sum_dc / draw_calls.size(), min_dc, max_dc
	])
	print("  Cutaway Refresh Max: %.2f ms" % max_cutaway_ms)
	print("  Occlusion Cutout Avg: %.2f ms | Max: %.2f ms" % [
		sum_cutout_ms / 120.0, max_cutout_ms
	])

	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
