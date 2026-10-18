extends SceneTree
var log_path := "user://cutout_screen_read_log.txt"
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
	log_line("SCREEN_READ_START")
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	# Mini scene in root directly (not WorldViewport) first
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.6, 0.9)
	env.environment = e
	root.add_child(env)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 1.2, 3)
	root.add_child(cam)
	var floor := MeshInstance3D.new()
	var fq := PlaneMesh.new(); fq.size=Vector2(8,8); floor.mesh=fq
	var fm := StandardMaterial3D.new(); fm.albedo_color=Color(0.2,0.9,0.25); fm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	floor.material_override=fm
	root.add_child(floor)
	# Box with screen-behind cutout shader
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size=Vector3(1.2,1.6,0.4); box.mesh=bm
	box.position = Vector3(0, 0.8, 0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform sampler2D occlusion_screen : hint_screen_texture, filter_nearest;
uniform float cut_force = 0.0;
void fragment() {
	vec3 behind = texture(occlusion_screen, SCREEN_UV).rgb;
	vec3 solid = vec3(0.8, 0.2, 0.1);
	ALBEDO = mix(behind, solid, cut_force);
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("cut_force", 1.0)
	box.material_override = mat
	root.add_child(box)
	for i in 10: await process_frame
	var img_solid: Image = await capture()
	mat.set_shader_parameter("cut_force", 0.0)
	var img_behind: Image = await capture()
	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img_solid.save_png(runtime.path_join("mini_screen_solid.png"))
	img_behind.save_png(runtime.path_join("mini_screen_behind.png"))
	img_solid.save_png("user://mini_screen_solid.png")
	img_behind.save_png("user://mini_screen_behind.png")
	var cx:=640; var cy:=360
	var s:=avg(img_solid,cx,cy,20); var b:=avg(img_behind,cx,cy,20)
	log_line("solid=%s behind=%s" % [str(s), str(b)])
	log_line("screen_read_works=%s" % str(b.g > 0.4 or b.b > 0.4))
	log_line("SCREEN_READ_DONE")
	quit(0)