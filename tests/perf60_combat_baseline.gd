extends SceneTree
## Real SelectivePixel + Dream3D combat stress for 60fps work.
## Boot matches tests/random_combat_perf.gd (autoload-safe load(), regenerate).
## Primary metric: wall-clock frame_ms from frame_post_draw deltas (NOT TIME_PROCESS —
## that monitor is a ~1s window max). process/physics monitors logged as window_max only.
##
## DISPLAY=:7 godot --path . --position -2400,-2400 --resolution 1280x720 \
##   -s tests/perf60_combat_baseline.gd -- --tag=baseline --seed=41001

const OUT_DIR := "/workspace/perf60"
const BUDGET_MS := 16.667
const SPIKE_MS := 25.0

var tag := "baseline"
var seed_arg := 41001
var idle_sec := 3.0
var combat_sec := 10.0
var walk_sec := 5.0
var rows: Array[Dictionary] = []
var phase := "boot"
var last_usec := 0
var last_physics_frames := 0
var world: Node3D
var display: Control
var world_vp_rid := RID()
var recording := false

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.substr(6)
		elif a.begins_with("--seed="): seed_arg = int(a.substr(7))
		elif a.begins_with("--idle="): idle_sec = float(a.substr(7))
		elif a.begins_with("--combat="): combat_sec = float(a.substr(9))
		elif a.begins_with("--walk="): walk_sec = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	call_deferred("_run")

func L(t: String) -> void:
	print("[PERF60] " + t)
	var path := OUT_DIR.path_join("%s_log.txt" % tag)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(t)
	f.close()

func _pct(sorted: Array, p: float) -> float:
	if sorted.is_empty(): return 0.0
	return float(sorted[mini(int(sorted.size() * p), sorted.size() - 1)])

func _stats(arr: Array) -> Dictionary:
	if arr.is_empty():
		return {"n": 0, "med": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "over167": 0, "over25": 0}
	var s := arr.duplicate(); s.sort()
	var over167 := 0; var over25 := 0
	for v in s:
		if float(v) > BUDGET_MS: over167 += 1
		if float(v) > SPIKE_MS: over25 += 1
	return {"n": s.size(), "med": _pct(s, 0.5), "p95": _pct(s, 0.95), "p99": _pct(s, 0.99),
		"max": float(s.back()), "over167": over167, "over25": over25}

func _living_enemies() -> Array:
	var out: Array = []
	if world == null or world.enemy_root == null: return out
	for c in world.enemy_root.get_children():
		if c is CharacterBody2D and is_instance_valid(c) and not bool(c.get("dead")):
			out.append(c)
	return out

func _count_active(enemies: Array) -> int:
	var n := 0
	for e in enemies:
		if e.can_process() and e.is_physics_processing(): n += 1
	return n

func _on_screen_count(enemies: Array) -> int:
	var cam: Camera3D = world.get("camera_3d")
	if cam == null: return 0
	var vp := cam.get_viewport().get_visible_rect().grow(40.0)
	var n := 0
	var cell: float = float(world.CELL_PIXELS)
	for e in enemies:
		var gp: Vector2 = e.global_position
		var w := world.to_global(Vector3(gp.x / cell, 0.48, gp.y / cell))
		if cam.is_position_behind(w): continue
		if vp.has_point(cam.unproject_position(w)): n += 1
	return n

func _tall_furniture() -> Node3D:
	var best: Node3D = null
	var best_h := 0.0
	for n in world.find_children("*", "Node3D", true, false):
		if not (n.has_meta(&"occlusion_cutout_occluder") and bool(n.get_meta(&"occlusion_cutout_occluder"))):
			continue
		if not (n as Node3D).is_visible_in_tree(): continue
		var have := false; var box := AABB()
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree(): continue
			var a: AABB = mi.global_transform * mi.get_aabb()
			box = a if not have else box.merge(a); have = true
		if have and box.size.y > best_h and box.size.y >= 1.2 and box.size.x < 3.5 and box.size.z < 3.5:
			best_h = box.size.y; best = n
	return best

