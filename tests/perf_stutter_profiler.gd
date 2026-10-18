extends SceneTree
## TEMPORARY stutter investigation profiler (read-only diagnostics, no gameplay changes).
## Mirrors main.gd's dream entry (SelectivePixelPreview wrapper + firearm render
## preparation), then records per-frame timing while the player idles and walks
## through every room. Run WITHOUT --headless so the real GL renderer is used.

const DUNGEON_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const SELECTIVE_PIXEL_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const OUT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/scratch/"
const SPIKE_MS := 25.0
const WALK_SPEED := 150.0

var dungeon: Node3D
var pixel_screen: Node
var rows: Array[Dictionary] = []
var phase := "boot"
var last_usec := 0
var last_physics_frames := 0
var last_room := -999
var event_note := ""
var world_vp_rid := RID()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	var seed_arg := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_arg = int(a.substr(5))

	dungeon = DUNGEON_SCENE.instantiate()
	dungeon.set("persist_profile", false)
	if seed_arg != 0:
		dungeon.set("seed", seed_arg)
	pixel_screen = SELECTIVE_PIXEL_SCENE.instantiate()
	pixel_screen.set(&"preview_mode", false)
	pixel_screen.set(&"initial_selective_enabled", true)
	pixel_screen.set(&"palette_enabled", false)
	pixel_screen.set(&"world", dungeon)
	var gen_start := Time.get_ticks_usec()
	var prepare: bool = dungeon.has_method("begin_firearm_render_preparation")
	if prepare:
		dungeon.set("loading_render_preparation_pending", true)
		paused = true
	root.add_child(pixel_screen)
	for i in 2:
		await process_frame
	print("[perf] generation+enter: %.1f ms" % ((Time.get_ticks_usec() - gen_start) / 1000.0))
	if prepare and bool(dungeon.call("begin_firearm_render_preparation")):
		var prep_start := Time.get_ticks_usec()
		var result: Dictionary = await preload("res://scripts/dream/firearm_render_preparation.gd").run(self, dungeon)
		print("[perf] firearm render preparation: %.1f ms -> %s" % [(Time.get_ticks_usec() - prep_start) / 1000.0, str(result).substr(0, 300)])
		if dungeon.has_method("finish_firearm_render_preparation"):
			dungeon.call("finish_firearm_render_preparation")
	dungeon.set("loading_render_preparation_pending", false)
	paused = false

	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var sub := _find_world_subviewport(pixel_screen)
	if sub != null:
		world_vp_rid = sub.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(world_vp_rid, true)
		print("[perf] world SubViewport size=%s" % str(sub.size))

	for i in 30:
		await process_frame
	process_frame.connect(_on_frame)
	last_usec = Time.get_ticks_usec()
	last_physics_frames = Engine.get_physics_frames()

	var player: CharacterBody2D = dungeon.get("player")
	# Phase 1: idle baseline
	phase = "idle"
	await _wait_seconds(5.0, player)

	# Phase 2: walk the whole building room by room
	phase = "walk"
	var rooms: Array = dungeon.get("rooms")
	var current_cell: Vector2i = dungeon.call("_cell_for_gameplay_position", player.global_position)
	var walk_deadline := Time.get_ticks_msec() + 70000
	for room_id in range(rooms.size()):
		if Time.get_ticks_msec() > walk_deadline:
			break
		var target_cell: Vector2i = dungeon.call("get_room_center_cell", room_id)
		var path: Array = dungeon.call("find_floor_path", current_cell, target_cell)
		if path.is_empty():
			continue
		for idx in range(1, path.size()):
			var target: Vector2 = dungeon.call("get_player_root_position_for_cell", path[idx])
			while is_instance_valid(player) and player.global_position.distance_to(target) > 2.0:
				var step := WALK_SPEED * (1.0 / 60.0)
				player.global_position = player.global_position.move_toward(target, step)
				player.set("current_health", 80.0)
				await process_frame
		current_cell = target_cell
		await _wait_seconds(1.0, player)

	# Phase 3: idle again after visiting everything (accumulation check)
	phase = "idle_after"
	await _wait_seconds(5.0, player)

	process_frame.disconnect(_on_frame)
	_report()
	quit(0)


func _wait_seconds(sec: float, player: Node) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if is_instance_valid(player):
			player.set("current_health", 80.0)
		await process_frame


