extends Sprite3D
## 3D 世界血条（billboard）。
##
## 这个项目里 2D 实体的视觉全部经由 depth bridge 重投影到 3D
## （EnemyRoot 的场景说明就是 "visuals are routed through depth bridges"），
## 所以挂在 2D 实体下的 Node2D 血条根本不会上屏——必须用 3D 节点。
##
## pixel_size 取 1/32：1 texel 正好对应屏幕上的 1 像素（与 2D 像素密度一致），
## 这样一张 44x6 的小图在屏幕上就是 44x6 像素。

const WIDTH := 44
const HEIGHT := 6
const BG := Color("080c12")
const FRAME := Color("c9d4de")
const FILL := Color("d24b57")
const FILL_LOW := Color("b8362f")

var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	transparent = true
	no_depth_test = false
	render_priority = 12
	pixel_size = 1.0 / 32.0
	_image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	# 先画一次空条，避免第一帧用纯白纹理闪一下。
	redraw(1.0, 1.0)


## 比例变化时重绘；同一张 ImageTexture 原地更新，不重建资源。
func redraw(current: float, maximum: float) -> void:
	if _image == null:
		return
	var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	_image.fill(BG)
	# 1px 亮框：贴在 3D 场景里也要一眼能认出这是生命值。
	for x in WIDTH:
		_image.set_pixel(x, 0, FRAME)
		_image.set_pixel(x, HEIGHT - 1, FRAME)
	for y in HEIGHT:
		_image.set_pixel(0, y, FRAME)
		_image.set_pixel(WIDTH - 1, y, FRAME)
	var inner_width := int(round(float(WIDTH - 2) * ratio))
	var colour := FILL if ratio > 0.35 else FILL_LOW
	for y in range(1, HEIGHT - 1):
		for x in range(1, 1 + inner_width):
			_image.set_pixel(x, y, colour)
	if _texture != null:
		_texture.update(_image)
