class_name EnemyOutlineController
extends Node

const OUTLINE_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")
const CONFIG := preload("res://resources/demo_config.tres")

var target_sprites: Array[CanvasItem] = []
var locked := false
enum OutlineState { NONE, WHITE, GRAY }
var outline_state := OutlineState.NONE
var _last_applied_outline_state := -1
var _last_flash_amount := -1.0


func configure(sprite: AnimatedSprite2D) -> void:
	configure_many([sprite] if sprite != null else [])


func configure_many(sprites: Array[CanvasItem]) -> void:
	target_sprites.clear()
	_last_applied_outline_state = OutlineState.NONE
	_last_flash_amount = 0.0
	for sprite in sprites:
		if sprite == null:
			continue
		target_sprites.append(sprite)
	# Every enemy receives an independent material so lock changes never leak to peers.
	for sprite in target_sprites:
		var outline_material := ShaderMaterial.new()
		outline_material.shader = OUTLINE_SHADER
		outline_material.set_shader_parameter("outline_enabled", 0.0)
		# 统一白描边宽度（源纹理像素空间）：shader 基于 TEXTURE_PIXEL_SIZE 换算。
		outline_material.set_shader_parameter("outline_width_source_pixels", CONFIG.enemy_outline_width_px)
		outline_material.set_shader_parameter("outline_color", Color.WHITE)
		outline_material.set_shader_parameter("flash_amount", 0.0)
		sprite.material = outline_material


func set_locked(value: bool) -> void:
	set_outline_state(OutlineState.WHITE if value else OutlineState.NONE)


func set_outline_state(state: int) -> void:
	outline_state = clampi(state, OutlineState.NONE, OutlineState.GRAY)
	locked = outline_state != OutlineState.NONE
	if outline_state == _last_applied_outline_state:
		return
	_last_applied_outline_state = outline_state
	var color := Color.WHITE if outline_state == OutlineState.WHITE else Color(0.55, 0.58, 0.62, 1.0)
	for sprite in target_sprites:
		if sprite != null and sprite.material is ShaderMaterial:
			var material := sprite.material as ShaderMaterial
			material.set_shader_parameter("outline_enabled", 1.0 if locked else 0.0)
			material.set_shader_parameter("outline_color", color)


## 受击白色闪烁：所有敌人共用同一套描边 shader 的 flash_amount 参数，
## 无需每种敌人单独实现；value<=0 时主体恢复原色。
func set_flash(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _last_flash_amount):
		return
	_last_flash_amount = clamped
	for sprite in target_sprites:
		if sprite != null and sprite.material is ShaderMaterial:
			(sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", clamped)
