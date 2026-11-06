extends "res://tests/shared_wall_dash_camera_test.gd"
var clips: Dictionary={}

func position_player(point: Vector2) -> void:
	var player: Node=world.player
	player.cancel_dash(); player.set_physics_process(false)
	player.global_position=point; player.velocity=Vector2.ZERO
	var room: int=world._room_id_at_position(point)
	world.set_current_room_id(room); world.activate_room(room)
	world._update_camera_and_actor_projection(0.0)
	await frames(15); freeze_enemies()
	player.movement_enabled=true; player.set_attacking_enabled(true)
	player.dash_charges=1; player.dash_cooldown_left=0.0; player.set_physics_process(true)

func space_clip(direction: Vector2,label: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(OUT+"/"+label)
	var player: Node=world.player
	# A slow rendered frame may contain every physics tick of the short dash.
	# Observe the authoritative signal as well as rendered-frame snapshots.
	var observed:={"active":false}
	var on_dash:=func(_remaining:float,_total:float,active:bool,_charges:int,_maximum:int)->void: observed.active=observed.active or active
	player.dash_state_changed.connect(on_dash)
	var pointer:=InputEventMouseMotion.new(); pointer.position=root.get_visible_rect().size*.5
	Input.parse_input_event(pointer); await frames(2)
	WALK.hold(player,direction)
	var event:=InputEventKey.new(); event.keycode=KEY_SPACE; event.physical_keycode=KEY_SPACE; event.pressed=true; Input.parse_input_event(event)
	var seen:=false; var supported:=true; var times: Array=[]
	for i in 65:
		await frames(1)
		seen=seen or player.is_phase_dash_active()
		supported=supported and player.phase_dash._floor_supported(player.global_position)
		if i==1: WALK.release(); event.pressed=false; Input.parse_input_event(event)
		await RenderingServer.frame_post_draw
		times.append(Time.get_ticks_msec())
		world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/"+label+"/%03d.png"%i)
	seen=seen or observed.active
	player.dash_state_changed.disconnect(on_dash)
	check(seen,label+" uses actual Space input")
	check(supported,label+" stays supported throughout the entire dash")
	clips[label]=times
	return {"seen":seen,"supported":supported}

func glass_candidate() -> Dictionary:
	var player: Node=world.player
	var offset: Vector2=player.body_collision.global_position-player.global_position
	for pane in get_nodes_in_group(&"breakable_glass_windows"):
		if not world.wall_root.is_ancestor_of(pane) or pane.is_shattered: continue
		var shape: CollisionShape2D=pane.collision_shape_2d
		if not is_instance_valid(shape): continue
		var size: Vector2=shape.shape.size
		var normal: Vector2=(Vector2.DOWN if size.x>size.y else Vector2.RIGHT).rotated(shape.global_rotation)
		for sign_value in [-1.0,1.0]:
			var direction: Vector2=normal*sign_value
			var start: Vector2=shape.global_position-direction*player.dash_distance*.42-offset
			var end: Vector2=start+direction*player.dash_distance
			if not player.phase_dash._standable(start,player.collision_mask) or not player.phase_dash._standable(end,player.collision_mask): continue
			if player.phase_dash._supported_travel_distance(start,direction,player.dash_distance)<player.dash_distance-.01: continue
			return {"pane":pane,"direction":direction,"start":start,"end":end}
	return {}

func solid_route(center: Vector2,direction: Vector2) -> Dictionary:
	var player: Node=world.player
	var offset: Vector2=player.body_collision.global_position-player.global_position
	var start: Vector2=center-direction*player.dash_distance*.42-offset
	var end: Vector2=start+direction*player.dash_distance
	if not player.phase_dash._standable(start,player.collision_mask) or not player.phase_dash._standable(end,player.collision_mask): return {}
	if player.phase_dash._supported_travel_distance(start,direction,player.dash_distance)<player.dash_distance-.01: return {}
	return {"start":start,"end":end,"direction":direction}

func door_candidate() -> Dictionary:
	for door in world.door_root.get_children():
		if not door.has_method("shatter_from_dash") or door.is_destroyed: continue
		for body in door._collision_bodies:
			if not is_instance_valid(body) or body.collision_layer==0: continue
			for sign_value in [-1.0,1.0]:
				var normal: Vector2=Vector2.DOWN.rotated(body.global_rotation)*sign_value
				var route:=solid_route(body.global_position,normal)
				if not route.is_empty(): route.door=door; return route
	return {}

func fixture_candidate() -> Dictionary:
	for fixture in get_nodes_in_group(&"generated_wall_attachments"):
		var reference: WeakRef=fixture.get_meta(&"wall_attachment_world",null)
		if reference==null or reference.get_ref()!=world: continue
		var key: String=fixture.get_meta(&"wall_support_edge_key","")
		if world.SHARED_WALL_BREACH.wall_for_key(world,key)==null: continue
		var edge: Dictionary=world.wall_edges[key]
		var center: Vector2=world._edge_gameplay_position(edge)
		for sign_value in [-1.0,1.0]:
			var direction: Vector2=(Vector2.DOWN if edge.axis=="H" else Vector2.RIGHT)*sign_value
			var route:=solid_route(center,direction)
			if not route.is_empty(): route.key=key; route.fixture=weakref(fixture); route.path=String(fixture.get_path()); return route
	return {}

func edge_candidate() -> Dictionary:
	var player: Node=world.player
	var offset: Vector2=player.body_collision.global_position-player.global_position
	for key in world.wall_edges:
		var edge: Dictionary=world.wall_edges[key]
		var cells: Array=world._edge_side_cells(edge)
		if world.floor_cells.has(cells[0])==world.floor_cells.has(cells[1]): continue
		var inside: Vector2i=cells[0] if world.floor_cells.has(cells[0]) else cells[1]
		var outside: Vector2i=cells[1] if inside==cells[0] else cells[0]
		var direction:=Vector2(outside-inside).normalized()
		var center: Vector2=world._edge_gameplay_position(edge)
		var start: Vector2=center-direction*player.dash_distance*.4-offset
		if not player.phase_dash._standable(start,player.collision_mask): continue
		var limit: float=player.phase_dash._supported_travel_distance(start,direction,player.dash_distance)
		if limit<8.0 or limit>=player.dash_distance: continue
		return {"start":start,"direction":direction,"key":key,"limit":limit}
	return {}

func run() -> void:
	await prepare_world()
	var player: Node=world.player
	var wall:=choose_wall()
	check(not wall.is_empty(),"real floor provides a wall crossing with continuous floor")
	if wall.is_empty(): main.queue_free(); await frames(4); quit(1); return
	await position_player(wall.start); await screenshot("final_wall_before")
	await space_clip(wall.direction,"final_wall_motion")
	check(world.broken_shared_walls.has(wall.key),"Space opens the actual masonry on the travelled route")
	check(world.edge_states.get(wall.key)==&"OPEN", "masonry opening persists in the real floor topology")
	await screenshot("final_wall_after")
	var fixture:=fixture_candidate()
	check(not fixture.is_empty(),"real floor provides an actual mounted decoration on a supported wall crossing")
	if not fixture.is_empty():
		await position_player(fixture.start); await screenshot("final_fixture_before")
		await space_clip(fixture.direction,"final_fixture_motion")
		check(world.broken_shared_walls.has(fixture.key),"actual Space destroys the decoration supporting wall")
		check(fixture.fixture.get_ref()==null,"actual production wall decoration disappears with its supporting wall")
		await screenshot("final_fixture_after")
	var door:=door_candidate()
	check(not door.is_empty(),"real floor provides a physical door with a supported crossing")
	if not door.is_empty():
		await position_player(door.start); await screenshot("final_door_before")
		check(not door.door.is_destroyed,"approach and camera preparation keep the door intact")
		await space_clip(door.direction,"final_door_motion")
		check(door.door.is_destroyed,"actual Space destroys the contacted physical door")
		check(door.door._collision_bodies.all(func(body: StaticBody2D)->bool: return body.collision_layer==0),"destroyed door has no remaining movement blocker")
		await screenshot("final_door_after")
	var glass:=glass_candidate()
	check(not glass.is_empty(),"real floor provides an intact glass crossing")
	if not glass.is_empty():
		var pane: Node3D=glass.pane
		await position_player(glass.start); await screenshot("final_glass_before")
		world.DASH_GLASS_BREAK.query(world,glass.start,glass.end,8.0)
		check(not pane.is_shattered,"glass query does not break the pane before actual input")
		await space_clip(glass.direction,"final_glass_motion")
		check(pane.is_shattered and pane.collision_body_2d.collision_layer==0,"actual Space shatters glass and removes its real collision")
		check(not pane.frame_root.is_visible_in_tree(),"shattered glass no longer leaves its top header or copied frame shadow")
		pane.set_cutaway_mode(false); pane.set_cutaway_mode(true)
		check(not pane.frame_root.is_visible_in_tree(),"room cutaway updates cannot restore a shattered glass header")
		await screenshot("final_glass_after")
	var boundary:=edge_candidate()
	check(not boundary.is_empty(),"real floor provides a boundary leading into black void")
	if not boundary.is_empty():
		await position_player(boundary.start)
		await screenshot("final_edge_before")
		await space_clip(boundary.direction,"final_edge_motion")
		check(player.phase_dash._floor_supported(player.global_position),"boundary dash ends completely on supported floor")
		check(player.global_position.distance_to(boundary.start)<player.dash_distance-1.0,"void boundary shortens travel instead of reaching outside the map")
		check(not player.is_phase_dash_active() and player.collision_mask!=0,"boundary stop restores normal collision and input")
		await screenshot("final_edge_after")
	var old_token: int=world.get_current_floor_token()
	player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d()
	world._begin_elevator_entry_transition()
	while world.floor_transition_in_progress: await frames(1)
	await frames(15)
	check(world.get_current_floor_token()!=old_token,"actual elevator enters a newly generated floor")
	check(world.broken_shared_walls.is_empty() and world.dash_breach_links.is_empty(),"new floor starts with intact topology and no inherited holes")
	FileAccess.open(OUT+"/final_clips.json",FileAccess.WRITE).store_string(JSON.stringify(clips))
	FileAccess.open(OUT+"/all_rules_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"wall_key":wall.key,"fixture_path":fixture.get("path",""),"door_found":not door.is_empty(),"glass_found":not glass.is_empty(),"edge_found":not boundary.is_empty()},"\t"))
	print("ALL_WALL_GLASS_DASH_CAMERA checks=",checks," failures=",failures)
	main.queue_free(); await frames(8); quit(1 if failures else 0)
