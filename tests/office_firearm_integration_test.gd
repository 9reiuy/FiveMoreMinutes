extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const BULLET := preload("res://scenes/entities/basic_projectile.tscn")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)


func _run() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	_check(world.regenerate(41001), "office generates")
	await process_frame
	var point: Vector2 = world.player.global_position
	var height_pixels := 25.0
	var wall := StaticBody2D.new()
	world.collision_root.add_child(wall)
	var previous := get_nodes_in_group(&"firearm_impact_visuals").size()
	world.spawn_firearm_impact_visual(point, Vector2.LEFT, wall, height_pixels)
	_check(get_nodes_in_group(&"firearm_impact_visuals").size() == previous + 1, "solid impact creates one 3D visual")
	var solid := world.floor_root.get_child(world.floor_root.get_child_count() - 1) as Node3D
	_check(StringName(solid.get("_surface_kind")) == &"solid", "wall is a solid impact")
	var expected: Vector3 = world.get_gameplay_world_position(point, height_pixels / world.CELL_PIXELS)
	_check(solid.global_position.distance_to(expected + Vector3.LEFT.rotated(Vector3.UP, -PI * 0.25) * 0.015) < 0.03, "impact uses authoritative hit point and height")
	var glass := StaticBody2D.new()
	glass.add_to_group(&"glass_windows")
	world.collision_root.add_child(glass)
	world.spawn_firearm_impact_visual(point, Vector2.UP, glass, height_pixels)
	var glass_effect := world.floor_root.get_child(world.floor_root.get_child_count() - 1) as Node3D
	_check(StringName(glass_effect.get("_surface_kind")) == &"glass", "glass uses cool shards")
	var sofa := StaticBody2D.new()
	sofa.add_to_group(&"damageable_props")
	sofa.set_meta(&"office_furniture_kind", "sofa")
	world.collision_root.add_child(sofa)
	world.spawn_firearm_impact_visual(point, Vector2.UP, sofa, height_pixels)
	var soft_effect := world.floor_root.get_child(world.floor_root.get_child_count() - 1) as Node3D
	_check(StringName(soft_effect.get("_surface_kind")) == &"soft", "soft furniture has no metal sparks")
	var server := StaticBody2D.new()
	server.add_to_group(&"damageable_props")
	server.set_meta(&"office_furniture_kind", "server")
	world.collision_root.add_child(server)
	world.spawn_firearm_impact_visual(point, Vector2.UP, server, height_pixels)
	var metal_effect := world.floor_root.get_child(world.floor_root.get_child_count() - 1) as Node3D
	_check(StringName(metal_effect.get("_surface_kind")) == &"metal", "server cabinet has metal sparks")
	var enemy := Node2D.new()
	enemy.add_to_group(&"dream_enemies")
	world.enemy_root.add_child(enemy)
	previous = get_nodes_in_group(&"firearm_impact_visuals").size()
	world.spawn_firearm_impact_visual(point, Vector2.UP, enemy, height_pixels)
	_check(get_nodes_in_group(&"firearm_impact_visuals").size() == previous, "character hit does not spawn metal particles")
	for i in 40:
		world.spawn_firearm_impact_visual(point, Vector2.UP, wall, height_pixels)
	_check(get_nodes_in_group(&"firearm_impact_visuals").size() <= world.MAX_ACTIVE_FIREARM_IMPACT_VISUALS, "impact budget remains bounded")
	_check(world.regenerate(41002), "next floor generates")
	_check(get_nodes_in_group(&"firearm_impact_visuals").is_empty(), "old floor impact effects are cleaned")
	# At the new 2500 px/s speed, each physics tick traverses nearly 42 px.
	# These four narrow barriers sit inside one tick so endpoint-only collision
	# would tunnel through them. The real bullet's swept query must still hit.
	var sweep_bullet := BULLET.instantiate() as Node2D
	world.gameplay_world.add_child(sweep_bullet)
	sweep_bullet.set_physics_process(false)
	sweep_bullet.call("setup", Vector2.RIGHT, 10.0, 100.0, 2500.0, &"player")
	var kinds := ["wall", "door", "glass", "furniture"]
	var barriers: Array[StaticBody2D] = []
	for index in kinds.size():
		var barrier := StaticBody2D.new()
		barrier.name = "Sweep_" + kinds[index]
		barrier.collision_layer = 1 if index < 3 else 8
		barrier.collision_mask = 0
		barrier.global_position = Vector2(100006.0, 100000.0 + index * 40.0)
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(2.0, 30.0)
		shape.shape = rectangle
		barrier.add_child(shape)
		world.collision_root.add_child(barrier)
		barriers.append(barrier)
	await physics_frame
	for index in kinds.size():
		var start := Vector2(100000.0, 100000.0 + index * 40.0)
		var hit: Dictionary = sweep_bullet.call("_cast_movement_segment", start, start + Vector2.RIGHT * (2500.0 / 60.0))
		_check(hit.get("collider") == barriers[index], "2500 px/s sweep hits narrow " + kinds[index])
	sweep_bullet.queue_free()
	world.queue_free()
	await process_frame
	print("Office firearm integration: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
