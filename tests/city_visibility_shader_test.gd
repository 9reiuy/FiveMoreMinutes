extends SceneTree
const CITY=preload("res://scripts/dream/preview/sample_neon_city.gd")
func _initialize()->void:call_deferred("run")
func frames()->void:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
func run()->void:
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(640,360)
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.position=Vector3(0,8,8);camera.look_at(Vector3.ZERO)
	var cells:Dictionary={}
	for y in range(-8,1):
		for x in range(-8,9):cells[Vector2i(x,y)]=true
	var topology:=CITY.classify_void(cells,Rect2i(-10,-10,21,21))
	topology.clearance_texture=ImageTexture.create_from_image(CITY.interior_cut_depth_image(topology))
	var city:=CITY.new();city.topology=topology
	var mat:ShaderMaterial=city._scenery_material(false,false)
	mat.set_shader_parameter("map_origin",Vector3.ZERO);mat.set_shader_parameter("map_x_axis",Vector3.RIGHT);mat.set_shader_parameter("map_z_axis",Vector3.BACK)
	var o:=camera.project_ray_origin(Vector2.ZERO)
	var d:=camera.project_ray_normal(Vector2.ZERO)
	mat.set_shader_parameter("ray_origin_tl",o);mat.set_shader_parameter("ray_origin_dx",camera.project_ray_origin(Vector2(640,0))-o);mat.set_shader_parameter("ray_origin_dy",camera.project_ray_origin(Vector2(0,360))-o)
	mat.set_shader_parameter("ray_direction_tl",d);mat.set_shader_parameter("ray_direction_dx",Vector3.ZERO);mat.set_shader_parameter("ray_direction_dy",Vector3.ZERO)
	var plane:=MeshInstance3D.new();plane.mesh=QuadMesh.new();plane.mesh.size=Vector2(24,24);plane.material_override=mat;scene.add_child(plane);plane.global_basis=camera.global_basis;plane.position=Vector3(0,2,2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/city_visibility_20261020/shader"))
	mat.set_shader_parameter("soft_occlusion_enabled",false);await frames()
	var before:=root.get_texture().get_image();before.save_png("res://.runtime/city_visibility_20261020/shader/before.png")
	mat.set_shader_parameter("soft_occlusion_enabled",true);await frames()
	var after:=root.get_texture().get_image();after.save_png("res://.runtime/city_visibility_20261020/shader/after.png")
	var changed:=0
	var outside_changed:=0
	for y in after.get_height():
		for x in after.get_width():
			if before.get_pixel(x,y)!=after.get_pixel(x,y):
				changed+=1
				if before.get_pixel(x,y).r>.02:outside_changed+=1
	await frames()
	var stable:=after.get_data()==root.get_texture().get_image().get_data()
	var center_clear:=after.get_pixel(320,110).r<.01
	var passed:=changed>100 and outside_changed==0 and stable and center_clear
	print("CITY_SHADER_GPU changed_inside=",changed," changed_outside=",outside_changed," stable=",stable," center_clear=",center_clear," passed=",passed)
	city.free();scene.free();quit(0 if passed else 1)
