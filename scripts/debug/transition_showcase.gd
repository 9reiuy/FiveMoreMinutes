extends Control

const SHARD_SHADER := preload("res://shaders/transitions/dream_shard_transition.gdshader")
const BAYER_SHADER := preload("res://shaders/transitions/bayer_dither_transition.gdshader")
const CRT_SCENE := preload("res://scenes/ui/death_crt_effect.tscn")
const BEDROOM_SCENE := preload("res://scenes/bedroom/bedroom.tscn")
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

@onready var scene_container: Node = $SceneContainer
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var director: TransitionDirector = $TransitionLayer/TransitionDirector
@onready var dither_rect: ColorRect = $TransitionLayer/DitherRect
@onready var baseline_fade: ColorRect = $TransitionLayer/BaselineFade
@onready var ui_layer: CanvasLayer = $UILayer
@onready var status_label: Label = $UILayer/Panel/VBox/StatusLabel

# Buttons
@onready var btn_mask_a: Button = $UILayer/Panel/VBox/ButtonRow/BtnMaskA
@onready var btn_mask_b: Button = $UILayer/Panel/VBox/ButtonRow/BtnMaskB
@onready var btn_mask_c: Button = $UILayer/Panel/VBox/ButtonRow/BtnMaskC
@onready var btn_dither: Button = $UILayer/Panel/VBox/ButtonRow/BtnDither
@onready var btn_crt: Button = $UILayer/Panel/VBox/ButtonRow/BtnCrt
@onready var btn_baseline: Button = $UILayer/Panel/VBox/ButtonRow/BtnBaseline
@onready var btn_swap: Button = $UILayer/Panel/VBox/ButtonRow/BtnSwap

var crt_effect: DeathCrtEffect = null
var current_scene_index := 0
var transition_running := false
var duration := 0.45
var dither_material: ShaderMaterial


func _ready() -> void:
	# Configure Dither Material
	dither_material = ShaderMaterial.new()
	dither_material.shader = BAYER_SHADER
	dither_rect.material = dither_material
	dither_rect.visible = false
	dither_material.set_shader_parameter("progress", 0.0)

	# Configure Baseline Fade
	baseline_fade.visible = false
	baseline_fade.color = Color(0, 0, 0, 0)

	# Instantiate CRT
	crt_effect = CRT_SCENE.instantiate()
	transition_layer.add_child(crt_effect)

	# Wire buttons
	btn_mask_a.pressed.connect(func(): play_shard_transition("bilateral", "双向尖锐三角夹逼 (参考动图同款)"))
	btn_mask_b.pressed.connect(func(): play_shard_transition("diagonal", "45°斜向尖锐三角推进"))
	btn_mask_c.pressed.connect(func(): play_shard_transition("radial", "径向向心三角侵蚀"))
	btn_dither.pressed.connect(play_dither_transition)
	btn_crt.pressed.connect(play_crt_transition)
	btn_baseline.pressed.connect(play_baseline_transition)
	btn_swap.pressed.connect(func():
		_load_scene(1 if current_scene_index == 0 else 0)
		_update_ui_status("直接换景 (无转场)")
	)

	# Initial scene: Bedroom
	_load_scene(0)
	_update_ui_status("待命 (点击按钮或按键盘 1-6 / 空格)")


func _load_scene(idx: int) -> void:
	for child in scene_container.get_children():
		child.queue_free()

	if idx == 0:
		var b = BEDROOM_SCENE.instantiate()
		scene_container.add_child(b)
	else:
		var r = RECEPTION_SCENE.instantiate()
		scene_container.add_child(r)
	current_scene_index = idx


func _input(event: InputEvent) -> void:
	if transition_running or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var code: Key = key_event.keycode
	if code == KEY_NONE:
		code = key_event.physical_keycode
	if code == KEY_KP_1: code = KEY_1
	elif code == KEY_KP_2: code = KEY_2
	elif code == KEY_KP_3: code = KEY_3
	elif code == KEY_KP_4: code = KEY_4
	elif code == KEY_KP_5: code = KEY_5
	elif code == KEY_KP_6: code = KEY_6

	match code:
		KEY_1:
			play_shard_transition("bilateral", "双向尖锐三角夹逼 (参考动图同款)")
		KEY_2:
			play_shard_transition("diagonal", "45°斜向尖锐三角推进")
		KEY_3:
			play_shard_transition("radial", "径向向心三角侵蚀")
		KEY_4:
			play_dither_transition()
		KEY_5:
			play_crt_transition()
		KEY_6:
			play_baseline_transition()
		KEY_SPACE:
			_load_scene(1 if current_scene_index == 0 else 0)
			_update_ui_status("直接换景 (无转场)")


func play_shard_transition(mask_id: String, mask_name: String) -> void:
	if transition_running: return
	transition_running = true
	_update_ui_status("播放中: 尖锐碎片侵蚀 · %s" % mask_name)

	var swap_callback = func():
		_load_scene(1 if current_scene_index == 0 else 0)

	var ok = await director.play_transition(mask_id, swap_callback, duration * 0.9, duration)
	transition_running = false
	if ok:
		_update_ui_status("完成: 尖锐碎片侵蚀 · %s" % mask_name)
	else:
		_update_ui_status("转场异常被重置")


func play_dither_transition() -> void:
	if transition_running: return
	transition_running = true
	dither_rect.visible = true
	_update_ui_status("播放中: Bayer Dither 像素消融")

	var tw1 := create_tween()
	tw1.tween_method(func(val: float): dither_material.set_shader_parameter("progress", val), 0.0, 1.0, duration * 0.5)
	await tw1.finished

	_load_scene(1 if current_scene_index == 0 else 0)

	var tw2 := create_tween()
	tw2.tween_method(func(val: float): dither_material.set_shader_parameter("progress", val), 1.0, 0.0, duration * 0.5)
	await tw2.finished

	dither_rect.visible = false
	transition_running = false
	_update_ui_status("完成: Bayer Dither 像素消融")


func play_crt_transition() -> void:
	if transition_running: return
	transition_running = true
	_update_ui_status("播放中: CRT 关机抽帧惊醒")
	crt_effect.play(duration * 0.8)
	await crt_effect.finished
	_load_scene(1 if current_scene_index == 0 else 0)
	transition_running = false
	_update_ui_status("完成: CRT 关机抽帧惊醒")


func play_baseline_transition() -> void:
	if transition_running: return
	transition_running = true
	baseline_fade.visible = true
	_update_ui_status("播放中: 原生普通淡入淡出 (基准对照)")

	var tw1 := create_tween()
	tw1.tween_property(baseline_fade, "color:a", 1.0, duration * 0.5)
	await tw1.finished

	_load_scene(1 if current_scene_index == 0 else 0)

	var tw2 := create_tween()
	tw2.tween_property(baseline_fade, "color:a", 0.0, duration * 0.5)
	await tw2.finished

	baseline_fade.visible = false
	transition_running = false
	_update_ui_status("完成: 原生普通淡入淡出")


func _update_ui_status(text: String) -> void:
	if is_instance_valid(status_label):
		var scene_name = "卧室" if current_scene_index == 0 else "前台接待区"
		status_label.text = "场景: %s | %s" % [scene_name, text]
