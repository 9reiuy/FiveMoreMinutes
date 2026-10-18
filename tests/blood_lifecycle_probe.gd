extends SceneTree

## Blood Bridge 生命周期探针（Phase 3A-1 验收，诊断用后删）：
## settle → 桥冻结停帧；append_wall_impact → 唤醒单次捕获 → 重新冻结；
## 捕获内容随新增冲击变化（血迹永久累积仍可见）。

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CONFIG := preload("res://resources/demo_config.tres")


func _init() -> void:
	call_deferred("_run")


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world: Node3D = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	world.regenerate(41004)
	var player: Node2D = world.player
	player.set_physics_process(false)
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0
	player.global_position = anchor
	for i in range(4):
		world.spawn_black_blood(anchor + Vector2(float(i) * 5.0, -10.0))
	await frames(10)

	var stain: Node = null
	for child in world.world_effects_root.get_children():
		if child.is_in_group(&"black_blood_stains"):
			stain = child
			break
	if stain == null:
		print("LIFE no stain")
		quit(1)
		return
	# 显式等待 settle（settle_seconds=0.38s；帧率相关，不能数帧）。
	var settle_wait := 0
	while not bool(stain.get("settled")) and settle_wait < 900:
		await process_frame
		settle_wait += 1
		if settle_wait % 120 == 0:
			print("LIFE wait t=%d settled=%s elapsed=%.2f is_processing=%s process_mode=%d can_process=%s" % [
				settle_wait, stain.get("settled"), float(stain.get("elapsed")),
				stain.is_processing(), int(stain.process_mode), stain.can_process()])
	print("LIFE target stain id=", stain.get_instance_id(), " settled=", stain.get("settled"),
		" elapsed=", float(stain.get("elapsed")), " processing=", stain.is_processing())
	check(bool(stain.get("settled")), "blood stain settles")
	await frames(6)   # 桥冻结排程 + 单次捕获
	var reference: Variant = stain.get_meta("depth_visual_bridge")
	var bridge: Node3D = reference.get_ref()
	print("LIFE settle: frozen=%s transform_only=%s processing=%s version=%d" % [
		bridge.get("static_visual_frozen"), bridge.get("transform_only"),
		bridge.is_processing(), int(stain.call("get_capture_content_version"))])
	check(bridge.get("static_visual_frozen") == true and bridge.is_processing() == false,
		"settled blood bridge is frozen and not processing")

	var viewport: SubViewport = bridge.get("render_viewport")
	var before := viewport.get_texture().get_image()

	# 冻结后追加冲击（模拟 wall/floor 后续血滴）：应唤醒→捕获→重新冻结。
	print("LIFE pre-append settled=", stain.get("settled"), " ground_px=",
		(stain.get("ground_pixels") as Array).size(), " frozen=", bridge.get("static_visual_frozen"))
	var px_before: int = (stain.get("ground_pixels") as Array).size()
	for i in range(3):
		stain.call("append_wall_impact", stain.get("global_position") + Vector2(6, 6), Vector2.UP, 120.0, null)
	print("LIFE post-append settled=", stain.get("settled"), " ground_px=",
		(stain.get("ground_pixels") as Array).size(), " (before ", px_before, ") bridge_processing=",
		bridge.is_processing(), " frozen=", bridge.get("static_visual_frozen"))
	await frames(8)
	print("LIFE after_append: frozen=%s processing=%s version=%d" % [
		bridge.get("static_visual_frozen"), bridge.is_processing(),
		int(stain.call("get_capture_content_version"))])
	check(bridge.get("static_visual_frozen") == true and bridge.is_processing() == false,
		"bridge re-frozen after wake capture")
	check(int(stain.call("get_capture_content_version")) >= 2,
		"capture content version advanced on append")
	var after := viewport.get_texture().get_image()
	var changed := false
	for y in range(after.get_height()):
		for x in range(after.get_width()):
			var ca := before.get_pixel(x, y)
			var cb := after.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02:
				changed = true
				break
	check(changed, "capture content updated after append (new impacts visible)")

	# 血色回归：capture 仍为 #D96B18 系
	var dom := Color.BLACK
	var spread := -1.0
	for y in range(after.get_height()):
		for x in range(after.get_width()):
			var c := after.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var sp := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if sp > spread:
				spread = sp
				dom = c
	check(absf(dom.r - 0.851) < 0.03 and absf(dom.g - 0.420) < 0.03,
		"capture color stays #D96B18 family (%.3f,%.3f,%.3f)" % [dom.r, dom.g, dom.b])
	print("LIFE PROBE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)


var failures := 0
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", label)
