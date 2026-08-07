extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const CRT := preload("res://scenes/ui/death_crt_effect.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")

var failures: Array[String] = []
var crt_finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_config_parameters()
	await _test_crt_effect_lifecycle()
	_test_sfx_event_registered()
	# Note: the death-flow integration assertion (player death spawns the CRT
	# overlay) lives in latest_requested_fixes_test.gd because dream_world.gd
	# depends on autoloads that only exist when running a scene.
	if failures.is_empty():
		print("CRT DEATH EFFECT TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_config_parameters() -> void:
	_assert(CONFIG.death_crt_effect_seconds > 0.0, "death_crt_effect_seconds is not configured")
	_assert(CONFIG.death_crt_effect_seconds <= 2.0, "death_crt_effect_seconds exceeds the 2.0s cap")
	_assert(ResourceLoader.exists("res://shaders/crt_shutdown.gdshader"), "crt_shutdown.gdshader is missing")


func _on_crt_finished() -> void:
	crt_finished = true


func _test_crt_effect_lifecycle() -> void:
	var crt = CRT.instantiate()
	root.add_child(crt)
	await process_frame
	_assert(crt.layer == 30, "CRT effect is not on the topmost layer")
	var overlay: ColorRect = crt.get_node_or_null("CrtOverlay")
	_assert(overlay != null, "CrtOverlay node is missing")
	if overlay != null:
		_assert(overlay.material is ShaderMaterial, "CrtOverlay has no ShaderMaterial")
		_assert(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "CrtOverlay blocks mouse input")
	_assert(is_equal_approx(crt.material.get_shader_parameter("progress"), 0.0), "CRT progress does not start at 0")
	crt_finished = false
	crt.finished.connect(_on_crt_finished)
	crt.play(0.2)
	await process_frame
	_assert(crt.active, "CRT effect did not become active after play()")
	await create_timer(0.3).timeout
	_assert(crt_finished, "CRT effect did not emit finished")
	# The final black frame must stay on screen until the scene switch frees it,
	# otherwise the dying game scene flashes back in between CRT and results.
	_assert(is_instance_valid(crt), "CRT effect freed itself before the scene switch")
	_assert(not crt.active, "CRT effect is still running after finishing")
	_assert(is_equal_approx(crt.material.get_shader_parameter("progress"), 1.0), "CRT progress did not stay at 1.0 (black frame)")
	crt.queue_free()
	await process_frame


func _test_sfx_event_registered() -> void:
	var manager := root.get_node_or_null("SFXManager")
	_assert(manager != null, "SFXManager autoload is missing")
	if manager != null:
		_assert(manager.players.has(&"crt_off"), "crt_off SFX event is not registered")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
