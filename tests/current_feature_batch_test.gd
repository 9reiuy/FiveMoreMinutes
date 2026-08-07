extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const MENU := preload("res://scenes/ui/main_menu.tscn")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const UPGRADE_PANEL := preload("res://scenes/ui/upgrade_panel.tscn")
const OPENING := preload("res://scenes/ui/opening.tscn")

var failures: Array[String] = []


class WorldProbe extends Node:
	var projectiles: Array[Node] = []
	var effects: Array[Node] = []
	func add_projectile(projectile: Node2D) -> void:
		projectiles.append(projectile)
		add_child(projectile)
	func add_weapon_effect(effect: Node2D) -> void:
		effects.append(effect)
		add_child(effect)


func _initialize() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "confirm", "restart_demo", "dash", "skill_menu"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_configuration()
	await _test_bedroom_outline_and_menu_stability()
	await _test_weapons_and_drops()
	await _test_upgrade_refresh()
	await _test_normal_life_ending()
	if failures.is_empty():
		print("CURRENT FEATURE BATCH TEST PASSED: outline -> stable menu -> four weapons -> drops -> refresh -> ending")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_configuration() -> void:
	_assert(is_equal_approx(CONFIG.basic_weapon_attack_interval, 0.3), "Pistol interval is not 0.3 seconds")
	_assert(CONFIG.shotgun_pellet_count == 9 and is_equal_approx(CONFIG.shotgun_pellet_damage, 3.0), "Shotgun defaults are incorrect")
	_assert(is_equal_approx(CONFIG.katana_melee_damage, 30.0) and is_equal_approx(CONFIG.katana_wave_damage, 10.0), "Katana defaults are incorrect")
	_assert(CONFIG.correction_experience_drop_count == 2 and CONFIG.stapler_experience_drop_count == 3, "Drop counts are not configured")
	_assert(CONFIG.upgrade_refreshes_per_level == 1 and CONFIG.normal_life_ending_required_workdays == 14, "Refresh or ending threshold is incorrect")


func _test_bedroom_outline_and_menu_stability() -> void:
	var bedroom := BEDROOM.instantiate()
	bedroom.persistent_state = {"balance": 1325, "ram": 0, "melatonin_inventory": 1, "melatonin_bottle_present": true, "permanent_upgrades": {}, "online_messages": []}
	root.add_child(bedroom)
	await process_frame
	_assert(bedroom.bed_sprite.material != bedroom.bottle_sprite.material, "Bed and bottle still share one outline material")
	_assert(bedroom.bed_click_area.input_pickable and bedroom.bottle_click_area.input_pickable, "Bedroom hover areas are not input-pickable")
	bedroom._set_highlighted("bed")
	_assert(float(bedroom.bed_outline_material.get_shader_parameter("outline_enabled")) == 1.0, "Bed outline was not enabled")
	bedroom._set_highlighted("bottle")
	_assert(float(bedroom.bottle_outline_material.get_shader_parameter("outline_enabled")) == 1.0 and float(bedroom.bed_outline_material.get_shader_parameter("outline_enabled")) == 0.0, "Bottle outline state overlaps the bed")
	bedroom.queue_free()
	await process_frame
	var menu := MENU.instantiate()
	root.add_child(menu)
	await process_frame
	menu._show_confirmation("new_game")
	await process_frame
	var primary_before: Vector2 = menu.primary_button.position
	var back_before: Vector2 = menu.back_button.position
	menu.primary_button.mouse_entered.emit()
	menu.back_button.mouse_entered.emit()
	await process_frame
	_assert(menu.primary_button.position == primary_before and menu.back_button.position == back_before, "Confirmation buttons move on hover")
	menu.queue_free()
	await process_frame


