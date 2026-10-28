extends SceneTree
const FIXTURE=preload("res://tests/fire_extinguisher_test.gd")
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func expected_links(world:Node)->Dictionary:
	var result:Dictionary={}
	for cell:Vector2i in world.floor_cells:
		var links:Array=[]
		for direction:Vector2i in SYSTEM.DIRECTIONS:
			var to:=cell+direction
			if not world.floor_cells.has(to) or world.pit_cells.has(to):continue
			var key:String=world._edge_key(world._edge_from_cell_direction(cell,direction))
			if not world.wall_edges.has(key) and not world.glass_wall_edges.has(key) and not world.window_wall_edges.has(key):links.append([to,key])
		result[cell]=links
	return result
func run()->void:
	var world:=FIXTURE.World.new();root.add_child(world)
	for y in 12:
		for x in 20:
			world.floor_cells[Vector2i(x,y)]="room";world.room_cells[Vector2i(x,y)]=0
	world.wall_edges["V:8:6"]={}
	var gas:=SYSTEM.new();world.floor_root.add_child(gas);gas.world=world
	gas.cache_links()
	expect(gas.static_links==expected_links(world),"initial graph matches independent full-floor traversal")
	var updated:int=gas.link_cell_updates
	world.wall_edges.erase("V:8:6");gas.cache_links()
	expect(gas.static_links==expected_links(world),"broken wall graph matches full traversal")
	expect(gas.link_cell_updates-updated==2 and gas.link_full_rebuilds==1,"single break only updates its two endpoints")
	world.glass_wall_edges["V:8:6"]={};gas.cache_links()
	world.glass_wall_edges.erase("V:8:6");world.glass_wall_edges["H:5:5"]={}
	gas.invalidate_topology();gas.cache_links()
	expect(gas.static_links==expected_links(world),"same-count explicit invalidation remains correct")
	world.pit_cells[Vector2i(6,6)]=true;gas.cache_links()
	expect(gas.static_links==expected_links(world),"pit insertion updates inbound adjacency")
	world.pit_cells.clear();gas.cache_links()
	expect(gas.static_links==expected_links(world),"pit removal restores adjacency")
	world.floor_cells.erase(Vector2i(19,11));world.floor_cells[Vector2i(20,11)]="room"
	gas.invalidate_topology(true);gas.cache_links()
	expect(gas.static_links==expected_links(world) and gas.link_full_rebuilds==2,"same-count floor-layout replacement uses explicit full rebuild")
	world.free();await process_frame
	print("EXTINGUISHER_TOPOLOGY checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
