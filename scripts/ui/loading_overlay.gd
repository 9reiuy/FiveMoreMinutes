extends CanvasLayer
class_name LoadingOverlay

@onready var root_control: Control = $Root
@onready var background: ColorRect = $Root/Background
@onready var progress_bar: ProgressBar = $Root/CenterContainer/VBox/ProgressBar
@onready var status_label: Label = $Root/CenterContainer/VBox/StatusLabel
@onready var percent_label: Label = $Root/CenterContainer/VBox/PercentLabel
@onready var dots_label: Label = $Root/CenterContainer/VBox/TitleContainer/Dots

var target_ratio: float = 0.0
var current_ratio: float = 0.0
var dot_timer: float = 0.0
var is_active: bool = false
var alpha_tween: Tween
var animation_token:=0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if root_control != null:
		root_control.modulate.a = 0.0


func _process(delta: float) -> void:
	if not is_active and root_control != null and root_control.modulate.a <= 0.001:
		visible = false
		set_process(false)
		return

	# Smooth progress interpolation
	current_ratio = move_toward(current_ratio, target_ratio, delta * 3.0)
	if progress_bar != null:
		progress_bar.value = current_ratio * 100.0
	if percent_label != null:
		percent_label.text = "%d%%" % int(round(current_ratio * 100.0))

	# Animated pulsing dots
	dot_timer += delta * 3.0
	var dots := int(dot_timer) % 4
	if dots_label != null:
		dots_label.text = ".".repeat(dots)


func show_loading(initial_text: String = "正在构建梦境宅邸...") -> void:
	set_process(true)
	animation_token+=1
	if alpha_tween!=null and alpha_tween.is_valid(): alpha_tween.kill()
	is_active = true
	visible = true
	target_ratio = 0.05
	current_ratio = 0.05
	if progress_bar != null:
		progress_bar.value = 5.0
	if status_label != null:
		status_label.text = initial_text
	if percent_label != null:
		percent_label.text = "5%"

	if root_control != null:
		alpha_tween=create_tween()
		alpha_tween.tween_property(root_control, "modulate:a", 1.0, 0.12)


func set_progress(ratio: float, text: String = "") -> void:
	target_ratio = maxf(target_ratio,clampf(ratio,0.0,1.0))
	if not text.is_empty() and status_label != null:
		status_label.text = text


func hide_loading() -> void:
	animation_token+=1
	var token:=animation_token
	if alpha_tween!=null and alpha_tween.is_valid(): alpha_tween.kill()
	target_ratio = 1.0
	current_ratio = 1.0
	if progress_bar != null:
		progress_bar.value = 100.0
	if percent_label != null:
		percent_label.text = "100%"

	is_active = false
	if root_control != null:
		alpha_tween=create_tween()
		alpha_tween.tween_property(root_control,"modulate:a",0.0,0.12)
		while token==animation_token and alpha_tween.is_running(): await get_tree().process_frame
	if token==animation_token: visible=false
