extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CONFIG = preload("res://resources/demo_config.tres")

var world: Node3D
var player: CharacterBody2D
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, msg: String) -> void:
	if not condition:
		failures.append(msg)
		print("FAIL: ", msg)
	else:
		print("PASS: ", msg)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	print("--- Starting Tactical Planning Dash Test ---")
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "World dungeon generated")

	player = world.player as CharacterBody2D
	check(player != null, "Player exists")

	var time_controller := root.get_node_or_null("DreamTimeController")
	if time_controller == null:
		time_controller = root.find_child("DreamTimeController", true, false)
	check(time_controller != null, "DreamTimeController exists")

	# ----------------------------------------------------
	# Test 1: Configuration properties in demo_config.tres
	# ----------------------------------------------------
	print("\n[Test 1] Config Parameter Verification")
	check(bool(CONFIG.get("tactical_dash_enabled")) == true, "CONFIG.tactical_dash_enabled is true")
	check(is_equal_approx(float(CONFIG.get("tactical_dash_distance_multiplier")), 2.0), "CONFIG.tactical_dash_distance_multiplier is 2.0")
	check(is_equal_approx(float(CONFIG.get("tactical_dash_cooldown_seconds")), 5.0), "CONFIG.tactical_dash_cooldown_seconds is 5.0")
	check(is_equal_approx(float(CONFIG.get("tactical_dash_time_scale")), 0.05), "CONFIG.tactical_dash_time_scale is 0.05")
	check(is_equal_approx(float(CONFIG.get("tactical_dash_hold_threshold")), 0.16), "CONFIG.tactical_dash_hold_threshold is 0.16")

	# ----------------------------------------------------
	# Test 2: Player Initialization & Preview Overlay
	# ----------------------------------------------------
	print("\n[Test 2] Player State Initialization")
	check(player.tactical_dash_enabled == true, "player.tactical_dash_enabled is true")
	check(is_equal_approx(player.tactical_dash_distance_multiplier, 2.0), "player multiplier is 2.0")
	check(is_equal_approx(player.tactical_dash_cooldown_seconds, 5.0), "player cooldown is 5.0s")
	check(player.tactical_dash_cooldown_left == 0.0, "player tactical cooldown starts at 0")
	check(player.tactical_plan_active == false, "tactical planning inactive by default")
	check(player.tactical_preview_overlay != null, "tactical_preview_overlay instantiated")

	# ----------------------------------------------------
	# Test 3: 2x Distance & Path Resolution
	# ----------------------------------------------------
	print("\n[Test 3] 2x Range & Tactical Path Resolution")
	var base_dist: float = player.dash_distance
	var expected_max_dist: float = base_dist * 2.0
	var far_target := player.global_position + Vector2(800.0, 0.0)
	var resolved_far: Dictionary = player.resolve_tactical_dash_path(far_target)
	check(bool(resolved_far.get("valid", false)), "Resolved far path is valid")
	check(float(resolved_far.get("distance", 0.0)) <= expected_max_dist + 1.0, "Path distance is capped at 2x dash distance")
	check(is_equal_approx(float(resolved_far.get("max_distance", 0.0)), expected_max_dist), "Path max_distance is 2x")

	var near_target := player.global_position + Vector2(50.0, 0.0)
	var resolved_near: Dictionary = player.resolve_tactical_dash_path(near_target)
	check(bool(resolved_near.get("valid", false)), "Resolved near path is valid")
	check(is_equal_approx(float(resolved_near.get("distance", 0.0)), 50.0), "Near path distance matches requested click distance (50px)")

	# ----------------------------------------------------
	# Test 4: Time-Scale & Slow Motion during Planning
	# ----------------------------------------------------
	print("\n[Test 4] Tactical Planning Activation & Bullet Time")
	player.call("_begin_tactical_plan")
	await frames(2)
	check(player.tactical_plan_active == true, "player.tactical_plan_active is true")
	check(time_controller.call("is_tactical_planning_active") == true, "time_controller.tactical_planning_active is true")
	check(is_equal_approx(Engine.time_scale, 0.05), "Engine.time_scale reduced to 0.05x")
	check(player.tactical_preview_overlay.visible == true, "tactical_preview_overlay is visible")
	check(player.tactical_preview_overlay._draw_control.is_visible_in_tree() == true, "overlay draw control is visible in tree")

	# ----------------------------------------------------
	# Test 5: Two-Step Interactive Planning
	# ----------------------------------------------------
	print("\n[Test 5] Two-Step Planning (Destination & Aim Target)")
	var dest_pos := player.global_position + Vector2(60.0, 0.0)
	var dest_ok: bool = player.plan_tactical_destination(dest_pos)
	check(dest_ok, "Step 1: Destination successfully set")
	check(player.tactical_plan_stage == 1, "Player transitioned to Stage 1 (Aiming)")
	check(player.tactical_has_destination == true, "tactical_has_destination is true")
	check(player.tactical_destination.distance_to(dest_pos) < 2.0, "Destination matches clicked location")

	var aim_pos := dest_pos + Vector2(0.0, 50.0)
	player.plan_tactical_aim(aim_pos)
	check(player.tactical_has_aim_target == true, "Step 2: Aim target successfully locked")
	check(player.tactical_aim_target.distance_to(aim_pos) < 0.1, "Aim target matches clicked position")

	# ----------------------------------------------------
	# Test 6: Cancel & Full Cooldown Refund
	# ----------------------------------------------------
	print("\n[Test 6] RMB / Space Release Cancel & 100% CD Refund")
	player.call("_cancel_tactical_plan")
	await frames(2)
	check(player.tactical_plan_active == false, "Planning mode exited")
	check(time_controller.call("is_tactical_planning_active") == false, "time_controller returned to normal")
	check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale restored to 1.0x")
	check(player.tactical_dash_cooldown_left == 0.0, "Tactical CD is 0.0 (100% refund on cancel)")
	check(player.tactical_preview_overlay.visible == false, "tactical_preview_overlay hidden")

	# ----------------------------------------------------
	# Test 7: Tactical Dash Execution & Firearm Attack
	# ----------------------------------------------------
	print("\n[Test 7] Execution & Firearm Attack at Destination")
	player.configure_weapon("basic", CONFIG)
	player.ammo_states["basic"] = {"current": 5, "maximum": 12, "reserve": 100, "reload_left": 0.0}
	var normal_dash_charges_before: int = player.dash_charges

	player.call("_begin_tactical_plan")
	var run_dest := player.global_position + Vector2(80.0, 0.0)
	player.plan_tactical_destination(run_dest)
	var shoot_target := run_dest + Vector2(100.0, 0.0)
	player.plan_tactical_aim(shoot_target)

	player.call("_execute_tactical_plan")
	check(player.dashing == true, "Player started tactical dash")
	check(player.is_tactical_dash_executing == true, "is_tactical_dash_executing is true")
	check(is_equal_approx(player.tactical_dash_cooldown_left, 5.0), "Tactical cooldown set to 5.0s")
	check(player.dash_charges == normal_dash_charges_before, "Normal dash charges NOT deducted by tactical dash")

	# Wait for dash to finish
	var wait_frames := 0
	while player.dashing and wait_frames < 60:
		await physics_frame
		await process_frame
		wait_frames += 1

	check(not player.dashing, "Tactical dash finished within reasonable frames")
	check(player.global_position.distance_to(run_dest) < 10.0, "Player reached planned destination")
	var ammo_after: int = int(player.ammo_states["basic"]["current"])
	check(ammo_after == 4, "Firearm shot fired at destination (ammo 5 -> 4)")

	# ----------------------------------------------------
	# Test 8: Execution & Empty Gun Throw (0 Ammo)
	# ----------------------------------------------------
	print("\n[Test 8] Empty Gun Throw (0 Ammo Rule)")
	await frames(2)
	player.tactical_dash_cooldown_left = 0.0
	player.ammo_states["basic"]["current"] = 0

	var throw_result := {"weapon_thrown": false, "thrown_direction": Vector2.ZERO}
	var drop_listener := func(drop_data: Dictionary) -> void:
		throw_result["weapon_thrown"] = true
		throw_result["thrown_direction"] = drop_data.get("direction", Vector2.ZERO)
	player.weapon_drop_requested.connect(drop_listener)

	player.call("_begin_tactical_plan")
	var throw_dest := player.global_position - Vector2(40.0, 0.0)
	var dest_valid: bool = player.plan_tactical_destination(throw_dest)
	check(dest_valid, "Test 8: Destination planned successfully")
	var throw_target := throw_dest + Vector2(0.0, 100.0) # Aiming DOWN
	player.plan_tactical_aim(throw_target)

	player.call("_execute_tactical_plan")
	check(player.dashing, "Test 8: Player started dash")
	wait_frames = 0
	while player.dashing and wait_frames < 60:
		await physics_frame
		await process_frame
		wait_frames += 1

	check(bool(throw_result.get("weapon_thrown")), "Empty gun was thrown upon completing tactical dash")
	var thrown_dir: Vector2 = throw_result.get("thrown_direction", Vector2.ZERO)
	check(thrown_dir.y > 0.8, "Weapon thrown downwards towards target direction")

	# ----------------------------------------------------
	# Test 9: Independent Cooldown & Normal Dash Isolation
	# ----------------------------------------------------
	print("\n[Test 9] Normal Dash Isolation")
	player.dash_charges = 1
	player.dash_cooldown_left = 0.0
	player.tactical_dash_cooldown_left = 3.0 # On CD

	# Player can still perform normal tap dash while tactical dash is on CD
	check(player.can_start_dash_aim(), "Player can still use normal dash while tactical dash is on CD")
	check(not player.can_start_tactical_plan(), "Tactical dash correctly blocked while on CD")

	if failures.is_empty():
		print("\n==========================================")
		print(" ALL TACTICAL PLANNING DASH TESTS PASSED! ")
		print("==========================================\n")
		quit(0)
	else:
		print("\n==========================================")
		print(" FAILURES DETECTED: %d" % failures.size())
		for f in failures:
			print(" - ", f)
		print("==========================================\n")
		quit(1)
