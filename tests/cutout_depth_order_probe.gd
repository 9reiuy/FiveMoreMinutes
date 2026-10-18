extends SceneTree
var log_path := "user://cutout_depth_order_log.txt"
func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(log_path, FileAccess.WRITE)
	else: f.seek_end()
	f.store_line(t); f.close(); print(t)
func _initialize() -> void: call_deferred("run")
func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	var s := Color(0,0,0,0); var n:=0
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			if x>=0 and y>=0 and x<img.get_width() and y<img.get_height():
				s += img.get_pixel(x,y); n+=1
	return s/float(maxi(n,1))
func capture() -> Image:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=true; world.persist_profile=false
	if "enable_game_start_cab_exit" in world: world.enable_game_start_cab_exit=false
	root.add_child(world)
	for i in 15: await process_frame
	world.regenerate(41001)
	for i in 100: await process_frame
	world.set_process(false)
	var cam: Camera3D = world.camera_3d
	# Isolated in the same WorldViewport: two quads only under a dedicated node parented to world
	var holder := Node3D.new(); holder.name = "CutoutProbeHolder"; world.add_child(holder)
	# Clear other geometry influence by moving far away
	var origin := cam.global_position + (-cam.global_transform.basis.z) * 4.0 + cam.global_transform.basis.x * 0.0
	var toward := (cam.global_position - origin).normalized()
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new(); bq.size=Vector2(2,2); back.mesh=bq
	var bm := StandardMaterial3D.new(); bm.albedo_color=Color(0.05,1,0.1); bm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; bm.cull_mode=BaseMaterial3D.CULL_DISABLED
	back.material_override=bm; holder.add_child(back)
	back.global_position = origin - toward * 0.5
	back.global_basis = Basis.looking_at(toward, Vector3.UP)
	var front := MeshInstance3D.new()
	var fq := QuadMesh.new(); fq.size=Vector2(2,2); front.mesh=fq
	# Use REAL office_low_pixel material with cutout enabled
	var office_mat: ShaderMaterial = load("res://shaders/dream3d/office_low_pixel.gdshader") as Shader # wrong
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/dream3d/office_low_pixel.gdshader")
	sm.set_shader_parameter("occlusion_cutout_enabled", true)
	# need atlas or it may be black - use unshaded simple instead cloned from live
	var live: ShaderMaterial = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh and mesh.material_override is ShaderMaterial:
			var cand := mesh.material_override as ShaderMaterial
			if cand.get_shader_parameter("occlusion_cutout_enabled") != null:
				live = cand.duplicate() as ShaderMaterial
				live.set_shader_parameter("occlusion_cutout_enabled", true)
				break
	if live == null:
		log_line("NO_LIVE_MAT"); quit(1); return
	front.material_override = live
	holder.add_child(front)
	front.global_position = origin
	front.global_basis = Basis.looking_at(toward, Vector3.UP)
	log_line("using_live_mat cutout=%s" % str(live.get_shader_parameter("occlusion_cutout_enabled")))
	var sp: Vector2 = cam.unproject_position(origin)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	# No cutout
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4.ZERO)
	var img0: Image = await capture()
	# With cutout
	RenderingServer.global_shader_parameter_set("occlusion_cutout_0", Vector4(sp.x/vp_size.x, sp.y/vp_size.y, 70.0, 1.0))
	var img1: Image = await capture()
	var root_size := Vector2(img1.get_width(), img1.get_height())
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp.x * scale)
	var py := int(offset.y + sp.y * scale)
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img0.save_png(runtime.path_join("iso_off.png"))
	img1.save_png(runtime.path_join("iso_on.png"))
	log_line("screen=%s px=%d,%d" % [str(sp), px, py])
	log_line("off=%s on=%s" % [str(avg(img0,px,py,12)), str(avg(img1,px,py,12))])
	log_line("green_on=%s" % str(avg(img1,px,py,12).g > 0.4))
	# Also try with a brand-new discard-only shader instead of live
	var simple := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert;
global uniform vec4 occlusion_cutout_0;
global uniform vec2 occlusion_viewport_size;
void fragment() {
	vec4 slot=occlusion_cutout_0;
	vec2 d=(SCREEN_UV-slot.xy)*occlusion_viewport_size;
	float dist=length(d);
	float f=1.0;
	if(slot.w>=0.5 && slot.z>0.0 && dist<slot.z){
		float nd=dist/slot.z;
		if(nd<0.35) f=0.0;
		else {
			float density=1.0-(nd-0.35)/0.65; float spacing=6.0;
			vec2 rot=vec2(d.x*0.707-d.y*0.707,d.x*0.707+d.y*0.707);
			vec2 cell=fract(rot/spacing)-vec2(0.5);
			float hole_r=spacing*0.45*density;
			f=smoothstep(hole_r-0.6,hole_r+0.6,length(cell)*spacing);
		}
	}
	ALBEDO=vec3(0.2,0.3,0.8); ROUGHNESS=1.0; SPECULAR=0.0;
	if(f<0.5) discard;
}
"""
	simple.shader = sh
	front.material_override = simple
	var img2: Image = await capture()
	log_line("simple_on=%s green=%s" % [str(avg(img2,px,py,12)), str(avg(img2,px,py,12).g > 0.4)])
	img2.save_png(runtime.path_join("iso_simple_on.png"))
	log_line("DONE")
	quit(0)