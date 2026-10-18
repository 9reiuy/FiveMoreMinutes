extends "res://tests/dream3d_combat_parity_test.gd"

const WEAPON_PICKUP_SCENE := preload("res://scenes/dream/world_weapon_pickup.tscn")
const PIXELATION_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")

## Native world carriers and the one-viewport pixelation wrapper. The wrapper
## switches resolution around one continuous gameplay world.
## Godot --headless --path . --script res://tests/pixel_environment_test.gd

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "native world generation")
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0 + Vector2(16, 16)
	player.global_position = anchor
	player.equip_weapon("basic", CONFIG, {})
	var enemy := enemy_at(anchor + Vector2(48, 0), 10000)
	enemy.set_physics_process(false)
	var furniture := prop_at(anchor + Vector2(-48, 0))
	var pickup := WEAPON_PICKUP_SCENE.instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.global_position = anchor + Vector2(0, 48)
	world._spawn_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])
	world.spawn_black_blood(anchor + Vector2(24, 24))
	var key := preload("res://scenes/dream/3d/BossKeyPickup.tscn").instantiate()
	world.key_root.add_child(key)
	key.global_position = anchor + Vector2(0, -48)
	world._spawn_depth_bridge(key, [NodePath("KeyVisual")])
	await frames(5)
	check(_carrier_visible(world.player_depth_bridge), "player carrier visible")
	check(_layer_of(world.player_depth_bridge) == 2, "player character receiver layer")
	check(_carrier_visible(_bridge_of(enemy)), "enemy carrier visible")
	check(_layer_of(_bridge_of(enemy)) == 2, "enemy shares character receiver layer")
	check(_carrier_visible(_bridge_of(furniture)), "furniture carrier visible")
	check(_layer_of(_bridge_of(furniture)) == 1, "furniture environment layer")
	check(_carrier_visible(_bridge_of(pickup)), "dropped weapon carrier visible")
	check(_carrier_visible(_bridge_of(key)), "boss key carrier visible")
	check(_carrier_visible(_bridge_of(world.world_effects_root.get_child(0))), "blood carrier visible")
	# A formal projectile is registered in its gameplay group. Looking only at
	# immediate children of gameplay_world used to miss actual projectile nodes.
	var before: Dictionary = {}
	for projectile in get_nodes_in_group(&"active_basic_projectiles"):
		before[projectile] = true
	player.auto_weapon._fire(Vector2(1, 1).normalized(), false)
	var new_projectile: Node = null
	for projectile in get_nodes_in_group(&"active_basic_projectiles"):
		if not before.has(projectile):
			new_projectile = projectile
			break
	check(new_projectile != null, "fired projectile enters active gameplay group")
	if new_projectile != null:
		check(_carrier_visible(_bridge_of(new_projectile)), "projectile carrier visible")
		check(_layer_of(_bridge_of(new_projectile)) == 1, "projectile stays on environment layer")
	await frames(20)
	check(is_instance_valid(world) and world.get_tree() != null, "world remains active")
	world.free()
	await frames(2)

	var display := PIXELATION_SCENE.instantiate() as Control
	display.set("preview_seed", 42001)
	root.add_child(display)
	await frames(4)
	var gameplay_world: Node = display.get("world")
	var gameplay_player: Node = gameplay_world.get("player") if gameplay_world != null else null
	var world_viewport: SubViewport = display.get("world_viewport")
	check(gameplay_world != null and gameplay_player != null, "pixelation wrapper hosts gameplay")
	check(world_viewport != null and gameplay_world != null and gameplay_world.get_viewport() == world_viewport, "one world viewport owns gameplay")
	if gameplay_world != null:
		var world_id := gameplay_world.get_instance_id()
		var player_id := gameplay_player.get_instance_id()
		display.call("set_selective_enabled", false)
		await frames(2)
		check(display.get("world").get_instance_id() == world_id, "turning pixelation off preserves world")
		check(display.get("world").get("player").get_instance_id() == player_id, "turning pixelation off preserves player")
		display.call("set_selective_enabled", true)
		await frames(2)
		check(display.get("world").get_instance_id() == world_id, "turning pixelation on preserves world")
		check(display.get("world").get("player").get_instance_id() == player_id, "turning pixelation on preserves player")
		check(world_viewport.size == Vector2i(640, 360), "pixelated world uses 640 by 360")
		check(display.get_stats().world_render_viewport_count == 1, "one full-world rendering channel remains")
	display.free()
	await frames(5)
	print("PIXEL ENVIRONMENT checks=", checks, " failures=", failures.size())
	quit(1 if failures.size() else 0)


func _bridge_of(node: Node) -> Node3D:
	if node == null or not node.has_meta(&"depth_visual_bridge"):
		return null
	var reference: Variant = node.get_meta(&"depth_visual_bridge")
	return reference.get_ref() if reference is WeakRef else null


func _carrier_visible(bridge: Node3D) -> bool:
	if bridge == null or not is_instance_valid(bridge):
		return false
	var sprite := bridge.get("actor_sprite") as Sprite3D
	return sprite != null and sprite.visible


func _layer_of(bridge: Node3D) -> int:
	if bridge == null or not is_instance_valid(bridge):
		return 0
	var sprite := bridge.get("actor_sprite") as Sprite3D
	return sprite.layers if sprite != null else 0
