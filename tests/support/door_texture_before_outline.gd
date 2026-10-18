extends RefCounted
## Immutable pre-outline texture fixture for actual-Camera A/B captures only.
static func door_image(size: Vector3, style: String, index: int) -> Image:
	var width := maxi(4,roundi(size.x*32)); var height := maxi(4,roundi(size.y*32))
	var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	var paint := Color("778e99")
	var rim := Color("536974"); var lip := Color("91a3aa")
	var window := Rect2i(Vector2i.ZERO,Vector2i.ZERO)
	if style=="window":
		var pane := Vector2i(roundi(width*.32),roundi(height*.32))
		window=Rect2i(Vector2i((width-pane.x)/2,roundi(height*.33)-pane.y/2),pane)
	for y in height:
		for x in width:
			var edge := mini(mini(x,width-1-x),mini(y,height-1-y))
			var color := paint
			if edge==0: color=rim
			elif edge==1: color=lip
			elif edge==2: color=paint.darkened(.13)
			# Insets are measured from the actual leaf edges, not repeating texture cells.
			if style=="solid" and x>=4 and x<width-4 and y>=8 and y<height-7:
				if x==4 or x==width-5 or y==8 or y==height-8: color=paint.darkened(.16)
				elif x==5 or y==9: color=paint.lightened(.07)
			if style=="window" and window.grow(2).has_point(Vector2i(x,y)):
				if not window.grow(1).has_point(Vector2i(x,y)): color=rim
				elif not window.has_point(Vector2i(x,y)): color=lip
			# Pixel hinge plates and sparse edge wear, with no painted shadow gradient.
			var hinge_x := width-3 if index==0 else 2
			if absi(x-hinge_x)<=1 and (absi(y-height/5)<=2 or absi(y-height*4/5)<=2): color=Color("62747d")
			if x==hinge_x and (y==height/5 or y==height*4/5): color=Color("a2b2b8")
			var lock_x := 3 if index==0 else width-4
			if absi(x-lock_x)<=1 and absi(y-height*55/100)<=3: color=Color("a4b2b7")
			if x==lock_x and y==height*58/100: color=Color("52656c")
			if edge==2 and y%23 in [6,7]: color=paint.lightened(.12)
			image.set_pixel(x,y,color)
	return image
