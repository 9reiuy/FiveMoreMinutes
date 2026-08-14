class_name HallwayView
extends Node2D

## 卧室阶段内的走廊子视图。它只负责走廊门的透明像素悬停/点击；
## 对话、当晚时间与持久状态继续由 Bedroom 管理，避免建立重复系统。

signal door_clicked
signal return_requested

@export var config: DemoConfig

@onready var art_root: Node2D = $ArtRoot
@onready var door_sprite: Sprite2D = $ArtRoot/Door
@onready var bottom_edge_interaction: BedroomDoorInteraction = $BottomEdgeInteraction

var door_image: Image
var door_outline_material: ShaderMaterial
var door_hovered := false
var bottom_edge_hovered := false
var interaction_enabled := true


func _ready() -> void:
	door_image = door_sprite.texture.get_image()
	door_outline_material = door_sprite.material as ShaderMaterial
	var outline_color := config.bedroom_interaction_outline_color
	outline_color.a = config.bedroom_interaction_outline_opacity
	door_outline_material.set_shader_parameter("outline_color", outline_color)
	# 配置值以屏幕像素为单位；门和卧室美术同为 0.25 倍统一缩放。
	var source_width := config.bedroom_interaction_outline_width / maxf(absf(art_root.scale.x), 0.001)
	door_outline_material.set_shader_parameter("outline_width_source_pixels", source_width)
	_set_door_hovered(false)


func open() -> void:
	visible = true
	set_interaction_enabled(true)
	_update_interaction_hover()


func close() -> void:
	set_interaction_enabled(false)
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_update_interaction_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 底部光条与 Door 的透明区域少量重叠时，返回光条拥有明确优先级。
		if bottom_edge_hovered:
			return_requested.emit()
		elif door_hovered:
			door_clicked.emit()
		else:
			return
		get_viewport().set_input_as_handled()


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	if not interaction_enabled:
		bottom_edge_hovered = false
		_set_door_hovered(false)
	bottom_edge_interaction.set_state(interaction_enabled, bottom_edge_hovered, false)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if bottom_edge_hovered or door_hovered else Input.CURSOR_ARROW)


func _update_interaction_hover() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	bottom_edge_hovered = interaction_enabled and bottom_edge_interaction.get_interaction_rect().has_point(mouse_position)
	_set_door_hovered(interaction_enabled and not bottom_edge_hovered and _is_opaque_door_pixel(mouse_position))
	bottom_edge_interaction.set_state(interaction_enabled, bottom_edge_hovered, false)


func _set_door_hovered(value: bool) -> void:
	if door_hovered == value:
		return
	door_hovered = value
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if door_hovered or bottom_edge_hovered else Input.CURSOR_ARROW)
	if door_outline_material != null:
		door_outline_material.set_shader_parameter("outline_enabled", 1.0 if door_hovered else 0.0)


func _is_opaque_door_pixel(viewport_position: Vector2) -> bool:
	if door_image == null or door_image.is_empty():
		return false
	var texture_position := door_sprite.to_local(viewport_position)
	var pixel := Vector2i(floori(texture_position.x), floori(texture_position.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= door_image.get_width() or pixel.y >= door_image.get_height():
		return false
	return door_image.get_pixelv(pixel).a > 0.1
