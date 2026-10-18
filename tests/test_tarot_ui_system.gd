extends SceneTree

const CARD_VIEW_SCENE := preload("res://scenes/ui/tarot/tarot_card_view.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/tarot/tarot_overlay.tscn")


func _init() -> void:
	print("==================================================")
	print("TEST: Starting Tarot UI Presentation System Tests")
	print("==================================================")
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	var success := true
	success = success and _test_tarot_card_view_structure()
	success = success and _test_tarot_card_view_logic_upright()
	success = success and _test_tarot_card_view_logic_reversed()
	success = success and await _test_tarot_card_view_interactions()
	success = success and _test_tarot_overlay_structure()
	success = success and await _test_tarot_overlay_sequence()

	if success:
		print("==================================================")
		print("TEST RESULT: ALL TAROT UI TESTS PASSED!")
		print("==================================================")
		quit(0)
	else:
		printerr("==================================================")
		printerr("TEST RESULT: SOME TESTS FAILED!")
		printerr("==================================================")
		quit(1)


func _test_tarot_card_view_structure() -> bool:
	print("[TEST] 1. TarotCardView node structure and properties...")
	var card_view := CARD_VIEW_SCENE.instantiate() as TarotCardView
	if card_view == null:
		printerr("Failed to instantiate TarotCardView")
		return false

	root.add_child(card_view)

	assert(card_view.custom_minimum_size == TarotCardView.CARD_SIZE, "custom_minimum_size must match CARD_SIZE")
	assert(card_view.size == TarotCardView.CARD_SIZE, "size must match CARD_SIZE")
	assert(card_view.pivot_offset == TarotCardView.CARD_SIZE * 0.5, "pivot_offset must be centered")

	var shadow: Control = card_view.get_node_or_null("CardShadow")
	var flipper: Control = card_view.get_node_or_null("CardFlipper")
	var back: TextureRect = card_view.get_node_or_null("CardFlipper/CardBack")
	var front: Control = card_view.get_node_or_null("CardFlipper/CardFront")
	var art: TextureRect = card_view.get_node_or_null("CardFlipper/CardFront/CardArt")
	var labels: Control = card_view.get_node_or_null("LabelContainer")
	var name_lbl: Label = card_view.card_name_label
	var orient_lbl: Label = card_view.orientation_label
	var glow: Control = card_view.get_node_or_null("SelectionGlow")

	assert(shadow != null, "CardShadow missing")
	assert(flipper != null, "CardFlipper missing")
	assert(back != null, "CardBack missing")
	assert(front != null, "CardFront missing")
	assert(art != null, "CardArt missing")
	assert(labels != null, "LabelContainer missing")
	assert(name_lbl != null, "CardNameLabel missing")
	assert(orient_lbl != null, "OrientationLabel missing")
	assert(glow != null, "SelectionGlow missing")

	# Texture filter checks
	assert(back.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "CardBack texture filter must be NEAREST")
	assert(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "CardArt texture filter must be NEAREST")

	card_view.queue_free()
	print("  -> Passed!")
	return true


func _test_tarot_card_view_logic_upright() -> bool:
	print("[TEST] 2. TarotCardView upright logic and flip...")
	var card_view := CARD_VIEW_SCENE.instantiate() as TarotCardView
	root.add_child(card_view)

	var def := TarotCardCatalog.get_card(&"the_fool")
	assert(def != null, "The Fool card definition missing from catalog")

	var result := TarotDrawResult.new(def, false) # Upright
	card_view.draw_result = result

	# Facedown initially
	assert(not card_view.is_revealed, "Card should start facedown")
	assert(card_view.card_back.visible == true, "CardBack should be visible")
	assert(card_view.card_front.visible == false, "CardFront should be hidden")
	assert(card_view.label_container.visible == false, "LabelContainer should be hidden")

	# Flip without animation
	card_view.flip(false)
	assert(card_view.is_revealed, "Card should be revealed after flip")
	assert(card_view.card_back.visible == false, "CardBack should be hidden")
	assert(card_view.card_front.visible == true, "CardFront should be visible")
	assert(card_view.label_container.visible == true, "LabelContainer should be visible")
	assert(card_view.card_name_label.text == "愚者", "CardNameLabel should display '愚者'")
	assert(card_view.orientation_label.text == "正位", "OrientationLabel should display '正位'")
	assert(card_view.card_art.rotation_degrees == 0.0, "Upright art rotation should be 0.0")
	assert(card_view.label_container.rotation_degrees == 0.0, "LabelContainer should remain upright (0.0)")

	card_view.queue_free()
	print("  -> Passed!")
	return true


