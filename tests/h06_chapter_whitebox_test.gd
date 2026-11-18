extends SceneTree
## Movement, blockers and real swept shots in the same GameTestLab scene as the launcher.
const LAB := "res://scenes/testing/H06ChapterWhiteboxLab.tscn"
const WORLD := preload("res://scripts/testing/h06_chapter/chapter_world.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
var world: WORLD
var checks: Array[String] = []
var failures: Array[String] = []
var evidence := ""
var with_camera := false
var retired_roots: Array[WeakRef] = []
var vehicle_frames := 0
var clearance_failure := Vector2.INF
var climbed_ramp := false

func _initialize() -> void:
	create_timer(210.0).timeout.connect(func() -> void:
		push_error("H06_WHITEBOX_TIMEOUT exceeded 210s")
		quit(2)
	)
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks.append(label)
	if not ok:
		failures.append(label)
		push_error(label)
	print("PASS " if ok else "FAIL ",label)

func frames(n: int) -> void:
	for i in n: await physics_frame

func observe_crawler() -> void:
	if not is_instance_valid(world) or world.blockout==null: return
	if world.stage not in [WORLD.Stage.CHASE,WORLD.Stage.STAFF,WORLD.Stage.APPROACH]: return
	var model := world.blockout.mech
	if not is_instance_valid(model): return
	var p := Vector2(model.position.x,model.position.z)
	vehicle_frames += 1
	if clearance_failure==Vector2.INF and not PLAN.crawler_clear(p,world.vehicle_obstacles): clearance_failure=p
	if model.position.y>1.0 and model.position.y<6.0 and model.rotation.x<-.20 and model.is_visible_in_tree(): climbed_ramp=true

func interact() -> void:
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(2)
	await process_frame

func see_window(key: String, file: String) -> void:
	if not world.blockout.windows.has(key):
		check(false,key+" staging window missing in active visit")
		return
	var window = world.blockout.windows[key]
	var before: float = window.elapsed
	await frames(22)
	check(window.started and (window.elapsed>before or before>=4.5),key+" staging responds to the passing player")
	check(not window.actors[0].is_in_group(&"dream_enemies") and world.player.movement_enabled,key+" performers are separate from combat and leave controls active")
	for actor: Sprite3D in window.actors:
		# Billboard culling bounds enclose every possible camera angle. Measure the drawn quad.
		var portrait := actor.get_item_rect()
		var height := portrait.size.y * actor.pixel_size
		var normal_scale:float=world.player.character_visual_scale
		check(height >= normal_scale and height <= 1.4*normal_scale and is_equal_approx(actor.pixel_size,normal_scale/32.0)
			and absf(portrait.position.y * actor.pixel_size) < .002 and absf(actor.position.y) <= .025,
			key+" engineer/scientist uses normal character proportions with feet on the walking path")
	if with_camera:
		var camera := world.camera_3d
		var frame := camera.get_viewport().get_visible_rect()
		var safe := frame.grow(-frame.size.y*.055)
		var witness := false
		for actor: Sprite3D in window.actors:
			var center := actor.global_position + camera.global_basis.y.normalized() * actor.get_item_rect().size.y * actor.pixel_size * .5
			if actor.visible and safe.has_point(camera.unproject_position(center)):
				witness = true
		check(witness,key+" has an on-screen performer in the real gameplay camera")
	await capture(file)

func capture(label: String) -> void:
	if not with_camera: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func walk(mark: Vector2,speed: float=7.0) -> bool:
	var p = world.player
	var previous := world._feet()
	var stuck := 0
	for i in 1400:
		var pos := world._feet()
		var left := mark-pos
		if left.length()<.21:
			p.clear_scripted_locomotion()
			return true
		if p.dead: break
		stuck = stuck+1 if i>3 and pos.distance_to(previous)<.001 else 0
		if stuck>36: break
		previous = pos
		p.set_scripted_locomotion(left.normalized(),minf(speed,left.length()*24.0)*world.CELL_PIXELS)
		await physics_frame
	p.clear_scripted_locomotion()
	print("Walk stopped: ",mark," at ",world._feet()," stage ",world.stage," dead=",p.dead)
	return false

func via(points: Array,label: String) -> void:
	var ok := true
	for p: Vector2 in points:
		if not await walk(p): ok = false; break
	check(ok,label)

func check_black_wall() -> void:
	var art = world.blockout
	for wall: MeshInstance3D in art.wall_root.find_children("Wall*","MeshInstance3D",true,false):
		var mesh := wall.mesh
		if mesh==null or mesh.get_surface_count()!=2: continue
		if mesh.surface_get_material(0)!=art.cutout.top_black: continue
		# Godot packs normals when committing the mesh. Check their direction after decoding.
		var black_normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var inner_normals: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
		var cap_vertices := 0
		for normal in black_normals:
			if normal.dot(Vector3.UP)>.999: cap_vertices += 1
		var vertical_face := not inner_normals.is_empty() and absf(inner_normals[0].y)<.001
		check(cap_vertices>=3 and vertical_face and mesh.surface_get_material(1)!=art.cutout.top_black,"region %d has black wall tops and a separate interior finish" % (art.region+1))
		return
	check(false,"expected a two-sided wall finish in region %d" % (art.region+1))

func visit_security_room() -> void:
	var room: Node3D = world.blockout.floor_root.get_node("SecurityAndRecords")
	var env: Environment = world.get_node("Lighting/WorldEnvironment").environment
	var sky_fill := env.ambient_light_energy
	check(world.room_fill_weight>.99 and sky_fill<world.blockout.HANGAR_AMBIENT*.40 and world.blockout.lights_root.has_node("CameraConsolePool") and world.blockout.lights_root.has_node("SortingLampPool"),"the roofed office uses local task lights with reduced sky fill")
	check(room.find_children("CameraPicture","MeshInstance3D",true,false).size()==3 and
		room.has_node("ArchivePlanBoard"),"room 206 contains the monitoring stations and records board")
	await via([Vector2(-2.35,-17.85)],"reach the operator aisle")
	var into_desk := Vector2(0,2.1)*world.CELL_PIXELS
	check(world.player.test_move(world.player.global_transform,into_desk) and
		not world.is_player_dash_landing_allowed(world.player.global_position+into_desk),"the operator desk stops both walking and rolling")
	await frames(15)
	await capture("01c-monitoring")
	await via([Vector2(4.9,-17.10)],"cross the open partition into the records room")
	await frames(15)
	await capture("01d-records")
	await via([Vector2(-5.5,-17.6),Vector2(-5.5,-18.4)],"return from records to the northern exit aisle")
	await frames(22)
	check(world.blockout.threshold_open==0.0,"the recessed shutter is visible from the monitoring aisle")
	await capture("01e-west-recess")

func cross_passage(id: int, roll_through := false) -> void:
	var door: Dictionary = PLAN.PASSAGES[id]
	var dir: Vector2 = door.forward
	var at: Vector2 = door.at
	var title := "1-%d to 1-%d" % [PLAN.REGION_FOR_VISIT[id]+1,PLAN.REGION_FOR_VISIT[id+1]+1]
	check(await walk(at-dir*1.05),title+" reaches the near lip")
	var old = world.blockout
	var upcoming = world.prepared
	if id==PLAN.Visit.GALLERY and is_instance_valid(upcoming):
		var near_deck: MeshInstance3D = old.floor_root.get_node("WestThresholdFloor")
		var far_deck: MeshInstance3D = upcoming.floor_root.get_node("WestThresholdFloor")
		check(near_deck.global_transform.is_equal_approx(far_deck.global_transform) and near_deck.get_aabb().size.is_equal_approx(far_deck.get_aabb().size) and near_deck.material_overlay==null and far_deck.material_overlay==null,"both sides share one lit recessed floor at the same height")
	check(old.visit==id and is_instance_valid(upcoming) and upcoming.visit==id+1 and not upcoming.floor_root.is_visible_in_tree() and not upcoming.lights_root.is_visible_in_tree() and not upcoming.physics_root.can_process(),title+" keeps the far region hidden and inactive until entry")
	if not is_instance_valid(upcoming): return
	var former: Array[WeakRef] = []
	for node: Node in [old.floor_root,old.wall_root,old.lights_root,old.physics_root]:
		former.append(weakref(node))
	var scrap := []
	for p: Node2D in world.world_weapon_root.get_children(): scrap.append(weakref(p))
	var player_id: int = world.player.get_instance_id()
	var equipped: String = world.player.selected_weapon_id
	if with_camera and id in [0,3]: await capture("passage-%d-before" % (id+1))
	if roll_through:
		await roll("move_up")
	else:
		check(await walk(at+dir*.21),title+" can stand inside the threshold")
		check(world.blockout.visit==id,title+" does not reveal at the edge")
		check(await walk(at+dir*1.15),title+" crosses to the far floor")
	check(world.blockout==upcoming and world.blockout.live and world.blockout.physics_root.can_process(),title+" activates the far floor, collision and lights")
	check(world.player.get_instance_id()==player_id and world.player.selected_weapon_id==equipped,title+" keeps the player and loadout")
	if world.blockout.visit!=id+1: return
	check_black_wall()
	for ref: WeakRef in former:
		var node: Node = ref.get_ref()
		check(not is_instance_valid(node) or (not node.can_process() and not node.is_visible_in_tree()),title+" retires an old scene root immediately")
		retired_roots.append(ref)
	for ref: WeakRef in scrap:
		var gun: Node2D = ref.get_ref()
		check(not is_instance_valid(gun) or not gun.can_process(),title+" retires weapons left behind")
	var retreat := (at-dir*1.5-world._feet())*world.CELL_PIXELS
	check(world.player.test_move(world.player.global_transform,retreat) and not world.is_player_dash_landing_allowed(world.player.global_position+retreat),title+" blocks walking and rolling back")
	if with_camera and id in [0,3]: await capture("passage-%d-after" % (id+1))

func fire_at(target: Node2D,until_defeated: bool=false) -> bool:
	var old: float = target.current_health
	var shooter := world.player
	var pointer := InputEventMouseMotion.new()
	pointer.position = current_scene.presentation.content_rect.get_center()
	root.push_input(pointer,true)
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	var muzzle: Vector2 = shooter.get_projectile_origin()
	shooter.set_meta(&"aim_direction_override",muzzle.direction_to(target.global_position))
	await frames(3)
	Input.action_press("attack")
	var strafe_x := 44.0
	for i in (1000 if until_defeated else 65):
		if until_defeated:
			var feet := world._feet()
			if absf(feet.x-strafe_x)<.4: strafe_x = 32.0 if strafe_x>38 else 44.0
			var strafe := feet.direction_to(Vector2(strafe_x,1.5))
			shooter.set_scripted_locomotion(strafe,6.4*world.CELL_PIXELS)
		shooter.set_meta(&"aim_direction_override",shooter.get_projectile_origin().direction_to(target.global_position))
		await physics_frame
		if target.dead or shooter.dead or (not until_defeated and target.current_health < old): break
	Input.action_release("attack")
	if until_defeated: shooter.clear_scripted_locomotion()
	shooter.remove_meta(&"aim_direction_override")
	var hit: bool = target.dead or (not until_defeated and target.current_health < old)
	if not hit:
		print("Firing positions ",shooter.global_position," / ",target.global_position,
			" current camera ",world.camera_3d.is_current()," weapon ",shooter.selected_weapon_id,
			" aim gate ",shooter._presentation_pointer_input_allowed()," range ",shooter.auto_weapon.attack_range)
	return hit

func clear_wave(expected: String,count: int) -> void:
	var targets:Array=world.warehouse_squads.get(expected,world.members)
	check(world.wave==expected and targets.size()==count,expected+" has the authored enemies")
	if world.blockout.gates.has(expected):
		check(world.blockout.closed[expected],expected+" exit locked until last kill")
	else:
		check(world.blockout.closed.pump,"warehouse stair exit remains locked during "+expected)
	if targets.is_empty(): return
	if expected=="guard": check(await fire_at(targets[1]),"real round hits a western guard")
	for unit: EmployeeEnemy in targets.duplicate():
		if not unit.dead: world.resolve_player_hit(unit,10000,world.player.global_position)
		if not unit.dead and unit.current_health == 1.0 and not unit.helmet_equipped:
			world.resolve_player_hit(unit,10000,world.player.global_position)
	await frames(3)
	if world.blockout.gates.has(expected):
		check(not world.blockout.closed[expected],expected+" exit opens after the last kill")

func clear_west_shutter_cohorts()->void:
	var encounter=world.west_shutter_encounter
	await frames(60)
	check(world.warehouse_triggered.has("inspection") and world.warehouse_triggered.has("archive"),"both west shutters triggered on initial warehouse entry")
	check(encounter.first.size()==5 and encounter.second.size()==5,"paired shutter encounter retains two five-person cohorts")
	for unit:EmployeeEnemy in encounter.first:
		if encounter.first_alive()<=2:break
		if unit.dead:continue
		world.resolve_player_hit(unit,10000,world.player.global_position)
		if not unit.dead and unit.current_health==1.0:world.resolve_player_hit(unit,10000,world.player.global_position)
		await frames(2)
	for i in 600:
		if encounter.phase>=encounter.Phase.SECOND and encounter.second.all(func(u):return u.dead or u.room_runtime_active):break
		await frames(1)
	check(encounter.phase>=encounter.Phase.SECOND and encounter.second.all(func(u):return u.dead or u.room_runtime_active),"second cohort activates after the first falls to two survivors")
	for unit:EmployeeEnemy in encounter.first+encounter.second:
		if not unit.dead:world.resolve_player_hit(unit,10000,world.player.global_position)
		if not unit.dead and unit.current_health==1.0:world.resolve_player_hit(unit,10000,world.player.global_position)
	for i in 120:
		if encounter.finished():break
		await frames(1)
	check(encounter.finished(),"both shutter cohorts clear before the original pump exit encounter")

func roll(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_press("roll")
	await frames(2)
	Input.action_release("roll")
	await frames(44)
	Input.action_release(action)
	await frames(3)

func press_restart(keycode: Key) -> bool:
	var previous_id := current_scene.get_instance_id()
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	root.push_input(key,true)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release,true)
	for i in 150:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id:
			return true
	return false

func sample(label: String) -> Dictionary:
	var raw: Array[float] = []
	for i in 14: await process_frame
	var last := Time.get_ticks_usec()
	for i in 90:
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append((now-last)*.001)
		last=now
	var sorted := raw.duplicate()
	sorted.sort()
	return {"area":label,"count":raw.size(),"p50_ms":sorted[44],"p95_ms":sorted[85],"p99_ms":sorted[89],"max_ms":sorted[-1],"frames_ms":raw}

func run() -> void:
	evidence = OS.get_environment("H06_EVIDENCE")
	if evidence.is_empty(): evidence = "user://h06_whitebox_test"
	DirAccess.make_dir_recursive_absolute(evidence)
	with_camera = DisplayServer.get_name()!="headless"
	if with_camera: preload("res://tests/support/background_gpu.gd").start(self)
	check(change_scene_to_file(LAB)==OK,"launch chapter through GameTestLab")
	await scene_changed
	await frames(5)
	world = current_scene.presentation.world
	physics_frame.connect(observe_crawler)
	var metrics := []
	check(world.stage==WORLD.Stage.GALLERY and world.player.has_any_weapon(),"entry has the real player and a weapon")
	check(world.blockout.mech.visible and not world._spotlight_triggered,"H06 first appears in its original bay")
	var holding := PLAN.CHASE_PATH[0]
	check(holding.is_equal_approx(PLAN.EXHIBIT_TRANSFER[-1]) and holding.distance_to(holding.clamp(PLAN.REAR_GATE.position,PLAN.REAR_GATE.end))>=PLAN.CRAWLER_RADIUS,"the bay opens onto the chase staging floor with six feet behind the closed freight shutter")
	check(world.blockout.region==PLAN.Region.GALLERY and world.prepared==null and not world.floor_cells.has(Vector2i(38,-5)),"new game loads only the entrance gallery")
	check_black_wall()
	check(PLAN.Region.size()==5 and PLAN.REGION_FOR_VISIT==[0,1,0,2,3,4],"five districts include a second visit to the red hangar")
	await via([Vector2(5.5,6),PLAN.HATCH],"find the hatch at the foot of the eastern flight")
	check(not world.blockout.secret_visible and not is_instance_valid(world.blockout.service_model),"upper gallery conceals the optional room")
	await capture("01-gallery")
	await interact()
	await frames(38)
	check(world.on_lower_floor and not world.climbing and world._feet().distance_to(PLAN.LADDER_FOOT)<.18,"climb down beneath the original stairs without changing district")
	await via([Vector2(9.7,1.5),Vector2(14.3,1.25)],"walk east through the under-stair opening into the yellow plant room")
	check(world.player.test_move(world.player.global_transform,Vector2(0,-67))
		and not world.is_player_dash_landing_allowed(Vector2(14.3,-1.2)*world.CELL_PIXELS),"the raised deck is only reachable through its central stair")
	await via([Vector2(14.3,2.65),Vector2(17.3,2.65),Vector2(17.3,1.0)],"step onto the middle of the five concrete treads")
	await frames(8)
	var stair_y := PLAN.lower_height(world._feet())
	check(stair_y>.22 and stair_y<.70 and absf(world.player_depth_bridge.ground_surface_height-stair_y)<.04
		and absf(world._camera_elevation-stair_y)<.06,"actor and camera follow the utility stair elevation")
	await capture("01a-plant-stairs")
	await via([Vector2(17.3,-1.05),PLAN.MODEL_BENCH+Vector2(0,1.32)],"reach the prototype trolley on the raised equipment floor")
	check(absf(world.player_depth_bridge.ground_surface_height-PLAN.SERVICE_RISE)<.04,"the plant room equipment deck supports the player at its real height")
	var plant: Node3D = world.blockout.floor_root.get_node("UnderStairPlantRoom")
	check(plant.has_node("CeladonPressureTank") and plant.find_children("WallBasin*","Node3D",false,false).size()==2,"green pressure tank and both wall basins are built on the raised floor")
	await interact()
	check(world.discovered and is_instance_valid(world.blockout.service_model) and world.blockout.model_cycle.is_running(),"optional prototype exhibit runs independently of the main H06")
	check(world.blockout.model_legs.size()==6,"the prototype cycles all six original leg joints")
	await capture("01a-secret")
	await via([Vector2(21,-1.05),Vector2(22.5,-.35)],"approach the secret room east wall")
	check(world.player.test_move(world.player.global_transform,Vector2(65,0))
		and not world.is_player_dash_landing_allowed(Vector2(25,-.4)*world.CELL_PIXELS),"yellow room has no walk or roll shortcut into the final arena")
	await via([Vector2(17.3,-.64),Vector2(17.3,2.65),Vector2(14.4,2.6),Vector2(12.0,1.55),Vector2(9.4,1.45),PLAN.LADDER_FOOT],"descend the plant stairs and return through the same hidden doorway")
	await interact()
	await frames(40)
	check(not world.on_lower_floor and not world.climbing and absf(world.player_depth_bridge.ground_surface_height-PLAN.upper_height(PLAN.HATCH))<.10,"climb back to the gallery with controls and height restored")
	await via([Vector2(5.5,-6.45),Vector2(.05,-6.45)],"reach the north gallery wall above the stairs")
	var facade: Node3D = world.blockout.wall_root
	check(not facade.has_node("DoorLeafN_204") and not facade.has_node("DoorLeafN_205") and
		not facade.has_node("OfficeBay204_Sill") and facade.has_node("OfficeBay205_Sill") and
		facade.has_node("PlaqueN_206"),"the marked doors and middle window are removed while the 206 entrance and its adjoining window remain")
	await frames(15)
	await capture("01b-north-gallery-wall")
	await via([Vector2(-6.05,-6.45)],"walk the original elevated gallery to door 206")
	check(world._spotlight_triggered and absf(world.player_depth_bridge.ground_surface_height-3.04)<.05,"light reveal and correct gallery height")
	await via([Vector2(-6.05,-15.6),Vector2(-5.5,-18.4)],"walk through 206 into the open observation room")
	check(world.checkpoint==WORLD.Save.OBSERVATION,"observation is the red district exit checkpoint")
	await visit_security_room()
	var pending: WeakRef = weakref(world.prepared)
	var pending_floor: WeakRef = weakref(world.prepared.floor_root)
	world.player.force_hazard_death(&"test_unentered_passage")
	check(await press_restart(KEY_R),"retry while the unseen western room is preparing")
	await frames(5)
	world = current_scene.presentation.world
	check(world.blockout.region==PLAN.Region.GALLERY and world.discovered and world.wave.is_empty(),"retry restores the red gallery and optional discovery")
	check(not is_instance_valid(pending.get_ref()) and not is_instance_valid(pending_floor.get_ref()),"retry releases the unrevealed room")
	await cross_passage(0)
	await via([Vector2(-5.5,-27.35)],"clear the matching recessed entrance on the west side")
	await frames(30)
	check(world.blockout.west_entry_closed and world.blockout.threshold_open==0.0,"the west side visibly closes the retired entrance")
	await capture("02-west-entrance")
	await via([Vector2(-5.5,-27),Vector2(-8.6,-27.6),Vector2(-8.6,-34.6),Vector2(-6.0,-34.6)],"reach the blue calibration floor")
	await see_window("calibration","02a-calibration-glass")
	check(not world.blockout.lamps.has("calibration") and world.blockout.closed.calibration,"calibration console removed and western barrier starts closed")
	check(not world.is_player_dash_landing_allowed(Vector2(-14,-29.2)*32),"a roll cannot cross the closed calibration barrier")
	await interact()
	check(world.blockout.closed.calibration,"remote E cannot open the barrier railing")
	var pre_guards: Array = world.warehouse_squads.get("guard",[])
	var pre_pumps: Array = world.warehouse_squads.get("pump",[])
	check(pre_guards.size()==2 and pre_pumps.size()==2,"warehouse room squads are already present inside their rooms before breaching")
	check(pre_guards.all(func(u): return is_instance_valid(u) and not u.dead and u.visible and not u.hostile),"guard enemies wait visibly inside the room without spawning from thin air")
	await via([Vector2(-2.60,-32.2),Vector2(-2.48,-31.42)],"approach the forklift beside the north cab side")
	await interact()
	check(is_instance_valid(world.blockout.forklift) and world.player.mounted_vehicle==world.blockout.forklift,"player boards the forklift with E")
	Input.action_press("move_up")
	for i in 220:
		await physics_frame
		if not world.blockout.closed.calibration and world._feet().x <= -12.8:
			break
	Input.action_release("move_up")
	Input.action_press("roll")
	for i in 60:
		await physics_frame
		if absf(world.blockout.forklift.speed) < 0.12:
			break
	Input.action_release("roll")
	await frames(2)
	check(not world.blockout.closed.calibration and world.checkpoint>=WORLD.Save.CALIBRATED,"driving the forklift west smashes the barrier railing open")
	check(world._feet().x <= -12.5,"forklift drives cleanly across the calibration threshold into the guard room")
	check(pre_guards.all(func(u): return world.members.has(u) and is_instance_valid(u) and u.hostile),"breaching activates the pre-existing guard units in place")
	await interact()
	check(world.player.mounted_vehicle==null,"player dismounts the forklift cleanly in the guard aisle")
	await via([Vector2(-16.2,-27.4)],"step clear south-west of the parked forklift into the guard firing lane")
	check(world.room_fill_weight<.01 and is_equal_approx(world.get_node("Lighting/KeyLight").light_energy,world.blockout.HANGAR_KEY),"leaving the inspection room restores the surrounding wing lighting")
	await clear_wave("guard",2)
	await via([Vector2(-22.6,-27.4),Vector2(-22.6,-30.7),Vector2(-34.5,-30.7)],"walk directly through the west doorway to inspection")
	await clear_west_shutter_cohorts()
	await via([Vector2(-35.0,-35.2)],"look into the sample handling room")
	await see_window("inspection","02b-sample-window")
	await via([Vector2(-38.6,-30.5),Vector2(-38.6,-20)],"enter the sample archive through the adjoining doorway")
	await via([Vector2(-38.6,-14.2),Vector2(-27,-14.2)],"go straight from the archive shelves into the pump floor")
	await clear_wave("pump",2)
	await via([Vector2(-29.2,-14.2),Vector2(-29.2,-6.2),Vector2(-38.6,-6.2),Vector2(-38.6,-22.6),Vector2(-15.0,-22.6),Vector2(-15.0,-6.2)],"loop unobstructed through the open ring-connected warehouse")
	await via([Vector2(-18.5,-4),Vector2(-18.5,8)],"descend the broad western staff stair")
	await cross_passage(1)
	await via([Vector2(-7.8,8)],"enter the empty red hangar at ground level")
	check(world.stage==WORLD.Stage.SEARCH and world.blockout.region==PLAN.Region.GALLERY and not is_instance_valid(world.blockout.mech) and world.on_lower_floor,"the same red district returns with an empty illuminated exhibit")
	await capture("02c-empty-bay")
	check(not world.blockout.closed.cargo_access and world._nearby_console(PLAN.RELAY_CONSOLE).is_empty(),
		"the south exit is already open with no console interaction")
	await via([Vector2(.5,7.9),Vector2(.5,10.4)],"follow the south arrow to the freight threshold")
	await cross_passage(2)
	check(world.checkpoint==WORLD.Save.TRANSFER,"walking through the south exit records the transfer checkpoint")
	check(world.blockout.windows.has("west_bank") and world.blockout.windows.west_bank.started,"walking through the middle of the freight door starts the dispatch vignette")
	await via([Vector2(2.4,16.4)],"see the dispatch crew evacuate the freight entrance before the chase")
	await see_window("west_bank","03a-evacuation")
	await via([Vector2(2.4,19.38)],"enter the sorting floor before the sound cue")
	check(world.stage==WORLD.Stage.CHASE and world.blockout.mech.visible,"H06 breaks in behind the player")
	await frames(24)
	await capture("03b-rear-door")
	await via([Vector2(2.4,20.05)],"approach the transverse inspection trench")
	check(world.player.test_move(world.player.global_transform,Vector2(0,40)),"walking cannot skip the open trench")
	await capture("03c-trench")
	await roll("move_down")
	check(world._feet().y>22.4 and world.jump_time<0 and world.player.movement_enabled,"Space roll crosses south across the trench")
	await via([Vector2(-4.9,27),Vector2(-4.9,37.5)],"cross the open sorting floor to the personnel shutter")
	check(world.player.test_move(world.player.global_transform,Vector2(0,42)),"standing movement blocked by low shutter")
	await capture("03d-sorting")
	await roll("move_down")
	check(world._feet().y>38.6 and not world.player.dashing,"Space roll clears the personnel shutter")
	await via([Vector2(-4.9,44),Vector2(-3.5,55.5),Vector2(-3.5,59.8),Vector2(12.1,60.1),Vector2(12.1,62.7)],"weave along sorting and loading walkways into the outbound dock")
	check(world.checkpoint==WORLD.Save.MIDPOINT and world.breached,"midpoint earned and machine broke the freight shutter")
	var open_shutter := world.blockout.freight_leaf.global_transform * world.blockout.freight_leaf.get_aabb() if is_instance_valid(world.blockout.freight_leaf) else AABB()
	check(PLAN.HEAVY_GATE.size.x>=2*PLAN.CRAWLER_RADIUS and is_instance_valid(world.blockout.freight_leaf) and open_shutter.position.y>PLAN.CRAWLER_HEIGHT,"the raised freight shutter clears the full moving H06 hull horizontally and overhead")
	check(retired_roots.all(func(ref: WeakRef): return not is_instance_valid(ref.get_ref())),"the first three visited room sets have been freed")
	await capture("03e-loading")
	for i in 450:
		if world.player.dead: break
		await physics_frame
	check(world.player.dead and world.player.last_damage_source==&"h06_chase","staying in the freight yard lets the pursuing H06 catch the player")
	if not world.player.dead: world.player.force_hazard_death(&"h06_test")
	var retried := await press_restart(KEY_R)
	check(retried,"R restarts from the death screen")
	if not retried:
		world.restart_current_floor_after_death()
		await scene_changed
	await frames(5)
	world = current_scene.presentation.world
	check(world.stage==WORLD.Stage.CHASE and world._feet().distance_to(Vector2(12.1,62.7))<.7 and not world.player.dead,"fresh scene resumes at the freight midpoint")
	await via([Vector2(12.1,77),Vector2(12.1,88.5),Vector2(25.8,88.5),Vector2(25.8,99.0),Vector2(37.5,99.0),Vector2(37.5,88.5)],"detour south around missile-shattered transfer chasm to transfer hall")
	await see_window("transfer_floor","03f-crane-window")
	check(not world.is_player_dash_landing_allowed(Vector2(31.8,88.5)*world.CELL_PIXELS),"missile-shattered chasm blocks straight shortcut across transfer floor")
	check(not world.is_player_dash_landing_allowed(PLAN.BELT.get_center()*world.CELL_PIXELS),"approaching transfer south bay shatters BELT platform into chasm")
	await via([Vector2(49.3,88.5),Vector2(61.5,88.5),Vector2(77.5,88.5),Vector2(77.5,74.0)],"sprint east along the northern transfer lane into inbound east corridor")
	check(world.checkpoint==WORLD.Save.CROSS_DOCK,"transfer hall awards the second chase checkpoint")
	check(not world.is_player_dash_landing_allowed(Vector2(68.5,81.5)*world.CELL_PIXELS),"inbound southwest missile fracture blocks shortcut")
	await via([Vector2(66.0,74.0),Vector2(66.0,50.0)],"ascend inbound east S-curve around broken pits and dropped crane bays")
	check(not world.is_player_dash_landing_allowed(PLAN.ROLLER.get_center()*world.CELL_PIXELS),"return_bay west missile fracture shatters roller lane")
	await via([Vector2(66.0,34.0),Vector2(50.3,34.0)],"follow north corridor and exit west beneath dispatch tiered cargo seals")
	check(not world.is_player_dash_landing_allowed(Vector2(58.0,28.0)*world.CELL_PIXELS),"dispatch north multi-tier crane cargo drops seal off ramp approach")
	await cross_passage(3)
	await via([Vector2(44.5,34)],"cross west into the green common room")
	check(world.stage==WORLD.Stage.STAFF and world.blockout.closed.refuge,"fire door shuts behind player")
	await via([Vector2(40.0,32.5),Vector2(35.5,31.8)],"enter the logistics hub command hall from the east airlock portal")
	var hub: Node3D = world.blockout.floor_root.get_node("LogisticsHub")
	check(hub.has_node("SortingHubKiosk") and hub.has_node("ConveyorChute_SW") and hub.has_node("ConveyorChute_SE") and hub.has_node("OverheadConveyorArm"),"central sorting kiosk, dual roller conveyors and overhead arm belong to hub 1-4")
	check(hub.has_node("DispatchControlOffice") and hub.has_node("ForkliftCorridorBay") and hub.has_node("ReceivingVestibule") and hub.has_node("SouthCargoVault"),"compartmentalized dispatch office, forklift bay, receiving pods and cargo vault belong to hub 1-4")
	check(hub.has_node("NorthConcourse") and hub.has_node("ArmoryPegAndLamps") and hub.has_node("ArmoryWorkbench") and hub.has_node("ArmoryRightLockers"),"north concourse and image-2 exit-corner armory workshop belong to hub 1-4")
	await capture("04c-hub-entry")
	var at_rest: float = world.player.current_health
	await frames(100)
	check(world.members.is_empty() and get_nodes_in_group(&"dream_enemies").is_empty() and world.player.current_health==at_rest,"the logistics hub remains a safe respite after the chase")
	check(not world.is_player_dash_landing_allowed(Vector2(33.8,28.6)*world.CELL_PIXELS),"sorting kiosk blocks dash landing")
	check(not world.is_player_dash_landing_allowed(Vector2(34.8,36.8)*world.CELL_PIXELS),"logistics forklift blocks dash landing")
	check(not world.is_player_dash_landing_allowed(Vector2(30.4,24.8)*world.CELL_PIXELS),"dispatch control office bulkhead window blocks dash landing")
	check(not world.is_player_dash_landing_allowed(Vector2(43.3,17.65)*world.CELL_PIXELS),"exit-corner armory workbench blocks dash landing")
	await capture("04a-sorting-rotunda")
	await via([PLAN.MEDICINE+Vector2(0,.91)],"enter the partitioned med-bay directly from the forklift corridor")
	world.player.receive_damage(8.0,&"test_medical")
	check(world.player.current_health<world.player.maximum_health,"arrive at first aid with missing health")
	await interact()
	check(world.medicine_used and world.player.current_health==world.player.maximum_health,"clinic restores health")
	await via([Vector2(37.5,29.5),Vector2(37.5,21.0),Vector2(41.2,16.5)],"traverse command bunker north to the open exit-corner weapon bay")
	var stock := []
	for gun in world.world_weapon_root.get_children():
		if PLAN.LOWER.duty.has_point(gun.position/world.CELL_PIXELS): stock.append(gun.weapon_id)
	check(stock.size()==3 and stock.has("assault_rifle") and stock.has("shotgun") and stock.has("mp5"),"three pickup weapons are mounted in the exit-corner armory")
	await capture("04b-exit-armory")
	for id: String in ["shotgun","mp5","assault_rifle"]:
		var front: Vector2 = PLAN.RACK[id]+Vector2(0,.78)
		check(await walk(front),"approach the "+id+" rack slot from the front")
		await frames(4)
		if id!="assault_rifle":
			await interact()
			check(world.player.selected_weapon_id==id,"use E to equip "+id)
	var aimed = world.current_world_weapon_target
	check(is_instance_valid(aimed) and aimed.weapon_id=="assault_rifle" and aimed.interaction_targeted,"the normal proximity outline selects the gun on the front of the rack")
	await interact()
	check(world.player.selected_weapon_id=="assault_rifle","standard pickup equips the visible rifle")
	await via([Vector2(38.0,14.5)],"exit armory directly to the north exit elevator lobby")
	check(world.checkpoint==WORLD.Save.ARENA,"pre-boss retry point set")
	check(climbed_ramp and world.ramp_distance>=world.escape_path.get_baked_length()-.1,"the full-scale H06 climbs the vehicle ramp and reaches the elevated hoist before the boss retry")
	check(not is_instance_valid(world.blockout.crawler_floor),"the last freight floor unloads after all six feet have reached the permanent vehicle deck")
	check(vehicle_frames>400 and clearance_failure==Vector2.INF,"the moving crawler keeps six-leg clearance in the actual chase, during handoff and on the approach")
	if clearance_failure!=Vector2.INF: print("First footprint obstruction: ",clearance_failure)
	check(retired_roots.all(func(ref: WeakRef): return not is_instance_valid(ref.get_ref())),"freight geometry, collision and lighting have unloaded inside the staff wing")
	world.player.force_hazard_death(&"test_arena_retry")
	check(await press_restart(KEY_R),"retry at the end of the staff wing")
	await frames(5)
	world = current_scene.presentation.world
	check(world.player.selected_weapon_id=="assault_rifle" and world.stage==WORLD.Stage.APPROACH,"arena retry keeps the weapon chosen in the armory")
	if with_camera: metrics.append(await sample("staff"))
	await cross_passage(4,true)
	for i in 320:
		if world.blockout.inclined_lift.is_docked:break
		await physics_frame
	await via([PLAN.ARENA_BRIDGE.get_center(),PLAN.LIFT_ENTRY+Vector2(0,-1.7)],"cross the grated bridge and board the docked freight platform")
	for i in 360:
		if world.stage==WORLD.Stage.DROP: break
		await physics_frame
	check(world.stage==WORLD.Stage.DROP and world.blockout.closed.boarding,"the overhead ambush starts mid-ride")
	await frames(25)
	await capture("05a-drop")
	for i in 140:
		if world.stage==WORLD.Stage.BOSS: break
		await physics_frame
	check(is_instance_valid(world.boss) and world.blockout.closed.arena,"H06 lands as an attackable arena boss")
	check(world.blockout.hoist_bridge==null and world.blockout.inclined_lift.speed>0.,"H06 lands on the clear moving deck")
	if is_instance_valid(world.boss):
		check(await fire_at(world.boss),"real player projectile damages the H06 body")
		await capture("05b-boss")
		var hp: float = world.player.current_health
		world.boss.wait = .01
		await frames(2)
		check(world.boss.winding and world.boss.warning.visible,"stomp telegraphs before dealing damage")
		world.boss.wait = .01
		await frames(3)
		check(world.player.current_health<hp,"standing in the warning receives stomp damage")
		if with_camera: metrics.append(await sample("boss"))
		check(await fire_at(world.boss,true),"armory rifle defeats the H06 via standard firing")
		await frames(4)
		check(world.stage==WORLD.Stage.EXIT and world.blockout.inclined_lift.travel==world.blockout.inclined_lift.Travel.ARRIVING,"boss defeat continues the ride to the upper stop")
		check(retired_roots.all(func(ref: WeakRef): return not is_instance_valid(ref.get_ref())),"all five previous sets of floors, walls, lights and collision have actually been freed")
		for i in 320:
			if world.stage==WORLD.Stage.DONE:break
			await physics_frame
		check(world.stage==WORLD.Stage.DONE and is_zero_approx(world.blockout.inclined_lift.speed),"arriving upstairs completes the chapter")
		await frames(24)
		await capture("05c-finish")
		check(await press_restart(KEY_F5),"F5 restarts the chapter after completion")
		await frames(4)
		world = current_scene.presentation.world
		check(world.stage==WORLD.Stage.GALLERY and world.blockout.mech.visible,"new game restores the exhibit and the entrance")
		var door: Dictionary = PLAN.PASSAGES[PLAN.Visit.GALLERY]
		await via([Vector2(5.5,6),Vector2(5.5,-6.45),Vector2(-6.05,-6.45),Vector2(-6.05,-15.6),door.at-door.forward*1.20],"reach the recessed passage without using the service hatch")
		await roll("move_up")
		check(world.blockout.region==PLAN.Region.WEST and not world.discovered,"a roll through the north recess enters the west wing on a fresh run")
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),
		"scene":LAB,"pid":OS.get_process_id(),"vehicle_physics_frames":vehicle_frames,"samples":metrics}
	var f := FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("H06 WHITEBOX ",checks.size()," checks, ",failures.size()," failures")
	unload_current_scene()
	world = null
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
