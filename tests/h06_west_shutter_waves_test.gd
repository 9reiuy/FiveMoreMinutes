extends "res://tests/h06_hangar_crew_test.gd"
const OUT:="res://.runtime/h06_shutter_cycle_20261117"
const ENCOUNTER:=preload("res://scripts/testing/h06_chapter/west_shutter_encounter.gd")
var metrics:FileAccess
var maximum_step:=0.0
var runway_error:=0.0
var previous_positions:Dictionary={}
var overview:=false
var door_trace:Array[Dictionary]=[]
var last_door_state:=""
var collect_movement:=true

func paired_shutters(opened:bool,settled:=false)->bool:
	for door:String in ENCOUNTER.DOORS:
		var art=world.blockout
		var bay:Dictionary=art.west_shutters[door]
		if art.is_west_shutter_open(door)!=opened:return false
		if settled and (bool(bay.get("moving",false)) or not is_equal_approx(float(bay.curtain.scale.y),.05 if opened else 1.0)):return false
		var body:StaticBody2D=art.west_shutter_bodies[door]
		if (body.collision_layer==0)!=opened:return false
		var layout:Dictionary=PLAN.WEST_SHUTTER_BAYS[door]
		var ray:=PhysicsRayQueryParameters2D.create(Vector2(-47.0,float(layout.z))*32.0,Vector2(-45.0,float(layout.z))*32.0,world.get_vision_occluder_collision_mask())
		var hit:Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty()==(not opened):return false
		if not opened and hit.get("collider")!=body:return false
		for z in range(ceili(float(layout.z)-float(layout.width)*.5),ceili(float(layout.z)+float(layout.width)*.5)):
			if world.wall_edges.has(world._edge_key({"axis":"V","x":-46,"y":z}))==opened:return false
	return true

func observe_doors()->void:
	var encounter=world.west_shutter_encounter
	var state:="%s:%s:%s:%s"%[encounter.get_instance_id(),encounter.phase,encounter.door_cycle,world.blockout.west_shutters.inspection.get("moving",false)]
	if state==last_door_state:return
	last_door_state=state
	door_trace.append({"usec":Time.get_ticks_usec(),"phase":encounter.phase,"cycle":encounter.door_cycle,"first_alive":encounter.first_alive(),"open":world.blockout.is_west_shutter_open("inspection"),"curtain_y_scale":world.blockout.west_shutters.inspection.curtain.scale.y})

func _initialize()->void:call_deferred("run")

func step(count:int,label:="")->void:
	var last:=Time.get_ticks_usec()
	for frame in count:
		await physics_frame
		await process_frame
		var now:=Time.get_ticks_usec()
		if not label.is_empty():metrics.store_line("%s,%d,%.3f"%[label,frame,(now-last)/1000.0])
		last=now
		var encounter:RefCounted=world.west_shutter_encounter
		if encounter==null:continue
		observe_doors()
		for record:Dictionary in encounter.walkers.values():
			if not collect_movement:break
			var unit:EmployeeEnemy=record.unit.get_ref()
			if not is_instance_valid(unit) or unit.dead:continue
			if previous_positions.has(unit.get_instance_id()):maximum_step=maxf(maximum_step,unit.global_position.distance_to(previous_positions[unit.get_instance_id()]))
			previous_positions[unit.get_instance_id()]=unit.global_position
			if record.roaming and not unit.hostile:
				var at:=unit.global_position/32.0
				var nearest:=INF
				for index in ENCOUNTER.RUNWAY.size():
					nearest=minf(nearest,at.distance_to(Geometry2D.get_closest_point_to_segment(at,ENCOUNTER.RUNWAY[index],ENCOUNTER.RUNWAY[(index+1)%ENCOUNTER.RUNWAY.size()])))
				runway_error=maxf(runway_error,nearest)

func defeat(unit:EmployeeEnemy)->void:
	for i in 3:
		if not is_instance_valid(unit) or unit.dead:return
		world.resolve_player_hit(unit,100000.0,unit.global_position-Vector2(32,0))
		await frames(2)

