extends SceneTree
var checks := 0
var failures := 0
var world: Node
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func mesh_area(mesh: Mesh) -> float:
	var area := 0.0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in range(0,indices.size(),3): area += (vertices[indices[i+1]]-vertices[indices[i]]).cross(vertices[indices[i+2]]-vertices[indices[i]]).length()*.5
	return area
func run() -> void:
	create_timer(45).timeout.connect(func() -> void: quit(2))
	var diag := root.get_node_or_null("_DroneGameDiag")
	if diag != null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001),"Real formal floor generates")
	world.set_process(false)
	world.player.set_physics_process(false)
	var windows: Array = world.wall_root.find_children("ExteriorBreakablePane","",true,false)
	check(windows.size()>1,"Exterior facade has independent damageable cells")
	if windows.is_empty(): world.free(); quit(1); return
	var pane: Node = windows[0]
	var sibling: Node = windows[1]
	var inward: Vector2 = world._window_inward_normal(pane.edge_data)
	var center: Vector2 = world._edge_gameplay_position(pane.edge_data)
	var service: Node = world.floor_root.get_node("ExteriorFalls")
	service.set_physics_process(false)
	check(pane.max_health==100 and pane.current_health==100,"Exterior pane matches door durability")
	check(pane.collision_body_2d.collision_layer!=0,"Intact pane blocks movement")
	check(not service.crossed_opening(center+inward*8,center-inward*8),"Intact facade never opens fall route")
	pane.take_damage(20,-inward)
	check(pane.current_health==80 and not pane.is_shattered,"First ordinary hit does not shatter exterior pane")
	check(is_instance_valid(pane.cracks),"Damage produces crack overlay")
	for i in 4: pane.take_damage(20,inward)
	check(pane.is_shattered and not pane.get_parent().visible,"Only destroyed cell is removed")
	check(not sibling.is_shattered and sibling.current_health==100,"Adjacent pane retains durability")
	check(service.crossed_opening(center+inward*8,center-inward*8),"Broken exterior edge permits fall")
	check(not service.crossed_opening(center-inward*8,center+inward*8),"Opening only triggers outward crossing")
	check(not service.crossed_opening(center+inward*8+inward.orthogonal()*33,center-inward*8+inward.orthogonal()*33),"Adjacent intact cell remains safe")
	await process_frame
	check(pane.collision_body_2d.collision_layer==0,"Broken pane releases real collision")
	var debris: Array = get_nodes_in_group(&"persistent_destruction_debris")
	check(debris.size()==1 and debris[0].get_parent()==world.floor_root,"Shards belong to current floor")
	var burst: Node = debris[0]
	check(burst.pieces.size()>=6 and burst.render.multimesh.instance_count==burst.pieces.size()*4,"Source is fractured into large panels with batched impact crumbs")
	var area := 0.0
	var textured := true
	for fragment in burst.pieces:
		area += mesh_area(fragment.visual.mesh)
		textured = textured and fragment.visual.mesh.surface_get_material(0)!=null
	check(absf(area-mesh_area(pane.glass_pane.mesh))<.01,"Fracture covers entire original glass without losing or duplicating surface area")
	check(textured,"Large pieces retain source materials rather than generic cube color")
	var forward := true
	for fragment in burst.pieces:
		var velocity: Vector3 = fragment.velocity
		var planar := Vector2(velocity.x,velocity.z)
		forward = forward and planar.normalized().dot(inward)>.98 and planar.length()>=4.0 and planar.length()<=6.01
	check(forward,"All large glass pieces launch forward in impact direction, never backwards")
	var initial: Transform3D = burst.pieces[0].node.transform
	burst._process(.08)
	check(not burst.pieces[0].node.transform.is_equal_approx(initial),"Large source fragments tumble in flight")
	var landed := false
	for i in 180:
		burst._process(1.0/60.0)
		for fragment in burst.pieces:
			if fragment.settled and not fragment.crumbs.is_empty(): landed=true
	check(landed,"Ground impact changes panels into small crumbs")
	check(burst.is_queued_for_deletion(),"Fragments disappear instead of remaining permanently")
	var interior: Node = load("res://scripts/dream/breakable_glass_window_3d.gd").new()
	world.floor_root.add_child(interior)
	interior.configure_window(pane.edge_data,"interior_test",2.6,.1,null)
	interior.take_damage(1)
	check(interior.is_shattered,"Interior glass keeps original one-hit durability")
	for i in 34: preload("res://scripts/dream/destruction_floor_debris.gd").spawn(pane,Vector2.ZERO,true)
	var live := 0
	for effect in get_nodes_in_group(&"persistent_destruction_debris"):
		if not effect.retiring: live += 1
	check(live<=32,"Persistent fragment budget bounded")
	var item := Node2D.new()
	world.pickup_root.add_child(item)
	item.global_position = center+inward*8
	service.previous[item.get_instance_id()] = item.global_position
	item.global_position = center-inward*8
	service._physics_process(.01)
	check(item.get_meta(&"exterior_falling",false),"Loose object falls through broken cell")
	var badge := Node2D.new()
	world.key_root.add_child(badge)
	badge.set_meta(&"employee_badge",true)
	badge.global_position = center-inward*8
	service._physics_process(.01)
	check(world.floor_cells.has(world._cell_for_gameplay_position(badge.global_position)),"Required badge relocated onto floor")
	check(not badge.get_meta(&"exterior_falling",false),"Badge is never removed by falling")
	service._physics_process(.6)
	check(item.is_queued_for_deletion(),"Loose object removed after brief fall")
	var enemy: Node = world._spawn_regular_employee(world.current_room_id,center+inward*8,&"employee",false,"luger")
	enemy.set_physics_process(false)
	enemy.set_process(false)
	service.previous[enemy.get_instance_id()] = enemy.global_position
	enemy.global_position = center-inward*8
	service._physics_process(.01)
	check(enemy.dead and enemy.get_meta(&"exterior_falling",false),"Live enemy commits normal death/reward pipeline on fall")
	var corpse: Node = world._spawn_regular_employee(world.current_room_id,center+inward*8,&"employee",false,"luger")
	corpse.force_pit_death(corpse.global_position)
	service.previous[corpse.get_instance_id()] = center+inward*8
	corpse.global_position = center-inward*8
	service._physics_process(.01)
	check(corpse.get_meta(&"exterior_falling",false),"Already dead corpse can fall as well")
	var furniture: Node = load("res://scenes/dream/props/desk.tscn").instantiate()
	world.furniture_root.add_child(furniture)
	furniture.global_position = center+inward*8
	service.previous[furniture.get_instance_id()] = furniture.global_position
	furniture.global_position = center-inward*8
	service._physics_process(.01)
	check(furniture.get_meta(&"exterior_falling",false),"Real movable desk falls through aperture")
	service._physics_process(.6)
	check(enemy.is_queued_for_deletion() and corpse.is_queued_for_deletion() and furniture.is_queued_for_deletion(),"Actors and furniture removed after falling")
	var player: Node = world.player
	player.global_position = center+inward*24
	var dash: Node = load("res://scripts/entities/player_phase_dash.gd").new()
	root.add_child(dash)
	dash.configure(player)
	var landing: Vector2 = dash.find_landing(player.global_position,-inward,168,player.collision_mask)
	check(landing.is_finite() and (landing-center).dot(inward)>0,"Space dash stops inside first exterior edge")
	var old_floor: Dictionary = world.floor_cells
	var old_pits: Dictionary = world.pit_cells
	world.floor_cells = {}
	for y in range(-2,3):
		for x in [-1,0,3,4,5]: world.floor_cells[Vector2i(x,y)] = true
	world.pit_cells = {}
	var separated: Vector2 = dash.find_landing(Vector2.ZERO,Vector2.RIGHT,128,player.collision_mask)
	check(separated.is_finite() and separated.x>=96,"Dash crosses void to reachable neighboring wing")
	world.floor_cells = {}
	for y in range(-2,3):
		for x in [-1,0,7,8]: world.floor_cells[Vector2i(x,y)] = true
	var unreachable: Vector2 = dash.find_landing(Vector2.ZERO,Vector2.RIGHT,168,player.collision_mask)
	check(not unreachable.is_finite() or unreachable.x<16,"Unreachable wing never extends dash range or causes void landing")
	world.floor_cells = old_floor
	world.pit_cells = old_pits
	dash.free()
	player.global_position = center+inward*8
	service.previous[player.get_instance_id()] = player.global_position
	player.global_position = center-inward*8
	service._physics_process(.01)
	check(player.get_meta(&"exterior_falling",false),"Walking out starts player fall")
	player.has_shield = true
	player.invulnerability_left = 100.0
	service._physics_process(.6)
	check(player.dead and player.current_health==0,"Exterior death bypasses shield and invulnerability")
	await process_frame
	player.revive_for_floor_restart("")
	check(not player.dead and player.visible and not player.has_meta(&"exterior_falling") and player.collision_mask!=0,"Retry restores player visibility, collisions and fall state")
	var saved_bursts := get_nodes_in_group(&"persistent_destruction_debris").size()
	var prior_index: int = world.floor_index
	world._stash_current_floor_for_rollback()
	check(not service.can_process(),"Transition stash suspends exterior controller")
	world._rollback_failed_transition(world.transition_generation_token,prior_index)
	check(is_instance_valid(service) and service.can_process() and service.openings.size()==1,"Failed transition restores same broken aperture")
	check(get_nodes_in_group(&"persistent_destruction_debris").size()==saved_bursts,"Rollback preserves fragment identity without duplication")
	var reference: WeakRef = weakref(service)
	check(world.regenerate(42002),"Next floor generates after destruction")
	await process_frame
	check(reference.get_ref()==null,"Next floor discards opening history and falling actors")
	check(get_nodes_in_group(&"persistent_destruction_debris").is_empty(),"Next floor clears every persistent fragment")
	world.free()
	await process_frame
	world = load("res://scenes/dream/Dream3D_OfficeSample.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001),"Independent approved sample generates")
	for i in 3: await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	var sample_panes: Array = world.wall_root.find_children("ExteriorBreakablePane","",true,false)
	check(not sample_panes.is_empty(),"Approved sample receives durable exterior panes")
	if not sample_panes.is_empty():
		sample_panes[0].take_damage(100,Vector2.RIGHT)
		check(sample_panes[0].is_shattered,"Sample exterior pane uses same destruction pipeline")
	var door: Node
	for candidate in world.door_root.get_children():
		if candidate.has_method("shatter") and not candidate.locked:
			door = candidate
			break
	check(door!=null,"Sample has a normal destructible door")
	if door!=null:
		var count: int = get_nodes_in_group(&"persistent_destruction_debris").size()
		door.shatter(Vector2.RIGHT)
		check(door.is_destroyed and get_nodes_in_group(&"persistent_destruction_debris").size()>=count+1,"Metal door creates persistent floor fragments")
		var bursts: Array = get_nodes_in_group(&"persistent_destruction_debris")
		var door_burst: Node = bursts.back()
		var rightward: bool = not door_burst.pieces.is_empty()
		for fragment in door_burst.pieces:
			var velocity: Vector3 = fragment.velocity
			rightward = rightward and velocity.x>0 and Vector2(velocity.x,velocity.z).normalized().dot(Vector2.RIGHT)>.98
		check(rightward,"Door panels and handles follow the same hit direction")
	world.free()
	await process_frame
	print("EXTERIOR_DESTRUCTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
