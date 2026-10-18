extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const TAROT_CATALOG := preload("res://scripts/data/tarot_card_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== RUNNING RECEPTION & TAROT INTEGRATION CAPTURE (1024x576) ===")
	root.size = Vector2i(1024, 576)

	var preview = PREVIEW_SCENE.instantiate()
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	preview.preview_mode = false
	preview.world = room
	root.add_child(preview)

	# Settle initial layout and frames
	for frame in 30:
		await process_frame

	# 1. Position player in front of reception desk
	print("Step 1: Player stands at reception desk front center...")
	room.player.global_position = Vector2(11.5, 3.85) * 32.0
	room.interaction_resolver.update_target()
	room._update_interaction_prompt()

	assert(room.interaction_prompt.visible == true, "Interaction prompt must be visible")
	assert(room.interaction_prompt.text == "[E] 交谈", "Prompt text must be '[E] 交谈'")

	for frame in 10:
		await process_frame

	var img_prompt := root.get_texture().get_image()
	if img_prompt != null:
		img_prompt.save_png("res://tests/reception_desk_prompt_fixed.png")
		print("  [SAVED] res://tests/reception_desk_prompt_fixed.png")

	# 1.5 Open waitress dialogue and verify centered presentation (portrait hidden)
	print("Step 1.5: Interacting with Waitress (opening centered dialogue)...")
	room._on_waitress_interaction_requested()
	# Settle animation and complete typewriter immediately for crisp screenshot
	for frame in 20:
		await process_frame
	if room.dialogue_dialog != null:
		room.dialogue_dialog._complete_typewriter()
	for frame in 10:
		await process_frame

	var img_dialogue := root.get_texture().get_image()
	if img_dialogue != null:
		img_dialogue.save_png("res://tests/waitress_dialogue_centered.png")
		print("  [SAVED] res://tests/waitress_dialogue_centered.png")

	room.dialogue_dialog.close_without_signal()
	for frame in 10:
		await process_frame

	# 2. Hand-craft 3 cards for deterministic reveal capture
	print("Step 2: Triggering Tarot sequence...")
	var card_fool := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_fool"), false)
	var card_magician := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_magician"), true)
	var card_star := TarotDrawResult.new(TAROT_CATALOG.get_card(&"the_star"), false)
	room.tarot_visit_state.hand = [card_fool, card_magician, card_star]
	room.tarot_visit_state.hand_generated = true

	room._start_tarot_sequence()
	var overlay: TarotOverlay = room.tarot_overlay

	assert(overlay != null, "tarot_overlay must exist")

	var wait_ticks := 0
	while overlay.current_state != TarotOverlay.State.CHOOSING and wait_ticks < 300:
		for frame in 2:
			await process_frame
		wait_ticks += 1
	print("Reached state:", overlay.current_state, "after ticks:", wait_ticks)

	for frame in 15:
		await process_frame

	var img_reveal := root.get_texture().get_image()
	if img_reveal != null:
		img_reveal.save_png("res://tests/tarot_overlay_reveal_fixed.png")
		print("  [SAVED] res://tests/tarot_overlay_reveal_fixed.png")

	# 3. Simulate selecting the middle reversed card (The Magician · 逆位)
	print("Step 3: Selecting middle card (The Magician · 逆位)...")
	var cards := overlay.get_cards()
	var selected_card := cards[1]
	selected_card.card_selected.emit(selected_card)

	# Wait for card select punch and hold (0.5s)
	for frame in 45:
		await process_frame

	var img_selected := root.get_texture().get_image()
	if img_selected != null:
		img_selected.save_png("res://tests/tarot_overlay_selected_fixed.png")
		print("  [SAVED] res://tests/tarot_overlay_selected_fixed.png")

	print("=== ALL SCREENSHOTS CAPTURED SUCCESSFULLY ===")
	preview.queue_free()
	quit(0)
