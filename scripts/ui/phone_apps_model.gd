class_name PhoneAppsModel
extends RefCounted

## Presentation reads the live profile; bedroom remains the sole purchase authority.
signal profile_changed
signal story_effect_requested(effect: StringName)
const CONFIG := preload("res://resources/demo_config.tres")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const TEXT := preload("res://scripts/data/text_content.gd")
var profile: Dictionary = {}
var bedroom_phone: Control
var clock_provider: Callable

func configure(state: Dictionary, phone: Control = null, clock: Callable = Callable()) -> void:
	profile = state
	bedroom_phone = phone
	clock_provider = clock

func get_messages() -> Array:
	var result: Array = []
	for message in profile.get("online_messages", []):
		if message is Dictionary:
			result.append(message)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_day := int(a.get("received_day_id", 0))
		var b_day := int(b.get("received_day_id", 0))
		return a_day > b_day if a_day != b_day else int(a.get("message_sequence", 0)) > int(b.get("message_sequence", 0)))
	return result

func get_unread_count() -> int:
	var count := 0
	for message in get_messages():
		if not bool(message.get("is_read", false)):
			count += 1
	return count

func open_messages() -> void:
	if is_instance_valid(bedroom_phone):
		bedroom_phone.call("_mark_online_messages_read")
		profile_changed.emit()
		return
	var changed := false
	for message in get_messages():
		# This existing story message deliberately remains unread until removed.
		if str(message.get("id", "")) == "day5_northern_times" and not bool(message.get("is_read", false)):
			continue
		changed = changed or not bool(message.get("is_read", false))
		message.is_read = true
		if str(message.get("id", "")) == "quicklink_news_debt_1993":
			profile.quicklink_news_read = true
	if changed:
		profile_changed.emit()

func get_message_text(message: Dictionary) -> String:
	if str(message.get("id", "")) == "day5_northern_times" and bool(profile.get("day5_northern_times_deleted", false)):
		return str(TEXT.get_dialogue(&"phone_deleted_message").get("lines", [{}])[0].get("text", ""))
	return str(message.get("text", ""))

func get_message_category(message: Dictionary) -> String:
	if str(message.get("id", "")) == "day5_northern_times" and bool(profile.get("day5_northern_times_deleted", false)):
		return str(TEXT.get_dialogue(&"phone_deleted_author").get("lines", [{}])[0].get("text", ""))
	return str(message.get("category", "讯息"))

func hover_message(message: Dictionary) -> void:
	if str(message.get("id", "")) != "day5_northern_times" or bool(profile.get("day5_northern_times_deleted", false)):
		return
	if is_instance_valid(bedroom_phone):
		bedroom_phone.call("_on_message_card_hovered", message)
	else:
		message.is_read = true
		profile.day5_northern_times_deleted = true
		story_effect_requested.emit(&"phone_message_glitch")
	profile_changed.emit()

func get_products() -> Array[Dictionary]:
	return [
		{"id": &"melatonin", "title": "褪黑素", "price": CONFIG.melatonin_price, "description": "延长梦境时间", "status": "库存 %d/%d" % [int(profile.get("melatonin_inventory", 0)), CONFIG.melatonin_inventory_cap]},
		{"id": &"cheap_meal", "title": "廉价便当", "price": CONFIG.cheap_meal_price, "description": "简单的能量摄入", "status": "配送中" if profile.get("delivery_state", "NONE") == "DELIVERING" else "今日 %d/%d" % [int(profile.get("cheap_meal_purchases_today", 0)), CONFIG.cheap_meal_daily_purchase_limit]},
		{"id": &"sunshade", "title": "遮阳帘", "price": CONFIG.sunshade_price, "description": "屏蔽闹钟白曝光", "status": "已购买" if bool(profile.get("sunshade_purchased", false)) else "限购一次"}
	]

func can_purchase() -> bool:
	return is_instance_valid(bedroom_phone)

func purchase(index: int) -> bool:
	if not can_purchase() or index < 0 or index >= 3:
		return false
	bedroom_phone.call(["_purchase_melatonin", "_purchase_cheap_meal", "_purchase_sunshade"][index])
	profile_changed.emit()
	return true

func get_balance_text() -> String:
	return FORMAT.format_currency(int(profile.get("balance", 0)))

func get_status() -> Dictionary:
	var status := {"time": "--:--", "battery": 1.0 - clampf(float(profile.get("stress_value", CONFIG.stress_default)) / maxf(float(CONFIG.stress_max), 1.0), 0, 1)}
	if clock_provider.is_valid():
		var provided: Variant = clock_provider.call()
		if provided is Dictionary:
			status.merge(provided, true)
		elif provided is String:
			status.time = provided
	elif is_instance_valid(bedroom_phone):
		var minutes := int(bedroom_phone.bedroom_time_minutes)
		status.time = "%02d:%02d" % [posmod(floori(float(minutes) / 60.0), 24), posmod(minutes, 60)]
	return status

func get_music_info(tree: SceneTree) -> Dictionary:
	var manager := tree.root.get_node_or_null("SFXManager")
	if manager == null or not is_instance_valid(manager.music_player):
		return {"title": "暂无音乐", "available": false, "paused": true}
	var id: StringName = manager.current_music_id
	var player: AudioStreamPlayer = manager.music_player
	var titles := {&"bedroom": "卧室背景音乐", &"bedroom_short": "卧室背景音乐", &"battle": "办公楼层音乐", &"battle_short": "办公楼层音乐", &"safe": "Sweet Vermouth", &"sweet_vermouth": "Sweet Vermouth", &"sing_swing_bada_bing": "Sing Swing Bada Bing", &"battle_sing_swing": "Sing Swing Bada Bing", &"groovy_ignition": "Groovy Ignition", &"battle_groovy": "Groovy Ignition", &"elevator": "降E大调夜曲Op.9 No.2", &"nocturne": "降E大调夜曲Op.9 No.2"}
	return {"title": titles.get(id, String(id) if not id.is_empty() else "暂无音乐"), "available": not id.is_empty() and player.stream != null, "paused": player.stream_paused}

func toggle_music(tree: SceneTree) -> void:
	var manager := tree.root.get_node_or_null("SFXManager")
	if manager != null and is_instance_valid(manager.music_player) and not String(manager.current_music_id).is_empty() and manager.music_player.stream != null:
		manager.music_player.stream_paused = not manager.music_player.stream_paused
