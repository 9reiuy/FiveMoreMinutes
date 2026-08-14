extends Control

## 对话框底图：使用 talk.png 裁剪出的面板主体（黑色不规则边框 + 深蓝底），
## 按九宫格拉伸适配任意面板尺寸，文本字体仍走全局像素主题（含中文回退）。
const FRAME_TEXTURE: Texture2D = preload("res://art/ui_imported/talk_panel.png")
const FRAME_MARGIN := 12

var frame_patches: Array[AtlasTexture] = []


func _ready() -> void:
	_build_patches()
	queue_redraw()


## 预切 3x3 九宫格补丁，边与角在拉伸时保持不变形。
func _build_patches() -> void:
	var source_size := FRAME_TEXTURE.get_size()
	var m := FRAME_MARGIN
	var xs := [0.0, float(m), source_size.x - m]
	var ys := [0.0, float(m), source_size.y - m]
	var ws := [float(m), source_size.x - m * 2.0, float(m)]
	var hs := [float(m), source_size.y - m * 2.0, float(m)]
	frame_patches.clear()
	for row in range(3):
		for col in range(3):
			var patch := AtlasTexture.new()
			patch.atlas = FRAME_TEXTURE
			patch.region = Rect2(xs[col], ys[row], ws[col], hs[row])
			frame_patches.append(patch)


func _draw() -> void:
	if frame_patches.is_empty():
		return
	var m := float(FRAME_MARGIN)
	var widths := [m, maxf(size.x - m * 2.0, 0.0), m]
	var heights := [m, maxf(size.y - m * 2.0, 0.0), m]
	var draw_y := 0.0
	for row in range(3):
		var draw_x := 0.0
		for col in range(3):
			if widths[col] > 0.0 and heights[row] > 0.0:
				draw_texture_rect(frame_patches[row * 3 + col], Rect2(draw_x, draw_y, widths[col], heights[row]), false)
			draw_x += widths[col]
		draw_y += heights[row]
