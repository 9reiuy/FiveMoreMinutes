extends SceneTree
## Standalone model lab for the blocky drone.  Builds the mesh procedurally
## with the project's own pixel material, saves it as a reusable scene, then
## renders preview stills and a turntable.  Nothing here is referenced by
## gameplay; run with:
##   godot --headless --path <project> --script res://scripts/dream/preview/drone_model_preview.gd

const OUT_DIR := "E:/GameProjects/AIWorkspaces/drone_preview/"
const SCENE_PATH := "res://scenes/dream/3d/props/drone_3d_pixel.tscn"
const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const DRONE_BUILDER := preload("res://scripts/dream/units/drone_model_builder.gd")

const BODY_COLOR := Color("6c7786")
const PANEL_COLOR := Color("8794a3")
const PLATE_COLOR := Color("9aa7b4")
const POD_COLOR := Color("2f353d")
const BLADE_COLOR := Color("24282f")
const GUN_COLOR := Color("6d7886")
const GUN_BARREL_COLOR := Color("20242a")
const VENT_COLOR := Color("1b1f25")
const HAZARD_COLOR := Color("c05a2e")
const TIP_COLOR := Color("d97a2e")
const EYE_COLOR := Color("e2453a")

var rotors: Array[Node3D] = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var drone := build_drone()
	_save_scene(drone)

	var viewport := _make_viewport()
	viewport.add_child(drone)
	var camera := _make_camera()
	viewport.add_child(camera)

	await _settle(4)

	# The nose (sensor + gun barrel) points down -Z, so the camera lives there.
	# Hero 3/4.
	_aim(camera, Vector3(1.80, 1.02, -2.35), Vector3(0.0, -0.06, 0.0))
	await _settle(3)
	_capture(viewport, "hero.png")

	# Bottom view: the underslung weapon is the point of this angle.
	_aim(camera, Vector3(1.70, -1.35, -2.30), Vector3(0.0, -0.28, 0.0))
	await _settle(3)
	_capture(viewport, "bottom.png")

	# Low front quarter: nose sensor and the gun in one frame.
	_aim(camera, Vector3(1.65, -0.12, -2.50), Vector3(0.0, -0.16, -0.14))
	await _settle(3)
	_capture(viewport, "front_low.png")

	# Side profile.
	_aim(camera, Vector3(3.40, 0.28, 0.0), Vector3(0.0, -0.12, 0.0))
	await _settle(3)
	_capture(viewport, "side.png")

	# Turntable: 16 steps, the single rotor spins so the blades read.
	_aim(camera, Vector3(1.80, 1.02, -2.35), Vector3(0.0, -0.06, 0.0))
	for frame in 16:
		drone.rotation.y = TAU * float(frame) / 16.0
		for rotor in rotors:
			rotor.rotation.y = float(frame) * deg_to_rad(55.0)
		await _settle(2)
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(OUT_DIR + "frame_%02d.png" % frame)
	print("TURNTABLE_DONE: 16 frames")
	print("DRONE_DONE")
	quit(0)


func build_drone() -> Node3D:
	var drone := DRONE_BUILDER.build()
	var rotor := drone.find_child("Rotor", true, false) as Node3D
	if rotor != null:
		rotors.append(rotor)
	return drone


func _save_scene(drone: Node3D) -> void:
	# pack() only serialises nodes whose owner points at the packed root; nodes
	# created by add_child() have owner == null, which saved an empty scene.
	_assign_owner(drone, drone)
	var packed := PackedScene.new()
	var error := packed.pack(drone)
	if error != OK:
		print("SCENE_PACK_FAILED: ", error)
		return
	error = ResourceSaver.save(packed, SCENE_PATH)
	print("SCENE_SAVED: ", SCENE_PATH, " err=", error)


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

	# A sky is mandatory: metal reflects the environment, so a flat BG_COLOR
	# leaves every METALLIC surface black.  The gradient doubles as the backdrop.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("26314a")
	sky_material.sky_horizon_color = Color("33405a")
	sky_material.sky_curve = 0.15
	sky_material.ground_horizon_color = Color("33405a")
	sky_material.ground_bottom_color = Color("141a24")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f86b8")
	environment.ambient_light_energy = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("eaf2ff")
	key.light_energy = 2.8
	key.shadow_enabled = true
	key.shadow_blur = 2.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 10.0
	key.rotation = Vector3(deg_to_rad(-56.0), deg_to_rad(62.0), 0.0)
	viewport.add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = Color("7d9bff")
	fill.light_energy = 3.2
	fill.omni_range = 9.0
	fill.position = Vector3(-2.2, 1.5, -1.2)
	viewport.add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = Color("ffab6a")
	rim.light_energy = 2.0
	rim.omni_range = 8.0
	rim.position = Vector3(1.9, 0.8, 2.2)
	viewport.add_child(rim)

	# Under-slung fill: the weapon lives in the body's shadow without it.
	var under := OmniLight3D.new()
	under.light_color = Color("9fb4ff")
	under.light_energy = 1.8
	under.omni_range = 4.5
	under.position = Vector3(0.6, -1.25, -1.1)
	viewport.add_child(under)
	return viewport


func _make_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = 100.0
	return camera


func _aim(camera: Camera3D, position: Vector3, target: Vector3) -> void:
	camera.position = position
	camera.look_at(target, Vector3.UP)


func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame


func _capture(viewport: SubViewport, file_name: String) -> void:
	# Windowed run: the display loop already draws; in --headless the render
	# target stays empty, so this lab is always launched with a window.
	var image := viewport.get_texture().get_image()
	if image == null:
		print("CAPTURE_FAILED: ", file_name)
		return
	image.save_png(OUT_DIR + file_name)
	print("CAPTURED: ", file_name)
