extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[TEST] Starting Tarot system tests...")
	var success := true

	success = test_tarot_card_definition() and success
	success = test_tarot_card_catalog() and success
	success = test_tarot_draw_result() and success
	success = test_tarot_draw_controller() and success
	success = test_main_session_state() and success

	if success:
		print("[TEST] ALL TAROT TESTS PASSED!")
		quit(0)
	else:
		push_error("[TEST] SOME TAROT TESTS FAILED!")
		quit(1)


func test_tarot_card_definition() -> bool:
	print("--- Testing TarotCardDefinition ---")
	var def := TarotCardDefinition.new()
	assert(def.id == &"", "Default id should be empty")
	assert(def.arcana_index == 0, "Default arcana_index should be 0")
	assert(def.display_name_zh == "", "Default display_name_zh should be empty")
	assert(def.display_name_en == "", "Default display_name_en should be empty")
	assert(def.front_texture == null, "Default front_texture should be null")
	assert(def.back_texture == null, "Default back_texture should be null")
	assert(def.effect_id == &"", "Default effect_id should be empty")
	assert(def.upright_description == "", "Default upright_description should be empty")
	assert(def.reversed_description == "", "Default reversed_description should be empty")

	var custom := TarotCardDefinition.new(
		&"the_fool",
		0,
		"愚者",
		"The Fool",
		null,
		null,
		&"effect_fool",
		"Upright desc",
		"Reversed desc"
	)
	assert(custom.id == &"the_fool", "Custom id should match")
	assert(custom.display_name_zh == "愚者", "Custom zh name should match")
	assert(custom.display_name_en == "The Fool", "Custom en name should match")
	assert(custom.effect_id == &"effect_fool", "Custom effect_id should match")
	assert(custom.upright_description == "Upright desc", "Custom upright_desc should match")
	assert(custom.reversed_description == "Reversed desc", "Custom reversed_desc should match")

	print("[PASS] TarotCardDefinition test passed.")
	return true


func test_tarot_card_catalog() -> bool:
	print("--- Testing TarotCardCatalog ---")
	var all_cards := TarotCardCatalog.get_all_cards()
	assert(all_cards.size() == 22, "Catalog must contain exactly 22 Major Arcana cards, got %d" % all_cards.size())

	var expected_cards := [
		{"index": 0, "id": &"the_fool", "zh": "愚者", "en": "The Fool"},
		{"index": 1, "id": &"the_magician", "zh": "魔术师", "en": "The Magician"},
		{"index": 2, "id": &"the_high_priestess", "zh": "女祭司", "en": "The High Priestess"},
		{"index": 3, "id": &"the_empress", "zh": "皇后", "en": "The Empress"},
		{"index": 4, "id": &"the_emperor", "zh": "皇帝", "en": "The Emperor"},
		{"index": 5, "id": &"the_hierophant", "zh": "教皇", "en": "The Hierophant"},
		{"index": 6, "id": &"the_lovers", "zh": "恋人", "en": "The Lovers"},
		{"index": 7, "id": &"the_chariot", "zh": "战车", "en": "The Chariot"},
		{"index": 8, "id": &"strength", "zh": "力量", "en": "Strength"},
		{"index": 9, "id": &"the_hermit", "zh": "隐士", "en": "The Hermit"},
		{"index": 10, "id": &"wheel_of_fortune", "zh": "命运之轮", "en": "Wheel of Fortune"},
		{"index": 11, "id": &"justice", "zh": "正义", "en": "Justice"},
		{"index": 12, "id": &"the_hanged_man", "zh": "倒吊人", "en": "The Hanged Man"},
		{"index": 13, "id": &"death", "zh": "死神", "en": "Death"},
		{"index": 14, "id": &"temperance", "zh": "节制", "en": "Temperance"},
		{"index": 15, "id": &"the_devil", "zh": "恶魔", "en": "The Devil"},
		{"index": 16, "id": &"the_tower", "zh": "高塔", "en": "The Tower"},
		{"index": 17, "id": &"the_star", "zh": "星星", "en": "The Star"},
		{"index": 18, "id": &"the_moon", "zh": "月亮", "en": "The Moon"},
		{"index": 19, "id": &"the_sun", "zh": "太阳", "en": "The Sun"},
		{"index": 20, "id": &"judgement", "zh": "审判", "en": "Judgement"},
		{"index": 21, "id": &"the_world", "zh": "世界", "en": "The World"}
	]

	var back_tex := TarotCardCatalog.get_card_back_texture()
	assert(back_tex != null, "Default back texture must load successfully")

	for expected in expected_cards:
		var by_index := TarotCardCatalog.get_card_by_index(expected["index"])
		assert(by_index != null, "Card at index %d should exist" % expected["index"])
		assert(by_index.id == expected["id"], "Card at index %d ID mismatch: %s vs %s" % [expected["index"], by_index.id, expected["id"]])
		assert(by_index.display_name_zh == expected["zh"], "Card %s display_name_zh mismatch" % expected["id"])
		assert(by_index.display_name_en == expected["en"], "Card %s display_name_en mismatch" % expected["id"])
		assert(by_index.front_texture != null, "Card %s front texture should not be null" % expected["id"])
		assert(by_index.back_texture != null, "Card %s back texture should not be null" % expected["id"])

		var by_id := TarotCardCatalog.get_card(expected["id"])
		assert(by_id == by_index, "Card retrieved by ID should match card retrieved by index")

	print("[PASS] TarotCardCatalog test passed: All 22 cards and textures verified.")
	return true


