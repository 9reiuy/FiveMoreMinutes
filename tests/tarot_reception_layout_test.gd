extends SceneTree
const SCENE=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func sweep(room: Node, start: Vector2, finish: Vector2) -> bool:
	var query:=PhysicsShapeQueryParameters2D.new()
	var shape:=CircleShape2D.new(); shape.radius=8
	query.shape=shape; query.transform=Transform2D(0,start*32)
	query.motion=(finish-start)*32; query.collision_mask=4
	var result: PackedFloat32Array=room.player.get_world_2d().direct_space_state.cast_motion(query)
	return result[0]>=.9999
func run() -> void:
	var room=SCENE.instantiate(); root.add_child(room)
	await physics_frame; await physics_frame
	check(room.floor_cells.size()==121,"Compact 14 by 8 hall with 3 by 3 right vestibule")
	check(get_nodes_in_group(&"reception_npc").size()==1,"Exactly one existing NPC")
	check(room.waitress_npc.global_position==room.WAITRESS_NPC_POS_2D,"NPC at the middle counter")
	check(room.door_root.get_child_count()==1,"Only one elevator door")
	check(room.elevator_floor_door.current_state==ElevatorFloorDoor3D.State.UNLOCKED,"Left elevator remains functional")
	var counts: Dictionary={}
	for item in room.props_root.get_children():
		var kind: String=String(item.get_meta(&"lobby_kind",""))
		counts[kind]=int(counts.get(kind,0))+1
	check(counts.get("sofa",0)==1 and counts.get("coffee_table",0)==1,"One grouped waiting area")
	check(counts.get("plant",0)==2,"Two corner planters")
	var desks:=0
	for item in room.props_root.get_children():
		if item is ReceptionDesk3D: desks+=1
	check(desks==1,"One service counter")
	for floor_mesh in room.floor_root.get_children():
		if not floor_mesh is MeshInstance3D or floor_mesh.mesh == null: continue
		check(floor_mesh.material_override.shader.resource_path=="res://shaders/dream3d/reception_stone.gdshader","Lobby uses its own dark stone finish")
	check(sweep(room,Vector2(16,4.5),Vector2(8,4.5)),"Right entrance reaches the front desk")
	check(sweep(room,Vector2(8,4.5),Vector2(1.5,4.5)),"Counter-to-left-elevator aisle is clear")
	check(sweep(room,Vector2(1.5,4.5),Vector2(1.5,1.3)),"Lift threshold is reachable")
	check(not sweep(room,Vector2(8,4.5),Vector2(8,2.8)),"Counter has solid collision")
	check(not sweep(room,Vector2(10.7,5),Vector2(10.7,5.9)),"Waiting table has solid collision")
	check(not sweep(room,Vector2(5,1),Vector2(5,-1)),"North wall outside elevator remains closed")
	room.player.global_position=Vector2(8,4.4)*32
	check(room.interaction_resolver.update_target()==room.waitress_npc,"NPC resolves from counter front")
	room.free(); await process_frame
	print("TAROT_RECEPTION_LAYOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
