extends "res://tests/h06_forklift_flicker_model_comparison.gd"
const SHADOW := preload("res://tests/support/forklift_shadow_candidate.gd")
var shadow_proxy: SHADOW


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	diagnostic_case = "stable_hull"
	diagnostic_title = "稳定投影"
	print("STABLE_SHADOW_COMPARISON_PID ", OS.get_process_id())
	call_deferred("run")


func apply_comparison() -> void:
	if not is_instance_valid(shadow_proxy):
		shadow_proxy = SHADOW.new()
		lift.visual.add_child(shadow_proxy)
		shadow_proxy.configure(lift.visual, lift.visual.MODEL_SCALE, lift.visual.CANOPY_RAISE)
	world.get_viewport().use_taa = false
	world.get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	shadow_proxy.set_mode((1 if diagnostic_case == "stable_full" else 2) if comparison_mode != 0 else 0)
	comparison_label.text = "F6 切换对照　·　" + ("B " + diagnostic_title if comparison_mode != 0 else "A 原投影") + "　·　请左右移动视角"
	comparison_trace.append({"mode": comparison_mode, "case": diagnostic_case, "time_usec": Time.get_ticks_usec()})
	FileAccess.open(evidence.path_join("switches.json"), FileAccess.WRITE).store_string(JSON.stringify(comparison_trace, "\t"))


func check_comparison_mode(mode: int) -> bool:
	return shadow_proxy.mode == (2 if mode != 0 else 0) and lift.visual.visible


func align_comparison_camera() -> void:
	var now := Time.get_ticks_usec()
	if now - config_check_usec < 250000: return
	config_check_usec = now
	var path := evidence.path_join("diagnostic_case.json")
	if not FileAccess.file_exists(path): return
	var value := FileAccess.get_file_as_string(path)
	if value == config_text: return
	var config: Variant = JSON.parse_string(value)
	if not config is Dictionary or config.get("case", "") not in ["stable_hull", "stable_full"]: return
	config_text = value
	diagnostic_case = config["case"]
	diagnostic_title = config.get("title", diagnostic_case)
	comparison_mode = 0
	apply_comparison()
