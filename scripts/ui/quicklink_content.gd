class_name QuicklinkContent
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const PRODUCT_ICONS := {
	"melatonin": preload("res://assets/ui/products/melatonin_icon.png"),
	"cheap_meal": preload("res://assets/ui/products/cheap_meal_icon.png"),
	"sunshade": preload("res://art/sunshade.png"),
}

# Content 局部坐标：原点 = QuicklinkScroll 左上角（= phone 的 (12, 76)）。
# 顶部返回按钮与标题由 bedroom_phone 绘制，这里只画余额与商品卡。
# 内容宽度 121 = 滚动区 136 - 滚动条 5 - 右侧安全边距 10，按钮贴右边缘但绝不与滚动条重叠。
const BUY_MELATONIN_BUTTON := Rect2(75, 79, 46, 24)
const BUY_CHEAP_MEAL_BUTTON := Rect2(75, 161, 46, 24)
const BUY_SUNSHADE_BUTTON := Rect2(75, 247, 46, 24)

var phone: Control  # bedroom_phone，提供数据与购买服务
var hovered_action := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var action := _action_at(event.position)
		if not action.is_empty() and action != hovered_action:
			SFX.play_event(&"ui_hover")
		if action != hovered_action:
			hovered_action = action
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# 与在线！™一致：松开时先检查拖动防误触，避免拖动列表时误购。
		if phone == null or not is_instance_valid(phone) or phone.quicklink_scroll.should_suppress_click():
			return
		match _action_at(event.position):
			"buy_melatonin":
				phone._purchase_melatonin()
				accept_event()
			"buy_cheap_meal":
				phone._purchase_cheap_meal()
				accept_event()
			"buy_sunshade":
				phone._purchase_sunshade()
				accept_event()


func _action_at(point: Vector2) -> String:
	if BUY_MELATONIN_BUTTON.has_point(point):
		return "buy_melatonin"
	if BUY_CHEAP_MEAL_BUTTON.has_point(point):
		return "buy_cheap_meal"
	if BUY_SUNSHADE_BUTTON.has_point(point):
		return "buy_sunshade"
	return ""


func _draw() -> void:
	if phone == null or not is_instance_valid(phone):
		return
	var font := PixelFont.get_font()
	var persistent_state: Dictionary = phone.persistent_state
	var config = phone.config
	var balance_color := Color("e3ebd5") if fmod(phone.balance_flash_left * 18.0, 2.0) > 1.0 else Color("b7bcb5")
	draw_string(font, Vector2(6, 14), "余额", HORIZONTAL_ALIGNMENT_LEFT, 42, 8, Color("778b96"))
	draw_string(font, Vector2(40, 14), FORMAT.format_currency(int(persistent_state.get("balance", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 75, 10, balance_color)
	var quicklink_items: Array = phone.quicklink_items

	var mel: Dictionary = quicklink_items[0] if not quicklink_items.is_empty() else {"name":"褪黑素", "description":"延长梦境时间。"}
	var mel_card := Rect2(0, 27, 121, 82)
	PhoneShopUI.draw_pixel_product_card(self, mel_card, PRODUCT_ICONS.melatonin, str(mel.name), str(mel.description), font)
	# 价格与购买按钮同一行左右分布（价格在按钮左侧），宽度足够完整显示。
	draw_string(font, Vector2(8, 95), "%s  %d/%d" % [FORMAT.format_currency(config.melatonin_price), int(persistent_state.get("melatonin_inventory", 0)), config.melatonin_inventory_cap], HORIZONTAL_ALIGNMENT_LEFT, 64, 8, Color("91a0a5"))
	var mel_capped: bool = int(persistent_state.get("melatonin_inventory", 0)) >= config.melatonin_inventory_cap
	var mel_insufficient: bool = int(persistent_state.get("balance", 0)) < config.melatonin_price
	PhoneShopUI.draw_pixel_shop_button(self, BUY_MELATONIN_BUTTON, "已满" if mel_capped else ("不足" if mel_insufficient else "购买"), mel_capped or mel_insufficient, hovered_action == "buy_melatonin", font)

	var meal: Dictionary = quicklink_items[1] if quicklink_items.size() > 1 else {"name":"廉价便当", "description":"简单的能量摄入"}
	var meal_card := Rect2(0, 113, 121, 82)
	PhoneShopUI.draw_pixel_product_card(self, meal_card, PRODUCT_ICONS.cheap_meal, str(meal.name), str(meal.description), font)
	draw_string(font, Vector2(8, 181), "%s  每日%d份" % [FORMAT.format_currency(config.cheap_meal_price), config.cheap_meal_daily_purchase_limit], HORIZONTAL_ALIGNMENT_LEFT, 64, 8, Color("91a0a5"))
	var meal_sold: bool = int(persistent_state.get("cheap_meal_purchases_today", 0)) >= config.cheap_meal_daily_purchase_limit
	var meal_insufficient: bool = int(persistent_state.get("balance", 0)) < config.cheap_meal_price
	PhoneShopUI.draw_pixel_shop_button(self, BUY_CHEAP_MEAL_BUTTON, "今日已购" if meal_sold else ("不足" if meal_insufficient else "购买"), meal_sold or meal_insufficient, hovered_action == "buy_cheap_meal", font)

	var sunshade: Dictionary = quicklink_items[2] if quicklink_items.size() > 2 else {"name":"遮阳帘", "description":"放下后可屏蔽闹钟白曝光"}
	var sunshade_card := Rect2(0, 199, 121, 82)
	PhoneShopUI.draw_pixel_product_card(self, sunshade_card, PRODUCT_ICONS.sunshade, str(sunshade.name), str(sunshade.description), font)
	draw_string(font, Vector2(8, 267), "%s  限买一次" % FORMAT.format_currency(config.sunshade_price), HORIZONTAL_ALIGNMENT_LEFT, 64, 8, Color("91a0a5"))
	var sunshade_owned: bool = bool(persistent_state.get("sunshade_purchased", false))
	var sunshade_insufficient: bool = int(persistent_state.get("balance", 0)) < config.sunshade_price
	PhoneShopUI.draw_pixel_shop_button(self, BUY_SUNSHADE_BUTTON, "已购" if sunshade_owned else ("不足" if sunshade_insufficient else "购买"), sunshade_owned or sunshade_insufficient, hovered_action == "buy_sunshade", font)
