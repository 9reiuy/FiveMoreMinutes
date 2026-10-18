extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const OUTPUT := "res://.runtime/map_rotation_review/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	root.add_child(world)
	if not world.regenerate(42001):
		quit(1)
		return
	world.player.invulnerability_left = 1000.0
	world.player.set_physics_process(false)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	for key in ["office", "restroom", "reception"]:
		for room in world.rooms:
			if String(room.get("sample_key", "")) != key:
				continue
			var room_id := int(room.get("id", -1))
			world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
			world.set_current_room_id(room_id)
			world.room_visibility.reveal_room(room_id)
			world.activate_room(room_id)
			world._update_camera_and_actor_projection(0.016)
			for _i in 15:
				await process_frame
			if DisplayServer.get_name() == "headless":
				continue
			var image := root.get_texture().get_image()
			var path: String = OUTPUT + key + ".png"
			image.save_png(path)
			print("CAPTURE: ", ProjectSettings.globalize_path(path))
			break
	world.queue_free()
	await process_frame
	quit()
