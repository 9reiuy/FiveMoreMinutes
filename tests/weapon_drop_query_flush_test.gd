extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY = preload("res://scenes/entities/employee_enemy.tscn")
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")
var checks := 0
var failures := 0
var contacts := 0
var drop_events := 0
var during_drop_count := -1
var requested_position := Vector2.ZERO
var requested_impulse := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var world := WORLD.instantiate()
	if "--legacy-world" in OS.get_cmdline_user_args():
		# Exact pre-fix production source, kept outside the tracked test sources.
		world.set_script(load("res://.runtime/runtime_error_fix_20261020/dream_3d_random_dungeon_before.gd"))
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var employee := ENEMY.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(employee)
	employee.global_position = Vector2.ZERO
	employee.set_meta(&"dream_room_id", 0)
	employee.current_health = 1
	employee.held_weapon_id = "basic"
	employee.held_weapon_skin_index = 0
	employee.set_process(false)
	employee.set_physics_process(false)
	employee.weapon_drop_requested.connect(world._on_employee_weapon_drop_requested.bind(employee))
	employee.weapon_drop_requested.connect(func(_weapon: String, point: Vector2, impulse: Vector2, _skin: int) -> void:
		drop_events += 1
		requested_position = point
		requested_impulse = impulse
		during_drop_count = world.world_weapon_root.get_child_count()
		if "--invalidate-drop-floor" in OS.get_cmdline_user_args():
			world._layout_generation += 1
	)
	var thrown := PICKUP.instantiate() as RigidBody2D
	world.world_effects_root.add_child(thrown)
	thrown.global_position = Vector2(-70, 0)
	thrown.set_weapon_id("basic", 0)
	thrown.body_entered.connect(func(body: Node) -> void:
		if body == employee: contacts += 1
	)
	thrown.set_thrown(Vector2(500, 0), 1000, 40, 0)
	for frame in 120:
		await physics_frame
		if employee.dead: break
	await process_frame
	check(contacts > 0, "Real rigid-body body_entered reaches employee")
	check(employee.dead and drop_events == 1, "Thrown impact kills actual employee and requests one held weapon")
	check(during_drop_count == 0, "Physics signal does not insert a new physics pickup during query flush")
	var invalidated := "--invalidate-drop-floor" in OS.get_cmdline_user_args()
	check(world.world_weapon_root.get_child_count() == (0 if invalidated else 1), "Old-floor pending drop is rejected" if invalidated else "After flush exactly one held-weapon pickup is committed")
	if not invalidated and world.world_weapon_root.get_child_count() == 1:
		var dropped: Node2D = world.world_weapon_root.get_child(0)
		check(dropped.weapon_id == "basic" and dropped.skin_index == 0, "Dropped identity and skin preserved")
		var direction := requested_impulse.normalized() if requested_impulse.length_squared() > .001 else Vector2.RIGHT
		var relative: Vector2 = dropped.global_position - requested_position
		check(absf(relative.dot(direction) - 12.0) < .1 and absf(relative.dot(direction.orthogonal())) <= 4.1, "Drop retains event-time position and authored forward/lateral offset")
		check(is_equal_approx(dropped.mass, world.WEAPON_VISUALS.get_world_mass("basic")), "Weapon mass preserved")
		# A non-physics pit event keeps immediate pickup availability, exact safe
		# floor landing, sky-drop arc and zero horizontal throw just as before.
		world.pit_cells[Vector2i.ZERO] = true
		world.floor_cells[Vector2i(1, 0)] = true
		var safe_point: Vector2 = world._nearest_safe_floor_world_position(Vector2i.ZERO)
		var rng_before: int = world._content_rng.state
		world._on_employee_weapon_drop_requested("basic", Vector2.ZERO, Vector2(120, 0), 0, employee)
		check(world.world_weapon_root.get_child_count() == 2, "Safe non-physics event stays synchronous")
		var pit_drop: Node2D = world.world_weapon_root.get_child(1)
		check(pit_drop.global_position == safe_point and pit_drop.sky_drop_height == 84.0, "Pit weapon retains nearest safe-floor point and original sky drop")
		check(pit_drop.linear_velocity == Vector2.ZERO and world._content_rng.state == rng_before, "Pit recovery adds no horizontal impulse or RNG draw")
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"enemy_kill")
	# Let the existing music-owner fade and audio playback release complete.
	for frame in 30:
		await physics_frame
		await process_frame
	print("Weapon drop query flush: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

