extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func compare(world: Node3D,start: Vector2i,finish: Vector2i) -> void:
	world.set_meta(&"test_legacy_goal_search",true)
	var old: Array[Vector2i]=world.find_floor_path(start,finish,false)
	world.set_meta(&"test_legacy_goal_search",false)
	var current: Array[Vector2i]=world.find_floor_path(start,finish,false)
	check(old==current,"shared frontier exact ordered path")
	if not current.is_empty():
		current.clear()
		check(world.find_floor_path(start,finish,false)==old,"caller mutation cannot alter cached distances")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scripts/dream/dream_3d_random_dungeon.gd").new()
	for y in 30:
		for x in 40: world.floor_cells[Vector2i(x,y)] = true
	world.floor_cells[Vector2i(100,100)] = true
	for y in 30:
		if y==5: continue
		var edge: Dictionary=world._edge_from_cell_direction(Vector2i(19,y),Vector2i.RIGHT)
		world.wall_edges[world._edge_key(edge)] = edge
	world._floor_path_cache_enabled=true
	var starts: Array[Vector2i]=[Vector2i(2,2),Vector2i(5,25),Vector2i(12,14),Vector2i(16,24),Vector2i(18,27),Vector2i(10,18),Vector2i(9,29),Vector2i(15,9)]
	for finish in [Vector2i(35,20),Vector2i(100,100),Vector2i(1,1),Vector2i(30,25),Vector2i(38,29),Vector2i(35,20)]:
		for start in starts: compare(world,start,finish)
		check(world._floor_path_goal_searches.size()<=4,"bounded destination retention")
	var edge: Dictionary=world._edge_from_cell_direction(Vector2i(19,5),Vector2i.RIGHT)
	world.wall_edges[world._edge_key(edge)] = edge
	for start in starts: compare(world,start,Vector2i(35,20))
	check(world.find_floor_path(starts[0],Vector2i(35,20)).is_empty(),"newly closed edge invalidates reachable frontier")
	world.wall_edges.erase(world._edge_key(edge))
	for start in starts: compare(world,start,Vector2i(35,20))
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_goal_search",legacy)
		var times: Array[int]=[]
		for iteration in 34:
			world._floor_path_goal_searches.clear(); world._floor_path_goal_order.clear()
			var started:=Time.get_ticks_usec()
			for start in starts: world.find_floor_path(start,Vector2i(35,20))
			if iteration>=2: times.append(Time.get_ticks_usec()-started)
		times.sort()
		print("SHARED_GOAL_EIGHT_COLD_QUERIES legacy=",legacy," median_us=",times[16]," p95_us=",times[30])
	world.free()
	world=load("res://scripts/dream/office_skeleton_world_base.gd").new()
	var rng:=RandomNumberGenerator.new(); rng.seed=81849
	for kind in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=kind
		for floor_seed in [41001,41002]:
			check(world.generate_layout_only(floor_seed),"formal skeleton generated")
			check(world._floor_path_goal_searches.is_empty(),"new floor forgets all previous goals")
			world._floor_path_cache_enabled=true
			var cells: Array=world.floor_cells.keys()
			for target_index in 8:
				var finish: Vector2i=cells[rng.randi_range(0,cells.size()-1)]
				for query_index in 32:
					var start: Vector2i=cells[rng.randi_range(0,cells.size()-1)]
					compare(world,start,finish)
	world.free()
	print("SHARED_GOAL checks=",checks," failures=",failures)
	quit(1 if failures else 0)