func _test_tarot_card_view_logic_reversed() -> bool:
	print("[TEST] 3. TarotCardView reversed logic and art inversion...")
	var card_view := CARD_VIEW_SCENE.instantiate() as TarotCardView
	root.add_child(card_view)

	var def := TarotCardCatalog.get_card(&"the_magician")
	assert(def != null, "The Magician card definition missing from catalog")

	var result := TarotDrawResult.new(def, true) # Reversed
	card_view.draw_result = result
	card_view.flip(false)

	assert(card_view.is_revealed, "Card should be revealed")
	assert(card_view.card_name_label.text == "魔术师", "CardNameLabel should display '魔术师'")
	assert(card_view.orientation_label.text == "逆位", "OrientationLabel should display '逆位'")
	assert(card_view.card_art.rotation_degrees == 180.0, "Reversed art rotation must be 180.0")
	assert(card_view.label_container.rotation_degrees == 0.0, "LabelContainer MUST stay 0.0 upright even when reversed!")

	card_view.queue_free()
	print("  -> Passed!")
	return true


func _test_tarot_card_view_interactions() -> bool:
	print("[TEST] 3.5 TarotCardView interactive hover, tilt, and click selection...")
	var card_view := CARD_VIEW_SCENE.instantiate() as TarotCardView
	root.add_child(card_view)

	var def := TarotCardCatalog.get_card(&"the_fool")
	var result := TarotDrawResult.new(def, false)
	card_view.draw_result = result
	card_view.flip(false)
	card_view.interactive = true

	# Test mouse entered
	var hovered_events: Array[bool] = []
	card_view.card_hovered.connect(func(v: TarotCardView, h: bool):
		hovered_events.append(h)
	)

	card_view._on_mouse_entered()
	assert(card_view.is_hovered == true, "Card should be hovered after mouse entered")
	assert(hovered_events.size() == 1 and hovered_events[0] == true, "Hover event true should be emitted")

	# Test mouse motion tilt
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(card_view.size.x * 0.8, card_view.size.y * 0.5)
	card_view._gui_input(motion_event)
	assert(abs(card_view.rotation_degrees) > 0.0, "Card should tilt with mouse motion")

	# Test mouse exited
	card_view._on_mouse_exited()
	assert(card_view.is_hovered == false, "Card should not be hovered after mouse exited")
	assert(hovered_events.size() == 2 and hovered_events[1] == false, "Hover event false should be emitted")

	# Test selection click
	var selected_cards: Array[TarotCardView] = []
	card_view.card_selected.connect(func(v: TarotCardView):
		selected_cards.append(v)
	)

	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	card_view._gui_input(click_event)

	assert(selected_cards.size() == 1 and selected_cards[0] == card_view, "card_selected should be emitted on click")

	# Test selection glow
	card_view.is_selected = true
	assert(card_view.selection_glow.visible == true, "SelectionGlow should be visible when selected")

	card_view.queue_free()
	print("  -> Passed!")
	return true



