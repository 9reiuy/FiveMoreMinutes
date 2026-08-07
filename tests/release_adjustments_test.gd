extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const WAVE := preload("res://scenes/entities/sword_wave.tscn")
const ENEMY := preload("res://scenes/entities/basic_enemy.tscn")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")

var failures: Array[String] = []


class DummyTarget extends Node2D:
	var dead := false
	var damage_received := 0.0
	func receive_damage(amount: float) -> void:
		damage_received += amount
	func take_damage(amount: float, _origin: Vector2 = Vector2.INF) -> void:
		damage_received += amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ram_and_config()
	await _test_wave_and_enemy_feedback()
	await _test_phone_and_documentation()
	if failures.is_empty():
		print("RELEASE ADJUSTMENTS TEST PASSED: RAM -> silent enemy hit -> accelerated katana -> spawn tuning -> phone shell -> docs")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ram_and_config() -> void:
	_assert(RunSettlement.calculate_run_ram(1) == 0, "Level 1 must settle 0 RAM")
	_assert(RunSettlement.calculate_run_ram(5) == 4, "Level 5 must settle 4 RAM")
	var meta := {"balance":0, "ram":0, "unemployed":false}
	var result := RunSettlement.settle({"level":5, "wake_minutes":420.0, "is_sunday":false}, meta, CONFIG)
	RunSettlement.settle(result, meta, CONFIG)
	_assert(meta.ram == 4, "Run settlement was duplicated or still uses experience")
	_assert(CONFIG.enemy_spawn_count_per_interval == 2 and CONFIG.maximum_enemies == 110, "Spawn batch or cap is not doubled")
	_assert(CONFIG.correction_unlock_seconds == 30.0 and CONFIG.stapler_unlock_seconds == 90.0 and CONFIG.large_correction_unlock_seconds == 180.0, "Special enemy unlock times are incorrect")
	_assert(CONFIG.katana_wave_width == 32.0 and CONFIG.katana_wave_max_distance == 300.0, "Katana width or unchanged distance is incorrect")
	_assert(CONFIG.katana_wave_acceleration_curve != null and CONFIG.katana_wave_acceleration_curve.sample_baked(0.5) < 0.5, "Katana curve is not Ease-In")


func _test_wave_and_enemy_feedback() -> void:
	var wave := WAVE.instantiate()
	root.add_child(wave)
	wave.set_process(false)
	wave.global_position = Vector2(320, 180)
	wave.setup(Vector2.RIGHT, 10.0, 450.0, 300.0, 32.0, 0.35, 0.25, CONFIG.katana_wave_acceleration_curve)
	var shape := wave.get_node("HitArea/CollisionShape2D").shape as RectangleShape2D
	_assert(shape != null and shape.size.y == 32.0, "Wave collision width does not match visual width")
	var enemy_a := DummyTarget.new()
	var enemy_b := DummyTarget.new()
	enemy_a.position = Vector2(335, 180)
	enemy_b.position = Vector2(342, 190)
	enemy_a.add_to_group("dream_enemies")
	enemy_b.add_to_group("dream_enemies")
	root.add_child(enemy_a)
	root.add_child(enemy_b)
	var start: Vector2 = wave.global_position
	wave._process(0.125)
	var first_step: float = wave.global_position.distance_to(start)
	wave._process(0.125)
	var second_step: float = float(wave.traveled) - first_step
	_assert(first_step < second_step and is_equal_approx(wave.global_position.y, 180.0), "Wave does not accelerate on a straight line")
	_assert(enemy_a.damage_received == 10.0 and enemy_b.damage_received == 10.0, "Wave damage or penetration changed")
	wave._process(0.1)
	_assert(is_equal_approx(wave.traveled - first_step - second_step, 45.0), "Wave final speed is not 450 px/s")
	while wave.traveled < wave.max_distance:
		wave._process(0.1)
	_assert(wave.traveled <= 300.0 and CONFIG.katana_melee_radius == 50.0, "Wave exceeded 300 px or melee radius changed")
	wave.queue_free()
	enemy_a.queue_free()
	enemy_b.queue_free()
	var target := DummyTarget.new()
	root.add_child(target)
	var enemy := ENEMY.instantiate()
	enemy.configure(target, 99.0, 0.0, Rect2(0, 0, 640, 360), 0.0, 0.0, CONFIG)
	root.add_child(enemy)
	await process_frame
	enemy.take_damage(1.0)
	var audio_children := 0
	for child in enemy.get_children():
		if child is AudioStreamPlayer:
			audio_children += 1
	_assert(audio_children == 0 and enemy.hit_flash_left > 0.0 and enemy.hit_scale_left > 0.0, "Enemy hit audio remains or visual feedback was removed")
	enemy.queue_free()
	target.queue_free()
	await process_frame


func _test_phone_and_documentation() -> void:
	var phone := PHONE.instantiate()
	phone.persistent_state = {"balance":0, "ram":0, "weekday_index":0, "permanent_upgrades":{}, "online_messages":[]}
	root.add_child(phone)
	await process_frame
	var shell := phone.get_node("PhoneShell") as TextureRect
	_assert(shell.texture.resource_path == "res://art/Badroom/Phone.png" and phone.size == Vector2(160, 336), "Phone.png is not bound at its original aspect")
	_assert(shell.mouse_filter == Control.MOUSE_FILTER_IGNORE and phone._app_rect(0).position.y >= phone.config.phone_upper_collapse_height, "Phone shell blocks input or app grid overlaps collapse area")
	phone.state = phone.PhoneState.EXPANDED
	phone.screen_state = phone.ScreenState.HOME
	phone._open_app("online")
	_assert(phone.screen_state == phone.ScreenState.ONLINE, "Existing phone app navigation changed")
	phone.force_collapse()
	_assert(phone.state == phone.PhoneState.COLLAPSED and phone.position.y == CONFIG.phone_collapsed_y, "Phone collapse behavior changed")
	var document := FileAccess.get_file_as_string("res://docs/GAMEPLAY_PARAMETERS.md")
	_assert(document.contains("`katana_wave_width` | 32") and document.contains("`enemy_spawn_count_per_interval` | 2") and document.contains("最终等级-1"), "Gameplay parameter document defaults do not match config")
	phone.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
