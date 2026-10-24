extends SceneTree
## 楼层内送餐机器人 / 楼层外巡逻无人机：3D 模型 + 血条 + 受击体积 + 射击 + 独立移动。
##
## 关键回归点：敌人的受击体积是独立 Hurtbox（layer 16，组 damage_hurtboxes），
## 因为 basic_projectile 的射线掩码是 1|4|8|16，不含 body 所在的 layer 2。

const WORLD_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CELL_PIXELS := 32.0

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[FAIL] " + label)
	else:
		print("[PASS] ", label)


func _run() -> void:
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	var world := WORLD_SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await process_frame
	_check(world.regenerate(90210), "floor generated")
	await process_frame
	await physics_frame

	_check(world.player != null, "player exists")
	var room_id := _pick_room(world)
	_check(room_id >= 0, "found a combat room (%d)" % room_id)
	if room_id < 0:
		_finish()
		return

	await _check_hotel_robot(world, room_id)
	await _check_exterior_drone(world)
	_finish()


func _pick_room(world: Node3D) -> int:
	for room in world.rooms:
		var id := int(room["id"])
		if id == int(world.spawn_room_id) or id == int(world.boss_room_id):
			continue
		if not bool(world.call("_is_combat_room", room)):
			continue
		return id
	return -1


func _check_hotel_robot(world: Node3D, room_id: int) -> void:
	world.current_room_id = room_id
	var visuals: Node3D = world.call("_hotel_robot_visual_container")
	_check(visuals != null, "robot visual container exists")
	var center: Vector2i = world.rooms[room_id]["center_cell"]
	var spawn_position := (Vector2(center) + Vector2(0.5, 0.5)) * CELL_PIXELS
	var spawned := bool(world.call("_spawn_hotel_robot", room_id, spawn_position, visuals))
	_check(spawned, "hotel robot spawned")
	await process_frame
	await physics_frame

	var unit: Node = null
	for child in world.enemy_root.get_children():
		if String(child.name).begins_with("HotelDeliveryRobot"):
			unit = child
			break
	_check(unit != null, "hotel robot body exists in gameplay world")
	if unit == null:
		return

	_check(unit is CharacterBody2D, "hotel robot is a Player-collidable 2D body")
	_check(unit.is_in_group(&"dream_enemies"), "hotel robot is in dream_enemies (player bullets can resolve hits)")

	var hurtbox := unit.get_node_or_null("Hurtbox") as Area2D
	_check(hurtbox != null, "hotel robot owns a Hurtbox Area2D")
	if hurtbox != null:
		_check(hurtbox.collision_layer == 16, "hurtbox is on layer 16 (projectile mask 1|4|8|16)")
		_check(hurtbox.is_in_group(&"damage_hurtboxes"), "hurtbox is in damage_hurtboxes")
		_check(hurtbox.has_method("get_damage_owner"), "hurtbox resolves damage owner")
		_check(hurtbox.get_damage_owner() == unit, "hurtbox damage owner is the robot body")
		var shape := hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_check(shape != null and shape.shape is CapsuleShape2D, "hurtbox has a capsule volume")
		if shape != null and shape.shape is CapsuleShape2D:
			var capsule := shape.shape as CapsuleShape2D
			_check(is_equal_approx(capsule.radius,16.0*2.0/3.0) and is_equal_approx(capsule.height,32.0*2.0/3.0) and shape.position==Vector2.ZERO,
				"hurtbox is in the gameplay floor plane (r=%.0f h=%.0f)" % [capsule.radius, capsule.height])

	# 3D 模型确实上了场，并且跟随 2D 实体。
	_check(visuals.get_child_count() == 1, "one 3D robot model in the scene")
	var visual := visuals.get_child(0) as Node3D
	_check(visual != null, "3D robot visual node exists")

	# Machine enemies now communicate damage by hit flash, never a health bar.
	var bar: Node3D = unit.get("health_bar_3d")
	_check(bar == null, "hotel robot no longer creates a health bar")
	if bar != null:
		_check(bar.get_parent() == visual, "3D health bar is attached to the robot visual")
		_check(bar.has_method("redraw"), "3D health bar can redraw")

	if visual != null:
		_check(visual.get_node_or_null("RobotModel") != null, "3D robot model built")
		_check(visual.get_node_or_null("RobotModel/WeaponRig") != null, "3D robot carries the deployable weapon rig")
		var expected: Vector3 = world.to_global(Vector3(
			spawn_position.x / CELL_PIXELS, 0.0, spawn_position.y / CELL_PIXELS))
		_check(visual.global_position.distance_to(expected) < 0.05,
			"3D model sits on the 2D robot position (%.2f)" % visual.global_position.distance_to(expected))

	# 受击 / 掉血 / 死亡。
	var hp_before := float(unit.get("hp"))
	var result: Dictionary = world.resolve_player_hit(unit, 15.0, unit.global_position)
	_check(not result.is_empty(), "resolve_player_hit accepts the robot")
	_check(float(unit.get("hp")) < hp_before, "robot loses HP when shot")
	if hurtbox != null:
		var proxy_result: Dictionary = world.resolve_player_hit(hurtbox, 10.0, unit.global_position)
		_check(not proxy_result.is_empty(), "shooting the hurtbox damages the robot")

	# 开火：武器展开后会打出正式子弹，并挂上拖尾载体。
	unit.set("alert", true)
	unit.set("deploy", 1.0)
	await physics_frame
	unit.call("_fire", Vector2.RIGHT)
	await process_frame
	var projectile: Node2D = null
	for node in get_nodes_in_group(&"dream_projectiles"):
		if node.get_parent() != null:
			projectile = node as Node2D
			break
	_check(projectile != null, "robot fires a formal projectile")
	if projectile != null:
		_check(projectile.has_meta(&"shot_height_pixels"), "projectile carries a shot-height visual plane")
		_check(projectile.has_meta(&"depth_visual_bridge"), "projectile got a depth bridge (tracer trail)")

	var kill_guard := 0
	while float(unit.get("hp")) > 0.0 and kill_guard < 40:
		world.resolve_player_hit(unit, 20.0, unit.global_position)
		kill_guard += 1
	_check(float(unit.get("hp")) <= 0.0, "robot can be killed")
	_check(bool(unit.get("dead")), "dead flag set on the robot")
	_check(not unit.is_in_group(&"dream_enemies"), "dead robot leaves the enemy group")
	await create_timer(0.9).timeout
	await process_frame
	_check(not is_instance_valid(unit), "dead robot is removed from the world")
	_check(visuals.get_child_count() == 1 and visuals.get_child(0).get_meta(&"unit_death_effect",false), "dead robot model transfers to one floor-owned death effect")


