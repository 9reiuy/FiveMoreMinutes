extends "res://tests/forklift_combat_test.gd"
## Actual 1-2 entry Camera; authored geometry/materials, staged stationary impact targets.
const SURFACE := preload("res://scripts/dream/floor_surface_blood.gd")


func run() -> void:
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.0))
	await frames(3)
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == world.player, "actual 1-2 entrance boards using E")
	await frames(60)
	await capture("00-chapter-parked")
	lift.speed = VEHICLE.FORWARD_SPEED
	Input.action_press("move_up")
	Input.action_press("move_left")
	await key(KEY_SPACE)
	begin_trace()
	await frames(13)
	end_trace("chapter-first-handbrake")
	check(lift.handbraking and lift.body_roll > 0.02 and not world.player.dashing,
		"Space drifts with outward body lean at the actual elevated 1-2 entrance")
	check_seat("actual 1-2 handbrake")
	check(lift.visual.body_mesh_instance.get_active_material(0) is StandardMaterial3D,
		"actual driving canopy remains opaque")
	await capture("01-chapter-handbrake")
	await key(KEY_SPACE, false)
	park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
	var surface: Node3D = SURFACE.install(world)
	check(is_instance_valid(surface), "actual chapter has the shared surface blood host")
	surface.record_diagnostics = true
	var blood_observations: Array[Dictionary] = []
	for lethal in [false, true]:
		park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
		var target := PLAN.FORKLIFT_START + Vector2(0.0, -3.4)
		var enemy: EmployeeEnemy = world._spawn_regular_employee(int(world.get_current_room_id()),
			target * 32.0, &"employee", false, "basic")
		enemy.set_room_runtime_active(true)
		enemy.set_physics_process(false)
		enemy.global_position += target * 32.0 - enemy.get_node("CollisionShape2D").global_position
		enemy.maximum_health = 1000.0
		enemy.current_health = 10.0 if lethal else 1000.0
		await frames(4)
		var events_before: int = surface.accepted_blood_events
		var landed_before: int = surface.hit_count
		var impacts_before: int = surface.impacts.size()
		begin_trace()
		lift.speed = VEHICLE.FORWARD_SPEED
		Input.action_press("move_up")
		for i in 50:
			await physics_frame
			if enemy.current_health < (10.0 if lethal else 1000.0): break
		Input.action_release("move_up")
		lift.reset_motion()
		check(enemy.impact_blood_spawned and surface.accepted_blood_events == events_before + 1,
			"actual chapter " + ("lethal" if lethal else "nonlethal") + " collision emits one blood spray")
		await frames(4)
		end_trace("chapter-first-" + ("lethal" if lethal else "nonlethal") + "-impact")
		await capture("chapter-" + ("lethal" if lethal else "nonlethal") + "-spray")
		await frames(72)
		check(surface.hit_count > landed_before and not surface.faces.is_empty(),
			"actual chapter blood settles onto the elevated room geometry")
		var floor_hits := 0
		for i in range(impacts_before, surface.impacts.size()):
			if Vector3(surface.impacts[i].normal).dot(Vector3.UP) > 0.9:
				floor_hits += 1
		check(floor_hits > 0, "actual chapter blood includes persistent marks on horizontal surfaces")
		blood_observations.append({"lethal": lethal, "floor_hits": floor_hits, "stats": surface.stats()})
		await capture("chapter-" + ("lethal" if lethal else "nonlethal") + "-settled")
		check(lift.try_exit(), "dismount for close review of deposited blood")
		place_feet(target + Vector2(-1.5, 0.5))
		await frames(16)
		await capture("chapter-" + ("lethal" if lethal else "nonlethal") + "-on-foot-review")
		place_feet(lift._seat_position() / 32.0 + Vector2(-1.2, 0.0))
		await frames(3)
		check(lift.board(world.player), "board again after reviewing the persistent stain")
		enemy.queue_free()
		await frames(3)
	check(lift.try_exit() and not lift.handbraking and lift.body_roll == 0.0,
		"actual chapter dismount clears transient drift state")
	var old_vehicle: WeakRef = weakref(lift)
	current_scene.queue_free()
	await frames(5)
	check(not is_instance_valid(old_vehicle.get_ref()), "actual chapter unload releases the vehicle")
	verify_audio()
	var report := {"checks": checks, "failures": failures, "metrics": metrics, "blood": blood_observations,
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"pid": OS.get_process_id(), "scope": "Actual 1-2 Camera and elevated surface blood; staged stationary targets with authored AI frozen for framing. Not a full chapter playthrough or performance certification."}
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FORKLIFT_CHAPTER_DRIFT checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
