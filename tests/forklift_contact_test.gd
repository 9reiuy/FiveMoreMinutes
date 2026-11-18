extends "res://tests/forklift_combat_test.gd"
## Real swept contacts in whitebox and production-art lab; same fixtures for the old controller.
var baseline := false
var observations: Array[Dictionary] = []
var obstacle_visuals: Array[Node3D] = []

func setup_vehicle(at: Vector2) -> void:
	var model := MODEL.new()
	model.position = Vector3(at.x, 0, at.y)
	world.add_child(model)
	var controller: Script = load("res://.runtime/forklift_collision_20261117/baseline_movement.gd") if baseline else VEHICLE
	lift = controller.new()
	lift.configure(world, model)
	lift.contact_response_enabled = not baseline
	if baseline:
		lift.wall_min_slide_angle = deg_to_rad(15)
		lift.max_slides = 4
	lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5,14.5,13,9).has_point(p)
	world.collision_root.add_child(lift)
	lift.set_active(true)
	place_feet(at + Vector2(-0.13,1.2))
	await frames(4)
	check(lift.board(world.player), "contact fixture boards with the original model")

func obstacle(rect: Rect2) -> StaticBody2D:
	var body := block(rect)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x,1.4,rect.size.y)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("646e75")
	material.roughness = 1.0
	mesh.material_override = material
	world.add_child(mesh)
	mesh.position = Vector3(rect.get_center().x,0.7,rect.get_center().y)
	obstacle_visuals.append(mesh)
	return body

func clear_fixture(objects: Array[Node] = []) -> void:
	for node in objects:
		if is_instance_valid(node): node.queue_free()
	for node in obstacle_visuals:
		if is_instance_valid(node): node.queue_free()
	obstacle_visuals.clear()
	park(Vector2(4,18.5))
	await frames(3)

func contact_frame(limit := 90) -> bool:
	for i in limit:
		await physics_frame
		if lift.get_slide_collision_count() > 0: return true
	return false

func wall_case(label: String, entry_speed: float, reverse := false) -> float:
	park(Vector2(4,18.5))
	var wall := obstacle(Rect2(2.3 if reverse else 7.0,14.5,0.18,9.0))
	await frames(3)
	lift.speed = -entry_speed if reverse else entry_speed
	if entry_speed > VEHICLE.FORWARD_SPEED: lift.boost_left = VEHICLE.BOOST_DURATION
	Input.action_press("move_down" if reverse else "move_up")
	begin_trace()
	var touched := await contact_frame()
	var recoil: float = lift.velocity.x / 32.0
	observations.append({"label":label,"entry_mps":entry_speed,"reverse":reverse,"velocity":lift.velocity/32,"position":lift.global_position/32})
	check(touched, label + " produces an actual swept contact")
	if not baseline:
		check(recoil > 0.2 if reverse else recoil < -0.2, label + " rebounds away from the wall instead of clearing momentum")
		check(absf(recoil) < entry_speed * 0.3, label + " hard contact dissipates most normal energy")
		check(absf(lift._impact_pitch) > 0.001, label + " contact gives a small directional chassis response")
		if entry_speed > VEHICLE.FORWARD_SPEED: check(lift.boost_left == 0, label + " major crash interrupts boost")
		var fx: Node3D = world._firearm_fx()
		check(not fx._hot_particles.is_empty(), label + " actual contact emits the shared muzzle-style sparks")
		check(fx._hot_particles.size() <= fx.HOT_LIMIT and fx.find_children("*","Light3D",true,false).is_empty(), label + " sparks stay in the bounded pool without adding lights")
		var count: int = fx._hot_particles.size()
		var rng_state: int = world._content_rng.state
		lift._emit_contact_sparks({"point":lift.global_position,"normal":Vector2.LEFT,"strength":1.0})
		check(fx._hot_particles.size() == count and world._content_rng.state == rng_state, label + " sustained contact is throttled and leaves combat randomness alone")
	await capture(label + "-first-contact")
	await frames(24)
	end_trace(label)
	var bounds: Rect2 = lift.get_obstacle_rect()
	check(bounds.position.x >= 2.40 if reverse else bounds.end.x <= 7.10, label + " cannot tunnel through the wall")
	check(lift._supported(lift.global_transform), label + " stays over supported floor")
	await clear_fixture([wall])
	return absf(recoil)

func grazing_case(label: String) -> void:
	park(Vector2(4,20.5), -PI/3)
	var wall := obstacle(Rect2(6.2,14.5,0.18,9.0))
	await frames(3)
	lift.speed = VEHICLE.FORWARD_SPEED
	Input.action_press("move_up")
	begin_trace()
	var touched := await contact_frame(60)
	var at: Vector2 = lift.global_position
	var retained: float = lift.velocity.length()/32.0
	check(touched, label + " grazes the actual wall")
	if not baseline: check(retained > 5.0, label + " preserves useful tangential momentum")
	await frames(6)
	if not baseline: check((at.y-lift.global_position.y)/32.0 > 0.35, label + " continues sliding along the wall")
	check(lift.global_position.x/32.0 < 6.2 and lift._supported(lift.global_transform), label + " remains on the correct side and over floor")
	observations.append({"label":label,"retained_mps":retained,"slide_metres":(at.y-lift.global_position.y)/32.0})
	end_trace(label)
	await capture(label)
	await clear_fixture([wall])

