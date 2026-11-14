extends AnimatableBody3D
const D=preload("res://scripts/testing/metro_station/metro_dimensions.gd")
const STATION_CLIP=preload("res://scripts/testing/metro_station/metro_station_clip.gd")
signal phase_changed(phase: String)

const STOP_X:=0.0
const TUNNEL_X:=D.TUNNEL_TRAVEL
@export var journey_duration:=D.JOURNEY_TIME
var phase: String="DOCKED"
var door_fraction:=0.0
var doors_wanted_open:=false
var automatic:=false
var phase_time:=0.0
var journey_time:=0.0
var door_nodes: Array[Dictionary]=[]
var bridges: Array[Node3D]=[]
var wheels: Array[Node3D]=[]
var last_woken_body_count:=0
var rider_query: PhysicsShapeQueryParameters3D
var station_only:=false
var carriages: Array[Node3D]=[]
var gangways: Array[Node3D]=[]
var station_clip: RefCounted
var _last_slice_x := INF
var _last_slice_center := INF
var _last_slice_fraction := -1.0
var _last_slice_enabled := false
var _arrival_origin := TUNNEL_X
var stop_x := STOP_X
var boarding_bridge: Node3D

func _ready() -> void:
	sync_to_physics=true
	var friction:=PhysicsMaterial.new()
	friction.friction=1.0
	friction.rough=true
	physics_material_override=friction
	for node in find_children("*","AnimatableBody3D",true,false):
		if node.has_meta("slide"):
			door_nodes.append({"node":node,"closed":node.position,"slide":float(node.get_meta("slide")),"side":float(node.get_meta("side")),"car":node.get_parent()})
	for node in find_children("*","Node3D",true,false):
		if node.has_meta("bridge"):bridges.append(node)
		if node.has_meta("wheel"):wheels.append(node)
		if node.has_meta("carriage_index") and node.get_parent()==self:carriages.append(node)
		if node.has_meta("left_car"):gangways.append(node)
	var animator:=get_node_or_null("ExportAnimations") as AnimationPlayer
	if animator!=null:animator.active=false
	station_clip=STATION_CLIP.new(self)
	update_doors()
	update_station_visibility()
	var audio:=preload("res://scripts/testing/metro_station/metro_train_audio.gd").new()
	audio.name="TrainAudio"
	add_child(audio)

func request_doors(open: bool) -> bool:
	if phase!="DOCKED":return false
	doors_wanted_open=open
	return true

func request_depart() -> bool:
	if phase!="DOCKED":return false
	doors_wanted_open=false
	change_phase("CLOSING")
	return true

func request_arrive(from_x: float = TUNNEL_X, dock_x := STOP_X, only_bridge: Node3D = null) -> bool:
	if phase!="AWAY":return false
	_arrival_origin = from_x
	stop_x = dock_x
	boarding_bridge = only_bridge
	position.x = from_x
	wake_riders()
	journey_time=0
	change_phase("ARRIVING")
	return true

func change_phase(value: String) -> void:
	phase=value
	phase_time=0
	phase_changed.emit(phase)

func reset_to_station() -> void:
	phase="DOCKED";phase_time=0;journey_time=0
	doors_wanted_open=false;door_fraction=0
	stop_x=STOP_X
	boarding_bridge=null
	position.x=STOP_X
	update_doors()
	update_station_visibility()
	phase_changed.emit(phase)

