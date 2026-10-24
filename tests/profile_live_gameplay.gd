extends SceneTree

const WORLD_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PROJ_SCENE := preload("res://scenes/entities/basic_projectile.tscn")

func _spawn_proj(world: Node3D, player: Node2D, pos: Vector2, dir: Vector2, dmg: float, dist: float, spd: float, w_id: StringName) -> Node2D:
	var p: Node2D = PROJ_SCENE.instantiate()
	p.global_position = pos
	p.call("setup", dir, dmg, dist, spd, &"player", player, w_id)
	world.call("add_projectile", p, player)
	return p

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		print("[PROFILE] Timeout reached, exiting.")
		quit(1)
	)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)

	# Simulate exact production startup: generate_on_ready = true, DreamDisplayBootstrap active
	var t_spawn0 := Time.get_ticks_usec()
	var world: Node3D = WORLD_SCENE.instantiate()
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.active_seed = 42001
	root.add_child(world)
	var t_spawn1 := Time.get_ticks_usec()
	print("[PROFILE] Synchronous add_child(world) + _ready/regenerate: %.2f ms" % [(t_spawn1 - t_spawn0) / 1000.0])

	# Measure the first 15 frames after spawn (including DreamDisplayBootstrap deferred reparenting)
	for f in 15:
		var f0 := Time.get_ticks_usec()
		await process_frame
		var f1 := Time.get_ticks_usec()
		var refl := world.get_node_or_null("FloorReflections")
		var dither := world.get_node_or_null("OfficeDitherLighting")
		var pend_sz: int = refl.pending.size() if refl != null else -1
		var dither_sz: int = dither.meshes.size() if dither != null else -1
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var compiles := (
			int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
			+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
			+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
			+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
		)
		if f < 8 or (f1 - f0) > 16000:
			print("[PROFILE] Post-spawn frame %d: %.2f ms | refl_pending=%d | dither_meshes=%d | DC=%d | nodes=%d | compiles=%d" % [
				f, (f1 - f0) / 1000.0, pend_sz, dither_sz, dc, nodes, compiles
			])

	# Wait a few frames to settle
	for _i in 10:
		await process_frame

	# 1. Measure First Weapon Shot (muzzle flash + smoke + projectile)
	var player: Node2D = world.player
	var shoot_pos := player.global_position + Vector2(18, 0)
	var c_before := (
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	)
	var n_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var m0 := Time.get_ticks_usec()
	var sm0 := Time.get_ticks_usec()
	world.spawn_weapon_muzzle(shoot_pos, Vector2.RIGHT, &"pistol", player)
	var sm1 := Time.get_ticks_usec()
	_spawn_proj(world, player, shoot_pos, Vector2.RIGHT, 25.0, 320.0, 950.0, &"basic")
	var m1 := Time.get_ticks_usec()
	await process_frame
	var m2 := Time.get_ticks_usec()
	var c_after := (
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	)
	var n_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("[PROFILE] First shot: muzzle=%.2fms, add_proj=%.2fms, frame=%.2fms (proc=%.2fms, phys=%.2fms, nodes=+%d, compiles=+%d)" % [
		(sm1 - sm0) / 1000.0, (m1 - sm1) / 1000.0, (m2 - m0) / 1000.0, proc_ms, phys_ms, n_after - n_before, c_after - c_before
	])

	# 2. Measure Shotgun 8-pellet volley + rapid pistol fire over 30 frames
	var volley_frame_times: Array[float] = []
	for f in 30:
		var f0 := Time.get_ticks_usec()
		var s_call_usec := 0
		if f % 5 == 0:
			var sc0 := Time.get_ticks_usec()
			world.spawn_weapon_muzzle(shoot_pos, Vector2.RIGHT.rotated(f * 0.05), &"shotgun", player)
			for p in 8:
				var ang := (p - 3.5) * 0.06
				_spawn_proj(world, player, shoot_pos, Vector2.RIGHT.rotated(ang), 18.0, 260.0, 900.0, &"shotgun")
			s_call_usec = Time.get_ticks_usec() - sc0
		await process_frame
		var f1 := Time.get_ticks_usec()
		var f_ms := (f1 - f0) / 1000.0
		volley_frame_times.append(f_ms)
		if f_ms >= 14.0:
			var p_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var ph_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var act_p := get_nodes_in_group(&"active_basic_projectiles").size()
			print("  [VOLLEY FRAME %d] total=%.2fms | spawn_call=%.2fms | proc=%.2fms | phys=%.2fms | DC=%d | active_proj=%d" % [
				f, f_ms, s_call_usec / 1000.0, p_ms, ph_ms, dc, act_p
			])
	var max_volley := 0.0
	var sum_volley := 0.0
	for t in volley_frame_times:
		sum_volley += t
		if t > max_volley: max_volley = t
	print("[PROFILE] Shotgun volley 30 frames: avg=%.2f ms, max=%.2f ms" % [sum_volley / volley_frame_times.size(), max_volley])

	# Direct micro-benchmark of BasicProjectile._update_office_tracer()
	var projs := get_nodes_in_group(&"active_basic_projectiles")
	if not projs.is_empty():
		var pnode: Node = projs[0]
		var t_tr0 := Time.get_ticks_usec()
		for _k in 50:
			pnode._trail_clock += 0.008
			pnode.global_position += Vector2(6.0, 0.5)
			pnode._record_trail_position()
			pnode._update_office_tracer()
		var t_tr1 := Time.get_ticks_usec()
		print("[PROFILE] 50x BasicProjectile._update_office_tracer(): %.2f ms (%.3f ms/call)" % [
			(t_tr1 - t_tr0) / 1000.0, (t_tr1 - t_tr0) / 50000.0
		])

	# 3. Measure Glass Window Shatter (DestructionFloorDebris.spawn)
	var windows: Array = world.wall_root.find_children("ExteriorBreakablePane", "", true, false)
	if not windows.is_empty():
		var pane: Node3D = windows[0]
		var g0 := Time.get_ticks_usec()
		preload("res://scripts/dream/destruction_floor_debris.gd").spawn(pane, Vector2.RIGHT, true)
		var g1 := Time.get_ticks_usec()
		await process_frame
		var g2 := Time.get_ticks_usec()
		print("[PROFILE] 1st Glass shatter spawn(): %.2f ms | Frame with shatter: %.2f ms" % [
			(g1 - g0) / 1000.0, (g2 - g0) / 1000.0
		])
		if windows.size() > 1:
			var pane2: Node3D = windows[1]
			var g3 := Time.get_ticks_usec()
			preload("res://scripts/dream/destruction_floor_debris.gd").spawn(pane2, Vector2.RIGHT, true)
			var g4 := Time.get_ticks_usec()
			print("[PROFILE] 2nd Glass shatter spawn(): %.2f ms" % [(g4 - g3) / 1000.0])

	# 4. Measure Door Shatter
	for candidate in world.door_root.get_children():
		if candidate.has_method("shatter") and not candidate.locked:
			var d0 := Time.get_ticks_usec()
			candidate.shatter(Vector2.RIGHT)
			var d1 := Time.get_ticks_usec()
			print("[PROFILE] Door shatter(): %.2f ms" % [(d1 - d0) / 1000.0])
			break

	# 5. Measure Per-Frame Subsystem Breakdown across 60 active combat frames
	var dither_node: Node = world.get_node_or_null("OfficeDitherLighting")
	var refl_node: Node = world.get_node_or_null("FloorReflections")
	var bridges: Array = world.actor_depth_bridges_root.get_children()

	var sum_dither_usec := 0
	var sum_bridges_usec := 0
	var sum_cutout_usec := 0
	var sum_world_proc_usec := 0

	for f in 60:
		player.global_position += Vector2(cos(f * 0.2) * 3.0, sin(f * 0.2) * 3.0)
		var u0 := Time.get_ticks_usec()
		if dither_node != null:
			dither_node._process(1.0 / 60.0)
		var u1 := Time.get_ticks_usec()
		sum_dither_usec += (u1 - u0)

		var b0 := Time.get_ticks_usec()
		for b in bridges:
			if is_instance_valid(b) and b.is_processing():
				b._process(1.0 / 60.0)
		var b1 := Time.get_ticks_usec()
		sum_bridges_usec += (b1 - b0)

		var c0 := Time.get_ticks_usec()
		world._update_occlusion_cutouts()
		var c1 := Time.get_ticks_usec()
		sum_cutout_usec += (c1 - c0)

		var w0 := Time.get_ticks_usec()
		world._process(1.0 / 60.0)
		var w1 := Time.get_ticks_usec()
		sum_world_proc_usec += (w1 - w0)

	print("[PROFILE] 60-frame avg per-frame costs:")
	print("  OfficeDitherLighting._process: %.3f ms/frame" % [sum_dither_usec / 60000.0])
	print("  ActorDepthBridges._process (all active=%d): %.3f ms/frame" % [bridges.size(), sum_bridges_usec / 60000.0])
	print("  world._update_occlusion_cutouts: %.3f ms/frame" % [sum_cutout_usec / 60000.0])
	print("  world._process total: %.3f ms/frame" % [sum_world_proc_usec / 60000.0])

	quit(0)
