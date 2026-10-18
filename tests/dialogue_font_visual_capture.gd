extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/font_fixed_"+name+".png")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	var room = load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.preview_mode=false
	display.world=room
	root.add_child(display)
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	await frames(30)
	room.set_process(false)
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	if room.dialogue_controller.is_active(): room.dialogue_controller.dismiss_if_active()
	room.dialogue_bubble.hide()
	room.player.global_position=Vector2(11.5,3.85)*32.0
	for i in 25: room._update_camera_and_projection(0.1)
	await frames(20)
	var anchor: Vector2 = room.player.get_presentation_hud_position(room.camera_3d.unproject_position(room.RECEPTION_DESK_POS_3D + Vector3(0,1.25,0))) + room.INTERACTION_PROMPT_OFFSET
	room.interaction_prompt.present("[E] 交谈",anchor,1)
	await create_timer(0.15).timeout
	await capture("prompt")
	room.interaction_prompt.dismiss(true)
	room.set_process(false)
	room.set_physics_process(false)
	if room.dialogue_controller.is_active(): room.dialogue_controller.dismiss_if_active()
	var bubble = room.dialogue_bubble
	var message := "欢迎来到办公室。需要帮助吗？请选择继续交谈，或返回游戏。"
	bubble.set_player_hud_position(Vector2(300,280))
	bubble.show_dialogue(message,Vector2(320,180),["继续交谈","返回游戏"])
	bubble.set_typing_progress(1.0,message.length())
	await create_timer(0.4).timeout
	await capture("dialogue")
	root.size=Vector2i(1024,576)
	await capture("dialogue_1024")
	display.queue_free()
	await frames(5)
	print("FONT_VISUAL_CAPTURE_DONE")
	quit()