func _check_exterior_drone(world: Node3D) -> void:
	var previous_windows: Dictionary=world.window_wall_edges.duplicate(true)
	world._spawn_exterior_drones()
	_check(is_instance_valid(world._exterior_drone_root) and world._exterior_drone_root.get_child_count()>0,"drones use real exterior windows")
	if world._exterior_drone_root.get_child_count()==0: return
	_check(world._exterior_drone_root.get_child_count()<=2,"drone population respects floor cap")
	_check(world.window_wall_edges==previous_windows,"drone spawning never turns solid walls into windows")
	await process_frame

	var drone := world._exterior_drone_root.get_child(0) as Node3D
	_check(drone != null, "drone node exists")
	var local := world.to_local(drone.global_position)
	_check(not world.floor_cells.has(Vector2i(int(floor(local.x)), int(floor(local.z)))),
		"drone floats outside the floor footprint")
	_check(absf(local.y - 1.45) < 0.01, "drone patrols at flight height")

	var proxy: Node2D = null
	for child in world.enemy_root.get_children():
		if String(child.name).begins_with("ExteriorDroneHitbox"):
			proxy = child
			break
	_check(proxy != null, "drone has a 2D hit proxy")
	if proxy == null:
		return
	var hurtbox := proxy.get_node_or_null("Hurtbox") as Area2D
	_check(hurtbox != null, "drone proxy owns a Hurtbox Area2D")
	if hurtbox != null:
		_check(hurtbox.collision_layer == 16, "drone hurtbox is on layer 16")
		_check(hurtbox.get_damage_owner() == proxy, "drone hurtbox owner is the proxy")
	var bar: Node3D = drone.call("health_bar")
	_check(bar == null, "drone no longer creates a health bar")

	var hp_before := float(drone.get("hp"))
	world.resolve_player_hit(proxy, 12.0, proxy.global_position)
	_check(float(drone.get("hp")) < hp_before, "shots on the proxy damage the drone")
	_check(drone.call("health_bar")==null, "drone damage does not recreate a health bar")

	var guard := 0
	while float(drone.get("hp")) > 0.0 and guard < 30:
		world.resolve_player_hit(proxy, 20.0, proxy.global_position)
		guard += 1
	_check(float(drone.get("hp")) <= 0.0, "drone can be killed")
	await create_timer(1.0).timeout
	await process_frame
	_check(not is_instance_valid(proxy), "dead drone's hit proxy is removed")


func _finish() -> void:
	print("special units (hotel robot / exterior drone): %d checks, %d failures"
		% [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
