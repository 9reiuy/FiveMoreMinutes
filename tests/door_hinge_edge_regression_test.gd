extends SceneTree
const DOOR := preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	# Another local diagnostic autoload may coexist in a dirty project. Disable
	# it in this test process only; never edit its source or project registration.
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	AudioServer.set_bus_mute(0,true)
	var map := Node3D.new()
	root.add_child(map)
	map.rotation.y = PI*.25
	var collisions := Node2D.new()
	root.add_child(collisions)
	var suspension_owner = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	for style: StringName in [&"single",&"double"]:
		for yaw in [0.0, PI*.5]:
			var door: PhysicalDoor3D = DOOR.instantiate()
			door.configure(2.0,2.6,.18,"left",1,style)
			door.position = Vector3(5,0,5)
			door.rotation.y = yaw
			door.set_meta(&"office_metal_door",true)
			map.add_child(door)
			door.configure_gameplay_collision(collisions)
			await frames(2)
			for index in range(1 if style==&"single" else 2):
				var leaf: RigidBody3D = door._leaves[index]
				var anchor: StaticBody3D = door._anchors[index]
				var side := 1.0 if index==0 else -1.0
				var edge := Vector3(side*door.leaf_width*.5,0,0)
				var fixed := anchor.global_position
				var center := leaf.global_position
				check((leaf.global_transform*edge).distance_to(fixed)<.001,"Closed hinge edge matches anchor")
				var force_direction := -door.global_basis.z
				door.apply_door_impact(&"player_push",leaf.global_position,force_direction,260.0,&"",index)
				var drift := 0.0
				var movement := 0.0
				var max_angle := 0.0
				for i in 45:
					await frames(1)
					drift = maxf(drift,(leaf.global_transform*edge).distance_to(fixed))
					movement = maxf(movement,leaf.global_position.distance_to(center))
					max_angle = maxf(max_angle,absf(leaf.rotation.y))
				print("HINGE_EDGE style=",style," yaw=",yaw," leaf=",index," drift=",drift," center_move=",movement," angle=",max_angle)
				check(drift<.025,"Hinge edge stays fixed, not just constant center radius")
				check(movement>door.leaf_width*.1,"Leaf center travels around hinge rather than spinning in place")
				check(max_angle>.1,"Door actually opens during probe")
				suspension_owner._suspend_cab_floor_node(door)
				check(leaf.freeze and leaf.collision_layer==0 and not door.can_process(),"Loading still freezes and disables collisions")
				await frames(1) # Commit the freeze before checking stationary pose.
				var suspended_pose := leaf.global_transform
				await frames(3)
				check(leaf.global_transform.is_equal_approx(suspended_pose),"Registered hinge cannot move while loading")
				suspension_owner._set_floor_runtime_suspended_for_cab(false)
				door.apply_door_impact(&"enemy_push",leaf.global_position,force_direction,260.0,&"",index)
				var resumed_drift := 0.0
				for i in 25:
					await frames(1)
					resumed_drift = maxf(resumed_drift,(leaf.global_transform*edge).distance_to(fixed))
				check(resumed_drift<.025,"Single/double rotated door retains jamb hinge after resume")
				check(door._collision_bodies[index].global_position.distance_to(door.get_leaf_center_2d(index))<.02,"Resumed 2D collision follows leaf")
			door.queue_free()
			await frames(2)
	map.free()
	collisions.free()
	suspension_owner.free()
	await frames(2)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	check(world.regenerate(42001),"Formal floor generates")
	world.set_process(false)
	world.player.set_physics_process(false)
	await frames(2)
	var probes: Array[Dictionary] = []
	for generated in world.door_root.get_children():
		if not generated is PhysicalDoor3D or generated.locked: continue
		for index in range(1 if generated.door_style==&"single" else 2):
			var leaf: RigidBody3D = generated._leaves[index]
			var anchor: StaticBody3D = generated._anchors[index]
			var edge := Vector3((1.0 if index==0 else -1.0)*generated.leaf_width*.5,0,0)
			probes.append({"door":generated,"leaf":leaf,"fixed":anchor.global_position,"edge":edge,"drift":0.0})
			generated.apply_door_impact(&"kick",leaf.global_position,-generated.global_basis.z,1200.0,&"",index)
	for i in 90:
		await frames(1)
		for probe in probes:
			probe.drift = maxf(float(probe.drift),(probe.leaf.global_transform*probe.edge).distance_to(probe.fixed))
	for probe in probes:
		print("FORMAL_HINGE ",probe.door.name," style=",probe.door.door_style," width=",probe.door.leaf_width," drift=",probe.drift)
		check(float(probe.drift)<.025,"Formal combat hinge edge stays attached: "+String(probe.door.name))
	check(await world._regenerate_staged(42002,world.floor_index+1,world.transition_generation_token),"Staged next floor generates")
	world._set_floor_runtime_suspended_for_cab(true)
	await frames(5)
	world._set_floor_runtime_suspended_for_cab(false)
	await frames(3)
	probes.clear()
	for generated in world.door_root.get_children():
		if not generated is PhysicalDoor3D or generated.locked: continue
		for index in range(1 if generated.door_style==&"single" else 2):
			var leaf: RigidBody3D = generated._leaves[index]
			var anchor: StaticBody3D = generated._anchors[index]
			var edge := Vector3((1.0 if index==0 else -1.0)*generated.leaf_width*.5,0,0)
			probes.append({"door":generated,"leaf":leaf,"fixed":anchor.global_position,"edge":edge,"drift":0.0})
			generated.apply_door_impact(&"player_push",leaf.global_position,-generated.global_basis.z,260.0,&"",index)
	for i in 60:
		await frames(1)
		for probe in probes:
			probe.drift = maxf(float(probe.drift),(probe.leaf.global_transform*probe.edge).distance_to(probe.fixed))
	for probe in probes:
		print("CROSS_FLOOR_HINGE ",probe.door.name," drift=",probe.drift)
		check(float(probe.drift)<.025,"Cab-restored hinge edge stays attached: "+String(probe.door.name))
	world.free()
	await frames(2)
	print("DOOR_HINGE_EDGE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