func freeze_other_squads()->void:
	for key:String in ["guard","pump","receiving"]:
		for unit:EmployeeEnemy in world.warehouse_squads.get(key,[]):unit.set_physics_process(false)

func view_warehouse()->void:
	world.set_process(false)
	overview=true
	if not RenderingServer.frame_pre_draw.is_connected(_frame_overview):RenderingServer.frame_pre_draw.connect(_frame_overview)
	_frame_overview()

func _frame_overview()->void:
	if not overview or not is_instance_valid(world) or not is_instance_valid(world.camera_3d):return
	# Preserve the real perspective/orientation; pull the actual Camera back
	# for an explicitly staged overview of the paired doors and yellow loop.
	world.camera_3d.global_position=world.to_global(Vector3(-29,3.04,-20))+world.camera_3d.global_basis.z.normalized()*60.0

func dispose_world()->void:
	overview=false
	world.set_physics_process(false)
	display.queue_free()
	await frames(5)

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	create_timer(150,true,false,true).timeout.connect(func():quit(3))
	var draw_clock:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf(float(now-draw_clock[0])/1000000.0,0.0,.05))
		draw_clock[0]=now)
	root.size=Vector2i(1280,720)
	evidence=ProjectSettings.globalize_path(OUT)
	metrics=FileAccess.open(OUT+"/frame_times.csv",FileAccess.WRITE)
	metrics.store_line("stage,frame,wall_ms")
	await enter(CHAPTER.Save.CALIBRATED,false)
	world.player.maximum_health=100000.0
	world.player.current_health=100000.0
	var encounter:RefCounted=world.west_shutter_encounter
	check(encounter!=null and encounter.first.size()==5 and encounter.second.size()==5,"both existing door squads and the matching second cohort are prepared")
	var first_ids:Array=encounter.first.map(func(u:EmployeeEnemy):return u.get_instance_id())
	var second_ids:Array=encounter.second.map(func(u:EmployeeEnemy):return u.get_instance_id())
	check(not world.blockout.is_west_shutter_open("inspection") and not world.blockout.is_west_shutter_open("archive"),"both upper shutters remain closed before warehouse entry")
	check(paired_shutters(false,true),"closed metal curtains are full height with matching physical and navigation blockers")
	check(encounter.first.all(func(u:EmployeeEnemy):return not u.room_runtime_active and u.global_position.x<-46.0*32.0),"first cohort waits behind the actual shutter line")
	check(encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active and not u.hostile),"second cohort stays dormant before its threshold")
	check(world.floor_cells.has(Vector2i(-48,-29)) and world.floor_cells.has(Vector2i(-48,-15)),"both rendered shutter pockets are connected to the real floor navigation")
	view_warehouse()
	await photograph("00-before-entry")
	world._place_feet(Vector2(-10.5,-29.6))
	world.player.set_scripted_locomotion(Vector2.LEFT,world.player.movement_speed)
	await step(55,"entry_and_first_release")
	world.player.clear_scripted_locomotion()
	check(world._feet().x<-12.5 and world.blockout.is_west_shutter_open("inspection") and world.blockout.is_west_shutter_open("archive"),"actual player movement into the warehouse opens both shutters together")
	check(encounter.phase==ENCOUNTER.Phase.FIRST,"entry starts the first cohort exactly once")
	freeze_other_squads()
	world._place_feet(Vector2(-2.6,-30.5))
	view_warehouse()
	await photograph("01-opening-and-first-exit")
	var last_out:EmployeeEnemy=encounter.first.back()
	last_out.set_physics_process(false)
	await step(180,"first_exit_waiting_for_last")
	check(last_out.global_position.x/32.0<ENCOUNTER.EXIT_X and paired_shutters(true,true),"both curtains stay raised until the last living cohort member actually exits")
	last_out.set_physics_process(true)
	await step(210,"first_exit_and_patrol")
	# Crowds can yield briefly to one another after the held actor resumes.
	# Bound the real route completion instead of assuming an exact arrival frame.
	for frame in 180:
		if encounter.walkers.values().all(func(r:Dictionary):return bool(r.roaming)):break
		await step(1,"first_patrol_join")
	check(encounter.first.all(func(u:EmployeeEnemy):return u.room_runtime_active and u.global_position.x>-45.0*32.0),"all five first-cohort enemies physically walk out of both bays")
	check(encounter.first.all(func(u:EmployeeEnemy):return not u.hostile and not u.has_last_known_target_position),"released enemies do not receive the distant player's position")
	check(encounter.walkers.values().all(func(r:Dictionary):return bool(r.roaming)),"all released enemies join the painted runway")
	check(maximum_step<32.0 and runway_error<1.5,"neutral movement follows the yellow aisle without teleporting or crossing shelving")
	check(encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active),"second cohort does not release while five first-cohort enemies survive")
	check(encounter.door_cycle==ENCOUNTER.DoorCycle.CLOSED and paired_shutters(false,true),"both visible roller curtains lower and restore collision and navigation after first-cohort egress")
	await photograph("02-first-cohort-on-runway")
	await defeat(encounter.first[0])
	await defeat(encounter.first[1])
	await step(12)
	check(encounter.first_alive()==3 and encounter.phase==ENCOUNTER.Phase.FIRST and encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active),"three first-cohort survivors do not trigger the second cohort")
	check(paired_shutters(false,true),"shutters wait closed while the first cohort has three survivors")
	for guard:EmployeeEnemy in world.warehouse_squads.guard:await defeat(guard)
	await step(6)
	check(encounter.phase==ENCOUNTER.Phase.FIRST,"unrelated guard deaths do not count toward the shutter threshold")
	world._start_wave("pump",CHAPTER.Stage.PUMP,CHAPTER.Save.PUMP)
	freeze_other_squads()
	check(world.checkpoint<CHAPTER.Save.PUMP and world.blockout.closed.pump,"an early pump trigger cannot save past unfinished shutter waves or open the exit")
	await defeat(encounter.first[2])
	await step(55,"second_release")
	check(encounter.first_alive()==2 and encounter.phase==ENCOUNTER.Phase.SECOND,"two first-cohort survivors trigger the second cohort")
	check(paired_shutters(true,true),"both shutters physically reopen and remove navigation stops for the second release")
	check(encounter.second.all(func(u:EmployeeEnemy):return u.room_runtime_active) and encounter.second.map(func(u:EmployeeEnemy):return u.get_instance_id())==second_ids,"second release reuses the five prepared actors instead of instantiating a new crowd")
	check(encounter.first.map(func(u:EmployeeEnemy):return u.get_instance_id())==first_ids,"first-cohort survivors keep their original identities")
	await photograph("03-second-cohort-exits")
	await step(210,"second_exit_and_patrol")
	check(encounter.second.all(func(u:EmployeeEnemy):return u.global_position.x>-45.0*32.0),"the second cohort also walks through the open shutters")
	check(encounter.door_cycle==ENCOUNTER.DoorCycle.CLOSED and paired_shutters(false,true),"both roller curtains close again after second-cohort egress while surviving enemies remain outside")
	await photograph("04-second-cohort-out-doors-closed")
	var probe:EmployeeEnemy=encounter.second[0]
	var facing:=Vector2.RIGHT
	var clear_target:=Vector2.INF
	for direction:Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var candidate:=probe.global_position+direction*48.0
		if world.is_employee_position_clear(candidate,probe) and probe._has_target_line_of_sight(candidate):
			clear_target=candidate;facing=direction;break
	check(clear_target.is_finite(),"visual-discovery fixture selects a genuinely unobstructed player position")
	if clear_target.is_finite():world._place_feet(clear_target/32.0)
	probe.last_facing_direction=facing
	probe._apply_live_facing(facing)
	probe.weapon_root.rotation=facing.angle()
	probe.wander_target=probe.global_position+facing*64.0
	probe.steering_commit_left=0.0
	probe.perception_update_left=0.0
	print("VISION_PROBE direction=",probe._get_gameplay_facing_direction()," los=",probe._has_target_line_of_sight(world.player.global_position)," distance=",probe.global_position.distance_to(world.player.global_position)," active=",probe.room_runtime_active," visual=",probe.uses_visual_perception)
	await step(30)
	check(probe.hostile and probe.has_last_known_target_position,"real visual discovery interrupts runway wandering")
	world._place_feet(Vector2(-2.6,-30.5))
	for unit:EmployeeEnemy in encounter.first+encounter.second:await defeat(unit)
	await step(8)
	check(encounter.finished() and world.warehouse_cleared.has("inspection") and world.warehouse_cleared.has("archive"),"both shutter zones clear only after both cohorts and the first survivors are defeated")
	for unit:EmployeeEnemy in world.warehouse_squads.pump:await defeat(unit)
	await step(8)
	check(world.stage==CHAPTER.Stage.RETURN and not world.blockout.closed.pump,"the original stair exit opens after all warehouse squads clear")
	var retired:WeakRef=weakref(encounter.first[3])
	await dispose_world()
	check(retired.get_ref()==null,"leaving the scene releases the cohort actors")
	# The following safety fixture deliberately repositions frozen units;
	# it is separate from the preceding real locomotion measurements.
	collect_movement=false
	previous_positions.clear()
	await enter(CHAPTER.Save.GUARD,false)
	check(world.west_shutter_encounter.phase==ENCOUNTER.Phase.FIRST and world.west_shutter_encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active),"retrying the guard checkpoint restarts the first cohort without releasing the second")
	encounter=world.west_shutter_encounter
	freeze_other_squads()
	await step(60)
	for index in encounter.first.size():
		var unit:EmployeeEnemy=encounter.first[index]
		unit.set_physics_process(false)
		unit.global_position=ENCOUNTER.RUNWAY[index]*32.0
	world._place_feet(Vector2(-47.8,-28.8))
	await step(40)
	check(paired_shutters(true,true),"a player inside a shutter bay prevents the closing cycle from trapping them")
	world._place_feet(Vector2(-2.6,-30.5))
	await step(1)
	check(encounter.door_cycle==ENCOUNTER.DoorCycle.CLOSING,"the first curtain closing starts once the player clears the bay")
	for index in 3:await defeat(encounter.first[index])
	check(encounter.phase==ENCOUNTER.Phase.FIRST and encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active),"an early two-survivor threshold waits for the previous closing cycle before releasing reinforcements")
	await step(90)
	check(encounter.phase==ENCOUNTER.Phase.SECOND and world.blockout.is_west_shutter_open("inspection"),"reinforcements reopen the shutters after the first closing and brief closed pause")
	await dispose_world()
	await enter(CHAPTER.Save.ARCHIVE,false)
	check(world.west_shutter_encounter.phase==ENCOUNTER.Phase.FIRST and world.west_shutter_encounter.first.size()==5 and not world.warehouse_squads.has("guard"),"a partial legacy archive checkpoint restarts the paired cohort without reviving cleared guards")
	await dispose_world()
	await enter(CHAPTER.Save.PUMP,false)
	check(world.west_shutter_encounter.finished() and world.west_shutter_encounter.first.is_empty() and world.west_shutter_encounter.second.is_empty(),"a completed warehouse checkpoint does not respawn the cleared shutter cohorts")
	check(paired_shutters(false,true),"a completed warehouse checkpoint restores closed full-height metal curtains")
	await dispose_world()
	metrics.close()
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"door_trace":door_trace,"maximum_actor_step_pixels":maximum_step,"maximum_neutral_runway_error_metres":runway_error,"scope":"native authored H06 test scene, actual curtain cycles egress safety collision navigation patrol perception thresholds retry and release; not whole-game performance certification"},"\t"))
	print("WEST_WAVES checks=",checks.size()," failures=",failures.size()," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
