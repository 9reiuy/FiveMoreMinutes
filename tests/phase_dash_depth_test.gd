extends SceneTree
var checks := 0
var failures: Array[String] = []
const OUTPUT := "res://.runtime/phase_dash_20261022/depth_fix"
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func draw() -> void:
	for i in 3:
		await process_frame
		RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
func material(code: String) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = Shader.new()
	ink.shader.code = code
	return ink
func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(640,360)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var arena := Node3D.new()
	root.add_child(arena)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	arena.add_child(camera)
	camera.position = Vector3(0,3,5)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	floor_mesh.mesh = plane
	arena.add_child(floor_mesh)
	var builder: Node = load("res://scripts/dream/preview/sample_floor_texture_review.gd").new()
	var floor_image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	floor_image.fill(Color(.05,.07,.1))
	floor_mesh.material_override = builder._material(floor_image)
	var ghost := Sprite3D.new()
	var pixels := Image.create(32,32,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	ghost.texture = ImageTexture.create_from_image(pixels)
	ghost.pixel_size = .04
	arena.add_child(ghost)
	ghost.position = Vector3(0,.8,0)
	ghost.global_basis = camera.global_basis
	var ink := ShaderMaterial.new()
	var formal: Shader = load("res://shaders/dream3d/phase_dash_afterimage.gdshader")
	ink.shader = formal
	ink.set_shader_parameter("capture_texture",ghost.texture)
	ink.set_shader_parameter("opacity",1.0)
	ink.set_shader_parameter("band",3.0)
	ghost.material_override = ink
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4,3,.1)
	wall.mesh = box
	wall.material_override = material("shader_type spatial;render_mode unshaded;void fragment(){ALBEDO=vec3(.05,.1,.2);}")
	arena.add_child(wall)
	wall.global_basis = camera.global_basis
	wall.position = ghost.position+camera.global_basis.z*.5
	wall.hide()
	var behind := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1,1)
	behind.mesh = quad
	behind.material_override = material("shader_type spatial;render_mode unshaded,depth_draw_always;void fragment(){ALBEDO=vec3(.05,.15,.9);ALPHA=1.0;}")
	arena.add_child(behind)
	behind.global_basis = camera.global_basis
	behind.position = ghost.position-camera.global_basis.z*.25
	behind.hide()
	for mode in 6:
		if mode==0:
			var legacy := Shader.new()
			legacy.code = formal.code.replace("depth_draw_opaque","depth_draw_never")
			ink.shader = legacy
		else: ink.shader = formal
		wall.visible = mode==2 or mode==3
		if mode==3:
			wall.material_override = material("shader_type spatial;render_mode unshaded,depth_draw_always;void fragment(){ALBEDO=vec3(.05,.1,.2);ALPHA=1.0;}")
		behind.visible = mode>=4
		if mode==4:
			pixels.fill_rect(Rect2i(10,10,12,12),Color.TRANSPARENT)
			(ghost.texture as ImageTexture).update(pixels)
		if mode==5: ink.set_shader_parameter("opacity",0.0)
		await draw()
		var picture := root.get_texture().get_image()
		var color := picture.get_pixelv(Vector2i(camera.unproject_position(ghost.global_position)))
		var pink := color.r>.7 and color.b>.3 and color.g<.4
		# Solid ground now renders opaque first: even the legacy depthless ghost
		# survives ground, while real foreground geometry still occludes it.
		check(pink if mode<=1 else not pink,"Floor/occluder/transparent silhouette case %d: %s" % [mode,color])
		if mode>=4: check(color.b>.7,"Transparent/faded pixels leave late background unobstructed %d" % mode)
		picture.save_png(OUTPUT+"/case_%d.png" % mode)
	wall.hide()
	behind.hide()
	ghost.hide()
	var trail := MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(7,2)
	trail.mesh = strip
	var ribbon := ShaderMaterial.new()
	ribbon.shader = load("res://shaders/dream3d/phase_dash_pixel_trail.gdshader")
	ribbon.set_shader_parameter("progress",.5)
	ribbon.set_shader_parameter("opacity",2.0)
	trail.material_override = ribbon
	trail.position.y = .12
	arena.add_child(trail)
	await draw()
	var picture := root.get_texture().get_image()
	var colour := picture.get_pixelv(Vector2i(camera.unproject_position(trail.position)))
	check(colour.r>.7,"Actual ribbon also survives late floor draw: %s" % colour)
	picture.save_png(OUTPUT+"/ribbon.png")
	trail.hide()
	var sweep := MeshInstance3D.new()
	var fan := PlaneMesh.new()
	fan.size = Vector2.ONE*5.125
	sweep.mesh = fan
	sweep.position.y = .4
	var arc := ShaderMaterial.new()
	arc.shader = load("res://shaders/dream3d/melee_pixel_sweep.gdshader")
	arc.set_shader_parameter("reach",80.0)
	arc.set_shader_parameter("sweep",.6)
	arc.set_shader_parameter("opacity",1.0)
	var limits := PackedFloat32Array()
	limits.resize(33)
	limits.fill(80)
	arc.set_shader_parameter("reach_limits",limits)
	sweep.material_override = arc
	arena.add_child(sweep)
	var arc_point := Vector3(55.0/32.0,.4,0)
	wall.position = arc_point+camera.global_basis.z*.5
	for mode in 6:
		arc.set_shader_parameter("paper",mode==1)
		wall.visible = mode==2
		if mode==3 or mode==4:
			limits.fill(20)
			arc.set_shader_parameter("reach_limits",limits)
		behind.visible = mode>=4
		behind.position = arc_point-camera.global_basis.z*.25
		if mode==5:
			limits.fill(80)
			arc.set_shader_parameter("reach_limits",limits)
			arc.set_shader_parameter("opacity",0.0)
		await draw()
		picture = root.get_texture().get_image()
		var center := Vector2i(camera.unproject_position(arc_point))
		var bright_pixels := 0
		for x in range(center.x-4,center.x+5):
			for y in range(center.y-4,center.y+5):
				var color := picture.get_pixel(x,y)
				if color.r>.4 and color.g>.4 and color.b>.2: bright_pixels += 1
		check(bright_pixels>3 if mode<2 else bright_pixels==0,"Actual bat/book sweep with floor, foreground cover and clipped reach %d: %d pixels" % [mode,bright_pixels])
		if mode>=4: check(picture.get_pixelv(center).b>.7,"Clipped/faded arc leaves no invisible rectangular depth blocker %d" % mode)
		picture.save_png(OUTPUT+"/melee_%d.png" % mode)
	arena.free()
	builder.free()
	await process_frame
	print("PHASE_DASH_DEPTH checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
