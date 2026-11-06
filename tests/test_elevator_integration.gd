extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ElevatorFloorDoor3D = preload("res://scripts/dream/elevator_floor_door_3d.gd")
const IndependentElevatorCab3D = preload("res://scripts/dream/independent_elevator_cab_3d.gd")

var world: Node3D
var player: Node2D
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[FAIL] ", label)
	else:
		print("[PASS] ", label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("Elevator test watchdog");quit(2))
	print("==================================================")
	print("=== ELEVATOR INTEGRATION & TRANSITION TEST SUITE ===")
	print("==================================================")

	# 1. Instantiate World
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false # Control manually for Test 1
	root.add_child(world)
	await frames(2)

	player = world.player
	check(player != null, "Player node instantiated")
	check(world != null, "World scene instantiated")

	# ================================================================
	# TEST 1: 1F Startup (No Cab in Floor Scene, Scripted Walk Out)
	# ================================================================
	print("\n--- TEST 1: 1F Startup (No Cab in Floor Scene, Scripted Walk Out) ---")
	check(world.regenerate(41001), "Floor 0 initial generation")
	await frames(2)
	check(world.elevator_floor_door != null, "Floor 0 elevator floor door created")
	check(world.floor_index == 0, "Floor index is 0")
	check(not world.player_has_left_elevator_cab, "Player has not yet left elevator cab")

	# Trigger game start exit
	await world._perform_game_start_cab_exit()
	await frames(2)

	check(world.player_has_left_elevator_cab, "Player successfully walked out of elevator at start")
	check(world.active_transition_cab == null, "No cab in floor scene after exit")
	check(bool(player.get("movement_enabled")) == true, "Player movement enabled after exit")
	check(bool(player.get("dash_enabled")) == true, "Player dash enabled after exit")
	check(world.elevator_floor_door.current_state == ElevatorFloorDoor3D.State.LOCKED, "Floor door closed and locked")
	check(not world.elevator_floor_door.doors_open, "Floor doors closed")

	var door_dist: float = (player.global_position - world.elevator_door_pos_2d).length()
	check(door_dist > 20.0, "Player moved out into corridor (distance: %.1f px)" % door_dist)

	# Verify door collision stops player (Problem 4 fix)
	check(world.elevator_floor_door.door_collider_2d.collision_layer == 4, "Door collider is on WORLD_WALL_LAYER (4)")
	check(not world.elevator_floor_door.door_shape_2d.disabled, "Door collider shape is enabled")

	# Test physical collision: attempt to move player into closed door
	var test_inward: Vector2 = world.elevator_floor_door.get_inward_2d()
	player.global_position = world.elevator_door_pos_2d - test_inward * 16.0
	var collision: KinematicCollision2D = player.move_and_collide(test_inward * 32.0, true)
	check(collision != null, "Closed elevator door physically blocks player collision")

	# Move player back to safe corridor position
	player.global_position = world.elevator_floor_door.get_corridor_approach_position_2d()

	# ================================================================
	# TEST 2: Approach Elevator Without Keycard (Locked / Denied)
	# ================================================================
	print("\n--- TEST 2: Approach Elevator Without Badge (Denied) ---")
	world.has_floor_badge = false
	check(not world.has_floor_badge, "Player does not have badge")

	# Simulate player approaching door
	player.global_position = world.elevator_floor_door.approach_trigger_2d.global_position
	world._on_elevator_approach_entered(player)
	await frames(5)

	check(world.elevator_floor_door.current_state == ElevatorFloorDoor3D.State.LOCKED, "Door remains locked without badge")
	check(not world.floor_transition_in_progress, "Transition not started without badge")
	check(world.transition_phase == &"IDLE", "Transition phase is IDLE")
	check(world.elevator_prompt_active, "Approach without badge sets elevator interaction context")

	# Exit approach trigger
	world._on_elevator_approach_exited(player)
	check(not world.elevator_prompt_active, "Exit clears elevator interaction context")

	# ================================================================
	# TEST 3 & 4: Acquire Badge & Full Transition to 2F
	# ================================================================
	print("\n--- TEST 3 & 4: Transition with Badge (Scripted Walk-In + Cab Ride + 2F Exit) ---")
	world.has_floor_badge = true
	check(world.has_floor_badge, "Player acquired employee badge")

	# Trigger transition entry
	var prev_health: float = float(player.get("health")) if player.get("health") != null else 100.0
	world._on_elevator_approach_entered(player)
	await frames(2)

	check(world.floor_transition_in_progress, "Floor transition started")
	check(world.transition_phase == &"ENTERING", "Transition phase is ENTERING")
	check(bool(player.get("movement_enabled")) == false, "Player manual movement locked on entry")

	# No fixed-duration cab ride: wait for real readiness, then normal exit.
	var elapsed := 0.0
	var loading_seen := false
	var ready_exit_seen := false
	var loading_deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<loading_deadline:
		await process_frame
		if world.transition_phase in [&"LOADING",&"PREPARING_FLOOR"] and root.has_node("ElevatorLoadingCover"):
			loading_seen=true
			check(paused and not player.movement_enabled,"Loading remains covered and input locked")
		if world.transition_phase==&"EXITING":
			ready_exit_seen=true
			break
	check(loading_seen,"Staged floor loaded during closed elevator phase")
	check(ready_exit_seen and world.is_loading_render_ready(),"Current rendered receipt precedes opening")
	check(world.active_transition_cab==null,"Temporary cab removed before arrival")
	check(not player.movement_enabled,"Input stays locked until exit animation completes")
	print("Waiting for normal ready-floor exit animation...")
	var transition_done := false
	elapsed = 0.0
	while not transition_done and elapsed < 8.0:
		await frames(5)
		elapsed += 5.0 / 60.0
		if world.transition_phase == &"IDLE" and not world.floor_transition_in_progress:
			transition_done = true

	check(transition_done, "Floor transition completed successfully")
	check(world.floor_index == 1, "Floor index advanced to 1 (2F)")
	check(not world.has_floor_badge, "Badge was consumed on inter-floor transition")
	check(world.active_transition_cab == null, "Independent cab destroyed after exit (never shown on 2F)")
	check(is_instance_valid(world.room_visibility) and world.room_visibility.world==world, "Current floor visibility owner restored after arrival")
	check(world.wall_root.visible, "New 2F floor building exterior visible")
	check(world.elevator_floor_door != null, "New 2F elevator floor door created")
	check(world.elevator_floor_door.current_state == ElevatorFloorDoor3D.State.LOCKED, "New 2F door locked")
	check(not world.elevator_floor_door.doors_open, "New 2F door closed")
	check(bool(player.get("movement_enabled")) == true, "Player movement restored on 2F")
	check(bool(player.get("dash_enabled")) == true, "Player dash restored on 2F")

	# Check player stats continuity
	var cur_health: float = float(player.get("health")) if player.get("health") != null else 100.0
	check(cur_health == prev_health, "Player health preserved across floor transition (%.1f == %.1f)" % [cur_health, prev_health])

	# ================================================================
	# TEST 5: Consecutive Transition to 3F (Multi-Floor Continuity)
	# ================================================================
	print("\n--- TEST 5: Consecutive Transition to 3F (Multi-Floor Continuity) ---")
	world.has_floor_badge = true
	world._begin_elevator_entry_transition()
	await frames(2)
	check(world.floor_transition_in_progress, "Transition to 3F started")

	transition_done = false
	elapsed = 0.0
	while not transition_done and elapsed < 8.0:
		await frames(5)
		elapsed += 5.0 / 60.0
		if world.transition_phase == &"IDLE" and not world.floor_transition_in_progress:
			transition_done = true

	check(transition_done, "Transition to 3F completed")
	check(world.floor_index == 2, "Floor index advanced to 2 (3F)")
	check(not world.has_floor_badge, "Badge consumed on 3F transition")
	check(world.active_transition_cab == null, "No cab in 3F floor scene")
	check(bool(player.get("movement_enabled")) == true, "Player controls active on 3F")

	# ================================================================
	# TEST 6: Rollback on Staged Generation Failure
	# ================================================================
	print("\n--- TEST 6: Failure Rollback Protection ---")
	world._stash_current_floor_for_rollback()
	check(world._floor_rollback_stash != null, "Floor rollback stash created without type error")
	check(world._stashed_floor_index == 2, "Stashed floor index is 2")

	# Create a mock cab to simulate rollback during cab ride
	world.active_transition_cab = IndependentElevatorCab3D.new(2)
	world.add_child(world.active_transition_cab)
	world.transition_phase = &"CAB_RIDE"
	world.floor_transition_in_progress = true

	# Trigger rollback
	await world._rollback_failed_transition(world.transition_generation_token, 2)
	await frames(2)

	check(world.floor_index == 2, "Floor index rolled back to original (2)")
	check(world._floor_rollback_stash == null, "Floor rollback stash cleared")
	check(world.active_transition_cab == null, "Cab cleaned up on rollback")
	check(not world.floor_transition_in_progress, "Transition flag reset on rollback")
	check(world.transition_phase == &"IDLE", "Transition phase reset to IDLE")
	check(world.wall_root.visible, "Original floor building exterior restored")
	check(bool(player.get("movement_enabled")) == true, "Player movement restored after rollback")

	# ================================================================
	# SUMMARY
	# ================================================================
	print("\n==================================================")
	print("=== TEST SUMMARY: %d CHECKS, %d FAILURES ===" % [checks, failures.size()])
	if failures.is_empty():
		print("=== ALL ELEVATOR TESTS PASSED! ===")
		print("==================================================")
		quit(0)
	else:
		for f in failures:
			print("  FAILED: ", f)
		print("==================================================")
		quit(1)
