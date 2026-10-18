extends SceneTree

## Damage-number regression: feedback is native GameplayUI, projected from the
## captured hit position, and does not follow an Enemy that moves afterward.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/employee_enemy.tscn")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)


func frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "damage-number generation")
	await frames(3)

	var enemy := ENEMY_SCENE.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(enemy)
	var anchor := Vector2(world.rooms[world.spawn_room_id]["center_cell"]) * 32.0
	enemy.global_position = anchor
	enemy.set_meta(&"dream_room_id", world.spawn_room_id)
	enemy.set_meta(&"content_kind", &"employee_enemy")
	enemy.configure(world.player, 1000.0, 0.0, world._room_bounds_pixels(world.spawn_room_id, 2.0), 0.0, 0.0, world.config)
	enemy.set_physics_process(false)
	world.register_depth_visual(enemy, [^"Shadow", ^"CharacterVisual", ^"WeaponRoot"])
	await frames(2)

	var impact := enemy.global_position + Vector2(4.0, -20.0)
	var expected_anchor: Vector2 = enemy.global_position + enemy.get_damage_number_offset()
	world.resolve_player_hit(enemy, 10.0, impact, &"player_projectile")
	check(world.native_damage_numbers_root.get_child_count() == 1, "damage number uses native GameplayUI holder")
	check(world.native_damage_number_anchors.size() == 1, "damage number stores a world hit anchor")
	check(world.world_effects_root.find_child("DamageNumber", true, false) == null, "damage number is not put in ActorDepth world effects")
	await frames(1)
	var holder := world.native_damage_numbers_root.get_child(0) as Node2D
	var expected: Vector2 = world.camera_3d.unproject_position(Vector3(expected_anchor.x / 32.0, 0.05, expected_anchor.y / 32.0))
	check(holder.position.distance_to(expected) < 1.0, "damage number projects from the impact world position")

	# Move the Enemy after the hit; the projected holder must stay at the saved
	# impact while its child continues the original rise/fade animation.
	enemy.global_position += Vector2(96.0, 0.0)
	await frames(1)
	check(holder.position.distance_to(expected) < 1.0, "damage number does not follow post-hit enemy movement")
	await frames(65)
	check(world.native_damage_numbers_root.get_child_count() == 0, "damage number keeps its finite native lifetime")

	print("DAMAGE NUMBER checks=", checks, " failures=", failures.size())
	world.free()
	await frames(3)
	quit(1 if failures.size() else 0)
