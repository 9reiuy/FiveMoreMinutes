extends SceneTree
class ClippedBlood extends BlackBloodEffect:
	func _is_ground_world_position_valid(point: Vector2) -> bool:
		return point.x < 12.0 and point.y > -18.0
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func components(points: Array[Vector2]) -> int:
	var remaining := {}
	for point in points: remaining[Vector2i(point)] = true
	var result := 0
	while not remaining.is_empty():
		result += 1
		var frontier: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(frontier[0])
		while not frontier.is_empty():
			var point: Vector2i = frontier.pop_back()
			for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
				var neighbor: Vector2i = point + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor); frontier.append(neighbor)
	return result
func pool(value: int, legacy := false, amount := 1.7) -> BlackBloodEffect:
	var blood := BlackBloodEffect.new()
	blood.office_pool_core = true
	blood.set_meta(&"test_legacy_otxo_morphology",legacy)
	var rng := RandomNumberGenerator.new(); rng.seed = value
	blood.setup_death_pool(rng,4,amount,0.55,1.05,2.05)
	blood.set_meta(&"rng_after_setup",rng.state)
	return blood
func run() -> void:
	var timings: Array = [[],[]]
	for value in range(310,326):
		var original_rng_state: int
		for mode in 2:
			var started := Time.get_ticks_usec()
			var blood := pool(value,mode==0)
			timings[mode].append(Time.get_ticks_usec()-started)
			var final_cells := blood._pool_growth_cells.duplicate()
			if mode==0: original_rng_state=blood.get_meta(&"rng_after_setup")
			else: check(original_rng_state==blood.get_meta(&"rng_after_setup"),"cosmetic islands preserve caller RNG state")
			check(final_cells.size() <= blood.MAX_POOL_CELLS,"bounded pool budget")
			check(final_cells.all(func(p: Vector2) -> bool: return p==p.round()),"fixed 1px cells")
			var unique := {}
			for point in final_cells: unique[point] = true
			check(unique.size()==final_cells.size(),"no duplicate alpha accumulation")
			if mode==1:
				check(final_cells.size()>blood.ground_pixels.size(),"Local wound seepage has independent late deposits")
				check(not blood.ground_pixels.is_empty(),"Wound core starts opaque at birth")
				var initial_reach := 0.0
				var final_reach := 0.0
				for point in blood.ground_pixels: initial_reach=maxf(initial_reach,point.length())
				for point in final_cells: final_reach=maxf(final_reach,point.length())
				check(final_reach<40.0 and initial_reach>final_reach*.6,"Wound pool stays local; distant splashes require airborne touchdown")
				var previous := blood.ground_pixels.duplicate()
				for step in 8:
					blood._process(0.07)
					check(previous.all(func(p: Vector2) -> bool: return blood.ground_pixels.has(p)),"growth preserves existing pixels")
					check(is_equal_approx(blood.ground_visual_scale,1.0) and is_equal_approx(blood.self_modulate.a,1.0),"deposits never enlarge or fade in")
					if step==1: check(blood.ground_pixels.size() >= final_cells.size()*0.90,"burst supplies most blood before 140ms; late seepage stays small")
					previous=blood.ground_pixels.duplicate()
				check(not blood.pool_growth_active and blood.ground_pixels.size()==final_cells.size(),"growth finishes and freezes")
			blood.free()
	for amount in [0.35,1.7,3.0]:
		var blood := pool(512,false,amount)
		check(blood._pool_growth_cells.size()>100,"amount retains visible wound core")
		blood.free()
	var clipped := ClippedBlood.new(); clipped.office_pool_core=true
	var rng := RandomNumberGenerator.new(); rng.seed=910
	clipped.setup_death_pool(rng,4,1.7,0.0,1.0,2.05)
	check(clipped.ground_pixels.all(func(p: Vector2) -> bool: return p.x<12 and p.y > -18),"all satellites and core respect surface clipping")
	clipped.free()
	for mode in 2:
		timings[mode].sort()
		print("OTXO_POOL_SETUP_MICROBENCH ",JSON.stringify({"legacy":mode==0,"median_us":timings[mode][8],"p95_us":timings[mode][15],"samples":16,"scope":"off-tree shape generation, no rendering or real-world queries"}))
	print("OTXO_BLOOD_MORPHOLOGY_CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures==0 else 1)
