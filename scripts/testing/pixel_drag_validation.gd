extends RefCounted
const METRICS := preload("res://scripts/testing/lab_recorder.gd")

static func verify(sample: Control, check: Callable, label: String) -> Dictionary:
	var world: Node3D = sample.world
	world.clear_preview_blood(); sample.set_drag_style(true)
	var same_bounds := true; var valid_floor := true; var grooves := true; var pixel_cells := true
	var rng_unchanged := true; var changed := 0; var retained := true
	var before_total := 0; var after_total := 0; var gap_cells := 0; var subset := true
	var before_faces: int = sample.blood.faces.size()
	var before_hits: int = sample.blood.hit_count
	var records: Array = []
	var cases := [[Vector2(6,8)*32,Vector2(24,3)],[Vector2(8,8)*32,Vector2(-24,4)],[Vector2(8,9)*32,Vector2(-3,-24)],[Vector2(5,9)*32,Vector2(16,-18)],[Vector2(5.5,1.3)*32,Vector2(0,-20)]]
	for item in cases:
		var start: Vector2 = item[0]; var finish: Vector2 = start+Vector2(item[1])
		var state: int = world._content_rng.state
		var reference := BlackBloodEffect.new(); reference.visible = false
		world.world_effects_root.add_child(reference); reference.global_position = start
		reference.set_surface_context(world,1)
		var rng := RandomNumberGenerator.new(); rng.state = state
		reference.setup_drag_smear(rng,4,start,finish,1.0,24.0)
		var accepted: bool = world.spawn_corpse_drag_trail(start,finish,1,1.0,24.0)
		var actual: BlackBloodEffect
		for node in world.world_effects_root.get_children():
			if node is BlackBloodEffect and node.has_meta(&"pixel_drag_art") and node.global_position.is_equal_approx(start) and not node.is_queued_for_deletion(): actual = node
		if not accepted or not is_instance_valid(actual):
			check.call(label+"_candidate_created",false); reference.free(); continue
		var info: Dictionary = actual.get_meta(&"pixel_drag_art")
		same_bounds = same_bounds and info.before_bounds==info.after_bounds
		retained = retained and info.after>=floori(info.before*.35) and info.after<info.before
		before_total += info.before; after_total += info.after; gap_cells += info.open_gap_cells
		if info.removed>0: changed += 1
		var source := {}; var output := {}
		for p in reference.ground_pixels: source[p] = true
		for p in actual.ground_pixels:
			output[p] = true
			subset = subset and source.has(p)
			if not source.has(p): valid_floor = valid_floor and actual._is_ground_world_position_valid(actual.to_global(p)) and actual._raycast_environment(actual.to_local(start),p).is_empty()
		for stamp in actual.ground_pixel_types: pixel_cells = pixel_cells and stamp==BlackBloodEffect.StampType.PIXEL_CELL
		var side := (finish-start).normalized().orthogonal()
		for p in reference.ground_pixels:
			var across := (reference.to_global(p)-start).dot(side)
			if absf(across-12.0*.28)<2.0 or absf(across+12.0*.58)<2.0: grooves = grooves and output.has(p)
		for p in actual.ground_pixels:
			var across := (actual.to_global(p)-start).dot(side)
			if absf(across-12.0*.28)<2.0 or absf(across+12.0*.58)<2.0: grooves = grooves and source.has(p)
		rng_unchanged = rng_unchanged and world._content_rng.state==state
		records.append(info)
		reference.free()
	check.call(label+"_pixel_art_changes_outer_cells",changed>=3)
	check.call(label+"_width_direction_and_endpoints_unchanged",records.size()==cases.size() and same_bounds)
	check.call(label+"_new_edge_cells_are_on_valid_unobstructed_floor",valid_floor)
	check.call(label+"_longitudinal_grooves_unchanged",grooves)
	check.call(label+"_reduces_fill_without_erasing_trail",retained and float(after_total)/maxi(before_total,1)<.82)
	check.call(label+"_opens_directional_gaps",gap_cells>5)
	check.call(label+"_only_carves_original_stain",subset)
	check.call(label+"_all_stamps_remain_pixel_cells",pixel_cells)
	check.call(label+"_content_rng_unchanged",rng_unchanged)
	check.call(label+"_spray_atlases_not_touched",sample.blood.faces.size()==before_faces and sample.blood.hit_count==before_hits)
	check.call(label+"_invalid_drag_rejected",not world.spawn_corpse_drag_trail(Vector2(6,8)*32,Vector2(6,8)*32,1,1.0,24.0) and not world.spawn_corpse_drag_trail(Vector2(6,8)*32,Vector2(9,8)*32,1,1.0,24.0))
	world.clear_preview_blood(); sample.set_drag_style(false)
	return {"cases":records,"changed_cases":changed,"scope":label,"retained_fraction":float(after_total)/maxi(before_total,1),"open_gap_cells":gap_cells}

static func measure(sample: Control, pixel_style: bool) -> Dictionary:
	sample.world.clear_preview_blood(); sample.set_drag_style(pixel_style)
	for i in 8: await sample.get_tree().process_frame
	var start := Time.get_ticks_usec(); var previous := start; var events := 0; var accepted := 0
	var times: Array = []; var rows: Array = []
	while Time.get_ticks_usec()-start<3000000:
		await sample.get_tree().process_frame
		var now := Time.get_ticks_usec(); var elapsed := (now-start)/1000000.0
		if events<20 and elapsed>=events*.15:
			var origin := Vector2(5.0+float(events%4)*.9,7.0+floorf(float(events)/4.0)*.4)*32
			if sample.world.spawn_corpse_drag_trail(origin,origin+Vector2(8,2),1,1.0,24.0): accepted += 1
			events += 1
		var dt := (now-previous)/1000.0; previous = now
		times.append(dt); rows.append([elapsed,dt,events])
	return {"pixel_style":pixel_style,"accepted":accepted,"frame_wall":METRICS.stats(times),"raw_rows":rows,"art_passes":sample.world.drag_art_reports.size(),"scope":"3-second matched 20-stroke production-art Camera window; captures outside measurement; not whole-game certification"}
