extends RefCounted
## One authoritative parcel snapshot for drawing, silhouettes and AI sight.
## The release mask still limits gas to reachable floor and source lifetime.
const CAPACITY:=280
const EYE_HEIGHT:=.65
const MIN_SIZE:=.10
const LOBE_SCALE:=.947
# Fast-response window, not a delay: return starts on the same physics tick.
const BODY_RECOVERY_TIME:=.75
const BODY_DAMPING:=14.0
const BODY_RETURN_RATE:=12.0
# Original eight lobes used to build cloud_mesh.res, in mesh-local space.
const LOBES:=[Vector4(0,0,0,.32),Vector4(-.34,-.08,.04,.26),Vector4(.33,.02,.12,.25),Vector4(-.12,.34,.04,.24),Vector4(.15,-.32,-.02,.22),Vector4(-.17,.06,-.33,.23),Vector4(.19,.24,-.19,.21),Vector4(.04,-.10,.33,.24)]
var controller:Node3D
var anchors:Image
var metadata:Image
var poses:Image
var points:=PackedVector3Array()
var homes:=PackedVector3Array()
var velocities:=PackedVector3Array()
var clearing:=PackedFloat32Array()
var body_recovery:=PackedFloat32Array()
var generations:=PackedInt32Array()
var seen_events:=PackedInt32Array()
var sizes:=PackedFloat32Array()
var sections:Array[PackedVector3Array]=[]
var buckets:Dictionary={}
var impulses:Array[Dictionary]=[]
var serial:=0

func configure(owner:Node3D,anchor_image:Image,meta_image:Image)->void:
	controller=owner
	anchors=anchor_image
	metadata=meta_image
	poses=Image.create(CAPACITY,1,false,Image.FORMAT_RGBAF)
	poses.fill(Color(0,0,0,0))
	points.resize(CAPACITY)
	homes.resize(CAPACITY)
	velocities.resize(CAPACITY)
	clearing.resize(CAPACITY)
	body_recovery.resize(CAPACITY)
	generations.resize(CAPACITY)
	seen_events.resize(CAPACITY)
	sizes.resize(CAPACITY)
	sections.resize(CAPACITY)

func sync_slots()->void:
	for index in CAPACITY:
		var anchor:=anchors.get_pixel(index,0)
		if anchor.a<=.001:
			generations[index]=0
			continue
		var generation:=int(metadata.get_pixel(index,0).b)
		var home:=Vector3(anchor.r,anchor.g,anchor.b)
		if generation==generations[index]:
			# Layout growth changes a parcel's fitted rest position. Carry
			# its existing disturbance with that frame instead of creating
			# an artificial, slowly recovering offset in untouched smoke.
			points[index]+=home-homes[index]
			homes[index]=home
			continue
		generations[index]=generation
		points[index]=home
		homes[index]=home
		velocities[index]=Vector3.ZERO
		clearing[index]=0.0
		body_recovery[index]=0.0
		seen_events[index]=serial

func push_impulse(from:Vector2,to:Vector2,radius:float,amount:float,velocity:Vector3,id:int,body_wake:=false)->void:
	serial=id
	impulses.append({"a":Vector3(from.x/32.0,.65,from.y/32.0),"b":Vector3(to.x/32.0,.65,to.y/32.0),"radius":radius,"amount":amount,"velocity":velocity,"id":id,"body_wake":body_wake})
	if impulses.size()>32:impulses.pop_front()

func _coverage(point:Vector3)->float:
	var cell:=Vector2i(Vector2(point.x,point.z).round())
	return float(controller.cells.get(cell,0.0))

