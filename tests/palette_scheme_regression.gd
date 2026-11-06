extends SceneTree
## Real post-shader color ramps. Also run the prior shader to prove the shaded
## accent regression is detected; no scene movement or screenshot timing noise.
var output:="res://.runtime/palette_switch_20261103/colors"
var shader_path:="res://shaders/palette_quantize.gdshader"
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func snap(view:SubViewport)->Image:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func max_channel(a:Color,b:Color)->float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--shader="):shader_path=arg.trim_prefix("--shader=")
	if DisplayServer.get_name()=="headless":quit(2);return
	create_timer(40,true,false,true).timeout.connect(func():quit(9))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(640,360));DisplayServer.window_set_position(Vector2i(-30000,-30000))
	Engine.max_fps=120
	DirAccess.make_dir_recursive_absolute(output)
	var view:=SubViewport.new();view.size=Vector2i(512,224);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var hues:Array[Color]=[Color.WHITE,Color(.25,.24,.58),Color(.2078431,.2117647,.8431373),Color(.48,.20,.27),Color(.59,.34,.55)]
	for i in hues.size():
		var rect:=ColorRect.new();rect.position=Vector2(0,i*32);rect.size=Vector2(512,32);view.add_child(rect)
		var source:=ShaderMaterial.new();var ramp:=Shader.new()
		ramp.code="shader_type canvas_item; render_mode unshaded; uniform vec4 hue; void fragment(){COLOR=vec4(hue.rgb*mix(.1,1.,min(floor(UV.x*512.)/480.,1.)),1.);}"
		source.shader=ramp;source.set_shader_parameter("hue",hues[i]);rect.material=source
	var markers:Array[Color]=[Color("d96b18"),Color("ff9a2e"),Color(1,0,0),Color(1,0,1),Color(1,0,.02),Color(1,0,.06),Color(1,0,.20),Color(1,0,.36),Color(1,0,.52),Color(1,0,.60)]
	for i in markers.size():
		var rect:=ColorRect.new();rect.position=Vector2(i*48,160);rect.size=Vector2(48,64);rect.color=markers[i];view.add_child(rect)
	var layer:=CanvasLayer.new();layer.layer=18;view.add_child(layer)
	var overlay:=ColorRect.new();overlay.size=view.size;layer.add_child(overlay)
	var mat:=ShaderMaterial.new();mat.shader=load(shader_path);overlay.material=mat
	mat.set_shader_parameter("smooth_light_ramp",true);mat.set_shader_parameter("tonal_sample",true)
	mat.set_shader_parameter("palette_scheme",1);var one:=await snap(view);one.save_png(output.path_join("scheme1.png"))
	mat.set_shader_parameter("palette_scheme",2);var two:=await snap(view);two.save_png(output.path_join("scheme2.png"))
	for row in range(1,5):
		for x in [56,120,240]:
			# The original muted violet nearly overlaps the blue base ramp in
			# deep shade. Do not invent extra saturation merely to pass a test.
			var threshold:=(.5 if row==1 else 6.)/255.
			check(max_channel(one.get_pixel(x,row*32+16),two.get_pixel(x,row*32+16))>threshold,"shaded accent %d at exposure x=%d remains distinct"%[row,x])
		check(max_channel(two.get_pixel(500,row*32+16),hues[row])<=1.01/255.,"authored reference hue %d preserved"%row)
		var worst:=0.
		var nonmonotonic:=0
		var previous:=0.
		for x in range(1,480):
			var a:=two.get_pixel(x-1,row*32+16);var b:=two.get_pixel(x,row*32+16)
			worst=maxf(worst,max_channel(a,b))
			var brightness:=b.r*.2126+b.g*.7152+b.b*.0722
			if brightness<previous-1.01/255.:nonmonotonic+=1
			previous=brightness
		check(worst<=3.01/255. and nonmonotonic==0,"accent %d light gradient has no posterized contour jumps"%row)
	var neutral_exact:=true
	for x in 512:neutral_exact=neutral_exact and one.get_pixel(x,16)==two.get_pixel(x,16)
	check(neutral_exact,"neutral light ramp preserved over all 512 pixels")
	for i in markers.size():check(one.get_pixel(i*48+24,192)==two.get_pixel(i*48+24,192),"semantic color unchanged "+str(i))
	mat.set_shader_parameter("palette_scheme",1)
	check(one.get_data()==(await snap(view)).get_data(),"1-2-1 exact restoration")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"shader":shader_path,"checks":checks,"failures":failures},"\t"))
	view.free();print("PALETTE_COLORS checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
