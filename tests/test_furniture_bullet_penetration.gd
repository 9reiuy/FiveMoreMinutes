extends SceneTree

const DUNGEON_SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PROJECTILE_SCENE = preload("res://scenes/entities/basic_projectile.tscn")

const PENETRABLE_PROPS := [
	"res://scenes/dream/props/trash_can_01.tscn",
	"res://scenes/dream/props/parcel_box_01.tscn",
	"res://scenes/dream/props/small_table_01.tscn",
	"res://scenes/dream/props/side_table_01.tscn",
	"res://scenes/dream/props/chair.tscn",
	"res://scenes/dream/props/desk.tscn",
	"res://scenes/dream/props/chair_02.tscn",
	"res://scenes/dream/props/floor_lamp_01.tscn",
	"res://scenes/dream/props/office_chair_01.tscn",
]

const SOLID_LARGE_PROPS := [
	"res://scenes/dream/props/fridge_01.tscn",
	"res://scenes/dream/props/wardrobe_01.tscn",
	"res://scenes/dream/props/filing_cabinet_01.tscn",
	"res://scenes/dream/props/bed_01.tscn",
	"res://scenes/dream/props/storage_cabinet_01.tscn",
]

class PenetrationDummyTarget extends StaticBody2D:
	var hp: float = 100.0
	func _init() -> void:
		add_to_group(&"damageable_props")
		collision_layer = 8
		var d_shape := CollisionShape2D.new()
		var d_box := RectangleShape2D.new()
		d_box.size = Vector2(24.0, 24.0)
		d_shape.shape = d_box
		add_child(d_shape)
	func take_damage(amount: float, _hit_dir: Vector2 = Vector2.ZERO, _force: float = 1.0) -> void:
		hp -= amount
	func is_damage_runtime_active() -> bool:
		return true

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING FURNITURE BULLET PENETRATION TEST ===")
	var world = DUNGEON_SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	root.add_child(world)
	world.regenerate(42001)
	for i in range(10):
		await process_frame

	var base_pos: Vector2 = world.player.global_position

	# 1. Test Small and Medium furniture: bullet must pass through and damage both prop and dummy behind
	for path in PENETRABLE_PROPS:
		var prop_scene: PackedScene = load(path)
		var prop: RigidBody2D = prop_scene.instantiate()
		prop.global_position = base_pos + Vector2(30.0, 0.0)
		world.furniture_root.add_child(prop)

		var dummy := PenetrationDummyTarget.new()
		dummy.name = "DummyTarget"
		dummy.global_position = base_pos + Vector2(100.0, -12.0)
		world.furniture_root.add_child(dummy)

		for i in range(3):
			await process_frame

		var prop_init_hp: float = prop.hp
		var dummy_init_hp: float = dummy.hp

		var proj = PROJECTILE_SCENE.instantiate()
		proj.global_position = base_pos + Vector2(0.0, -12.0)
		world.add_child(proj)
		proj.setup(Vector2.RIGHT, 15.0, 300.0, 600.0, &"player")

		for f in range(25):
			await process_frame

		check(prop.hp < prop_init_hp, "%s took damage from projectile (HP: %.1f < %.1f)" % [path.get_file(), prop.hp, prop_init_hp])
		check(dummy.hp < dummy_init_hp, "Bullet penetrated %s and hit dummy behind it (Dummy HP: %.1f < %.1f)" % [path.get_file(), dummy.hp, dummy_init_hp])

		if is_instance_valid(proj):
			proj.queue_free()
		prop.queue_free()
		dummy.queue_free()
		for i in range(2):
			await process_frame

	# 2. Test Large furniture: bullet must hit prop, damage it, and DESPAWN without hitting dummy behind
	for path in SOLID_LARGE_PROPS:
		var prop_scene: PackedScene = load(path)
		var prop: RigidBody2D = prop_scene.instantiate()
		prop.global_position = base_pos + Vector2(30.0, 0.0)
		world.furniture_root.add_child(prop)

		var dummy := PenetrationDummyTarget.new()
		dummy.name = "DummyTarget"
		dummy.global_position = base_pos + Vector2(100.0, -12.0)
		world.furniture_root.add_child(dummy)

		for i in range(3):
			await process_frame

		var prop_init_hp: float = prop.hp
		var dummy_init_hp: float = dummy.hp

		var proj = PROJECTILE_SCENE.instantiate()
		proj.global_position = base_pos + Vector2(0.0, -12.0)
		world.add_child(proj)
		proj.setup(Vector2.RIGHT, 15.0, 300.0, 600.0, &"player")

		for f in range(25):
			await process_frame

		check(prop.hp < prop_init_hp, "Solid large prop %s took damage (HP: %.1f < %.1f)" % [path.get_file(), prop.hp, prop_init_hp])
		check(dummy.hp == dummy_init_hp, "Solid large prop %s BLOCKED bullet from reaching dummy (Dummy HP: %.1f == %.1f)" % [path.get_file(), dummy.hp, dummy_init_hp])
		check(not is_instance_valid(proj) or proj.consumed, "Bullet despawned on solid prop %s" % path.get_file())

		if is_instance_valid(proj):
			proj.queue_free()
		prop.queue_free()
		dummy.queue_free()
		for i in range(2):
			await process_frame

	print("\n=== PENETRATION SUMMARY: %d FAILURES ===" % failures.size())
	if not failures.is_empty():
		for f in failures:
			print("  - ", f)
	quit()
