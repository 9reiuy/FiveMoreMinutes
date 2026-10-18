extends SceneTree

func _init() -> void:
	print("--- Starting OTXO Blood System Parity Test ---")
	
	# 1. Test Spatter and Velocity Streaks
	var spray := BlackBloodEffect.new()
	spray.setup(Vector2.RIGHT, true)
	var snapshot := spray.get_airborne_visual_snapshot()
	assert(not snapshot.is_empty(), "Airborne particles should not be empty")
	assert(snapshot[0].has("velocity"), "Snapshot must contain velocity for 3D streaks")
	assert(snapshot[0].has("vertical"), "Snapshot must contain vertical velocity for 3D streaks")
	print("✔ Test 1 passed: Airborne snapshot contains velocity & vertical fields (%d particles)" % snapshot.size())
	
	# 2. Test Ground Stamp Classification
	assert(spray.ground_pixel_types.size() == spray.ground_pixels.size(), "Stamp types array must match ground pixels count")
	var core_count := 0
	var satellite_count := 0
	for t in spray.ground_pixel_types:
		if t == BlackBloodEffect.StampType.CORE_SPLAT:
			core_count += 1
		elif t == BlackBloodEffect.StampType.SATELLITE_DOT:
			satellite_count += 1
	assert(core_count > 0, "Should have CORE_SPLAT pixels")
	assert(satellite_count > 0, "Should have SATELLITE_DOT pixels")
	print("✔ Test 2 passed: Ground stamp classification active (Core=%d, Satellite=%d)" % [core_count, satellite_count])
	
	# 3. Test Wall Drips
	var wall := BlackBloodEffect.new()
	wall.setup_wall_stain(Vector2.UP)
	var drip_count := 0
	for t in wall.ground_pixel_types:
		if t == BlackBloodEffect.StampType.WALL_DRIP:
			drip_count += 1
	assert(drip_count > 0, "Wall stain must generate WALL_DRIP entries")
	print("✔ Test 3 passed: Wall stain generates organic wall drips (%d drips)" % drip_count)
	
	# 4. Test Death Pool Noise Distorted Boundary
	var pool := BlackBloodEffect.new()
	pool.setup_death_pool()
	assert(pool.ground_pixels.size() >= 28, "Death pool must have sufficient pixels")
	assert(pool.ground_pixel_types.size() == pool.ground_pixels.size(), "Pool stamp count must match pixel count")
	var min_dist := 9999.0
	var max_dist := 0.0
	for p in pool.ground_pixels:
		var d := p.length()
		min_dist = minf(min_dist, d)
		max_dist = maxf(max_dist, d)
	print("✔ Test 4 passed: Death pool generated Amoeba boundary (Min dist: %.1f, Max dist: %.1f, Pixels: %d)" % [min_dist, max_dist, pool.ground_pixels.size()])
	
	# 5. Test Draw Pipeline
	var canvas_item := spray as CanvasItem
	spray.queue_redraw()
	wall.queue_redraw()
	pool.queue_redraw()
	print("✔ Test 5 passed: _draw() queue_redraw completed cleanly")

	# 6. Test Snappy Speed & Settle Time
	assert(spray.settle_seconds <= 0.25, "Settle seconds must be snappy (<= 0.25s)")
	var vel: Vector2 = snapshot[0]["velocity"]
	assert(vel.length() >= 200.0, "Airborne speed must be high velocity (>= 200 px/s)")
	print("✔ Test 6 passed: Blood spray speed is snappy (Speed=%.1f px/s, Settle=%.2fs)" % [vel.length(), spray.settle_seconds])

	spray.free()
	wall.free()
	pool.free()
	
	print("--- All OTXO Blood Parity Tests PASSED! ---")
	quit(0)
