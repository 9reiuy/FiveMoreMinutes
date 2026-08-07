class_name DeathCrtEffect
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal finished

@onready var overlay: ColorRect = $CrtOverlay
@onready var material: ShaderMaterial = $CrtOverlay.material

var active := false
var effect_progress := 0.0
var effect_duration := 0.0


func _ready() -> void:
	layer = 30
	if is_instance_valid(material):
		material.set_shader_parameter("progress", 0.0)


func play(duration: float) -> void:
	if active or not is_inside_tree():
		return
	active = true
	effect_progress = 0.0
	effect_duration = maxf(duration, 0.05)
	SFX.play_event(&"crt_off")
	_set_progress(0.0)


func _process(delta: float) -> void:
	if not active:
		return
	effect_progress += delta / effect_duration
	if effect_progress >= 1.0:
		effect_progress = 1.0
		_set_progress(1.0)
		active = false
		finished.emit()
		# Keep the final black frame on screen so the dying game scene never
		# flashes back in. The scene transition (fade -> swap -> reveal) frees
		# this node together with its parent scene.
	else:
		_set_progress(effect_progress)


func _set_progress(value: float) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("progress", value)

