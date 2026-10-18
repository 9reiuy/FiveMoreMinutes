extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const TRAIL_SCRIPT = preload("res://scripts/entities/roll_speed_trail.gd")
const CONFIG = preload("res://resources/demo_config.tres")

var world: Node3D
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
	print("--- Starting Katana ZERO Dash Trail Parity Test ---")
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "World dungeon generated")

	var player: Node2D = world.player
	check(player != null, "Player exists")

	# Test 1: Test RollSpeedTrail direct setup and Katana ZERO features
	RollSpeedTrail.reset_counter()
	var trail1 := TRAIL_SCRIPT.new() as RollSpeedTrail
	root.add_child(trail1)
	trail1.setup(player.visual, Vector2(100, 100), Vector2.RIGHT, 0.12, 0.85, 0.26)
	
	# Verify MotionStretch and Snapshot hierarchy
	var motion_axis := trail1.get_node_or_null("MotionStretch")
	check(motion_axis != null, "MotionStretch container created")
	var snapshot := motion_axis.get_node_or_null("Snapshot") if motion_axis else null
	check(snapshot != null, "Snapshot node created")

	# Verify Katana ZERO Shader applied to cloned sprites
	var head_sprite := snapshot.find_child("Head", true, false) as Sprite2D
	check(head_sprite != null, "Head sprite cloned into snapshot")
	if head_sprite != null:
		var mat := head_sprite.material as ShaderMaterial
		check(mat != null, "ShaderMaterial applied to sprite")
		if mat != null:
			var prim: Color = mat.get_shader_parameter("primary_color")
			var sec: Color = mat.get_shader_parameter("secondary_color")
			check(is_equal_approx(prim.g, 0.95), "Ghost 0 has Cyber Cyan primary color")
			check(is_equal_approx(sec.r, 1.0), "Ghost 0 has Hot Magenta secondary chromatic color")
			var split: float = mat.get_shader_parameter("split_pixels")
			check(split >= 2.0, "Chromatic split pixels configured (>= 2.0)")
			var scanline: float = mat.get_shader_parameter("scanline_strength")
			check(scanline >= 0.2, "CRT scanlines configured (>= 0.2)")

	# Verify Blade Speed Streaks
	var streak_found := false
	for child in trail1.get_children():
		if child is Line2D:
			streak_found = true
			var line := child as Line2D
			check(line.points.size() >= 2, "Blade streak has 2 points")
			check(line.points[1].x < line.points[0].x, "Blade streak trails backwards along movement")
			check(line.width_curve != null, "Blade streak has tapering width curve")
			break
	check(streak_found, "Blade speed streaks (Line2D) generated for dash")

	# Test 2: Verify Palette Cycling (Ghost 1 should be Hot Magenta)
	var trail2 := TRAIL_SCRIPT.new() as RollSpeedTrail
	root.add_child(trail2)
	trail2.setup(player.visual, Vector2(120, 100), Vector2.RIGHT, 0.12, 0.85, 0.26)
	var head_sprite2 := trail2.find_child("Head", true, false) as Sprite2D
	if head_sprite2 != null and head_sprite2.material is ShaderMaterial:
		var prim2: Color = (head_sprite2.material as ShaderMaterial).get_shader_parameter("primary_color")
		check(is_equal_approx(prim2.r, 1.0) and prim2.g < 0.2, "Ghost 1 cycles to Hot Magenta primary color")

	trail1.queue_free()
	trail2.queue_free()
	await frames(2)

	# Test 3: Integrated In-Game Player Dash Test
	var initial_pos := player.global_position
	var parent_before_count := player.get_parent().get_child_count()

	# Trigger dash
	player.last_aim_direction = Vector2.RIGHT
	player.dash_charges = 1
	player.dash_cooldown_left = 0.0
	player.call("_start_dash", Vector2.RIGHT)
	check(player.dashing, "Player successfully started dash")

	# Advance frames during dash
	var trails_seen := 0
	for step in 8:
		await physics_frame
		await process_frame
		for child in player.get_parent().get_children():
			if child is RollSpeedTrail:
				trails_seen += 1

	check(trails_seen >= 3, "Multiple Katana ZERO ghosts spawned during dash (found %d instances)" % trails_seen)

	# Advance frames until dash finishes and trails fade out
	await frames(30)
	check(not player.dashing, "Player dash completed")

	await frames(25)
	var lingering_trails := 0
	for child in player.get_parent().get_children():
		if child is RollSpeedTrail and is_instance_valid(child):
			lingering_trails += 1
	check(lingering_trails == 0, "All Katana ZERO trail instances cleanly freed after lifetime")

	if failures.is_empty():
		print("--- ALL Katana ZERO Dash Trail Tests PASSED! ---")
		quit(0)
	else:
		print("--- Failures detected: %d ---" % failures.size())
		quit(1)
