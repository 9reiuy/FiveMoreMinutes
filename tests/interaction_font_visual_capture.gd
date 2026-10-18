extends SceneTree
## Silent screen-space typography check against the live pixelated office.

const PREVIEW = preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	var preview: Control = PREVIEW.instantiate()
	root.add_child(preview)
	for _i in 10:
		await process_frame
	var world: Node3D = preview.world
	world.player.invulnerability_left = 999.0
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	for _i in 35:
		await process_frame
	preview.status_label.hide()
	world.set_process(false)
	world.player.set_physics_process(false)
	world.interaction_prompt.text = "E 交换为小手枪"
	world.interaction_prompt.position = Vector2(280, 285)
	world.interaction_prompt.visible = true
	world.weapon_name_popup.text = "小手枪"
	world.weapon_name_popup.position = Vector2(280, 250)
	world.weapon_name_popup.visible = true
	for enabled in [true, false]:
		preview.set_selective_enabled(enabled)
		for _i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "pixelated" if enabled else "native"
		root.get_texture().get_image().save_png("res://.runtime/interaction_font_%s.png" % suffix)
	preview.queue_free()
	for _i in 5:
		await process_frame
	quit()
