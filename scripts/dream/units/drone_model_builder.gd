extends RefCounted
## Shared builder for the blocky drone.  Used by the model lab and by the
## in-game fire sample so both always produce the same mesh.

const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const METAL_SHADER := preload("res://shaders/dream3d/drone_metal_pixel.gdshader")
const OUTLINE_SHADER := preload("res://shaders/dream3d/drone_pixel_outline.gdshader")

const BODY_COLOR := Color("6c7786")
const PANEL_COLOR := Color("8794a3")
const PLATE_COLOR := Color("9aa7b4")
const POD_COLOR := Color("2f353d")
const BLADE_COLOR := Color("24282f")
const GUN_COLOR := Color("6d7886")
const VENT_COLOR := Color("1b1f25")
const HAZARD_COLOR := Color("c05a2e")
const TIP_COLOR := Color("d97a2e")
const EYE_COLOR := Color("e2453a")

const MUZZLE_LOCAL := Vector3(0.0, -0.17, -0.85)


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Drone3D"

	# metal, roughness, paint, glow — armour is brushed steel, the gun is dark
	# iron, painted accents stay dielectric.
	var body_material := surface_material(BODY_COLOR, "metal", 0.85, 0.60)
	var panel_material := surface_material(PANEL_COLOR, "paint", 0.82, 0.62)
	var panel_dark_material := surface_material(Color("57606b"), "paint", 0.82, 0.48)
	var plate_material := surface_material(PLATE_COLOR, "tile", 0.74, 0.50)
	var pod_material := surface_material(POD_COLOR, "metal", 0.92, 0.34)
	var blade_material := surface_material(BLADE_COLOR, "metal", 0.95, 0.30)
	var tip_material := surface_material(TIP_COLOR, "metal", 0.0, 0.50, 1.0)
	var gun_material := surface_material(GUN_COLOR, "metal", 0.95, 0.42)
	var barrel_material := surface_material(Color("2c3138"), "metal", 0.94, 0.36)
	var vent_material := surface_material(VENT_COLOR, "metal", 0.55, 0.55)
	var hazard_material := surface_material(HAZARD_COLOR, "paint", 0.0, 0.50, 1.0)
	var eye_material := surface_material(EYE_COLOR, "metal", 0.0, 0.45, 0.0, true)

	# One cube chassis.
	box(root, "Body", Vector3(0.80, 0.80, 0.80), Vector3.ZERO, body_material)

	# Layered armour plating: two stacked plates per vertical face, each a hair
	# proud of the hull, so every face reads as panels instead of one flat slab.
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		box(root, "PanelX%sUpper" % tag, Vector3(0.022, 0.28, 0.58), Vector3(side * 0.401, 0.14, 0.0), panel_material)
		box(root, "PanelX%sLower" % tag, Vector3(0.022, 0.30, 0.58), Vector3(side * 0.401, -0.19, 0.0), panel_dark_material)
		var ztag := "B" if side < 0.0 else "F"
		box(root, "PanelZ%sUpper" % ztag, Vector3(0.58, 0.28, 0.022), Vector3(0.0, 0.14, side * 0.401), panel_material)
		box(root, "PanelZ%sLower" % ztag, Vector3(0.58, 0.30, 0.022), Vector3(0.0, -0.19, side * 0.401), panel_dark_material)

	# Front dressing: hazard stripe, cooling vents, corner bolts.
	box(root, "HazardStripe", Vector3(0.40, 0.06, 0.016), Vector3(0.0, 0.02, -0.415), hazard_material)
	for vent_index in 3:
		box(root, "Vent%d" % vent_index, Vector3(0.30, 0.028, 0.014), Vector3(0.0, -0.13 - 0.05 * float(vent_index), -0.414), vent_material)
	for bolt_x in [-0.235, 0.235]:
		for bolt_y in [0.235, -0.30]:
			box(root, "Bolt%.2f_%.2f" % [bolt_x, bolt_y], Vector3(0.05, 0.05, 0.018), Vector3(bolt_x, bolt_y, -0.414), plate_material)

	# Single large rotor on the roof: motor cap, mast, hub, two crossed blades
	# with bright tip weights so the disc reads while spinning.
	box(root, "MotorCap", Vector3(0.30, 0.11, 0.30), Vector3(0.0, 0.455, 0.0), plate_material)
	box(root, "MotorCollar", Vector3(0.36, 0.04, 0.36), Vector3(0.0, 0.405, 0.0), pod_material)
	box(root, "Mast", Vector3(0.09, 0.10, 0.09), Vector3(0.0, 0.55, 0.0), vent_material)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 0.61, 0.0)
	root.add_child(rotor)
	box(rotor, "Hub", Vector3(0.16, 0.09, 0.16), Vector3.ZERO, blade_material)
	box(rotor, "HubCap", Vector3(0.07, 0.03, 0.07), Vector3(0.0, 0.055, 0.0), plate_material)
	for blade_index in 2:
		var blade := box(rotor, "Blade%d" % blade_index, Vector3(1.75, 0.022, 0.19), Vector3.ZERO, blade_material)
		blade.rotation.y = deg_to_rad(90.0 * float(blade_index))
		# Tips are children of the blade so they inherit its rotation.
		for tip_side in [-1.0, 1.0]:
			box(blade, "Tip%s" % ("A" if tip_side < 0.0 else "B"),
				Vector3(0.09, 0.028, 0.17), Vector3(tip_side * 0.858, 0.0, 0.0), tip_material)

	# Underslung weapon: mount, receiver, shroud, barrel, muzzle, magazine.
	var gun := Node3D.new()
	gun.name = "Weapon"
	gun.position = Vector3(0.0, -0.40, 0.0)
	root.add_child(gun)
	box(gun, "Mount", Vector3(0.20, 0.10, 0.24), Vector3(0.0, -0.05, 0.02), pod_material)
	box(gun, "Receiver", Vector3(0.26, 0.18, 0.46), Vector3(0.0, -0.17, 0.02), gun_material)
	box(gun, "FeedCover", Vector3(0.28, 0.05, 0.22), Vector3(0.0, -0.075, 0.02), panel_dark_material)
	box(gun, "BarrelShroud", Vector3(0.13, 0.13, 0.32), Vector3(0.0, -0.17, -0.34), pod_material)
	box(gun, "Barrel", Vector3(0.065, 0.065, 0.32), Vector3(0.0, -0.17, -0.65), barrel_material)
	box(gun, "MuzzleBrake", Vector3(0.145, 0.145, 0.11), MUZZLE_LOCAL, pod_material)
	box(gun, "MuzzleBand", Vector3(0.155, 0.055, 0.03), Vector3(0.0, -0.17, -0.80), hazard_material)
	var magazine := box(gun, "Magazine", Vector3(0.14, 0.24, 0.18), Vector3(0.0, -0.34, 0.12), barrel_material)
	magazine.rotation.x = deg_to_rad(12.0)
	var magazine_band := box(gun, "MagazineBand", Vector3(0.145, 0.05, 0.185), Vector3(0.0, -0.40, 0.135), hazard_material)
	magazine_band.rotation.x = deg_to_rad(12.0)
	# Red sensor strip on the front face, facing -Z (Godot forward).
	box(root, "SensorEye", Vector3(0.15, 0.06, 0.022), Vector3(0.0, 0.14, -0.414), eye_material)

	apply_outline(root)
	return root


## Pixel metal material: same swatch texture, but with a real METALLIC /
## ROUGHNESS / SPECULAR response so the model reads as iron instead of flat
## matte paint.
static func surface_material(
	color: Color,
	kind: String,
	metallic := 0.9,
	roughness := 0.32,
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


## One-pixel white inverted-hull outline, the same language the game uses
## around enemies.
static func apply_outline(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		mesh.material_overlay = material


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
