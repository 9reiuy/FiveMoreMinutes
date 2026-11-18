extends "res://tests/h06_forklift_route_flash_probe.gd"
## Private interactive comparison. Production materials and game entry are unchanged.

const STABILITY := preload("res://scripts/dream/preview/pixel_camera_stability.gd")
var comparison_mode := 0
var comparison_label: Label
var anchor := Vector3.ZERO
var comparison_trace: Array[Dictionary] = []
var initial_comparison_mode := 0
var comparison_caption := "1-2 闪点对照 — F6 切换 — 独立静音测试"

class CompareInput extends Node:
	var probe: SceneTree
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F6:
			probe.next_comparison()
			get_viewport().set_input_as_handled()
	func _process(_delta: float) -> void:
		probe.align_comparison_camera()


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("FLICKER_COMPARISON_PID ", OS.get_process_id())
	call_deferred("run")


func trace_case(label: String, count: int, fire := false, pointer_pan := false) -> void:
	# Keep the complete game route, without diagnostic frame-readback stalls.
	for i in count:
		if fire and i % 22 == 0: shoot(true)
		if fire and i % 22 == 3: shoot(false)
		await physics_frame
	shoot(false)
	if label != "after_shooting_pan": return
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	for projectile in get_nodes_in_group(&"dream_projectiles"): projectile.queue_free()
	world.player.invulnerability_left = 100000.0
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	await frames(90)
	var p: Vector2 = world._player_ground_anchor_position() / 32.0
	anchor = world.to_global(Vector3(p.x, world._floor_height_at(p), p.y))
	var hud := CanvasLayer.new()
	hud.layer = 245
	root.add_child(hud)
	comparison_label = Label.new()
	comparison_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comparison_label.add_theme_font_override(&"font", preload("res://scripts/ui/crisp_interaction_font.gd").get_font())
	comparison_label.add_theme_font_size_override(&"font_size", 15)
	comparison_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	comparison_label.add_theme_constant_override(&"outline_size", 5)
	comparison_label.position = Vector2(18, 38)
	hud.add_child(comparison_label)
	var input := CompareInput.new()
	input.probe = self
	input.process_priority = 150
	root.add_child(input)
	for mode in [0, 1, 2, initial_comparison_mode]:
		comparison_mode = mode
		apply_comparison()
		await frames(10)
		check(check_comparison_mode(mode), "comparison mode %d selects the actual WorldViewport" % mode)
		await capture("comparison-mode-%d" % mode)
	await prepare_comparison()
	verify_audio()
	FileAccess.open(evidence.path_join("ready.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"pid": OS.get_process_id(), "checks": checks, "failures": failures,
		"normal_route_completed": true, "scope": "Interactive visual comparison only; no production renderer or materials changed."}, "\t"))
	if OS.get_environment("FLICKER_CHECK_AUTO") == "1":
		current_scene.queue_free()
		await frames(6)
		verify_audio()
		print("FLICKER_COMPARISON_AUTO checks=", checks.size(), " failures=", failures.size())
		quit(0 if failures.is_empty() else 1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(160, 100))
	DisplayServer.window_set_title(comparison_caption)
	print("FLICKER_COMPARISON_READY checks=", checks.size(), " failures=", failures.size())
	while true: await process_frame


func prepare_comparison() -> void:
	pass


func next_comparison() -> void:
	comparison_mode = (comparison_mode + 1) % 3
	apply_comparison()


func check_comparison_mode(mode: int) -> bool:
	return world.get_viewport().use_taa == (mode == 1)


func apply_comparison() -> void:
	world.get_viewport().use_taa = comparison_mode == 1
	world.camera_3d.h_offset = 0.0
	world.camera_3d.v_offset = 0.0
	var title: String = ["A 原画面", "B 时间抗锯齿", "C 像素对齐"][comparison_mode]
	comparison_label.text = "F6 切换对照　·　" + title + "　·　请左右移动视角"
	comparison_trace.append({"mode": comparison_mode, "time_usec": Time.get_ticks_usec()})
	FileAccess.open(evidence.path_join("switches.json"), FileAccess.WRITE).store_string(JSON.stringify(comparison_trace, "\t"))


func align_comparison_camera() -> void:
	if comparison_mode != 2 or not is_instance_valid(world): return
	STABILITY.apply(world.camera_3d, anchor)
	var feet: Vector2 = world._player_ground_anchor_position()
	var p := feet / 32.0
	var ground: Vector3 = world.to_global(Vector3(p.x, world._floor_height_at(p), p.y))
	world.gameplay_canvas.transform.origin = world.camera_3d.unproject_position(ground) - feet
