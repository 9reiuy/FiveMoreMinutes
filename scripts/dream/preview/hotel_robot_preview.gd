extends SceneTree
## Model lab for the hotel delivery robot: builds it, saves the scene, renders
## one still per LCD expression plus a 3/4 hero, a top view and a face loop.
## Run windowed:
##   godot --path <project> --script res://scripts/dream/preview/hotel_robot_preview.gd

const OUT_DIR := "E:/GameProjects/AIWorkspaces/hotel_robot_preview/"
const SCENE_PATH := "res://scenes/dream/3d/props/hotel_delivery_robot_3d.tscn"
const BUILDER := preload("res://scripts/dream/units/hotel_robot_builder.gd")
const FACE_ART := preload("res://scripts/dream/units/robot_face_art.gd")
const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const SHADOW_SHADER := preload("res://shaders/dream3d/office_contact_shadow.gdshader")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var robot := BUILDER.build("calm")
	_save_scene(robot)
	var slab := robot.get_node_or_null("FrontSlab") as MeshInstance3D
	if slab != null:
		var slab_material := slab.material_override as ShaderMaterial
		if slab_material != null:
			var panel_texture: Variant = slab_material.get_shader_parameter("panel_texture")
			if panel_texture is ImageTexture:
				(panel_texture as ImageTexture).get_image().save_png(OUT_DIR + "front_panel_texture.png")

	var viewport := _make_viewport()
	_add_floor(viewport)
	viewport.add_child(robot)
	var camera := _make_camera()
	viewport.add_child(camera)
	await _settle(4)

	# One still per expression, straight on so the LCD is readable.
	_aim(camera, Vector3(0.0, 0.64, 2.30), Vector3(0.0, 0.60, 0.0))
	for expression in FACE_ART.EXPRESSIONS:
		BUILDER.apply_expression(robot, expression)
		await _settle(3)
		_capture(viewport, "face_%s.png" % expression)

	# Weapon deployment: front view shows both bays opening symmetrically.
	var rig := robot.get_node_or_null("WeaponRig")
	if rig != null:
		rig.set("auto_cycle", false)
		_aim(camera, Vector3(0.95, 0.98, 2.05), Vector3(0.0, 0.58, 0.0))
		for step in [0.0, 0.25, 0.5, 0.75, 1.0]:
			rig.call("set_deploy", step)
			await _settle(3)
			_capture(viewport, "deploy_%03d.png" % int(round(step * 100.0)))
		_aim(camera, Vector3(1.05, 1.10, 1.95), Vector3(0.0, 0.56, 0.0))
		await _settle(3)
		_capture(viewport, "deployed_hero.png")

		# Deployment loop: 20 frames from stowed to locked forward.
		_aim(camera, Vector3(0.95, 0.98, 2.05), Vector3(0.0, 0.58, 0.0))
		for frame in 20:
			rig.call("set_deploy", clampf(float(frame) / 15.0, 0.0, 1.0))
			await _settle(2)
			var image := viewport.get_texture().get_image()
			if image != null:
				image.save_png(OUT_DIR + "deploy_%02d.png" % frame)
		rig.call("set_deploy", 0.0)
		print("DEPLOY_FRAMES: 20")

	# Hero three-quarter and a top view for the silhouette.
	BUILDER.apply_expression(robot, "calm")
	_aim(camera, Vector3(1.05, 1.20, 1.95), Vector3(0.0, 0.56, 0.0))
	await _settle(3)
	_capture(viewport, "hero.png")

	_aim(camera, Vector3(0.55, 2.30, 0.70), Vector3(0.0, 0.56, 0.0))
	await _settle(3)
	_capture(viewport, "top.png")

	# Face loop: four frames per expression.
	_aim(camera, Vector3(0.0, 0.64, 2.30), Vector3(0.0, 0.60, 0.0))
	var index := 0
	for expression in FACE_ART.EXPRESSIONS:
		BUILDER.apply_expression(robot, expression)
		for _repeat in 4:
			await _settle(2)
			var image := viewport.get_texture().get_image()
			if image != null:
				image.save_png(OUT_DIR + "face_%02d.png" % index)
			index += 1
	print("FACE_FRAMES: ", index)
	print("SCENE_SAVED: ", SCENE_PATH)
	print("ROBOT_DONE")
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
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("eaf2ff")
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.shadow_blur = 2.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 8.0
	key.rotation = Vector3(deg_to_rad(-54.0), deg_to_rad(46.0), 0.0)
	viewport.add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = Color("7d9bff")
	fill.light_energy = 1.2
	fill.omni_range = 4.5
	fill.position = Vector3(-1.1, 0.9, 1.0)
	viewport.add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = Color("ffab6a")
	rim.light_energy = 0.9
	rim.omni_range = 4.0
	rim.position = Vector3(1.0, 0.6, -0.9)
	viewport.add_child(rim)
	return viewport


func _add_floor(viewport: SubViewport) -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(4.0, 4.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "Floor"
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = PIXEL_MATERIALS.make(Color("2f3744"), "floor_tile", true)
	viewport.add_child(floor_instance)

	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(0.72, 0.72)
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
	camera.fov = 30.0
	camera.near = 0.03
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
