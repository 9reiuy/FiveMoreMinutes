extends SceneTree
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func make_blood(legacy:bool)->BlackBloodEffect:
	var blood:=BlackBloodEffect.new();root.add_child(blood);blood.set_process(false)
	blood.set_meta(&"test_legacy_landing_occupied",legacy)
	blood.ballistic_death_spray=true
	for y in range(-30,10):
		for x in range(-40,40):blood.ground_pixels.append(Vector2(x,y));blood.ground_pixel_types.append(BlackBloodEffect.StampType.PIXEL_CELL)
	return blood
func run()->void:
	await physics_frame
	var samples:Array=[]
	for trial in 10:
		var results:Array=[];var times:Array=[]
		for legacy in [true,false,true]:
			var blood:=make_blood(legacy)
			var cache:=blood._new_blood_cell_query_cache()
			var started:=Time.get_ticks_usec()
			for i in 72:
				blood._land_ballistic_droplet({"position":Vector2((i%12)*4-20,12+(i/12)*4),"velocity":Vector2(30,20),"splash_radius":2.0,"splash_seed":trial*1000+i},cache)
			times.append((Time.get_ticks_usec()-started)/1000.0)
			results.append([blood.ground_pixels.duplicate(),blood.ground_pixel_types.duplicate(),blood.landed_death_droplets])
			blood.free()
		expect(var_to_bytes(results[0])==var_to_bytes(results[1]) and var_to_bytes(results[1])==var_to_bytes(results[2]),"dense same-step touchdowns preserve exact ordered pixels/stamps/count")
		samples.append(times)
	for frame_count in [1,2,5]:
		var pair:Array=[]
		for legacy in [true,false]:
			var blood:=make_blood(legacy)
			blood.ground_pixels.clear();blood.ground_pixel_types.clear()
			for i in 24:
				blood.airborne_pixels.append({"position":Vector2(i%6*3,i/6*3),"velocity":Vector2(20,10),"height":.1+i*.02,"vertical":-5.0,"size":2.0,"splash_radius":2.0,"splash_seed":i})
			for tick in frame_count:blood._process(.05)
			pair.append([blood.ground_pixels.duplicate(),blood.ground_pixel_types.duplicate(),blood.airborne_pixels.duplicate(true),blood.settled,blood.content_version,blood.landed_death_droplets])
			blood.free()
		expect(var_to_bytes(pair[0])==var_to_bytes(pair[1]),"full active lifecycle/cross-frame cache lifetime matches reference")
	print("BLOOD_LANDING_BENCH ",JSON.stringify({"scope":"72 touchdowns + 3200 existing cells; A/B/A CPU, not whole-game FPS","times_ms":samples}))
	print("BLOOD_LANDING checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
