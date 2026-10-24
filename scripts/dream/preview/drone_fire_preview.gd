extends SceneTree
## Builds the in-game drone fire sample: a small night office room dressed with
## the project's pixel floor/wall materials, the drone hovering with its
## underslung gun firing.  Saves the scene, then renders stills + a firing loop.
##
## Run windowed (headless cannot read the SubViewport back):
##   godot --path <project> --script res://scripts/dream/preview/drone_fire_preview.gd

const OUT_DIR := "E:/GameProjects/AIWorkspaces/drone_preview/"
const SAMPLE_SCENE := "res://scenes/dream/preview/DroneFireSample.tscn"
const DRONE_BUILDER := preload("res://scripts/dream/units/drone_model_builder.gd")
const FIRE_RIG := preload("res://scripts/dream/units/drone_weapon_fire.gd")
const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")

## Time since ignition per turntable frame: idle, the flash, its decay, then rest.
const FLASH_FRAMES := [9.0, 9.0, 0.0, 0.02, 0.045, 0.07, 0.10, 0.15, 0.30, 0.55, 9.0, 9.0]

var fire_rig: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sample := build_sample()
	_save_scene(sample)

	var viewport := _make_viewport()
	viewport.add_child(sample)
	var camera := _make_camera()
	viewport.add_child(camera)

	await _settle(6)
	fire_rig.set("auto_fire", false)

	# Idle still.
	fire_rig.call("set_flash_time", 9.0)
	await _settle(3)
	_capture(viewport, "fire_idle.png")

	# Peak flash still.
	fire_rig.call("set_flash_time", 0.03)
	await _settle(3)
	_capture(viewport, "fire_peak.png")

	# Decaying flash still.
	fire_rig.call("set_flash_time", 0.09)
	await _settle(3)
	_capture(viewport, "fire_decay.png")

	# Firing loop.
	for index in FLASH_FRAMES.size():
		fire_rig.call("set_flash_time", float(FLASH_FRAMES[index]))
		await _settle(2)
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(OUT_DIR + "fire_%02d.png" % index)
	print("FIRE_FRAMES_DONE: ", FLASH_FRAMES.size())
	print("SAMPLE_SCENE: ", SAMPLE_SCENE)
	print("DRONE_FIRE_DONE")
	quit(0)


func build_sample() -> Node3D:
	var root := Node3D.new()
	root.name = "DroneFireSample"

	_make_environment(root)
	_make_room(root)

	# Drone hovering over the room centre, turned a little so the gun reads.
	var drone := DRONE_BUILDER.build()
	drone.name = "Drone"
	drone.position = Vector3(0.0, 1.15, 0.0)
	drone.rotation.y = deg_to_rad(146.0)
	root.add_child(drone)

	# Fire rig sits on the muzzle brake, so the flash follows the weapon.
	var muzzle := drone.get_node_or_null("Weapon/MuzzleBrake") as Node3D
	if muzzle == null:
		print("FIRE_RIG_FAILED: no MuzzleBrake")
	else:
		fire_rig = FIRE_RIG.new()
		fire_rig.name = "MuzzleFire"
		fire_rig.set("auto_fire", true)
		muzzle.add_child(fire_rig)

	return root


func _make_room(root: Node3D) -> void:
	var floor_material := PIXEL_MATERIALS.make(Color("2b323d"), "floor_tile", true)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18.0, 18.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "Floor"
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_material
	root.add_child(floor_instance)

	var wall_material := PIXEL_MATERIALS.make(Color("39424f"), "tile", true)
	var back_wall := DRONE_BUILDER.box(root, "WallBack", Vector3(16.0, 3.6, 0.24), Vector3(0.0, 1.8, -6.4), wall_material)
	back_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	DRONE_BUILDER.box(root, "WallLeft", Vector3(0.24, 3.6, 14.0), Vector3(-7.2, 1.8, 0.0), wall_material)

	# A few crates for scale and for the muzzle light to catch on.
	var crate_material := PIXEL_MATERIALS.make(Color("4a5563"), "wood", true)
	var crate_dark := PIXEL_MATERIALS.make(Color("333b46"), "wood", true)
	var crates := [
		{"pos": Vector3(-2.6, 0.45, -3.2), "size": 0.9, "mat": crate_material},
		{"pos": Vector3(-1.5, 0.35, -4.0), "size": 0.7, "mat": crate_dark},
		{"pos": Vector3(2.8, 0.5, -3.6), "size": 1.0, "mat": crate_material},
		{"pos": Vector3(3.4, 0.3, -2.4), "size": 0.6, "mat": crate_dark},
	]
	for index in crates.size():
		var crate: Dictionary = crates[index]
		var side: float = crate["size"]
		var crate_mesh := DRONE_BUILDER.box(root, "Crate%d" % index, Vector3(side, side, side),
			crate["pos"], crate["mat"])
		crate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _make_environment(root: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0e131c")
	sky_material.sky_horizon_color = Color("1b2431")
	sky_material.sky_curve = 0.12
	sky_material.ground_horizon_color = Color("1b2431")
	sky_material.ground_bottom_color = Color("080b10")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("51627f")
	environment.ambient_light_energy = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	root.add_child(world_environment)

	# Dim overhead office light; the muzzle flash is the bright event.
	var lamp := OmniLight3D.new()
	lamp.name = "CeilingLamp"
	lamp.light_color = Color("9fb6e6")
	lamp.light_energy = 3.2
	lamp.omni_range = 14.0
	lamp.position = Vector3(0.0, 4.2, -1.2)
	lamp.shadow_enabled = true
	root.add_child(lamp)

	# Fill from the camera side so the hull's metal still reads.
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("7d9bff")
	fill.light_energy = 2.4
	fill.omni_range = 12.0
	fill.position = Vector3(2.4, 2.6, 4.2)
	root.add_child(fill)


func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _make_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.05
	camera.far = 120.0
	# Game-like high three-quarter view: the muzzle light has to spill onto the
	# floor for the effect to read the way it will in play.
	camera.position = Vector3(0.55, 2.05, 5.40)
	camera.look_at(Vector3(0.0, 0.90, 0.10), Vector3.UP)
	return camera


func _save_scene(sample: Node3D) -> void:
	# Runtime-only children (flash quads, lights built in _ready) have no owner
	# and are therefore excluded, so the saved sample rebuilds them on load.
	_assign_owner(sample, sample)
	var packed := PackedScene.new()
	var error := packed.pack(sample)
	if error != OK:
		print("SAMPLE_PACK_FAILED: ", error)
		return
	error = ResourceSaver.save(packed, SAMPLE_SCENE)
	print("SAMPLE_SAVED: ", SAMPLE_SCENE, " err=", error)


func _assign_owner(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_assign_owner(child, root_node)


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
