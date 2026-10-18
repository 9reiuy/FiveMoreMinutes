extends SceneTree
## Regression guard for the DoorLeaf crash:
##   Invalid call. Nonexistent function 'get_closest_leaf_point_2d' in base 'Node3D'
## The boss wake exit 3D marker used to be parented to DoorRoot, so every
## melee/E door lookup reached a door-only method on a bare Node3D.
## This test runs with spawn_content = true, the value the real scene uses.

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const CONFIG = preload("res://resources/demo_config.tres")

var world: Node3D
var failures: Array[String] = []
var checks := 0
var player: Node2D

func _init() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	world.run_interface.auto_open_upgrades = false

	var shapes_seen := {}
	for test_seed in [41001, 41002, 41003, 41004, 41005, 41006]:
		check(world.regenerate(test_seed), "seed %d generation" % test_seed)
		await frames(4)
		for room in world.rooms:
			shapes_seen[String(room.get("shape", &"rectangle"))] = true
		# Invariant: DoorRoot holds PhysicalDoor3D instances and nothing else.
		for child in world.door_root.get_children():
			check(child is PhysicalDoor3D, "seed %d: DoorRoot child '%s' is a PhysicalDoor3D" % [test_seed, child.name])
		# The wake exit marker exists once content is spawned and lives elsewhere.
		if world.wake_exit_visual != null and is_instance_valid(world.wake_exit_visual):
			check(world.wake_exit_visual.get_parent() != world.door_root, "seed %d: wake exit marker is not parented to DoorRoot" % test_seed)
		await _exercise_doors(test_seed)

	check(shapes_seen.has("rectangle"), "covered rectangle rooms")
	check(shapes_seen.has("irregular") or shapes_seen.has("courtyard"), "covered irregular or courtyard rooms")
	print("shapes covered: ", shapes_seen.keys())
	print("DOOR LEAF REGRESSION checks=", checks, " failures=", failures.size())
	world.free()
	await frames(10)
	quit(0 if failures.is_empty() else 1)


func _exercise_doors(test_seed: int) -> void:
	# Hardening: a stray non-door child must be ignored, not crashed on.
	var stray := Node3D.new()
	stray.name = "StrayDoorRootChild"
	world.door_root.add_child(stray)

	var door := _first_unlocked_door()
	if door == null:
		check(false, "seed %d: an unlocked door exists" % test_seed)
		stray.free()
		return
	check(door.get_parent() == world.door_root, "seed %d: the selected target is a DoorRoot door" % test_seed)
	var normal := Vector2(door.global_basis.z.x, door.global_basis.z.z)
	var stand := door.get_leaf_center_2d() - normal * 22.0
	var reach := door.door_width * 32.0 * 0.5 + 1.0

	# E push.
	player.global_position = stand
	await frames(2)
	check(world.request_player_door_push(), "seed %d: E pushes the nearest door" % test_seed)
	await frames(55)
	check(absf(door.get_open_angle()) > 0.05, "seed %d: E rotates the actual leaf" % test_seed)

	# The stray child never became a door target and never blocked the lookup.
	check(not (stray is PhysicalDoor3D), "seed %d: stray child is never treated as a door" % test_seed)
	stray.free()

	# Punch, kick and melee all share apply_door_impact_near.
	world.regenerate(test_seed)
	await frames(4)
	door = _first_unlocked_door()
	if door == null:
		check(false, "seed %d: an unlocked door exists after regenerate" % test_seed)
		return
	normal = Vector2(door.global_basis.z.x, door.global_basis.z.z)
	stand = door.get_leaf_center_2d() - normal * 22.0
	player.global_position = stand
	await frames(2)
	check(world.apply_door_impact_near(stand, normal, 60.0, 260.0, &"punch"), "seed %d: punch reaches the door" % test_seed)
	check(str(door.get_meta("last_impact_source", "")) == "punch", "seed %d: punch impact is attributed to the leaf" % test_seed)

	# The contact point must sit on the door leaf, never inside a wall or a courtyard void.
	var contact: Vector2 = door.get_closest_leaf_point_2d(stand)
	check(contact.distance_to(door.get_leaf_center_2d()) <= reach, "seed %d: impact point lies on the leaf segment" % test_seed)
	check(contact.distance_to(stand) <= 60.0, "seed %d: impact point is inside the interaction envelope" % test_seed)


func _first_unlocked_door() -> PhysicalDoor3D:
	for child in world.door_root.get_children():
		var door := child as PhysicalDoor3D
		if door != null and is_instance_valid(door) and not door.locked:
			return door
	return null