func prop_case(label: String, mass: float, prop_speed := 0.0, frozen := false) -> Dictionary:
	park(Vector2(4,18.5))
	var prop := RigidBody2D.new()
	prop.add_to_group(&"pushable_prop")
	prop.mass = mass
	prop.gravity_scale = 0
	prop.lock_rotation = true
	prop.freeze = frozen
	prop.collision_layer = 8
	prop.collision_mask = 1|2|4|8
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(0.6,1.6)*32
	shape.shape = box
	prop.add_child(shape)
	world.furniture_root.add_child(prop)
	prop.global_position = Vector2(7.0,18.5)*32
	await frames(4)
	prop.linear_velocity = Vector2(prop_speed*32,0)
	var start: Vector2 = prop.global_position
	lift.speed = 8.0
	Input.action_press("move_up")
	begin_trace()
	var touched := await contact_frame(90)
	var speed_after: float = lift.velocity.x/32
	check(touched, label + " contacts a physical body")
	await frames(3)
	var result := {"label":label,"mass":mass,"prop_entry_mps":prop_speed,"vehicle_after_mps":speed_after,"prop_after_mps":prop.linear_velocity.x/32,"prop_travel_m":(prop.global_position-start).length()/32}
	observations.append(result)
	if not baseline:
		if frozen:
			check(prop.global_position.is_equal_approx(start) and speed_after < 0.0, label + " fixed props stay fixed and return a collision reaction")
		else:
			check(prop.linear_velocity.x > 15.0 and result.prop_travel_m > 0.02, label + " transfers impulse to the movable prop")
			check(speed_after > 0.0, label + " heavier vehicle keeps forward motion")
	end_trace(label)
	await clear_fixture([prop])
	return result

func real_chair_case(label: String) -> void:
	park(Vector2(4,18.5))
	var chair: RigidBody2D = load("res://scenes/dream/props/office_chair_01.tscn").instantiate()
	world.furniture_root.add_child(chair)
	chair.global_position = Vector2(7,18.5)*32 - chair.get_node("CollisionShape2D").position
	var visual: Node3D = world._spawn_furniture_presentation(chair)
	await frames(4)
	var start: Vector2 = chair.global_position
	lift.speed = 8.0
	Input.action_press("move_up")
	var touched := await contact_frame()
	await frames(8)
	check(touched, label + " contacts the existing authored office chair")
	if not baseline: check(chair.global_position.distance_to(start) > 8.0, label + " existing furniture impulse API moves the visible chair")
	await capture(label)
	await clear_fixture([chair,visual])

func run() -> void:
	create_timer(200,true,false,true).timeout.connect(func(): quit(3))
	baseline = OS.get_environment("FORKLIFT_CONTACT_BASELINE") == "1"
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world: break
	check(lab.ready_world,"independent contact lab loads")
	verify_audio()
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = false
	for mode in [0,1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		await setup_vehicle(Vector2(4,18.5))
		var label := "whitebox" if mode == 0 else "production-art"
		var slow := await wall_case(label+"-wall-slow",4.0)
		var fast := await wall_case(label+"-wall-boost",18.0)
		if not baseline: check(fast > slow*2, label + " faster collision gives a stronger reaction")
		await wall_case(label+"-reverse-wall",4.8,true)
		await grazing_case(label+"-grazing")
		var light := await prop_case(label+"-light",1.0)
		var heavy := await prop_case(label+"-heavy",24.0)
		if not baseline: check(light.vehicle_after_mps > heavy.vehicle_after_mps+1.0, label + " heavy obstacles absorb more vehicle momentum than light ones")
		await prop_case(label+"-moving-prop",1.0,2.0)
		await prop_case(label+"-fixed-prop",1.0,0.0,true)
		await real_chair_case(label+"-authored-chair")
		park(Vector2(4,18.5))
		await sample(label+"-parked")
		await sample(label+"-driving",true)
		check(lift.try_exit(),label+" driver can dismount after collisions")
		check(lift._impact_yaw_velocity == 0 and lift._impact_pitch == 0 and lift._impact_lean == 0,label+" dismount clears collision reaction state")
		var old: WeakRef = weakref(lift)
		await lab.rebuild()
		check(not is_instance_valid(old.get_ref()),label+" reset releases the vehicle and its contact state")
	lab.queue_free()
	await frames(4)
	verify_audio()
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"baseline":baseline,"checks":checks,"failures":failures,"metrics":metrics,"contacts":observations,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"scope":"Real swept whitebox and production-art contacts. Bounded raw frame samples, not whole-game performance certification."},"\t"))
	print("FORKLIFT_CONTACT checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
