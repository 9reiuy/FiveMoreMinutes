extends RefCounted
static var cached_smoke: ImageTexture
## Small stepped silhouettes shared by the sample's flame, smoke and impacts.
static func polygon(canvas: CanvasItem,points: PackedVector2Array,colour: Color,outline: Color=Color("272d36"))->void:
	for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var shifted:=PackedVector2Array()
		for point in points: shifted.append(point.round()+offset)
		canvas.draw_colored_polygon(shifted,outline)
	canvas.draw_colored_polygon(points,colour)

static func puff(canvas: CanvasItem,at: Vector2,radius: float,colour: Color)->void:
	var diameter:=maxf(2,roundf(radius*2))
	canvas.draw_texture_rect(smoke_texture(),Rect2((at-Vector2.ONE*diameter*.5).round(),Vector2.ONE*diameter),false,colour)

## Experimental soft smoke. The reference build ships an untextured white square
## and turns it into mist by stacking horizontal, vertical and radial blur
## effects, so the same three passes are folded into one small texture here.
## Default style stays "pixel": nothing ships soft unless asked to.
static var smoke_style: String = "pixel"
static var cached_soft: ImageTexture
## Soft puffs ship near-white because the reference build's floor is bright; on a
## dark floor a near-white soft blob reads as light, not dust. These knobs let a
## capture compare the literal recipe against a grey, lower-peak variant.
static var soft_tint: Color = Color("e0e0d3")
static var soft_peak: float = 1.0

static func set_soft_look(tint: Color, peak: float) -> void:
	soft_tint = tint
	soft_peak = clampf(peak, 0.0, 1.0)
	cached_soft = null

## Comparison hook only: lets a capture run swap in another game's extracted puff art
## without touching any shipping configuration.
static var texture_override: ImageTexture

static func set_texture_override(texture: ImageTexture) -> void:
	texture_override = texture

static func set_smoke_style(style: String) -> void:
	smoke_style = style

static func active_smoke_texture() -> ImageTexture:
	if texture_override != null: return texture_override
	return soft_smoke_texture() if smoke_style == "soft" else smoke_texture()

static func soft_smoke_texture() -> ImageTexture:
	if cached_soft != null: return cached_soft
	var width := 32
	var height := 32
	var square := 9
	var energy := PackedFloat32Array()
	energy.resize(width * height)
	var offset := (width - square) / 2
	for y in range(offset, offset + square):
		for x in range(offset, offset + square): energy[y * width + x] = 1.0
	energy = _line_blur(energy, width, height, 3, false)
	energy = _line_blur(energy, width, height, 3, true)
	energy = _radial_blur(energy, width, height, .18)
	var peak := 0.0
	for value in energy: peak = maxf(peak, value)
	if peak <= 0.0: peak = 1.0
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var tint := soft_tint
	for y in height:
		for x in width:
			var level := clampf(energy[y * width + x] / peak * 1.45, 0.0, 1.0)
			level = level * level * (3.0 - 2.0 * level) * soft_peak
			# Same palette as the pixel puff, but no outline: the falloff is the shape.
			image.set_pixelv(Vector2i(x, y), Color(tint.r, tint.g, tint.b, level))
	cached_soft = ImageTexture.create_from_image(image)
	return cached_soft

static func _line_blur(source: PackedFloat32Array, width: int, height: int, radius: int, vertical: bool) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(source.size())
	var span := radius * 2 + 1
	for y in height:
		for x in width:
			var total := 0.0
			for step in range(-radius, radius + 1):
				var sx: int = x if vertical else clampi(x + step, 0, width - 1)
				var sy: int = clampi(y + step, 0, height - 1) if vertical else y
				total += source[sy * width + sx]
			result[y * width + x] = total / float(span)
	return result

static func _radial_blur(source: PackedFloat32Array, width: int, height: int, reach: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(source.size())
	var centre := Vector2(width, height) * .5
	var taps := PackedFloat32Array([.35, .7, 1.0])
	for y in height:
		for x in width:
			var here := Vector2(x + .5, y + .5)
			var total := source[y * width + x]
			var count := 1.0
			for factor in taps:
				var sample := centre + (here - centre) * (1.0 + reach * factor)
				var sx := clampi(int(sample.x), 0, width - 1)
				var sy := clampi(int(sample.y), 0, height - 1)
				total += source[sy * width + sx]
				count += 1.0
			result[y * width + x] = total / count
	return result

static func smoke_texture()->ImageTexture:
	if cached_smoke!=null: return cached_smoke
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	var solid: Dictionary={}
	for rect in [Rect2i(6,2,5,8),Rect2i(3,5,9,7),Rect2i(2,8,12,5),Rect2i(5,11,7,3)]:
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): solid[Vector2i(x,y)]=true
	for point: Vector2i in solid:
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not solid.has(point+offset): image.set_pixelv(point+offset,Color("343c46"))
	for point: Vector2i in solid: image.set_pixelv(point,Color("c6c6bb") if point.y>9 else Color("e0e0d3"))
	cached_smoke=ImageTexture.create_from_image(image)
	return cached_smoke
