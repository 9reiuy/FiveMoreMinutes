extends SceneTree
## Real production entry verify for the furniture Occlusion Cutout (v4).
## main.tscn -> main._show_dream("basic") -> SelectivePixelPreview/WorldViewport
## -> Dream3D_RandomDungeon, real game camera, real Player.  The Player is put
## BEHIND the tallest furniture; the world's own _update_occlusion_cutouts()
## computes the slot.  OFF/ON are captured from the same frozen frame state and
## camera (OFF = cutout slots zeroed).  Furniture is never hidden.
## Run (rendered display required):
##   DISPLAY=:7 godot --path . --position -2400,-2400 --resolution 1280x720 \
##     -s tests/cutout_real_v4.gd -- --prefix=real_v4 [--out=/abs/dir]
const MAIN_SCENE := "res://scenes/app/main.tscn"
var out_dir := "res://.runtime/cutout_sample"
var prefix := "real_v4"
var failures: Array[String] = []
var main: Node
var world: Node
var display: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prefix="): prefix = a.substr(9)
		if a.begins_with("--out="): out_dir = a.substr(6)
	if out_dir.begins_with("res://"): out_dir = ProjectSettings.globalize_path(out_dir)
	call_deferred("run")

func L(t: String) -> void:
	print("[CUT4] " + t)

func check(ok: bool, what: String) -> void:
	L(("PASS " if ok else "FAIL ") + what)
	if not ok: failures.append(what)

func cap() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func frames(n: int) -> void:
	for i in n: await process_frame

func root_aabb(r: Node3D) -> AABB:
	var have := false
	var box := AABB()
	for m in r.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		box = a if not have else box.merge(a)
		have = true
	return box if have else AABB()

func tallest_furniture() -> Node3D:
	var best: Node3D = null; var best_h := 0.0
	for n in world.find_children("*", "Node3D", true, false):
		if not (n.has_meta(&"occlusion_cutout_occluder") and bool(n.get_meta(&"occlusion_cutout_occluder")) and (n as Node3D).is_visible_in_tree()): continue
		var b := root_aabb(n)
		if b.size.y > best_h and b.size.x < 3.0 and b.size.z < 3.0:
			best_h = b.size.y; best = n
	return best

func mat_info(mat: Material) -> String:
	if mat == null: return "null"
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var code := sm.shader.code if sm.shader else ""
		var rm := ""
		var i := code.find("render_mode")
		if i >= 0: rm = code.substr(i, code.find(";", i) - i)
		var path := sm.shader.resource_path if sm.shader else ""
		return "%s [%s] cut_en=%s" % [path if path != "" else "<runtime copy>", rm, str(sm.get_shader_parameter("occlusion_cutout_enabled"))]
	return mat.get_class()

func place_behind(furn: Node3D) -> void:
	var cam: Camera3D = world.camera_3d
	var fwd := -cam.global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
	var b := root_aabb(furn)
	var c := b.get_center()
	var depth := absf(fwd.x) * b.size.x * 0.5 + absf(fwd.z) * b.size.z * 0.5
	var behind := Vector3(c.x, 0, c.z) + fwd * (depth + 0.30)
	var local: Vector3 = (world as Node3D).to_local(behind)
	world.player.global_position = Vector2(local.x, local.z) * world.CELL_PIXELS

## Measures the 3x3 core of the hole in the final window image.
func hole_px(slot: Vector4, img: Image) -> Vector3i:
	var cr: Rect2 = display.get("content_rect")
	var wv: SubViewport = display.get("world_viewport")
	var vis := root.get_visible_rect().size
	var sx := float(img.get_width()) / vis.x
	var sy := float(img.get_height()) / vis.y
	return Vector3i(int((cr.position.x + slot.x * cr.size.x) * sx), int((cr.position.y + slot.y * cr.size.y) * sy), int(slot.z * (cr.size.x / float(wv.size.x)) * sx))

func core_stats(img: Image, h: Vector3i) -> Vector2:
	var core := int(h.z * 0.2)
	var sum := 0.0; var n := 0; var blk := 0
	for y in range(h.y - core, h.y + core + 1):
		for x in range(h.x - core, h.x + core + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): continue
			var l := img.get_pixel(x, y).get_luminance()
			sum += l; n += 1
			if l < 0.03: blk += 1
	return Vector2(sum / maxf(n, 1), float(blk) / maxf(n, 1))

func core_diff(a: Image, b: Image, h: Vector3i) -> float:
	var core := int(h.z * 0.2); var d := 0.0; var n := 0
	for y in range(h.y - core, h.y + core + 1):
		for x in range(h.x - core, h.x + core + 1):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height(): continue
			var p := a.get_pixel(x, y); var q := b.get_pixel(x, y)
			d += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b); n += 1
	return d / maxf(n, 1)

