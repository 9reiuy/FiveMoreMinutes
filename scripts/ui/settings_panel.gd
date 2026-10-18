class_name UnifiedSettingsPanel
extends VBoxContainer

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const SHADOW_QUALITIES := ["low", "standard", "high"]

@onready var master_slider: HSlider = $Master/ControlRow/Slider
@onready var master_value: Label = $Master/ControlRow/Value
@onready var music_slider: HSlider = $Music/ControlRow/Slider
@onready var music_value: Label = $Music/ControlRow/Value
@onready var sfx_slider: HSlider = $SFX/ControlRow/Slider
@onready var sfx_value: Label = $SFX/ControlRow/Value
@onready var pixelation_check: CheckBox = $Pixelation/ControlRow/Check
@onready var palette_option: OptionButton = $PaletteScheme/ControlRow/Option
@onready var shadow_quality_option: OptionButton = $ShadowQuality/Option
var syncing := false


func _ready() -> void:
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_entered.connect(_play_hover)
		slider.drag_ended.connect(_on_slider_drag_ended)
	master_slider.value_changed.connect(_on_volume_changed.bind(&"master_volume"))
	music_slider.value_changed.connect(_on_volume_changed.bind(&"music_volume"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(&"sfx_volume"))
	pixelation_check.focus_mode = Control.FOCUS_NONE
	pixelation_check.mouse_entered.connect(_play_hover)
	pixelation_check.toggled.connect(_on_pixelation_toggled)
	palette_option.focus_mode = Control.FOCUS_NONE
	palette_option.mouse_entered.connect(_play_hover)
	palette_option.clear()
	palette_option.add_item("方案 1", 0)
	palette_option.add_item("关闭", 1)
	palette_option.item_selected.connect(_on_palette_selected)
	shadow_quality_option.focus_mode = Control.FOCUS_NONE
	shadow_quality_option.mouse_entered.connect(_play_hover)
	for quality_name in ["低", "默认", "高"]:
		shadow_quality_option.add_item(quality_name)
	shadow_quality_option.item_selected.connect(_on_shadow_quality_selected)
	var sm := _get_sm()
	if sm != null and sm.has_signal("setting_changed"):
		sm.connect("setting_changed", _on_setting_changed)
	_sync_all()


func _get_sm() -> Node:
	if Engine.get_main_loop() is SceneTree:
		var root_node = (Engine.get_main_loop() as SceneTree).root
		if root_node != null:
			return root_node.get_node_or_null("SettingsManager")
	return null


func _sync_all() -> void:
	syncing = true
	var sm := _get_sm()
	if sm != null:
		master_slider.value = sm.call("get_volume", &"master_volume")
		music_slider.value = sm.call("get_volume", &"music_volume")
		sfx_slider.value = sm.call("get_volume", &"sfx_volume")
		pixelation_check.set_pressed_no_signal(bool(sm.call("get_setting", &"pixelation_enabled", true)))
		palette_option.select(0 if bool(sm.call("get_palette_enabled")) else 1)
		var quality_index := SHADOW_QUALITIES.find(String(sm.call("get_setting", &"shadow_quality", "standard")))
		shadow_quality_option.select(quality_index if quality_index >= 0 else 1)
	_refresh_value_labels()
	syncing = false


func _on_volume_changed(value: float, setting_name: StringName) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_volume", setting_name, value)
	_refresh_value_labels()


func _on_pixelation_toggled(pressed: bool) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_setting", &"pixelation_enabled", pressed)
	SFX.play_event(&"confirm")


func _on_palette_selected(index: int) -> void:
	if syncing:
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_setting", &"palette_enabled", index == 0)
	SFX.play_event(&"confirm")


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	_sync_all()


func _on_shadow_quality_selected(index: int) -> void:
	if syncing or index < 0 or index >= SHADOW_QUALITIES.size():
		return
	var sm := _get_sm()
	if sm != null:
		sm.call("set_setting", &"shadow_quality", SHADOW_QUALITIES[index])
	SFX.play_event(&"confirm")


func _refresh_value_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _on_slider_drag_ended(_value_changed: bool) -> void:
	SFX.play_event(&"confirm")


func _play_hover() -> void:
	SFX.play_event(&"ui_hover")
