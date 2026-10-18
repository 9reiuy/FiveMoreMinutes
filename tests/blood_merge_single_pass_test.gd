extends SceneTree
class CountedBlood extends BlackBloodEffect:
	var raster_calls := 0
	var blocked := false
	func _ground_cells_in_target(effect: BlackBloodEffect) -> Dictionary:
		raster_calls+=1
		return super._ground_cells_in_target(effect)
	func _raycast_environment(_from: Vector2, destination: Vector2) -> Dictionary:
		return {"position":destination} if blocked else {}
	func _is_ground_world_position_valid(point: Vector2) -> bool:
		return absf(point.x)<10000.0
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func effect(legacy: bool) -> CountedBlood:
	var blood:=CountedBlood.new()
	root.add_child(blood); blood.set_process(false)
	blood.set_meta(&"blood_floor_visual",true)
	blood.set_meta(&"test_legacy_ground_merge",legacy)
	blood.settled=true; blood.surface_room_id=1; blood.content_version=17
	return blood
func copy_state(source: CountedBlood, target: CountedBlood) -> void:
	target.transform=source.transform
	target.ground_pixels.assign(source.ground_pixels)
	target.ground_pixel_types.assign(source.ground_pixel_types)
	target.ground_visual_scale=source.ground_visual_scale
	target.blocked=source.blocked
	target.pool_growth_active=source.pool_growth_active
	target.fade_started=source.fade_started
	target.surface_room_id=source.surface_room_id
	target.set_meta(&"blood_floor_token",source.get_meta(&"blood_floor_token",-1))
func old_pipeline(target: CountedBlood, source: CountedBlood) -> bool:
	return target.can_absorb_ground_effect(source,108.0) and target.absorb_ground_effect(source)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var rng:=RandomNumberGenerator.new(); rng.seed=81273
	for trial in 180:
		var old_a:=effect(true); var old_b:=effect(true)
		var new_a:=effect(false); var new_b:=effect(false)
		old_a.position=Vector2(rng.randf_range(-1200,1200),rng.randf_range(-1200,1200))
		old_b.position=old_a.position+Vector2(rng.randf_range(-40,40),rng.randf_range(-40,40))
		old_a.rotation=rng.randf_range(-PI,PI); old_b.rotation=rng.randf_range(-PI,PI)
		old_a.scale=Vector2(rng.randf_range(.5,2),rng.randf_range(.5,2))
		old_b.scale=Vector2(rng.randf_range(.5,2),rng.randf_range(.5,2))
		old_a.ground_visual_scale=rng.randf_range(.35,1.5); old_b.ground_visual_scale=rng.randf_range(.35,1.5)
		for target in [old_a,old_b]:
			for index in 64:
				target.ground_pixels.append(Vector2(rng.randf_range(-30,30),rng.randf_range(-30,30)))
				target.ground_pixel_types.append([0,1,3,4][index%4])
		match trial%13:
			1: old_b.surface_room_id=2
			2: old_b.set_meta(&"blood_floor_token",7)
			3: old_a.blocked=true
			4: old_b.pool_growth_active=true
			5: old_a.fade_started=true
			6: old_b.position+=Vector2(400,0)
			7: old_b.ground_pixel_types[0]=BlackBloodEffect.StampType.WALL_DRIP
		copy_state(old_a,new_a); copy_state(old_b,new_b)
		# Check both public eligibility and full results against the old pipeline,
		# including insertion order, rounding, stamp expansion and content version.
		check(old_a._ground_cells_in_target(old_b)==new_a._ground_cells_in_target(new_b),"raster parity %d"%trial)
		check(old_a.can_absorb_ground_effect(old_b)==new_a.can_absorb_ground_effect(new_b),"eligibility parity %d"%trial)
		old_a.raster_calls=0; new_a.raster_calls=0
		var accepted:=old_pipeline(old_a,old_b)
		check(accepted==new_a.absorb_ground_effect(new_b),"merge parity %d"%trial)
		check(old_a.ground_pixels==new_a.ground_pixels and old_a.ground_pixel_types==new_a.ground_pixel_types,"ordered pixels parity %d"%trial)
		check(old_a.content_version==new_a.content_version and old_a.ground_visual_scale==new_a.ground_visual_scale,"version/scale parity %d"%trial)
		if accepted: check(old_a.raster_calls==6 and new_a.raster_calls==2,"one operation raster count %d"%trial)
		for node in [old_a,old_b,new_a,new_b]: node.free()
	# Representative dense settled atlas. Setup/reset is excluded from timing.
	var pixels: Array[Vector2]=[]; var stamps: Array[int]=[]
	for y in range(-25,25):
		for x in range(-40,40): pixels.append(Vector2(x,y)); stamps.append(BlackBloodEffect.StampType.PIXEL_CELL)
	for legacy in [true,false,true]:
		var target:=effect(legacy); var incoming:=effect(legacy)
		incoming.position=Vector2(48,0)
		incoming.ground_pixels.assign([Vector2.ZERO,Vector2(2,2),Vector2(4,0)])
		incoming.ground_pixel_types.assign([0,1,3])
		var times: Array[float]=[]
		for iteration in 22:
			target.ground_pixels.assign(pixels); target.ground_pixel_types.assign(stamps); target.ground_visual_scale=1.0
			var start:=Time.get_ticks_usec()
			var accepted:=old_pipeline(target,incoming) if legacy else target.absorb_ground_effect(incoming)
			var elapsed:=float(Time.get_ticks_usec()-start)/1000.0
			check(accepted,"dense merge accepted")
			if iteration>=2: times.append(elapsed)
		times.sort()
		print("BLOOD_MERGE_LOCAL_PERF ",JSON.stringify({"legacy":legacy,"pixels":pixels.size(),"median_ms":times[10],"p95_ms":times[19],"samples":20,"scope":"CPU synchronous merge only; not total combat frame time"}))
		target.free(); incoming.free()
	print("BLOOD_SINGLE_PASS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
