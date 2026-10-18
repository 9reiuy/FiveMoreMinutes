extends Label
## Clear HUD presentation only. No input, world collision, or gameplay ownership.
const DURATION := 0.10
const SLIDE := 10.0
var anchor := Vector2.ZERO
var reveal := 0.0
var wanted := false
var target_key := 0
var backdrop: Control

class Backdrop extends Control:
	func _draw() -> void:
		var label := get_parent() as Label
		if label.text.is_empty(): return
		var font := label.get_theme_font(&"font")
		var width := ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x) + 12.0
		var box := Rect2(Vector2(floorf((label.size.x - width) * 0.5), -3), Vector2(width, label.size.y + 6))
		draw_rect(box, Color(0.035, 0.055, 0.08, 0.94))
		draw_rect(box, Color(0.62, 0.72, 0.77), false, 1.0)
		var center := floorf(label.size.x * 0.5)
		draw_rect(Rect2(center - 2, box.end.y, 4, 2), Color(0.62, 0.72, 0.77))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	backdrop = Backdrop.new()
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

func present(message: String, screen_anchor: Vector2, key: int) -> void:
	anchor = screen_anchor.round()
	if not wanted or key != target_key:
		reveal = 0.0
	target_key = key
	wanted = true
	text = message
	visible = true
	_apply_animation()

func dismiss(immediate := false) -> void:
	wanted = false
	if immediate:
		reveal = 0.0
		visible = false
		modulate.a = 0.0

func _process(delta: float) -> void:
	if get_tree().paused:
		dismiss(true)
		return
	reveal = move_toward(reveal, 1.0 if wanted else 0.0, delta / DURATION)
	_apply_animation()
	if not wanted and reveal == 0.0:
		visible = false

func _apply_animation() -> void:
	position = (anchor + Vector2(0, SLIDE * (1.0 - reveal))).round()
	modulate.a = reveal
	if is_instance_valid(backdrop): backdrop.queue_redraw()

static func pickup_verb(target: Node, actor: Node) -> String:
	if target.is_in_group(&"employee_badge_pickup"):
		return "拾取"
	if actor.has_method("get_weapon_in_category"):
		var visuals = preload("res://scripts/data/dream_gun_atlas.gd")
		var category = visuals.get_category(str(target.get("weapon_id")))
		return "拾取" if str(actor.call("get_weapon_in_category", category)).is_empty() else "替换"
	return "拾取" if str(actor.get("selected_weapon_id")).is_empty() else "替换"
