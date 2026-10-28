extends SceneTree
class Blood extends BlackBloodEffect:
	var raster_calls:=0
	var blocked:=false
	func _ground_cells_in_target(effect:BlackBloodEffect)->Dictionary:
		raster_calls+=1
		return super._ground_cells_in_target(effect)
	func _raycast_environment(_from:Vector2,to:Vector2)->Dictionary:return {"position":to} if blocked else {}
	func _is_ground_world_position_valid(_point:Vector2)->bool:return true
var checks:=0
var failures:Array=[]
var directory:=""
var timings:Array=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func make(legacy:bool)->Blood:
	var value:=Blood.new();root.add_child(value);value.set_process(false)
	value.set_meta(&"blood_floor_visual",true);value.set_meta(&"test_legacy_ground_prepare_order",legacy)
	value.set_meta(&"test_legacy_ground_commit_loop",legacy)
	value.settled=true;value.surface_room_id=1;value.content_version=10
	return value
func clone_state(source:Blood,target:Blood)->void:
	target.global_transform=source.global_transform;target.ground_pixels.assign(source.ground_pixels);target.ground_pixel_types.assign(source.ground_pixel_types)
	target.ground_visual_scale=source.ground_visual_scale;target.blocked=source.blocked;target.surface_room_id=source.surface_room_id
	target.pool_growth_active=source.pool_growth_active;target.fade_started=source.fade_started
	target.set_meta(&"blood_floor_token",source.get_meta(&"blood_floor_token",-1))
func state(value:Blood)->PackedByteArray:return var_to_bytes([value.ground_pixels,value.ground_pixel_types,value.content_version,value.ground_visual_scale,value.ground_sampling_scale])
func _initialize()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):directory=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func run()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=984173
	for trial in 600:
		var a:=make(true);var b:=make(false);var source:=make(false)
		a.position=Vector2(rng.randf_range(-10000,10000),rng.randf_range(-10000,10000));a.rotation=rng.randf_range(-PI,PI);a.scale=Vector2(rng.randf_range(.3,3),rng.randf_range(.3,3));a.skew=rng.randf_range(-.3,.3)
		source.position=a.position+Vector2(rng.randf_range(-250,250),rng.randf_range(-250,250));source.rotation=rng.randf_range(-PI,PI);source.scale=Vector2(rng.randf_range(.3,3),rng.randf_range(.3,3));source.skew=rng.randf_range(-.3,.3)
		for value:Blood in [a,source]:
			value.ground_visual_scale=rng.randf_range(.3,2)
			for index in rng.randi_range(0,160):
				value.ground_pixels.append(Vector2(rng.randf_range(-70,70),rng.randf_range(-70,70)));value.ground_pixel_types.append([0,1,3,4][index%4])
		match trial%17:
			1:source.surface_room_id=2
			2:source.set_meta(&"blood_floor_token",21)
			3:a.blocked=true
			4:source.pool_growth_active=true
			5:a.fade_started=true
			6:source.ground_pixel_types.append(2);source.ground_pixels.append(Vector2.ZERO)
		clone_state(a,b)
		var extent:=rng.randf_range(10,130)
		var old:=a._prepare_ground_merge(source,extent);var current:=b._prepare_ground_merge(source,extent)
		expect(var_to_bytes(old.keys())==var_to_bytes(current.keys()),"ordered eligibility %d"%trial)
		expect(a.absorb_ground_effect(source,extent)==b.absorb_ground_effect(source,extent),"absorption result %d"%trial)
		expect(state(a)==state(b),"committed pixels/version/scale %d"%trial)
		a.free();b.free();source.free()
	# Exact extent/rounding edges, including negative coordinates and stamps
	# whose centers fit but whose lobes exceed the bounded capture.
	for offset in [-109.0,-108.5,-108.0,-107.5,-.50001,-.5,-.49999,.49999,.5,.50001,106.5,107.0,107.5,108.0]:
		for stamp in [0,1,3,4]:
			var a:=make(true);var b:=make(false);var source:=make(false)
			a.ground_pixels.assign([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]);a.ground_pixel_types.assign([4,4,4]);clone_state(a,b)
			source.position=Vector2(offset,0);source.ground_pixels.assign([Vector2.ZERO]);source.ground_pixel_types.assign([stamp])
			expect(a.absorb_ground_effect(source)==b.absorb_ground_effect(source),"boundary acceptance")
			expect(state(a)==state(b),"boundary ordered state")
			a.free();b.free();source.free()
	# A/B/A same-state CPU benchmark. Setup/reset is outside the timed call.
	for valid in [false,true]:
		for legacy in [true,false,true]:
			var a:=make(legacy);var source:=make(false)
			for y in range(-40,40):
				for x in range(-50,50):a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
			source.position=Vector2(0,0) if valid else Vector2(155,0)
			source.ground_pixels.assign([Vector2.ZERO,Vector2.ONE,Vector2(-1,1)]);source.ground_pixel_types.assign([4,4,4])
			var values:Array[float]=[]
			for iteration in 72:
				a.raster_calls=0
				var started:=Time.get_ticks_usec();var cells:=a._prepare_ground_merge(source,108.0);var duration:float=(Time.get_ticks_usec()-started)/1000.0
				expect(not cells.is_empty() if valid else cells.is_empty(),"benchmark acceptance")
				expect(a.raster_calls==2 if valid or legacy else a.raster_calls==1,"invalid incoming avoids dense target raster")
				if iteration>=12:values.append(duration)
			values.sort();var row:Dictionary={"valid":valid,"legacy":legacy,"target_pixels":a.ground_pixels.size(),"incoming_pixels":source.ground_pixels.size(),"median_ms":values[30],"p95_ms":values[56],"samples":values.size(),"scope":"synchronous prepare only, no GPU/full-frame claim"}
			timings.append(row);print("BLOOD_PREPARE_ORDER_BENCH ",JSON.stringify(row));a.free();source.free()
	var report:Dictionary={"checks":checks,"failures":failures,"timings":timings}
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("test.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BLOOD_PREPARE_ORDER checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
