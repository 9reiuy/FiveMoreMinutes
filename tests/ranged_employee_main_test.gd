extends "res://tests/ranged_enemy_lab_test.gd"
## Exercise the same encounters through Main's checkpoint and campaign routes.

const CHAPTER := preload("res://scripts/testing/h06_chapter/chapter_world.gd")
const WAREHOUSE_LANE := Vector2(-19.2, -29.7) * 32.0

var main: Node

func wait_for_floor(scene: PackedScene) -> bool:
	var deadline := Time.get_ticks_msec() + 110000
	while main.transition_running and Time.get_ticks_msec() < deadline:
		await process_frame
	world = main._supported_dream_world
	var correct := is_instance_valid(world) and world.scene_file_path == scene.resource_path
	if correct:
		while world.floor_transition_in_progress and Time.get_ticks_msec() < deadline:
			await process_frame
		correct = not main.transition_running and not world.floor_transition_in_progress and world.campaign_run
	check(correct, "Main opened " + scene.resource_path)
	if not correct:
		print("RANGED_ENTRY_FAILED ", main.get_meta(&"last_elevator_preparation_failure", {}))
	return correct

func check_dispatch() -> void:
	gunner.equip_weapon("assault_rifle")
	gunner.hostile = true
	gunner.state = EmployeeEnemy.State.ATTACK_PLAYER
	gunner.reaction_left = 0.0
	gunner.pickup_pause_left = 0.0
	gunner.can_see_target = false
	gunner.searching = false
	gunner.turning = false
	gunner.weapon_root.rotation = PI
	gunner.perception_update_left = 0.0
	gunner.attack_cooldown_left = 0.0
	move_player(Vector2(85, 0))
	gunner._remember_target_position(world.player.global_position, 0)
	gunner._update_target_perception_clock(DT)
	check(gunner.searching and not gunner.short_warning, "dispatch starts a search before visual contact")
	check(until_aim(140) > 0 and is_equal_approx(gunner.ranged_warning_seconds, 0.70), "first sight after a dispatch gets the full warning")

func chapter_guard() -> void:
	var regulars := 0
	var specialists := 0
	for squad: Array in world.warehouse_squads.values():
		for unit: EmployeeEnemy in squad:
			if unit.get_meta(&"enemy_type") == &"employee":
				regulars += 1
				check(unit is SAMPLE, "authored regular uses production gunner")
			else:
				specialists += 1
				check(not unit is SAMPLE, "authored specialist retains its own behaviour")
	for guard: EmployeeEnemy in world.warehouse_squads.get("guard", []):
		if guard is SAMPLE and guard.held_weapon_id == "basic":
			gunner = guard
	check(regulars > 0 and specialists > 0 and is_instance_valid(gunner), "checkpoint restores mixed warehouse guards and their authored weapons")
	if not is_instance_valid(gunner): return
	world._place_feet(Vector2(-19.0, -29.5))
	for i in 120:
		await physics_frame
		if world.members.has(gunner): break
	check(world.members.has(gunner) and gunner.room_runtime_active, "walking into the guard room activates its existing gunner")
	for unit in world.enemy_root.get_children():
		if unit is EmployeeEnemy and unit != gunner and unit.room_runtime_active:
			unit.set_room_runtime_active(false)
	gunner.set_room_runtime_active(false)
	# Pass outside the roll's melee sweep so the guard survives to turn around.
	await check_live_roll(WAREHOUSE_LANE, 0, "chapter-roll-reaim", true)
	check(not gunner.dead, "the roll passes the guard without defeating it")
	if gunner.dead: return
	fixture(WAREHOUSE_LANE, 0)
	await check_bursts()
	await check_reacquisition()
	await check_wall()
	check_dispatch()

func random_floor() -> void:
	for room: Dictionary in world.rooms:
		if not world._is_combat_room(room) or int(room.id) == world.boss_room_id: continue
		world.player.global_position = Vector2(room.center_cell) * 32.0
		world.activate_room(room.id)
		for actor in world.enemy_root.get_children():
			if actor is EmployeeEnemy and int(actor.get_meta(&"dream_room_id", -1)) == int(room.id) and actor.get_meta(&"enemy_type") == &"employee":
				check(actor is SAMPLE, "generated room spawns production gunner")
				if actor is SAMPLE: gunner = actor
		if is_instance_valid(gunner): break
	check(is_instance_valid(gunner), "campaign generated an ordinary encounter")
	if world.boss_room_id >= 0:
		world.player.global_position = Vector2(world.rooms[world.boss_room_id].center_cell) * 32.0
		world.activate_room(world.boss_room_id)
		world._spawn_room_boss()
		check(is_instance_valid(world.boss_enemy) and world.boss_enemy.boss_variant and not world.boss_enemy is SAMPLE, "floor boss retains its own firing rules")
	check(world._regular_employee_scene(&"boss") == world.EMPLOYEE_SCENE and world._regular_employee_scene(&"waitress") == world.EMPLOYEE_SCENE, "train rival and waitress keep their original scene")

func run() -> void:
	folder = OS.get_environment("RANGED_LAB_EVIDENCE")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://ranged_employee_main_test")
	DirAccess.make_dir_recursive_absolute(folder)
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	var settings := root.get_node("SettingsManager")
	settings._load_settings()
	settings._apply_all_audio()
	if not quiet(): return
	Engine.max_fps = 60
	create_timer(300, true, false, true).timeout.connect(func(): quit(3))
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	while main.transition_running: await process_frame
	phase = "chapter"
	main.persistent_day_state = main._create_initial_state()
	main.chapter_one.start_new()
	main.chapter_one.state.stage = "ASCENT"
	set_meta(CHAPTER.RETRY_KEY, {"checkpoint": CHAPTER.Save.CALIBRATED})
	print("RANGED_MAIN checkpoint entry")
	main.chapter_one.resume()
	if await wait_for_floor(main.H06_CHAPTER_SCENE):
		root.get_node("DreamTimeController").set_slow_time_enabled(false)
		await chapter_guard()
		check(timings.has("chapter_roll") and timings.has("chapter_shot_ticks_60hz"), "finished live roll and rifle trials")
	var old_guard: WeakRef = weakref(gunner) if is_instance_valid(gunner) else null
	gunner = null
	phase = "random-floor"
	main.persistent_day_state = main._create_initial_state()
	seed(120)
	print("RANGED_MAIN random campaign entry")
	main._show_dream("basic")
	if await wait_for_floor(main.DREAM_SCENE):
		check(old_guard != null and old_guard.get_ref() == null, "transition releases the previous encounter")
		random_floor()
		check(is_instance_valid(gunner), "tested the generated campaign encounter")
	if not quiet(): return
	var result := {"passed": passed, "failed": failed, "timings": timings, "renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name()}
	FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("RANGED_PROMOTION passed=", passed.size(), " failed=", failed.size())
	quit(0 if failed.is_empty() else 1)