## One OFF/ON capture of the current frozen state. Returns ON stats.
func off_on(tag: String, save: bool) -> Dictionary:
	var slots: Array = world._last_cutout_slots.duplicate()
	var s0: Vector4 = slots[0]
	check(s0.w > 0.5, "%s: game opened a Player cutout slot (slot0=%s)" % [tag, str(s0)])
	world.set_process(false)
	await frames(3)
	var on: Image = await cap()
	for i in 8: RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	await frames(3)
	var off: Image = await cap()
	for i in 8: RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, slots[i])
	await frames(3)
	var on2: Image = await cap()
	world.set_process(true)
	var h := hole_px(s0, on)
	var so := core_stats(off, h); var s1 := core_stats(on, h); var s2 := core_stats(on2, h)
	var d := core_diff(off, on, h)
	L("%s hole=(%d,%d) r=%d core luma/black OFF=%s ON=%s ON_restore=%s meanDiff=%.3f" % [tag, h.x, h.y, h.z, str(so), str(s1), str(s2), d])
	check(s1.y < 0.10, "%s: hole core is not clear-black (black_frac=%.3f)" % [tag, s1.y])
	check(d > 0.05, "%s: hole core differs from OFF (furniture really opened)" % tag)
	check(core_diff(on, on2, h) < 0.01, "%s: ON reproducible after OFF->ON restore" % tag)
	if save:
		off.save_png(out_dir.path_join(prefix + "_off.png"))
		on.save_png(out_dir.path_join(prefix + "_on.png"))
		var f := FileAccess.open(out_dir.path_join(prefix + "_hole.txt"), FileAccess.WRITE)
		f.store_line("%d %d %d" % [h.x, h.y, h.z]); f.close()
	return {"on": s1, "hole": h}

func freeze_actors() -> void:
	var player: Node2D = world.player
	player.set_physics_process(false)
	if player.get("auto_weapon") != null: player.auto_weapon.set_process(false)
	for e in get_nodes_in_group(&"dream_enemies"):
		e.set_process(false); e.set_physics_process(false)
		if e is Node2D: (e as Node2D).global_position += Vector2(100000, 100000)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioServer.set_bus_mute(0, true)
	main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state["tutorial_completed"] = true
	seed(120)
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world) and not main.transition_running:
			break
	world = main._supported_dream_world
	if not is_instance_valid(world):
		L("FAIL entry"); quit(1); return
	main._apply_palette_enabled(false)
	world.persist_profile = false
	while world.floor_transition_in_progress:
		await process_frame
	await frames(30)
	display = main.current_screen
	L("display=%s class_script=%s" % [str(display.get_path()), display.get_script().resource_path])
	check(display.get_node_or_null("OcclusionCutoutComposite") == null, "no full-screen composite overlay in display")
	check(world.find_child("CutoutBehindViewport", true, false) == null, "no behind-camera SubViewport")
	freeze_actors()
	# ---- 1. first display
	var furn := tallest_furniture()
	if furn == null: L("FAIL no furniture"); quit(1); return
	L("furniture=%s h=%.2f" % [str(furn.get_path()).get_file(), root_aabb(furn).size.y])
	place_behind(furn)
	await frames(90)
	for m in furn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		L("mesh %s layers=%d vis=%s override=%s overlay=%s" % [mi.name, mi.layers, str(mi.is_visible_in_tree()), mat_info(mi.material_override), mat_info(mi.material_overlay)])
		check(mi.is_visible_in_tree(), "furniture mesh %s stays visible" % mi.name)
		if mi.material_overlay is ShaderMaterial and (mi.material_overlay as ShaderMaterial).shader.resource_path.ends_with("furniture_pixel_outline.gdshader"):
			check((mi.material_overlay as ShaderMaterial).get_shader_parameter("occlusion_cutout_enabled") == true, "outline hull on %s is cutout-aware" % mi.name)
	await off_on("first", true)
	# ---- 2. reuse: walk out (slot closes) and back behind (slot reopens)
	world.player.global_position += Vector2(6, 4) * world.CELL_PIXELS
	await frames(40)
	var s_away: Vector4 = world._last_cutout_slots[0]
	check(s_away.w < 0.5, "reuse: slot closes when Player leaves (slot0=%s)" % str(s_away))
	place_behind(furn)
	await frames(60)
	await off_on("reuse", false)
	# ---- 3. pause / resume
	paused = true
	await frames(20)
	var pimg: Image = await cap()
	var ph: Vector3i = hole_px(world._last_cutout_slots[0], pimg)
	var ps := core_stats(pimg, ph)
	L("paused core=%s" % str(ps))
	check(ps.y < 0.10, "pause: hole stays open (not black) while paused")
	paused = false
	await frames(30)
	await off_on("resume", false)
	# ---- 4. new floor (world regenerate = scene content swap, new furniture/material instances)
	if world.has_method("regenerate"):
		world.regenerate(41001)
		await frames(120)
		while world.floor_transition_in_progress:
			await process_frame
		freeze_actors()
		var furn2 := tallest_furniture()
		if furn2 == null:
			check(false, "newfloor: furniture found")
		else:
			L("newfloor furniture=%s h=%.2f" % [str(furn2.get_path()).get_file(), root_aabb(furn2).size.y])
			place_behind(furn2)
			await frames(90)
			var r: Dictionary = await off_on("newfloor", false)
			var on_img: Image = await cap()
			on_img.save_png(out_dir.path_join(prefix + "_newfloor_on.png"))
	L("FAILURES=%d %s" % [failures.size(), str(failures)])
	L("DONE")
	quit(0 if failures.is_empty() else 2)
