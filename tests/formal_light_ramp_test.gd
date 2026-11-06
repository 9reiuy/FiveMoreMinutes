extends SceneTree
## Render the real post shader: smooth illumination and unchanged gameplay colors.
const OUT := "res://.runtime/lighting_revision_20261103/ramp_test"
var checks := 0
var failures: Array[String] = []
var measures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func shot(view: SubViewport) -> Image:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func max_step(im: Image) -> float:
	var result := 0.0
	for x in range(1,256):
		var a:=im.get_pixel(x-1,16); var b:=im.get_pixel(x,16)
		result=maxf(result,absf((a.r-b.r)*.2126+(a.g-b.g)*.7152+(a.b-b.b)*.0722))
	return result
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(60.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	var view:=SubViewport.new(); view.size=Vector2i(480,64); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var gradient:=ColorRect.new(); gradient.size=Vector2(256,32); view.add_child(gradient)
	var gradient_material:=ShaderMaterial.new(); var gradient_shader:=Shader.new()
	gradient_shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(vec3(mix(0.015,0.55,UV.x)),1.0); }"
	gradient_material.shader=gradient_shader; gradient.material=gradient_material
	var colors: Array[Color]=[Color("d96b18"),Color("ff9a2e"),Color(1,0,0),Color(1,0,1),Color(1,0,.02),Color(1,0,.20),Color(1,0,.52),Color(.25,.24,.58),Color("3536d7"),Color(.48,.20,.27),Color(.59,.34,.55)]
	for i in colors.size():
		var rect:=ColorRect.new(); rect.position=Vector2(i*40,32); rect.size=Vector2(40,32); rect.color=colors[i]; view.add_child(rect)
	var layer:=CanvasLayer.new(); layer.layer=18; view.add_child(layer)
	var output:=ColorRect.new(); output.size=Vector2(480,64); layer.add_child(output)
	var mat:=ShaderMaterial.new(); mat.shader=load("res://shaders/palette_quantize.gdshader"); output.material=mat
	for scheme in [1,2]:
		for tonal in [false,true]:
			mat.set_shader_parameter("palette_scheme",scheme); mat.set_shader_parameter("tonal_sample",tonal)
			mat.set_shader_parameter("smooth_light_ramp",false); var before:=await shot(view)
			mat.set_shader_parameter("smooth_light_ramp",true); var after:=await shot(view)
			var label:="scheme%d_tonal%d" % [scheme,int(tonal)]
			before.save_png(OUT+"/"+label+"_before.png"); after.save_png(OUT+"/"+label+"_after.png")
			var old_step:=max_step(before); var new_step:=max_step(after)
			check(new_step<old_step*.1,label+" reduces light-ramp jumps by over 90 percent")
			for i in 7: check(before.get_pixel(i*40+20,48)==after.get_pixel(i*40+20,48),label+" preserves semantic color "+str(i))
			if scheme==2:
				for i in range(7,colors.size()):
					# Compare to the authored accent: the old ordered dither could
					# replace this very pixel with a neighboring ramp entry.
					var a: Color=colors[i]; var b:=after.get_pixel(i*40+20,48)
					check(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))<=1.01/255.,label+" preserves reference hue "+str(i))
			var repeat:=await shot(view)
			check(after.get_data()==repeat.get_data(),label+" remains stable without temporal noise")
			measures.append({"label":label,"old_max_step":old_step,"new_max_step":new_step})
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measures":measures},"\t"))
	view.queue_free(); await process_frame
	print("FORMAL_LIGHT_RAMP checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
