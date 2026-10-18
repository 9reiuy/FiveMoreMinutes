extends SceneTree

const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate() as Dream3DReceptionRoom
	root.add_child(room)
	for i in range(10):
		await process_frame

	room.player.global_position = Vector2(11.5, 3.85) * 32.0
	room._update_camera_and_projection(0.016)
	var w_pos1 := room._get_waitress_hud_pos()
	var p_pos1 := room._get_player_hud_pos()
	print("POS 1: Waitress HUD = ", w_pos1, ", Player HUD = ", p_pos1)

	# Simulate player moving to the right by 64px
	room.player.global_position = Vector2(11.5 + 2.0, 3.85) * 32.0
	room._update_camera_and_projection(0.016)
	var w_pos2 := room._get_waitress_hud_pos()
	var p_pos2 := room._get_player_hud_pos()
	print("POS 2: Waitress HUD = ", w_pos2, ", Player HUD = ", p_pos2)

	# Dialogue bubble position
	room.dialogue_bubble.set_speaker_hud_position(w_pos1)
	var bubble_pos1 := room.dialogue_bubble.position
	room.dialogue_bubble.set_speaker_hud_position(w_pos2)
	var bubble_pos2 := room.dialogue_bubble.position
	print("BUBBLE POS 1 = ", bubble_pos1, ", BUBBLE POS 2 = ", bubble_pos2)

	room.queue_free()
	quit()
