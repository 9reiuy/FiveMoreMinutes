extends SceneTree
const MOTION := preload("res://scripts/testing/h06_chapter/crawler_motion.gd")
const HOST := preload("res://tests/support/h06_crawler_motion_host.gd")
var checks: Array[Dictionary] = []
var motion: MOTION
var model: Node3D
var evidence := ""
var max_plant_drift := 0.0
var max_solve_error := 0.0
var max_ground_error := 0.0
var metrics: Array[Dictionary] = []

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	create_timer(55).timeout.connect(func(): push_error("H06_MOTION_TIMEOUT"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"label":label})
	print("PASS " if ok else "FAIL ", label)

func frames(n: int) -> void:
	for i in n: await physics_frame

func inspect_feet() -> void:
	for leg: Dictionary in motion.gait.legs:
		var ankle: Vector3 = leg.ankle.global_position
		if ankle.distance_to(leg.target)>max_solve_error+.025:
			print("JOINT_EXTENT ",leg.root.name," at=",model.position," error=",ankle.distance_to(leg.target)," swing=",leg.swing)
		max_solve_error = maxf(max_solve_error, ankle.distance_to(leg.target))
		if not leg.swing:
			max_plant_drift = maxf(max_plant_drift,ankle.distance_to(leg.plant))
			var plane := motion.gait.surface(ankle)
			var normal := Vector3(plane.y,plane.z,plane.w).normalized()
			max_ground_error = maxf(max_ground_error, absf((ankle.y-plane.x)*normal.y-leg.sole))

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	var host := HOST.new()
	root.add_child(host)
	model = load("res://art/Dream/H06/crawler_h06.glb").instantiate()
	host.add_child(model)
	model.scale = Vector3.ONE*1.44
	for anim: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false):
		anim.play(anim.get_animation_list()[0]); anim.seek(.25,true); anim.pause()
	model.position = Vector3(100,0,100)
	motion = MOTION.new()
	root.add_child(motion)
	motion.configure(host,model)
	check(motion.gait.legs.size()==6 and motion.get_child_count()>=20,"all six imported leg chains and chassis have real gameplay collision shapes")
	await frames(2)
	for i in 240:
		motion.move_toward_point(model.position+Vector3(0,0,6./60),1./60)
		inspect_feet()
		await physics_frame
	check(model.position.z>122.5,"swept body walks at the requested speed on open floor")
	check(motion.gait.total_steps>8,"alternating tripods perform repeated steps")
	metrics.append({"phase":"walk","joint":max_solve_error,"drift":max_plant_drift,"ground":max_ground_error,"unreachable":motion.gait.unreachable_feet})
	print("WALK_METRICS ",metrics[-1])
	check(max_plant_drift<.025 and max_solve_error<.025,"planted feet stay in world space and two-bone joints reach the feet")
	check(max_ground_error<.015,"support soles remain on the ground")
	var wall := StaticBody2D.new()
	wall.collision_layer = MOTION.ROAD_LAYER
	wall.position = Vector2(100,114)*32
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24,.4)*32
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	motion.teleport(Vector3(100,0,105),0)
	await frames(2)
	var hit := motion.move_and_collide(Vector2(0,35*32))
	motion.teleport(Vector3(motion.position.x/32,0,motion.position.y/32),0)
	check(hit!=null and model.position.z<112.0 and model.position.z>105,"high-speed sweep stops on the extended legs before passing through a solid wall")
	var stop := model.position
	for i in 60:
		motion.move_toward_point(model.position+Vector3(.04,0,.1),1./60)
		await physics_frame
	check(model.position.x>stop.x+1.2 and model.position.z<113,"contact slides along the obstacle instead of teleporting through it")
	motion.teleport(Vector3(58,3.5,12.5),PI)
	max_plant_drift=0; max_solve_error=0; max_ground_error=0
	for i in 200:
		motion.move_toward_point(model.position+Vector3(0,0,-2./60),1./60)
		inspect_feet()
		await physics_frame
	check(max_ground_error<.025 and max_solve_error<.04,"inclined ramp feet follow the real height and support normal")
	metrics.append({"phase":"ramp","joint":max_solve_error,"drift":max_plant_drift,"ground":max_ground_error,"unreachable":motion.gait.unreachable_feet})
	print("RAMP_METRICS ",metrics[-1])
	motion.teleport(Vector3(45.2,7,-5.5),-PI*.5)
	var landed_count := [0]
	motion.landed.connect(func(): landed_count[0]+=1)
	check(motion.begin_jump(Vector3(38,0,-5.5)),"jump starts from the existing hoist platform")
	check(not motion.begin_jump(Vector3.ZERO),"an active jump cannot be restarted midair")
	var min_crouch := 7.
	var apex := 7.
	var compressed := false
	var tucked := false
	var phases: Array[int] = []
	max_solve_error=0; max_plant_drift=0; max_ground_error=0
	for i in 300:
		if not phases.has(motion.jump): phases.append(motion.jump)
		motion.advance_jump(1./60)
		if motion.jump in [MOTION.Jump.CROUCH,MOTION.Jump.PUSH]:
			min_crouch = minf(min_crouch,model.position.y)
			inspect_feet()
		if motion.jump==MOTION.Jump.FLIGHT:
			apex = maxf(apex,model.position.y)
			tucked = tucked or motion.gait.legs[0].ankle.global_position.y-model.position.y>.55
			check(motion.collision_layer==0,"airborne robot does not leave an invisible ground-level blocker") if i==45 else null
		if motion.jump in [MOTION.Jump.COMPRESS,MOTION.Jump.RECOVER]:
			compressed = compressed or model.position.y<-.2
			inspect_feet()
		if motion.jump==MOTION.Jump.NONE: break
		await physics_frame
	check(phases.size()==5,"jump includes crouch, push-off, flight, impact compression and recovery")
	check(min_crouch<6.7 and apex>7.9 and tucked,"takeoff loads the legs, gains height and folds the feet in flight")
	check(compressed and landed_count[0]==1,"impact compresses the leg suspension and emits exactly one landing")
	check(model.position.distance_to(Vector3(38,0,-5.5))<.002 and absf(model.rotation.x)<.002,"recovery returns to a stable grounded stance at the destination")
	check(max_ground_error<.025 and max_solve_error<.045,"crouch and landing keep feet grounded without stretching disconnected joints")
	var weak: WeakRef = weakref(motion)
	motion.disable(); motion.queue_free(); host.queue_free(); wall.queue_free()
	await frames(3)
	check(weak.get_ref()==null and get_nodes_in_group(&"dream_enemies").is_empty(),"unload removes the physics body, proxies and enemy registrations")
	var failed := checks.filter(func(item): return not item.pass)
	FileAccess.open(evidence.path_join("motion-test.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"metrics":metrics,"max_joint_error":max_solve_error,"max_ground_error":max_ground_error,"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_MOTION_RESULT ",checks.size()," checks; failures=",failed.size())
	quit(0 if failed.is_empty() else 1)
