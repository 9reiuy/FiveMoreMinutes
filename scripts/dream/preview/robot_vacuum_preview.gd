extends SceneTree
## Model lab for the cylindrical robot vacuum.  Builds it, saves a reusable
## scene, then renders turntable + detail stills (including the underside with
## the side brushes).  Run windowed:
##   godot --path <project> --script res://scripts/dream/preview/robot_vacuum_preview.gd

const OUT_DIR := "E:/GameProjects/AIWorkspaces/robot_vacuum_preview/"
const SCENE_PATH := "res://scenes/dream/3d/props/robot_vacuum_3d.tscn"
const BUILDER := preload("res://scripts/dream/preview/robot_vacuum_builder.gd")
const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const SHADOW_SHADER := preload("res://shaders/dream3d/office_contact_shadow.gdshader")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var robot := BUILDER.build()
	_save_scene(robot)

	var viewport := _make_viewport()
	_add_floor(viewport)
	viewport.add_child(robot)
	var camera := _make_camera()
	viewport.add_child(camera)
	await _settle(4)

	_aim(camera, Vector3(0.52, 0.32, 0.58), Vector3(0.0, 0.055, 0.0))
	await _settle(3)
	_capture(viewport, "hero.png")

	_aim(camera, Vector3(0.0, 0.80, 0.02), Vector3(0.0, 0.03, 0.0))
	await _settle(3)
	_capture(viewport, "top.png")

	_aim(camera, Vector3(0.46, -0.52, 0.52), Vector3(0.0, 0.02, 0.0))
	await _settle(3)
	_capture(viewport, "bottom.png")

	_aim(camera, Vector3(0.72, 0.12, 0.0), Vector3(0.0, 0.05, 0.0))
	await _settle(3)
	_capture(viewport, "side.png")

	_aim(camera, Vector3(0.52, 0.32, 0.58), Vector3(0.0, 0.055, 0.0))
	for frame in 16:
		robot.rotation.y = TAU * float(frame) / 16.0
		await _settle(2)
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(OUT_DIR + "frame_%02d.png" % frame)
	print("TURNTABLE_DONE")
	print("SCENE_SAVED: ", SCENE_PATH)
	print("VACUUM_DONE")
	quit(0)


func _save_scene(robot: Node3D) -> void:
	_assign_owner(robot, robot)
	var packed := PackedScene.new()
	var error := packed.pack(robot)
	if error != OK:
		print("SCENE_PACK_FAILED: ", error)
		return
	error = ResourceSaver.save(packed, SCENE_PATH)
	print("SCENE_SAVE_ERR: ", error)


func _assign_owner(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_assign_owner(child, root_node)


func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("26314a")
	sky_material.sky_horizon_color = Color("33405a")
	sky_material.sky_curve = 0.15
	sky_material.ground_horizon_color = Color("33405a")
	sky_material.ground_bottom_color = Color("141a24")
	sky_material.sun_angle_max = 0.0
	sky_material.sky_energy_multiplier = 0.45
	sky_material.ground_energy_multiplier = 0.45
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f86b8")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("eaf2ff")
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.shadow_blur = 2.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 6.0
	key.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(58.0), 0.0)
	viewport.add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = Color("7d9bff")
	fill.light_energy = 1.3
	fill.omni_range = 5.0
	fill.position = Vector3(-0.9, 0.7, -0.6)
	viewport.add_child(fill)

	# Underside fill: without it the whole brush deck renders as black navy.
	var under := OmniLight3D.new()
	under.light_color = Color("9fb4ff")
	under.light_energy = 1.5
	under.omni_range = 1.6
	under.position = Vector3(0.25, -0.42, 0.30)
	viewport.add_child(under)

	var rim := OmniLight3D.new()
	rim.light_color = Color("ffab6a")
	rim.light_energy = 0.9
	rim.omni_range = 4.0
	rim.position = Vector3(0.8, 0.35, 0.9)
	viewport.add_child(rim)
	return viewport


func _add_floor(viewport: SubViewport) -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(3.0, 3.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "Floor"
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = PIXEL_MATERIALS.make(Color("31394a"), "floor_tile", true)
	viewport.add_child(floor_instance)

	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(0.52, 0.52)
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = shadow_mesh
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	shadow_material.set_shader_parameter("shadow_opacity", 0.5)
	shadow.material_override = shadow_material
	shadow.rotation.x = -PI * 0.5
	shadow.position = Vector3(0.0, 0.004, 0.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(shadow)


func _make_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.02
	camera.far = 60.0
	return camera


func _aim(camera: Camera3D, position: Vector3, target: Vector3) -> void:
	camera.position = position
	camera.look_at(target, Vector3.UP)


func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame


func _capture(viewport: SubViewport, file_name: String) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		print("CAPTURE_FAILED: ", file_name)
		return
	image.save_png(OUT_DIR + file_name)
	print("CAPTURED: ", file_name)
