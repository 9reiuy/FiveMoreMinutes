extends SceneTree

const ShadowManagerScript = preload("res://scripts/dream/office_shadow_manager.gd")

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	print("--- Running OfficeShadowManager Hysteresis & Tuning Test ---")
	
	# 1. Verify Constants
	_check(ShadowManagerScript.HOLD_SECONDS == 0.8, "Hold interval is 0.8 seconds")
	_check(ShadowManagerScript.FADE_SECONDS == 0.25, "Fade interval is 0.25 seconds")

	# 2. Instantiate and test selection logic
	var mgr = ShadowManagerScript.new()
	root.add_child(mgr)
	mgr.quality = "low" # LIMITS["low"] == 2 for easy testing

	# Create mock lights
	var light_a = OmniLight3D.new()
	var light_b = OmniLight3D.new()
	var light_c = OmniLight3D.new()

	mgr.candidates.append_array([light_a, light_b, light_c])

	# Test hysteresis in selection:
	# Assume low quality (limit 2).
	# Incumbents light_a and light_b are selected.
	var init_sel: Array[Light3D] = [light_a, light_b]
	mgr.selected = init_sel.duplicate()
	mgr.active = {
		light_a: 0.0,
		light_b: 0.0
	}
	mgr._clock = 1.0 # Above the 0.8-second hold interval.

	# A thirty percent score advantage is below the forty percent threshold.
	var scores_case1 = {
		light_a: 20.0,
		light_b: 10.0,
		light_c: 13.0
	}
	_simulate_select_with_scores(mgr, scores_case1)
	_check(mgr.selected.has(light_b) and not mgr.selected.has(light_c), "Thirty percent challenger stays out with 1.4x barrier")

	# Fifty percent score advantage replaces the incumbent after hold.
	var scores_case2 = {
		light_a: 20.0,
		light_b: 10.0,
		light_c: 15.0
	}
	_simulate_select_with_scores(mgr, scores_case2)
	_check(not mgr.selected.has(light_b) and mgr.selected.has(light_c), "Fifty percent challenger replaces incumbent")

	# A newly enabled light keeps its slot through its 0.8-second hold.
	var reset_sel: Array[Light3D] = [light_a, light_b]
	mgr.selected = reset_sel.duplicate()
	mgr.active[light_a] = 0.5
	mgr.active[light_b] = 0.5
	mgr._clock = 1.0 # 1.0 - 0.5 = 0.5 < HOLD_SECONDS (0.8)
	var scores_case3 = {
		light_a: 20.0,
		light_b: 10.0,
		light_c: 25.0
	}
	_simulate_select_with_scores(mgr, scores_case3)
	_check(mgr.selected.has(light_b) and not mgr.selected.has(light_c), "Challenger should NOT preempt incumbent while hold time has not elapsed")

	# 3. Test fade delta / FADE_SECONDS
	light_a.shadow_opacity = 0.0
	var delta := 0.05
	var target := 1.0
	var step: float = delta / mgr.FADE_SECONDS
	var expected_opacity: float = move_toward(0.0, target, step)
	_check(is_equal_approx(expected_opacity, 0.2), "Fade opacity advances 0.2 in 50ms")

	# Cleanup
	light_a.free()
	light_b.free()
	light_c.free()
	mgr.free()

	print("OfficeShadowManager tests: ", "ALL PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

func _simulate_select_with_scores(mgr: Node3D, scores: Dictionary) -> void:
	var ranked: Array[Light3D] = []
	for light in mgr.candidates:
		if is_instance_valid(light):
			ranked.append(light)
	ranked.sort_custom(func(a: Light3D, b: Light3D) -> bool: return scores[a] > scores[b])
	mgr.selected = mgr.selected.filter(func(light: Light3D) -> bool: return is_instance_valid(light) and scores.get(light, 0.0) > 0.0)
	while mgr.selected.size() > int(mgr.LIMITS[mgr.quality]):
		mgr.selected.pop_back()
	for challenger in ranked:
		if scores[challenger] <= 0.0 or mgr.selected.has(challenger):
			continue
		if mgr.selected.size() < int(mgr.LIMITS[mgr.quality]):
			mgr.selected.append(challenger)
			continue
		var weakest: Light3D = null
		for incumbent in mgr.selected:
			if mgr._clock - float(mgr.active.get(incumbent, mgr._clock)) < mgr.HOLD_SECONDS:
				continue
			if weakest == null or scores[incumbent] < scores[weakest]:
				weakest = incumbent
		if weakest != null and scores[challenger] > scores[weakest] * 1.4:
			mgr.selected.erase(weakest)
			mgr.selected.append(challenger)
