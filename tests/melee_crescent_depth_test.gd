extends SceneTree
var checks := 0
var failures := 0
const OUTPUT := "res://.runtime/melee_crescent_20261022"
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func draw() -> Image:
	for i in 3:
		await process_frame
		RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func white_count(picture: Image) -> int:
	var count := 0
	for y in picture.get_height():
		for x in picture.get_width():
			var colour := picture.get_pixel(x,y)
			if minf(colour.r,minf(colour.g,colour.b))>.7: count += 1
	return count
func run() -> void:
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var arena := Node3D.new()
	root.add_child(arena)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	arena.add_child(camera)
	camera.position = Vector3(0,3,5)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(20,20)
	floor_mesh.mesh = floor_plane
	var builder: Node = load("res://scripts/dream/preview/sample_floor_texture_review.gd").new()
	var floor_image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	floor_image.fill(Color(.04,.05,.08))
	floor_mesh.material_override = builder._material(floor_image)
	arena.add_child(floor_mesh)
	var fx: Node3D = load("res://scripts/dream/melee_crescent_hit_3d.gd").new()
	arena.add_child(fx)
	fx.setup(camera,Vector3(0,.8,0),Vector2.RIGHT,{"origin":Vector3(0,0,.04),"normal":Vector3.BACK})
	fx.set_process(false)
	fx.material.set_shader_parameter("progress",.3)
	fx.material.set_shader_parameter("line_count",0)
	var crescent := await draw()
	check(white_count(crescent)>40,"Actual approved floor does not erase crescent")
	crescent.save_png(OUTPUT+"/crescent_only.png")
	fx.material.set_shader_parameter("line_count",3)
	var cuts := await draw()
	check(white_count(cuts)>white_count(crescent),"Random thin cuts add visible pixels")
	cuts.save_png(OUTPUT+"/crescent_cuts.png")
	root.size = Vector2i(240,135)
	fx.material.set_shader_parameter("line_count",0)
	var low_crescent := await draw()
	fx.material.set_shader_parameter("line_count",3)
	var low_cuts := await draw()
	check(white_count(low_cuts)>white_count(low_crescent)+5,"Thin lines survive low-resolution world raster")
	root.size = Vector2i(640,360)
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var palette := ShaderMaterial.new()
	palette.shader = load("res://shaders/palette_quantize.gdshader")
	rect.material = palette
	layer.add_child(rect)
	root.add_child(layer)
	var filtered := await draw()
	check(white_count(filtered)>40,"Palette 1 preserves readable hit ink")
	filtered.save_png(OUTPUT+"/crescent_palette.png")
	layer.free()
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4,4,.1)
	wall.mesh = box
	var wall_material := StandardMaterial3D.new()
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_material.albedo_color = Color(.05,.1,.2)
	wall.material_override = wall_material
	arena.add_child(wall)
	wall.global_basis = camera.global_basis
	wall.global_position = fx.global_position+camera.global_basis.z*1.5
	check(white_count(await draw())==0,"Foreground wall hides crescent and every cut")
	wall.hide()
	fx.material.set_shader_parameter("progress",1.0)
	check(white_count(await draw())==0,"Expired effect writes no visible ink")
	arena.free()
	builder.free()
	await process_frame
	print("MELEE_CRESCENT_DEPTH checks=",checks," failures=",failures)
	quit(1 if failures else 0)
