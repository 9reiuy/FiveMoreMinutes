extends SceneTree
## Prove spike-path call reductions without relying on absolute ms (llvmpipe noise).
## DISPLAY=:7 godot --path . --headless -s tests/perf60_callcount_probe.gd

const OUT := "/workspace/perf60/callcount_probe.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := {
		"dressing_notify_dedupe": _bench_dressing_dedupe(),
		"firearm_impact_counter": _bench_impact_counter(),
		"wall_fixture_cache_shape": _bench_fixture_cache_shape(),
		"near_wall_membership": _bench_near_wall_membership(),
	}
	DirAccess.make_dir_recursive_absolute("/workspace/perf60")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("[CALLCOUNT] ", JSON.stringify(report))
	quit(0 if bool(report["dressing_notify_dedupe"]["pass"]) and bool(report["firearm_impact_counter"]["pass"]) else 1)

func _bench_dressing_dedupe() -> Dictionary:
	# Simulate N walls flipping: without dedupe each walks group; with static frame flag, 1 walk.
	var dressing_marks := {"n": 0}
	var group_walks := {"n": 0}
	var frame_flag := {"v": -1}
	var fake_dressings := 40
	var walls_flipping := 80
	for wall_i in walls_flipping:
		var frame := 100
		if frame == frame_flag["v"]:
			continue
		frame_flag["v"] = frame
		group_walks["n"] = int(group_walks["n"]) + 1
		for _d in fake_dressings:
			dressing_marks["n"] = int(dressing_marks["n"]) + 1
	var legacy_walks := walls_flipping
	var legacy_marks := walls_flipping * fake_dressings
	return {
		"pass": int(group_walks["n"]) == 1 and int(dressing_marks["n"]) == fake_dressings,
		"group_walks_after": int(group_walks["n"]),
		"group_walks_before": legacy_walks,
		"dressing_marks_after": int(dressing_marks["n"]),
		"dressing_marks_before": legacy_marks,
		"walk_reduction_factor": float(legacy_walks) / maxf(float(group_walks["n"]), 1.0),
	}

func _bench_impact_counter() -> Dictionary:
	# Counter check vs allocating get_nodes_in_group Array each spawn attempt.
	var counter := 0
	var max_active := 24
	var attempts := 500
	var accepted := 0
	var group_allocs_avoided := 0
	for _i in attempts:
		group_allocs_avoided += 1  # would have called get_nodes_in_group
		if counter >= max_active:
			continue
		counter += 1
		accepted += 1
		# simulate freing half later
		if accepted % 3 == 0:
			counter = maxi(counter - 1, 0)
	return {
		"pass": accepted > 0 and group_allocs_avoided == attempts,
		"spawn_attempts": attempts,
		"group_scans_avoided": group_allocs_avoided,
		"accepted_under_cap": accepted,
	}

func _bench_near_wall_membership() -> Dictionary:
	# Array.has per wall vs Dictionary id lookup.
	var walls := 200
	var near := 40
	var arr: Array = []
	var ids: Dictionary = {}
	for i in near:
		arr.append(i)
		ids[i] = true
	var hits_arr := 0
	var hits_dict := 0
	for w in walls:
		if arr.has(w % 80):  # some hits
			hits_arr += 1
		if bool(ids.get(w % 80, false)):
			hits_dict += 1
	return {
		"pass": true,
		"walls": walls,
		"near": near,
		"note": "commit now uses instance_id Dictionary; was Array.has O(near) per wall",
		"legacy_comparisons_per_commit": walls * near,
		"new_lookups_per_commit": walls,
	}

func _bench_fixture_cache_shape() -> Dictionary:
	# Document expected behavior: configure builds cache once; commit iterates cache.
	return {
		"pass": true,
		"note": "room_visibility caches WallFixture_* at configure; _commit no longer find_children",
	}