func _pack_crowd(enemies: Array, furn: Node3D) -> void:
	var cam: Camera3D = world.camera_3d
	var fwd := -cam.global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := cam.global_transform.basis.x; right.y = 0.0; right = right.normalized()
	var have := false; var box := AABB()
	for m in furn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		box = a if not have else box.merge(a); have = true
	var c := box.get_center()
	var depth := absf(fwd.x) * box.size.x * 0.5 + absf(fwd.z) * box.size.z * 0.5
	var base := Vector3(c.x, 0, c.z) + fwd * (depth + 0.4)
	var cell: float = float(world.CELL_PIXELS)
	if world.player != null:
		var front := Vector3(c.x, 0, c.z) - fwd * (depth + 1.2)
		var local_p: Vector3 = world.to_local(front)
		world.player.global_position = Vector2(local_p.x, local_p.z) * cell
		world.player.set("current_health", 80.0)
		world.player.set("invulnerability_left", 3600.0)
	var i := 0
	for e in enemies:
		var col := i % 4; var row := int(i / 4)
		var offset := right * ((col - 1.5) * 0.35) + fwd * (row * 0.28)
		var behind := base + offset
		var local: Vector3 = world.to_local(behind)
		e.global_position = Vector2(local.x, local.z) * cell
		e.set_physics_process(true); e.set_process(true)
		if e.has_method("set_room_runtime_active"):
			e.call("set_room_runtime_active", true)
		if "target" in e: e.set("target", world.player)
		i += 1

func _on_frame() -> void:
	if not recording: return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - last_usec) / 1000.0
	last_usec = now
	var pf := Engine.get_physics_frames()
	var physics_steps := pf - last_physics_frames
	last_physics_frames = pf
	var enemies := _living_enemies()
	var cutout_ms := 0.0
	if world.has_meta(&"perf60_last_cutout_ms"):
		cutout_ms = float(world.get_meta(&"perf60_last_cutout_ms"))
	rows.append({
		"phase": phase,
		"frame_ms": frame_ms,
		"monitor_process_window_max_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"monitor_physics_window_max_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"physics_steps": physics_steps,
		"world_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(world_vp_rid) if world_vp_rid.is_valid() else 0.0,
		"world_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(world_vp_rid) if world_vp_rid.is_valid() else 0.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"active_2d": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"active_3d": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"enemies_alive": enemies.size(),
		"enemies_active": _count_active(enemies),
		"enemies_on_screen": _on_screen_count(enemies),
		"cutout_ms": cutout_ms,
		"room": int(world.get("current_room_id")) if is_instance_valid(world) else -1,
	})

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if is_instance_valid(world) and world.player != null:
			world.player.set("current_health", 80.0)
			world.player.set("invulnerability_left", 3600.0)
		await process_frame

func _report_phase(ph: String) -> void:
	var ft: Array = []; var rcpu: Array = []; var gpu: Array = []; var cut: Array = []
	var max_alive := 0; var max_onscreen := 0; var max_active := 0
	for r in rows:
		if r.phase != ph: continue
		ft.append(r.frame_ms); rcpu.append(r.world_cpu_ms); gpu.append(r.world_gpu_ms); cut.append(r.cutout_ms)
		max_alive = maxi(max_alive, int(r.enemies_alive))
		max_onscreen = maxi(max_onscreen, int(r.enemies_on_screen))
		max_active = maxi(max_active, int(r.enemies_active))
	var sf := _stats(ft); var sc := _stats(rcpu); var sg := _stats(gpu); var su := _stats(cut)
	L("PHASE %s frames=%d enemies_alive_max=%d active_max=%d on_screen_max=%d" % [ph, sf.n, max_alive, max_active, max_onscreen])
	L("  frame_ms   med=%.2f p95=%.2f p99=%.2f max=%.2f over16.7=%d over25=%d" % [sf.med, sf.p95, sf.p99, sf.max, sf.over167, sf.over25])
	L("  worldCPU   med=%.2f p95=%.2f p99=%.2f max=%.2f  (llvmpipe; not user GPU)" % [sc.med, sc.p95, sc.p99, sc.max])
	L("  worldGPU   med=%.2f p95=%.2f p99=%.2f max=%.2f  (llvmpipe; ignore for ship)" % [sg.med, sg.p95, sg.p99, sg.max])
	L("  cutout_ms  med=%.3f p95=%.3f max=%.3f" % [su.med, su.p95, su.max])

func _save_csv() -> void:
	if rows.is_empty(): return
	var csv := FileAccess.open(OUT_DIR.path_join("%s_frames.csv" % tag), FileAccess.WRITE)
	var keys: Array = rows[0].keys()
	csv.store_line(",".join(PackedStringArray(keys)))
	for r in rows:
		var vals := PackedStringArray()
		for k in keys: vals.append(str(r[k]))
		csv.store_line(",".join(vals))
	csv.close()

