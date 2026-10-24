extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func draw() -> Color:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_pixel(320,180)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(640,360);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var monitor:=root.get_node_or_null("PerformanceMonitor")
	if monitor!=null:monitor.current_mode=0;monitor._update_display_mode()
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("151e34");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.12;scene.add_child(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.near=.1;camera.far=30
	scene.add_child(camera);camera.position=Vector3(0,1,6);camera.look_at(Vector3(0,1,0));camera.current=true
	var cloud:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);cloud.mesh=mesh;cloud.position=Vector3(0,1,0)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/dream3d/extinguisher_smoke.gdshader");mat.render_priority=3
	mat.set_shader_parameter("fusion_enabled",true)
	var field:=Image.create(8,192,false,Image.FORMAT_RGBAF);field.fill(Color(0,0,0,0))
	mat.set_shader_parameter("fusion_field",ImageTexture.create_from_image(field));mat.set_shader_parameter("collective_fusion",true)
	cloud.material_override=mat;cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;scene.add_child(cloud)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,0,0);sun.light_energy=0;sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;scene.add_child(sun)
	var dark:=await draw();sun.light_energy=1.2;var lit:=await draw()
	check(lit.r>dark.r+.15,"Cloud receives real scene lighting rather than remaining unshaded")
	var blocker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(3,.5,1.2);blocker.mesh=box;blocker.position=Vector3(0,2,1.73)
	blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;scene.add_child(blocker)
	var shaded:=await draw()
	check(shaded.r<lit.r-.08,"An intervening wall shadow darkens the cloud without drawing over it")
	check(shaded.r>0.01,"Shadowed cloud retains a small ambient readability floor")
	print("SMOKE_LIGHTING dark=",dark," lit=",lit," shadow=",shaded)
	scene.free();await process_frame
	print("EXTINGUISHER_LIGHTING checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
