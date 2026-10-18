extends SceneTree
## CPU-side combat profile: SelectivePixel + regenerate, then optionally freeze
## world SubViewport updates so frame_ms ≈ script+physics (not llvmpipe).
## Also wraps world with world_method_timing_probe for section medians.
##
## DISPLAY=:7 godot --path . --position -2400,-2400 --resolution 1280x720 \
##   -s tests/perf60_cpu_profile.gd -- --tag=cpu_base --seed=41001 --freeze-world-render=1

const OUT_DIR := "/workspace/perf60"
const BUDGET_MS := 16.667

var tag := "cpu_base"
var seed_arg := 41001
var sample_sec := 8.0
var warmup_sec := 2.0
var freeze_world_render := true
var world: Node3D
var display: Control
var rows: Array = []
var section_totals: Dictionary = {}  # name -> Array of per-frame ms
var last_usec := 0
var phase := "warm"
var recording := false

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.substr(6)
		elif a.begins_with("--seed="): seed_arg = int(a.substr(7))
		elif a.begins_with("--sample="): sample_sec = float(a.substr(9))
		elif a.begins_with("--warmup="): warmup_sec = float(a.substr(9))
		elif a.begins_with("--freeze-world-render="): freeze_world_render = a.substr(22) != "0"
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	call_deferred("_run")

func L(t: String) -> void:
	print("[PERF60CPU] " + t)
	var path := OUT_DIR.path_join("%s_log.txt" % tag)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close()

func _stats(arr: Array) -> Dictionary:
	if arr.is_empty(): return {"n":0,"med":0.0,"p95":0.0,"p99":0.0,"max":0.0,"over167":0}
	var s := arr.duplicate(); s.sort()
	var over := 0
	for v in s:
		if float(v) > BUDGET_MS: over += 1
	return {"n":s.size(),"med":float(s[s.size()/2]),"p95":float(s[mini(s.size()-1,floori(s.size()*0.95))]),
		"p99":float(s[mini(s.size()-1,floori(s.size()*0.99))]),"max":float(s.back()),"over167":over}

func _living() -> Array:
	var out: Array = []
	if world == null or world.enemy_root == null: return out
	for c in world.enemy_root.get_children():
		if c is CharacterBody2D and is_instance_valid(c) and not bool(c.get("dead")):
			out.append(c)
	return out

func _pack(enemies: Array) -> void:
	var cam: Camera3D = world.camera_3d
	var fwd := -cam.global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := cam.global_transform.basis.x; right.y = 0.0; right = right.normalized()
	# Pack in front of camera near player spawn / room center — no need tall furniture.
	var origin := cam.global_position
	origin.y = 0.0
	var base := origin + fwd * 4.0
	var cell: float = float(world.CELL_PIXELS)
	if world.player != null:
		var front := origin + fwd * 2.0
		var lp: Vector3 = world.to_local(front)
		world.player.global_position = Vector2(lp.x, lp.z) * cell
		world.player.set("current_health", 9999.0)
		world.player.set("invulnerability_left", 9999.0)
	var i := 0
	for e in enemies:
		var col := i % 4; var row := int(i / 4)
		var p := base + right * ((col - 1.5) * 0.45) + fwd * (row * 0.4)
		var local: Vector3 = world.to_local(p)
		e.global_position = Vector2(local.x, local.z) * cell
		e.set_physics_process(true); e.set_process(true)
		if e.has_method("set_room_runtime_active"): e.call("set_room_runtime_active", true)
		# Keep them alive for sustained crowd.
		e.set("current_health", 9999.0)
		if "max_health" in e: e.set("max_health", 9999.0)
		if "target" in e: e.set("target", world.player)
		i += 1

func _on_screen(enemies: Array) -> int:
	var cam: Camera3D = world.camera_3d
	var vp := cam.get_viewport().get_visible_rect().grow(40.0)
	var n := 0; var cell: float = float(world.CELL_PIXELS)
	for e in enemies:
		var gp: Vector2 = e.global_position
		var w := world.to_global(Vector3(gp.x / cell, 0.48, gp.y / cell))
		if cam.is_position_behind(w): continue
		if vp.has_point(cam.unproject_position(w)): n += 1
	return n

