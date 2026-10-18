class_name TestTarotDrawSystem
extends SceneTree

const TAROT_CATALOG := preload("res://scripts/data/tarot_card_catalog.gd")
const TAROT_CONTROLLER := preload("res://scripts/dream/tarot/tarot_draw_controller.gd")
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const TAROT_CARD_VIEW_SCENE := preload("res://scenes/ui/tarot/tarot_card_view.tscn")

var _tests_passed := 0
var _tests_failed := 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % message)


func _run_all_tests() -> void:
	print("==================================================")
	print("STARTING FULL TAROT DRAW SYSTEM INTEGRATION SUITE")
	print("==================================================")

	_test_draw_integrity()
	_test_reverse_presentation_and_probability()
	_test_rng_isolation()
	await _test_once_per_visit_and_interaction()
	await _test_skip_path()
	await _test_full_selection_and_elevator_flow()

	print("==================================================")
	print("TAROT SUITE COMPLETED: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print("ALL TAROT DRAW SYSTEM TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("SOME TAROT DRAW SYSTEM TESTS FAILED!")
		quit(1)


func _test_draw_integrity() -> void:
	print("\n--- Test 1: Draw Integrity (100 draws, 3 distinct Major Arcana each) ---")
	var catalog_cards := TAROT_CATALOG.get_all_cards()
	_assert(catalog_cards.size() == 22, "Catalog contains exactly 22 Major Arcana definitions")

	var valid_ids := {}
	for card in catalog_cards:
		valid_ids[card.id] = true

	var controller := TAROT_CONTROLLER.new()
	var all_draws_valid := true

	for i in range(100):
		var hand: Array = controller.draw_three()
		if hand.size() != 3:
			all_draws_valid = false
			break
		var id0 = hand[0].get_id()
		var id1 = hand[1].get_id()
		var id2 = hand[2].get_id()
		if not valid_ids.has(id0) or not valid_ids.has(id1) or not valid_ids.has(id2):
			all_draws_valid = false
			break
		if id0 == id1 or id0 == id2 or id1 == id2:
			all_draws_valid = false
			break

	_assert(all_draws_valid, "100 consecutive draws returned exactly 3 distinct cards from 22 Major Arcana")


func _test_reverse_presentation_and_probability() -> void:
	print("\n--- Test 2: Reverse Presentation & Probability ---")
	var controller := TAROT_CONTROLLER.new()
	var total_cards := 0
	var reversed_cards := 0

	for i in range(500):
		var hand: Array = controller.draw_three()
		for res in hand:
			total_cards += 1
			if res.is_reversed:
				reversed_cards += 1

	var reverse_ratio := float(reversed_cards) / float(total_cards)
	print("  Sampled %d cards, reversed = %d (ratio = %.3f)" % [total_cards, reversed_cards, reverse_ratio])
	_assert(reverse_ratio >= 0.40 and reverse_ratio <= 0.60, "Reverse probability is ~50% (got " + str(snapped(reverse_ratio * 100.0, 0.1)) + "%)")

	# Test result methods and formatting
	var fool_def := TAROT_CATALOG.get_card(&"the_fool")
	var upright_res := TarotDrawResult.new(fool_def, false)
	var reversed_res := TarotDrawResult.new(fool_def, true)

	_assert(upright_res.get_orientation_name_zh() == "正位", "Upright orientation name is '正位'")
	_assert(reversed_res.get_orientation_name_zh() == "逆位", "Reversed orientation name is '逆位'")
	_assert(upright_res.get_full_title_zh() == "愚者 · 正位", "Upright full title matches '愚者 · 正位'")
	_assert(reversed_res.get_full_title_zh() == "愚者 · 逆位", "Reversed full title matches '愚者 · 逆位'")

	var dict_rep: Dictionary = reversed_res.to_dictionary()
	_assert(dict_rep["card_id"] == &"the_fool" and dict_rep["is_reversed"] == true and dict_rep["arcana_index"] == 0,
		"TarotDrawResult.to_dictionary() produces correct data contract")

	# Test CardView orientation presentation
	var card_view := TAROT_CARD_VIEW_SCENE.instantiate() as TarotCardView
	root.add_child(card_view)
	card_view.draw_result = reversed_res
	card_view.flip(false)

	var card_art: TextureRect = card_view.get_node("CardFlipper/CardFront/CardArt")
	var label_container: Control = card_view.get_node("LabelContainer")

	_assert(card_art.rotation_degrees == 180.0, "Reversed card art is rotated 180 degrees")
	_assert(label_container.rotation_degrees == 0.0, "Label container stays 0 degrees upright")

	card_view.queue_free()


func _test_rng_isolation() -> void:
	print("\n--- Test 3: RNG Isolation (Global PRNG not polluted) ---")
	# Seed global RNG
	seed(1337)
	var expected_global_seq: Array[float] = []
	for i in range(5):
		expected_global_seq.append(randf())

	# Reset seed, run 100 tarot controller draws, then read global RNG
	seed(1337)
	var controller := TAROT_CONTROLLER.new(9999)
	for i in range(100):
		controller.draw_three()

	var actual_global_seq: Array[float] = []
	for i in range(5):
		actual_global_seq.append(randf())

	var rng_isolated := true
	for i in range(5):
		if not is_equal_approx(expected_global_seq[i], actual_global_seq[i]):
			rng_isolated = false
			break

	_assert(rng_isolated, "TarotDrawController isolated internal RNG without polluting global randf() sequence")


func _test_once_per_visit_and_interaction() -> void:
	print("\n--- Test 4: Once-Per-Visit Locked Hand & NPC Dialogue ---")
	var reception: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	root.add_child(reception)
	await create_timer(0.05).timeout

	_assert(reception.tarot_visit_state.hand_generated == false, "Initial visit state has hand_generated == false")
	_assert(reception.tarot_visit_state.selected == false, "Initial visit state has selected == false")

	# Trigger first draw via _start_tarot_sequence
	reception._start_tarot_sequence()
	_assert(reception.tarot_visit_state.hand_generated == true, "hand_generated is true after sequence start")
	_assert(reception.tarot_visit_state.hand.size() == 3, "Hand contains 3 cards")
	var first_hand_ids: Array = [
		reception.tarot_visit_state.hand[0].get_id(),
		reception.tarot_visit_state.hand[1].get_id(),
		reception.tarot_visit_state.hand[2].get_id()
	]
	var first_hand_rev: Array = [
		reception.tarot_visit_state.hand[0].is_reversed,
		reception.tarot_visit_state.hand[1].is_reversed,
		reception.tarot_visit_state.hand[2].is_reversed
	]

	# Close overlay if present
	if reception.active_tarot_overlay != null:
		reception.active_tarot_overlay.dismiss(0.0)
		reception.active_tarot_overlay = null
		await create_timer(0.05).timeout

	# Trigger second start (simulate closing UI and talking to waitress again)
	reception._start_tarot_sequence()
	var second_hand_ids: Array = [
		reception.tarot_visit_state.hand[0].get_id(),
		reception.tarot_visit_state.hand[1].get_id(),
		reception.tarot_visit_state.hand[2].get_id()
	]
	var second_hand_rev: Array = [
		reception.tarot_visit_state.hand[0].is_reversed,
		reception.tarot_visit_state.hand[1].is_reversed,
		reception.tarot_visit_state.hand[2].is_reversed
	]

	_assert(first_hand_ids == second_hand_ids and first_hand_rev == second_hand_rev,
		"Hand is strictly locked within the same visit (no re-roll exploit)")

	# Clean up overlay
	if reception.active_tarot_overlay != null:
		reception.active_tarot_overlay.dismiss(0.0)
		reception.active_tarot_overlay = null

	reception.queue_free()
	await create_timer(0.05).timeout


func _test_skip_path() -> void:
	print("\n--- Test 5: Skip Path (Direct Elevator Entry) ---")
	var reception: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	var test_profile := {}
	var test_night := {
		"has_tarot_card": false,
		"selected_tarot_card_id": &"",
		"selected_tarot_reversed": false
	}
	reception.configure_reception("basic", test_profile, test_night)
	root.add_child(reception)
	await create_timer(0.05).timeout

	# Directly trigger elevator entry without drawing
	reception._start_elevator_entry()
	await reception.elevator_entered

	_assert(test_night["has_tarot_card"] == false, "Skip path: night_state.has_tarot_card remains false")
	_assert(reception.tarot_visit_state.selected == false, "Skip path: tarot_visit_state.selected is false")

	reception.queue_free()
	await create_timer(0.05).timeout


func _test_full_selection_and_elevator_flow() -> void:
	print("\n--- Test 6: Full Selection & Unified Elevator Transition Flow ---")
	var reception: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	var test_profile := {}
	var test_night := {
		"has_tarot_card": false,
		"selected_tarot_card_id": &"",
		"selected_tarot_reversed": false
	}
	reception.configure_reception("basic", test_profile, test_night)
	root.add_child(reception)
	await create_timer(0.05).timeout

	# Start sequence
	reception._start_tarot_sequence()
	var overlay: TarotOverlay = reception.active_tarot_overlay
	_assert(overlay != null, "TarotOverlay created and active")

	# Wait for dealing & revealing sequence to finish
	var wait_ticks := 0
	while overlay.current_state != TarotOverlay.State.CHOOSING and wait_ticks < 100:
		await create_timer(0.05).timeout
		wait_ticks += 1

	_assert(overlay.current_state == TarotOverlay.State.CHOOSING, "TarotOverlay reached CHOOSING state")
	var cards: Array[TarotCardView] = overlay.get_cards()
	_assert(cards.size() == 3, "Overlay has 3 instantiated card views")

	# Pick the middle card (index 1)
	var chosen_card := cards[1]
	var chosen_res := chosen_card.draw_result
	print("  Simulating player selecting card: %s (%s)" % [chosen_res.get_full_title_zh(), chosen_res.get_id()])

	# Listen for elevator_entered signal from reception
	var tracker := {"received": false}
	reception.elevator_entered.connect(func(): tracker["received"] = true)

	# Simulate player clicking the card
	chosen_card.card_selected.emit(chosen_card)

	# Wait for card select hold (0.8s) + selection finished
	wait_ticks = 0
	while not reception.tarot_visit_state.selected and wait_ticks < 50:
		await create_timer(0.05).timeout
		wait_ticks += 1

	# Additional settle time for dismissal and player control re-enabling
	await create_timer(0.4).timeout

	_assert(reception.tarot_visit_state.selected == true, "tarot_visit_state.selected is true after choice")
	_assert(reception.player.movement_enabled == true, "player.movement_enabled is true after tarot selection")
	_assert(not tracker["received"], "elevator_entered has NOT fired yet (player remains free to move)")
	_assert(test_night["has_tarot_card"] == true, "test_night has_tarot_card is true")
	_assert(test_night["selected_tarot_card_id"] == chosen_res.get_id(), "test_night selected_tarot_card_id recorded correctly")
	_assert(test_night["selected_tarot_reversed"] == chosen_res.is_reversed, "test_night selected_tarot_reversed recorded correctly")

	# Simulate player manually walking to elevator and entering
	print("  Simulating player manually walking to elevator and entering...")
	var elevator_approach_pos: Vector2 = reception.elevator_floor_door.get_corridor_approach_position_2d() if reception.elevator_floor_door != null else reception.ELEVATOR_POS_2D
	reception.player.global_position = elevator_approach_pos
	reception._on_elevator_approach_entered(reception.player)
	_assert(reception.elevator_approach_active == true, "Elevator approach active when player arrives")

	reception._start_elevator_entry()

	wait_ticks = 0
	while not tracker["received"] and wait_ticks < 120:
		await create_timer(0.05).timeout
		wait_ticks += 1

	_assert(tracker["received"], "elevator_entered signal emitted following manual elevator entry")
	_assert(test_night["has_tarot_card"] == true, "test_night has_tarot_card remains true")
	_assert(test_night["selected_tarot_card_id"] == chosen_res.get_id(), "test_night selected_tarot_card_id matches chosen card")

	reception.queue_free()
	await create_timer(0.05).timeout
