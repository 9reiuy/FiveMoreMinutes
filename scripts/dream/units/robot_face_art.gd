extends RefCounted
## Pixel LCD faces for the hotel delivery robot.  Draws on a 28x18 logical grid
## and bakes it into a dot-matrix texture: every logical pixel is a 4x4 block
## with a 1 texel gap, so the panel reads as an LCD instead of a flat image.

const COLS := 28
const ROWS := 18
const CELL := 4
const GAP := 1
const LIT := Color(0.58, 0.93, 1.0)
const DIM := Color(0.10, 0.30, 0.36)
const OFF := Color(0.015, 0.035, 0.055)

const EXPRESSIONS := ["calm", "surprised", "angry", "confused"]


static func texture_for(expression: String) -> ImageTexture:
	var grid := _blank()
	match expression:
		"surprised":
			_draw_surprised(grid)
		"angry":
			_draw_angry(grid)
		"confused":
			_draw_confused(grid)
		_:
			_draw_calm(grid)
	return _bake(grid)


static func _blank() -> Array:
	var grid: Array = []
	for _y in ROWS:
		var row: Array = []
		for _x in COLS:
			row.append(0)
		grid.append(row)
	return grid


static func _put(grid: Array, x: int, y: int, value := 1) -> void:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return
	grid[y][x] = value


static func _rect(grid: Array, x: int, y: int, w: int, h: int, value := 1) -> void:
	for yy in h:
		for xx in w:
			_put(grid, x + xx, y + yy, value)


static func _line(grid: Array, x0: int, y0: int, x1: int, y1: int, value := 1) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	if steps == 0:
		_put(grid, x0, y0, value)
		return
	for step in steps + 1:
		var t := float(step) / float(steps)
		_put(grid, roundi(lerpf(float(x0), float(x1), t)), roundi(lerpf(float(y0), float(y1), t)), value)


static func _ring(grid: Array, x: int, y: int, w: int, h: int) -> void:
	for yy in h:
		for xx in w:
			var edge := xx == 0 or yy == 0 or xx == w - 1 or yy == h - 1
			if edge:
				_put(grid, x + xx, y + yy)


# --- Expressions -----------------------------------------------------------

static func _draw_calm(grid: Array) -> void:
	# Relaxed lids: short dashes, gently curved mouth.
	_rect(grid, 5, 7, 4, 1)
	_rect(grid, 19, 7, 4, 1)
	_put(grid, 10, 12)
	_put(grid, 11, 13)
	_put(grid, 12, 13)
	_put(grid, 13, 13)
	_put(grid, 14, 13)
	_put(grid, 15, 13)
	_put(grid, 16, 12)


static func _draw_surprised(grid: Array) -> void:
	# Wide open eyes and a round gasp.
	_ring(grid, 4, 5, 5, 5)
	_ring(grid, 19, 5, 5, 5)
	_ring(grid, 11, 11, 6, 5)
	_put(grid, 22, 2)
	_put(grid, 23, 3)


static func _draw_angry(grid: Array) -> void:
	# Slanted brows pressing down on small hot eyes, gritted zigzag mouth.
	_line(grid, 3, 5, 8, 8)
	_line(grid, 24, 5, 19, 8)
	_rect(grid, 5, 9, 3, 2)
	_rect(grid, 20, 9, 3, 2)
	_line(grid, 10, 14, 11, 13)
	_line(grid, 11, 13, 12, 14)
	_line(grid, 12, 14, 13, 13)
	_line(grid, 13, 13, 14, 14)
	_line(grid, 14, 14, 15, 13)
	_line(grid, 15, 13, 16, 14)
	_line(grid, 16, 14, 17, 13)


static func _draw_confused(grid: Array) -> void:
	# One flat lid, one blinking dot, wavy mouth, floating question mark.
	_rect(grid, 4, 7, 4, 1)
	_rect(grid, 20, 8, 2, 2)
	_line(grid, 10, 13, 12, 12)
	_line(grid, 12, 12, 14, 14)
	_line(grid, 14, 14, 16, 13)
	_rect(grid, 22, 2, 1, 4)
	_rect(grid, 23, 2, 2, 1)
	_rect(grid, 24, 3, 1, 1)
	_put(grid, 22, 7)


# --- Baking ----------------------------------------------------------------

static func _bake(grid: Array) -> ImageTexture:
	var width := COLS * CELL + (COLS - 1) * GAP
	var height := ROWS * CELL + (ROWS - 1) * GAP
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(OFF)
	for gy in ROWS:
		for gx in COLS:
			var value: int = grid[gy][gx]
			if value == 0:
				continue
			var colour := LIT
			if value == 2:
				colour = DIM
			var x0 := gx * (CELL + GAP)
			var y0 := gy * (CELL + GAP)
			for y in CELL:
				for x in CELL:
					image.set_pixel(x0 + x, y0 + y, colour)
	return ImageTexture.create_from_image(image)
