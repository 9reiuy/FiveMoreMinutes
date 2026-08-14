class_name BlackjackApp
extends Control

signal balance_changed

const CONFIG := preload("res://resources/demo_config.tres")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const SFX := preload("res://scripts/audio/sfx_manager.gd")

const HIT_RECT := Rect2(270, 210, 72, 24)
const STAND_RECT := Rect2(350, 210, 72, 24)

var persistent_state: Dictionary = {}
var player_cards: Array[String] = []
var dealer_cards: Array[String] = []
var current_stake := 0
var round_active := false
var round_settled := true
var dealer_hidden := false
var result_text := "选择下注金额开始"
var hovered_action := ""
var random := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	random.randomize()
	queue_redraw()


func configure(state: Dictionary) -> void:
	persistent_state = state
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next := _action_at(event.position)
		if next != hovered_action:
			hovered_action = next
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not next.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var action := _action_at(event.position)
	if action.begins_with("bet_"):
		_start_round(int(action.trim_prefix("bet_")))
	elif action == "hit":
		_hit()
	elif action == "stand":
		_stand()
	accept_event()


func _action_at(point: Vector2) -> String:
	if round_active:
		if HIT_RECT.has_point(point): return "hit"
		if STAND_RECT.has_point(point): return "stand"
		return ""
	for index in CONFIG.blackjack_chip_values.size():
		var value := int(CONFIG.blackjack_chip_values[index])
		if _chip_rect(index).has_point(point) and value <= _balance(): return "bet_%d" % value
	return ""


func _start_round(stake: int) -> void:
	if round_active or stake <= 0 or stake > _balance():
		SFX.play_event(&"forbidden")
		return
	# 扣注与进入Active在同一调用完成，重复点击无法再次扣款。
	persistent_state.balance = maxi(0, _balance() - stake)
	current_stake = stake
	round_active = true
	round_settled = false
	dealer_hidden = true
	player_cards = [_draw_card(), _draw_card()]
	dealer_cards = [_draw_card(), _draw_card()]
	result_text = "要牌，或停牌"
	balance_changed.emit()
	SFX.play_event(&"confirm")
	if _is_natural(player_cards):
		dealer_hidden = false
		if _is_natural(dealer_cards): _settle("平局", current_stake)
		else: _settle("21点", current_stake + roundi(current_stake * CONFIG.blackjack_natural_payout_ratio))
	queue_redraw()


func _hit() -> void:
	if not round_active: return
	player_cards.append(_draw_card())
	SFX.play_event(&"phone_operation")
	if _hand_value(player_cards) > 21:
		dealer_hidden = false
		_settle("爆牌", 0)
	queue_redraw()


func _stand() -> void:
	if not round_active: return
	dealer_hidden = false
	while _hand_value(dealer_cards) < CONFIG.blackjack_dealer_stand_value:
		dealer_cards.append(_draw_card())
	var player_value := _hand_value(player_cards)
	var dealer_value := _hand_value(dealer_cards)
	if dealer_value > 21: _settle("庄家爆牌", current_stake * 2)
	elif player_value > dealer_value: _settle("你赢了", current_stake * 2)
	elif player_value < dealer_value: _settle("你输了", 0)
	else: _settle("平局", current_stake)
	queue_redraw()


func _settle(text: String, return_amount: int) -> void:
	if round_settled: return
	round_settled = true
	round_active = false
	persistent_state.balance = maxi(0, _balance() + maxi(return_amount, 0))
	result_text = text
	balance_changed.emit()
	SFX.play_event(&"confirm")


func _draw_card() -> String:
	return ["A","2","3","4","5","6","7","8","9","10","J","Q","K"][random.randi_range(0, 12)]


func _hand_value(cards: Array[String]) -> int:
	var total := 0
	var aces := 0
	for card in cards:
		if card == "A": total += 11; aces += 1
		elif card in ["J","Q","K"]: total += 10
		else: total += int(card)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _is_natural(cards: Array[String]) -> bool:
	return cards.size() == 2 and _hand_value(cards) == 21


func _balance() -> int:
	return int(persistent_state.get("balance", 0))


func _chip_rect(index: int) -> Rect2:
	return Rect2(25 + index * 100, 210, 82, 24)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1320"))
	var font := PixelFont.get_font()
	draw_string(font, Vector2(0, 18), "21点 // BLACKJACK", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("c8dce5"))
	draw_string(font, Vector2(0, 36), "余额  " + FORMAT.format_currency(_balance()), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("86afc2"))
	_draw_hand("庄家", dealer_cards, Vector2(24, 59), dealer_hidden, font)
	_draw_hand("玩家", player_cards, Vector2(24, 125), false, font)
	draw_string(font, Vector2(0, 194), result_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("c7b9c8"))
	if round_active:
		_draw_button(HIT_RECT, "要牌", hovered_action == "hit", true, font)
		_draw_button(STAND_RECT, "停牌", hovered_action == "stand", true, font)
	else:
		for index in CONFIG.blackjack_chip_values.size():
			var value := int(CONFIG.blackjack_chip_values[index])
			_draw_button(_chip_rect(index), FORMAT.format_currency(value), hovered_action == "bet_%d" % value, value <= _balance(), font)


func _draw_hand(label: String, cards: Array[String], origin: Vector2, hide_second: bool, font: Font) -> void:
	draw_string(font, origin, "%s  %s" % [label, "?" if hide_second else str(_hand_value(cards))], HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color("8eaab8"))
	for index in cards.size():
		var rect := Rect2(origin + Vector2(92 + index * 42, -13), Vector2(34, 48))
		draw_rect(rect, Color("d7d5cf") if not (hide_second and index == 1) else Color("2f4d68"))
		draw_rect(rect, Color("6d8190"), false, 1.0)
		var text := "?" if hide_second and index == 1 else cards[index]
		draw_string(font, rect.position + Vector2(0, 28), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color("172334"))


func _draw_button(rect: Rect2, text: String, hovered: bool, enabled: bool, font: Font) -> void:
	var fill := Color("294b62") if hovered and enabled else (Color("182c3d") if enabled else Color("151b24"))
	draw_rect(rect, fill)
	draw_rect(rect, Color("628ba1") if enabled else Color("343d46"), false, 1.0)
	draw_string(font, rect.position + Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color("d0e1e7") if enabled else Color("56616a"))
