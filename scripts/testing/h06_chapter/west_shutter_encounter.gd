extends RefCounted
## One encounter owns the paired west bays; unrelated warehouse squads stay independent.
const PLAN:=preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const SOUND:=preload("res://scripts/audio/sfx_manager.gd")
const DOORS:=["inspection","archive"]
const SECOND_KEYS:={"inspection":"west_second_inspection","archive":"west_second_archive"}
const RUNWAY:Array[Vector2]=[Vector2(-38.3,-30.5),Vector2(-38.3,-7.8),Vector2(-26.8,-7.8),Vector2(-26.8,-22.1),Vector2(-15.0,-22.1),Vector2(-15.0,-30.5)]
const REINFORCE_AT:=2
const CLOSED_PAUSE:=.45
const EXIT_X:=-45.35
enum Phase { WAITING, FIRST, SECOND, COMPLETE }
enum DoorCycle { CLOSED, RELEASING, CLOSING }
var phase:=Phase.WAITING
var door_cycle:=DoorCycle.CLOSED
var closed_for:=0.0
var world:Node3D
var first:Array[EmployeeEnemy]=[]
var second:Array[EmployeeEnemy]=[]
var pending:Array[Dictionary]=[]
var walkers:Dictionary={}

static func spawn_specs(door:String,reinforcement:=false)->Array:
	var specs:Array=PLAN.WAVES[door].duplicate(true)
	for index in specs.size():
		# Both cohorts start inside the existing bay, behind the curtain.
		specs[index][0]=Vector2(-48.35 if reinforcement else -47.35,float(PLAN.WEST_SHUTTER_BAYS[door].z)+(index-(specs.size()-1)*.5)*1.05)
	return specs

func configure(owner:Node3D)->void:
	world=owner
	for door:String in DOORS:world.blockout.close_west_shutter(door,true)
	if world.warehouse_cleared.has("inspection") and world.warehouse_cleared.has("archive"):
		phase=Phase.COMPLETE
		return
	for door:String in DOORS:
		for unit:EmployeeEnemy in world.warehouse_squads.get(door,[]):first.append(unit)
		for unit:EmployeeEnemy in world.warehouse_squads.get(SECOND_KEYS[door],[]):second.append(unit)

func finished()->bool:
	return phase==Phase.COMPLETE

func has_pending_batches()->bool:
	return phase!=Phase.COMPLETE

func first_alive()->int:
	return _alive(first)

func _alive(units:Array)->int:
	var count:=0
	for unit in units:
		if is_instance_valid(unit) and not unit.dead:count+=1
	return count

func tick(point:Vector2,delta:float)->void:
	if world.blockout.visit!=PLAN.Visit.WEST or world.on_lower_floor:return
	if phase==Phase.WAITING:
		if world.gate_state.get("calibration",true):return
		var inside:=false
		for key:String in ["guard","inspection","archive","pump"]:
			inside=inside or PLAN.UPPER[key].has_point(point)
		if not inside:return
		start()
	for index in range(pending.size()-1,-1,-1):
		pending[index].delay-=delta
		if float(pending[index].delay)>0.0:continue
		var entry:Dictionary=pending[index]
		pending.remove_at(index)
		_release(entry.unit.get_ref(),entry.door)
	_tick_walkers(delta)
	_tick_doors(point,delta)
	if phase==Phase.FIRST and door_cycle==DoorCycle.CLOSED and closed_for>=CLOSED_PAUSE and first_alive()<=REINFORCE_AT:
		phase=Phase.SECOND
		_open_batch(true)
		world._prompt("左侧增援出动　·　清理黄色跑道")
	elif phase==Phase.SECOND and door_cycle==DoorCycle.CLOSED and _alive(first)+_alive(second)==0:
		phase=Phase.COMPLETE
		for key:String in DOORS:world.warehouse_cleared[key]=true
	if phase==Phase.COMPLETE and _alive(world.warehouse_squads.get("guard",[]))==0:
		world.warehouse_cleared["guard"]=true
		# Parallel waves must not let an early pump-room visit skip living
		# shutter enemies on retry. Advance only once the preceding fights end.
		world.checkpoint=maxi(world.checkpoint,world.Save.PUMP)

func start()->void:
	if phase!=Phase.WAITING:return
	if not world.warehouse_triggered.has("guard") and not world.warehouse_cleared.has("guard"):
		world._start_wave("guard",world.Stage.GUARD,world.Save.GUARD)
	phase=Phase.FIRST
	for door:String in DOORS:
		world.warehouse_triggered[door]=true
	if world.wave.is_empty():world.wave="west_shutters"
	_open_batch(false)
	world._prompt("左侧两扇卷帘门开启　·　警卫进入黄色跑道")

func _open_batch(reinforcement:bool)->void:
	door_cycle=DoorCycle.RELEASING
	closed_for=0.0
	for door:String in DOORS:
		world.blockout.open_west_shutter(door)
		SOUND.play_world_sfx_3d(&"wall_break",Vector3(-46.0,3.6,float(PLAN.WEST_SHUTTER_BAYS[door].z)))
	# Release only after the visible curtain has finished lifting, every time.
	_queue_batch(reinforcement,.50)

