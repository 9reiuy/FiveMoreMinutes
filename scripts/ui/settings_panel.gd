class_name UnifiedSettingsPanel
extends VBoxContainer

const SFX := preload("res://scripts/audio/sfx_manager.gd")

@onready var master_slider: HSlider = $Master/ControlRow/Slider
@onready var master_value: Label = $Master/ControlRow/Value
@onready var music_slider: HSlider = $Music/ControlRow/Slider
@onready var music_value: Label = $Music/ControlRow/Value
@onready var sfx_slider: HSlider = $SFX/ControlRow/Slider
@onready var sfx_value: Label = $SFX/ControlRow/Value
@onready var sleepwalk_toggle: CheckButton = $Sleepwalk
@onready var fast_sleep_toggle: CheckButton = $FastSleep

var syncing := false


func _ready() -> void:
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_entered.connect(_play_hover)
		slider.drag_ended.connect(_on_slider_drag_ended)
	sleepwalk_toggle.focus_mode = Control.FOCUS_NONE
	sleepwalk_toggle.mouse_entered.connect(_play_hover)
	fast_sleep_toggle.focus_mode = Control.FOCUS_NONE
	fast_sleep_toggle.mouse_entered.connect(_play_hover)
	master_slider.value_changed.connect(_on_volume_changed.bind(&"master_volume"))
	music_slider.value_changed.connect(_on_volume_changed.bind(&"music_volume"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(&"sfx_volume"))
	sleepwalk_toggle.toggled.connect(_on_sleepwalk_toggled)
	fast_sleep_toggle.toggled.connect(_on_fast_sleep_toggled)
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_sync_all()


func _sync_all() -> void:
	syncing = true
	master_slider.value = SettingsManager.get_volume(&"master_volume")
	music_slider.value = SettingsManager.get_volume(&"music_volume")
	sfx_slider.value = SettingsManager.get_volume(&"sfx_volume")
	sleepwalk_toggle.button_pressed = SettingsManager.get_sleepwalk_mode()
	fast_sleep_toggle.button_pressed = SettingsManager.get_fast_sleep_enabled()
	_refresh_value_labels()
	syncing = false


func _on_volume_changed(value: float, setting_name: StringName) -> void:
	if syncing:
		return
	SettingsManager.set_volume(setting_name, value)
	_refresh_value_labels()


func _on_sleepwalk_toggled(enabled: bool) -> void:
	if syncing:
		return
	SFX.play_event(&"confirm")
	SettingsManager.set_sleepwalk_mode(enabled)


func _on_fast_sleep_toggled(enabled: bool) -> void:
	if syncing:
		return
	SFX.play_event(&"confirm")
	SettingsManager.set_fast_sleep_enabled(enabled)


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	_sync_all()


func _refresh_value_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _on_slider_drag_ended(_value_changed: bool) -> void:
	SFX.play_event(&"confirm")


func _play_hover() -> void:
	SFX.play_event(&"ui_hover")
