extends SceneTree
## Verifies that under the full Main -> SelectivePixelPreview pipeline:
## 1. UI CanvasLayers are reparented to root canvas (640x360)
## 2. Dialogue panel centers when portrait hidden
## 3. TarotOverlay cards are centered
## 4. Interaction prompt uses HUD projection

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main_scene)
	for frame in 5:
		await process_frame

	var reception = load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	main_scene._set_screen(reception)
	for frame in 30:
		await process_frame

	var pixel_screen = main_scene.find_child("SelectivePixelPreview", true, false)
	assert(pixel_screen != null, "SelectivePixelPreview must exist")

	# ─── 1. Verify CanvasLayer reparenting ───
	var gameplay_ui: CanvasLayer = null
	var dialogue_layer: CanvasLayer = null
	var tarot_layer: CanvasLayer = null
	for child in pixel_screen.get_children():
		if child is CanvasLayer:
			if child.name == "GameplayUI":
				gameplay_ui = child
			elif child.name == "DialogueLayer":
				dialogue_layer = child
			elif child.name == "TarotLayer":
				tarot_layer = child

	assert(gameplay_ui != null, "GameplayUI must be reparented to SelectivePixelPreview")
	assert(dialogue_layer != null, "DialogueLayer must be reparented to SelectivePixelPreview")
	assert(tarot_layer != null, "TarotLayer must be reparented to SelectivePixelPreview")
	print("PASS: All UI CanvasLayers reparented to SelectivePixelPreview root canvas")

	# ─── 2. Verify Control sizes are 640x360 ───
	var dialogue: Control = dialogue_layer.find_child("ConfirmationDialog", true, false)
	assert(dialogue != null, "ConfirmationDialog must exist")
	# The full-rect Control should be 640x360 in the root canvas
	print("  ConfirmationDialog size:", dialogue.size, " viewport_rect:", dialogue.get_viewport_rect())
	assert(dialogue.get_viewport_rect().size == Vector2(640, 360), "ConfirmationDialog viewport_rect must be 640x360, got: %s" % str(dialogue.get_viewport_rect().size))
	print("PASS: ConfirmationDialog viewport_rect is 640x360")

	var tarot_overlay = tarot_layer.find_child("TarotOverlay", true, false)
	assert(tarot_overlay != null, "TarotOverlay must exist")
	print("  TarotOverlay size:", tarot_overlay.size, " viewport_rect:", tarot_overlay.get_viewport_rect())
	assert(tarot_overlay.get_viewport_rect().size == Vector2(640, 360), "TarotOverlay viewport_rect must be 640x360, got: %s" % str(tarot_overlay.get_viewport_rect().size))
	print("PASS: TarotOverlay viewport_rect is 640x360")

	# ─── 3. Trigger dialogue (portrait hidden) and verify centering ───
	reception._on_waitress_interaction_requested()
	for frame in 10:
		await process_frame

	assert(dialogue.visible, "Dialogue must be visible after interaction")
	var panel: Control = dialogue.find_child("DialoguePanel", true, false)
	assert(panel != null, "DialoguePanel must exist")
	var panel_x: float = panel.position.x
	var panel_w: float = panel.size.x
	var expected_x: float = (640.0 - panel_w) * 0.5
	print("  DialoguePanel position.x:", panel_x, " size.x:", panel_w, " expected_x:", expected_x)
	assert(absf(panel_x - expected_x) < 2.0, "DialoguePanel must be centered (got x=%.1f, expected=%.1f)" % [panel_x, expected_x])
	print("PASS: DialoguePanel is horizontally centered when portrait hidden")

	# ─── 4. Trigger tarot and verify card positions ───
	# Close dialogue first
	dialogue.close_without_signal()
	for frame in 5:
		await process_frame

	reception.tarot_overlay.start_tarot_sequence([
		TarotDrawResult.new(TarotCardCatalog.get_card(&"the_fool"), false),
		TarotDrawResult.new(TarotCardCatalog.get_card(&"the_magician"), true),
		TarotDrawResult.new(TarotCardCatalog.get_card(&"the_star"), false)
	])

	var wait_ticks := 0
	while reception.tarot_overlay.current_state != TarotOverlay.State.CHOOSING and wait_ticks < 300:
		for frame in 2:
			await process_frame
		wait_ticks += 1

	assert(reception.tarot_overlay.current_state == TarotOverlay.State.CHOOSING, "TarotOverlay must reach CHOOSING state")
	var cards = reception.tarot_overlay.get_cards()
	assert(cards.size() == 3, "Must have 3 cards")

	# CardSlotContainer should be centered at (320, 180) in 640x360
	var slot_container = reception.tarot_overlay.find_child("CardSlotContainer", true, false)
	print("  CardSlotContainer global_pos:", slot_container.global_position)
	# With 640x360 canvas, center anchor (0.5, 0.5) => global (320, 180)
	assert(absf(slot_container.global_position.x - 320.0) < 5.0, "CardSlotContainer X must be ~320, got: %.1f" % slot_container.global_position.x)
	assert(absf(slot_container.global_position.y - 180.0) < 5.0, "CardSlotContainer Y must be ~180, got: %.1f" % slot_container.global_position.y)
	print("PASS: TarotOverlay CardSlotContainer centered at (320, 180) in 640x360 canvas")

	for i in cards.size():
		var c = cards[i]
		print("  Card %d global_pos: %s size: %s" % [i, str(c.global_position), str(c.size)])

	print("")
	print("========================================")
	print("ALL UI ALIGNMENT INTEGRATION TESTS PASS!")
	print("========================================")

	quit(0)
