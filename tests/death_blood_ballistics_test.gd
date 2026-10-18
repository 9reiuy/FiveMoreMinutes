extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func make_blood(value: int, legacy := false) -> BlackBloodEffect:
	var blood := BlackBloodEffect.new()
	blood.office_impact_blot=true; blood.settle_seconds=.12
	blood.set_meta(&"test_legacy_death_spray",legacy)
	var rng := RandomNumberGenerator.new(); rng.seed=value
	blood.setup(Vector2.RIGHT,true,rng,1,1.7,1.45,1.45,1.55)
	blood.set_meta(&"rng_state",rng.state)
	return blood
func run() -> void:
	for value in range(20,28):
		var blood := make_blood(value)
		var legacy := make_blood(value,true)
		check(blood.get_meta(&"rng_state")==legacy.get_meta(&"rng_state"),"Cosmetic flight preserves caller RNG advance")
		var count := blood.airborne_pixels.size()
		check(count>0 and count<=blood.DEATH_SPRAY_MAX_DROPLETS,"One existing impact owns bounded death droplets")
		check(blood.ground_pixels.is_empty(),"No remote splats before a droplet touches down")
		check(blood.airborne_pixels.all(func(p: Dictionary) -> bool: return p.height>0),"Every death droplet starts above ground")
		blood._process(.12)
		check(not blood.settled and blood.landed_death_droplets>0 and not blood.airborne_pixels.is_empty(),"Low droplets land early while higher droplets survive the 120ms flatten timer")
		var landed_per_frame: Array[int]=[]
		var initial_landed := blood.landed_death_droplets
		var partially_landed := false
		for frame in 60:
			var before := blood.landed_death_droplets
			blood._process(1.0/60.0)
			if blood.landed_death_droplets>before: landed_per_frame.append(blood.landed_death_droplets-before)
			if blood.landed_death_droplets>0 and not blood.airborne_pixels.is_empty(): partially_landed=true
			check(blood.airborne_pixels.all(func(p: Dictionary) -> bool: return p.height>0),"Only positive-height particles remain airborne")
		check(partially_landed,"Different flight times deposit blood over multiple frames")
		check(landed_per_frame.size()>=8 and landed_per_frame.max()<count/3 and initial_landed<count/2,"Touchdown is distributed over many frames instead of a delayed collective drop")
		check(blood.settled and blood.landed_death_droplets==count,"Every unobstructed droplet lands once")
		check(blood.ground_pixel_types.all(func(t: int) -> bool: return t==BlackBloodEffect.StampType.PIXEL_CELL),"Landed splashes use fixed pixel cells")
		check(blood.ground_pixels.size()<=blood.MAX_POOL_CELLS,"Splash cells obey ground budget")
		blood.free(); legacy.free()
	var probe := BlackBloodEffect.new(); probe.ballistic_death_spray=true
	probe.airborne_pixels=[{"position":Vector2.ZERO,"velocity":Vector2(100,0),"height":10.0,"vertical":0.0,"size":2.0,"splash_radius":2.0,"splash_seed":47}]
	probe._process(.1)
	check(probe.ground_pixels.is_empty() and not probe.airborne_pixels.is_empty(),"Known ballistic probe has no early ground blood")
	probe._process(.2)
	check(probe.landed_death_droplets==1 and probe.airborne_pixels.is_empty(),"Large delta clips integration to physical touchdown")
	check(not probe.ground_pixels.is_empty() and probe.ground_pixels.all(func(p: Vector2) -> bool: return p.x>13 and p.x<24),"Splash deposits at traveled touchdown, not wound center or full-frame overshoot")
	probe.free()
	var wall := StaticBody2D.new(); wall.position=Vector2(12,0); wall.collision_layer=1
	var collision := CollisionShape2D.new(); var rectangle := RectangleShape2D.new(); rectangle.size=Vector2(2,100); collision.shape=rectangle
	wall.add_child(collision); root.add_child(wall)
	var blocked := make_blood(40); root.add_child(blocked); blocked.set_process(false)
	var starting_drops := blocked.airborne_pixels.size()
	await physics_frame; await physics_frame
	for frame in 60: blocked._process(1.0/60.0)
	check(blocked.ground_pixels.all(func(p: Vector2) -> bool: return p.x<11),"Actual wall blocks all ground splashes behind it")
	check(blocked.landed_death_droplets<starting_drops and blocked.settled,"Wall collisions end flight without replaying blocked splashes")
	blocked.free(); wall.free()
	print("DEATH_BLOOD_BALLISTICS_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
