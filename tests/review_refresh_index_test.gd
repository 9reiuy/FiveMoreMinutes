extends SceneTree
## Real sample / formal GPU output. Legacy lookup is reconstructed in-memory
## only, retaining the exact current art and all other refresh operations.
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func frames(count: int) -> void:
	for index in count: await process_frame
func snapshot() -> Image:
	await frames(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func legacy_copy(review: Node, script: GDScript) -> Node:
	var copy: Node=script.new()
	copy.world=review.world
	for property in [&"walls",&"windows",&"doors",&"props",&"wall_materials"]:
		copy.set(property,review.get(property).duplicate())
	copy.enabled=review.enabled
	return copy
func measure(review: Node) -> Dictionary:
	var samples: Array=[]
	for index in 30:
		var start:=Time.get_ticks_usec()
		review.refresh_assets()
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	return {"median_ms":samples[15],"p95_ms":samples[28],"calls":30}
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var script:=GDScript.new()
	script.source_code=FileAccess.get_file_as_string("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")\
		.replace("wall_ids.has(wall.get_instance_id())","walls.any(func(r: Dictionary) -> bool: return r.node.get_ref()==wall)")\
		.replace("window_ids.has(wall.get_instance_id())","windows.any(func(r: Dictionary) -> bool: return r.wall.get_ref()==wall)")\
		.replace("door_ids.has(door.get_instance_id())","doors.any(func(r: Dictionary) -> bool: return r.door.get_ref()==door)")
	check(script.reload()==OK,"Legacy diagnostic script parses")
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false
	world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	for floor_index in 3:
		paused=false
		check(world.regenerate(120+floor_index),"Sample floor generation")
		await frames(30)
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		# Compare the furnished office, not the arrival transition's black mask.
		world.transition_phase=&"IDLE"
		for cell in world.floor_cells:
			var point:=Vector2(cell)*32.0
			if point.length()<100.0 and world._content_position_is_clear(point,12.0):
				world.player.global_position=point
				break
		world.camera_aim_offset=Vector3.ZERO
		await frames(30)
		paused=true
		var review: Node=world.get_node("SampleWallAndDesktopReview")
		review.refresh_assets()
		var old:=legacy_copy(review,script)
		var counts:=Vector3i(review.walls.size(),review.windows.size(),review.doors.size())
		check(counts.x>100 and counts.y>0 and counts.z>0,"Representative walls/windows/doors exist")
		for pixel in [false,true]:
			for palette in [false,true]:
				display.set_selective_enabled(pixel); display.set_palette_enabled(palette)
				old.refresh_assets()
				var before: Image=await snapshot()
				review.refresh_assets()
				var after: Image=await snapshot()
				check(before.get_data()==after.get_data(),"Indexed refresh preserves formal GPU pixels")
				if floor_index==0 and pixel and palette:
					before.save_png("res://.runtime/review_index_before.png")
					after.save_png("res://.runtime/review_index_after.png")
		var baseline:=measure(old)
		var candidate:=measure(review)
		var repeat:=measure(old)
		check(Vector3i(review.walls.size(),review.windows.size(),review.doors.size())==counts,"Repeated refresh does not duplicate dressing")
		check(candidate.median_ms<minf(baseline.median_ms,repeat.median_ms)*.5,"Indexed membership reduces refresh CPU cost materially")
		# Invalid weak references must be discarded, not poison the next layout.
		var dummy:=Node3D.new()
		var stale: Dictionary={"node":weakref(dummy)}
		review.walls.append(stale); dummy.free()
		review.refresh_assets()
		check(review.walls.size()==counts.x,"Stale wall record is released")
		print("REVIEW_INDEX_PERF ",JSON.stringify({"floor":floor_index,"walls":counts.x,"windows":counts.y,"doors":counts.z,"legacy":baseline,"indexed":candidate,"legacy_repeat":repeat,"scope":"refresh CPU only; GPU image parity checked separately"}))
		old.free()
	settings.values=saved; paused=false; display.queue_free()
	await frames(5)
	print("REVIEW_INDEX_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
