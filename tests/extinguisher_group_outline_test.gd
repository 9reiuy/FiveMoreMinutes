extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func draw() -> Image:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(640,360);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var monitor:=root.get_node_or_null("PerformanceMonitor")
	if monitor!=null:monitor.current_mode=0;monitor._update_display_mode()
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("c397b6");scene.add_child(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3
	scene.add_child(camera);camera.position=Vector3(0,0,5);camera.current=true
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/dream3d/extinguisher_smoke.gdshader");material.render_priority=3
	material.set_shader_parameter("receive_scene_light",false)
	var quad:=QuadMesh.new();quad.material=material
	var bank:=MultiMesh.new();bank.transform_format=MultiMesh.TRANSFORM_3D;bank.use_colors=true;bank.mesh=quad;bank.instance_count=3
	for i in 3:
		bank.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(1.6,1.6,1)),Vector3((i-1)*.52,0,(i-1)*.2)))
		bank.set_instance_color(i,Color(.1+i*.4,1,1,1))
	var carrier:=MultiMeshInstance3D.new();carrier.multimesh=bank;scene.add_child(carrier)
	material.set_shader_parameter("group_outline",false);var plain:=await draw()
	material.set_shader_parameter("group_outline",true);var grouped:=await draw()
	var bg:=plain.get_pixel(5,5)
	var internal:=0;var exterior:=0
	for y in 360:
		for x in 640:
			if grouped.get_pixel(x,y).r<.02:
				if plain.get_pixel(x,y)==bg:exterior+=1
				else:internal+=1
	check(internal>30,"Separate cloud groups retain visible black contours over one another")
	check(exterior>30,"Cloud groups have black exterior contours")
	material.set_shader_parameter("outline_width_texels",1.0);var thin:=await draw()
	var thin_ink:=0
	for y in 360:
		for x in 640:
			if thin.get_pixel(x,y).r<.02:thin_ink+=1
	check(internal+exterior>thin_ink*1.5,"Two-texel black outlines are thicker than the former one-texel outlines")
	material.set_shader_parameter("outline_width_texels",2.0)
	bank.visible_instance_count=1;bank.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3(3,3,1)),Vector3.ZERO))
	bank.set_instance_color(0,Color(.9,1,1,1))
	material.set_shader_parameter("group_outline",false);var fill:=await draw()
	material.set_shader_parameter("group_outline",true);var single:=await draw()
	var seams:=0;var holes:=0;var tones: Dictionary={}
	for y in 360:
		for x in 640:
			var paper:=fill.get_pixel(x,y)
			if paper!=bg:
				tones[roundi(paper.r*255)]=true
				# Ignore the subpixel raster boundary; only the eroded body is an
				# internal seam candidate, never a contour-edge rounding difference.
				var inside:=x>4 and x<635 and y>4 and y<355
				if inside:
					for offset in [Vector2i(-4,0),Vector2i(4,0),Vector2i(0,-4),Vector2i(0,4)]:
						if fill.get_pixel(x+offset.x,y+offset.y)==bg:inside=false;break
				if inside and single.get_pixel(x,y).r<.02:seams+=1
	for y in range(165,185):
		for x in range(305,335):
			if fill.get_pixel(x,y)==bg:holes+=1
	check(seams==0,"Circles INSIDE a single cloud group have no black seams")
	check(holes==0,"Halftone ink does not cut transparent holes through a cloud")
	check(tones.size()==2,"Both shadows share one light base, without a solid grey patch")
	var sparse:=0;var dense:=0;var rounded:=0;var coverage_steps: Dictionary={}
	for gy in range(6,90,6):
		for gx in range(6,90,6):
			var dots:=0;var occupied:=0;var corner_ink:=0
			for dy in 6:
				for dx in 6:
					var uv:=Vector2(gx+dx+.5,gy+dy+.5)/96.0
					var at:=camera.unproject_position(Vector3((uv.x-.5)*3,(.5-uv.y)*3,0))
					var color:=fill.get_pixelv(Vector2i(at))
					if color==bg:continue
					occupied+=1
					if color.r<.7:
						dots+=1
						if dx in [0,5] and dy in [0,5]:corner_ink+=1
			if occupied==36:
				if dots>0:coverage_steps[dots]=true
				if dots>=1 and dots<=4:sparse+=1
				if dots>=10:dense+=1
				if dots>0 and corner_ink==0:rounded+=1
	check(sparse>0 and dense>0,"GPU shows sparse and dense circular halftone patterns")
	check(coverage_steps.size()>=3,"Shadow transition has several shrinking-dot coverage levels, not two hard-cut bands")
	check(rounded>5,"Halftone dots leave their tile corners empty, instead of forming squares")
	material.set_shader_parameter("world_to_floor",Transform3D.IDENTITY);material.set_shader_parameter("clip_at_floor",true)
	var ground:=await draw()
	check(ground.get_pixel(320,210)==bg,"Cloud base can be clipped flat at the ground")
	check(ground.get_pixel(320,135)!=bg,"Upper cloud lobes survive base clipping")
	material.set_shader_parameter("clip_at_floor",false);material.set_shader_parameter("smoke_clock",1.2)
	var later:=await draw();var changed:=0
	for y in 360:
		for x in 640:
			if later.get_pixel(x,y)!=single.get_pixel(x,y):changed+=1
	check(changed>100,"Cloud shape and half-tone patches remain animated")
	material.set_shader_parameter("group_outline",false);material.set_shader_parameter("smoke_clock",0.0)
	var min_aspect:=100.0;var max_aspect:=0.0;var min_area:=1000000;var max_area:=0
	var silhouettes: Dictionary={}
	for seed_value in [.03,.18,.33,.48,.63,.78,.93]:
		bank.set_instance_color(0,Color(seed_value,1,1,1))
		var variant:=await draw()
		var low:=Vector2i(640,360);var high:=Vector2i.ZERO;var area:=0;var signature:=0
		for y in 360:
			for x in 640:
				if variant.get_pixel(x,y)==bg:continue
				low=Vector2i(mini(low.x,x),mini(low.y,y));high=Vector2i(maxi(high.x,x),maxi(high.y,y))
				area+=1;signature=posmod(signature+x*17+y*31,2147483647)
		var aspect:=float(high.x-low.x+1)/maxi(1,high.y-low.y+1)
		min_aspect=minf(min_aspect,aspect);max_aspect=maxf(max_aspect,aspect)
		min_area=mini(min_area,area);max_area=maxi(max_area,area);silhouettes[signature]=true
	check(silhouettes.size()==7,"Seven different circle counts/seeds give seven distinct cloud silhouettes")
	check(max_aspect/min_aspect>1.15,"Cloud groups vary in width/height, not just number of circles")
	check(float(max_area)/maxi(1,min_area)>1.2,"Cloud groups vary in overall mass rather than repeating one large ball template")
	print("CLOUD_VARIANTS distinct=",silhouettes.size()," aspect_min=",min_aspect," aspect_max=",max_aspect," area_min=",min_area," area_max=",max_area)
	print("CLOUD_GROUPS internal_contour=",internal," exterior_contour=",exterior," within_group_seams=",seams," small_transition_dots=",sparse," dense_round=",dense," rounded_tiles=",rounded," dot_levels=",coverage_steps.size())
	scene.free();await process_frame
	print("EXTINGUISHER_GROUP checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
