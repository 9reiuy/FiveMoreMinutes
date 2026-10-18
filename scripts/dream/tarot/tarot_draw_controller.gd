class_name TarotDrawController
extends RefCounted

const TAROT_REVERSED_PROBABILITY: float = 0.5
const HAND_SIZE: int = 3

var _rng: RandomNumberGenerator


func _init(seed_val: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_val != 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()


static func create_seeded_controller(seed_val: int) -> TarotDrawController:
	return TarotDrawController.new(seed_val)


func draw_three() -> Array[TarotDrawResult]:
	var all_cards := TarotCardCatalog.get_all_cards()
	var total_cards := all_cards.size()

	var indices: Array[int] = []
	for i in range(total_cards):
		indices.append(i)

	var draw_count := mini(HAND_SIZE, total_cards)
	var drawn_results: Array[TarotDrawResult] = []

	for i in range(draw_count):
		var swap_idx := _rng.randi_range(i, total_cards - 1)
		var picked_index := indices[swap_idx]
		indices[swap_idx] = indices[i]
		indices[i] = picked_index

		var card_def := TarotCardCatalog.get_card_by_index(picked_index)
		var is_reversed := _rng.randf() < TAROT_REVERSED_PROBABILITY
		var draw_result := TarotDrawResult.new(card_def, is_reversed)
		drawn_results.append(draw_result)

	return drawn_results
