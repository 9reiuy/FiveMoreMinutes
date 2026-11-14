extends SceneTree
var out:="user://lobby_side_lift"
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(count: int=4) -> void:
	for index in count:await process_frame
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"description":label});print("PASS " if ok else "FAIL ",label)
func sweep(room: Node,start: Vector2,finish: Vector2) -> bool:
	var query:=PhysicsShapeQueryParameters2D.new();var circle:=CircleShape2D.new();circle.radius=7
	query.shape=circle;query.transform=Transform2D(0,start*32)
	query.motion=(finish-start)*32;query.collision_mask=4
	var result: PackedFloat32Array=room.player.get_world_2d().direct_space_state.cast_motion(query)
	return result[0]>.999
func run() -> void:
	await process_frame
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var room: Node=load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate();root.add_child(room)
	await frames();await physics_frame
	var door: Node=room.elevator_floor_door
	check(door.get_script().resource_path.ends_with("lobby_elevator_door_3d.gd"),"Lobby uses its own station-style lift profile")
	check(not door.industrial_facade.visible and not door.frame_root.visible,"Freight trim is not visible on the lobby lift")
	check(door.left_door_mesh.has_node("NarrowWiredWindow") and door.right_door_mesh.has_node("NarrowWiredWindow"),"Both moving panels carry the reference narrow windows")
	check(door.status_text.text.contains("READY"),"Green status screen reflects the existing unlocked state")
	check(is_equal_approx(door.opening_width,2.0),"Reference lift has tall proportions and a two-metre clear opening")
	check(not sweep(room,Vector2(door.position.x,door.position.z)-door.get_inward_2d()*.8,Vector2(door.position.x,door.position.z)+door.get_inward_2d()*.8),"Closed reference door blocks the player")
	var left_start: float=door.left_door_mesh.position.x;var right_start: float=door.right_door_mesh.position.x
	var rail_offset: float=absf(door.left_door_mesh.position.z-door.right_door_mesh.position.z)
	check(rail_offset>.06,"Telescoping leaves use separate depth rails")
	var monotonic:=true;var previous:=Vector2(left_start,right_start)
	var opened: Array[bool]=[false]
	door.doors_opened.connect(func():opened[0]=true,CONNECT_ONE_SHOT)
	door.open_doors(.35)
	var deadline:=Time.get_ticks_msec()+4000
	while not opened[0] and Time.get_ticks_msec()<deadline:
		await process_frame
		var actual:=Vector2(door.left_door_mesh.position.x,door.right_door_mesh.position.x)
		monotonic=monotonic and actual.x>=previous.x-.0001 and actual.y>=previous.y-.0001
		previous=actual
	check(opened[0] and monotonic,"Both leaves travel right throughout the opening animation")
	check(previous.x>left_start+.5 and previous.y>right_start+.5,"Opening never splits the left leaf toward the left")
	check(is_equal_approx(previous.x,previous.y),"Both leaves telescope into the same right-hand pocket")
	check(door.doors_open and door.current_state==door.State.OPEN,"Original opened state and signal remain valid")
	await frames();await physics_frame
	check(sweep(room,Vector2(door.position.x,door.position.z)-door.get_inward_2d()*.8,Vector2(door.position.x,door.position.z)+door.get_inward_2d()*.8),"Open two-metre doorway is physically traversable")
	check(not sweep(room,Vector2(door.position.x,door.position.z)+Vector2(0,1.5)-door.get_inward_2d()*.8,Vector2(door.position.x,door.position.z)+Vector2(0,1.5)+door.get_inward_2d()*.8),"Stone pocket stays solid while the moving door collider is disabled")
	await door.close_doors(.1);await frames();await physics_frame
	check(is_equal_approx(door.left_door_mesh.position.x,left_start) and is_equal_approx(door.right_door_mesh.position.x,right_start),"Closing returns both leaves to the original seam")
	check(not sweep(room,Vector2(door.position.x,door.position.z)-door.get_inward_2d()*.8,Vector2(door.position.x,door.position.z)+door.get_inward_2d()*.8),"Closing restores the doorway collision")
	check(not door.doors_open and door.current_state==door.State.CLOSED,"Original closed signal and state remain valid")
	check(room.elevator_doors.size()==6,"Three west and three east lifts are present")
	for landing in room.elevator_doors:
		var centre:=Vector2(landing.position.x,landing.position.z);var inward: Vector2=landing.get_inward_2d()
		if landing.doors_open:await landing.close_doors(.02)
		await physics_frame;await frames(2)
		check(not sweep(room,centre-inward*.8,centre+inward*.8),landing.landing_identifier+" blocks entry while closed")
		await landing.open_doors(.02);await physics_frame;await frames(2)
		check(sweep(room,centre-inward*.8,centre+inward*.8),landing.landing_identifier+" opens a real traversable side-wall entrance")
		await landing.close_doors(.02);await physics_frame
	var failures:=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures,"left_start":left_start,"right_start":right_start,"open_centres":str(previous)},"\t"))
	room.queue_free();await frames();preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0);await frames(3);print("LOBBY_SIDE_LIFT checks=",checks.size()," failures=",failures);quit(1 if failures else 0)
