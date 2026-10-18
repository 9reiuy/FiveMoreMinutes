extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PROJECTILE := preload("res://scenes/entities/basic_projectile.tscn")

func _init() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await process_frame
	await process_frame
	world.regenerate(41002)
	var player := world.player
	var bullet := PROJECTILE.instantiate()
	bullet.setup(Vector2(0.0, -1.0), 1.0, 270.0, 155.0, &"player", player, &"basic")
	bullet.global_position = player.global_position
	world.add_projectile(bullet)
	await process_frame
	await process_frame
	var bridge: Node = bullet.get_meta("depth_visual_bridge").get_ref()
	print("source root transform=", bullet.global_transform)
	print("head transform=", bullet.get_node("BulletSprite").global_transform)
	print("trail transform=", bullet.get_node("ProjectileTrail").global_transform)
	print("bridge=", bridge, "sprite=", bridge.actor_sprite.global_transform)
	for i in bridge.source_roots.size():
		print("source[",i,"] ",bridge.source_roots[i].name," clone=",bridge.clone_roots[i].transform)
	print("trail local rot=",bullet.get_node("ProjectileTrail").rotation,"velocity=",bullet.velocity)
	world.free()
	await process_frame
	quit()
