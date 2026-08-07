extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal weapon_selected(weapon_id: String)

const BASIC_CARD := Rect2(36, 82, 176, 104)
const BEAM_CARD := Rect2(232, 82, 176, 104)
const SHOTGUN_CARD := Rect2(428, 82, 176, 104)
const KATANA_CARD := Rect2(134, 202, 176, 104)
const GRENADE_CARD := Rect2(330, 202, 176, 104)

@export var config: DemoConfig

var hovered_weapon := ""
var selection_locked := false
var unlock_state: Dictionary = {"shotgun": false, "beam": false, "katana": false, "grenade": false}


func _ready() -> void:
	# 武器选择是阻断性 UI：强制 ALWAYS 处理，确保任何暂停原因集合下输入不被冻结；
	# 显式恢复鼠标可见（防止上一个场景残留 HIDDEN 导致无法点击）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 点击/悬停用 _input 处理（先于 GUI 路由），避免鼠标事件被其它全屏
## Control 的 GUI 拾取拦截导致界面无法交互；本界面为 640×360 全屏且
## 位于视口原点，_input 的视口坐标与卡片 Rect 常量直接对应。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var next_hovered := _weapon_at(event.position)
		if not next_hovered.is_empty() and next_hovered != hovered_weapon:
			SFX.play_event(&"ui_hover")
		hovered_weapon = next_hovered
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if selection_locked:
			return
		var selected := _weapon_at(event.position)
		if not selected.is_empty() and _is_unlocked(selected):
			selection_locked = true
			SFX.play_event(&"confirm")
			weapon_selected.emit(selected)


func _weapon_at(point: Vector2) -> String:
	if BASIC_CARD.has_point(point):
		return "basic"
	if BEAM_CARD.has_point(point):
		return "beam"
	if SHOTGUN_CARD.has_point(point):
		return "shotgun"
	if KATANA_CARD.has_point(point):
		return "katana"
	if GRENADE_CARD.has_point(point):
		return "grenade"
	return ""


func _is_unlocked(weapon_id: String) -> bool:
	return weapon_id == "basic" or bool(unlock_state.get(weapon_id, false))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("11121a"))
	var font := PixelFont.get_font()
	draw_string(font, Vector2(0, 62), "选择今晚带入梦中的武器", HORIZONTAL_ALIGNMENT_CENTER, 640, 22, Color("c8c3cb"))
	_draw_card(BASIC_CARD, "basic", "小手枪", "单发投射物", config.basic_weapon_damage, config.basic_weapon_attack_interval, font)
	_draw_card(BEAM_CARD, "beam", "光束武器", "直线穿透范围内所有敌人", config.beam_damage, config.beam_attack_interval, font)
	_draw_card(SHOTGUN_CARD, "shotgun", "霰弹枪", "9颗弹丸 / 30度扩散", config.shotgun_pellet_damage, config.shotgun_attack_interval, font)
	_draw_card(KATANA_CARD, "katana", "太刀", "近身斩击 + 穿透剑气", config.katana_melee_damage, config.katana_attack_interval, font)
	_draw_card(GRENADE_CARD, "grenade", "榴弹", "固定目标 / 范围自伤", config.grenade_enemy_damage, config.grenade_attack_interval, font)
	draw_string(font, Vector2(0, 338), "点击一张卡片进入梦境", HORIZONTAL_ALIGNMENT_CENTER, 640, 14, Color("777987"))


func _draw_card(rect: Rect2, weapon_id: String, title: String, description: String, damage: float, interval: float, font: Font) -> void:
	var hovered := hovered_weapon == weapon_id
	var unlocked := _is_unlocked(weapon_id)
	var fill := Color("31313e") if hovered and unlocked else Color("23242e")
	var border := Color("a49aaa") if hovered and unlocked else Color("555563")
	draw_rect(rect, fill)
	draw_rect(rect.grow(-4), border, false, 2.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 26), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color("d3ced4") if unlocked else Color("656570"))
	if not unlocked:
		var reason := "完成任意结局后解锁" if weapon_id == "grenade" else ("第2天解锁" if weapon_id == "shotgun" else ("第一次迟到后解锁" if weapon_id == "beam" else "第一次旷工后解锁"))
		draw_string(font, Vector2(rect.position.x, rect.position.y + 64), reason, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("77727c"))
		draw_string(font, Vector2(rect.position.x, rect.end.y - 14), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color("855f68"))
		return
	draw_string(font, Vector2(rect.position.x + 8, rect.position.y + 50), description, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 12, Color("9997a1"))
	draw_string(font, Vector2(rect.position.x + 15, rect.position.y + 76), "基础伤害  %.0f" % damage, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b7afb9"))
	draw_string(font, Vector2(rect.position.x + 92, rect.position.y + 76), "间隔 %.2f秒" % interval, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b7afb9"))
