extends SceneTree
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var reflections: Node = load("res://scripts/dream/floor_reflections.gd").new()
	root.add_child(reflections)
	reflections.set_process(false)
	var carrier: Node = load("res://scripts/dream/melee_sweep_visual_3d.gd").new()
	root.add_child(carrier)
	var original_shader: Shader = carrier.material.shader
	reflections._register_visual(carrier.mesh)
	check(carrier.mesh.material_override==carrier.material,"Reflection registration preserves live melee material identity")
	check(reflections.replacements.is_empty(),"Live melee never enters static material replacement list")
	check(carrier.material.shader.code.contains("sample_capture_pass"),"Reflection shader adaptation remains installed")
	for opacity in [0.0,.2,.8,1.0,0.0]:
		carrier.material.set_shader_parameter("opacity",opacity)
		carrier.material.set_shader_parameter("sweep",.7)
		check(is_equal_approx(carrier.mesh.material_override.get_shader_parameter("opacity"),opacity),"Live rendered opacity follows owner: %s" % opacity)
	check(is_equal_approx(carrier.mesh.material_override.get_shader_parameter("sweep"),.7),"Live rendered sweep follows owner")
	var static_mesh := MeshInstance3D.new()
	static_mesh.material_override = ShaderMaterial.new()
	static_mesh.material_override.shader = original_shader
	var static_material := static_mesh.material_override
	root.add_child(static_mesh)
	reflections._register_visual(static_mesh)
	check(static_mesh.material_override!=static_material,"Unmarked static materials still receive isolated copies")
	check(original_shader.resource_path=="res://shaders/dream3d/melee_pixel_sweep.gdshader" and not original_shader.code.contains("sample_capture_pass"),"Shared original shader remains unchanged")
	reflections.restore()
	check(carrier.mesh.material_override==carrier.material and carrier.material.shader==original_shader,"Reflection cleanup restores shader without losing live material")
	check(static_mesh.material_override==static_material,"Reflection cleanup restores static material")
	static_mesh.free()
	carrier.free()
	reflections.free()
	for i in 3: await process_frame
	print("MELEE_REFLECTION_MATERIAL checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
