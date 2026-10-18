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
