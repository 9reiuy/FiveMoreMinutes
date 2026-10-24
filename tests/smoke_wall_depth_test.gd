extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func draw() -> Color:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_pixel(320,180)
func difference(a: Color,b: Color) -> float:return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(640,360);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var monitor:=root.get_node_or_null("PerformanceMonitor")
	if monitor!=null:monitor.current_mode=0;monitor._update_display_mode()
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
	scene.add_child(camera);camera.position=Vector3(0,1,7);camera.look_at(Vector3(0,1,0));camera.current=true
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-25,-25,0)
	var wall:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(4,4,.12);wall.mesh=box
	wall.material_override=preload("res://scripts/dream/office_pixel_materials.gd").make(Color(.2,.4,.7),"paint")
	scene.add_child(wall);wall.position.y=1
	var fog:=MeshInstance3D.new();var card:=QuadMesh.new();card.size=Vector2(1.6,1.6);fog.mesh=card
	var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/dream3d/extinguisher_smoke.gdshader");mat.render_priority=3
	mat.set_shader_parameter("fusion_enabled",true)
	var field:=Image.create(8,192,false,Image.FORMAT_RGBAF);field.fill(Color(0,0,0,0))
	mat.set_shader_parameter("fusion_field",ImageTexture.create_from_image(field));mat.set_shader_parameter("collective_fusion",true)
	var mask:=Image.create(10,10,false,Image.FORMAT_RGBA8);mask.fill(Color.RED)
	mat.set_shader_parameter("smoke_mask",ImageTexture.create_from_image(mask));mat.set_shader_parameter("mask_origin",Vector2(-5,-5));mat.set_shader_parameter("mask_size",Vector2(10,10));mat.set_shader_parameter("world_to_floor",Transform3D.IDENTITY)
	fog.material_override=mat;scene.add_child(fog);fog.position=Vector3(0,1,1);fog.hide()
	var base:=await draw()
	fog.show();var front:=await draw()
	check(difference(front,base)>.15,"Smoke in front covers a wall drawn in the architecture transparent pass")
	fog.position.z=-1;var behind:=await draw()
	check(difference(behind,base)<.01,"A foreground wall still occludes smoke; no through-wall overlay")
	fog.position.z=1
	var actor:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.8,1.2);actor.mesh=quad
	var silhouette:=ShaderMaterial.new();silhouette.shader=load("res://shaders/dream3d/extinguisher_silhouette.gdshader");silhouette.render_priority=8
	var pixel:=Image.create(2,2,false,Image.FORMAT_RGBA8);pixel.fill(Color.WHITE)
	silhouette.set_shader_parameter("capture_texture",ImageTexture.create_from_image(pixel));actor.material_override=silhouette
	scene.add_child(actor);actor.position=Vector3(0,1,2)
	var visible_actor:=await draw()
	check(visible_actor.r<.03 and visible_actor.g<.03 and visible_actor.b<.03,"Complete silhouette remains visible over foreground gas")
	actor.position.z=-2;fog.hide();var hidden_actor:=await draw()
	check(difference(hidden_actor,base)<.01,"Silhouette does not reveal a character behind a solid wall")
	scene.free();await process_frame
	print("SMOKE_WALL_DEPTH checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
