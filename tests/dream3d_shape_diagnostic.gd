extends SceneTree
func _init() -> void:
	var g = preload("res://scripts/dream/dream_3d_random_dungeon.gd").new()
	g.generate_on_ready=false
	for seed in range(41001,41006):
		g._rng.seed=seed
		g._reset_layout_data()
		g._generate_building_layout()
		var report: Dictionary = g._validate_layout()
		for key in report:
			if report[key] is bool and not report[key]: print("FALSE ",key)
		for room in g.rooms:
			if room.is_large: print("ROOM ",room.id," ",room.shape," ",room.void_rect)
		for key in g.edge_states:
			if g.edge_states[key]==&"WALL" and g.door_edges.has(key): print("WALLDOOR ",key)
		print("SEED ",seed)
	g.free()
	quit()
