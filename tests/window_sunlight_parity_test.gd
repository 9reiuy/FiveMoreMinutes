extends SceneTree

const WALL_SCENE := preload("res://scenes/dream/3d/WallStraight3D.tscn")
const CONFIG_RESOURCE := preload("res://resources/demo_config.tres")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_demo_config_defaults()
	_test_window_wall_geometry_and_lighting()
	_test_window_shadow_caster_aperture()
	_test_window_glass_visual()

	if failures.is_empty():
		print("WINDOW SUNLIGHT PARITY TEST PASSED: common-direction soft window light, aperture caster and continuous sky glass verified.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_demo_config_defaults() -> void:
	_assert(CONFIG_RESOURCE.window_light_enabled == true, "window_light_enabled should default to true")
	_assert(CONFIG_RESOURCE.window_light_energy >= 1.8, "window_light_energy should be >= 1.8, got %f" % CONFIG_RESOURCE.window_light_energy)
	_assert(CONFIG_RESOURCE.window_light_range <= 8.0 and CONFIG_RESOURCE.window_light_range >= 5.0, "window_light_range should be localized between 5.0m and 8.0m, got %f" % CONFIG_RESOURCE.window_light_range)
	_assert(CONFIG_RESOURCE.window_light_angle <= 70.0 and CONFIG_RESOURCE.window_light_angle >= 40.0, "window_light_angle should be between 40 and 70 degrees, got %f" % CONFIG_RESOURCE.window_light_angle)
	var col: Color = CONFIG_RESOURCE.window_light_color
	_assert(col.b > col.r and col.b >= 0.9, "window_light_color should be cool-toned city night blue (b > r), got %s" % str(col))

func _test_window_wall_geometry_and_lighting() -> void:
	var wall = WALL_SCENE.instantiate()
	root.add_child(wall)
	wall.configure_wall(3.0, 0.1)
	wall.set_window_variant(true)
	var inward_dir := Vector2(-1.0, 0.0)
	wall.set_window_inward_normal(
		inward_dir,
		true,
		CONFIG_RESOURCE.window_light_energy,
		CONFIG_RESOURCE.window_light_range,
		CONFIG_RESOURCE.window_light_angle,
		CONFIG_RESOURCE.window_light_attenuation,
		CONFIG_RESOURCE.window_light_color,
		CONFIG_RESOURCE.window_light_inset
	)

	var light: SpotLight3D = wall.get_node_or_null("WindowLight") as SpotLight3D
	_assert(light != null, "WindowLight SpotLight3D node must exist on window wall")
	if light != null:
		_assert(light.shadow_enabled == false, "WindowLight uses a soft continuous-run fill without intersecting shadow cones")
		_assert((light.light_cull_mask & 1) != 0, "WindowLight cull mask must include Layer 1 (floor, walls, furniture)")
		_assert((light.light_cull_mask & 2) != 0, "WindowLight cull mask must include Layer 2 (player visual)")
		_assert((light.light_cull_mask & 4) != 0, "WindowLight cull mask must include Layer 4 (player shadow proxy)")
		_assert(light.light_energy >= 2.0, "WindowLight energy must be >= 2.0")
		_assert(light.shadow_blur <= 1.0, "WindowLight shadow blur should be crisp (<= 1.0), got %f" % light.shadow_blur)
		_assert(light.shadow_opacity >= 0.9, "WindowLight shadow opacity should be deep (>= 0.9), got %f" % light.shadow_opacity)

		# Check light position is outside and elevated
		var inward_v3 := Vector3(-1, 0, 0)
		var wall_pos: Vector3 = wall.global_position
		var to_light: Vector3 = light.global_position - wall_pos
		var outward_component: float = to_light.dot(-inward_v3)
		_assert(outward_component > 0.5, "Window light must be positioned outdoors/outside the window, outward dot was %f" % outward_component)
		_assert(light.global_position.y > 2.0, "Window light must be elevated above floor glass, Y was %f" % light.global_position.y)

		# Check aim is pointing inward/downward towards the room floor
		var forward := -light.global_transform.basis.z.normalized()
		_assert(forward.dot(inward_v3) > 0.2, "Window light must point inward from the shared floor sun direction")
		_assert(forward.y < -0.2, "Window light must pitch downward towards the floor")

	var radial_fill: OmniLight3D = wall.get_node_or_null("WindowRadialFill") as OmniLight3D
	if radial_fill != null:
		_assert(radial_fill.visible == false or radial_fill.light_energy == 0.0, "WindowRadialFill must not flood the room with unshadowed light")
	var second_wall = WALL_SCENE.instantiate()
	root.add_child(second_wall)
	second_wall.configure_wall(3.0, 0.1)
	second_wall.set_window_variant(true)
	second_wall.set_window_inward_normal(Vector2(0, -1), true)
	var second_light := second_wall.get_node_or_null("WindowLight") as SpotLight3D
	_assert(second_light != null and (-second_light.global_basis.z).dot(-light.global_basis.z) > 0.999, "separate facade windows use one sunlight direction")
	second_wall.queue_free()

	wall.queue_free()

func _test_window_shadow_caster_aperture() -> void:
	var wall = WALL_SCENE.instantiate()
	root.add_child(wall)
	wall.configure_wall(3.0, 0.1)
	wall.set_window_variant(true)

	var shadow_mesh: MeshInstance3D = wall.get_node_or_null("ShadowCasterMesh") as MeshInstance3D
	_assert(shadow_mesh != null, "ShadowCasterMesh must exist on wall segment")
	if shadow_mesh != null:
		_assert(shadow_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "ShadowCasterMesh must be SHADOWS_ONLY")
		_assert(shadow_mesh.mesh == wall.wall_mesh.mesh, "ShadowCasterMesh must use the window mesh with aperture, not solid wall mesh")
		_assert(shadow_mesh.position.is_equal_approx(Vector3.ZERO), "ShadowCasterMesh position for window wall must align at Vector3.ZERO with visual wall")

	wall.queue_free()

func _test_window_glass_visual() -> void:
	var wall = WALL_SCENE.instantiate()
	root.add_child(wall)
	wall.configure_wall(3.0, 0.1)
	wall.set_window_variant(true)

	var pane: MeshInstance3D = wall.get_node_or_null("WindowGlassVisual") as MeshInstance3D
	_assert(pane != null, "WindowGlassVisual MeshInstance3D must exist")
	if pane != null:
		_assert(pane.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Glass pane must not cast shadow to allow sunlight to pass through")
		var mat = pane.material_override as ShaderMaterial
		_assert(mat != null, "Glass pane must use ShaderMaterial")
		if mat != null:
			_assert(mat.shader != null, "Glass pane ShaderMaterial must have a valid shader")

	wall.queue_free()
