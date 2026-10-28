extends RefCounted
## Keep the real lobby/cab live while a frozen target world renders offscreen.
## The existing display wrapper stays intact on commit: no actor reparent/copy.
static func run(main: Node, dream: Node3D) -> void:
	var tree := main.get_tree()
	var source: Node3D = main._supported_dream_world
	var previous: Control = main.current_screen
	var screen: Control = main.SELECTIVE_PIXEL_SCENE.instantiate()
	screen.preview_mode = false
	screen.staging = true
	screen.world = dream
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hide()
	dream.generate_on_ready = false
	dream.loading_render_preparation_pending = true
	dream.floor_transition_in_progress = true
	main.scene_container.add_child(screen)
	# The loading world must not own global time or music while the lobby is live.
	dream._exit_dream_time_mode()
	source._enter_dream_time_mode()
	preload("res://scripts/audio/sfx_manager.gd").play_elevator_music(source.get_instance_id())
	var failed: bool = bool(main.get_meta(&"test_fail_reception_generation", false))
	var ok := false
	if not failed:
		ok = await dream._regenerate_staged(dream.seed, 0, dream.transition_generation_token)
	if ok and is_instance_valid(dream) and dream.begin_firearm_render_preparation():
		var report: Dictionary = await preload("res://scripts/dream/firearm_render_preparation.gd").run(tree, dream)
		ok = not bool(report.get("cancelled", false))
		dream.complete_firearm_render_preparation(report)
	if not is_instance_valid(source) or main.current_screen != previous:
		screen.queue_free()
		return
	if not ok:
		screen.queue_free()
		# Await disposal so a retiring world cannot clear the restored time/audio.
		await tree.process_frame
		if is_instance_valid(source): source.rollback_elevator_entry()
		main.set_meta(&"last_reception_journey", {"success":false,"retryable":true})
		return
	# This is actual visible, unpaused cab time, not time spent generating.
	var visible_seconds := 0.0
	var last := Time.get_ticks_usec()
	while visible_seconds < dream.ELEVATOR_VISIBLE_RIDE_SECONDS:
		await tree.process_frame
		if not is_instance_valid(source) or main.current_screen != previous:
			screen.queue_free()
			return
		var now := Time.get_ticks_usec()
		if not tree.paused: visible_seconds += minf(float(now-last)/1000000.0, .1)
		last = now
	# Preserve the actual prepared display/viewport, including captured resources.
	var blend: CanvasLayer
	var picture: TextureRect
	if DisplayServer.get_name() != "headless":
		blend = CanvasLayer.new()
		blend.layer = 37
		picture = TextureRect.new()
		picture.texture = ImageTexture.create_from_image(tree.root.get_texture().get_image())
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blend.add_child(picture)
		main.add_child(blend)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source.player.movement_enabled = false
	previous.process_mode = Node.PROCESS_MODE_DISABLED
	previous.hide()
	for item in previous.find_children("*", "CanvasLayer", true, false): item.hide()
	main.current_screen = screen
	main._supported_dream_world = dream
	main.pause_allowed = true
	screen.commit_staging()
	screen.process_mode = Node.PROCESS_MODE_INHERIT
	dream._enter_dream_time_mode()
	main._apply_palette_enabled(main.get_tree().root.get_node("SettingsManager").get_palette_enabled())
	previous.queue_free()
	await tree.process_frame
	dream._set_building_exterior_visible(true)
	dream.floor_transition_in_progress = false
	dream.finish_loading_render_preparation()
	if is_instance_valid(blend):
		var reveal := main.create_tween()
		reveal.tween_property(picture, "modulate:a", 0.0, .3)
		await reveal.finished
		blend.queue_free()
	main.set_meta(&"last_reception_journey", {"success":true,"visible_ride_seconds":visible_seconds,"fullscreen_loading":false})