func test_tarot_draw_result() -> bool:
	print("--- Testing TarotDrawResult ---")
	var fool := TarotCardCatalog.get_card(&"the_fool")
	assert(fool != null, "The fool must exist")

	var upright_draw := TarotDrawResult.new(fool, false)
	assert(upright_draw.get_id() == &"the_fool", "Draw result id should match")
	assert(upright_draw.get_display_name_zh() == "愚者", "Draw result display_name_zh should match")
	assert(upright_draw.get_orientation_name_zh() == "正位", "Upright orientation should be 正位")
	assert(upright_draw.get_full_title_zh() == "愚者 · 正位", "Upright full title should be 愚者 · 正位")
	var upright_dict := upright_draw.to_dictionary()
	assert(upright_dict["card_id"] == &"the_fool", "Dict card_id mismatch")
	assert(upright_dict["is_reversed"] == false, "Dict is_reversed mismatch")
	assert(upright_dict["arcana_index"] == 0, "Dict arcana_index mismatch")

	var reversed_draw := TarotDrawResult.new(fool, true)
	assert(reversed_draw.get_orientation_name_zh() == "逆位", "Reversed orientation should be 逆位")
	assert(reversed_draw.get_full_title_zh() == "愚者 · 逆位", "Reversed full title should be 愚者 · 逆位")
	var reversed_dict := reversed_draw.to_dictionary()
	assert(reversed_dict["is_reversed"] == true, "Dict is_reversed should be true")

	# Test empty/null safety
	var empty_draw := TarotDrawResult.new(null, false)
	assert(empty_draw.get_id() == &"", "Empty draw id should be empty")
	assert(empty_draw.get_display_name_zh() == "", "Empty draw name should be empty")
	assert(empty_draw.to_dictionary()["arcana_index"] == -1, "Empty draw arcana_index should be -1")

	print("[PASS] TarotDrawResult test passed.")
	return true


func test_tarot_draw_controller() -> bool:
	print("--- Testing TarotDrawController ---")
	var controller1 := TarotDrawController.create_seeded_controller(12345)
	var controller2 := TarotDrawController.create_seeded_controller(12345)

	var draw1 := controller1.draw_three()
	var draw2 := controller2.draw_three()

	assert(draw1.size() == 3, "draw_three must return exactly 3 cards")
	assert(draw2.size() == 3, "draw_three must return exactly 3 cards")

	# Check seed determinism
	for i in range(3):
		assert(draw1[i].get_id() == draw2[i].get_id(), "Seeded controllers must produce identical cards at index %d" % i)
		assert(draw1[i].is_reversed == draw2[i].is_reversed, "Seeded controllers must produce identical orientation at index %d" % i)

	# Check distinct cards (no replacement)
	var ids: Dictionary = {}
	for res in draw1:
		assert(not ids.has(res.get_id()), "Drawn cards must be distinct, got duplicate: %s" % res.get_id())
		ids[res.get_id()] = true

	# Test multiple random draws to ensure distinctness and valid results
	var unseeded := TarotDrawController.new()
	for trial in range(50):
		var cards := unseeded.draw_three()
		assert(cards.size() == 3, "Draw size must be 3")
		var trial_ids: Dictionary = {}
		for card in cards:
			assert(not trial_ids.has(card.get_id()), "Cards must be distinct in trial %d" % trial)
			trial_ids[card.get_id()] = true

	print("[PASS] TarotDrawController test passed: Determinism and distinctness verified.")
	return true


func test_main_session_state() -> bool:
	print("--- Testing main.gd session state ---")
	var main_script = load("res://scripts/app/main.gd")
	assert(main_script != null, "main.gd must load")
	var main_instance = Node.new()
	main_instance.set_script(main_script)

	var fresh_state: Dictionary = main_instance.call("_fresh_night_state")
	assert(fresh_state.has("has_tarot_card"), "_fresh_night_state must contain has_tarot_card")
	assert(fresh_state["has_tarot_card"] == false, "has_tarot_card default must be false")
	assert(fresh_state.has("selected_tarot_card_id"), "_fresh_night_state must contain selected_tarot_card_id")
	assert(fresh_state["selected_tarot_card_id"] == &"", "selected_tarot_card_id default must be &\"\"")
	assert(fresh_state.has("selected_tarot_reversed"), "_fresh_night_state must contain selected_tarot_reversed")
	assert(fresh_state["selected_tarot_reversed"] == false, "selected_tarot_reversed default must be false")

	var initial_night_state: Dictionary = main_instance.get("night_state")
	assert(initial_night_state.has("has_tarot_card"), "night_state must contain has_tarot_card")
	assert(initial_night_state.has("selected_tarot_card_id"), "night_state must contain selected_tarot_card_id")
	assert(initial_night_state.has("selected_tarot_reversed"), "night_state must contain selected_tarot_reversed")

	main_instance.free()
	print("[PASS] main.gd session state test passed.")
	return true
