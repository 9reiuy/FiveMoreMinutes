extends "res://tests/blood_ground_prepare_order_test.gd"
func fill(value:Blood)->void:
	for y in range(-20,20):
		for x in range(-30,30):value.ground_pixels.append(Vector2(x,y));value.ground_pixel_types.append(4)
func same(a:Blood,b:Blood,source:Blood,label:String)->void:
	expect(a.absorb_ground_effect(source)==b.absorb_ground_effect(source),label+" acceptance")
	expect(state(a)==state(b),label+" ordered committed state")
func run()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=169837
	for origin in [Vector2.ZERO,Vector2(4096.125,-2048.5),Vector2(65535.5,-65535.5),Vector2(65536,65536),Vector2(65536.5,0),Vector2(10000000,10000000)]:
		var a:=make(true);var b:=make(false);var source:=make(false)
		a.set_meta(&"test_legacy_compact_ground_cache",true);b.set_meta(&"test_legacy_compact_ground_cache",false)
		a.position=origin;b.position=origin;fill(a);fill(b)
		source.position=origin;source.ground_pixels.assign([Vector2.ZERO]);source.ground_pixel_types.assign([4])
		same(a,b,source,"prime cache")
		if origin.x<=65536.0:
			expect(not b._compact_merge_cells.is_empty(),"normal translation stores bounded compact cache")
			var first:=b._ground_cells_in_target(b);first.clear()
			expect(not b._ground_cells_in_target(b).is_empty(),"returned dictionary never aliases cached ownership")
		else:expect(b._compact_merge_cells.is_empty(),"large translation stays on original round-trip path")
		for step in 90:
			# Alternate changes invalidate by exact array/transform/scale checks,
			# without relying on callers to update a content-version counter.
			match step:
				10:
					a.ground_pixels[0]+=Vector2(.5,.5);b.ground_pixels[0]=a.ground_pixels[0]
				20:
					a.ground_pixel_types[0]=0;b.ground_pixel_types[0]=0
				30:
					a.position+=Vector2(.125,.25);b.position=a.position
				40:
					a.rotation=.17;b.rotation=a.rotation;a.scale=Vector2(.9,1.1);b.scale=a.scale
				50:
					a.rotation=0;b.rotation=0;a.scale=Vector2.ONE;b.scale=Vector2.ONE
				60:
					a.ground_visual_scale=1.1;b.ground_visual_scale=1.1
				70:
					a.ground_pixels.reverse();b.ground_pixels.reverse();a.ground_pixel_types.reverse();b.ground_pixel_types.reverse()
				80:
					a.ground_pixels.remove_at(0);b.ground_pixels.remove_at(0);a.ground_pixel_types.remove_at(0);b.ground_pixel_types.remove_at(0)
			source.position=a.position+Vector2(rng.randf_range(-130,130),rng.randf_range(-130,130))
			source.ground_pixels.assign([Vector2.ZERO,Vector2.ONE,Vector2(-1,1)]);source.ground_pixel_types.assign([step%2,4,4])
			same(a,b,source,"mutations %s/%d"%[origin,step])
		for extent in [8.0,16.0,108.0,109.0,8192.0]:
			expect(var_to_bytes(a._prepare_ground_merge(source,extent).keys())==var_to_bytes(b._prepare_ground_merge(source,extent).keys()),"changed extent never reuses a wider capture acceptance")
		a.free();b.free();source.free()
	# Dense accepted workload; only prepare+commit are timed, construction is not.
	for legacy in [true,false,true]:
		var a:=make(legacy);var source:=make(false)
		a.set_meta(&"test_legacy_compact_ground_cache",legacy)
		for y in range(-40,40):
			for x in range(-50,50):a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
		source.ground_pixel_types.assign([4,4,4])
		var values:Array[float]=[]
		for iteration in 72:
			source.position=Vector2(0,0);source.ground_pixels.assign([Vector2(iteration%40-20,0),Vector2.ONE,Vector2(-1,1)])
			var started:=Time.get_ticks_usec();var accepted:=a.absorb_ground_effect(source);var duration:float=(Time.get_ticks_usec()-started)/1000.0
			expect(accepted,"dense unchanged union remains accepted")
			if iteration>=12:values.append(duration)
		values.sort();var row:Dictionary={"legacy":legacy,"target_pixels":a.ground_pixels.size(),"median_ms":values[30],"p95_ms":values[56],"cache_hits":a._compact_merge_hits,"samples":values.size(),"scope":"full synchronous absorb, including cache creation/validation; not gameplay FPS"}
		timings.append(row);print("BLOOD_COMPACT_CACHE_BENCH ",JSON.stringify(row));a.free();source.free()
	for legacy in [true,false,true]:
		var a:=make(legacy);var source:=make(false);a.set_meta(&"test_legacy_compact_ground_cache",legacy)
		for y in range(-30,30):
			for x in range(-50,50):a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
		source.position=Vector2(50,0);source.ground_pixel_types.assign([4,4,4])
		var values:Array[float]=[]
		for iteration in 72:
			source.ground_pixels.assign([Vector2(0,iteration-36),Vector2(1,iteration-36),Vector2(2,iteration-36)])
			var started:=Time.get_ticks_usec();var accepted:=a.absorb_ground_effect(source);var duration:float=(Time.get_ticks_usec()-started)/1000.0
			expect(accepted,"new boundary pixels remain accepted")
			if iteration>=12:values.append(duration)
		values.sort();var row:Dictionary={"legacy":legacy,"target_pixels":a.ground_pixels.size(),"median_ms":values[30],"p95_ms":values[56],"cache_hits":a._compact_merge_hits,"samples":values.size(),"scope":"full synchronous absorb with three new cells each call; includes cache refresh, no gameplay FPS claim"}
		timings.append(row);print("BLOOD_COMPACT_GROW_BENCH ",JSON.stringify(row));a.free();source.free()
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("test.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings},"\t"));file.close()
	print("BLOOD_COMPACT_CACHE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
