class_name DreamBrowserApp
extends Control

signal weapon_selected(weapon_id: String)

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const WEAPON_IDS := ["basic", "shotgun", "beam", "katana", "grenade"]
const WEAPON_DATA := {
	"basic": {"name":"小手枪", "description":"快速发射单发子弹。"},
	"shotgun": {"name":"霰弹枪", "description":"一次发射多枚散射弹丸。"},
	"beam": {"name":"光束武器", "description":"发射贯穿直线光束。"},
	"katana": {"name":"太刀", "description":"近身斩击并发射剑气。"},
	"grenade": {"name":"榴弹", "description":"投掷范围爆炸物。"},
}
const UNLOCK_KEYS := {"shotgun":"shotgun_unlocked", "beam":"beam_weapon_unlocked", "katana":"katana_unlocked", "grenade":"grenade_weapon_unlocked"}

var persistent_state: Dictionary = {}
var hovered_weapon := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_clear_hover)


func configure(state: Dictionary) -> void:
	persistent_state = state
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next := _weapon_at(event.position)
		if next != hovered_weapon:
			hovered_weapon = next
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not next.is_empty() else Control.CURSOR_ARROW
			if not next.is_empty(): SFX.play_event(&"ui_hover")
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var weapon_id := _weapon_at(event.position)
		if not weapon_id.is_empty():
			SFX.play_event(&"confirm")
			weapon_selected.emit(weapon_id)
			accept_event()


func _weapon_at(point: Vector2) -> String:
	for index in WEAPON_IDS.size():
		var weapon_id: String = WEAPON_IDS[index]
		if _is_unlocked(weapon_id) and _item_rect(index).has_point(point): return weapon_id
	return ""


func _is_unlocked(weapon_id: String) -> bool:
	return weapon_id == "basic" or bool(persistent_state.get(UNLOCK_KEYS.get(weapon_id, ""), false))


func is_weapon_unlocked(weapon_id: String) -> bool:
	return _is_unlocked(weapon_id)


func _item_rect(index: int) -> Rect2:
	return Rect2(12, 31 + index * 40, maxf(size.x - 24, 120), 35)


func _clear_hover() -> void:
	hovered_weapon = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1722"))
	var font := PixelFont.get_font()
	draw_string(font, Vector2(12, 17), "DREAM BROWSER // 已解锁武器", HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 24), 10, Color("9fc5d4"))
	var current := str(persistent_state.get("current_weapon_id", "basic"))
	for index in WEAPON_IDS.size():
		var weapon_id: String = WEAPON_IDS[index]
		if not _is_unlocked(weapon_id): continue
		var rect := _item_rect(index)
		var selected := weapon_id == current
		var hovered := weapon_id == hovered_weapon
		draw_rect(rect, Color("19364a") if hovered else Color("112838"))
		draw_rect(rect, Color("7daec1") if selected else Color("315d76"), false, 1.0)
		_draw_weapon_icon(weapon_id, rect.position + Vector2(7, 7))
		var data: Dictionary = WEAPON_DATA[weapon_id]
		draw_string(font, rect.position + Vector2(31, 13), str(data.name), HORIZONTAL_ALIGNMENT_LEFT, 112, 9, Color("d2e6ec"))
		draw_string(font, rect.position + Vector2(31, 27), str(data.description), HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 92), 7, Color("7f9eaa"))
		if selected: draw_string(font, rect.position + Vector2(rect.size.x - 50, 20), "当前", HORIZONTAL_ALIGNMENT_CENTER, 42, 8, Color("e5c873"))


func _draw_weapon_icon(weapon_id: String, origin: Vector2) -> void:
	var accent: Color = {"basic":Color("7195ad"), "shotgun":Color("8aa0aa"), "beam":Color("5ab9ca"), "katana":Color("a0b5c0"), "grenade":Color("849b75")}.get(weapon_id, Color("7195ad"))
	draw_rect(Rect2(origin, Vector2(20, 20)), Color("09131c"))
	draw_rect(Rect2(origin, Vector2(20, 20)), Color("294d62"), false, 1.0)
	match weapon_id:
		"katana": draw_line(origin + Vector2(4, 16), origin + Vector2(16, 4), accent, 2.0)
		"grenade":
			draw_circle(origin + Vector2(10, 12), 5, accent)
			draw_rect(Rect2(origin + Vector2(9, 4), Vector2(5, 4)), accent)
		"beam":
			draw_rect(Rect2(origin + Vector2(3, 9), Vector2(14, 3)), accent)
			draw_rect(Rect2(origin + Vector2(15, 6), Vector2(2, 9)), accent)
		_:
			draw_rect(Rect2(origin + Vector2(3, 7), Vector2(14, 5 if weapon_id == "shotgun" else 3)), accent)
			draw_rect(Rect2(origin + Vector2(7, 11), Vector2(4, 5)), accent)
