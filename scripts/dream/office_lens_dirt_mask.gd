extends RefCounted
## One camera-fixed map, generated once from a seed. Fixtures reveal it as they move across the frame.
const SIZE := Vector2i(320, 180)
const SEED := 0x4c454e53
const DROP_EVERY_NTH_MARK := 5
static var _texture: ImageTexture

static func texture() -> ImageTexture:
	if _texture == null:
		_texture = _make_texture()
	return _texture


static func _make_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var patina := _noise(SEED, 0.027)
	var fine := _noise(SEED + 79, 0.087)
	var mask := PackedFloat32Array()
	mask.resize(SIZE.x * SIZE.y)
	for y in SIZE.y:
		for x in SIZE.x:
			var broad := patina.get_noise_2d(float(x) * 0.79, float(y) * 1.31)
			var detail := fine.get_noise_2d(float(x), float(y))
			mask[y * SIZE.x + x] = 0.042 + 0.039 * smoothstep(-0.51, 0.56, broad) + detail * 0.022
	# Sample every mark so the seeded locations of the remaining marks stay the same.
	for index in 35:
		var center := Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		var size := Vector2(rng.randf_range(2.3, 9.0), rng.randf_range(1.4, 5.8))
		var turn := rng.randf_range(-PI, PI)
		var amount := rng.randf_range(0.035, 0.125)
		if (index + 1) % DROP_EVERY_NTH_MARK == 0:
			continue
		_mark(mask, fine, center, size, turn, amount)
		var broken_edge := Vector2(size.x * 0.60, size.y * -0.35).rotated(turn)
		_mark(mask, fine, center + broken_edge, size * Vector2(0.55, 0.69), turn + 0.46, amount * 0.45)
	for index in 20:
		var center := Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		var size := Vector2(rng.randf_range(9.0, 39.0), rng.randf_range(0.78, 3.2))
		var turn := rng.randf_range(-0.76, 0.14)
		var amount := rng.randf_range(0.055, 0.19)
		if (index + 1) % DROP_EVERY_NTH_MARK == 0:
			continue
		_mark(mask, fine, center, size, turn, amount)
		_mark(mask, fine, center + Vector2(0.0, 2.6).rotated(turn), size * Vector2(0.59, 0.74), turn + 0.07, amount * 0.44)
	for index in 325:
		var center := Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		var radius := rng.randf_range(0.56, 1.34)
		var size := Vector2(radius, radius * rng.randf_range(0.48, 0.95))
		var turn := rng.randf_range(-PI, PI)
		var amount := rng.randf_range(0.056, 0.21)
		if (index + 1) % DROP_EVERY_NTH_MARK == 0:
			continue
		_mark(mask, fine, center, size, turn, amount)
	var bytes := PackedByteArray()
	bytes.resize(SIZE.x * SIZE.y * 3)
	for index in mask.size():
		var value := roundi(clampf(mask[index], 0.0, 0.87) * 255.0)
		for channel in 3:
			bytes[index * 3 + channel] = value
	return ImageTexture.create_from_image(Image.create_from_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8, bytes))

static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	return noise

static func _mark(mask: PackedFloat32Array, noise: FastNoiseLite, center: Vector2,
	radii: Vector2, turn: float, amount: float) -> void:
	var extent := Vector2.ONE * (radii.length() * 1.16 + 2.0)
	var first := Vector2i((center - extent).floor()).max(Vector2i.ZERO)
	var last := Vector2i((center + extent).ceil()).min(SIZE)
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var pixel := Vector2(x + 0.5, y + 0.5)
			var offset := (pixel - center).rotated(-turn) / radii
			var irregularity := noise.get_noise_2d(pixel.x, pixel.y) * 0.32
			var edge := 1.0 - smoothstep(0.06, 1.0, offset.length() + irregularity)
			mask[y * SIZE.x + x] += amount * edge * edge
