extends Control

@export var config: DemoConfig

@onready var experience_area: Control = $ExperienceBarArea
@onready var experience_bar: ProgressBar = $ExperienceBarArea/ExperienceProgressBar
@onready var experience_value_label: Label = $ExperienceBarArea/ExperienceValueLabel
@onready var dash_icon: TextureRect = $DashIndicator/DashIcon
@onready var endless_day_area: Control = $EndlessDayArea
@onready var endless_day_label: Label = $EndlessDayArea/DayLabel
@onready var endless_day_progress: ProgressBar = $EndlessDayArea/DayProgress

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
var endless_mode := false
var endless_day_duration := 120.0


func _ready() -> void:
	# 顶部只保留经验条：Y=0 贴顶、横向满宽、极薄，无外围 Panel。
	# 高度为旧版 12 的一半（6）；EXP 文字由 Label 垂直居中自动适配。
	experience_area.offset_left = 0.0
	experience_area.offset_top = 0.0
	experience_area.offset_right = 0.0
	experience_area.offset_bottom = 6.0
	_update_experience_labels()
	_update_dash_indicator()
	endless_day_area.visible = endless_mode


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


func configure_endless_mode(enabled: bool, day_duration: float) -> void:
	endless_mode = enabled
	endless_day_duration = maxf(day_duration, 0.001)
	if is_node_ready():
		endless_day_area.visible = enabled


func set_endless_day_progress(day: int, progress: float) -> void:
	if not is_node_ready():
		return
	endless_day_label.text = "第%d天" % maxi(day, 1)
	endless_day_progress.value = clampf(progress, 0.0, 1.0) * 100.0


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
	# 等级显示已移除（内部 level 变量保留），EXP 数值居中叠在经验条内。
	experience_value_label.text = "%d / %d" % [experience, experience_target]


func set_dash_state(remaining: float, total: float, active: bool, charges: int = 1, maximum_charges: int = 1) -> void:
	dash_remaining = remaining
	dash_total = maxf(total, 0.001)
	dash_active = active
	dash_charges = charges
	dash_max_charges = maximum_charges
	_update_dash_indicator()
	queue_redraw()


func set_hungry_run(enabled: bool) -> void:
	dash_hunger_disabled = enabled
	_update_dash_indicator()
	queue_redraw()


func _update_dash_indicator() -> void:
	if not is_instance_valid(dash_icon):
		return
	var material := dash_icon.material as ShaderMaterial
	if material == null:
		return
	# 仍有可用次数时保持完整图标；次数耗尽后，按剩余冷却比例让灰色遮罩
	# 从底部逐步退去。空腹禁用和冲刺动作本身显示为完全灰色。
	var cooldown_ratio := 0.0
	if dash_hunger_disabled or dash_active:
		cooldown_ratio = 1.0
	elif dash_charges <= 0:
		cooldown_ratio = clampf(dash_remaining / maxf(dash_total, 0.001), 0.0, 1.0)
	material.set_shader_parameter("cooldown_ratio", cooldown_ratio)


func set_skill_state(has_shield: bool, revive_ready: bool) -> void:
	shielded = has_shield
	dissociation_ready = revive_ready
	queue_redraw()


func _draw() -> void:
	var font := PixelFont.get_font()
	# HP 条与 HP 文字已全部移除（受伤/回血逻辑不受影响）；
	# Dash 图标由 DashIndicator 节点绘制；文字只保留状态说明。
	# 冲刺状态仅由DashIcon内部灰色冷却遮罩表达，不再显示任何就绪/充能文字。
	# 无尽模式仍保留内部 elapsed_time、Day 和 RAM 结算，只隐藏顶部经过时间。
	if not endless_mode:
		draw_string(font, Vector2(0, 66), time_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 19, Color("d2ced6"))
	draw_string(font, Vector2(510, 61), "击败 %d" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8f8c98"))
	if shielded:
		draw_string(font, Vector2(510, 80), "护盾 ◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8ebad0"))
	if dissociation_ready:
		draw_string(font, Vector2(510, 97), "意识解离 ◈", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d7b45f"))
