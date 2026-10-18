extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color=Color(0.05,0.06,0.08)
	bg.size=Vector2(640,360)
	canvas.add_child(bg)
	for mode in 4:
		var font = load("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf").duplicate()
		font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.keep_rounding_remainders=false
		font.oversampling=1.0 if mode==1 else 0.0
		if mode==2: font=load("res://assets/fonts/boutique_bitmap/BoutiqueBitmap7x7_1.7.ttf").duplicate()
		if mode==3: font=load("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf").duplicate()
		for j in 5:
			var sz=[10,12,14,16,20][j]
			var label := Label.new()
			label.text="%d/%d 拾取 替换\n进入 交谈测试" % [mode,sz]
			label.position=Vector2(8+mode*158,10+j*65)
			label.add_theme_font_override("font",font)
			label.add_theme_font_size_override("font_size",sz)
			label.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			canvas.add_child(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/font_raster_probe.png")
	canvas.queue_free()
	await process_frame
	quit()
