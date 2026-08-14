shader_type canvas_item;
render_mode unshaded;

// 世界坐标里的UI式反馈保持清晰，不受梦境CanvasModulate压暗。
void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
