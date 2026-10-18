extends SceneTree
const PIXEL=preload("res://scripts/ui/pixel_transition.gd")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value: failures+=1; push_error(label)
func frames(count:int)->void:
	for i in count: await RenderingServer.frame_post_draw
func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	var view:=SubViewport.new(); view.size=Vector2i(640,360); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var background:=ColorRect.new(); background.size=Vector2(640,360); background.color=Color.WHITE; view.add_child(background)
	var mask:=ColorRect.new(); mask.size=background.size; mask.material=PIXEL.material(); view.add_child(mask)
	var previous:=-1
	for amount in [0.0,.25,.5,.75,1.0]:
		mask.material.set_shader_parameter("progress",amount); await frames(2)
		var pixels: Image=view.get_texture().get_image(); pixels.convert(Image.FORMAT_RGBA8)
		var count:=0; var block_ok:=true; var binary:=true
		for y in 360:
			for x in 640:
				var c:=pixels.get_pixel(x,y)
				var black:=c.r<.001 and c.g<.001 and c.b<.001
				count+=1 if black else 0
				binary=binary and (black or (c.r>.999 and c.g>.999 and c.b>.999))
				block_ok=block_ok and c==pixels.get_pixel((x/4)*4,(y/4)*4)
		check(binary and block_ok,"Mask is unshaded binary 4x4 logical pixels with no bright edge")
		check(count>=previous,"Coverage increases monotonically")
		if amount==0: check(count==0,"Zero coverage leaves the scene fully visible")
		if amount==1: check(count==640*360,"Work endpoint is completely opaque black")
		if amount==.5:
			check(pixels.get_pixel(320,180).r>.999,"Center opening remains visible halfway through closure")
		if amount==.75:
			var sides_black:=true
			for point in [Vector2i(4,180),Vector2i(636,180),Vector2i(320,4),Vector2i(320,356)]:
				sides_black=sides_black and pixels.get_pixelv(point).r<.001
			check(sides_black,"All four sides close toward the center")
			var horizontal:=0; var vertical:=0
			for x in 640:
				if pixels.get_pixel(x,180).r>.999: horizontal+=1
			for y in 360:
				if pixels.get_pixel(320,y).r>.999: vertical+=1
			check(absi(horizontal-vertical)<=4 and horizontal>100,"Circular opening has equal pixel diameter on both axes")
			check(pixels.get_pixel(400,180).r>.999 and pixels.get_pixel(392,252).r<.001,"Iris has a circular boundary rather than square corners")
		previous=count
	view.free(); print("PIXEL_TRANSITION_GPU checks=",checks," failures=",failures)
	quit(1 if failures else 0)
