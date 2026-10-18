extends SceneTree

const THEME = preload("res://scripts/dream/dream_room_environment_theme.gd")
const PIXELS = preload("res://scripts/dream/office_pixel_materials.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const SAMPLE = preload("res://scripts/dream/office_sample_floor.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	for key in SAMPLE.ART_REVIEW_ROOMS:
		var room := {"authored_sample": true, "sample_key": key, "archetype": "server"}
		var floor := THEME.get_sample_base_floor_material(room) as ShaderMaterial
		check(floor != null, "%s sample floor material" % key)
		check(floor != THEME.get_base_floor_material("server"), "%s does not alter optional floor" % key)
		check(floor.get_shader_parameter("atlas" if key == "office" else "pixel_texture") != null, "%s has floor artwork" % key)
	check(THEME.get_sample_base_floor_material({"authored_sample": false, "sample_key": "server", "archetype": "server"}) == THEME.get_base_floor_material("server"), "optional generator retains its original material")
	check(PIXELS.swatch("floor_tile") == PIXELS.swatch("floor_tile"), "quiet tile texture is shared")
	check(PIXELS.swatch("floor_carpet") == PIXELS.swatch("floor_carpet"), "quiet carpet texture is shared")
	var base := CATALOG.make_visual("server", false)
	var sample := CATALOG.make_visual("server", true)
	var base_mesh := base.get_child(0) as MeshInstance3D
	var sample_mesh := sample.get_child(0) as MeshInstance3D
	check(base_mesh != null and sample_mesh != null, "server geometry remains shared")
	if base_mesh != null and sample_mesh != null:
		check((base_mesh.material_override as ShaderMaterial).get_shader_parameter("sample_furniture_surface") != true, "optional furniture unchanged")
		check((sample_mesh.material_override as ShaderMaterial).get_shader_parameter("sample_furniture_surface") == true, "authored furniture has face hierarchy")
	var chair := CATALOG.make_visual("chair", true)
	var chair_meshes: Array[MeshInstance3D] = []
	CATALOG._collect_meshes(chair, chair_meshes)
	var imported_surface_found := false
	for mesh in chair_meshes:
		for surface in mesh.mesh.get_surface_count():
			var active := mesh.get_active_material(surface) as ShaderMaterial
			if active != null and active.shader == PIXELS.SHADER and active.get_shader_parameter("sample_furniture_surface") == true:
				imported_surface_found = true
	check(imported_surface_found, "imported sample furniture also has face hierarchy")
	base.free()
	sample.free()
	chair.free()
	print("MATERIAL SEPARATION failures=", failures)
	quit(1 if failures else 0)
