class_name OfficePixelAtlasArt
extends RefCounted

## The open-office sample's deliberately authored, grid-aligned surface art.
## Each 32x32 panel is placed by hand below. No noise, color quantizer, or
## screenshot-derived pixels are used. The image is exported as a PNG by the
## dedicated build tool; gameplay only loads that PNG.
const TILE := 32
const COLUMNS := 8
const ROWS := 4

const INK := Color("171c25")
const EDGE := Color("303c49")
const STEEL := Color("6b7b82")
const STEEL_LIGHT := Color("a4adb0")
const PAPER := Color("d5d3bd")
const DESK := Color("a8987d")
const DESK_LIGHT := Color("c6b697")
const BLUE := Color("51677d")
const BLUE_LIGHT := Color("8196a6")

static func build() -> Image:
	var image := Image.create(COLUMNS * TILE, ROWS * TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_carpet(image, 0, 0)
	_wall(image, 1, 0)
	_door(image, 2, 0)
	_desk_top(image, 3, 0)
	_desk_side(image, 4, 0)
	_chair_top(image, 5, 0)
	_cabinet_top(image, 6, 0)
	_monitor(image, 7, 0)
	for direction in 8:
		_desk_front(image, direction, 1, direction)
		_chair_front(image, direction, 2, direction)
		_cabinet_front(image, direction, 3, direction)
	return image

static func _block(image: Image, col: int, row: int, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(col * TILE + x, row * TILE + y, w, h), color)

static func _carpet(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, Color("4b5968"))
	_block(image, col, row, 0, 0, 32, 1, Color("607081"))
	_block(image, col, row, 0, 0, 1, 32, Color("35414e"))
	_block(image, col, row, 4, 7, 5, 2, Color("536373"))
	_block(image, col, row, 19, 17, 6, 2, Color("43515f"))
	_block(image, col, row, 10, 25, 4, 2, Color("536373"))

static func _wall(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, Color("929b9b"))
	_block(image, col, row, 0, 0, 32, 2, Color("c2c5bd"))
	_block(image, col, row, 0, 3, 32, 1, Color("748181"))
	_block(image, col, row, 30, 4, 2, 23, Color("7a8685"))
	_block(image, col, row, 0, 24, 32, 2, Color("495662"))
	_block(image, col, row, 0, 26, 32, 6, Color("303b47"))
	_block(image, col, row, 0, 27, 32, 1, Color("718086"))
	_block(image, col, row, 15, 4, 1, 20, Color("85908e"))

static func _door(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, INK)
	_block(image, col, row, 2, 1, 28, 31, Color("414f5b"))
	_block(image, col, row, 4, 2, 24, 28, Color("68737b"))
	_block(image, col, row, 6, 4, 20, 22, Color("53616d"))
	_block(image, col, row, 4, 2, 2, 28, Color("a4aca8"))
	_block(image, col, row, 24, 4, 2, 22, Color("303c49"))
	_block(image, col, row, 19, 16, 5, 2, PAPER)
	_block(image, col, row, 18, 17, 2, 5, STEEL_LIGHT)

static func _desk_top(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, EDGE)
	_block(image, col, row, 2, 2, 28, 27, DESK)
	_block(image, col, row, 3, 3, 25, 2, DESK_LIGHT)
	_block(image, col, row, 2, 28, 28, 2, Color("6d604f"))
	# Keyboard and its individual block keys.
	_block(image, col, row, 6, 20, 16, 7, INK)
	_block(image, col, row, 7, 21, 14, 4, STEEL)
	for key_x in [8, 11, 14, 17]:
		_block(image, col, row, key_x, 22, 2, 1, STEEL_LIGHT)
	_block(image, col, row, 16, 24, 4, 1, INK)
	# Paper, binder clip and coffee mug are composed as fixed pixel clusters.
	_block(image, col, row, 3, 7, 9, 10, PAPER)
	_block(image, col, row, 4, 9, 6, 1, STEEL)
	_block(image, col, row, 4, 12, 5, 1, STEEL)
	_block(image, col, row, 4, 7, 3, 1, EDGE)
	_block(image, col, row, 24, 9, 5, 5, INK)
	_block(image, col, row, 25, 10, 3, 3, Color("d1d1c6"))
	_block(image, col, row, 26, 10, 2, 2, Color("47382f"))

static func _desk_side(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, Color("685d50"))
	_block(image, col, row, 0, 0, 32, 4, DESK_LIGHT)
	_block(image, col, row, 0, 4, 32, 3, DESK)
	_block(image, col, row, 3, 9, 23, 18, Color("82735e"))
	_block(image, col, row, 25, 9, 2, 18, EDGE)
	for drawer_y in [12, 19]:
		_block(image, col, row, 5, drawer_y, 18, 1, INK)
		_block(image, col, row, 12, drawer_y + 2, 5, 2, STEEL_LIGHT)
	_block(image, col, row, 2, 28, 3, 4, EDGE)
	_block(image, col, row, 27, 28, 3, 4, EDGE)

static func _chair_top(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, INK)
	_block(image, col, row, 4, 2, 24, 28, EDGE)
	_block(image, col, row, 6, 4, 20, 23, BLUE)
	_block(image, col, row, 7, 5, 17, 3, BLUE_LIGHT)
	_block(image, col, row, 8, 22, 15, 3, Color("40576d"))
	_block(image, col, row, 5, 10, 2, 11, STEEL)
	_block(image, col, row, 25, 10, 2, 11, STEEL)

static func _cabinet_top(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, EDGE)
	_block(image, col, row, 2, 2, 27, 27, STEEL)
	_block(image, col, row, 3, 3, 24, 3, STEEL_LIGHT)
	_block(image, col, row, 25, 4, 3, 24, Color("4c5b66"))

static func _monitor(image: Image, col: int, row: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, INK)
	_block(image, col, row, 2, 2, 28, 27, Color("b9b8a8"))
	_block(image, col, row, 4, 4, 24, 19, EDGE)
	_block(image, col, row, 6, 6, 20, 15, Color("263944"))
	_block(image, col, row, 7, 7, 13, 2, Color("4b6571"))
	_block(image, col, row, 5, 26, 18, 1, Color("817f76"))
	_block(image, col, row, 25, 25, 2, 2, Color("b49f67"))

static func _desk_front(image: Image, col: int, row: int, direction: int) -> void:
	_desk_side(image, col, row)
	var left_light := direction in [0, 1, 7]
	var edge_x := 1 if left_light else 29
	_block(image, col, row, edge_x, 7, 2, 20, DESK_LIGHT if left_light else EDGE)
	_block(image, col, row, 5, 26, 23, 1, Color("524b43"))

static func _chair_front(image: Image, col: int, row: int, direction: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, Color("323c47"))
	_block(image, col, row, 4, 2, 24, 24, INK)
	_block(image, col, row, 6, 4, 20, 19, BLUE)
	_block(image, col, row, 7 if direction < 4 else 18, 5, 7, 2, BLUE_LIGHT)
	_block(image, col, row, 5, 23, 22, 5, Color("40556b"))
	_block(image, col, row, 2, 17, 3, 10, STEEL)
	_block(image, col, row, 27, 17, 3, 10, STEEL)
	_block(image, col, row, 15, 27, 2, 5, INK)

static func _cabinet_front(image: Image, col: int, row: int, direction: int) -> void:
	_block(image, col, row, 0, 0, 32, 32, INK)
	_block(image, col, row, 2, 1, 28, 30, STEEL)
	_block(image, col, row, 3 if direction < 4 else 27, 2, 2, 27, STEEL_LIGHT)
	for drawer_y in [3, 12, 21]:
		_block(image, col, row, 5, drawer_y, 22, 8, Color("4f5d67"))
		_block(image, col, row, 6, drawer_y + 1, 19, 5, Color("809096"))
		_block(image, col, row, 12, drawer_y + 2, 8, 2, PAPER)
		_block(image, col, row, 13, drawer_y + 6, 6, 1, INK)
