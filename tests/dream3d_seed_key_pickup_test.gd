extends SceneTree

## Regression for the daily-random-map seed mechanism, the Boss Key E-pickup
## flow, proximity white outlines, the door aim-outline resolver and
## run-persistent blood stains.  Headless.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GENERATOR_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const WEAPON_PICKUP_SCENE := preload("res://scenes/dream/world_weapon_pickup.tscn")
const BASIC_ATTACK_RANGE := 270.0

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
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	await _test_seed_drives_layout()
	await _test_key_and_pickups_and_blood()
	print("SEED/KEY/PICKUP checks=", checks, " failures=", failures.size())
	quit(1 if failures.size() else 0)


## The mechanism main.gd now relies on: distinct seeds must produce distinct
## deterministic layouts (and the same seed must stay reproducible).
func _test_seed_drives_layout() -> void:
	var signatures: Dictionary = {}
	for index in range(8):
		var test_seed := 41500 + index * 7
		var generator: Node = GENERATOR_SCRIPT.new()
		generator.generate_on_ready = false
		generator.room_count = 12
		check(generator.generate_layout_only(test_seed), "layout generates for seed %d" % test_seed)
		var signature: String = generator.get_layout_signature()
		signatures[signature] = true
		check(generator.generate_layout_only(test_seed) and generator.get_layout_signature() == signature,
			"seed %d stays deterministic" % test_seed)
		generator.free()
	check(signatures.size() == 8, "8 distinct seeds produced 8 distinct layouts (got %d)" % signatures.size())


func _test_key_and_pickups_and_blood() -> void:
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "visual-run generation")
	await frames(4)
	var player: Node2D = world.player
	player.set_physics_process(false)

	# --- Door aim-outline resolver: a real ray at a door returns the door and
	# --- applying it arms the white outline overlay.
	var door: Node = null
	for child in world.door_root.get_children():
		if child.is_in_group(&"physical_door_3d"):
			door = child
			break
	check(door != null, "a physical door exists")
	if door != null:
		var body: Node2D = door.get("_collision_body_2d")
		check(body != null, "door has a synced 2D blocker")
		if body != null:
			player.global_position = body.global_position + Vector2(0, 40)
			var origin: Vector2 = player.global_position
			var direction := (body.global_position - origin).normalized()
			var found: Node = world.target_highlight.find_target(origin, direction, BASIC_ATTACK_RANGE, player.get_rid())
			check(found == door, "aim ray resolves the physical door (got %s)" % [found])
			world.target_highlight._select(found)
			check(found != null and (found.get("door_visual") as MeshInstance3D).material_overlay != null,
				"resolved door arms its outline overlay")

	# --- Boss Key: no auto-collect on touch anymore.
	var key: Node2D = world.key_pickup
	check(key != null and is_instance_valid(key), "boss key spawned in the key room")
	if key != null:
		check(key.is_in_group(&"boss_key_pickup"), "boss key joins the pickup group")
		check(int(key.get("collision_layer")) == 0, "boss key no longer sits on the wall layer")
		check(not world.has_boss_key, "key not granted at spawn")
		player.global_position = key.global_position
		await frames(3)
		check(not world.has_boss_key, "touching the key does NOT auto-collect")

		# Proximity targeting arms the unified white outline via the bridge.
		player.global_position = key.global_position + Vector2(16, 0)
		world._update_world_weapon_interaction()
		check(bool(key.get("interaction_targeted")), "nearby key becomes the interaction candidate")
		var reference: Variant = key.get_meta(&"depth_visual_bridge", null)
		var bridge: Node = reference.get_ref() if reference is WeakRef else null
		check(bridge != null, "key owns a depth bridge")
		if bridge != null:
			var key_render_root := bridge.get("render_root") as Node2D
			var key_replica := key_render_root.get_node_or_null("KeyVisual") if key_render_root != null else null
			check(key_replica != null and key_replica.has_method("_draw"), "key custom visual is copied into the depth viewport")
			check((bridge.get("actor_sprite") as Sprite3D).visible, "key depth carrier is visible in the world")
			var overlay: Material = (bridge.get("actor_sprite") as Sprite3D).material_overlay
			check(overlay != null, "nearby key shows the white outline")

		# Leaving the radius clears candidate state and outline.
		player.global_position = key.global_position + Vector2(300, 0)
		world._update_world_weapon_interaction()
		check(not bool(key.get("interaction_targeted")), "far key loses candidate state")
		if bridge != null:
			check((bridge.get("actor_sprite") as Sprite3D).material_overlay == null, "far key outline cleared")

		# E collects; boss door unlocks through the untouched collect_boss_key.
		player.global_position = key.global_position + Vector2(16, 0)
		world._update_world_weapon_interaction()
		Input.action_press("pickup_weapon")
		world._update_world_weapon_interaction()
		Input.action_release("pickup_weapon")
		await frames(2)
		check(bool(world.has_boss_key), "E collects the key")
		check(not world.is_boss_door_locked(), "boss door unlocked after pickup")

	# --- Weapon pickup proximity outline (same unified path as the key).
	var pickup := WEAPON_PICKUP_SCENE.instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.global_position = player.global_position + Vector2(20, 0)
	var pickup_paths: Array[NodePath] = [NodePath("Shadow"), NodePath("WeaponSprite")]
	world._spawn_depth_bridge(pickup, pickup_paths)
	await frames(1)
	world._update_world_weapon_interaction()
	check(bool(pickup.get("interaction_targeted")), "nearby weapon pickup is targeted")
	var pickup_bridge_ref: Variant = pickup.get_meta(&"depth_visual_bridge", null)
	var pickup_bridge: Node = pickup_bridge_ref.get_ref() if pickup_bridge_ref is WeakRef else null
	check(pickup_bridge != null and (pickup_bridge.get("actor_sprite") as Sprite3D).material_overlay != null,
		"nearby weapon pickup shows the white outline")
	player.global_position = player.global_position + Vector2(300, 0)
	world._update_world_weapon_interaction()
	check(not bool(pickup.get("interaction_targeted")), "far weapon pickup untargeted")

	# --- Blood persists for the whole run: no lifetime fade, no cap eviction.
	check(int(world.EMPLOYEE_CONFIG.black_blood_max_stains) == 0, "blood cap disabled (0 = run-persistent)")
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0 + Vector2(16, 16)
	for index in range(50):
		world.spawn_black_blood(anchor + Vector2(float(index % 10) * 3.0, float(index / 10) * 3.0))
	for index in range(20):
		world.spawn_death_blood_pool(anchor + Vector2(float(index % 5) * 4.0, float(index / 5) * 4.0))
	await frames(2)
	var stains: Array = world.get_tree().get_nodes_in_group(&"black_blood_stains")
	check(stains.size() >= 70, "70 blood stains coexist with the cap disabled (got %d)" % stains.size())
	var aged: Node = stains[0]
	aged.set("elapsed", 999.0)
	aged._process(0.016)
	check(not aged.is_queued_for_deletion(), "aged stain is not auto-freed")
	var aged_color: Color = aged.get("self_modulate")
	check(aged_color.a > 0.99, "aged stain keeps full opacity")

	world.free()
	await frames(5)
