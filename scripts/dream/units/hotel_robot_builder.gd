extends RefCounted
## Hotel delivery robot: tall white cylinder, dark visor, pixel LCD face.
## The screen material is exposed so callers can swap expressions at runtime.

const PIXEL_MATERIALS := preload("res://scripts/dream/office_pixel_materials.gd")
const METAL_SHADER := preload("res://shaders/dream3d/drone_metal_pixel.gdshader")
const OUTLINE_SHADER := preload("res://shaders/dream3d/drone_pixel_outline.gdshader")
const SCREEN_SHADER := preload("res://shaders/dream3d/hotel_robot_screen.gdshader")
const PANEL_SHADER := preload("res://shaders/dream3d/hotel_robot_panel.gdshader")
const FACE_ART := preload("res://scripts/dream/units/robot_face_art.gd")
const WEAPON_RIG := preload("res://scripts/dream/units/hotel_robot_weapons.gd")

const SHELL_COLOR := Color("b3bcc6")
const SHELL_SHADE := Color("8b95a1")
const TRIM_COLOR := Color("2c333c")
const GLASS_COLOR := Color("0b1119")
const RUBBER_COLOR := Color("12161b")
const ACCENT_COLOR := Color("6fe3ff")

const RADIUS := 0.25
const BODY_BOTTOM := 0.05
const BODY_TOP := 0.86
const SHOULDER_TOP := 0.99

static func build(expression := "calm") -> Node3D:
	var root := Node3D.new()
	root.name = "HotelDeliveryRobot"

	var shell := surface_material(SHELL_COLOR, "paint", 0.10, 0.52)
	var shell_shade := surface_material(SHELL_SHADE, "tile", 0.12, 0.58)
	var trim := surface_material(TRIM_COLOR, "metal", 0.25, 0.55)
	var glass := surface_material(GLASS_COLOR, "metal", 0.55, 0.18)
	var rubber := surface_material(RUBBER_COLOR, "metal", 0.05, 0.80)
	var accent := surface_material(ACCENT_COLOR, "metal", 0.0, 0.30, 0.0, true)

	# Plinth, main drum and the tapered shoulder.
	cylinder(root, "Plinth", 0.262, 0.262, 0.050, Vector3(0.0, 0.025, 0.0), rubber, 10)
	cylinder(root, "Body", RADIUS, RADIUS, BODY_TOP - BODY_BOTTOM,
		Vector3(0.0, (BODY_TOP + BODY_BOTTOM) * 0.5, 0.0), shell, 10)
	cylinder(root, "Shoulder", 0.212, RADIUS, SHOULDER_TOP - BODY_TOP,
		Vector3(0.0, (SHOULDER_TOP + BODY_TOP) * 0.5, 0.0), shell, 10)
	var dome := SphereMesh.new()
	dome.radius = 0.212
	dome.height = 0.130
	dome.radial_segments = 10
	dome.rings = 4
	var dome_instance := MeshInstance3D.new()
	dome_instance.name = "Dome"
	dome_instance.mesh = dome
	dome_instance.material_override = shell
	dome_instance.position = Vector3(0.0, SHOULDER_TOP, 0.0)
	root.add_child(dome_instance)

	# Seam ring where the shoulder meets the drum.
	cylinder(root, "SeamRing", 0.253, 0.253, 0.008, Vector3(0.0, BODY_TOP, 0.0), shell_shade, 10)
	# Status ring under the dome, glowing faintly.
	cylinder(root, "StatusRing", 0.208, 0.208, 0.010, Vector3(0.0, SHOULDER_TOP - 0.012, 0.0), accent, 10)

	# Flat front face: the cylinder alone cannot carry a screen, a flat slab
	# set into the hull gives the visor a surface to sit flush on.
	var slab_mesh := MeshInstance3D.new()
	slab_mesh.name = "FrontSlab"
	var slab_box := BoxMesh.new()
	slab_box.size = Vector3(0.300, 0.900, 0.160)
	slab_mesh.mesh = slab_box
	slab_mesh.material_override = front_panel_material()
	slab_mesh.position = Vector3(0.0, 0.500, 0.170)
	root.add_child(slab_mesh)
	box(root, "FrontSlabEdge", Vector3(0.306, 0.010, 0.166), Vector3(0.0, 0.948, 0.170), shell_shade)

	# Face panel: dark visor with the LCD inside it, flush with the slab.
	var panel := Node3D.new()
	panel.name = "FacePanel"
	panel.position = Vector3(0.0, 0.870, 0.245)
	root.add_child(panel)
	box(panel, "VisorBezel", Vector3(0.300, 0.190, 0.030), Vector3.ZERO, glass)
	box(panel, "VisorLip", Vector3(0.312, 0.014, 0.036), Vector3(0.0, -0.100, -0.001), trim)

	var screen_material := ShaderMaterial.new()
	screen_material.shader = SCREEN_SHADER
	screen_material.set_shader_parameter("screen_texture", FACE_ART.texture_for(expression))
	var screen := MeshInstance3D.new()
	screen.name = "FaceScreen"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.262, 0.146)
	screen.mesh = quad
	screen.material_override = screen_material
	screen.position = Vector3(0.0, 0.003, 0.017)
	
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(screen)

	# Front vents near the plinth.
	for index in 3:
		box(root, "Vent%d" % index, Vector3(0.110, 0.010, 0.008),
			Vector3(0.0, 0.135 + 0.030 * float(index), 0.256), trim)

	# Side weapon bays: flush hatch, telescoping arm, compact cannon.
	var rig := WEAPON_RIG.new()
	rig.name = "WeaponRig"
	root.add_child(rig)
	for side in [-1.0, 1.0]:
		build_weapon_bay(rig, side, trim, rubber, shell, shell_shade, accent)

	# Drive wheels peeking out of the plinth.
	for side in [-1.0, 1.0]:
		var wheel := cylinder(root, "Wheel%s" % ("L" if side < 0.0 else "R"),
			0.036, 0.036, 0.028, Vector3(side * 0.155, 0.036, 0.020), rubber, 8)
		wheel.rotation.z = deg_to_rad(90.0)

	apply_outline(root)
	return root