func _test_weapons_and_drops() -> void:
	var probe := WorldProbe.new()
	probe.add_to_group("dream_world")
	root.add_child(probe)
	var player := PLAYER.instantiate()
	probe.add_child(player)
	await process_frame
	player.global_position = Vector2(320, 180)
	player.configure_weapon("shotgun", CONFIG, {})
	player.set_attacking_enabled(false)
	player.shotgun_weapon._fire_full_volley(Vector2.RIGHT, false)
	_assert(probe.projectiles.size() == 9, "Shotgun did not create exactly 9 independently moving pellets")
	player.configure_weapon("katana", CONFIG, {})
	player.set_attacking_enabled(false)
	var projectile_before := probe.projectiles.size()
	player.katana_weapon._fire_full_attack(Vector2.RIGHT, false)
	_assert(probe.projectiles.size() == projectile_before + 1 and probe.effects.size() == 1, "Katana did not create one slash and one wave together")
	probe.queue_free()
	await process_frame
	var dream := DREAM.instantiate()
	root.add_child(dream)
	await process_frame
	dream.spawner.running = false
	dream.player.set_attacking_enabled(false)
	dream._on_enemy_defeated(Vector2(200, 150), CONFIG.correction_experience_drop_count)
	dream._on_enemy_defeated(Vector2(240, 150), CONFIG.stapler_experience_drop_count)
	_assert(dream.pickup_container.get_child_count() == 5, "Correction and stapler did not create 2 + 3 experience gems")
	for gem in dream.pickup_container.get_children():
		_assert(int(gem.value) == 1, "An experience gem is not worth exactly 1 base experience")
	dream.queue_free()
	await process_frame


func _test_upgrade_refresh() -> void:
	var panel := UPGRADE_PANEL.instantiate()
	root.add_child(panel)
	await process_frame
	var refresh_counter := [0]
	panel.refresh_requested.connect(func(): refresh_counter[0] += 1)
	var options: Array[Dictionary] = [
		{"id":"a", "family":"a", "name":"A", "description":"A", "rarity":"blue"},
		{"id":"b", "family":"b", "name":"B", "description":"B", "rarity":"purple"},
		{"id":"c", "family":"c", "name":"C", "description":"C", "rarity":"gold"}
	]
	panel.open(2, options, 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(320, 327)
	panel._gui_input(click)
	panel._gui_input(click)
	_assert(refresh_counter[0] == 1 and panel.refreshes_remaining == 0 and panel.visible, "Upgrade refresh is not one-use or closes the panel")
	panel.queue_free()
	await process_frame


func _test_normal_life_ending() -> void:
	var meta := {"balance": 1000, "ram": 0, "unemployed": false, "normal_attendance_workday_streak": 13, "normal_life_ending_unlocked": false}
	var summary := {"wake_minutes": 420.0, "total_experience": 100, "level": 2, "is_sunday": false}
	var result := RunSettlement.settle(summary, meta, CONFIG)
	_assert(meta.normal_attendance_workday_streak == 14 and meta.normal_life_ending_unlocked, "The fourteenth on-time workday did not unlock the ending")
	_assert(result.normal_life_ending_triggered and result.wage == 500 and result.run_ram == 1, "Ending trigger skipped the final wage or RAM settlement")
	RunSettlement.settle(result, meta, CONFIG)
	_assert(meta.balance == 1500 and meta.ram == 1 and meta.normal_attendance_workday_streak == 14, "Settling the ending twice changed persistent values")
	var sunday_meta := {"balance": 0, "ram": 0, "unemployed": false, "normal_attendance_workday_streak": 8, "normal_life_ending_unlocked": false}
	var sunday := RunSettlement.settle({"wake_minutes": 700.0, "total_experience": 0, "is_sunday": true}, sunday_meta, CONFIG)
	_assert(sunday_meta.normal_attendance_workday_streak == 8 and sunday.wage == 0 and not sunday.normal_life_ending_triggered, "Sunday changed the streak, paid wages, or triggered the ending")
	var late_meta := {"balance": 0, "ram": 0, "unemployed": false, "normal_attendance_workday_streak": 5, "normal_life_ending_unlocked": false}
	RunSettlement.settle({"wake_minutes": 480.0, "total_experience": 0, "is_sunday": false}, late_meta, CONFIG)
	_assert(late_meta.normal_attendance_workday_streak == 0, "Late attendance did not reset the streak")
	var ending := OPENING.instantiate()
	ending.ending_mode = true
	root.add_child(ending)
	await process_frame
	_assert(ending.paragraphs == ["你的生活还在继续，但这一切如你愿吗？"], "Normal-life ending does not reuse the requested typewriter text")
	ending.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
