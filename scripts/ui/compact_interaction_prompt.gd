extends Label
## Clear HUD presentation only. No input, world collision, or gameplay ownership.
const DURATION := 0.16
const SLIDE := 10.0
## Halve HSV saturation while retaining each original colour's hue and value.
const FRAME_COLOR := Color(141.5 / 255.0, 168.5 / 255.0, 226.0 / 255.0)
const BACKGROUND_COLOR := Color(25.5 / 255.0, 29.5 / 255.0, 35.0 / 255.0)
const SECONDARY_FRAME_COLOR := Color(0.695, 0.745, 0.77)
const SECONDARY_BACKGROUND_COLOR := Color(0.0575, 0.0675, 0.08, 0.94)
const TEXT_COLOR := Color(0.895, 0.945, 0.96)
const TEXT_OUTLINE_COLOR := Color(0.04, 0.05, 0.06)
const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const FONT_SIZE := 14
const SHORT_ACTIONS := ["拾取","替换","进入","交流"]
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
		if label.text in SHORT_ACTIONS:
			var amount: float=label.frame_expansion()
			box=Rect2(Vector2(roundf(label.size.x*.5-width*amount*.5),-3),Vector2(maxf(2,roundf(width*amount)),label.size.y+6))
			draw_rect(box,BACKGROUND_COLOR)
			# Thin straight frame, inset echo and staggered corner caps.
			draw_rect(box,FRAME_COLOR,false,1)
			if box.size.x>12:
				draw_line(box.position+Vector2(3,2),Vector2(box.end.x-2,box.position.y+2),Color(FRAME_COLOR,.45),1)
				draw_line(Vector2(box.end.x-2,box.position.y+2),box.end-Vector2(2,3),Color(FRAME_COLOR,.45),1)
				for corner in [box.position,box.end]:
					var sign_value: float=1 if corner==box.position else -1
					draw_line(corner+Vector2(-2,4)*sign_value,corner+Vector2(-2,-2)*sign_value,FRAME_COLOR,1)
					draw_line(corner+Vector2(-2,-2)*sign_value,corner+Vector2(6,-2)*sign_value,FRAME_COLOR,1)
			return
		draw_rect(box, SECONDARY_BACKGROUND_COLOR)
		draw_rect(box, SECONDARY_FRAME_COLOR, false, 1.0)
		var center := floorf(label.size.x * 0.5)
		draw_rect(Rect2(center - 2, box.end.y, 4, 2), SECONDARY_FRAME_COLOR)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override(&"font", PIXEL_FONT.get_font())
	add_theme_font_size_override(&"font_size", FONT_SIZE)
	add_theme_color_override(&"font_color", TEXT_COLOR)
	add_theme_color_override(&"font_outline_color", TEXT_OUTLINE_COLOR)
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false
	set_process(false)
	backdrop = Backdrop.new()
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

func present(message: String, screen_anchor: Vector2, key: int) -> void:
	if message.is_empty():
		text = ""
		dismiss(true)
		return
	anchor = screen_anchor.round()
	if not wanted or key != target_key:
		reveal = 0.0
	target_key = key
	wanted = true
	text = message
	visible = true
	set_process(true)
	_apply_animation()

func dismiss(immediate := false) -> void:
	wanted = false
	if immediate:
		reveal = 0.0
		visible = false
		modulate.a = 0.0
		set_process(false)

func _process(delta: float) -> void:
	if get_tree().paused:
		dismiss(true)
		return
	reveal = move_toward(reveal, 1.0 if wanted else 0.0, delta / DURATION)
	_apply_animation()
	if not wanted and reveal == 0.0:
		visible = false
		set_process(false)

func _apply_animation() -> void:
	var travel:=1.0-pow(1.0-reveal,2)
	position = (anchor + Vector2(0, SLIDE * (1.0 - travel))).round()
	modulate.a = reveal
	self_modulate.a=clampf((reveal-.15)/.45,0,1) if text in SHORT_ACTIONS else 1.0
	if is_instance_valid(backdrop): backdrop.queue_redraw()

func frame_expansion() -> float:
	# Ease-out back, drawn in integer pixels; never scale Chinese glyphs.
	var t:=reveal-1.0
	return maxf(.08,1.0+2.4*t*t*t+1.4*t*t) if wanted else maxf(.08,reveal)

static func pickup_verb(target: Node, actor: Node) -> String:
	if target.is_in_group(&"employee_badge_pickup"):
		return ""
	if actor.has_method("get_weapon_in_category"):
		var visuals = preload("res://scripts/data/dream_gun_atlas.gd")
		var category = visuals.get_category(str(target.get("weapon_id")))
		return "" if str(actor.call("get_weapon_in_category", category)).is_empty() else "替换"
	return "" if str(actor.get("selected_weapon_id")).is_empty() else "替换"
