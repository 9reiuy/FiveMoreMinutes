class_name EnemyOutlineController
extends Node

const OUTLINE_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")

var target_sprite: AnimatedSprite2D
var locked := false


func configure(sprite: AnimatedSprite2D) -> void:
	target_sprite = sprite
	if target_sprite == null:
		return
	# Every enemy receives an independent material so lock changes never leak to peers.
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_enabled", 0.0)
	outline_material.set_shader_parameter("outline_width_source_pixels", 5.0)
	outline_material.set_shader_parameter("outline_color", Color.WHITE)
	target_sprite.material = outline_material


func set_locked(value: bool) -> void:
	locked = value
	if target_sprite != null and target_sprite.material is ShaderMaterial:
		(target_sprite.material as ShaderMaterial).set_shader_parameter("outline_enabled", 1.0 if locked else 0.0)
