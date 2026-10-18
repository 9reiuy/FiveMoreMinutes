extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING TASK-018 ALWAYS VISIBLE ROOMS & TIERED LIGHTING TEST ===")

	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = true
	root.add_child(world)

	await frames(2)
	check(world.regenerate(42001), "World regenerate succeeded (seed 42001)")
	await frames(6)

	# -------------------------------------------------------------
	# Test Suite 1: Minimap Removal Verification
	# -------------------------------------------------------------
	print("\n--- Test Suite 1: Minimap Removal ---")
	var hud_node: Node = world.get_node_or_null("GameplayCanvas/GameplayUI")
	if hud_node != null:
		check(hud_node.get("dungeon_minimap") == null, "dungeon_minimap property on HUD is null")
		check(hud_node.get_node_or_null("DungeonMinimap") == null, "DungeonMinimap node absent from GameplayUI")
	else:
		check(true, "GameplayUI node checked")

	# -------------------------------------------------------------
	# Test Suite 2: Room Count & Layout Scale
	# -------------------------------------------------------------
	print("\n--- Test Suite 2: Layout Scale ---")
	var rooms: Array = world.rooms
	check(rooms.size() >= 14, "Rooms size is at least 14 (got %d)" % rooms.size())
	check(world.current_room_id == world.spawn_room_id, "Current room is spawn room (%d)" % world.spawn_room_id)

	# -------------------------------------------------------------
	# Test Suite 3: Pre-Spawned Furniture Across All Rooms
	# -------------------------------------------------------------
	print("\n--- Test Suite 3: Pre-Spawned Furniture & Visibility ---")
	var furniture_root: Node2D = world.furniture_root
	check(furniture_root != null, "furniture_root exists")
	var total_furniture := furniture_root.get_child_count()
	check(total_furniture > 20, "Total furniture spawned at start > 20 (got %d)" % total_furniture)

	var furniture_rooms: Dictionary = {}
	var all_furniture_visible := true
	for child in furniture_root.get_children():
		var r_id: int = int(child.get_meta(&"dream_room_id", -1))
		if r_id >= 0:
			furniture_rooms[r_id] = int(furniture_rooms.get(r_id, 0)) + 1
		var c_item := child as CanvasItem
		if c_item != null and not c_item.visible:
			all_furniture_visible = false

	check(furniture_rooms.size() >= 9, "Furniture spawned across at least 9 rooms (got %d rooms)" % furniture_rooms.size())
	check(all_furniture_visible, "All 2D furniture CanvasItems have visible == true")

	# Verify 3D furniture visuals in actor_depth_bridges_root
	var bridges_root: Node3D = world.actor_depth_bridges_root
	check(bridges_root != null, "actor_depth_bridges_root exists")
	var furniture_visual_count := 0
	var all_furniture_visuals_visible := true
	for bridge in bridges_root.get_children():
		if bridge is Furniture3DVisual:
			furniture_visual_count += 1
			if not bridge.visible:
				all_furniture_visuals_visible = false
	check(furniture_visual_count > 20, "Total Furniture3DVisual instances > 20 (got %d)" % furniture_visual_count)
	check(all_furniture_visuals_visible, "All Furniture3DVisual instances have visible == true")

	# -------------------------------------------------------------
	# Test Suite 4: Pre-Spawned Enemies & Always-Visible Presentation
	# -------------------------------------------------------------
	print("\n--- Test Suite 4: Pre-Spawned Enemies & Visibility ---")
	var enemy_root: Node2D = world.enemy_root
	check(enemy_root != null, "enemy_root exists")
	var total_enemies := enemy_root.get_child_count()
	check(total_enemies > 0, "Enemies spawned at start > 0 (got %d)" % total_enemies)

	var enemy_rooms: Dictionary = {}
	var unentered_dormant_ok := true
	var unentered_visible_ok := true
	var unentered_hurtbox_ok := true
	var sample_unentered_room := -1

	for child in enemy_root.get_children():
		var enemy := child as EmployeeEnemy
		if enemy == null:
			continue
		var r_id: int = int(enemy.get_meta(&"dream_room_id", -1))
		if r_id >= 0:
			enemy_rooms[r_id] = int(enemy_rooms.get(r_id, 0)) + 1

		if r_id != world.current_room_id:
			if sample_unentered_room < 0:
				sample_unentered_room = r_id
			# In unentered room, runtime active should be false (idle)
			if enemy.room_runtime_active:
				unentered_dormant_ok = false
			# But visible should be true
			if not enemy.visible:
				unentered_visible_ok = false
			# Hurtbox should be monitorable so bullets can hit
			var hurtbox := enemy.get_node_or_null("Hurtbox") as Area2D
			if hurtbox == null or not hurtbox.monitorable:
				unentered_hurtbox_ok = false

	check(enemy_rooms.size() >= 5, "Enemies spawned across at least 5 combat rooms (got %d rooms)" % enemy_rooms.size())
	check(unentered_dormant_ok, "Unentered room enemies have room_runtime_active == false (idle)")
	check(unentered_visible_ok, "Unentered room enemies have visible == true (always visible)")
	check(unentered_hurtbox_ok, "Unentered room enemies have hurtbox.monitorable == true (shootable)")

	# Verify enemy 3D depth bridges
	var enemy_bridges_visible := true
	for bridge in bridges_root.get_children():
		if not bridge.has_meta(&"source_actor"):
			continue
		var src: Variant = bridge.get_meta(&"source_actor")
		if src is EmployeeEnemy:
			var sprite = bridge.get("actor_sprite")
			if sprite != null and is_instance_valid(sprite):
				if not sprite.visible:
					enemy_bridges_visible = false
	check(enemy_bridges_visible, "All enemy 3D depth bridges have actor_sprite.visible == true")

	# -------------------------------------------------------------
	# Test Suite 5: Tiered Lighting Verification
	# -------------------------------------------------------------
	print("\n--- Test Suite 5: Tiered Lighting ---")
	var light_root: Node3D = world.ceiling_light_root
	check(light_root != null, "ceiling_light_root exists")
	var total_lights := light_root.get_child_count()
	check(total_lights > 0, "Total ceiling light fixtures > 0 (got %d)" % total_lights)

	var all_holders_visible := true
	var spots_tiered_correctly := true
	for holder in light_root.get_children():
		if not holder.visible:
			all_holders_visible = false
		var holder_room: int = int(holder.get_meta(&"dream_room_id", -1))
		var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
		if spot != null:
			var should_cast_shadow: bool = (holder_room == int(world.get("current_room_id"))) and light_root.get("shadow_enabled") == true
			if not spot.visible or spot.shadow_enabled != should_cast_shadow:
				spots_tiered_correctly = false

	check(all_holders_visible, "All room light holders have visible == true (all rooms bright)")
	check(spots_tiered_correctly, "SpotLights stay lit across rooms; only current room may cast shadows (%d)" % world.current_room_id)

	# -------------------------------------------------------------
	# Test Suite 6: Cross-Room Awake & Alertness
	# -------------------------------------------------------------
	print("\n--- Test Suite 6: Cross-Room Awake ---")
	check(sample_unentered_room >= 0, "Found sample unentered room with enemies (room %d)" % sample_unentered_room)
	if sample_unentered_room >= 0:
		world.wake_room_enemies(sample_unentered_room, Vector2(100, 100))
		await frames(2)

		var room_enemies_awakened := true
		for child in enemy_root.get_children():
			var enemy := child as EmployeeEnemy
			if enemy == null:
				continue
			var r_id: int = int(enemy.get_meta(&"dream_room_id", -1))
			if r_id == sample_unentered_room:
				if not enemy.room_runtime_active or not enemy.hostile:
					room_enemies_awakened = false

		check(room_enemies_awakened, "wake_room_enemies awakened all enemies in room %d (active & hostile)" % sample_unentered_room)

	# -------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------
	print("\n==================================================")
	print("CHECKS PASSED: %d / %d" % [checks - failures.size(), checks])
	if not failures.is_empty():
		print("FAILED CHECKS (%d):" % failures.size())
		for f in failures:
			print("  - ", f)
		print("==================================================")
		quit(1)
	else:
		print("ALL CHECKS PASSED SUCCESSFULLY!")
		print("==================================================")
		quit(0)
