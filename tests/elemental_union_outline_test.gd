extends SceneTree
const SYSTEM=preload("res://scripts/dream/elemental_particles_3d.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func draw() -> Image:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	var arena:=Node3D.new()
	root.add_child(arena)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("879bad")
	environment.environment=env
	arena.add_child(environment)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3
	arena.add_child(camera)
	camera.position=Vector3(0,0,5)
	camera.current=true
	var effect:=SYSTEM.new()
	arena.add_child(effect)
	effect.set_process(false)
	for kind in 2:
		for side in [-1.0,1.0]:
			effect._spawn(kind,Vector3(-1.1+kind*2.2+side*.15,0,side*.15),Vector3.ZERO,.85,2.0,false)
	effect._upload()
	for covered in [false,true]:
		var blocker: MeshInstance3D
		if covered:
			blocker=MeshInstance3D.new()
			var box:=BoxMesh.new()
			box.size=Vector3(.65,1.8,.1)
			blocker.mesh=box
			blocker.position=Vector3(-1.1,0,1.0)
			var material:=StandardMaterial3D.new()
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color=Color("657383")
			blocker.material_override=material
			arena.add_child(blocker)
		for bank in effect.outline_banks:bank.visible_instance_count=0
		var before:=await draw()
		effect._upload()
		var after:=await draw()
		var background:=before.get_pixel(5,180)
		var interior_changes:=0
		var contour_pixels:=0
		for y in 360:
			for x in 640:
				var old:=before.get_pixel(x,y)
				var current:=after.get_pixel(x,y)
				if old==current:continue
				if old!=background: interior_changes+=1
				else: contour_pixels+=1
		check(interior_changes==0,"Union contour never draws seams over existing fire/smoke or foreground cover")
		check(contour_pixels>20,"An exterior contour is actually rendered")
		print("UNION_OUTLINE covered=",covered," interior_changes=",interior_changes," exterior_pixels=",contour_pixels)
		if blocker!=null:blocker.free()
	arena.free()
	print("ELEMENTAL_UNION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