func _screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(OUT_DIR.path_join("%s_%s.png" % [tag, name]))
		L("SHOT %s size=%s" % [OUT_DIR.path_join("%s_%s.png" % [tag, name]), str(img.get_size())])

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	L("START tag=%s seed=%d adapter=%s" % [tag, seed_arg, RenderingServer.get_video_adapter_name()])
	L("METRIC primary=frame_ms (frame_post_draw wall clock); TIME_PROCESS is window-max — not used as frame cost")

	# Autoload is a child of root under -s --path .
	if not root.has_node("SettingsManager"):
		L("FAIL no SettingsManager autoload")
		quit(2); return

	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	display.set_selective_enabled(true)
	display.set_palette_enabled(false)
	seed(seed_arg)
	if not world.regenerate(seed_arg):
		L("FAIL regenerate")
		quit(1); return
	for i in 40:
		await process_frame
	while bool(world.get("floor_transition_in_progress")):
		await process_frame

	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if display.get("world_viewport") != null:
		var wv: SubViewport = display.world_viewport
		world_vp_rid = wv.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(world_vp_rid, true)
		L("world_vp size=%s root=%s" % [str(wv.size), str(root.size)])

	var enemies := _living_enemies()
	L("BOOT enemies_alive=%d enemy_count=%s cap=%s room=%s draws=%d" % [
		enemies.size(), str(world.get("enemy_count")), str(world.get("effective_global_enemy_cap")),
		str(world.get("current_room_id")), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	])
	# Wake all rooms (worst-case population still capped by global_enemy_cap).
	var rooms: Array = world.get("rooms") if world.get("rooms") != null else []
	for room_id in range(rooms.size()):
		if world.has_method("activate_room"):
			world.call("activate_room", room_id)
	for i in 15:
		await process_frame
	enemies = _living_enemies()
	L("AFTER_ACTIVATE enemies_alive=%d rooms=%d" % [enemies.size(), rooms.size()])

	process_frame.connect(_on_frame)
	recording = true
	last_usec = Time.get_ticks_usec()
	last_physics_frames = Engine.get_physics_frames()

	phase = "idle"
	await _wait(idle_sec)
	await _screenshot("idle")

	var furn := _tall_furniture()
	enemies = _living_enemies()
	if furn != null and not enemies.is_empty():
		_pack_crowd(enemies, furn)
		L("PACKED behind %s enemies=%d" % [str(furn.name), enemies.size()])
	else:
		L("PACK skip furn=%s enemies=%d" % [str(furn), enemies.size()])
	for i in 20:
		await process_frame
	# Enable combat fire.
	if world.player != null:
		if world.player.has_method("equip_weapon"):
			world.player.call("equip_weapon", "assault_rifle", world.get("config"))
		world.player.set_meta(&"force_weapon_attack", true)
	enemies = _living_enemies()
	L("COMBAT_STATE alive=%d active=%d on_screen=%d" % [
		enemies.size(), _count_active(enemies), _on_screen_count(enemies)
	])
	phase = "combat_crowd"
	await _wait(combat_sec)
	await _screenshot("combat_crowd")
	if world.player != null:
		world.player.remove_meta(&"force_weapon_attack")

	phase = "walk"
	var player: CharacterBody2D = world.get("player")
	var walk_end := Time.get_ticks_msec() + int(walk_sec * 1000.0)
	var room_i := 0
	while Time.get_ticks_msec() < walk_end and rooms.size() > 0:
		var target_cell: Vector2i = world.call("get_room_center_cell", room_i % rooms.size())
		var target: Vector2 = world.call("get_player_root_position_for_cell", target_cell)
		var steps := 0
		while is_instance_valid(player) and player.global_position.distance_to(target) > 8.0 and steps < 200:
			player.global_position = player.global_position.move_toward(target, 150.0 * (1.0 / 60.0))
			player.set("current_health", 80.0)
			await process_frame
			steps += 1
		room_i += 1
		await _wait(0.3)
	await _screenshot("walk")

	recording = false
	process_frame.disconnect(_on_frame)
	_save_csv()
	for ph in ["idle", "combat_crowd", "walk"]:
		_report_phase(ph)
	L("TOP_SPIKES")
	var idx: Array = range(rows.size())
	idx.sort_custom(func(a, b): return rows[a].frame_ms > rows[b].frame_ms)
	for i in mini(30, idx.size()):
		var r: Dictionary = rows[idx[i]]
		L("  #%d %s frame=%.1f rCPU=%.1f gpu=%.1f draws=%d enemies=%d/%d/%d cut=%.2f room=%d" % [
			idx[i], r.phase, r.frame_ms, r.world_cpu_ms, r.world_gpu_ms, r.draw_calls,
			r.enemies_active, r.enemies_on_screen, r.enemies_alive, r.cutout_ms, r.room
		])
	L("DONE adapter=%s rows=%d" % [RenderingServer.get_video_adapter_name(), rows.size()])
	quit(0)
