class_name CaptureTarotOverlay
extends SceneTree

const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const TAROT_CATALOG := preload("res://scripts/data/tarot_card_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- STARTING TAROT SCREENSHOT CAPTURE ---")
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	root.add_child(room)

	# Let initial frames settle
	for frame in 30:
		await process_frame

	# 1. Capture Dialogue with Waitress
	print("1. Opening Waitress interaction dialogue...")
	room._on_waitress_interaction_requested()
	# Wait for dialogue animation to slide in and complete typewriter
	await create_timer(0.35).timeout
	if room.dialogue_dialog != null:
		room.dialogue_dialog._complete_typewriter()
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw

	var img_dialogue := root.get_texture().get_image()
	if img_dialogue != null and not img_dialogue.is_empty():
		img_dialogue.save_png("res://tests/tarot_dialogue.png")
		print("  [SAVED] res://tests/tarot_dialogue.png")

	# Close dialogue cleanly
	if room.dialogue_dialog != null:
		room.dialogue_dialog.close_without_signal()
	await create_timer(0.1).timeout

	# 2. Hand-craft 3 diverse cards: The Fool (upright), The Magician (reversed), The Star (upright)
	print("2. Starting Tarot 3-card reveal...")
	var card_fool := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_fool"), false)
	var card_magician := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_magician"), true)
	var card_star := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_star"), false)
	var typed_hand: Array[TarotDrawResult] = [card_fool, card_magician, card_star]
	room.tarot_visit_state.hand = typed_hand
	room.tarot_visit_state.hand_generated = true

	# Start tarot sequence
	room._start_tarot_sequence()
	var overlay: TarotOverlay = room.active_tarot_overlay

	# Wait until sequence reaches CHOOSING state
	while overlay.current_state != TarotOverlay.State.CHOOSING:
		await create_timer(0.05).timeout

	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw

	var img_reveal := root.get_texture().get_image()
	if img_reveal != null and not img_reveal.is_empty():
		img_reveal.save_png("res://tests/tarot_overlay_reveal.png")
		print("  [SAVED] res://tests/tarot_overlay_reveal.png")

	# 3. Simulate selecting the middle reversed card (The Magician · 逆位)
	print("3. Selecting middle card (The Magician · 逆位)...")
	var cards := overlay.get_cards()
	var selected_card := cards[1]
	selected_card.card_selected.emit(selected_card)

	# Wait 0.4s into the 0.8s hold so it is centered and enlarged with selection glow
	await create_timer(0.4).timeout
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw

	var img_selected := root.get_texture().get_image()
	if img_selected != null and not img_selected.is_empty():
		img_selected.save_png("res://tests/tarot_overlay_selected.png")
		print("  [SAVED] res://tests/tarot_overlay_selected.png")

	print("--- TAROT SCREENSHOTS CAPTURED SUCCESSFULLY! ---")
	quit(0)