## Swap the LCD face on a built robot.
static func apply_expression(root: Node3D, expression: String) -> void:
	var screen := root.get_node_or_null("FacePanel/FaceScreen") as MeshInstance3D
	if screen == null:
		return
	var material := screen.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("screen_texture", FACE_ART.texture_for(expression))


static func cylinder(
	parent: Node3D,
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position: Vector3,
	material: Material,
	segments := 20
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
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
	metallic := 0.25,
	roughness := 0.55,
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
		# The face stack is inset into the hull; an inverted-hull outline there
		# only draws stray white seams around the bezel.
		var parent := mesh.get_parent()
		if parent != null and parent.name == "FacePanel":
			continue
		if String(mesh.name).begins_with("Cabinet"):
			continue
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		mesh.material_overlay = material


static func build_weapon_bay(
	parent: Node3D,
	side: float,
	trim: Material,
	rubber: Material,
	shell: Material,
	shell_shade: Material,
	accent: Material
) -> void:
	var bay := Node3D.new()
	bay.name = "BayL" if side < 0.0 else "BayR"
	bay.position = Vector3(0.0, 0.560, 0.020)
	parent.add_child(bay)

	# Dark launch slot flush with the hull, framed by two trim strips.
	box(bay, "RecessPanel", Vector3(0.014, 0.185, 0.320), Vector3(side * 0.246, 0.0, 0.0), trim)
	box(bay, "SlotFrameTop", Vector3(0.018, 0.014, 0.344), Vector3(side * 0.246, 0.100, 0.0), shell_shade)
	box(bay, "SlotFrameBottom", Vector3(0.018, 0.014, 0.344), Vector3(side * 0.246, -0.100, 0.0), shell_shade)

	# Telescoping arm carries the gun past the body silhouette.
	var arm_pivot := Node3D.new()
	arm_pivot.name = "ArmPivot"
	arm_pivot.position = Vector3(side * 0.075, 0.0, -0.040)
	bay.add_child(arm_pivot)
	box(arm_pivot, "Arm", Vector3(0.100, 0.042, 0.042), Vector3(side * 0.050, 0.0, 0.0), shell_shade)

	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(side * 0.100, 0.0, 0.0)
	arm_pivot.add_child(gun)
	# Turret breech, a long barrel and a muzzle brake.  Stowed, the whole gun
	# yaws inward so the barrel lies inside the hull; deploying swings it out.
	box(gun, "Breech", Vector3(0.085, 0.085, 0.150), Vector3.ZERO, trim)
	box(gun, "BreechTop", Vector3(0.070, 0.020, 0.120), Vector3(0.0, 0.052, 0.0), shell_shade)
	var barrel := cylinder(gun, "Barrel", 0.020, 0.020, 0.260, Vector3(0.0, 0.0, 0.195), rubber, 8)
	barrel.rotation.x = deg_to_rad(90.0)
	var muzzle := cylinder(gun, "MuzzleBrake", 0.030, 0.030, 0.055, Vector3(0.0, 0.0, 0.350), shell_shade, 8)
	muzzle.rotation.x = deg_to_rad(90.0)
	box(gun, "Sight", Vector3(0.016, 0.014, 0.070), Vector3(0.0, 0.055, 0.045), accent)


## Front panel texture: plain shell above, painted double-door cabinet below.
## Layout matches the slab (0.30 x 0.90), so the door sits at world y 0.30..0.64.
static func front_panel_material() -> ShaderMaterial:
	var width := 96
	var height := 288
	var base := Color("aab4bf")
	var door_fill := Color("9aa5b1")
	var line := Color("2a313a")
	var ink := Color("1d232b")
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var colour := base
			# Faint vertical brushing so the flat face is not a dead colour field.
			if x % 6 == 0:
				colour = base * 0.985
			image.set_pixel(x, y, colour)

	# Door rectangle (v 80..189 of 288).
	var left := 10
	var right := 86
	var bottom := 208
	var top := 93
	for y in range(bottom, top + 1):
		for x in range(left, right + 1):
			image.set_pixel(x, y, door_fill)
	for thickness in 2:
		for x in range(left, right + 1):
			image.set_pixel(x, bottom + thickness, line)
			image.set_pixel(x, top - thickness, line)
		for y in range(bottom, top + 1):
			image.set_pixel(left + thickness, y, line)
			image.set_pixel(right - thickness, y, line)
	# Inner highlight just under the top edge, sells the recess.
	for x in range(left + 3, right - 2):
		image.set_pixel(x, top + 3, Color("9aa5b1"))
	# Centre seam of the double door.
	for y in range(top + 1, bottom):
		image.set_pixel(47, y, line)
		image.set_pixel(48, y, line)
	# Vertical pull handle, painted flat.
	for y in range(132, 172):
		for x in range(74, 79):
			image.set_pixel(x, y, ink)
	for y in range(134, 170):
		image.set_pixel(74, y, ink * 1.35)
	# Service label and corner screws.
	for x in range(20, 40, 6):
		for y in range(100, 106):
			image.set_pixel(x, y, ink)
	for corner in [Vector2i(left + 5, bottom + 5), Vector2i(right - 5, bottom + 5),
			Vector2i(left + 5, top - 5), Vector2i(right - 5, top - 5)]:
		image.set_pixel(corner.x, corner.y, ink)
		image.set_pixel(corner.x + 1, corner.y, ink)
		image.set_pixel(corner.x, corner.y + 1, ink)

	var material := ShaderMaterial.new()
	material.shader = PANEL_SHADER
	material.set_shader_parameter("panel_texture", ImageTexture.create_from_image(image))
	material.set_shader_parameter("tint", Color(0.96, 0.97, 0.99))
	return material
