extends SceneTree
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func blood(legacy:bool)->BlackBloodEffect:
	var value:=BlackBloodEffect.new();root.add_child(value);value.set_process(false)
	value.set_meta(&"blood_floor_visual",true);value.set_meta(&"test_legacy_merge_frontier",legacy);value.set_meta(&"test_legacy_deposit_bounds",legacy)
	value.settled=true;value.surface_room_id=1
	return value
func state(a:BlackBloodEffect)->Array:
	return [a.ground_pixels,a.ground_pixel_types,a.ground_visual_scale,a.content_version,a._pool_growth_cells,a._pool_cell_arrivals]
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var random:=RandomNumberGenerator.new();random.seed=955219
	var a:=blood(true);var b:=blood(false)
	for i in 140:
		# Prefix-valid growth, followed by deletions, reordering, transforms,
		# non-pixel stamps, cap rejection and a different extent.
		if i%23==0:
			a.ground_pixels.clear();a.ground_pixel_types.clear()
			for y in range(-9,9):
				for x in range(-15,15):
					if posmod(x+y,7)!=0:a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
			b.ground_pixels.assign(a.ground_pixels);b.ground_pixel_types.assign(a.ground_pixel_types)
		if i%23==5:
			a.ground_pixels.reverse();a.ground_pixel_types.reverse();b.ground_pixels.reverse();b.ground_pixel_types.reverse()
		if i%23==9:
			a.ground_pixels.remove_at(0);a.ground_pixel_types.remove_at(0);b.ground_pixels.remove_at(0);b.ground_pixel_types.remove_at(0)
		if i%23==13:
			a.rotation+=.17;b.rotation=a.rotation;a.scale=Vector2(1.1,.9);b.scale=a.scale
		var source:=blood(false);source.position=Vector2(random.randf_range(-20,20),random.randf_range(-16,16))
		for n in 8:source.ground_pixels.append(Vector2(random.randi_range(-7,7),random.randi_range(-7,7)));source.ground_pixel_types.append([0,1,3,4][n%4])
		var extent:=108.0 if i%11 else 8.0
		var aa:=a.absorb_ground_effect(source,extent);var bb:=b.absorb_ground_effect(source,extent)
		expect(aa==bb,"merge acceptance %d"%i)
		expect(var_to_bytes(state(a))==var_to_bytes(state(b)),"ordered merge state %d"%i)
		source.free()
	a.free();b.free()
	# Full patch rasterization and RNG state, including clipped, thin and large
	# rotated patches. Only points the original distance test rejects are skipped.
	for trial in 120:
		a=blood(true);b=blood(false)
		var patch:Dictionary={"center":Vector2(random.randf_range(-105,105),random.randf_range(-105,105)),"radii":Vector2(random.randf_range(.1,26),random.randf_range(.1,23)),"angle":random.randf_range(-PI,PI),"arrival":random.randf()}
		var ra:=RandomNumberGenerator.new();ra.seed=trial+718
		var rb:=RandomNumberGenerator.new();rb.seed=ra.seed
		a._rasterize_pool_deposit(patch,ra,{}, {},true)
		b._rasterize_pool_deposit(patch,rb,{}, {},true)
		expect(var_to_bytes(state(a))==var_to_bytes(state(b)),"patch pixels and arrival order %d"%trial)
		expect(ra.state==rb.state,"patch RNG %d"%trial)
		a.free();b.free()
	for trial in 16:
		a=blood(true);b=blood(false);a.office_pool_core=true;b.office_pool_core=true
		var ra:=RandomNumberGenerator.new();ra.seed=trial+418
		var rb:=RandomNumberGenerator.new();rb.seed=ra.seed
		a.setup_death_pool(ra,1,1.7,.45,.35,2.05,Vector2(1,.7));b.setup_death_pool(rb,1,1.7,.45,.35,2.05,Vector2(1,.7))
		expect(var_to_bytes(state(a))==var_to_bytes(state(b)) and ra.state==rb.state,"complete initialization parity %d"%trial)
		for dt in [.08,.14,.3]:
			a._process(dt);b._process(dt);expect(var_to_bytes(state(a))==var_to_bytes(state(b)),"growth/arrival parity %d"%trial)
		a.free();b.free()
	# Capacity edge with a surrounded hole, followed by an over-capacity union.
	a=blood(true);b=blood(false)
	for y in range(-41,42):
		for x in range(-50,50):
			if Vector2(x,y)==Vector2.ZERO or a.ground_pixels.size()>=8191:continue
			a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
	b.ground_pixels.assign(a.ground_pixels);b.ground_pixel_types.assign(a.ground_pixel_types)
	var incoming:=blood(false);incoming.ground_pixels.assign([Vector2.ONE]);incoming.ground_pixel_types.assign([4])
	for index in 3:
		incoming.position=Vector2.ZERO if index<2 else Vector2(80,80)
		expect(a.absorb_ground_effect(incoming)==b.absorb_ground_effect(incoming),"capacity eligibility parity")
		expect(var_to_bytes(state(a))==var_to_bytes(state(b)),"capacity ordered pixel parity")
	a.free();b.free();incoming.free()
	# Equal workload, no can_absorb double-raster legacy pipeline in this bench.
	for legacy in [true,false,true]:
		a=blood(legacy)
		for y in range(-25,25):
			for x in range(-40,40):a.ground_pixels.append(Vector2(x,y));a.ground_pixel_types.append(4)
		var times:Array[float]=[]
		for i in 32:
			var source:=blood(false);source.position=Vector2(35+i*.25,0)
			source.ground_pixels.assign([Vector2.ZERO,Vector2(1,1),Vector2(2,-1)]);source.ground_pixel_types.assign([4,4,4])
			var start:=Time.get_ticks_usec();a.absorb_ground_effect(source);var duration:float=(Time.get_ticks_usec()-start)/1000.0
			if i>1:times.append(duration)
			source.free()
		times.sort();print("FRONTIER_BENCH ",JSON.stringify({"legacy_frontier":legacy,"median_ms":times[15],"p95_ms":times[28],"scope":"same single-pass merge; 4000-cell target, 30 sequential deposits"}));a.free()
	for legacy in [true,false,true]:
		var times:Array[float]=[]
		for i in 12:
			a=blood(legacy);a.office_pool_core=true
			var rng:=RandomNumberGenerator.new();rng.seed=i+915
			var start:=Time.get_ticks_usec();a.setup_death_pool(rng,1,1.7,.45,.35,2.05,Vector2(1,.7));times.append((Time.get_ticks_usec()-start)/1000.0)
			a.free()
		times.sort();print("DEPOSIT_BENCH ",JSON.stringify({"legacy_bounds":legacy,"median_ms":times[6],"p95_ms":times[11],"scope":"12 actual death-pool initializations, matching seed list"}))
	print("BLOOD_FRONTIER_DEPOSIT checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
