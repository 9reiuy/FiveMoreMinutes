extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node3D = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	if not world.regenerate(42001):
		quit(2)
		return
	var room_id := -1
	var room_center := Vector2.ZERO
	for room in world.rooms:
		if String(room.get("archetype", "")) == "open_office":
			room_id = int(room.id)
			room_center = Vector2(room.center_cell) * world.CELL_PIXELS
			break
	if room_id < 0:
		quit(3)
		return
	world.player.global_position = room_center
	world.activate_room(room_id)
	world.player.movement_enabled = false
	var victim: EmployeeEnemy
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy:
			actor.set_physics_process(false)
			if victim == null and int(actor.get_meta(&"dream_room_id", -1)) == room_id:
				victim = actor
	if victim == null:
		quit(4)
		return
	victim.global_position = room_center + Vector2(32.0, 0.0)
	for _i in 5:
		await process_frame
	victim.take_damage(999.0, Vector2.LEFT, 280.0, &"shotgun")
	var bridge_ref: Variant = victim.get_meta(&"depth_visual_bridge", null)
	var bridge: Node3D = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	if bridge == null:
		quit(5)
		return
	var failures := 0
	for sample in 15:
		for _i in 4:
			await process_frame
		var lowest := float(bridge.get("lowest_visible_pixel"))
		var viewport := bridge.get("render_viewport") as SubViewport
		var sprite := bridge.get("actor_sprite") as Sprite3D
		var camera := world.camera_3d as Camera3D
		var up_y := camera.global_basis.orthonormalized().y.y
		var capture_offset := bridge.get("viewport_offset") as Vector2
		var visible_bottom_y := sprite.global_position.y - up_y * (lowest + capture_offset.y - float(viewport.size.y) * 0.5) / 32.0
		if lowest > 0.0 and visible_bottom_y < -0.01:
			failures += 1
		print("CORPSE_CONTACT sample=", sample, " bottom_y=", visible_bottom_y, " opaque_y=", lowest, " viewport=", viewport.size)
		if sample in [5, 14] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/corpse_contact_%02d.png" % sample)
	world.queue_free()
	for _i in 4:
		await process_frame
	print("CORPSE_CONTACT failures=", failures)
	quit(0 if failures == 0 else 1)
