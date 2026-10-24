extends SceneTree
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
const TEST=preload("res://tests/fire_extinguisher_test.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func draw() -> Image:
	for i in 6:await process_frame
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
	var banks: Array[MultiMesh]=[]
	var materials: Array[ShaderMaterial]=[]
	for outer in [true,false]:
		var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/dream3d/extinguisher_smoke_outline.gdshader" if outer else "res://shaders/dream3d/extinguisher_smoke.gdshader")
		mat.render_priority=2 if outer else 3;mat.set_shader_parameter("receive_scene_light",false)
		mat.set_shader_parameter("fusion_enabled",true);mat.set_shader_parameter("outer_outline_pass",outer);materials.append(mat)
		var mesh:=QuadMesh.new();mesh.material=mat
		var bank:=MultiMesh.new();bank.transform_format=MultiMesh.TRANSFORM_3D;bank.use_colors=true;bank.use_custom_data=true;bank.mesh=mesh;bank.instance_count=2
		for i in 2:
			bank.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(1.6,1.6,1)),Vector3(-.4+i*.8,0,0)))
			bank.set_instance_color(i,Color(.13+i*.45,1,1,1));bank.set_instance_custom_data(i,Color(0,0,0,0))
		var carrier:=MultiMeshInstance3D.new();carrier.multimesh=bank;scene.add_child(carrier);banks.append(bank)
	banks[0].visible_instance_count=0
	var separate:=await draw()
	for bank in banks:
		bank.set_instance_custom_data(0,Color(.5,0,1,1))
		bank.set_instance_custom_data(1,Color(-.5,0,1,1))
	var fused:=await draw()
	var bg:=separate.get_pixel(5,5);var neck_pixels:=0
	for y in 360:
		for x in 640:
			if separate.get_pixel(x,y)==bg and fused.get_pixel(x,y)!=bg:neck_pixels+=1
	check(neck_pixels>20,"Nearby cloud groups grow a visible neck instead of only overlapping flat sprites")
	banks[0].visible_instance_count=2
	var outlined:=await draw()
	var interior_black:=0;var exterior_black:=0;var inner_shadow:=0
	for y in 360:
		for x in 640:
			var old:=fused.get_pixel(x,y);var current:=outlined.get_pixel(x,y)
			if current.r<.02:
				if old==bg:exterior_black+=1
				else:interior_black+=1
			if old!=bg and current.r>.1 and current.r<.75:inner_shadow+=1
	check(interior_black==0,"Overlapping interiors contain no black contours")
	check(exterior_black>30,"Only the exterior of the combined smoke retains black ink")
	check(inner_shadow>30,"Internal layers retain halftone shadow ink rather than becoming featureless white")
	for bank in banks:
		bank.set_instance_custom_data(0,Color(0,0,0,0));bank.set_instance_custom_data(1,Color(0,0,0,0))
		bank.set_instance_transform(1,Transform3D(Basis.from_scale(Vector3(1.6,1.6,1)),Vector3(1.8,0,0)))
	var apart:=await draw()
	var gap:=camera.unproject_position(Vector3(.8,0,0))
	check(apart.get_pixelv(Vector2i(gap))==bg,"Separating groups disconnect cleanly without an orphan bridge")
	var world=TEST.World.new();root.add_child(world)
	for y in 2:
		for x in 2:world.floor_cells[Vector2i(x,y)]="room"
	var smoke:=SYSTEM.new();smoke.world=world;world.add_child(smoke);smoke.set_physics_process(false)
	for cell in world.floor_cells:smoke.cells[cell]=1.0
	world.wall_edges["V:1:0"]={"axis":"V","x":1,"y":0}
	var puffs: Array[Dictionary]=[{"at":Vector3.ZERO,"cell":Vector2i.ZERO,"size":1.0,"alpha":1.0},{"at":Vector3(.5,0,0),"cell":Vector2i(1,0),"size":1.0,"alpha":1.0}]
	smoke.link_fusion(puffs,camera)
	check(smoke.fusion_pairs==0,"A real separating wall prevents cross-group fusion")
	check(not smoke.fusion_can_cross(Vector2i.ZERO,Vector2i.ONE),"One blocked corner route prevents a diagonal bridge through a wall end")
	world.wall_edges.clear();smoke.link_fusion(puffs,camera)
	check(smoke.fusion_pairs==1 and float(puffs[0].link.a)>0,"Open connected cells allow a nearby pair to fuse")
	puffs[1].at=Vector3(1.5,0,0);smoke.link_fusion(puffs,camera)
	check(smoke.fusion_pairs==0,"Distant clouds are not pulled together")
	puffs[1].at=Vector3(.5,0,1);smoke.link_fusion(puffs,camera)
	check(smoke.fusion_pairs==0,"Groups far apart in depth are not falsely fused by screen overlap")
	puffs[1].at=Vector3(.5,0,0);puffs[1].alpha=.1;smoke.link_fusion(puffs,camera)
	check(smoke.fusion_pairs==0,"Fading wisps stop participating in fusion")
	print("SMOKE_FUSION neck_pixels=",neck_pixels," interior_black=",interior_black," exterior_black=",exterior_black," shadow_pixels=",inner_shadow)
	# Exercise the NEW production multi-neighbour field, not just the legacy
	# pair fallback above. Three clouds must contribute at the same time.
	for bank in banks:bank.visible_instance_count=0
	var live=SYSTEM.install(world);live.set_physics_process(false)
	for material in live.materials:
		material.set_shader_parameter("receive_scene_light",false)
		material.set_shader_parameter("clip_at_floor",false)
	var triple: Array[Dictionary]=[]
	for point in [Vector3(-.65,-.4,0),Vector3(.65,-.4,0),Vector3(0,.73,0)]:
		triple.append({"at":point,"cell":Vector2i.ZERO,"size":1.6,"alpha":1.0,"seed":.23})
	for index in 3:
		for bank in [live.banks[0],live.outer_banks[0]]:
			bank.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3(1.6,1.6,1)),triple[index].at))
			bank.set_instance_color(index,Color(.23,1,1,1))
			bank.set_instance_custom_data(index,Color((float(index)+.5)/SYSTEM.MAX_PUFFS,0,0,0))
	live.banks[0].visible_instance_count=3;live.outer_banks[0].visible_instance_count=0
	var unfused_triple:=await draw()
	live.build_collective_field(triple,camera,true)
	check(live.fusion_pairs==6,"Three groups participate simultaneously, not as one disjoint pair")
	for row in 3:
		check(live.fusion_field_image.get_pixel(1,row).r>.9 and live.fusion_field_image.get_pixel(3,row).r>.9,"Each cloud receives both neighbours in its continuous field")
	var fused_triple:=await draw()
	var collective_pixels:=0
	for y in 360:
		for x in 640:
			if unfused_triple.get_pixel(x,y)==bg and fused_triple.get_pixel(x,y)!=bg:collective_pixels+=1
	check(collective_pixels>20,"Production scalar field grows rounded joining lobes on GPU")
	live.outer_banks[0].visible_instance_count=3
	var collective_outline:=await draw()
	var collective_inner_black:=0
	for y in 360:
		for x in 640:
			if fused_triple.get_pixel(x,y)!=bg and collective_outline.get_pixel(x,y).r<.02:collective_inner_black+=1
	check(collective_inner_black==0,"Collective field still reserves black for its exterior")
	triple[2].at=Vector3(0,4,0);live.build_collective_field(triple,camera,true)
	check(live.fusion_pairs==2,"A departing cloud leaves the field without an orphan connector")
	world.wall_edges["V:1:0"]={"axis":"V","x":1,"y":0}
	triple[1].cell=Vector2i(1,0);live.build_collective_field(triple,camera,true)
	check(live.fusion_pairs==0,"Production collective field respects real wall separation")
	print("COLLECTIVE_FUSION added_pixels=",collective_pixels," interior_black=",collective_inner_black)
	world.free();scene.free();await process_frame
	print("EXTINGUISHER_FUSION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