func _tick_doors(point:Vector2,delta:float)->void:
	if phase not in [Phase.FIRST,Phase.SECOND]:return
	if door_cycle==DoorCycle.RELEASING:
		if not pending.is_empty():return
		var cohort:Array=first if phase==Phase.FIRST else second
		for unit:EmployeeEnemy in cohort:
			if is_instance_valid(unit) and not unit.dead and unit.global_position.x/32.0<EXIT_X:return
		# Wait for physical egress, even if combat interrupts the patrol route.
		# Do not shut the player in a bay or lower a curtain onto a living actor.
		for door:String in DOORS:
			var bay:Dictionary=PLAN.WEST_SHUTTER_BAYS[door]
			if point.x<EXIT_X and absf(point.y-float(bay.z))<float(bay.width)*.5+.5:return
			var mouth:=Rect2(-46.6,float(bay.z)-float(bay.width)*.5-.4,1.25,float(bay.width)+.8)
			for unit:EmployeeEnemy in world.members:
				if is_instance_valid(unit) and not unit.dead and unit.room_runtime_active and mouth.has_point(unit.global_position/32.0):return
		for door:String in DOORS:world.blockout.close_west_shutter(door)
		door_cycle=DoorCycle.CLOSING
	elif door_cycle==DoorCycle.CLOSING:
		for door:String in DOORS:
			if not world.blockout.is_west_shutter_closed(door):return
		door_cycle=DoorCycle.CLOSED
		closed_for=0.0
	else:closed_for+=delta

func _queue_batch(reinforcement:bool,delay:float)->void:
	for door:String in DOORS:
		var key:String=SECOND_KEYS[door] if reinforcement else door
		var squad:Array=world.warehouse_squads.get(key,[])
		for index in squad.size():
			var unit:EmployeeEnemy=squad[index]
			if is_instance_valid(unit) and not unit.dead:
				pending.append({"unit":weakref(unit),"door":door,"delay":delay+index*.18})

func _release(unit:EmployeeEnemy,door:String)->void:
	if not is_instance_valid(unit) or unit.dead:return
	unit.set_room_bounds(Rect2(world._west_upper_bounds().position*32.0,world._west_upper_bounds().size*32.0).grow(-6.0))
	unit.uses_visual_perception=true
	unit.can_see_target=false
	unit.has_last_known_target_position=false
	unit.last_known_target_velocity=Vector2.ZERO
	unit.hostile=false
	unit.state=EmployeeEnemy.State.NEUTRAL_WANDER
	unit.perception_update_left=0.0
	unit.wander_wait_left=0.0
	var z:float=PLAN.WEST_SHUTTER_BAYS[door].z
	var join:=Vector2(-38.3,z)*32.0
	var exit_route:Array[Vector2]=[Vector2(-45.5,unit.global_position.y/32.0)*32.0,Vector2(-42.0,z)*32.0,join]
	unit.set_authored_patrol_route(exit_route)
	unit.set_room_runtime_active(true)
	if not world.members.has(unit):world.members.append(unit)
	walkers[unit.get_instance_id()]={"unit":weakref(unit),"join":join,"roaming":false,"was_hostile":false}

func _tick_walkers(delta:float)->void:
	for id in walkers.keys():
		var record:Dictionary=walkers[id]
		var unit:EmployeeEnemy=record.unit.get_ref()
		if not is_instance_valid(unit) or unit.dead:
			walkers.erase(id)
			continue
		if not unit.hostile and unit.state==EmployeeEnemy.State.NEUTRAL_WANDER:
			if record.was_hostile or (not record.roaming and unit.global_position.distance_to(record.join)<20.0):
				_assign_runway(unit,record)
				record.roaming=true
			if record.roaming:_follow_runway(unit,record,delta)
		record.was_hostile=unit.hostile

func _assign_runway(unit:EmployeeEnemy,record:Dictionary)->void:
	var at:=unit.global_position/32.0
	var nearest:=Vector2.ZERO
	var segment:=0
	var best:=INF
	for index in RUNWAY.size():
		var point:=Geometry2D.get_closest_point_to_segment(at,RUNWAY[index],RUNWAY[(index+1)%RUNWAY.size()])
		var distance:=point.distance_squared_to(at)
		if distance<best:best=distance;nearest=point;segment=index
	var direction:=1 if unit.random.randi_range(0,1)==0 else -1
	var start_index:int=segment+1 if direction==1 else segment
	var route:Array[Vector2]=[]
	if at.distance_to(nearest)>.20:route.append(nearest*32.0)
	for step in RUNWAY.size():route.append(RUNWAY[posmod(start_index+step*direction,RUNWAY.size())]*32.0)
	unit.set_authored_patrol_route(route)
	unit.wander_wait_left=0.0
	record.route=route
	record.route_index=0
	record.pause=0.0

func _follow_runway(unit:EmployeeEnemy,record:Dictionary,delta:float)->void:
	var route:Array=record.route
	var desired:Vector2=route[record.route_index]
	if float(record.pause)>0.0:
		record.pause=maxf(0.0,float(record.pause)-delta)
		unit.wander_target=unit.global_position
		unit.wander_wait_left=.1
		return
	if unit.global_position.distance_to(desired)<=8.0:
		record.route_index=(int(record.route_index)+1)%route.size()
		record.pause=unit.random.randf_range(.35,.85)
		unit.wander_target=unit.global_position
		unit.wander_wait_left=.1
		return
	# Generic neutral unsticking may skip a hint. Here corners define a real
	# painted aisle, so keep the next corner until physically reached.
	if unit.wander_target.distance_squared_to(desired)>1.0:unit.steering_commit_left=0.0
	unit.wander_target=desired
	unit.wander_wait_left=0.0
