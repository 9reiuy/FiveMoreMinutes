extends SceneTree
const GUIDANCE := preload("res://scripts/dream/office_objective_guidance.gd")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const DRONE_PROXY := preload("res://scripts/entities/exterior_drone_proxy.gd")
var failures := 0
class TestWorld extends Node3D:
	var player: Node2D
	var camera_3d: Camera3D
	var enemy_root: Node2D
	var floor_badge_pickup: Node2D
	var floor_transition_in_progress := false
	var transition_phase := &"IDLE"
	var has_floor_badge := false
	var elevator_door_pos_2d := Vector2.ZERO
	func _map_gameplay_to_world(point: Vector2) -> Vector3:
		return Vector3(point.x / 32.0, 0, point.y / 32.0)
class TestEnemy extends Node2D:
	var dead := false
	var knocked_down := true
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func gameplay_at_screen(camera: Camera3D, screen: Vector2, height: float) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)
	var point := origin + ray * ((height - origin.y) / ray.y)
	return Vector2(point.x, point.z) * 32.0

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(GUIDANCE.choose_mode(29.99, false, false, false) == &"hidden", "before30")
	check(GUIDANCE.choose_mode(30, false, false, false) == &"enemy", "at30")
	check(GUIDANCE.choose_mode(0, false, true, false) == &"badge", "early badge")
	check(GUIDANCE.choose_mode(0, true, true, false) == &"elevator", "picked priority")
	check(GUIDANCE.choose_mode(40, true, true, true) == &"hidden", "cab suspended")
	check(GUIDANCE.ARROW_TEXTURE.get_size() == Vector2(144, 48), "three atlas frames")
	check(GUIDANCE.arrow_frame(&"enemy") == 0 and GUIDANCE.arrow_frame(&"badge") == 1 and GUIDANCE.arrow_frame(&"elevator") == 1, "enemy and objectives use the first two frames")
	check(GUIDANCE.arrow_size(6) > GUIDANCE.arrow_size(15) and GUIDANCE.arrow_size(15) > GUIDANCE.arrow_size(36), "near targets have larger arrows")
	check(GUIDANCE.arrow_size(0) == GUIDANCE.MAX_ARROW_SIZE and GUIDANCE.arrow_size(100) == GUIDANCE.MIN_ARROW_SIZE, "distance size is bounded")
	var rect := Rect2(24, 24, 592, 312)
	check(GUIDANCE.edge_position(Vector2(1000,180), rect) == Vector2(616,180), "edge right")
	check(GUIDANCE.edge_position(Vector2(320,-100), rect) == Vector2(320,24), "edge top")
	var manager := GUIDANCE.new()
	root.add_child(manager)
	manager.elapsed = 42
	manager.states.append({"id": 1})
	manager.reset_floor()
	check(manager.elapsed == 0 and manager.states.is_empty(), "reset")
	manager.states = []
	for i in range(12):
		manager.states.append({"position":Vector2(611,180),"on_screen":false,"id":i,"size":GUIDANCE.MAX_ARROW_SIZE})
	manager._stack_states(Rect2(0, 0, 640, 360))
	check(manager.states.size() == 12, "stack neverdrops")
	for i in range(manager.states.size()):
		for j in range(i):
			check(Vector2(manager.states[i].position).distance_to(manager.states[j].position) >= GUIDANCE._arrow_radius(manager.states[i]) + GUIDANCE._arrow_radius(manager.states[j]) - 1.0, "different-sized arrow frames do not overlap")
	manager.states.clear()
	for i in range(30):
		manager.states.append({"position":Vector2(611,180),"id":i,"size":36.0})
	manager._stack_states(Rect2(0, 0, 640, 360))
	for i in range(manager.states.size()):
		for j in range(i):
			check(Vector2(manager.states[i].position).distance_to(manager.states[j].position) >= GUIDANCE._arrow_radius(manager.states[i]) + GUIDANCE._arrow_radius(manager.states[j]) - 1.0, "full enemy crowd remains separated")
	var world := TestWorld.new()
	world.add_to_group(&"dream_world")
	root.add_child(world)
	var player := PLAYER.instantiate()
	world.add_child(player)
	world.player = player
	world.camera_3d = Camera3D.new()
	world.add_child(world.camera_3d)
	world.camera_3d.position = Vector3(0, 8, 8)
	world.camera_3d.look_at(Vector3.ZERO)
	world.enemy_root = Node2D.new()
	world.add_child(world.enemy_root)
	var enemies: Array[Node2D] = []
	for i in range(5):
		var enemy := TestEnemy.new()
		enemy.add_to_group(&"dream_enemies")
		if i == 4:
			enemy.set_meta(&"exterior_flying", true)
		world.enemy_root.add_child(enemy)
		enemies.append(enemy)
	var muzzle := Node2D.new()
	muzzle.name = "ExteriorDroneMuzzle"
	world.enemy_root.add_child(muzzle)
	manager.configure(world)
	await process_frame
	var view_size := world.camera_3d.get_viewport().get_visible_rect().size
	for i in range(enemies.size()):
		enemies[i].global_position = gameplay_at_screen(world.camera_3d, Vector2(view_size.x + 200 + 25 * i, view_size.y * 0.5), 0.9)
	manager.update(29)
	check(manager.states.is_empty(), "runtimebefore30")
	paused = true
	manager.update(10)
	check(manager.elapsed == 29 and manager.states.is_empty(), "pause stopsclock")
	paused = false
	player.movement_enabled = false
	manager.update(5)
	check(manager.elapsed == 29, "control lock stopsclock")
	player.movement_enabled = true
	manager.update(1)
	check(manager.states.size() == 5, "all living offscreen knocked-down enemies included, muzzle excluded")
	var drone := DRONE_PROXY.new()
	world.enemy_root.add_child(drone)
	drone.global_position = gameplay_at_screen(world.camera_3d, Vector2(-200, view_size.y * 0.5), 1.45)
	manager.update(0)
	var drone_arrows := 0
	for state in manager.states:
		if state.id == drone.get_instance_id():
			drone_arrows += 1
	check(manager.states.size() == 6 and drone_arrows == 1, "real drone proxy gets exactly one arrow, never its muzzle")
	drone.dead = true
	manager.update(0)
	check(manager.states.size() == 5, "defeated drone arrow disappears")
	drone.queue_free()
	enemies[0].global_position = gameplay_at_screen(world.camera_3d, view_size * 0.5, 0.9)
	manager.update(0)
	check(manager.states.size() == 4, "onscreen enemy has no arrow")
	var original_far := world.camera_3d.far
	world.camera_3d.far = 1.0
	manager.update(0)
	var clipped_arrow := false
	for state in manager.states:
		if state.id == enemies[0].get_instance_id():
			clipped_arrow = true
			check(Vector2(state.position).distance_to(view_size * 0.5) > 100.0, "far-clipped target projects to a screen edge")
	check(clipped_arrow, "target beyond camera far plane retains its arrow")
	world.camera_3d.far = original_far
	enemies[0].global_position = gameplay_at_screen(world.camera_3d, Vector2(view_size.x + 1, view_size.y * 0.5), 0.9)
	manager.update(0)
	check(manager.states.size() == 4, "partially onscreen enemy has no arrow")
	enemies[0].global_position = gameplay_at_screen(world.camera_3d, Vector2(view_size.x + 200, view_size.y * 0.5), 0.9)
	manager.update(0)
	check(manager.states.size() == 5, "arrow returns when enemy leaves screen")
	world.enemy_root.get_child(0).dead = true
	manager.update(0)
	check(manager.states.size() == 4, "dead removed immediately")
	world.floor_badge_pickup = Node2D.new()
	world.add_child(world.floor_badge_pickup)
	world.floor_badge_pickup.global_position = gameplay_at_screen(world.camera_3d, Vector2(view_size.x + 200, view_size.y * 0.5), 0.3)
	manager.update(0)
	check(manager.states.size() == 1 and manager.states[0].kind == &"badge", "drop replacesenemies")
	world.floor_badge_pickup.global_position = gameplay_at_screen(world.camera_3d, view_size * 0.5, 0.3)
	manager.update(0)
	check(manager.states.is_empty(), "onscreen badge has no arrow")
	world.elevator_door_pos_2d = gameplay_at_screen(world.camera_3d, Vector2(view_size.x + 200, view_size.y * 0.5), 1.3)
	world.has_floor_badge = true
	manager.update(0)
	check(manager.states.size() == 1 and manager.states[0].kind == &"elevator", "pick replacesbadge")
	world.elevator_door_pos_2d = gameplay_at_screen(world.camera_3d, view_size * 0.5, 1.3)
	manager.update(0)
	check(manager.states.is_empty(), "onscreen elevator has no arrow")
	world.transition_phase = &"CAB_RIDE"
	manager.update(5)
	check(manager.states.is_empty() and manager.elapsed == 30, "cab hides stopsclock")
	player.selected_weapon_id = ""
	player.left_hand_part.visible = false
	player.right_hand_part.visible = false
	player.set_attacking_enabled(false)
	check(player.left_hand_part.visible and player.right_hand_part.visible, "cabin fists visible whiledisabled")
	check(not player.should_trigger_weapon_attack(), "cabin noattack")
	player.selected_weapon_id = "basic"
	player.ammo_states["basic"] = {"current": 0, "reload_left": 2.0}
	player._update_weapon_name(0.01)
	check(player.weapon_name_label.text == "正在换弹" and player.weapon_name_label.visible, "local3dreload")
	player._update_weapon_name(1)
	check(player.weapon_name_label.visible, "reload outlives popup timer")
	player.ammo_states["basic"].reload_left = 0.0
	player._update_weapon_name(0)
	check(not player.weapon_name_label.visible, "reload ended clears")
	player.ammo_states["basic"].reload_left = 2.0
	player.suppress_local_weapon_name_label = true
	player._update_weapon_name(0)
	check(not player.weapon_name_label.visible, "random nativeHUDauthority")
	world.remove_from_group(&"dream_world")
	var legacy := Node2D.new()
	legacy.add_to_group(&"dream_world")
	root.add_child(legacy)
	# The player caches its world; explicitly simulate the old world being
	# released before checking the 2D-world path.
	player._cached_dream_world = null
	player.suppress_local_weapon_name_label = false
	player.weapon_name_label.text = "legacy"
	player.weapon_name_time_left = 1.0
	player._update_weapon_name(0)
	check(player.weapon_name_label.text == "legacy", "legacy2D unchanged")
	legacy.queue_free()
	world.queue_free()
	manager.queue_free()
	await process_frame
	print("OFFICE GUIDANCE failures=", failures)
	quit(1 if failures else 0)