func _on_frame() -> void:
	if not recording: return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - last_usec) / 1000.0
	last_usec = now
	# Drain world probe section timings accumulated this frame into per-frame buckets.
	if world.get("timing_rows") != null:
		var tr: Dictionary = world.timing_rows
		for key in tr.keys():
			var arr: Array = tr[key]
			if arr.is_empty(): continue
			# sum calls this frame for this key
			var sum := 0.0
			for v in arr: sum += float(v)
			if not section_totals.has(key): section_totals[key] = []
			# Only append during sample phase; clear rows each frame via probe restart
			(section_totals[key] as Array).append(sum)
		# clear for next frame (probe accumulates until timing_finish)
		world.timing_rows.clear()
	var enemies := _living()
	rows.append({
		"phase": phase,
		"frame_ms": frame_ms,
		"enemies": enemies.size(),
		"on_screen": _on_screen(enemies),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"active_2d": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	})

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if world.player != null:
			world.player.set("current_health", 9999.0)
			world.player.set("invulnerability_left", 9999.0)
		for e in _living():
			e.set("current_health", 9999.0)
		await process_frame

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	L("START tag=%s seed=%d freeze_world_render=%s adapter=%s" % [tag, seed_arg, str(freeze_world_render), RenderingServer.get_video_adapter_name()])

	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	# Swap to timing probe script (inherits formal world).
	var exports: Dictionary = {}
	for property in world.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_EDITOR:
			exports[property.name] = world.get(property.name)
	world.set_script(preload("res://tests/support/world_method_timing_probe.gd"))
	for key in exports: world.set(key, exports[key])
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
		L("FAIL regenerate"); quit(1); return
	for i in 30: await process_frame
	while bool(world.floor_transition_in_progress): await process_frame

	var rooms: Array = world.rooms
	for room_id in range(rooms.size()):
		world.activate_room(room_id)
	for i in 10: await process_frame

	var enemies := _living()
	L("BOOT enemies=%d rooms=%d" % [enemies.size(), rooms.size()])
	_pack(enemies)
	for i in 15: await process_frame
	enemies = _living()
	L("PACKED enemies=%d on_screen=%d" % [enemies.size(), _on_screen(enemies)])

	# Warm with full render so captures/shaders compile.
	phase = "warm"
	recording = true
	last_usec = Time.get_ticks_usec()
	process_frame.connect(_on_frame)
	world.timing_begin()
	await _wait(warmup_sec)

	if freeze_world_render and display.world_viewport != null:
		display.world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		L("WORLD_RENDER frozen (UPDATE_DISABLED) — frame_ms ≈ CPU script+physics+root present")

	# Clear warm rows / section noise
	rows.clear()
	section_totals.clear()
	world.timing_rows.clear()
	phase = "crowd_cpu"
	last_usec = Time.get_ticks_usec()
	await _wait(sample_sec)

	recording = false
	process_frame.disconnect(_on_frame)
	var probe_summary: Dictionary = world.timing_finish()

	var ft: Array = []
	for r in rows:
		if r.phase == "crowd_cpu": ft.append(r.frame_ms)
	var sf := _stats(ft)
	L("CROWD_CPU frames=%d freeze=%s enemies=%d" % [sf.n, str(freeze_world_render), _living().size()])
	L("  frame_ms med=%.2f p95=%.2f p99=%.2f max=%.2f over16.7=%d" % [sf.med, sf.p95, sf.p99, sf.max, sf.over167])

	# Per-frame section sums from our draining
	var section_report: Dictionary = {}
	for key in section_totals.keys():
		section_report[key] = _stats(section_totals[key])
		var st: Dictionary = section_report[key]
		L("  section %-36s med=%.3f p95=%.3f max=%.3f n=%d" % [key, st.med, st.p95, st.max, st.n])

	# Probe call-level summary (may span warm+sample if not cleared — we cleared rows)
	L("PROBE_CALLS %s" % JSON.stringify(probe_summary))

	# Screenshot only if render not frozen for whole sample — take one with render on
	if freeze_world_render and display.world_viewport != null:
		display.world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img: img.save_png(OUT_DIR.path_join("%s_crowd.png" % tag)); L("SHOT %s" % OUT_DIR.path_join("%s_crowd.png" % tag))

	var out := {"tag": tag, "freeze_world_render": freeze_world_render, "frame": sf,
		"sections": section_report, "probe": probe_summary, "enemies": _living().size(),
		"adapter": RenderingServer.get_video_adapter_name()}
	var jf := FileAccess.open(OUT_DIR.path_join("%s_summary.json" % tag), FileAccess.WRITE)
	jf.store_string(JSON.stringify(out, "\t")); jf.close()
	L("DONE")
	quit(0)
