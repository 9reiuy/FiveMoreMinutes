extends SceneTree
const ATTACHMENTS=preload("res://scripts/dream/wall_attachments.gd")
const STAGING=preload("res://scripts/story/chapter_room_staging.gd")
const CAMERA=preload("res://scripts/story/surveillance_camera.gd")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func owned(world:Node,key:String)->Array[Node]:
	var result:Array[Node]=[]
	for node in get_nodes_in_group(ATTACHMENTS.GROUP):
		if node.get_meta(&"wall_attachment_world").get_ref()==world and String(node.get_meta(&"wall_support_edge_key",""))==key: result.append(node)
	return result
func break_key(world:Node,key:String,label:String)->void:
	var nodes:=owned(world,key)
	var references:Array[WeakRef]=[]
	for node in nodes: references.append(weakref(node))
	check(not nodes.is_empty(),label+" has real production attachments")
	check(world._commit_dash_wall_breaches([key],world.get_current_floor_token(),Vector2.RIGHT)==1,label+" supporting wall breaks")
	var gone:=true
	for reference in references: gone=gone and reference.get_ref()==null
	check(gone,label+" removes the complete attached mesh/light hierarchy")
func run()->void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	world.set_meta(&"test_floor_reflections_disabled",true)
	root.add_child(world); await process_frame
	check(world.regenerate(90210),"production native office generates")
	world.process_mode=Node.PROCESS_MODE_DISABLED
	await process_frame
	var random_key:=""
	var native_key:=""
	var lamp_key:=""
	var power_key:=""
	var tank_key:=""
	var tank:Node
	var random_roots:=0
	var native_roots:=0
	var lamp_roots:=0
	for node in get_nodes_in_group(ATTACHMENTS.GROUP):
		var key:=String(node.get_meta(&"wall_support_edge_key",""))
		if world.SHARED_WALL_BREACH.wall_for_key(world,key)==null: continue
		if String(node.get_parent().name).begins_with("ApprovedRandomRoomFixtures_"):
			random_roots+=1; random_key=key
		if node.get_parent()==world.wall_root:
			native_roots+=1; native_key=key
		if String(node.name).contains("_WallLight"):
			lamp_roots+=1; lamp_key=key
		if node.name==&"FloorPowerSwitch": power_key=key
		if node.is_in_group(&"fire_extinguishers") and not bool(node.broken): tank_key=key; tank=node
	check(random_roots>0,"real random-room signs and multi-part fixtures are bound")
	check(native_roots>0,"real generator decor plates are bound to their source edge")
	check(lamp_roots>0,"real planned wall lamps retain their exact support edge")
	check(tank!=null,"real hanging extinguisher owner is bound with its separate visual")
	# Use the same production chapter placement and camera factory as Main.
	var camera_site:Dictionary={}
	for room in world.rooms:
		camera_site=STAGING.camera_site(world,int(room.id))
		if not camera_site.is_empty() and world.SHARED_WALL_BREACH.wall_for_key(world,String(camera_site.key))!=null: break
	check(not camera_site.is_empty(),"chapter staging finds an actual camera mounting wall")
	var cameras:=Node3D.new(); world.add_child(cameras)
	var camera:Node3D=CAMERA.create(world,camera_site); cameras.add_child(camera)
	check(camera.has_meta(&"wall_support_edge_key") and camera.find_child("MonitoringCone",true,false)!=null,"production surveillance includes a bound mount/head and live light cone")
	var camera_key:=String(camera_site.key)
	# A real floor-standing furniture mesh very close to that wall is unrelated.
	var furniture:Node2D=load("res://scenes/dream/props/storage_cabinet_01.tscn").instantiate()
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(furniture,"cabinet")
	furniture.set_meta(&"office_visual_style", &"approved_room")
	furniture.set_meta(&"dream_room_id", int(world.room_cells.get(world._edge_side_cells(camera_site.edge)[1], world.spawn_room_id)))
	furniture.position=(camera_site.point+camera_site.inward*.65)*world.CELL_PIXELS
	world.furniture_root.add_child(furniture)
	if furniture is RigidBody2D: furniture.freeze=true
	var furniture_visual:Node3D=world._spawn_furniture_presentation(furniture)
	var furniture_ref:WeakRef=weakref(furniture)
	break_key(world,camera_key,"chapter surveillance")
	check(furniture_ref.get_ref()!=null and furniture.is_inside_tree() and is_instance_valid(furniture_visual) and not furniture.get_node("CollisionShape2D").disabled,"breaking the wall preserves a nearby real floor cabinet, its gameplay collision and production visual")
	for spec in [[random_key,"random-room wall dressing"],[native_key,"native generator plate"],[lamp_key,"planned wall lamp"]]:
		var key:=String(spec[0])
		if world.SHARED_WALL_BREACH.wall_for_key(world,key)!=null: break_key(world,key,String(spec[1]))
	var lights_clean:=true
	for light in world.ceiling_light_root.get_shadow_candidates(): lights_clean=lights_clean and is_instance_valid(light)
	for light in world.shadow_manager.candidates: lights_clean=lights_clean and is_instance_valid(light)
	check(lights_clean,"removed wall lamps leave no stale lighting or shadow-manager candidates")
	if not power_key.is_empty() and world.SHARED_WALL_BREACH.wall_for_key(world,power_key)!=null:
		break_key(world,power_key,"wall power cabinet and interaction collider")
	if is_instance_valid(tank) and world.SHARED_WALL_BREACH.wall_for_key(world,tank_key)!=null:
		var tank_visual_ref:WeakRef=weakref(tank.visual)
		break_key(world,tank_key,"hanging extinguisher and collision owner")
		await process_frame
		check(tank_visual_ref.get_ref()==null,"hanging extinguisher cleanup also retires its separately owned production visual")
	var exterior:Node3D
	for pane in get_nodes_in_group(&"breakable_glass_windows"):
		if world.wall_root.is_ancestor_of(pane) and bool(pane.exterior): exterior=pane; break
	check(exterior!=null,"actual facade pane is available for parent-structure regression")
	if exterior!=null:
		var structure:Node3D=exterior.get_parent()
		exterior.shatter(Vector2.RIGHT)
		world.room_visibility.set_current_presentation_room(world.spawn_room_id)
		var hidden:=not structure.visible
		for node in structure.find_children("*","Node3D",true,false):
			if node is GeometryInstance3D or node is Light3D: hidden=hidden and not node.is_visible_in_tree()
		check(hidden,"exterior parent header, copied shadow geometry and window lamp stay hidden after cutaway refresh")
	# Fixed sample fixtures and the floor rug share a container, not a support.
	world.use_authored_office_sample=true
	check(world.regenerate(90211),"actual authored sample generates")
	await process_frame
	var sample_fixture:Node3D
	var rug:Node3D
	for node in get_nodes_in_group(ATTACHMENTS.GROUP):
		if String(node.get_parent().name)=="RoomLowPixelFixtures_lounge" and world.SHARED_WALL_BREACH.wall_for_key(world,String(node.get_meta(&"wall_support_edge_key","")))!=null: sample_fixture=node; break
	for node in world.floor_root.find_children("LowContrastSeatRug","Node3D",true,false): rug=node; break
	check(sample_fixture!=null,"real authored lounge sign is bound separately from the floor rug in the same container")
	check(rug!=null and not rug.is_in_group(ATTACHMENTS.GROUP),"real authored lounge rug remains explicitly floor-supported")
	if sample_fixture!=null:
		var sample_key:=String(sample_fixture.get_meta(&"wall_support_edge_key"))
		# Stash/recover uses a fresh layout token and must preserve support ownership.
		world._stash_current_floor_for_rollback(); world._reset_layout_data()
		await world._rollback_failed_transition(world.transition_generation_token,world.floor_index)
		check(int(sample_fixture.get_meta(&"wall_attachment_floor"))==world.get_current_floor_token(),"rollback rebinds restored attachments to the fresh floor token")
		break_key(world,sample_key,"restored authored wall attachment")
		check(is_instance_valid(rug) and rug.is_inside_tree(),"removing authored wall signs leaves the real floor rug intact")
	world.free(); await process_frame
	print("WALL_ATTACHMENT_PRODUCTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
