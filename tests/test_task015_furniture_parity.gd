extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const FURNITURE_3D_VISUAL_SCRIPT := preload("res://scripts/dream/furniture_3d_visual.gd")
const FURNITURE_3D_DEBRIS_SCRIPT := preload("res://scripts/dream/furniture_3d_debris.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
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
	print("=== STARTING TASK-015 FURNITURE 3D PARITY TEST ===")

	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)

	# 1. Regenerate dungeon floor
	check(world.regenerate(42001), "Regenerate initial floor 42001")
	await frames(5)

	# 2. Test full production furniture presentation mapping (All 15 pool scenes)
	var converted_scenes := [
		"res://scenes/dream/props/parcel_box_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
		"res://scenes/dream/props/small_table_01.tscn",
		"res://scenes/dream/props/filing_cabinet_01.tscn",
		"res://scenes/dream/props/sticker_parcel_box_01.tscn",
		"res://scenes/dream/props/storage_cabinet_01.tscn",
		"res://scenes/dream/props/wardrobe_01.tscn",
		"res://scenes/dream/props/fridge_01.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/bed_01.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/chair.tscn",
	]

	for path in converted_scenes:
		var packed: PackedScene = load(path)
		check(packed != null, "Loaded scene: %s" % path)
		var furn := packed.instantiate() as RigidBody2D
		check(furn != null, "Instantiated %s as RigidBody2D" % path)
		furn.position = Vector2(128.0, 96.0)
		furn.rotation = 0.5
		furn.set_meta(&"dream_room_id", 0)
		world.furniture_root.add_child(furn)

		# Spawn presentation
		var visual_node: Node3D = world._spawn_furniture_presentation(furn)
		check(visual_node != null, "Presentation spawned for %s" % path)
		check(visual_node.get_script() == FURNITURE_3D_VISUAL_SCRIPT, "%s received Furniture3DVisual adapter" % path)

		# Check 2D sprite/shadow hidden
		var spr := furn.get_node_or_null("Sprite2D") as CanvasItem
		var shd := furn.get_node_or_null("Shadow") as CanvasItem
		check(spr != null and not spr.visible, "2D Sprite2D hidden for %s" % path)
		check(shd != null and not shd.visible, "2D Shadow hidden for %s" % path)

		# Check 3D transform accuracy
		check(absf(visual_node.position.x - 128.0 / 32.0) < 0.001, "3D X matches 2D X / 32.0 (got %.3f)" % visual_node.position.x)
		check(absf(visual_node.position.z - 96.0 / 32.0) < 0.001, "3D Z matches 2D Y / 32.0 (got %.3f)" % visual_node.position.z)
		check(absf(visual_node.rotation.y - (-0.5)) < 0.001, "3D Yaw matches -2D rotation (got %.3f)" % visual_node.rotation.y)

		# Check visual mesh exists and has StandardMaterial3D
		var visual_inst: Node3D = visual_node.get("visual_instance")
		check(visual_inst != null, "3D VisualInstance3D instantiated for %s" % path)
		var mesh_inst: MeshInstance3D = visual_inst.get_node_or_null("MeshInstance3D")
		check(mesh_inst != null and mesh_inst.mesh != null, "MeshInstance3D valid with mesh for %s" % path)

		# Test 2D push response & visual lockstep
		furn.apply_central_impulse(Vector2(200.0, 0.0))
		await frames(3)
		var diff_x := absf(visual_node.position.x - furn.global_position.x / 32.0)
		var diff_z := absf(visual_node.position.z - furn.global_position.y / 32.0)
		check(diff_x < 0.001, "3D visual dynamically tracks 2D push X for %s" % path)
		check(diff_z < 0.001, "3D visual dynamically tracks 2D push Z for %s" % path)

		# Clean up test prop
		furn.queue_free()
		await frames(2)
		check(not is_instance_valid(visual_node), "3D visual freed on 2D prop queue_free for %s" % path)

	# 3. Test Vaulting parity across categories
	var vaultable_cases := [
		"res://scenes/dream/props/parcel_box_01.tscn",
		"res://scenes/dream/props/sticker_parcel_box_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
		"res://scenes/dream/props/small_table_01.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/chair.tscn",
	]
	for vpath in vaultable_cases:
		var p: RigidBody2D = load(vpath).instantiate()
		check(p.call("is_vaultable") == true, "%s is vaultable (Small/Medium)" % vpath.get_file())
		p.free()

	var non_vaultable_cases := [
		"res://scenes/dream/props/filing_cabinet_01.tscn",
		"res://scenes/dream/props/storage_cabinet_01.tscn",
		"res://scenes/dream/props/wardrobe_01.tscn",
		"res://scenes/dream/props/fridge_01.tscn",
		"res://scenes/dream/props/bed_01.tscn",
	]
	for nvpath in non_vaultable_cases:
		var p: RigidBody2D = load(nvpath).instantiate()
		check(p.call("is_vaultable") == false, "%s is NOT vaultable (Large)" % nvpath.get_file())
		p.free()

	# 4. Test non-furniture fallback retains ActorDepthBridge
	var non_furniture := Node2D.new()
	var test_spr := Sprite2D.new()
	test_spr.name = "Sprite2D"
	non_furniture.add_child(test_spr)
	world.furniture_root.add_child(non_furniture)
	var fallback_bridge: Node3D = world._spawn_furniture_presentation(non_furniture)
	check(fallback_bridge != null, "Fallback presentation spawned for non-furniture")
	check(not (fallback_bridge.get_script() == FURNITURE_3D_VISUAL_SCRIPT), "Non-furniture uses standard ActorDepthBridge")
	non_furniture.queue_free()
	await frames(2)

	# 5. Test Destruction & Debris
	var test_box: RigidBody2D = load("res://scenes/dream/props/parcel_box_01.tscn").instantiate()
	test_box.position = Vector2(300.0, 300.0)
	world.furniture_root.add_child(test_box)
	var box_visual: Node3D = world._spawn_furniture_presentation(test_box)
	await frames(2)

	test_box.destroy()
	check(test_box.destroyed == true, "2D prop destroyed flag set")
	await frames(3)

	# Verify debris was added
	var debris_found := false
	for child in world.actor_depth_bridges_root.get_children():
		if child.get_script() == FURNITURE_3D_DEBRIS_SCRIPT:
			debris_found = true
			break
	check(debris_found, "Furniture3DDebris spawned on destruction")

	# 6. Verify dungeon floor furniture generation has ZERO legacy fallback
	var dungeon_3d_visual_count := 0
	var dungeon_legacy_furniture_fallback_count := 0
	for child in world.actor_depth_bridges_root.get_children():
		if child.get_script() == FURNITURE_3D_VISUAL_SCRIPT:
			dungeon_3d_visual_count += 1
		elif child.has_meta(&"source_actor"):
			var src: Variant = child.get_meta(&"source_actor")
			if src is Node2D and src.is_in_group(&"damageable_props"):
				dungeon_legacy_furniture_fallback_count += 1
	print("Found %d 3D Furniture Visuals naturally spawned in floor 42001" % dungeon_3d_visual_count)
	print("Found %d legacy furniture fallbacks in floor 42001" % dungeon_legacy_furniture_fallback_count)
	check(dungeon_3d_visual_count > 0, "Dungeon spawned 3D Furniture Visuals in rooms (got %d)" % dungeon_3d_visual_count)
	check(dungeon_legacy_furniture_fallback_count == 0, "Dungeon has ZERO legacy furniture fallbacks (got %d)" % dungeon_legacy_furniture_fallback_count)

	# 7. Verify Elevator and Corridor have ZERO furniture
	var elevator_corridor_furniture_count := 0
	if world.furniture_root != null:
		for f in world.furniture_root.get_children():
			var rid: int = f.get_meta("dream_room_id", -1)
			var f_pos: Vector2 = f.global_position
			var dist_to_door := f_pos.distance_to(world.elevator_door_pos_2d) if world.elevator_door_pos_2d != Vector2.ZERO else 9999.0
			var dist_to_anchor := f_pos.distance_to(Vector2(world.elevator_anchor_cell) * world.CELL_PIXELS) if world.elevator_anchor_cell != Vector2i.ZERO else 9999.0
			var r: Dictionary = world.rooms[rid] if rid >= 0 and rid < world.rooms.size() else {}
			var r_type: StringName = StringName(r.get("room_type", &""))
			var arch: String = String(r.get("archetype", ""))
			if rid == world.spawn_room_id or rid == world.elevator_room_id or r_type in [&"elevator_lobby", &"corridor"] or arch in ["elevator_lobby", "corridor"] or dist_to_door < 160.0 or dist_to_anchor < 160.0:
				elevator_corridor_furniture_count += 1
	check(elevator_corridor_furniture_count == 0, "Elevator and corridor have ZERO furniture (got %d)" % elevator_corridor_furniture_count)

	print("=== TEST COMPLETED ===")
	print("Total failures: ", failures.size())
	if failures.size() > 0:
		for f in failures:
			print("  * ", f)
		quit(1)
	else:
		print("ALL TASK-015 CHECKS PASSED!")
		quit(0)
