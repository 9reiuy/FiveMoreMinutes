extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func ticks(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func inside_or_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in polygon.size():
		if Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(point)<.05: return true
	return false
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	var previous_sensor: WeakRef
	for seed_value in [42001,42002,42003]:
		check(world.regenerate(seed_value),"Formal floor generated")
		await ticks(4)
		if previous_sensor != null: check(previous_sensor.get_ref()==null,"Old floor corpse contact sensor released")
		world.player.set_physics_process(false)
		var anchor: Vector2 = world.player.global_position
		var enemy = world._spawn_regular_employee(world.current_room_id,anchor+Vector2(30,-20),&"employee",false,"luger")
		enemy.take_damage(999,Vector2.RIGHT,50,&"rifle")
		enemy.set_process(false)
		for i in 120: enemy._update_death_presentation(1.0/60)
		check(enemy.death_landed,"Formal corpse landed")
		var sensor = enemy.corpse_contact
		await ticks(2) # The real sensor shape is installed outside physics callbacks.
		previous_sensor = weakref(sensor)
		sensor._physics_process(1.0/60)
		check(sensor.projected_to_floor,"Formal corpse footprint uses official camera-to-floor mapping")
		var points := PackedVector2Array()
		sensor._part_points(enemy.character_visual,points,enemy.character_visual.global_transform.affine_inverse(),0.0)
		var local_points := PackedVector2Array()
		for point in points: local_points.append(enemy.character_visual.transform*point)
		var bridge: Node = enemy.get_meta(&"depth_visual_bridge").get_ref()
		var projected: PackedVector2Array = bridge.project_corpse_contact_points(local_points)
		var covered := not projected.is_empty()
		var missed := 0
		for point in projected:
			var inside := inside_or_edge(sensor.to_local(enemy.to_global(point)),sensor.contact_shape.shape.points)
			if not inside: missed += 1
			covered = covered and inside
		print("CORPSE_FOOTPRINT raw=",points.size()," projected=",projected.size()," hull=",sensor.contact_shape.shape.points.size()," missed=",missed," sleeping=",not enemy.ragdoll_active)
		check(covered,"Head, torso, hand and foot bounds all lie inside full-body footprint")
		world.player.global_position = anchor-Vector2(80,0)
		var chair = load("res://scenes/dream/props/office_chair_01.tscn").instantiate()
		world.furniture_root.add_child(chair)
		chair.global_position = sensor.global_position-Vector2(10,0)
		chair.linear_velocity = Vector2(180,0)
		enemy.death_ground_velocity = Vector2.ZERO
		await ticks(4)
		check(enemy.death_ground_velocity.length()>0,"Real moving office-chair overlap pushes corpse")
		check(enemy.ragdoll_active,"Actual furniture contact wakes joints")
		# Stashing must stop child contacts too, and rollback preserves the same corpse.
		var old_index: int = world.floor_index
		world._stash_current_floor_for_rollback()
		check(not sensor.can_process(),"Stashed floor sensor stops processing")
		world._rollback_failed_transition(world.transition_generation_token,old_index)
		check(is_instance_valid(enemy) and sensor.can_process(),"Rollback restores same corpse and contact sensor")
	world.free()
	await ticks(4)
	check(previous_sensor.get_ref()==null,"Last floor shutdown releases sensor")
	print("CORPSE_CONTACT_WORLD checks=",checks," failures=",failures)
	quit(1 if failures else 0)
