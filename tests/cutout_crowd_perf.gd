extends SceneTree
## Crowd cutout CPU timing. Spawns/packs enemies behind tall furniture so many
## are on-screen and occluded, then samples _update_occlusion_cutouts().
## DISPLAY=:7 godot --path . --position -2400,-2400 --resolution 1280x720 \
##   -s tests/cutout_crowd_perf.gd -- --out=/workspace/cutout-samples --tag=baseline
var out_dir := "/workspace/cutout-samples"
var tag := "baseline"
var samples := 90
var warmup := 20

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.substr(6)
		if a.begins_with("--tag="): tag = a.substr(6)
		if a.begins_with("--samples="): samples = int(a.substr(10))
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func L(t: String) -> void:
	print("[CROWD] " + t)
	var f := FileAccess.open(out_dir.path_join("cutout_perf_opt_%s.txt" % tag), FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(out_dir.path_join("cutout_perf_opt_%s.txt" % tag), FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(t)
	f.close()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func root_aabb(r: Node3D) -> AABB:
	var have := false
	var box := AABB()
	for m in r.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		box = a if not have else box.merge(a)
		have = true
	return box if have else AABB()

func tall_furniture_list(world: Node) -> Array:
	var list: Array = []
	for n in world.find_children("*", "Node3D", true, false):
		if not (n.has_meta(&"occlusion_cutout_occluder") and bool(n.get_meta(&"occlusion_cutout_occluder")) and (n as Node3D).is_visible_in_tree()):
			continue
		var b := root_aabb(n)
		if b.size.y >= 1.2 and b.size.x < 3.5 and b.size.z < 3.5:
			list.append({"node": n, "aabb": b, "h": b.size.y})
	list.sort_custom(func(a, b): return float(a.h) > float(b.h))
	return list

func pack_behind(world: Node, furn: Node3D, actors: Array) -> void:
	var cam: Camera3D = world.camera_3d
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var b := root_aabb(furn)
	var c := b.get_center()
	var depth := absf(fwd.x) * b.size.x * 0.5 + absf(fwd.z) * b.size.z * 0.5
	var base := Vector3(c.x, 0, c.z) + fwd * (depth + 0.35)
	var i := 0
	for actor_v in actors:
		var actor := actor_v as Node2D
		if actor == null or not is_instance_valid(actor):
			continue
		# Tight 3-wide pack so most bodies stay under one tall cabinet silhouette.
		var col := i % 3
		var row := int(i / 3)
		var offset := right * ((col - 1.0) * 0.28) + fwd * (row * 0.22)
		var behind := base + offset
		var local: Vector3 = (world as Node3D).to_local(behind)
		actor.global_position = Vector2(local.x, local.z) * world.CELL_PIXELS
		actor.set_physics_process(false)
		actor.set_process(false)
		i += 1

func median(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	return float(s[s.size() / 2])

func p95(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, floori(s.size() * 0.95))])

func count_occluded(world: Node, actors: Array) -> Dictionary:
	var on_screen := 0
	var occluded := 0
	var cam: Camera3D = world.camera_3d
	var vp := cam.get_viewport().get_visible_rect().grow(100.0)
	for actor_v in actors:
		var actor := actor_v as Node2D
		if actor == null or not is_instance_valid(actor):
			continue
		var cut: Dictionary = world._get_actor_cutout_slot(actor)
		if cut.is_empty():
			continue
		var w: Vector3 = cut.get("world", Vector3.ZERO)
		if cam.is_position_behind(w):
			continue
		var sp := cam.unproject_position(w)
		if not vp.has_point(sp):
			continue
		on_screen += 1
		if world._actor_is_occluded_by_occluder(w):
			occluded += 1
	return {"on_screen": on_screen, "occluded": occluded}

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	L("CROWD_START tag=%s" % tag)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if world.get("enable_game_start_cab_exit") != null:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(15)
	var ok: bool = bool(world.regenerate(41001))
	L("regenerate=%s" % str(ok))
	await frames(90)
	while bool(world.get("floor_transition_in_progress")):
		await process_frame

	var tall := tall_furniture_list(world)
	if tall.is_empty():
		L("FAIL no tall furniture")
		quit(1)
		return
	var furn: Node3D = tall[0]["node"]
	L("furniture=%s h=%.2f" % [str(furn.get_path()).get_file(), float(tall[0]["h"])])

	# Ensure we have enough enemies: keep existing, spawn extras near player room.
	var enemies: Array = []
	if world.enemy_root != null:
		for c in world.enemy_root.get_children():
			if c is EmployeeEnemy and is_instance_valid(c) and not bool(c.get("dead")):
				enemies.append(c)
	var need := 14 - enemies.size()
	var room_id := int(world.get("spawn_room_id"))
	var base_pos: Vector2 = world.player.global_position if world.player else Vector2.ZERO
	for i in need:
		var e = world._spawn_regular_employee(room_id, base_pos + Vector2(i * 40, 0), &"employee")
		if e != null:
			enemies.append(e)
	# Cap at 14 for the packed crowd.
	while enemies.size() > 14:
		enemies.pop_back()

	var actors: Array = []
	if world.player != null:
		actors.append(world.player)
	actors.append_array(enemies)
	pack_behind(world, furn, actors)
	await frames(30)
	# Force mesh cache warm
	world._update_occlusion_cutouts()
	await frames(5)

	var furn_meshes: Array = world._furniture_meshes()
	var bridges := 0
	if world.actor_depth_bridges_root != null:
		bridges = world.actor_depth_bridges_root.get_child_count()
	var occ := count_occluded(world, actors)
	L("CROWD_STATE enemies=%d on_screen=%d occluded=%d furn_meshes=%d bridges=%d" % [
		enemies.size(), int(occ.on_screen), int(occ.occluded), furn_meshes.size(), bridges
	])

	# A/B: legacy full furniture scan vs optimized near+cache path, same pack.
	world.set_meta(&"test_legacy_furniture_screen_scan", true)
	world._cutout_furniture_meshes_dirty = true
	var legacy_ms: Array = []
	for i in warmup + samples:
		var t0 := Time.get_ticks_usec()
		world._update_occlusion_cutouts()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if i >= warmup:
			legacy_ms.append(ms)
	L("CROWD_PERF_LEGACY cutout_ms med=%.3f p95=%.3f max=%.3f n=%d" % [
		median(legacy_ms), p95(legacy_ms), legacy_ms.max() if not legacy_ms.is_empty() else 0.0, legacy_ms.size()
	])
	world.set_meta(&"test_legacy_furniture_screen_scan", false)
	world._cutout_furniture_screen_rects.clear()
	var cutout_ms: Array = []
	for i in warmup + samples:
		var t0 := Time.get_ticks_usec()
		world._update_occlusion_cutouts()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if i >= warmup:
			cutout_ms.append(ms)
	L("CROWD_PERF_OPT cutout_ms med=%.3f p95=%.3f max=%.3f n=%d speedup=%.2fx" % [
		median(cutout_ms), p95(cutout_ms), cutout_ms.max() if not cutout_ms.is_empty() else 0.0, cutout_ms.size(),
		(median(legacy_ms) / maxf(median(cutout_ms), 0.0001))
	])
	L("CROWD_PERF cutout_ms med=%.3f p95=%.3f max=%.3f n=%d" % [
		median(cutout_ms), p95(cutout_ms), cutout_ms.max() if not cutout_ms.is_empty() else 0.0, cutout_ms.size()
	])

	# Off-map control: move enemies far away
	for e in enemies:
		if is_instance_valid(e):
			(e as Node2D).global_position += Vector2(200000, 200000)
	await frames(5)
	var off_ms: Array = []
	for i in 40:
		var t0 := Time.get_ticks_usec()
		world._update_occlusion_cutouts()
		off_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	L("CROWD_PERF_ENEMIES_OFFMAP cutout_ms med=%.3f p95=%.3f (delta_vs_crowd=%.3f)" % [
		median(off_ms), p95(off_ms), median(cutout_ms) - median(off_ms)
	])

	# Capture one still for visual sanity (crowd packed behind cabinet).
	world.set_process(true)
	await frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join("cutout_perf_opt_%s.png" % tag))
	L("CROWD_DONE saved=%s" % out_dir.path_join("cutout_perf_opt_%s.png" % tag))
	quit(0)