func _find_world_subviewport(node: Node) -> SubViewport:
	for c in node.get_children():
		if c is SubViewport and c.get_child_count() > 0:
			for cc in c.get_children():
				if cc == dungeon:
					return c
		var r := _find_world_subviewport(c)
		if r != null:
			return r
	return null


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - last_usec) / 1000.0
	last_usec = now
	var pf := Engine.get_physics_frames()
	var physics_steps := pf - last_physics_frames
	last_physics_frames = pf
	var room := int(dungeon.get("current_room_id")) if is_instance_valid(dungeon) else -1
	var note := ""
	if room != last_room:
		note = "room %d->%d" % [last_room, room]
		last_room = room
	var active_enemies := 0
	var enemy_root: Node = dungeon.get("enemy_root") if is_instance_valid(dungeon) else null
	var enemy_total := enemy_root.get_child_count() if enemy_root != null else 0
	if enemy_root != null:
		for e in enemy_root.get_children():
			if e.can_process() and e.is_physics_processing():
				active_enemies += 1
	rows.append({
		"phase": phase,
		"frame_ms": frame_ms,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"physics_steps": physics_steps,
		"root_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		"world_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(world_vp_rid) if world_vp_rid.is_valid() else 0.0,
		"world_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(world_vp_rid) if world_vp_rid.is_valid() else 0.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"tex_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"active_bodies": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"active_bodies_2d": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"enemies_active": active_enemies,
		"enemies_total": enemy_total,
		"room": room,
		"note": note,
	})


func _pct(sorted: Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[mini(int(sorted.size() * p), sorted.size() - 1)])


func _report() -> void:
	var csv := FileAccess.open(OUT_DIR + "perf_frames.csv", FileAccess.WRITE)
	var keys := rows[0].keys()
	csv.store_line(",".join(PackedStringArray(keys)))
	for r in rows:
		var vals := PackedStringArray()
		for k in keys:
			vals.append(str(r[k]))
		csv.store_line(",".join(vals))
	csv.close()

	for ph in ["idle", "walk", "idle_after"]:
		var ft: Array = []
		var proc: Array = []
		var phys: Array = []
		var rcpu: Array = []
		var gpu: Array = []
		var spikes := 0
		for r in rows:
			if r.phase != ph:
				continue
			ft.append(r.frame_ms); proc.append(r.process_ms); phys.append(r.physics_ms)
			rcpu.append(r.world_cpu_ms); gpu.append(r.world_gpu_ms)
			if r.frame_ms > SPIKE_MS:
				spikes += 1
		if ft.is_empty():
			continue
		for a in [ft, proc, phys, rcpu, gpu]:
			a.sort()
		var total := 0.0
		for v in ft: total += v
		print("[perf] phase=%s frames=%d avg=%.2fms (%.0f fps) p50=%.2f p95=%.2f p99=%.2f max=%.2f spikes>%dms=%d" % [ph, ft.size(), total / ft.size(), 1000.0 / (total / ft.size()), _pct(ft, .5), _pct(ft, .95), _pct(ft, .99), ft.back(), SPIKE_MS, spikes])
		print("        process p50=%.2f p99=%.2f max=%.2f | physics p50=%.2f p99=%.2f max=%.2f | worldRenderCPU p50=%.2f p99=%.2f max=%.2f | worldGPU p50=%.2f p99=%.2f max=%.2f" % [_pct(proc, .5), _pct(proc, .99), proc.back(), _pct(phys, .5), _pct(phys, .99), phys.back(), _pct(rcpu, .5), _pct(rcpu, .99), rcpu.back(), _pct(gpu, .5), _pct(gpu, .99), gpu.back()])

	print("[perf] ---- top 40 spike frames ----")
	var idx: Array = range(rows.size())
	idx.sort_custom(func(a, b): return rows[a].frame_ms > rows[b].frame_ms)
	for i in mini(40, idx.size()):
		var j: int = idx[i]
		var r: Dictionary = rows[j]
		# nearby room-change notes within +-3 frames
		var ctx := ""
		for k in range(maxi(0, j - 3), mini(rows.size(), j + 4)):
			if rows[k].note != "":
				ctx += " [%+d %s]" % [k - j, rows[k].note]
		print("  #%d %s frame=%.1fms proc=%.1f phys=%.1f(x%d) rCPU=%.1f gpu=%.1f draws=%d nodes=%d enemies=%d/%d bodies3d=%d%s" % [j, r.phase, r.frame_ms, r.process_ms, r.physics_ms, r.physics_steps, r.world_cpu_ms, r.world_gpu_ms, r.draw_calls, r.nodes, r.enemies_active, r.enemies_total, r.active_bodies, ctx])
	var first: Dictionary = rows[0]
	var last: Dictionary = rows.back()
	print("[perf] nodes %d -> %d, objects %d -> %d, orphans %d -> %d, texmem %.1f -> %.1f MB" % [first.nodes, last.nodes, first.objects, last.objects, first.orphans, last.orphans, first.tex_mem_mb, last.tex_mem_mb])
