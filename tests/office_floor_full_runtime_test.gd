extends SceneTree

const FLOOR_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)


func _run() -> void:
	var world := FLOOR_SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	await process_frame
	_check(world.regenerate(42001), "fixed-seed floor builds")
	await process_frame
	_check(not world.lazy_room_presentation, "full floor presentation enabled")
	var enemy_count: int = world.enemy_root.get_child_count()
	_check(enemy_count > 0, "distant encounters exist before room entry")
	var all_active := true
	for enemy in world.enemy_root.get_children():
		if enemy is EmployeeEnemy and not bool(enemy.get("room_runtime_active")):
			all_active = false
	_check(all_active, "all enemies stay active")
	var mask := world.room_visibility.outside_black_gradient as ColorRect
	_check(mask != null and mask.get_parent() is CanvasLayer, "screen-wide footprint mask exists")
	if mask != null:
		_check((mask.get_parent() as CanvasLayer).layer < world.ui_layer.layer, "footprint mask leaves HUD unobstructed")
		var material := mask.material as ShaderMaterial
		var texture: Texture2D = material.get_shader_parameter("footprint_distance")
		var grid_origin: Vector2 = material.get_shader_parameter("grid_origin")
		var atlas := texture.get_image()
		var cab_texel := Vector2i(world.elevator_anchor_cell) - Vector2i(grid_origin)
		_check(atlas.get_pixelv(cab_texel).r > 0.95, "unrendered in-floor cab cells are blacked out")
	_check(world.elevator_floor_door != null and world.elevator_floor_door.get_parent() == world.wake_exit_root,
		"only floor door is attached to generated floor")
	var alternate_room := -1
	for room in world.rooms:
		var candidate := int(room.get("id", -1))
		if candidate >= 0 and candidate != world.spawn_room_id:
			alternate_room = candidate
			break
	if alternate_room >= 0:
		world.activate_room(alternate_room)
		await process_frame
		_check(world.enemy_root.get_child_count() == enemy_count, "room entry does not duplicate enemies")
		all_active = true
		for enemy in world.enemy_root.get_children():
			if enemy is EmployeeEnemy and not bool(enemy.get("room_runtime_active")):
				all_active = false
		_check(all_active, "room entry does not freeze distant enemies")
	for repeat in 2:
		_check(world.regenerate(42001), "same-seed rebuild %d succeeds" % repeat)
		await process_frame
		var mask_layers := 0
		for child in world.room_visibility.get_children():
			if child is CanvasLayer and not child.is_queued_for_deletion():
				mask_layers += 1
		_check(mask_layers == 1, "one live mask after rebuild %d" % repeat)
		_check(world.enemy_root.get_child_count() == enemy_count,
			"enemy nodes do not accumulate after rebuild %d" % repeat)
	world.queue_free()
	await process_frame
	print("Office full-floor runtime: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
