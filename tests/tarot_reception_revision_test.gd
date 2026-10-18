extends SceneTree
const SCENE=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const DOOR=preload("res://scripts/dream/elevator_floor_door_3d.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func bounds(node: Node3D) -> AABB:
	var result:=AABB()
	var first:=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		var box: AABB=mesh.global_transform*mesh.get_aabb()
		result=box if first else result.merge(box); first=false
	return result
func run() -> void:
	var room=SCENE.instantiate(); root.add_child(room)
	await process_frame; await process_frame
	var environment: Environment=room.get_node(^"Lighting/WorldEnvironment").environment
	check(is_equal_approx(environment.ambient_light_energy,.38),"Night ambient matches formal floor")
	check(environment.ambient_light_color==Color(.4,.44,.52,1),"Night ambient hue matches formal floor")
	check(is_equal_approx(room.key_light.light_energy,.025) and not room.key_light.shadow_enabled,"Formal floor gentle key fill replaces daytime lighting")
	for i in 3:
		var desk: Node3D=room.props_root.get_node("RearWorkstation%d"%i)
		var cabinet: Node3D=room.props_root.get_node("StaffStorage%d"%i)
		check(is_equal_approx(desk.rotation.y,PI),"Desk worker side faces south employee position")
		check(not bounds(desk).intersects(bounds(cabinet)),"Actual desk and cabinet meshes do not overlap")
		var collider: StaticBody2D=room.collision_root.get_node("RearWorkstation%dCollider"%i)
		check(collider.get_child(0).shape.size==Vector2(2.2,1.1)*32,"Desk collision matches true 2.2x1.1 footprint")
		if i>0:
			var chair: Node3D=room.props_root.get_node("EmptyStaffChair%d"%i)
			check(not bounds(desk).intersects(bounds(chair)),"Desk and employee chair have real clearance")
	for width in [2.0,3.0,4.0]:
		var door=DOOR.new(); root.add_child(door)
		door.configure_opening(width,.5)
		check(door.industrial_facade!=null,"Shared industrial facade exists")
		check(door.left_door_mesh.has_node(^"IndustrialLeafPanels") and door.right_door_mesh.has_node(^"IndustrialLeafPanels"),"Door details follow the animated leaf nodes")
		check(is_equal_approx((door.left_door_mesh.mesh as BoxMesh).size.x,width*.5+.02),"Existing variable opening leaf size is preserved")
		check(door.indicator_root.position.z>.32 and door.card_reader_root.position.z>.32,"State display and call panel are in front of industrial trim")
		var original_y: float=door.left_door_mesh.position.y
		await door.open_doors(.01)
		check(door.doors_open and absf(door.left_door_mesh.position.x)>width*.5,"Existing open animation retracts decorated door")
		check(door.left_door_mesh.position.y==original_y,"Open animation preserves leaf vertical alignment")
		await door.close_doors(.01)
		check(not door.doors_open and is_equal_approx(absf(door.left_door_mesh.position.x),width*.25),"Existing close animation restores leaf seam")
		door.queue_free()
		await process_frame
	room.free(); await process_frame
	print("TAROT_RECEPTION_REVISION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
