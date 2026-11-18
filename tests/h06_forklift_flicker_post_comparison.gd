extends "res://tests/h06_forklift_flicker_comparison.gd"
## A/B exclusions after 3D rendering; reload a small allowlisted case file without replaying.
var diagnostic_case := "no_post"
var diagnostic_title := "关闭屏幕效果"
var config_text := ""
var config_check_usec := 0


func next_comparison() -> void:
	comparison_mode = 1 - mini(comparison_mode, 1)
	apply_comparison()


func check_comparison_mode(mode: int) -> bool:
	var semantic: CanvasLayer = current_scene.presentation.world_viewport.get_node("WorldSemanticLayer")
	return semantic.visible == (mode == 0) if diagnostic_case == "no_post" else true


func apply_comparison() -> void:
	world.get_viewport().use_taa = false
	world.get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	world.camera_3d.h_offset = 0.0
	world.camera_3d.v_offset = 0.0
	var active := comparison_mode != 0
	var no_post := active and diagnostic_case in ["no_post", "unshaded"]
	var semantic: CanvasLayer = current_scene.presentation.world_viewport.get_node("WorldSemanticLayer")
	semantic.visible = not no_post
	var finish: Node = world.get_node_or_null("WorldCameraFinish")
	if finish != null: finish.set_enabled(not no_post)
	if world.player.has_meta(&"stylized_player_hurt"):
		var hurt: Node = world.player.get_meta(&"stylized_player_hurt").get_ref()
		if is_instance_valid(hurt):
			hurt.clear()
			hurt.set_process(not no_post)
	if diagnostic_case == "unshaded" and active:
		world.get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var no_fx := active and diagnostic_case == "no_vfx"
	for host: Node in [world.floor_root, world]:
		for path: String in ["FirearmFlashFX", "MuzzleSmoke", "BurningEffects"]:
			var effect: Node = host.get_node_or_null(path)
			if effect is Node3D: effect.visible = not no_fx
	lift.visual.visible = not (active and diagnostic_case == "no_vehicle") and not lift.destroyed
	var optics: Node = world.get_node_or_null("OfficeLightOptics")
	if optics != null: optics.enabled = not (active and diagnostic_case == "no_optics")
	comparison_label.text = "F6 切换对照　·　" + ("B " + diagnostic_title if active else "A 原画面") + "　·　请左右移动视角"
	comparison_trace.append({"mode": comparison_mode, "case": diagnostic_case, "time_usec": Time.get_ticks_usec()})
	FileAccess.open(evidence.path_join("switches.json"), FileAccess.WRITE).store_string(JSON.stringify(comparison_trace, "\t"))


func align_comparison_camera() -> void:
	var now := Time.get_ticks_usec()
	if now - config_check_usec < 250000: return
	config_check_usec = now
	var path := evidence.path_join("diagnostic_case.json")
	if not FileAccess.file_exists(path): return
	var value := FileAccess.get_file_as_string(path)
	if value == config_text: return
	var config: Variant = JSON.parse_string(value)
	if not config is Dictionary or config.get("case", "") not in ["no_post", "no_vfx", "no_optics", "no_vehicle", "unshaded"]: return
	config_text = value
	diagnostic_case = config["case"]
	diagnostic_title = config.get("title", diagnostic_case)
	comparison_mode = 0
	apply_comparison()
