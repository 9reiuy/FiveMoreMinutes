extends RefCounted
## Authored ground routes skirt the empty bay, then use the passage behind the hatch.
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const DESTINATIONS:Array[Vector2]=[Vector2(13.2,.65),Vector2(14.1,1.50),Vector2(13.2,2.35)]
const ROUTES:Array=[
	[Vector2(-6.2,6.65),Vector2(2.8,6.65),Vector2(3.12,3.5),Vector2(3.3,1.50),Vector2(7.8,1.50),Vector2(10.5,1.50)],
	[Vector2(2.8,-1.35),Vector2(3.3,1.50),Vector2(4.6,1.50),Vector2(7.8,1.50),Vector2(10.5,1.50)],
	[Vector2(2.8,4.40),Vector2(3.3,1.50),Vector2(4.6,1.50),Vector2(7.8,1.50),Vector2(10.5,1.50)]]
var crew:Node3D
var art
var age:=0.0
var started:=false
var finished:=false
var routes:Array[Dictionary]=[]

func bind(owner_crew:Node3D,owner_art)->void:
	crew=owner_crew
	art=owner_art
	for index in crew.actors.size():
		var points:Array[Vector2]=[]
		for point:Vector2 in ROUTES[index]:points.append(point*32.0)
		points.append(DESTINATIONS[index]*32.0)
		routes.append({"points":points,"index":0,"arrived":false,"facing":Vector2.RIGHT})
	if crew.world.staff_story.crew_escaped:
		finished=true
		for index in crew.actors.size():
			crew.actors[index].position=DESTINATIONS[index]*32.0
			routes[index].arrived=true
			_pose(index,Vector2.LEFT,false)

func start()->void:
	if started:return
	started=true
	crew.world.discovered=true
	art.open_hatch(true)
	art.service_view(crew.world.on_lower_floor,crew.world._feet())
	sync_room_visibility(art.secret_visible)

func advance(delta:float)->void:
	if not started:return
	age+=delta
	var speed:float=crew.world.config.employee_movement_speed*crew.world.config.employee_run_speed_multiplier
	for index in crew.actors.size():
		var route:Dictionary=routes[index]
		var actor:EmployeeEnemy=crew.actors[index]
		if route.arrived:
			_pose(index,Vector2.LEFT,false)
			actor._update_enemy_blink(delta)
			continue
		if age<index*.36+.12:continue
		var budget:=speed*delta
		var direction:Vector2=route.facing
		while budget>0.0 and not route.arrived:
			var target:Vector2=route.points[route.index]
			var distance:=actor.position.distance_to(target)
			if distance<=.01:
				route.index+=1
				if int(route.index)>=route.points.size():route.arrived=true
				continue
			direction=actor.position.direction_to(target)
			route.facing=direction
			var step:=minf(budget,distance)
			actor.position+=direction*step
			budget-=step
		_pose(index,direction,not route.arrived)
		actor._update_enemy_blink(delta)
	sync_room_visibility(art.secret_visible)
	if not finished and routes.all(func(route:Dictionary):return bool(route.arrived)):
		finished=true
		crew.world.staff_story.crew_escaped=true

func sync_room_visibility(revealed:bool)->void:
	for index in crew.bridges.size():
		var feet: Vector2 = crew.actors[index].position / crew.world.CELL_PIXELS
		crew.bridges[index].visible = revealed or not PLAN.behind_service_roof(feet)

func _pose(index:int,direction:Vector2,running:bool)->void:
	var actor:EmployeeEnemy=crew.actors[index]
	actor.work_activity.reset_pose()
	actor.pose_escape_run(direction,age*15.0+index*1.7,running)
