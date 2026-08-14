class_name EndingTextCanvas
extends Control

## 结局文字专用前景画布。它是背景的后置兄弟节点，避免父 Control 的 _draw()
## 被后续 TextureRect 子节点覆盖，不改动结局状态机和逐字速度。
var presentation: Control


func configure(source: Control) -> void:
	presentation = source
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if is_instance_valid(presentation) and presentation.has_method("draw_ending_content"):
		presentation.draw_ending_content(self)
