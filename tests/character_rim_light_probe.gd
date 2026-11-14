extends SceneTree
const EFFECT := preload("res://scripts/testing/character_rim_effect.gd")
var effect = EFFECT.new()
var viewport: SubViewport
var world: Node3D
var light: OmniLight3D
var material: ShaderMaterial
var failures: Array[String] = []
var measurements: Dictionary = {}

func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); print("FAIL ",label)
func capture(name: String) -> Image:
	await frames(4); await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("res://.runtime/character_rim_20261113/probe/"+name+".png")
	return image
func energy(image: Image, left: bool) -> float:
	var sum := 0.0
	for y in range(32,224):
		for x in (range(32,128) if left else range(128,224)):
			var c := image.get_pixel(x,y); sum += c.r+c.g+c.b
	return sum
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.runtime/character_rim_20261113/probe")
	viewport = SubViewport.new(); viewport.size = Vector2i(256,256)
	viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new(); viewport.add_child(world)
	var env := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_energy = 0
	env.environment = environment; world.add_child(env)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0; camera.position = Vector3(0,0,4); world.add_child(camera); camera.make_current()
	var texture := Image.create(32,32,false,Image.FORMAT_RGBA8)
	texture.fill(Color(0,0,0,0))
	for y in range(4,28):
		for x in range(4,28): texture.set_pixel(x,y,Color(0,0,0,1))
	var quad := MeshInstance3D.new(); var mesh := QuadMesh.new(); mesh.size = Vector2(2,2); quad.mesh = mesh
	material = ShaderMaterial.new(); material.shader = load("res://shaders/dream3d/lit_pixel_carrier.gdshader")
	material.set_shader_parameter("capture_texture",ImageTexture.create_from_image(texture))
	material.set_shader_parameter("character_emission_strength",0.0)
	quad.material_override = material; world.add_child(quad)
	light = OmniLight3D.new(); light.position = Vector3(-2,0.3,1)
	light.omni_range = 6; light.light_energy = 3; light.shadow_enabled = true; world.add_child(light)
	effect.bind_material(material)
	await frames(30)
	var base := await capture("baseline")
	effect.set_enabled(true)
	var left := await capture("left")
	light.position.x = 2
	var right := await capture("right")
	light.hide()
	var dark := await capture("dark")
	effect.set_enabled(false)
	var dark_base := await capture("dark_baseline")
	measurements = {"baseline":energy(base,true)+energy(base,false),"left_l":energy(left,true),"left_r":energy(left,false),"right_l":energy(right,true),"right_r":energy(right,false),"dark":energy(dark,true)+energy(dark,false),"dark_base":energy(dark_base,true)+energy(dark_base,false)}
	check(measurements.left_l > measurements.left_r*1.3+10,"left light selects left edge on black art")
	check(measurements.right_r > measurements.right_l*1.3+10,"right light selects right edge")
	check(dark.get_data() == dark_base.get_data(),"new highlight is exactly absent without light")
	light.show(); effect.set_enabled(true)
	material.set_shader_parameter("smoke_silhouette",true)
	var smoke := await capture("smoke_after")
	effect.set_enabled(false)
	var smoke_base := await capture("smoke_before")
	check(smoke.get_data()==smoke_base.get_data(),"smoke silhouette does not acquire luminous rim")
	material.set_shader_parameter("smoke_silhouette",false)
	material.set_shader_parameter("hurt_flash_amount",1.0)
	var hurt_base := await capture("hurt_before")
	effect.set_enabled(true)
	var hurt := await capture("hurt_after")
	check(hurt.get_data()==hurt_base.get_data(),"hurt flash has no additional doubled rim")
	material.set_shader_parameter("hurt_flash_amount",0.0)
	var other := Image.create(32,32,false,Image.FORMAT_RGBA8); other.fill(Color.WHITE)
	material.set_shader_parameter("actor_pixel_rim_has_other_capture",true)
	material.set_shader_parameter("actor_pixel_rim_other_capture",ImageTexture.create_from_image(other))
	var covered := await capture("union_covered")
	effect.set_enabled(false)
	var covered_base := await capture("union_baseline")
	check(covered.get_data()==covered_base.get_data(),"overlapping part coverage suppresses internal edge light")
	var file := FileAccess.open("res://.runtime/character_rim_20261113/probe/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"measurements":measurements,"failures":failures},"\t")); file.close()
	print("CHARACTER_RIM_PROBE ",JSON.stringify({"measurements":measurements,"failures":failures}))
	effect.clear(); viewport.free(); await frames(6)
	quit(0 if failures.is_empty() else 1)