func _test_tarot_overlay_structure() -> bool:
	print("[TEST] 4. TarotOverlay structure and slots...")
	var overlay := OVERLAY_SCENE.instantiate() as TarotOverlay
	if overlay == null:
		printerr("Failed to instantiate TarotOverlay")
		return false

	assert(overlay is Control, "TarotOverlay must be a Control")
	assert(overlay.anchors_preset == Control.PRESET_FULL_RECT, "TarotOverlay anchors_preset must be PRESET_FULL_RECT")
	assert(overlay.custom_minimum_size == Vector2(640, 360), "TarotOverlay custom_minimum_size must be Vector2(640, 360)")
	assert(overlay.size == Vector2(640, 360), "TarotOverlay default size must be Vector2(640, 360)")
	assert(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "TarotOverlay mouse_filter must be MOUSE_FILTER_STOP")

	var dummy_layer := CanvasLayer.new()
	dummy_layer.layer = 45
	root.add_child(dummy_layer)
	dummy_layer.add_child(overlay)

	assert(overlay.dim_background != null, "DimBackground missing")
	assert(overlay.header_container != null, "HeaderContainer missing")
	assert(overlay.title_label != null, "TitleLabel missing")
	assert(overlay.subtitle_label != null, "SubtitleLabel missing")
	assert(overlay.card_slot_container != null, "CardSlotContainer missing")
	assert(overlay.prompt_label != null, "PromptLabel missing")

	# Check slot positions: Left (-190), Center (0), Right (+190)
	assert(overlay.get_slot_position(0) == Vector2(-190, 0), "Left slot must be at (-190, 0)")
	assert(overlay.get_slot_position(1) == Vector2(0, 0), "Center slot must be at (0, 0)")
	assert(overlay.get_slot_position(2) == Vector2(190, 0), "Right slot must be at (190, 0)")

	dummy_layer.queue_free()
	print("  -> Passed!")
	return true


func _test_tarot_overlay_sequence() -> bool:
	print("[TEST] 5. TarotOverlay sequence execution and selection flow...")
	var dummy_layer := CanvasLayer.new()
	dummy_layer.layer = 45
	root.add_child(dummy_layer)

	var overlay := OVERLAY_SCENE.instantiate() as TarotOverlay
	dummy_layer.add_child(overlay)

	var draw_controller := TarotDrawController.new(42)
	var hand := draw_controller.draw_three()
	assert(hand.size() == 3, "Hand must contain 3 cards")

	overlay.call_deferred(&"start_tarot_sequence", hand)

	# Wait until overlay reaches CHOOSING state
	var wait_ticks := 0
	while overlay.current_state != TarotOverlay.State.CHOOSING and wait_ticks < 100:
		await create_timer(0.05).timeout
		wait_ticks += 1

	assert(overlay.visible == true, "Overlay should be visible after start_tarot_sequence")
	assert(overlay.current_state == TarotOverlay.State.CHOOSING, "Overlay should reach CHOOSING state")
	assert(overlay.cards.size() == 3, "Overlay should have 3 cards")
	assert(overlay.prompt_label.visible == true, "PromptLabel should be visible in CHOOSING state")

	for c in overlay.cards:
		assert(c.is_revealed == true, "All cards should be revealed in CHOOSING state")
		assert(c.interactive == true, "All cards should be interactive in CHOOSING state")

	# Simulate selecting the middle card (index 1)
	var selected_card := overlay.cards[1]
	var selected_result_holder: Array[TarotDrawResult] = []
	overlay.selection_finished.connect(func(res: TarotDrawResult):
		selected_result_holder.append(res)
	)

	# Trigger card selected
	selected_card.card_selected.emit(selected_card)

	assert(overlay.current_state == TarotOverlay.State.COMMITTED, "State should transition to COMMITTED immediately on select")
	for c in overlay.cards:
		assert(c.interactive == false, "All cards should become non-interactive once committed")

	# Wait for selection finish
	var select_ticks := 0
	while selected_result_holder.is_empty() and select_ticks < 50:
		await create_timer(0.05).timeout
		select_ticks += 1

	assert(not selected_result_holder.is_empty(), "selection_finished signal should be emitted")
	assert(selected_result_holder[0] == selected_card.draw_result, "Emitted result should match selected card's result")

	# Verify dismiss behavior
	await overlay.dismiss(0.05)
	assert(overlay.visible == false, "Overlay should be hidden after dismiss")
	assert(overlay.modulate.a == 1.0, "Overlay modulate.a should be reset to 1.0 after dismiss")

	dummy_layer.queue_free()
	print("  -> Passed!")
	return true
