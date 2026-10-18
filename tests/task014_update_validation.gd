extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GENERATOR = preload("res://scripts/dream/dream_3d_random_dungeon.gd")
var failures: Array[String] = []
var checks := 0
var world: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func bridge_of(source: Node) -> Node:
	if not source.has_meta(&"depth_visual_bridge"):
		return null
	var reference: Variant = source.get_meta(&"depth_visual_bridge", null)
	return reference.get_ref() if reference is WeakRef else null

func freeze_combat() -> void:
	world.player.set_physics_process(false)
	world.player.invulnerability_left = 1000.0
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
		for weapon in enemy.get_children():
			if weapon.name.ends_with("Weapon"):
				weapon.set_process(false)

func enter_room(room_id: int) -> void:
	world.player.global_position = Vector2(world.rooms[room_id].center_cell) * world.CELL_PIXELS
	world.activate_room(room_id)
	freeze_combat()

func _run() -> void:
	if "--render-check" in OS.get_cmdline_user_args():
		await render_check()
		return
	var generator: Node = GENERATOR.new()
	for test_seed in range(41001, 41021):
		check(generator.generate_layout_only(test_seed), "layout seed %d" % test_seed)
		check(generator.boss_room_id == -1 and generator.boss_door_id == -1, "no boss roles %d" % test_seed)
		check(not generator.find_floor_path(generator.spawn_cell, generator.elevator_anchor_cell).is_empty(), "reachable elevator %d" % test_seed)
		generator._build_room_encounter_plans()
		var carrier_count := 0
		for room in generator.rooms:
			generator._resolve_room_encounter_descriptor(int(room.id))
			for entry in generator.room_encounters[int(room.id)].get("enemy_spawns", []):
				if entry.get("badge_carrier", false):
					carrier_count += 1
		check(carrier_count == 1, "actual descriptor carrier count %d = %d" % [test_seed, carrier_count])
	generator.free()
	print("TASK014: 20 seed checks finished")
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = false
	root.add_child(world)
	check(world.regenerate(41001), "initial full floor")
	freeze_combat()
	await frames(6)
	var player_id: int = world.player.get_instance_id()
	world.player.current_health = maxf(1.0, world.player.maximum_health * 0.65)
	var health: float = world.player.current_health
	var selected: String = world.player.selected_weapon_id
	var ammo: Dictionary = world.player.ammo_states.duplicate(true)
	var ranged: String = world.player.ranged_weapon_id
	var melee: String = world.player.melee_weapon_id
	world.run_interface.seconds = 123.0
	var campaign_layer: int = world.dream_layer_id
	for floor_number in range(10):
		var carrier: Node = null
		var count := 0
		for enemy in world.enemy_root.get_children():
			if enemy.get_meta(&"employee_badge_carrier", false):
				count += 1
				carrier = enemy
		check(count == 1, "floor %d real employee carrier count %d" % [floor_number, count])
		if carrier == null:
			break
		enter_room(int(carrier.get_meta(&"dream_room_id")))
		await frames(4)
		world._on_elevator_body_entered(world.player)
		check(not world.floor_transition_in_progress, "locked elevator rejects entry")
		var origin: Vector2 = carrier.global_position
		carrier._die()
		world._on_badge_carrier_defeated(origin, 0, carrier)
		await frames(4)
		var badge: Node = world.floor_badge_pickup
		check(is_instance_valid(badge), "death drops badge")
		if not is_instance_valid(badge):
			break
		check(badge.global_position.is_equal_approx(origin), "badge uses cached death origin")
		check(is_instance_valid(bridge_of(badge)), "badge has 3D visual bridge")
		var marker: Node = world.badge_marker
		check(is_instance_valid(marker) and is_instance_valid(bridge_of(marker)), "marker and bridge exist")
		badge.collect()
		await frames(4)
		check(world.has_floor_badge and world.elevator_state == &"UNLOCKED", "formal pickup unlocks elevator")
		check(not is_instance_valid(badge) and not is_instance_valid(marker), "pickup removes badge and marker")
		world.player_has_left_elevator_cab = true
		var old_trigger: Node = world.elevator_trigger
		var old_bridges: Array = world.actor_depth_bridges_root.get_children()
		enter_room(world.elevator_room_id)
		world.player.dashing = true
		world._on_elevator_body_entered(world.player)
		world._on_elevator_body_entered(world.player)
		await frames(4)
		freeze_combat()
		check(world.floor_index == floor_number + 1, "duplicate entry advances exactly one floor")
		check(not world.has_floor_badge and world.elevator_state == &"LOCKED", "next floor resets badge")
		check(not world.player.dashing, "elevator cancels the preceding floor's dash")
		check(world.player.get_instance_id() == player_id and is_equal_approx(world.player.current_health, health), "player and HP retained")
		check(world.player.selected_weapon_id == selected and world.player.ranged_weapon_id == ranged and world.player.melee_weapon_id == melee, "weapons retained")
		check(world.player.ammo_states == ammo, "ammo retained")
		check(world.run_interface.seconds >= 123.0 and world.dream_layer_id == campaign_layer, "run timer and campaign retained")
		check(not is_instance_valid(old_trigger), "previous elevator freed")
		var surviving := 0
		for bridge in old_bridges:
			if is_instance_valid(bridge):
				surviving += 1
		check(surviving == 0, "previous bridges freed")
		print("TASK014 FLOOR ", world.floor_index, " nodes=", get_node_count(), " bridges=", world.actor_depth_bridges_root.get_child_count(), " enemies=", world.enemy_root.get_child_count())
	# The marker must also disappear if the pickup is freed outside collect().
	world._spawn_employee_badge(world.player.global_position, world.spawn_room_id, world._layout_generation)
	var orphan_marker: Node = world.badge_marker
	world.floor_badge_pickup.queue_free()
	await frames(3)
	check(not is_instance_valid(orphan_marker), "unexpected badge deletion cleans marker")
	# Simulate a late callback from the preceding floor while this floor owns a
	# pending death event. It must not clear the new floor's once-only guard.
	world.badge_drop_pending = true
	world._spawn_employee_badge(Vector2.ZERO, 0, world._layout_generation - 1)
	check(world.badge_drop_pending, "stale callback does not mutate new floor")
	world.free()
	await frames(4)
	print("TASK014 VALIDATION checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func render_check() -> void:
	var main: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	main._set_screen(world)
	check(world.regenerate(41001), "render floor")
	freeze_combat()
	await frames(12)
	var initial: int = world.spawn_room_id
	var other := -1
	for room in world.rooms:
		if int(room.id) != initial:
			other = int(room.id)
			break
	for room_id in [initial, other, initial]:
		enter_room(room_id)
		await frames(12)
		var found := 0
		for furniture in world.furniture_root.get_children():
			if int(furniture.get_meta(&"dream_room_id", -1)) != room_id:
				continue
			var bridge := bridge_of(furniture)
			if not is_instance_valid(bridge):
				check(false, "furniture missing bridge")
				continue
			var image: Image = bridge.render_viewport.get_texture().get_image()
			check(image != null and image.get_used_rect().has_area(), "real nontransparent furniture capture room %d" % room_id)
			check(bridge.capture_initialized and bridge.static_visual_frozen, "furniture froze after completed capture")
			found += 1
		print("TASK014 RENDER room=", room_id, " furniture=", found)
	world._spawn_employee_badge(world.player.global_position + Vector2(45, 0), initial, world._layout_generation)
	await frames(12)
	var badge_bridge := bridge_of(world.floor_badge_pickup)
	var badge_image: Image = badge_bridge.render_viewport.get_texture().get_image()
	check(badge_image != null and badge_image.get_used_rect().has_area(), "real badge capture")
	var marker_bridge := bridge_of(world.badge_marker)
	var y_before: float = marker_bridge.actor_sprite.global_position.y
	await frames(12)
	var y_after: float = marker_bridge.actor_sprite.global_position.y
	check(absf(y_after - y_before) > 0.001, "marker world Y animates")
	print("TASK014 RENDER marker Y=", y_before, " -> ", y_after)
	var output_dir := OS.get_environment("TASK014_OUTPUT_DIR")
	if not output_dir.is_empty():
		for enabled in [false, true]:
			main._apply_palette_enabled(enabled)
			await frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_dir.path_join("room_badge_palette_%s.png" % enabled))
	print("TASK014 RENDER checks=", checks, " failures=", failures.size())
	main.free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
