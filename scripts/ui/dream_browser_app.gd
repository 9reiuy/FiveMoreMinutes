class_name DreamBrowserApp
extends Control

signal weapon_selected(weapon_id: String)

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const WEAPON_DATA := {
	"basic": {"name":"小手枪", "description":"快速发射单发子弹。"},
	"shotgun": {"name":"霰弹枪", "description":"一次发射多枚散射弹丸。"},
	"lucille": {"name":"露西尔", "description":"10px纯近战，命中Employee必定击倒。"},
	"assault_rifle": {"name":"突击枪", "description":"高射速自动步枪。"},
	"books": {"name":"Books", "description":"近距离扇形近战。"},
}
const UNLOCK_KEYS := {"shotgun":"shotgun_unlocked"}

var persistent_state: Dictionary = {}
var hovered_weapon := ""
var weapon_ids: Array[String] = []
var _scroll_row := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(_clear_hover)
	weapon_ids = DreamGunAtlas.get_weapon_ids()
	configure(persistent_state)


func configure(state: Dictionary) -> void:
	persistent_state = state
	var available := _unlocked_weapon_ids()
	var selected := available.find(str(state.get("current_weapon_id", "basic")))
	_scroll_row = clampi(selected, 0, maxi(available.size() - _visible_rows(), 0))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_scroll_row = clampi(_scroll_row + step, 0, maxi(_unlocked_weapon_ids().size() - _visible_rows(), 0))
		_clear_hover()
		accept_event()
	elif event is InputEventMouseMotion:
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
	var available := _unlocked_weapon_ids()
	for index in range(_scroll_row, mini(available.size(), _scroll_row + _visible_rows())):
		if _item_rect(index).has_point(point): return available[index]
	return ""


func _unlocked_weapon_ids() -> Array[String]:
	var available: Array[String] = []
	for id in weapon_ids:
		if _is_unlocked(id): available.append(id)
	return available


func _visible_rows() -> int:
	return maxi(1, floori((size.y - 31.0) / 40.0))


func _is_unlocked(weapon_id: String) -> bool:
	if not DreamGunAtlas.has_weapon(weapon_id):
		return false
	if weapon_id == "basic" or DreamGunAtlas.uses_lucille_motion(weapon_id):
		return true
	var unlock_key := str(UNLOCK_KEYS.get(weapon_id, ""))
	return not unlock_key.is_empty() and bool(persistent_state.get(unlock_key, false))


func is_weapon_unlocked(weapon_id: String) -> bool:
	return _is_unlocked(weapon_id)


func _item_rect(index: int) -> Rect2:
	return Rect2(12, 31 + (index - _scroll_row) * 40, maxf(size.x - 24, 120), 35)


func _clear_hover() -> void:
	hovered_weapon = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1722"))
	var font := PixelFont.get_font()
	draw_string(font, Vector2(12, 17), "DREAM BROWSER // 已解锁武器", HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 24), 10, Color("9fc5d4"))
	var current := str(persistent_state.get("current_weapon_id", "basic"))
	var available := _unlocked_weapon_ids()
	_scroll_row = clampi(_scroll_row, 0, maxi(available.size() - _visible_rows(), 0))
	for index in range(_scroll_row, mini(available.size(), _scroll_row + _visible_rows())):
		var weapon_id: String = available[index]
		var rect := _item_rect(index)
		var selected := weapon_id == current
		var hovered := weapon_id == hovered_weapon
		draw_rect(rect, Color("596d98") if hovered else Color("354464"))
		draw_rect(rect, Color("a8bbe0") if selected else Color("6f84ad"), false, 1.0)
		_draw_weapon_icon(weapon_id, rect.position + Vector2(7, 7))
		var data: Dictionary = WEAPON_DATA.get(weapon_id, {"name":DreamGunAtlas.get_display_name(weapon_id), "description":"近距离挥击并击倒敌人。"})
		draw_string(font, rect.position + Vector2(62, 13), str(data.name), HORIZONTAL_ALIGNMENT_LEFT, 92, 9, Color("d2e6ec"))
		draw_string(font, rect.position + Vector2(62, 27), str(data.description), HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 123), 7, Color("7f9eaa"))
		if selected: draw_string(font, rect.position + Vector2(rect.size.x - 50, 20), "当前", HORIZONTAL_ALIGNMENT_CENTER, 42, 8, Color("e5c873"))
	if available.size() > _visible_rows():
		var track := Rect2(size.x - 7, 31, 3, _visible_rows() * 40 - 5)
		draw_rect(track, Color("223044"))
		var thumb_height := track.size.y * float(_visible_rows()) / available.size()
		var offset := (track.size.y - thumb_height) * _scroll_row / float(available.size() - _visible_rows())
		draw_rect(Rect2(track.position + Vector2(0, offset), Vector2(3, thumb_height)), Color("9fc5d4"))


func _draw_weapon_icon(weapon_id: String, origin: Vector2) -> void:
	if DreamGunAtlas.has_weapon(weapon_id):
		var icon := DreamGunAtlas.get_icon(weapon_id)
		var source_size: Vector2 = icon.get_size()
		var fit_scale := minf(1.0, minf(48.0 / maxf(source_size.x, 1.0), 32.0 / maxf(source_size.y, 1.0)))
		var draw_size := source_size * fit_scale
		draw_texture_rect(icon, Rect2(origin + Vector2(24, 10) - draw_size * 0.5, draw_size), false)
		return
	var accent: Color = {"basic":Color("7195ad"), "shotgun":Color("8aa0aa"), "lucille":Color("a0b5c0"), "assault_rifle":Color("9b8fd0"), "books":Color("d0a45c")}.get(weapon_id, Color("7195ad"))
	draw_rect(Rect2(origin, Vector2(20, 20)), Color("09131c"))
	draw_rect(Rect2(origin, Vector2(20, 20)), Color("294d62"), false, 1.0)
	match weapon_id:
		_:
			draw_rect(Rect2(origin + Vector2(3, 7), Vector2(14, 5 if weapon_id == "shotgun" else 3)), accent)
			draw_rect(Rect2(origin + Vector2(7, 11), Vector2(4, 5)), accent)
