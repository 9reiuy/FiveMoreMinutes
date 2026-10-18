extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var preview = PREVIEW_SCENE.instantiate()
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	preview.preview_mode = false
	preview.world = room
	root.add_child(preview)

	for i in range(25):
		await process_frame

	room.player.global_position = Vector2(11.5, 3.85) * 32.0
	room._update_camera_and_projection(0.016)

	for i in range(10):
		await process_frame

	var bridge_ref: WeakRef = room.waitress_npc.get_meta(&"depth_visual_bridge")
	var bridge = bridge_ref.get_ref()
	print("Bridge actor_sprite global_position: ", bridge.actor_sprite.global_position)
	var sprite_screen_pos = room.camera_3d.unproject_position(bridge.actor_sprite.global_position)
	print("Sprite unprojected position: ", sprite_screen_pos)

	var waitress_hud_pos = room._get_waitress_hud_pos()
	print("Calculated waitress_hud_pos: ", waitress_hud_pos)
	print("Difference: ", sprite_screen_pos - waitress_hud_pos)

	# Now move player by 64px
	room.player.global_position += Vector2(64.0, 32.0)
	room._update_camera_and_projection(0.016)
	bridge._process(0.016)
	for i in range(5):
		await process_frame

	var sprite_screen_pos2 = room.camera_3d.unproject_position(bridge.actor_sprite.global_position)
	var waitress_hud_pos2 = room._get_waitress_hud_pos()
	print("\nAfter player move:")
	print("Sprite unprojected position: ", sprite_screen_pos2)
	print("Calculated waitress_hud_pos: ", waitress_hud_pos2)
	print("Difference: ", sprite_screen_pos2 - waitress_hud_pos2)

	preview.queue_free()
	quit()