func _physics_process(delta: float) -> void:
	if get_tree().paused:return
	phase_time+=delta
	var next_fraction := move_toward(door_fraction, 1.0 if doors_wanted_open else 0.0, delta / .75)
	if next_fraction != door_fraction:
		door_fraction = next_fraction
		update_doors()
	var previous_x := position.x
	if phase=="CLOSING" and door_fraction<=.0001:
		wake_riders()
		journey_time=0;change_phase("DEPARTING")
	elif phase in ["DEPARTING","ARRIVING"]:
		wake_riders()
		journey_time=minf(journey_duration,journey_time+delta)
		var t:=journey_time/journey_duration
		var smooth:=t*t*t*(t*(t*6.0-15.0)+10.0)
		position.x=lerpf(stop_x,TUNNEL_X,smooth) if phase=="DEPARTING" else lerpf(_arrival_origin,stop_x,smooth)
		if journey_time>=journey_duration:
			if phase=="DEPARTING":change_phase("AWAY")
			else:
				position.x=stop_x
				change_phase("DOCKED")
				doors_wanted_open=true
	if position.x != previous_x:
		for wheel in wheels:
			wheel.rotation.z = position.x / .25
	if automatic:
		if phase=="DOCKED":
			if phase_time<2.5:doors_wanted_open=true
			elif phase_time>4.0:request_depart()
		elif phase=="AWAY" and phase_time>2.0:request_arrive()

func _process(_delta: float) -> void:
	# AnimatableBody3D commits its synchronized transform after physics.
	# Slice the committed pose before rendering, rather than the previous pose.
	update_station_visibility()

func wake_riders() -> void:
	# Resting rigid bodies can stay asleep on a horizontally moving platform.
	# Keep supported occupants awake during motion; very gentle initial
	# acceleration can otherwise let the physics server put them back to sleep.
	# Contact/friction does the carrying. Transforms and sleep eligibility stay
	# physics-owned, and normal sleeping resumes when the train stops.
	if rider_query==null:
		var volume:=BoxShape3D.new();volume.size=Vector3(D.TRAIN_LENGTH-.1,2.5,2.6)
		rider_query=PhysicsShapeQueryParameters3D.new()
		rider_query.shape=volume
		rider_query.exclude=[get_rid()]
		rider_query.collision_mask=0xFFFFFFFF
		rider_query.collide_with_areas=false
	rider_query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.35,0))
	last_woken_body_count=0
	for result in get_world_3d().direct_space_state.intersect_shape(rider_query,128):
		var body: Node=result.collider
		if body is RigidBody3D:
			body.sleeping=false
			last_woken_body_count+=1

func update_doors() -> void:
	var t:=door_fraction*door_fraction*(3.0-2.0*door_fraction)
	for data in door_nodes:
		var closed: Vector3=data.closed
		var selected: bool = (boarding_bridge == null or (data.car == boarding_bridge.get_parent()
			and signf(boarding_bridge.position.z) == float(data.side) and absf(closed.x - boarding_bridge.position.x) < .5))
		var local_t: float=t if selected and car_at_platform(data.car) else 0.0
		data.node.position=closed+Vector3(data.slide*local_t,0,data.side*minf(local_t*4.0,1.0)*.035)
	for bridge in bridges:
		bridge.visible=door_fraction>.90 and phase=="DOCKED" and car_at_platform(bridge.get_parent()) \
			and (boarding_bridge == null or bridge == boarding_bridge)
		for child in bridge.get_children():
			if child is CollisionShape3D:child.set_deferred("disabled",not bridge.visible)

func car_at_platform(car: Node3D) -> bool:
	return absf(position.x+car.position.x)+D.HALF_CAR<=D.STATION_HALF

func update_station_visibility() -> void:
	# Slice only the displayed geometry at fixed world-space station planes.
	# Keep all carriage roots, interiors, joint floors and physics continuous.
	var center_x := get_parent_node_3d().global_position.x
	var train_x := global_position.x
	if train_x == _last_slice_x and center_x == _last_slice_center and door_fraction == _last_slice_fraction and station_only == _last_slice_enabled:
		return
	_last_slice_x = train_x
	_last_slice_center = center_x
	_last_slice_fraction = door_fraction
	_last_slice_enabled = station_only
	for car in carriages:car.visible=true
	for joint in gangways:joint.visible=true
	if station_clip != null:
		station_clip.update(station_only, center_x - D.STATION_HALF, center_x + D.STATION_HALF)
