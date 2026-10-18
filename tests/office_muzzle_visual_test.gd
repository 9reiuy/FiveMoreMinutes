extends SceneTree

const EFFECT_SCENE := preload("res://scenes/entities/weapon_muzzle_effect.tscn")
const LIGHTING_SCRIPT := preload("res://scripts/dream/dream_night_lighting.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_effect_opt_in()
	_test_light_pool_world_origin()
	if failures.is_empty():
		print("OFFICE MUZZLE VISUAL TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_effect_opt_in() -> void:
	var effect := EFFECT_SCENE.instantiate() as Node2D
	root.add_child(effect)
	effect.call("setup", Vector2.RIGHT, &"assault_rifle", 0.055, Color.ORANGE, Color.YELLOW)
	_check(not bool(effect.get("office_3d_style")), "Legacy 2D flash must retain its original drawing style")
	_check(effect.scale == Vector2.ONE, "Legacy 2D flash keeps its original size")
	_check(is_equal_approx(float(effect.get("initial_lifetime")), 0.055), "Legacy duration must remain unchanged")
	effect.call("enable_office_3d_style")
	_check(bool(effect.get("office_3d_style")), "3D office must explicitly opt in to the new flash")
	_check(effect.scale == Vector2.ONE * 1.4, "3D flash enlarges around the same muzzle origin")
	var pistol := EFFECT_SCENE.instantiate() as Node2D
	root.add_child(pistol)
	pistol.call("setup", Vector2.RIGHT, &"pistol", 0.055, Color.ORANGE, Color.YELLOW)
	pistol.call("enable_office_3d_style")
	_check(pistol.scale == Vector2.ONE * 2.0, "Pistol core remains legible at game camera distance")
	_check(is_equal_approx(float(effect.get("initial_lifetime")), 0.18), "Office spark/smoke duration must reach 180 ms")
	var copy := EFFECT_SCENE.instantiate() as Node2D
	root.add_child(copy)
	effect.call("copy_depth_visual_state_to", copy)
	_check(bool(copy.get("office_3d_style")), "Depth capture copy must use the same 3D drawing path")
	_check(is_equal_approx(float(copy.get("initial_lifetime")), 0.18), "Depth copy must preserve effect timing")
	effect.queue_free()
	copy.queue_free()
	pistol.queue_free()


func _test_light_pool_world_origin() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.global_position = Vector3(3.0, 0.0, -2.0)
	var lighting := LIGHTING_SCRIPT.new() as Node3D
	parent.add_child(lighting)
	lighting.call("configure", null)
	var lights: Array = lighting.get("muzzle_lights")
	_check(lights.size() == 6, "Muzzle pool must remain at six lights")
	for entry in lights:
		_check(not (entry as OmniLight3D).shadow_enabled, "Muzzle lights must not cast expensive shadows")
	var muzzle_world := Vector3(7.2, 1.05, -4.4)
	lighting.call("flash_muzzle_world", muzzle_world, &"assault_rifle")
	var first := lights[0] as OmniLight3D
	_check(first.global_position.is_equal_approx(muzzle_world), "World-space flash must use the captured muzzle position exactly")
	_check(is_equal_approx(first.light_energy, 3.0), "assault_rifle must use rifle intensity instead of pistol fallback")
	lighting.call("_process", 0.09)
	_check(not first.visible, "Pulse must expire even without a player during floor transition")
	lighting.call("flash_muzzle", Vector2(32.0, 64.0), &"pistol")
	var second := lights[1] as OmniLight3D
	_check(second.global_position.is_equal_approx(parent.to_global(Vector3(1.0, 0.70, 2.0))), "Legacy 2D-coordinate entry point must preserve its mapping")
	parent.queue_free()
