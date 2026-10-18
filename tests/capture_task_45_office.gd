extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OUTPUT := "res://.runtime/task45/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	root.add_child(world)
	world.regenerate(42001)
	world.player.invulnerability_left = 1000.0
	world.player.set_physics_process(false)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	for room_id in [4, 5]:
		var room: Dictionary = world.rooms[room_id]
		world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
		world.activate_room(room_id)
		for _i in 12:
			await process_frame
		var image := root.get_texture().get_image()
		if image == null:
			push_error("Viewport image unavailable")
			quit(1)
			return
		var path := OUTPUT + "room_%d.png" % room_id
		image.save_png(path)
		print("CAPTURE: ", ProjectSettings.globalize_path(path))
		if room_id == 5:
			# Camera-only comparison: identical current assets and seed, old yaw.
			var formal_rotation: Vector3 = world.camera_rig.rotation
			world.camera_rig.rotation.y = 0.0
			world.room_visibility.refresh_active_presentation()
			for _i in 4:
				await process_frame
			var comparison := root.get_texture().get_image()
			comparison.save_png(OUTPUT + "room_5_yaw0_comparison.png")
			world.camera_rig.rotation = formal_rotation
			world.room_visibility.refresh_active_presentation()
	world.queue_free()
	await process_frame
	quit()
