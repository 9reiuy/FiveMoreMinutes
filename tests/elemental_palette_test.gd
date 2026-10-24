extends SceneTree
var output:="res://.runtime/burning_integration_20261023"
func _initialize() -> void:call_deferred("run")
func draw() -> Image:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var lab=load("res://scenes/dream/preview/ElementalParticlesSample.tscn").instantiate()
	root.add_child(lab);lab.set_process(false);lab.effects.set_process(false)
	lab.effects.clear();lab.effects.emit_fire(Vector3(-3,.12,0))
	for i in 120:lab.effects.step(1.0/60.0)
	lab.effects.explode(Vector3(0,.3,0),1.65)
	lab.effects.step(.10)
	var before:=await draw()
	before.save_png(output+"/native_fire.png")
	var layer:=CanvasLayer.new();layer.name="WorldPaletteLayer";layer.layer=18;root.add_child(layer)
	var rect:=ColorRect.new();rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material:=ShaderMaterial.new();material.shader=load("res://shaders/palette_quantize.gdshader");rect.material=material
	lab.effects.preserve_flame_colors=true;lab.effects._upload()
	var max_error:=0
	var warm_pixels:=0
	for enabled in [false,true]:
		material.set_shader_parameter("palette_enabled",enabled)
		var after:=await draw()
		after.save_png(output+("/palette_on.png" if enabled else "/palette_off.png"))
		for y in before.get_height():
			for x in before.get_width():
				var original:=before.get_pixel(x,y)
				if original.r<.7 or original.g<.15 or original.b>.75 or original.r-original.b<.2:continue
				warm_pixels+=1
				var current:=after.get_pixel(x,y)
				max_error=maxi(max_error,roundi(maxf(absf(original.r-current.r),maxf(absf(original.g-current.g),absf(original.b-current.b)))*255.0))
	print("FIRE_PALETTE warm_pixels=",warm_pixels," max_channel_error=",max_error)
	lab.free();layer.free()
	quit(0 if warm_pixels>20 and max_error<=2 else 1)
