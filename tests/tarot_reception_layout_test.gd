extends SceneTree
const SCENE=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const FINAL_FLOOR=preload("res://scripts/dream/preview/sample_floor_texture_review.gd")
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
	check(room.floor_cells.size()==448,"Approved lobby footprint")
	check(get_nodes_in_group(&"reception_npc").size()==1,"Exactly one existing NPC")
	check(room.waitress_npc.global_position==Vector2(16,2.6)*32,"NPC at left service bay")
	check(room.door_root.get_child_count()==3,"Three elevator doors")
	check(room.elevator_floor_door.current_state==ElevatorFloorDoor3D.State.UNLOCKED,"Left elevator remains functional")
	for door in room.door_root.get_children():
		if door==room.elevator_floor_door: continue
		check(door.current_state==ElevatorFloorDoor3D.State.LOCKED and door.approach_trigger_2d==null,"Background elevator has no interaction trigger")
	var counts: Dictionary={}
	for item in room.props_root.get_children():
		var kind: String=String(item.get_meta(&"lobby_kind",""))
		counts[kind]=int(counts.get(kind,0))+1
	check(counts.get("sofa",0)==5,"Five lounge sofas")
	check(counts.get("coffee_table",0)==2,"Two lounge coffee tables")
	check(counts.get("plant",0)==12,"Twelve separate planters")
	var desks:=0
	for item in room.props_root.get_children():
		if item is ReceptionDesk3D: desks+=1
	check(desks==3,"Three service bays, no extra NPC")
	var variant: int=posmod((str(room.active_seed)+"reception").hash(),3)
	var expected: Image=FINAL_FLOOR.floor_image("reception",variant)
	for floor_mesh in room.floor_root.get_children():
		var material: ShaderMaterial=floor_mesh.mesh.surface_get_material(0)
		var atlas: Texture2D=material.get_shader_parameter("atlas")
		check(atlas!=null and atlas.get_image().get_data()==expected.get_data(),"Floor uses final approved reception marble pixels")
		check(material.get_shader_parameter("review_bevel")!=null,"Final marble bevel map is retained")
	for i in 5:
		var x:=9.7+float(i)*1.4
		check(sweep(room,Vector2(x,17.8),Vector2(x,13.8)),"Open gate lane %d is traversable"%i)
	for x in [11.5,12.5,13.5]:
		check(sweep(room,Vector2(x,14),Vector2(x,5.5)),"Central three-cell path is clear")
	check(sweep(room,Vector2(12.5,5.5),Vector2(16,5.5)),"Desk approach remains reachable")
	check(sweep(room,Vector2(12.5,5.5),Vector2(3.5,5.5)),"Elevator approach remains reachable")
	check(not sweep(room,Vector2(9,17.8),Vector2(9,13.8)),"Gate housing has real collision")
	check(not sweep(room,Vector2(4.8,8.8),Vector2(4.8,10)),"Coffee table retains collision")
	check(not sweep(room,Vector2(7.5,3),Vector2(7.5,-1)),"Closed background elevator blocks passage")
	room.player.global_position=Vector2(16,4.8)*32
	check(room.interaction_resolver.update_target()==room.waitress_npc,"Left-bay NPC interaction resolves from counter front")
	room.free(); await process_frame
	print("TAROT_RECEPTION_LAYOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
