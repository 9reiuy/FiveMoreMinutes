class_name EnemyOutlineController
extends Node

const OUTLINE_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")
const CONFIG := preload("res://resources/demo_config.tres")

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
	# 统一白描边宽度（源纹理像素空间）：shader 基于 TEXTURE_PIXEL_SIZE 换算，
	# 不乘节点 scale，因此 VisualRoot 放大 4 倍也不会变成巨描边。
	outline_material.set_shader_parameter("outline_width_source_pixels", CONFIG.enemy_outline_width_px)
	outline_material.set_shader_parameter("outline_color", Color.WHITE)
	target_sprite.material = outline_material


func set_locked(value: bool) -> void:
	locked = value
	if target_sprite != null and target_sprite.material is ShaderMaterial:
		(target_sprite.material as ShaderMaterial).set_shader_parameter("outline_enabled", 1.0 if locked else 0.0)


## 受击白色闪烁：所有敌人共用同一套描边 shader 的 flash_amount 参数，
## 无需每种敌人单独实现；value<=0 时主体恢复原色。
func set_flash(value: float) -> void:
	if target_sprite != null and target_sprite.material is ShaderMaterial:
		(target_sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", clampf(value, 0.0, 1.0))
