extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	var view:=SubViewport.new(); view.size=Vector2i(320,64); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var colors: Array[Color]=[Color("d96b18"),Color("ff9a2e"),Color(1,0,0),Color(1,0,1),Color(1,0,.02),Color(1,0,.20),Color(1,0,.52)]
	for i in colors.size():
		var rect:=ColorRect.new(); rect.position=Vector2(i*40,0); rect.size=Vector2(40,64); rect.color=colors[i]; view.add_child(rect)
	var layer:=CanvasLayer.new(); layer.layer=18; view.add_child(layer)
	var output:=ColorRect.new(); output.size=Vector2(320,64); layer.add_child(output)
	var material:=ShaderMaterial.new(); material.shader=load("res://shaders/palette_quantize.gdshader"); output.material=material
	var failures:=0
	for scheme in [1,2]:
		material.set_shader_parameter("palette_scheme",scheme)
		material.set_shader_parameter("tonal_sample",false)
		await process_frame; await RenderingServer.frame_post_draw
		var before:=view.get_texture().get_image()
		material.set_shader_parameter("tonal_sample",true)
		await process_frame; await RenderingServer.frame_post_draw
		var after:=view.get_texture().get_image()
		for i in colors.size():
			if before.get_pixel(i*40+20,32)!=after.get_pixel(i*40+20,32): failures+=1
	print("TONAL_SEMANTIC checks=14 failures=",failures)
	view.queue_free(); await process_frame; quit(failures)