func advance(delta:float)->void:
	# GPU consumes this snapshot instead of simulating an independent field.
	# A body parts the existing puffs and quickly releases its wake; shots
	# retain the original dispersal and source-mask clearing behavior.
	var dt:=clampf(delta,0.0,.05)
	buckets.clear()
	for index in CAPACITY:
		sections[index]=PackedVector3Array()
		var anchor:=anchors.get_pixel(index,0)
		if anchor.a<=.001:
			sizes[index]=0.0
			poses.set_pixel(index,0,Color(0,0,0,0))
			continue
		var meta:=metadata.get_pixel(index,0)
		var home:=Vector3(anchor.r,anchor.g,anchor.b)
		var point:=points[index]
		var wake:=maxf(0.0,body_recovery[index]-dt)
		var velocity:=velocities[index]*exp(-dt*(BODY_DAMPING if wake>0.0 else 1.8))
		var removed:float=clearing[index]*exp(-dt*1.2)
		for impulse in impulses:
			if int(impulse.id)<=seen_events[index]:continue
			var segment:Vector3=Vector3(impulse.b)-Vector3(impulse.a)
			var along:=clampf((point-Vector3(impulse.a)).dot(segment)/maxf(.00001,segment.length_squared()),0.0,1.0)
			var offset:Vector3=point-Vector3(impulse.a)-segment*along
			offset.y*=.4
			var weight:=exp(-offset.length_squared()*2.0/maxf(.001,float(impulse.radius)*float(impulse.radius)))
			var flow:Vector3=impulse.velocity
			if bool(impulse.body_wake):
				# Do not accumulate tiny body forces outside the local wake;
				# those parcels would otherwise retain the slow shot response.
				if weight<=.02:continue
				wake=BODY_RECOVERY_TIME
				# Push sideways around the body instead of deleting the cloud.
				var lateral:=Vector3(offset.x,0,offset.z)
				if lateral.length_squared()<.0001:lateral=Vector3(-flow.z,0,flow.x)
				flow=lateral.normalized()*minf(3.0,flow.length())+flow*.15
			velocity+=flow*weight
			removed=1.0-(1.0-removed)*exp(-float(impulse.amount)*weight)
		seen_events[index]=serial
		velocity=velocity.clamp(Vector3.ONE*-6.0,Vector3.ONE*6.0)
		var quiet:=1.0 if wake>0.0 else exp(-velocity.length()*5.0)
		var return_rate:=BODY_RETURN_RATE if wake>0.0 else .26
		var move:Vector3=(velocity*.8+(home-point)*return_rate*quiet)*dt
		move=move.limit_length(.35)
		for step in 6:
			var goal:=point+move/6.0
			var offset:=Vector2(goal.x-home.x,goal.z-home.z)
			var limit:=maxf(0.0,meta.a-.12)
			if wake>0.0:
				# Retain at least 80% of each fitted puff near walls/edges.
				var rest_radius:=minf(anchor.a*.58,minf(meta.a,minf(home.y-.04,2.8-home.y-.04)))
				limit=minf(.40,maxf(0.0,meta.a-rest_radius*.80))
			offset=offset.limit_length(limit)
			goal.x=home.x+offset.x
			goal.z=home.z+offset.y
			goal.y=clampf(goal.y,.16,2.6)
			if _coverage(goal)>.05:point=goal
		points[index]=point
		velocities[index]=velocity
		clearing[index]=removed
		body_recovery[index]=wake
		var radius:=minf(maxf(0.0,meta.a-Vector2(point.x-home.x,point.z-home.z).length()),minf(point.y-.04,2.8-point.y-.04))
		var size:=minf(anchor.a,maxf(0.0,radius)/.58)*sqrt(clampf(_coverage(point),0.0,1.0))*(1.0-clampf(removed,0.0,1.0))
		if size<MIN_SIZE:size=0.0
		sizes[index]=size
		poses.set_pixel(index,0,Color(point.x,point.y,point.z,size))
		if size==0.0:continue
		_build_sections(index,point,size,meta.r)
	impulses.clear()

func _build_sections(index:int,point:Vector3,size:float,yaw:float)->void:
	var scale:=size*LOBE_SCALE
	var c:=cos(yaw)
	var s:=sin(yaw)
	var cross_sections:=PackedVector3Array()
	for lobe:Vector4 in LOBES:
		var dy:float=EYE_HEIGHT-point.y-lobe.y*scale
		var radius_squared:float=pow(lobe.w*scale,2.0)-dy*dy
		if radius_squared<=0.0:continue
		cross_sections.append(Vector3(point.x+(c*lobe.x+s*lobe.z)*scale,point.z+(-s*lobe.x+c*lobe.z)*scale,radius_squared))
	sections[index]=cross_sections
	if cross_sections.is_empty():return
	var reach:=.58*size
	var low:=Vector2i(Vector2(point.x-reach,point.z-reach).floor())
	var high:=Vector2i(Vector2(point.x+reach,point.z+reach).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key:=Vector2i(x,y)
			if not buckets.has(key):buckets[key]=[]
			buckets[key].append(index)

func contains(point:Vector2)->bool:
	var at:=point/32.0
	for index:int in buckets.get(Vector2i(at.floor()),[]):
		for circle:Vector3 in sections[index]:
			if at.distance_squared_to(Vector2(circle.x,circle.y))<circle.z:return true
	return false

func blocks_sight(from:Vector2,to:Vector2)->bool:
	var a:=from/32.0
	var b:=to/32.0
	var candidates:Dictionary={}
	var steps:=maxi(1,ceili(a.distance_to(b)*2.0))
	# Supercover bins include grazing segments along bin boundaries.
	for step in range(steps+1):
		var cell:=Vector2i(a.lerp(b,float(step)/steps).floor())
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for index:int in buckets.get(Vector2i(x,y),[]):candidates[index]=true
	for index:int in candidates:
		for circle:Vector3 in sections[index]:
			var center:=Vector2(circle.x,circle.y)
			var nearest:=Geometry2D.get_closest_point_to_segment(center,a,b)
			if nearest.distance_squared_to(center)>=circle.z:continue
			if float(controller.cells.get(Vector2i(nearest.round()),0.0))>.05:return true
	return false
