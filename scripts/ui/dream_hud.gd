extends Control

@export var config: DemoConfig

@onready var experience_area: Control = $ExperienceBarArea
@onready var level_label: Label = $ExperienceBarArea/Content/LevelLabel
@onready var experience_bar: ProgressBar = $ExperienceBarArea/Content/ExperienceProgressBar
@onready var experience_value_label: Label = $ExperienceBarArea/Content/ExperienceValueLabel

var time_text := "04:00"
var health := 100.0
var maximum_health := 100.0
var level := 1
var experience := 0
var experience_target := 20
var kills := 0
var dash_remaining := 0.0
var dash_total := 2.0
var dash_active := false
var dash_charges := 1
var dash_max_charges := 1
var dash_hunger_disabled := false
var shielded := false
var dissociation_ready := false
var displayed_experience_ratio := 0.0
var target_experience_ratio := 0.0
var level_flash_left := 0.0


func _ready() -> void:
	experience_area.offset_left = config.experience_bar_margin
	experience_area.offset_top = config.experience_bar_margin
	experience_area.offset_right = -config.experience_bar_margin
	experience_area.offset_bottom = config.experience_bar_margin + config.experience_bar_height
	_update_experience_labels()


func _process(delta: float) -> void:
	displayed_experience_ratio = move_toward(displayed_experience_ratio, target_experience_ratio, config.experience_bar_fill_animation_speed * delta)
	experience_bar.value = displayed_experience_ratio * 100.0
	level_flash_left = maxf(0.0, level_flash_left - delta)
	var near_level := target_experience_ratio >= config.experience_bar_near_level_threshold and target_experience_ratio < 1.0
	var pulse := 0.86 + sin(Time.get_ticks_msec() * 0.009) * 0.14 if near_level else 1.0
	experience_bar.modulate = Color(1.18, 1.18, 1.08, 1.0) if level_flash_left > 0.0 else Color(pulse, pulse, pulse, 1.0)
	queue_redraw()


func set_clock(value: String) -> void:
	time_text = value
	queue_redraw()


func set_health(current: float, maximum: float) -> void:
	health = current
	maximum_health = maximum
	queue_redraw()


func set_progression(new_level: int, new_experience: int, target: int, new_kills: int) -> void:
	if new_level > level:
		level_flash_left = 0.35
	level = new_level
	experience = maxi(0, new_experience)
	experience_target = maxi(1, target)
	kills = new_kills
	target_experience_ratio = clampf(float(experience) / experience_target, 0.0, 1.0)
	_update_experience_labels()
	queue_redraw()


func _update_experience_labels() -> void:
	if not is_node_ready():
		return
	level_label.text = "LV. %d" % level
	experience_value_label.text = "%d / %d" % [experience, experience_target]


func set_dash_state(remaining: float, total: float, active: bool, charges: int = 1, maximum_charges: int = 1) -> void:
	dash_remaining = remaining
	dash_total = maxf(total, 0.001)
	dash_active = active
	dash_charges = charges
	dash_max_charges = maximum_charges
	queue_redraw()


func set_hungry_run(enabled: bool) -> void:
	dash_hunger_disabled = enabled
	queue_redraw()


func set_skill_state(has_shield: bool, revive_ready: bool) -> void:
	shielded = has_shield
	dissociation_ready = revive_ready
	queue_redraw()


func _draw() -> void:
	var font := PixelFont.get_font()
	# Secondary combat information stays below the top experience strip.
	draw_rect(Rect2(14, 48, 168, 19), Color(0.035, 0.04, 0.06, 0.82))
	draw_rect(Rect2(18, 52, 160.0 * clampf(health / maxf(maximum_health, 1.0), 0.0, 1.0), 11), Color("81515b"))
	draw_string(font, Vector2(16, 83), "生命 %d/%d" % [int(health), int(maximum_health)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b5b1bb"))
	var dash_ready := dash_charges > 0 and not dash_active and not dash_hunger_disabled
	var button := Rect2(15, 93, 56, 34)
	var icon_color := Color("3f6075") if dash_ready else Color("222a34")
	draw_rect(button, icon_color)
	draw_rect(button, Color("8eabbc") if dash_ready else Color("46515d"), false, 2.0)
	draw_rect(Rect2(button.position, Vector2(3, 3)), Color("101620"))
	draw_rect(Rect2(button.end - Vector2(3, 3), Vector2(3, 3)), Color("101620"))
	var cooldown_ratio := clampf(dash_remaining / dash_total, 0.0, 1.0)
	if cooldown_ratio > 0.0 and not dash_hunger_disabled:
		draw_rect(Rect2(button.position, Vector2(button.size.x * cooldown_ratio, button.size.y)), Color(0.04, 0.055, 0.08, 0.72))
	draw_string(font, Vector2(button.position.x, button.position.y + 14), "SPACE", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 9, Color("d2dbe0") if dash_ready else Color("69737b"))
	draw_string(font, Vector2(button.position.x, button.position.y + 27), "空腹" if dash_hunger_disabled else "冲刺", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 8, Color("9b5965") if dash_hunger_disabled else Color("a8b6bd"))
	draw_string(font, Vector2(77, 103), "禁用" if dash_hunger_disabled else "充能 %d/%d" % [dash_charges, dash_max_charges], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8f5961") if dash_hunger_disabled else Color("a4a8b5"))
	if dash_remaining > 0.0 and not dash_hunger_disabled:
		draw_string(font, Vector2(77, 117), "%.1fs" % dash_remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("858995"))
	draw_string(font, Vector2(0, 66), time_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 19, Color("d2ced6"))
	draw_string(font, Vector2(510, 61), "击败 %d" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8f8c98"))
	if shielded:
		draw_string(font, Vector2(510, 80), "护盾 ◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8ebad0"))
	if dissociation_ready:
		draw_string(font, Vector2(510, 97), "意识解离 ◈", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d7b45f"))
