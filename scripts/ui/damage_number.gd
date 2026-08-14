extends Node2D

## 伤害数字两种模式：
## - TOTAL：同一敌人的短窗口累计“总伤显示”，持续受击时只更新同一个数字
##   （数值叠加、字号随累计增大但有上限），0.6 秒无新伤害后上浮淡出。
## - CRITICAL：暴击时只显示“暴击”两个字（不带任何伤害数值），
##   短暂上弹后淡出；暴击的真实伤害仍计入总伤累计。

signal finished

enum Mode { TOTAL, CRITICAL, HEAL }

const TOTAL_IDLE_SECONDS := 0.6
const TOTAL_FADE_SECONDS := 0.35
const TOTAL_RISE_SPEED := 14.0
const CRITICAL_DURATION := 0.5
const CRITICAL_TEXT := "暴击"
# 字号随累计总伤按平方根增长；上限 46px 且总宽 ≤140px，
# 保证最大视觉尺寸不超过宝箱怪（约 245px 宽）身体大小。
const BASE_FONT_SIZE := 14
const MAX_FONT_SIZE := 46
const MAX_TEXT_WIDTH := 140.0

var mode: Mode = Mode.CRITICAL
var total := 0
var active := false
var elapsed := 0.0
var idle_left := 0.0
var fade_left := 0.0
var drift := Vector2.ZERO


func _ready() -> void:
	visible = false
	set_process(false)


## 暴击提示：只显示“暴击”文字（不显示伤害数值），短暂上弹后淡出。
func activate(at_position: Vector2) -> void:
	mode = Mode.CRITICAL
	total = 0
	global_position = at_position + Vector2(randf_range(-5.0, 5.0), 0.0)
	elapsed = 0.0
	drift = Vector2(randf_range(-6.0, 6.0), -30.0)
	modulate.a = 1.0
	active = true
	visible = true
	set_process(true)
	queue_redraw()


## 总伤数字：开启累计窗口；窗口期间由 add_total 反复更新同一个节点。
func activate_total(at_position: Vector2, first_amount: int) -> void:
	mode = Mode.TOTAL
	total = 0
	global_position = at_position
	idle_left = TOTAL_IDLE_SECONDS
	fade_left = 0.0
	modulate.a = 1.0
	active = true
	visible = true
	set_process(true)
	add_total(first_amount)


## 回复数字复用总伤数字的0.6秒保持、0.35秒淡出和上浮速度。
func activate_heal(at_position: Vector2, amount: int) -> void:
	mode = Mode.HEAL
	total = maxi(1, amount)
	global_position = at_position + Vector2(randf_range(-5.0, 5.0), -34.0)
	idle_left = TOTAL_IDLE_SECONDS
	fade_left = 0.0
	modulate.a = 1.0
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func add_total(amount: int) -> void:
	total += maxi(1, amount)
	idle_left = TOTAL_IDLE_SECONDS
	fade_left = 0.0
	modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if mode == Mode.TOTAL or mode == Mode.HEAL:
		position.y -= TOTAL_RISE_SPEED * delta
		if fade_left > 0.0:
			fade_left -= delta
			modulate.a = clampf(fade_left / TOTAL_FADE_SECONDS, 0.0, 1.0)
			if fade_left <= 0.0:
				_finish()
		else:
			idle_left -= delta
			if idle_left <= 0.0:
				fade_left = TOTAL_FADE_SECONDS
	else:
		elapsed += delta
		position += drift * delta
		modulate.a = 1.0 - clampf(elapsed / CRITICAL_DURATION, 0.0, 1.0)
		if elapsed >= CRITICAL_DURATION:
			_finish()


func _finish() -> void:
	active = false
	visible = false
	set_process(false)
	finished.emit()


func _total_font_size() -> int:
	var font_size := BASE_FONT_SIZE + int(sqrt(float(maxi(total, 1))) * 2.2)
	var text := str(total)
	var font := PixelFont.get_font()
	# 宽度超上限时逐级缩小，确保高伤害数字醒目但不遮挡整个战斗画面。
	while font_size > BASE_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > MAX_TEXT_WIDTH:
		font_size -= 2
	return mini(font_size, MAX_FONT_SIZE)


func _draw() -> void:
	var font := PixelFont.get_font()
	if mode == Mode.CRITICAL:
		# 暴击提示不带任何数值，只用强调色短暂弹出，不抢过总伤数字。
		var text_width := font.get_string_size(CRITICAL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(-text_width * 0.5, 0), CRITICAL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e05a5a"))
		return
	if mode == Mode.HEAL:
		var heal_text := "+%d" % total
		var heal_width := font.get_string_size(heal_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BASE_FONT_SIZE).x
		draw_string(font, Vector2(-heal_width * 0.5, 0), heal_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BASE_FONT_SIZE, Color("55c96b"))
		return
	var font_size := _total_font_size()
	var text := str(total)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
