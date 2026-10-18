extends SceneTree
class LockedWorld extends "res://scripts/dream/dream_3d_random_dungeon.gd":
	func _can_cross_floor_edge(_from: Vector2i,_to: Vector2i,ignore_lock: bool=true) -> bool:
		return ignore_lock
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scripts/dream/dream_3d_random_dungeon.gd").new()
	for y in 36:
		for x in 44:
			world.floor_cells[Vector2i(x,y)] = true
	for x in range(3,42):
		if x%11==0: continue
		var edge: Dictionary=world._edge_from_cell_direction(Vector2i(x,15),Vector2i.DOWN)
		world.wall_edges[world._edge_key(edge)] = edge
	world._floor_path_cache_enabled = true
	world._current_floor_path_adjacency()
	var rng:=RandomNumberGenerator.new(); rng.seed=7219
	for trial in 240:
		var start:=Vector2i(rng.randi_range(-1,44),rng.randi_range(-1,36))
		var finish:=Vector2i(rng.randi_range(-1,44),rng.randi_range(-1,36))
		if trial%19==0:
			var old_cell:=Vector2i(1+trial%39,1)
			world.floor_cells.erase(old_cell); world.floor_cells[Vector2i(1+trial%39,37)] = true
		if trial%23==0 and not world.wall_edges.is_empty():
			world.wall_edges.erase(world.wall_edges.keys()[0])
			var edge: Dictionary=world._edge_from_cell_direction(Vector2i(1+trial%39,20),Vector2i.DOWN)
			world.wall_edges[world._edge_key(edge)] = edge
		world.set_meta(&"test_legacy_floor_path",true)
		var old: Array[Vector2i]=world.find_floor_path(start,finish,trial%2==0)
		world.set_meta(&"test_legacy_floor_path",false)
		var current: Array[Vector2i]=world.find_floor_path(start,finish,trial%2==0)
		check(old==current,"exact BFS tie ordering and topology replacement %d"%trial)
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_floor_path",legacy)
		var times: Array[int]=[]
		for iteration in 32:
			var started:=Time.get_ticks_usec()
			var path: Array[Vector2i]=world.find_floor_path(Vector2i(2,2),Vector2i(41,33),false)
			if iteration>=2: times.append(Time.get_ticks_usec()-started)
			if iteration==2: check(not path.is_empty(),"timed query actually crosses the floor")
		times.sort()
		print("FLOOR_PATH_ADJACENCY legacy=",legacy," median_us=",times[15]," p95_us=",times[28])
	world.free()
	# Formal generator topology, not a rectangular synthetic arena.
	world = load("res://scripts/dream/office_skeleton_world_base.gd").new()
	for floor_seed in [41001,42001,43001,44001,45001]:
		check(world.generate_layout_only(floor_seed),"formal layout %d"%floor_seed)
		check(world._floor_path_adjacency.is_empty(),"generation resets previous graph")
		world._floor_path_cache_enabled = true
		world._current_floor_path_adjacency()
		check(world._floor_path_adjacency.keys()==world.floor_cells.keys(),"graph belongs to current floor")
		var cells: Array=world.floor_cells.keys()
		for trial in 80:
			var start: Vector2i=cells[rng.randi_range(0,cells.size()-1)]
			var finish: Vector2i=cells[rng.randi_range(0,cells.size()-1)]
			world.set_meta(&"test_legacy_floor_path",true)
			var old: Array[Vector2i]=world.find_floor_path(start,finish,trial%2==0)
			world.set_meta(&"test_legacy_floor_path",false)
			check(old==world.find_floor_path(start,finish,trial%2==0),"formal floor ordered path parity")
		# Glass destruction removes wall membership immediately, without waiting
		# for a timer or a floor reset; use a real generated wall segment.
		for key in world.wall_edges.keys():
			var edge: Dictionary=world.wall_edges[key]
			var a:=Vector2i(int(edge.x),int(edge.y))
			var b:=a+(Vector2i.LEFT if String(edge.axis)=="V" else Vector2i.UP)
			if not world.floor_cells.has(a) or not world.floor_cells.has(b): continue
			world.wall_edges.erase(key)
			world.set_meta(&"test_legacy_floor_path",true)
			var old: Array[Vector2i]=world.find_floor_path(a,b)
			world.set_meta(&"test_legacy_floor_path",false)
			check(old==world.find_floor_path(a,b),"removed generated wall refreshes graph immediately")
			break
	world.free()
	var locked:=LockedWorld.new()
	locked.floor_cells={Vector2i.ZERO:true,Vector2i.RIGHT:true}
	locked._floor_path_cache_enabled=true
	check(locked._current_floor_path_adjacency().is_empty(),"unknown derivative keeps dynamic edge policy")
	check(locked.find_floor_path(Vector2i.ZERO,Vector2i.RIGHT,false).is_empty(),"dynamic locked edge stays blocked")
	check(locked.find_floor_path(Vector2i.ZERO,Vector2i.RIGHT,true).size()==2,"ignore lock parameter remains authoritative")
	locked.free()
	print("FLOOR_PATH_ADJACENCY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
