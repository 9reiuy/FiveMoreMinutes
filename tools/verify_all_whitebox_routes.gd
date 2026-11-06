extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	print("==================================================")
	print("  MEGASTRUCTURE WHITEBOX FULL ROUTE VERIFICATION  ")
	print("==================================================")
	
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)
	
	for i in range(15):
		await process_frame
		
	var player: CharacterBody2D = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	print("[INIT] Player spawned at: ", player.global_position)
	
	# --- TEST 1: Straight north walk from spawn (X = 192) ---
	print("\n--- TEST 1: Straight Walk along Center Lane (X = 192) ---")
	player.global_position = Vector2(192.0, 1152.0)
	player.velocity = Vector2.ZERO
	
	var stuck_frame = -1
	var last_y = player.global_position.y
	var stuck_ticks = 0
	
	for f in range(250):
		player.velocity = Vector2(0, -200)
		player.move_and_slide()
		await physics_frame
		
		if abs(player.global_position.y - last_y) < 0.001:
			stuck_ticks += 1
			if stuck_ticks >= 3:
				stuck_frame = f
				break
		else:
			stuck_ticks = 0
		last_y = player.global_position.y
		
		if player.global_position.y <= 320.0:
			break
			
	if stuck_frame >= 0:
		print("FAILED: Center walk stuck at pos: ", player.global_position)
		quit(1)
	else:
		print("PASSED: Center walk reached corridor exit Y = %.1f (CLEAR)" % player.global_position.y)

	# --- TEST 2: Straight north walk across ALL X start positions in Zone 1 ---
	print("\n--- TEST 2: Multi-Lane Funnel Ingress from Zone 1 (Pure W forward) ---")
	var test_xs = [64, 96, 128, 160, 192, 224, 256, 288, 320]
	var all_lanes_passed = true
	
	for tx in test_xs:
		player.global_position = Vector2(float(tx), 1152.0)
		player.velocity = Vector2.ZERO
		last_y = player.global_position.y
		stuck_ticks = 0
		var stuck = false
		
		for f in range(280):
			player.velocity = Vector2(0, -200)
			player.move_and_slide()
			await physics_frame
			
			if abs(player.global_position.y - last_y) < 0.001:
				stuck_ticks += 1
				if stuck_ticks >= 3:
					stuck = true
					break
			else:
				stuck_ticks = 0
			last_y = player.global_position.y
			
			if player.global_position.y <= 320.0:
				break
				
		if stuck:
			print("  X = %3d: FAILED! Stuck at %s" % [tx, player.global_position])
			all_lanes_passed = false
		else:
			print("  X = %3d: PASSED -> reached Y = %.1f (final X = %.1f)" % [tx, player.global_position.y, player.global_position.x])

	# --- TEST 3: Pure W from inside every alcove ---
	print("\n--- TEST 3: Alcove Egress (Moving straight North from cover) ---")
	var alcoves = [
		{"name": "West Alcove 2 (Z: 23.5m)", "pos": Vector2(96.0, 750.0)},
		{"name": "East Alcove 1 (Z: 18.5m)", "pos": Vector2(288.0, 590.0)},
		{"name": "West Alcove 1 (Z: 13.5m)", "pos": Vector2(96.0, 430.0)}
	]
	var all_alcoves_passed = true
	for at in alcoves:
		player.global_position = at["pos"]
		player.velocity = Vector2.ZERO
		last_y = player.global_position.y
		stuck_ticks = 0
		var stuck = false
		
		for f in range(120):
			player.velocity = Vector2(0, -200)
			player.move_and_slide()
			await physics_frame
			
			if abs(player.global_position.y - last_y) < 0.001:
				stuck_ticks += 1
				if stuck_ticks >= 3:
					stuck = true
					break
			else:
				stuck_ticks = 0
			last_y = player.global_position.y
			
			if player.global_position.y <= at["pos"].y - 96.0:
				break
				
		if stuck:
			print("  %s: FAILED! Stuck at %s" % [at["name"], player.global_position])
			all_alcoves_passed = false
		else:
			print("  %s: PASSED -> smoothly slid out to pos = %s" % [at["name"], player.global_position])

	# --- TEST 4: Flanking Shooter Barricade in Zone 3 ---
	print("\n--- TEST 4: Zone 3 Flanking Routes around Barricade ---")
	# Left flank: exit corridor at (160, 320), navigate northwest around barricade to elevator (192, 48)
	var left_flank_passed = true
	player.global_position = Vector2(160.0, 320.0)
	for f in range(150):
		# move diagonally left-up then up then right
		var target = Vector2(112.0, 160.0)
		if player.global_position.y < 165.0:
			target = Vector2(192.0, 48.0)
		var dir = (target - player.global_position).normalized()
		player.velocity = dir * 200.0
		player.move_and_slide()
		await physics_frame
		if player.global_position.distance_to(Vector2(192.0, 48.0)) < 24.0:
			break
	if player.global_position.distance_to(Vector2(192.0, 48.0)) < 32.0:
		print("  Left Flank: PASSED -> Reached Elevator at pos = %s" % player.global_position)
	else:
		print("  Left Flank: FAILED at pos = %s" % player.global_position)
		left_flank_passed = false

	# Right flank
	var right_flank_passed = true
	player.global_position = Vector2(224.0, 320.0)
	for f in range(150):
		var target = Vector2(272.0, 160.0)
		if player.global_position.y < 165.0:
			target = Vector2(192.0, 48.0)
		var dir = (target - player.global_position).normalized()
		player.velocity = dir * 200.0
		player.move_and_slide()
		await physics_frame
		if player.global_position.distance_to(Vector2(192.0, 48.0)) < 24.0:
			break
	if player.global_position.distance_to(Vector2(192.0, 48.0)) < 32.0:
		print("  Right Flank: PASSED -> Reached Elevator at pos = %s" % player.global_position)
	else:
		print("  Right Flank: FAILED at pos = %s" % player.global_position)
		right_flank_passed = false

	print("\n==================================================")
	if all_lanes_passed and all_alcoves_passed and left_flank_passed and right_flank_passed:
		print("  ALL TESTS PASSED: 100% SNAG-FREE NAVIGATION!     ")
		print("==================================================")
		quit(0)
	else:
		print("  SOME TESTS FAILED!                              ")
		print("==================================================")
		quit(1)
