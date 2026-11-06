extends SceneTree
## A full reconstruction is the independent reference for each local update.
const CUTAWAY=preload("res://scripts/dream/office_wall_cutaway.gd")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func ids(walls:Array)->Array[int]:
	var result:Array[int]=[]
	for wall in walls: result.append(wall.get_instance_id())
	result.sort(); return result
func same_mesh(a:Mesh,b:Mesh)->bool:
	if a.get_surface_count()!=b.get_surface_count(): return false
	for surface in a.get_surface_count():
		if a.surface_get_arrays(surface)!=b.surface_get_arrays(surface): return false
	return true
func run()->void:
	for kind in ["A1","B2","C3","V3"]:
		var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
		world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
		world.native_skeleton_type=kind
		world.set_meta(&"test_floor_reflections_disabled",true)
		root.add_child(world); await process_frame
		check(world.regenerate(90210),kind+" generates")
		world.process_mode=Node.PROCESS_MODE_DISABLED
		var cutaway:RefCounted=world.office_wall_cutaway
		var batches:Node=world.wall_root.get_node_or_null("WallShadowBatches")
		var candidates:Array[Dictionary]=[]
		for key in world.wall_edges:
			var wall:Node3D=world.SHARED_WALL_BREACH.wall_for_key(world,key)
			if wall==null: continue
			var count:=0
			for side in [-1.0,1.0]: count+=cutaway.endpoints[cutaway._endpoint_key(wall,side)].size()-1
			candidates.append({"key":key,"count":count})
		candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.count)>int(b.count))
		var configured:int=cutaway.configure_count
		var batch_id:int=batches.get_instance_id()
		var unrelated_changed:=false
		var shadow_ok:=true
		var bounded:=true
		for index in mini(3,candidates.size()):
			var key:String=candidates[index].key
			var wall:Node3D=world.SHARED_WALL_BREACH.wall_for_key(world,key)
			if wall==null: continue
			var affected:Dictionary={}
			for side in [-1.0,1.0]:
				for neighbor:Node3D in cutaway.endpoints[cutaway._endpoint_key(wall,side)]:
					if neighbor!=wall: affected[neighbor.get_instance_id()]=neighbor
			var before:Dictionary={}
			for previous in cutaway.walls:
				if previous!=wall and not affected.has(previous.get_instance_id()):
					before[previous.get_instance_id()]=[previous.office_full_mesh,previous.office_cut_mesh]
			check(world._commit_dash_wall_breaches([key],world.get_current_floor_token(),Vector2.RIGHT)==1,kind+" junction destruction commits")
			bounded=bounded and int(cutaway.last_local_update_count)<=6
			for neighbor:Node3D in affected.values():
				var neighbor_key:=String(neighbor.get_meta(&"edge_key",""))
				shadow_ok=shadow_ok and not batches.edge_instances.has(neighbor_key) and neighbor.shadow_mesh.visible==neighbor.wall_shadow_visible
			for previous in cutaway.walls:
				if before.has(previous.get_instance_id()):
					var meshes:Array=before[previous.get_instance_id()]
					unrelated_changed=unrelated_changed or previous.office_full_mesh!=meshes[0] or previous.office_cut_mesh!=meshes[1]
		check(int(cutaway.configure_count)==configured and batches.get_instance_id()==batch_id,kind+" keeps the floor configuration and existing shadow batches")
		check(bounded and not unrelated_changed,kind+" updates at most the endpoint neighbors and retains unrelated meshes")
		check(shadow_ok,kind+" retires changed copied casters and restores their original shadow meshes")
		var local_records:Dictionary=cutaway.records.duplicate()
		var local_cut:Dictionary={}
		for wall in cutaway.walls: local_cut[wall.get_instance_id()]=wall.office_cut_mesh
		var reference:RefCounted=CUTAWAY.new()
		reference.configure(world)
		var matching:bool=local_records.size()==reference.records.size()
		for id in local_records:
			var a:Dictionary=local_records[id]; var b:Dictionary=reference.records[id]
			matching=matching and a.miters==b.miters and a.last_posts_mask==b.last_posts_mask and same_mesh(a.full,b.full)
			for property in ["aligned_left","aligned_right","perp_left","perp_right"]: matching=matching and ids(a[property])==ids(b[property])
			matching=matching and same_mesh(local_cut[id],b.cut_variants[int(b.last_posts_mask)])
		check(matching,kind+" local miters, endpoints, cap profiles and full shadow geometry match a fresh floor reconstruction")
		world.free(); await process_frame
	print("SHARED_WALL_LOCAL_CUTAWAY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
