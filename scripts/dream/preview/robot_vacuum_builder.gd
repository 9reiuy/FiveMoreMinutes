extends RefCounted
## Cylindrical robot vacuum, built from the same pixel/material language as the
## drone: pixel swatch textures, white 1px outline, real metal response.

const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const METAL_SHADER := preload("res://shaders/dream3d/drone_metal_pixel.gdshader")
const OUTLINE_SHADER := preload("res://shaders/dream3d/drone_pixel_outline.gdshader")

const BODY_COLOR := Color("4f5a67")
const TOP_COLOR := Color("626d7a")
const DARK_COLOR := Color("2b313a")
const RUBBER_COLOR := Color("171b21")
const BRUSH_COLOR := Color("d8a13c")
const ROLLER_COLOR := Color("3d444e")
const GLASS_COLOR := Color("161c24")
const LED_COLOR := Color("5ee0b0")

const RADIUS := 0.185
const HEIGHT := 0.072
const SEGMENTS := 18


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "RobotVacuum"

	var body_material := surface_material(BODY_COLOR, "metal", 0.26, 0.56)
	var top_material := surface_material(TOP_COLOR, "paint", 0.22, 0.50)
	var dark_material := surface_material(DARK_COLOR, "metal", 0.30, 0.58)
	var rubber_material := surface_material(RUBBER_COLOR, "metal", 0.05, 0.78)
	var brush_material := surface_material(BRUSH_COLOR, "metal", 0.20, 0.60)
	var roller_material := surface_material(ROLLER_COLOR, "tile", 0.25, 0.66)
	var glass_material := surface_material(GLASS_COLOR, "metal", 0.55, 0.24)
	var led_material := surface_material(LED_COLOR, "metal", 0.0, 0.35, 0.0, true)

	# The hull floats on its wheels: base_y is the underside plane, so the brush
	# deck sits between it and the floor instead of inside the body.
	var base_y := 0.020
	var top_y := base_y + HEIGHT

	cylinder(root, "Chassis", RADIUS, HEIGHT, Vector3(0.0, base_y + HEIGHT * 0.5, 0.0), body_material)
	cylinder(root, "Bumper", RADIUS * 1.015, 0.024, Vector3(0.0, base_y + 0.016, 0.0), dark_material)
	box(root, "BumperSensor", Vector3(0.36, 0.012, 0.012), Vector3(0.0, base_y + 0.018, -RADIUS * 1.02), rubber_material)

	# Top plate with a recessed seam ring.
	cylinder(root, "TopPlate", RADIUS * 0.94, 0.010, Vector3(0.0, top_y + 0.005, 0.0), top_material)
	cylinder(root, "SeamRing", RADIUS * 0.97, 0.005, Vector3(0.0, top_y + 0.001, 0.0), dark_material)

	# LiDAR turret and its glass window.
	cylinder(root, "LidarBase", 0.056, 0.016, Vector3(0.0, top_y + 0.018, 0.0), dark_material, 12)
	cylinder(root, "LidarGlass", 0.050, 0.020, Vector3(0.0, top_y + 0.034, 0.0), glass_material, 12)
	cylinder(root, "LidarCap", 0.042, 0.006, Vector3(0.0, top_y + 0.047, 0.0), top_material, 12)

	# Control island: display strip, two buttons, status LED.
	var deck_y := top_y + 0.012
	box(root, "Display", Vector3(0.105, 0.004, 0.040), Vector3(0.0, deck_y, 0.088), glass_material)
	box(root, "DisplayGlow", Vector3(0.085, 0.002, 0.020), Vector3(0.0, deck_y + 0.003, 0.088), led_material)
	box(root, "ButtonHome", Vector3(0.036, 0.008, 0.026), Vector3(-0.062, deck_y, 0.130), dark_material)
	box(root, "ButtonPower", Vector3(0.026, 0.008, 0.026), Vector3(0.062, deck_y, 0.130), dark_material)
	box(root, "StatusLed", Vector3(0.014, 0.004, 0.010), Vector3(0.0, deck_y + 0.002, 0.140), led_material)

	# Light underside plate so the dark brush deck and hatch read against it.
	cylinder(root, "UndersidePlate", RADIUS * 0.92, 0.005, Vector3(0.0, base_y - 0.002, 0.0),
		surface_material(Color("5a6572"), "tile", 0.28, 0.60))

	# Underside deck.  Wheels touch the floor, everything else clears it.
	for side in [-1.0, 1.0]:
		var wheel := cylinder(root, "Wheel%s" % ("L" if side < 0.0 else "R"), 0.020, 0.022,
			Vector3(side * RADIUS * 0.70, 0.020, 0.02), rubber_material, 12)
		wheel.rotation.z = deg_to_rad(90.0)
	cylinder(root, "Caster", 0.010, 0.010, Vector3(0.0, 0.010, -RADIUS * 0.60), dark_material, 10)

	var roller := cylinder(root, "RollerBrush", 0.012, 0.26, Vector3(0.0, base_y - 0.003, -RADIUS * 0.40), roller_material, 12)
	roller.rotation.z = deg_to_rad(90.0)
	for index in 5:
		var band := cylinder(root, "RollerBand%d" % index, 0.014, 0.010,
			Vector3(-0.09 + 0.045 * float(index), base_y - 0.003, -RADIUS * 0.40), brush_material, 10)
		band.rotation.z = deg_to_rad(90.0)

	# Battery hatch and brush guard plate.
	box(root, "BatteryHatch", Vector3(0.14, 0.006, 0.09), Vector3(0.0, base_y - 0.001, 0.055), dark_material)
	box(root, "BrushGuard", Vector3(0.28, 0.006, 0.05), Vector3(0.0, base_y - 0.001, -RADIUS * 0.40), dark_material)

	# Three-armed side brushes, mirrored left/right.
	for side in [-1.0, 1.0]:
		var hub := Node3D.new()
		hub.name = "SideBrush%s" % ("L" if side < 0.0 else "R")
		hub.position = Vector3(side * RADIUS * 0.72, base_y - 0.010, -RADIUS * 0.55)
		root.add_child(hub)
		cylinder(hub, "Hub", 0.012, 0.008, Vector3.ZERO, dark_material, 8)
		for arm in 3:
			var blade := box(hub, "Arm%d" % arm, Vector3(0.080, 0.004, 0.010), Vector3(0.042, 0.0, 0.0), brush_material)
			blade.rotation.y = deg_to_rad(120.0 * float(arm))

	apply_outline(root)
	return root


static func cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	segments := SEGMENTS
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


static func surface_material(
	color: Color,
	kind: String,
	metallic := 0.3,
	roughness := 0.5,
	paint := 0.0,
	glow := false
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = METAL_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("pixel_texture", PIXEL_MATERIALS.swatch(kind))
	material.set_shader_parameter("object_space", true)
	material.set_shader_parameter("metallic_amount", metallic)
	material.set_shader_parameter("roughness_amount", roughness)
	material.set_shader_parameter("specular_amount", 0.30)
	material.set_shader_parameter("paint_amount", paint)
	material.set_shader_parameter("glow", glow)
	return material


static func apply_outline(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		mesh.material_overlay = material
