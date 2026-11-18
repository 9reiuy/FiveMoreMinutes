class_name MiniForklift3D
extends Node3D
## Compact electric counterbalance mini forklift (LK-P 243) calibrated to DreamPlayer proportions.
## +X is forward (single central mast & forks), +Y is up (Y=0 tyre contact), +/-Z are right/left.

const STEEL_DIFF := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png"
const STEEL_NOR := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png"
const STEEL_ROUGH := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png"
const STEEL_MET := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Metallic.png"

const MET12_NOR := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_NormalGL.png"
const MET12_ROUGH := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Roughness.png"
const STABLE_SHADOW := preload("res://scripts/dream/props/forklift_shadow_caster.gd")

## Calibrated cab dimensions for DreamPlayer (32 px/m -> standing ~1.06 m, seated ~0.94 m, max hair ~0.94 m).
const MODEL_SCALE := 1.14
const BASE_CHASSIS_MIN_X := -0.82
const BASE_FORK_TIP_X := 1.70
const BASE_FLOOR_PAN_Y := 0.24
const BASE_FOOTWELL_Y := 0.18
const BASE_SEAT_Y := 0.40
const BASE_BACK_TOP_Y := 1.00
const BASE_STEERING_GRIP := Vector3(0.19, 0.77, 0.0)

const CHASSIS_MIN_X := BASE_CHASSIS_MIN_X * MODEL_SCALE
const CHASSIS_MAX_X := 0.84 * MODEL_SCALE
const FORK_TIP_X := BASE_FORK_TIP_X * MODEL_SCALE
const TOTAL_LENGTH := FORK_TIP_X - CHASSIS_MIN_X # ~2.87 m
const OUTER_WIDTH := 1.24 * MODEL_SCALE # ~1.41 m
const CAB_INNER_WIDTH := 0.98 * MODEL_SCALE # ~1.12 m clear cab opening for DreamPlayer hair/torso
const FLOOR_PAN_Y := BASE_FLOOR_PAN_Y * MODEL_SCALE
const FOOTWELL_Y := BASE_FOOTWELL_Y * MODEL_SCALE
const SEAT_CUSHION_Y := BASE_SEAT_Y * MODEL_SCALE # ~0.456 m matching OperatorChair seat height
const SEAT_BACK_TOP_Y := BASE_BACK_TOP_Y * MODEL_SCALE
const CANOPY_RAISE := 0.42
const CAB_CEILING_Y := (1.46 + CANOPY_RAISE) * MODEL_SCALE
const CANOPY_TOP_Y := (1.58 + CANOPY_RAISE) * MODEL_SCALE
const MAST_TOP_Y := 2.38 * MODEL_SCALE # ~2.71 m
const SEAT_ANCHOR_LOCAL := Vector3(-0.10 * MODEL_SCALE, SEAT_CUSHION_Y, 0.0)
const STEERING_GRIP_LOCAL := BASE_STEERING_GRIP * MODEL_SCALE

const FRONT_AXLE := Vector2(0.34, 0.26)
const REAR_AXLE := Vector2(-0.56, 0.17)
const MAST_TILT := -0.044 # ~2.5 deg rearward tilt like industrial mast balance
const MAST_PIVOT := Vector3(0.79, 0.34, 0.0)

static var _cached_meshes: Dictionary = {}
static var _cached_textures: Dictionary = {}


class MeshBuilder extends RefCounted:
	var surfaces: Dictionary = {}

	func triangle(mat: Material, a: Vector3, b: Vector3, c: Vector3, outward: Vector3,
			na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO,
			uva := Vector2.INF, uvb := Vector2.INF, uvc := Vector2.INF) -> void:
		a *= MODEL_SCALE
		b *= MODEL_SCALE
		c *= MODEL_SCALE
		if (b - a).cross(c - a).length_squared() < 1e-11:
			return
		var n_out := outward.normalized() if outward.length_squared() > 1e-10 else (b - a).cross(c - a).normalized()
		if na == Vector3.ZERO:
			na = n_out
			nb = n_out
			nc = n_out
		if (c - a).cross(b - a).dot(n_out) < 0.0:
			var tmp_p := b; b = c; c = tmp_p
			var tmp_n := nb; nb = nc; nc = tmp_n
			var tmp_u := uvb; uvb = uvc; uvc = tmp_u
		if not surfaces.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			surfaces[mat] = st
		var tool: SurfaceTool = surfaces[mat]
		var verts: Array[Array] = [[a, na, uva], [b, nb, uvb], [c, nc, uvc]]
		var dom := n_out.abs()
		for v: Array in verts:
			var p: Vector3 = v[0]
			var n: Vector3 = v[1]
			var uv: Vector2 = v[2]
			if uv == Vector2.INF:
				if dom.x > maxf(dom.y, dom.z):
					uv = Vector2(p.z, p.y)
				elif dom.y > dom.z:
					uv = Vector2(p.x, p.z)
				else:
					uv = Vector2(p.x, p.y)
			tool.set_normal(n.normalized())
			tool.set_uv(uv)
			tool.add_vertex(p)

	func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
			na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO, nd := Vector3.ZERO,
			uva := Vector2.INF, uvb := Vector2.INF, uvc := Vector2.INF, uvd := Vector2.INF) -> void:
		triangle(mat, a, b, c, outward, na, nb, nc, uva, uvb, uvc)
		triangle(mat, a, c, d, outward, na, nc, nd, uva, uvc, uvd)

	func bake() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for st: SurfaceTool in surfaces.values():
			st.generate_tangents()
			st.index()
			st.commit(mesh)
		return mesh


var body_mesh_instance: MeshInstance3D
var windshield_mesh_instance: MeshInstance3D
var stable_shadow_caster: Node3D
var seat_anchor: Marker3D
var drive_wheels: Array[Node3D] = []
var _parked_materials: Dictionary[MeshInstance3D, Dictionary] = {}
var _body_roll := INF
var _body_pitch := 0.0


func _init() -> void:
	name = "MiniForklift3D"
	_ensure_built()


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if body_mesh_instance != null and is_instance_valid(body_mesh_instance):
		return
	var meshes := _get_or_build_meshes()

	body_mesh_instance = MeshInstance3D.new()
	body_mesh_instance.name = "BodyMesh"
	body_mesh_instance.mesh = meshes.opaque
	body_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body_mesh_instance)
	for wheel_data: Dictionary in meshes.wheels:
		var pivot := Node3D.new()
		pivot.name = "RearWheel" if wheel_data.rear else "FrontWheel"
		pivot.position = wheel_data.center * MODEL_SCALE
		add_child(pivot)
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_data.mesh
		pivot.add_child(wheel)
		pivot.set_meta(&"rear", wheel_data.rear)
		pivot.set_meta(&"radius", wheel_data.radius * MODEL_SCALE)
		drive_wheels.append(pivot)

	windshield_mesh_instance = MeshInstance3D.new()
	windshield_mesh_instance.name = "WindshieldGlass"
	windshield_mesh_instance.mesh = meshes.glass
	windshield_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(windshield_mesh_instance)

	seat_anchor = Marker3D.new()
	seat_anchor.name = "DriverSeatAnchor"
	seat_anchor.position = SEAT_ANCHOR_LOCAL
	add_child(seat_anchor)
	stable_shadow_caster = STABLE_SHADOW.install(self)


## Places a 2D/3D seated character rig relative to the internal seat cushion anchor.
func get_driver_seat_transform() -> Transform3D:
	return seat_anchor.transform


func animate_drive(distance: float, steering_angle: float, handbrake := false) -> void:
	for pivot in drive_wheels:
		if bool(pivot.get_meta(&"rear")):
			pivot.rotation.y = steering_angle
		var wheel := pivot.get_child(0) as MeshInstance3D
		if not (handbrake and bool(pivot.get_meta(&"rear"))):
			wheel.rotation.z = wrapf(wheel.rotation.z - distance / float(pivot.get_meta(&"radius")), -PI, PI)


func set_body_roll(angle: float, pitch := 0.0) -> void:
	# Suspension rolls the body around the seat line; tyres remain grounded and
	# the seated actor stays centered. Root Z pitch still follows stairs/ramps.
	if is_equal_approx(_body_roll, angle) and is_equal_approx(_body_pitch, pitch):
		return
	_body_roll = angle
	_body_pitch = pitch
	var lean := Basis(Vector3.RIGHT, angle) * Basis(Vector3.BACK, pitch)
	var pivot := Vector3(0.0, SEAT_CUSHION_Y, 0.0)
	var pose := Transform3D(lean, pivot - lean * pivot)
	body_mesh_instance.transform = pose
	windshield_mesh_instance.transform = pose
	seat_anchor.transform = pose * Transform3D(Basis.IDENTITY, SEAT_ANCHOR_LOCAL)


func set_driver_onboard(occupied: bool) -> void:
	# Keep the complete original vehicle opaque while driving. Parked cutout
	# overrides belong to this instance and are restored unchanged on dismount.
	if occupied:
		if not _parked_materials.is_empty():
			return
		for part: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			if bool(part.get_meta(&"surface_blood_excluded", false)):
				if bool(part.get_meta(&"surface_blood_mark", false)):
					part.set_meta(&"parked_blood_cutout", part.material_override.get_shader_parameter(&"occlusion_cutout_enabled"))
					part.material_override.set_shader_parameter(&"occlusion_cutout_enabled", false)
				continue
			if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				continue
			var surfaces: Array[Material] = []
			for surface in part.mesh.get_surface_count():
				surfaces.append(part.get_surface_override_material(surface))
				part.set_surface_override_material(surface, null)
			_parked_materials[part] = {"material": part.material_override, "surfaces": surfaces}
			part.material_override = null
		return
	for part in _parked_materials:
		if not is_instance_valid(part):
			continue
		var saved: Dictionary = _parked_materials[part]
		part.material_override = saved.material
		for surface in saved.surfaces.size():
			part.set_surface_override_material(surface, saved.surfaces[surface])
	_parked_materials.clear()
	for part: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta(&"surface_blood_mark", false)): continue
		part.material_override.set_shader_parameter(&"occlusion_cutout_enabled", part.get_meta(&"parked_blood_cutout", true))


## Returns AABB corners on XZ floor for 2D collider fitting (chassis + extended fork span).
static func get_footprint_rect() -> Rect2:
	return Rect2(CHASSIS_MIN_X, -OUTER_WIDTH * 0.5, TOTAL_LENGTH, OUTER_WIDTH)


static func _get_or_build_meshes() -> Dictionary:
	if not _cached_meshes.is_empty():
		return _cached_meshes

	var mats := _create_materials()
	var opaque := MeshBuilder.new()
	var glass_builder := MeshBuilder.new()

	_build_chassis_and_fenders(opaque, mats)
	_build_cab_and_seat(opaque, mats)
	_build_canopy_and_windshield(opaque, glass_builder, mats)
	_build_central_mast_and_forks(opaque, mats)

	_cached_meshes = {
		"opaque": opaque.bake(),
		"glass": glass_builder.bake(),
		"wheels": _build_drive_wheels(mats),
	}
	return _cached_meshes


static func _create_materials() -> Dictionary:
	var nor_met12 := load(MET12_NOR) as Texture2D
	var rough_met12 := load(MET12_ROUGH) as Texture2D
	var nor_iron := load(STEEL_NOR) as Texture2D
	var rough_iron := load(STEEL_ROUGH) as Texture2D
	var met_iron := load(STEEL_MET) as Texture2D
	var col_iron := load(STEEL_DIFF) as Texture2D

	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("d88c28")
	orange.metallic = 0.16
	orange.roughness = 0.42
	orange.normal_texture = nor_met12
	orange.normal_scale = 0.35
	orange.roughness_texture = rough_met12
	orange.uv1_scale = Vector3(1.6, 1.6, 1.6)
	orange.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var orange_dark := StandardMaterial3D.new()
	orange_dark.albedo_color = Color("b66c1a")
	orange_dark.metallic = 0.18
	orange_dark.roughness = 0.50
	orange_dark.normal_texture = nor_met12
	orange_dark.normal_scale = 0.35
	orange_dark.uv1_scale = Vector3(1.6, 1.6, 1.6)

	var charcoal := StandardMaterial3D.new()
	charcoal.albedo_color = Color("24282d")
	charcoal.metallic = 0.14
	charcoal.roughness = 0.62
	charcoal.normal_texture = nor_met12
	charcoal.normal_scale = 0.30
	charcoal.uv1_scale = Vector3(2.0, 2.0, 2.0)

	var dark_recess := StandardMaterial3D.new()
	dark_recess.albedo_color = Color("131619")
	dark_recess.metallic = 0.10
	dark_recess.roughness = 0.84

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("1b1e21")
	rubber.metallic = 0.0
	rubber.roughness = 0.90

	var seat_pad := StandardMaterial3D.new()
	seat_pad.albedo_color = Color("222529")
	seat_pad.metallic = 0.02
	seat_pad.roughness = 0.78

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("b5bcc0")
	steel.albedo_texture = col_iron
	steel.metallic = 0.78
	steel.metallic_texture = met_iron
	steel.roughness = 0.38
	steel.roughness_texture = rough_iron
	steel.normal_texture = nor_iron
	steel.normal_scale = 0.45
	steel.uv1_scale = Vector3(1.8, 1.8, 1.8)
	steel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var trim_silver := StandardMaterial3D.new()
	trim_silver.albedo_color = Color("c5cbcf")
	trim_silver.metallic = 0.82
	trim_silver.roughness = 0.28

	var cyan_led := StandardMaterial3D.new()
	cyan_led.albedo_color = Color("24d4f0")
	cyan_led.emission_enabled = true
	cyan_led.emission = Color("1cc8eb")
	cyan_led.emission_energy_multiplier = 1.45
	cyan_led.roughness = 0.18

	var amber_led := StandardMaterial3D.new()
	amber_led.albedo_color = Color("f0932b")
	amber_led.emission_enabled = true
	amber_led.emission = Color("e57c18")
	amber_led.emission_energy_multiplier = 1.35
	amber_led.roughness = 0.22

	var hazard := StandardMaterial3D.new()
	hazard.albedo_texture = _get_hazard_texture()
	hazard.roughness = 0.48
	hazard.metallic = 0.10
	hazard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var mast_plate := StandardMaterial3D.new()
	mast_plate.albedo_texture = _get_mast_badge_texture()
	mast_plate.roughness = 0.42
	mast_plate.roughness_texture = rough_met12
	mast_plate.normal_texture = nor_met12
	mast_plate.normal_scale = 0.35
	mast_plate.metallic = 0.16
	mast_plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var side_243_l := StandardMaterial3D.new()
	side_243_l.albedo_texture = _get_side_243_texture(false)
	side_243_l.roughness = 0.42
	side_243_l.roughness_texture = rough_met12
	side_243_l.normal_texture = nor_met12
	side_243_l.normal_scale = 0.35
	side_243_l.metallic = 0.16
	side_243_l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var side_243_r := StandardMaterial3D.new()
	side_243_r.albedo_texture = _get_side_243_texture(true)
	side_243_r.roughness = 0.42
	side_243_r.roughness_texture = rough_met12
	side_243_r.normal_texture = nor_met12
	side_243_r.normal_scale = 0.35
	side_243_r.metallic = 0.16
	side_243_r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.68, 0.78, 0.84, 0.25)
	glass.metallic = 0.15
	glass.roughness = 0.08
	glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	return {
		"orange": orange,
		"orange_dark": orange_dark,
		"charcoal": charcoal,
		"dark": dark_recess,
		"rubber": rubber,
		"seat": seat_pad,
		"steel": steel,
		"silver": trim_silver,
		"cyan": cyan_led,
		"amber": amber_led,
		"hazard": hazard,
		"mast_plate": mast_plate,
		"side_243_l": side_243_l,
		"side_243_r": side_243_r,
		"glass": glass,
	}


static func _build_chassis_and_fenders(m: MeshBuilder, mats: Dictionary) -> void:
	var orange: Material = mats.orange
	var orange_dark: Material = mats.orange_dark
	var charcoal: Material = mats.charcoal
	var dark: Material = mats.dark
	var steel: Material = mats.steel
	var silver: Material = mats.silver
	var cyan: Material = mats.cyan

	# Underbody belly pan & front cross-frame spine
	_bevel_box(m, dark, Vector3(-0.04, 0.13, 0.0), Vector3(1.38, 0.08, 0.82), 0.02)
	_bevel_box(m, charcoal, Vector3(0.02, 0.20, 0.0), Vector3(0.68, 0.08, 0.86), 0.02)
	# Cab entry floor pan + depressed footwell ahead of seat
	_bevel_box(m, charcoal, Vector3(-0.06, BASE_FLOOR_PAN_Y - 0.02, 0.0), Vector3(0.46, 0.05, 0.90), 0.015)
	_bevel_box(m, dark, Vector3(0.28, BASE_FOOTWELL_Y - 0.015, 0.0), Vector3(0.32, 0.04, 0.62), 0.01)

	# Side step rocker skirts (left & right) with dual crisp silver horizontal pinstripes
	for side: float in [-1.0, 1.0]:
		_bevel_box(m, orange, Vector3(-0.14, 0.21, side * 0.49), Vector3(0.56, 0.18, 0.10), 0.025)
		_bevel_box(m, silver, Vector3(-0.13, 0.185, side * 0.542), Vector3(0.46, 0.014, 0.010), 0.003)
		_bevel_box(m, silver, Vector3(-0.13, 0.228, side * 0.542), Vector3(0.46, 0.014, 0.010), 0.003)

	# Rear counterweight block + stepped shoulders (open rear wheel wells underneath)
	_bevel_box(m, orange, Vector3(-0.54, 0.50, 0.0), Vector3(0.56, 0.44, 1.06), 0.055)
	_bevel_box(m, orange, Vector3(-0.62, 0.34, 0.0), Vector3(0.40, 0.30, 0.62), 0.04) # center tail between rear wheels
	_bevel_box(m, charcoal, Vector3(-0.78, 0.25, 0.0), Vector3(0.11, 0.16, 0.88), 0.025) # rear rubberized bumper apron
	_bevel_box(m, dark, Vector3(-0.825, 0.24, 0.0), Vector3(0.03, 0.09, 0.18), 0.006) # tow hitch recess
	# Rear counterweight upper engine cowl behind seat backrest
	_bevel_box(m, orange, Vector3(-0.58, 0.85, 0.0), Vector3(0.36, 0.30, 0.68), 0.055)
	_bevel_box(m, orange, Vector3(-0.56, 1.00, 0.0), Vector3(0.28, 0.075, 0.54), 0.025)
	for i in 4:
		_bevel_box(m, dark, Vector3(-0.755, 0.72 + i * 0.055, 0.0), Vector3(0.024, 0.022, 0.42), 0.005)
		_bevel_box(m, dark, Vector3(-0.695, 0.85 + i * 0.036, 0.0), Vector3(0.020, 0.016, 0.38), 0.004)

	# Glowing cyan shoulder strips & `◁ 243` stenciled cheek badges on rear sides
	for side: float in [-1.0, 1.0]:
		_bevel_box(m, dark, Vector3(-0.37, 0.722, side * 0.46), Vector3(0.20, 0.036, 0.055), 0.008)
		_bevel_box(m, cyan, Vector3(-0.37, 0.728, side * 0.465), Vector3(0.17, 0.022, 0.048), 0.006)
		var mat_badge: Material = mats.side_243_l if side < 0.0 else mats.side_243_r
		var bx := -0.56
		var by := 0.50
		var bz := side * 0.532
		var hw := 0.115
		var hh := 0.048
		if side < 0.0:
			m.quad(mat_badge,
				Vector3(bx + hw, by - hh, bz), Vector3(bx - hw, by - hh, bz),
				Vector3(bx - hw, by + hh, bz), Vector3(bx + hw, by + hh, bz),
				Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1),
				Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
		else:
			m.quad(mat_badge,
				Vector3(bx - hw, by - hh, bz), Vector3(bx + hw, by - hh, bz),
				Vector3(bx + hw, by + hh, bz), Vector3(bx - hw, by + hh, bz),
				Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
				Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))

	# Curved sculpted front wheel-arch fenders & signature diagonal suspension struts
	for side: float in [-1.0, 1.0]:
		_build_curved_fender_arch(m, orange, dark, side)
		# Cyan indicator bezel sitting cleanly atop each front fender crown
		_bevel_box(m, charcoal, Vector3(0.39, 0.610, side * 0.48), Vector3(0.11, 0.036, 0.082), 0.012)
		_bevel_box(m, cyan, Vector3(0.415, 0.625, side * 0.48), Vector3(0.070, 0.020, 0.054), 0.006)
		# Upper fender lug + diagonal machined steel strut curving down-forward to wheel hub center
		var lug_base := Vector3(0.14, 0.435, side * 0.515)
		var lug_tip := Vector3(0.165, 0.445, side * 0.585)
		_bar(m, orange, lug_base, lug_tip, 0.068, 0.064)
		var hub_outer := Vector3(FRONT_AXLE.x, FRONT_AXLE.y, side * 0.598)
		_tube(m, silver, lug_tip, hub_outer, 0.024, 14)
		_tube(m, steel, lug_tip - Vector3(0, 0, side * 0.008), lug_tip + Vector3(0, 0, side * 0.012), 0.031, 14)
		_tube(m, charcoal, hub_outer - Vector3(0, 0, side * 0.025), hub_outer + Vector3(0, 0, side * 0.012), 0.044, 16)
		_tube(m, silver, hub_outer + Vector3(0, 0, side * 0.004), hub_outer + Vector3(0, 0, side * 0.020), 0.024, 16)

	# Front sloped nose bulkhead between the front fenders + lower cross bumper beam
	_bevel_box(m, charcoal, Vector3(0.58, 0.30, 0.0), Vector3(0.30, 0.14, 0.68), 0.025)
	_bevel_box(m, orange, Vector3(0.47, 0.46, 0.0), Vector3(0.28, 0.24, 0.72), 0.045)
	_bevel_box(m, orange, Vector3(0.37, 0.55, 0.0), Vector3(0.24, 0.18, 0.78), 0.04)


static func _build_curved_fender_arch(m: MeshBuilder, orange: Material, dark: Material, side: float) -> void:
	var c := Vector2(FRONT_AXLE.x, FRONT_AXLE.y)
	var r_in := 0.295
	var r_out := 0.345
	var z_in := side * 0.355
	var z_out := side * 0.585
	var segs := 18
	var a_start := deg_to_rad(-18.0)
	var a_end := deg_to_rad(185.0)
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var a0 := lerpf(a_start, a_end, t0)
		var a1 := lerpf(a_start, a_end, t1)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var n0 := Vector3(d0.x, d0.y, 0.0)
		var n1 := Vector3(d1.x, d1.y, 0.0)

		var o0 := Vector3(c.x + d0.x * r_out, maxf(0.11, c.y + d0.y * r_out), z_out - side * 0.025)
		var o1 := Vector3(c.x + d1.x * r_out, maxf(0.11, c.y + d1.y * r_out), z_out - side * 0.025)
		var i0 := Vector3(c.x + d0.x * r_out, maxf(0.11, c.y + d0.y * r_out), z_in)
		var i1 := Vector3(c.x + d1.x * r_out, maxf(0.11, c.y + d1.y * r_out), z_in)
		# Curved top crown of wheel arch
		m.quad(orange, o0, o1, i1, i0, (n0 + n1) * 0.5, n0, n1, n1, n0)

		var io0 := Vector3(c.x + d0.x * r_in, maxf(0.11, c.y + d0.y * r_in), z_out)
		var io1 := Vector3(c.x + d1.x * r_in, maxf(0.11, c.y + d1.y * r_in), z_out)
		var ii0 := Vector3(c.x + d0.x * r_in, maxf(0.11, c.y + d0.y * r_in), z_in)
		var ii1 := Vector3(c.x + d1.x * r_in, maxf(0.11, c.y + d1.y * r_in), z_in)
		# Dark inner wheel well lining
		m.quad(dark, ii0, ii1, io1, io0, -(n0 + n1) * 0.5)
		# Chamfered outer fender rim lip wrapping down to inner rim
		m.quad(orange, io0, io1, o1, o0, Vector3(0, 0, side) + (n0 + n1) * 0.25)
		m.quad(orange, i0, i1, ii1, ii0, Vector3(0, 0, -side))


static func _build_drive_wheels(mats: Dictionary) -> Array[Dictionary]:
	var wheels: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		for rear: bool in [false, true]:
			var axle := REAR_AXLE if rear else FRONT_AXLE
			var wheel := MeshBuilder.new()
			_wheel(wheel, Vector3.ZERO, axle.y, 0.070 if rear else 0.092,
				side, mats.rubber, mats.orange, mats.dark, mats.silver)
			wheels.append({"mesh": wheel.bake(), "rear": rear, "radius": axle.y,
				"center": Vector3(axle.x, axle.y, side * (0.435 if rear else 0.485))})
	return wheels


static func _wheel(m: MeshBuilder, center: Vector3, radius: float, half_width: float, side: float,
		rubber: Material, hub_orange: Material, dark: Material, silver: Material) -> void:
	var sectors := 36
	var section := [
		Vector2(-1.0, 0.70), Vector2(-1.02, 0.85), Vector2(-0.80, 0.96),
		Vector2(-0.48, 1.0), Vector2(0.48, 1.0), Vector2(0.80, 0.96),
		Vector2(1.02, 0.85), Vector2(0.98, 0.70),
	]
	for i in sectors:
		var aa := TAU * i / sectors
		var ab := TAU * (i + 1) / sectors
		var p := Vector3(cos(aa), sin(aa), 0.0)
		var q := Vector3(cos(ab), sin(ab), 0.0)
		for j in range(section.size() - 1):
			var s: Vector2 = section[j]
			var t: Vector2 = section[j + 1]
			var ds: Vector2 = section[mini(j + 1, section.size() - 1)] - section[maxi(j - 1, 0)]
			var dt: Vector2 = section[mini(j + 2, section.size() - 1)] - section[j]
			var ns := (p * ds.x * half_width - Vector3(0, 0, side * ds.y * radius)).normalized()
			var nt := (p * dt.x * half_width - Vector3(0, 0, side * dt.y * radius)).normalized()
			var ms := (q * ds.x * half_width - Vector3(0, 0, side * ds.y * radius)).normalized()
			var mt := (q * dt.x * half_width - Vector3(0, 0, side * dt.y * radius)).normalized()
			m.quad(rubber,
				center + p * radius * s.y + Vector3(0, 0, side * s.x * half_width),
				center + q * radius * s.y + Vector3(0, 0, side * s.x * half_width),
				center + q * radius * t.y + Vector3(0, 0, side * t.x * half_width),
				center + p * radius * t.y + Vector3(0, 0, side * t.x * half_width),
				ns + ms + nt + mt, ns, ms, mt, nt)
	var out_dir := Vector3(0, 0, side)
	var face := center + out_dir * (half_width * 0.92)
	var back_face := center - out_dir * (half_width * 0.88)
	for i in sectors:
		var aa := TAU * i / sectors
		var ab := TAU * (i + 1) / sectors
		var p := Vector3(cos(aa), sin(aa), 0.0)
		var q := Vector3(cos(ab), sin(ab), 0.0)
		# Dark recessed sidewall dish
		m.quad(dark, face + p * radius * 0.72, face + q * radius * 0.72,
			face + q * radius * 0.56 - out_dir * 0.015, face + p * radius * 0.56 - out_dir * 0.015, out_dir)
		# Back hub closure
		m.triangle(dark, back_face, back_face + p * radius * 0.72, back_face + q * radius * 0.72, -out_dir)
		# Chunky convex orange dome hubcap like the concept art
		m.quad(hub_orange, face + p * radius * 0.57 + out_dir * 0.005, face + q * radius * 0.57 + out_dir * 0.005,
			face + q * radius * 0.24 + out_dir * 0.028, face + p * radius * 0.24 + out_dir * 0.028, out_dir,
			(p * 0.4 + out_dir).normalized(), (q * 0.4 + out_dir).normalized(), out_dir, out_dir)
		m.triangle(silver, face + out_dir * 0.032,
			face + p * radius * 0.24 + out_dir * 0.028,
			face + q * radius * 0.24 + out_dir * 0.028, out_dir)


static func _build_cab_and_seat(m: MeshBuilder, mats: Dictionary) -> void:
	var charcoal: Material = mats.charcoal
	var seat: Material = mats.seat
	var dark: Material = mats.dark
	var silver: Material = mats.silver

	# Adjustable seat pedestal riser under cushion
	_bevel_box(m, dark, Vector3(-0.10, 0.30, 0.0), Vector3(0.32, 0.12, 0.34), 0.02)
	# Contoured driver seat bottom cushion (width 0.54 m so DreamPlayer fits centered with side bolsters)
	_bevel_box(m, seat, Vector3(-0.09, BASE_SEAT_Y - 0.035, 0.0), Vector3(0.44, 0.08, 0.48), 0.024)
	for side: float in [-1.0, 1.0]:
		_bevel_box(m, seat, Vector3(-0.10, BASE_SEAT_Y - 0.01, side * 0.22), Vector3(0.40, 0.06, 0.09), 0.022)

	# Reclined contoured high backrest (tilted aft ~10 deg)
	var back_lo := Vector3(-0.34, BASE_SEAT_Y + 0.04, 0.0)
	var back_hi := Vector3(-0.44, BASE_BACK_TOP_Y, 0.0)
	_bar(m, seat, back_lo, back_hi, 0.44, 0.095)
	for side: float in [-1.0, 1.0]:
		_bar(m, seat, back_lo + Vector3(0.02, 0.02, side * 0.19), back_hi + Vector3(0.02, -0.06, side * 0.175), 0.09, 0.105)
	_bevel_box(m, charcoal, Vector3(-0.445, BASE_BACK_TOP_Y - 0.04, 0.0), Vector3(0.11, 0.14, 0.30), 0.03)

	# Steering column + angled dashboard cowl + 3-spoke compact wheel + foot pedals
	_bevel_box(m, charcoal, Vector3(0.32, 0.58, 0.0), Vector3(0.22, 0.14, 0.56), 0.03)
	_tube(m, dark, Vector3(0.32, 0.56, 0.0), BASE_STEERING_GRIP, 0.030, 12)
	# Compact steering wheel ring in plane tilted toward driver
	var steer_center := BASE_STEERING_GRIP
	var axis := (steer_center - Vector3(0.32, 0.56, 0.0)).normalized()
	var right_v := Vector3(0, 0, 1)
	var up_v := axis.cross(right_v).normalized()
	var wr := 0.115
	for i in 16:
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		var p0 := steer_center + right_v * (cos(a0) * wr) + up_v * (sin(a0) * wr)
		var p1 := steer_center + right_v * (cos(a1) * wr) + up_v * (sin(a1) * wr)
		_tube(m, charcoal, p0, p1, 0.015, 8)
	_bar(m, silver, steer_center, steer_center + right_v * wr, 0.018, 0.012)
	_bar(m, silver, steer_center, steer_center - right_v * wr, 0.018, 0.012)
	_bar(m, silver, steer_center, steer_center - up_v * wr, 0.018, 0.012)

	# Floor foot pedals in front well
	_bevel_box(m, charcoal, Vector3(0.27, BASE_FOOTWELL_Y + 0.035, -0.09), Vector3(0.09, 0.025, 0.055), 0.006)
	_bevel_box(m, charcoal, Vector3(0.27, BASE_FOOTWELL_Y + 0.035, 0.06), Vector3(0.09, 0.025, 0.075), 0.006)


static func _build_canopy_and_windshield(m: MeshBuilder, g: MeshBuilder, mats: Dictionary) -> void:
	var charcoal: Material = mats.charcoal
	var dark: Material = mats.dark
	var silver: Material = mats.silver
	var steel: Material = mats.steel
	var orange: Material = mats.orange
	var cyan: Material = mats.cyan
	var amber: Material = mats.amber
	var glass: Material = mats.glass

	# Raise the complete canopy and its supports, keeping the driver beneath the opaque roof.
	var rise := CANOPY_RAISE
	_bevel_box(m, charcoal, Vector3(-0.19, 1.52 + rise, 0.0), Vector3(0.92, 0.12, 1.10), 0.038)
	_bevel_box(m, dark, Vector3(-0.21, 1.585 + rise, 0.0), Vector3(0.68, 0.022, 0.88), 0.01) # subtle raised roof rib

	# Signature 4 recessed pill-oval cutouts across front canopy header brow
	_bevel_box(m, charcoal, Vector3(0.245, 1.515 + rise, 0.0), Vector3(0.03, 0.08, 0.72), 0.01)
	for i in 4:
		var z := lerpf(-0.22, 0.22, float(i) / 3.0)
		_bevel_box(m, dark, Vector3(0.264, 1.515 + rise, z), Vector3(0.014, 0.046, 0.072), 0.012)

	# Rear C-pillars & brushed silver shoulder gussets (leaving cab sides wide open!)
	for side: float in [-1.0, 1.0]:
		var cp_bot := Vector3(-0.50, 0.84, side * 0.475)
		var cp_top := Vector3(-0.53, 1.48 + rise, side * 0.48)
		_bar(m, charcoal, cp_bot, cp_top, 0.16, 0.105)
		# Silver metallic L-gusset trim wrapping lower C-pillar forward along shoulder
		var gus_mid := Vector3(-0.38, 0.84, side * 0.468)
		var gus_top := Vector3(-0.43, 1.26 + rise * 0.65, side * 0.475)
		_bar(m, silver, gus_mid, gus_top, 0.075, 0.052)
		_bevel_box(m, silver, Vector3(-0.35, 0.80, side * 0.468), Vector3(0.14, 0.06, 0.052), 0.015)

		# Sleek tapered brushed-silver front A-pillars aligned flush with canopy front brow
		var a_bot := Vector3(0.455, 0.615, side * 0.47)
		var a_top := Vector3(0.245, 1.47 + rise, side * 0.47)
		_bar(m, silver, a_bot, a_top, 0.076, 0.070)
		_bar(m, dark, a_bot + Vector3(0.012, 0.0, -side * 0.02), a_top + Vector3(0.012, 0.0, -side * 0.02), 0.022, 0.022)

		# Roof-mounted cyan rectangular spotlights with tiny amber side indicators
		var pod := Vector3(0.235, 1.61 + rise, side * 0.375)
		_bevel_box(m, charcoal, pod, Vector3(0.115, 0.088, 0.135), 0.022)
		_bevel_box(m, cyan, pod + Vector3(0.054, 0.0, 0.0), Vector3(0.020, 0.056, 0.096), 0.008)
		_bevel_box(m, amber, pod + Vector3(0.015, 0.0, side * 0.066), Vector3(0.044, 0.036, 0.016), 0.005)

	# Driver left-side orange wing mirror mounted halfway up left A-pillar (-Z side)
	var mirror_root := Vector3(0.365, 1.04 + rise * 0.5, -0.495)
	var mirror_head := Vector3(0.345, 1.06 + rise * 0.5, -0.59)
	_bar(m, dark, mirror_root, mirror_head, 0.022, 0.022)
	_bevel_box(m, orange, mirror_head + Vector3(0.01, 0.01, -0.02), Vector3(0.065, 0.155, 0.088), 0.022)
	_bevel_box(m, dark, mirror_head + Vector3(-0.02, 0.01, -0.02), Vector3(0.016, 0.125, 0.064), 0.005)

	# Upper canopy header & lower cowl trim framing the slanted glass pane
	_bar(m, charcoal, Vector3(0.25, 1.465 + rise, -0.46), Vector3(0.25, 1.465 + rise, 0.46), 0.055, 0.065)
	_bar(m, dark, Vector3(0.45, 0.625, -0.44), Vector3(0.45, 0.625, 0.44), 0.045, 0.045)

	# Slanted clear panoramic glass windshield (built onto non-shadow-casting transparent surface)
	var g_bl := Vector3(0.452, 0.635, -0.445)
	var g_br := Vector3(0.452, 0.635, 0.445)
	var g_tr := Vector3(0.248, 1.455 + rise, 0.445)
	var g_tl := Vector3(0.248, 1.455 + rise, -0.445)
	var g_norm := Vector3(g_tr.y - g_br.y, g_br.x - g_tr.x, 0.0).normalized()
	g.quad(glass, g_bl, g_br, g_tr, g_tl, g_norm, g_norm, g_norm, g_norm, g_norm)


static func _build_central_mast_and_forks(m: MeshBuilder, mats: Dictionary) -> void:
	var orange: Material = mats.orange
	var orange_dark: Material = mats.orange_dark
	var charcoal: Material = mats.charcoal
	var dark: Material = mats.dark
	var steel: Material = mats.steel
	var silver: Material = mats.silver
	var hazard: Material = mats.hazard
	var mast_plate: Material = mats.mast_plate

	var mast_pts := func(p: Vector3) -> Vector3:
		# Rotate mast local coordinates (X forward, Y height from pivot, Z side) around Z-axis by MAST_TILT.
		var c := cos(MAST_TILT)
		var s := sin(MAST_TILT)
		var rx := p.x * c - p.y * s
		var ry := p.x * s + p.y * c
		return MAST_PIVOT + Vector3(rx, ry, p.z)

	# Twin hydraulic tilt cylinders anchoring lower mast to front bulkhead
	for side: float in [-1.0, 1.0]:
		var cyl_back := Vector3(0.50, 0.36, side * 0.145)
		var cyl_front: Vector3 = mast_pts.call(Vector3(-0.04, 0.02, side * 0.145))
		_tube(m, dark, cyl_back, cyl_back.lerp(cyl_front, 0.65), 0.032, 12)
		_tube(m, silver, cyl_back.lerp(cyl_front, 0.60), cyl_front, 0.020, 12)

	# Central mast hinge saddle
	_bevel_box_xform(m, dark, Vector3(0.0, 0.04, 0.0), Vector3(0.16, 0.36, 0.28), 0.02, mast_pts)

	# Lower brushed-silver inner lift column (local Y from +0.16 to +1.15 -> world 0.50 .. 1.49 m)
	_bevel_box_xform(m, steel, Vector3(0.0, 0.66, 0.0), Vector3(0.14, 1.02, 0.21), 0.015, mast_pts)
	_bevel_box_xform(m, dark, Vector3(0.068, 0.66, 0.0), Vector3(0.025, 0.94, 0.07), 0.005, mast_pts) # center slot

	# Orange wrap-around guide collar near mid-column (world Y ~ 1.28 .. 1.38 m)
	_bevel_box_xform(m, orange, Vector3(0.0, 0.98, 0.0), Vector3(0.19, 0.095, 0.28), 0.022, mast_pts)

	# Upper wide orange telescopic mast housing (local Y +1.05 .. +1.93 -> world Y ~ 1.39 .. 2.27 m)
	_bevel_box_xform(m, orange, Vector3(0.0, 1.49, 0.0), Vector3(0.18, 0.88, 0.25), 0.022, mast_pts)
	# Crisp LK-P 243 + hazard band badge plates on front (+X) & both side cheeks (+/-Z)
	_add_mast_plate_decals(m, mast_plate, mast_pts)
	# Dark upper slotted louvers below cap
	for iy in [1.74, 1.80]:
		_bevel_box_xform(m, dark, Vector3(0.088, iy, 0.0), Vector3(0.020, 0.024, 0.14), 0.004, mast_pts)

	# Top rounded dark charcoal mast cap head (world Y ~ 2.26 .. 2.38 m)
	_bevel_box_xform(m, charcoal, Vector3(-0.01, 1.98, 0.0), Vector3(0.24, 0.125, 0.29), 0.036, mast_pts)
	_bevel_box_xform(m, dark, Vector3(-0.06, 1.93, 0.0), Vector3(0.14, 0.06, 0.22), 0.018, mast_pts)

	# U-shaped arched orange fork carriage yoke straddling the center column (world Y ~ 0.66 .. 0.88 m)
	_bevel_box_xform(m, orange, Vector3(0.075, 0.44, 0.0), Vector3(0.14, 0.14, 0.66), 0.028, mast_pts)
	_bevel_box_xform(m, dark, Vector3(0.095, 0.45, 0.0), Vector3(0.12, 0.07, 0.26), 0.012, mast_pts)
	for side: float in [-1.0, 1.0]:
		# Outer arched orange yoke legs + twin brushed-silver vertical guide rails down to carriage beam
		_bevel_box_xform(m, orange, Vector3(0.075, 0.36, side * 0.30), Vector3(0.14, 0.24, 0.12), 0.024, mast_pts)
		_bevel_box_xform(m, steel, Vector3(0.075, 0.04, side * 0.29), Vector3(0.11, 0.52, 0.095), 0.012, mast_pts)
		_bevel_box_xform(m, dark, Vector3(0.065, -0.04, side * 0.29), Vector3(0.125, 0.28, 0.105), 0.010, mast_pts)

	# Lower horizontal orange fork carriage beam & hazard-striped corner heel blocks
	var carriage_y := 0.175
	_bevel_box(m, orange, Vector3(0.90, carriage_y, 0.0), Vector3(0.125, 0.135, 0.72), 0.02)
	for side: float in [-1.0, 1.0]:
		_bevel_box(m, orange_dark, Vector3(0.90, carriage_y + 0.01, side * 0.35), Vector3(0.14, 0.19, 0.12), 0.022)
		# Crisp yellow/black hazard decal wrap on front & outer corner heel blocks
		_add_box_face_decal(m, hazard, Vector3(0.972, carriage_y + 0.01, side * 0.35), Vector3(0.0, 0.16, 0.10), Vector3.RIGHT, 1.0)
		_add_box_face_decal(m, hazard, Vector3(0.90, carriage_y + 0.01, side * 0.412), Vector3(0.11, 0.16, 0.0), Vector3(0, 0, side), 1.0)

		# Steel L-shaped tapered fork tine at z = +/-0.215 m extending cleanly to FORK_TIP_X (+1.70 m)
		var fz := side * 0.215
		_bevel_box(m, dark, Vector3(0.955, carriage_y + 0.04, fz), Vector3(0.085, 0.23, 0.11), 0.012)
		_bevel_box(m, steel, Vector3(0.985, 0.15, fz), Vector3(0.055, 0.20, 0.092), 0.008)
		# Tapered brushed steel horizontal fork blade
		var f_x0 := 0.98
		var f_x1 := BASE_FORK_TIP_X - 0.14
		var f_x2 := BASE_FORK_TIP_X
		var y_bot := 0.030
		var y_top0 := 0.068
		var y_top1 := 0.056
		var y_tip := 0.040
		var hw0 := 0.048
		var hw1 := 0.044
		var hw2 := 0.032
		# Main rear half of blade
		var r_bl := Vector3(f_x0, y_bot, fz - hw0); var r_br := Vector3(f_x0, y_bot, fz + hw0)
		var r_tl := Vector3(f_x0, y_top0, fz - hw0); var r_tr := Vector3(f_x0, y_top0, fz + hw0)
		var m_bl := Vector3(f_x1, y_bot, fz - hw1); var m_br := Vector3(f_x1, y_bot, fz + hw1)
		var m_tl := Vector3(f_x1, y_top1, fz - hw1); var m_tr := Vector3(f_x1, y_top1, fz + hw1)
		var t_bl := Vector3(f_x2, y_bot + 0.004, fz - hw2); var t_br := Vector3(f_x2, y_bot + 0.004, fz + hw2)
		var t_tl := Vector3(f_x2, y_tip, fz - hw2); var t_tr := Vector3(f_x2, y_tip, fz + hw2)
		# Top, sides, bottom, and wedge tip
		m.quad(steel, r_tl, m_tl, m_tr, r_tr, Vector3.UP)
		m.quad(steel, m_tl, t_tl, t_tr, m_tr, Vector3(0.1, 1.0, 0).normalized())
		m.quad(steel, r_bl, r_br, m_br, m_bl, Vector3.DOWN)
		m.quad(steel, m_bl, m_br, t_br, t_bl, Vector3.DOWN)
		m.quad(steel, r_bl, m_bl, m_tl, r_tl, Vector3.FORWARD)
		m.quad(steel, m_bl, t_bl, t_tl, m_tl, Vector3.FORWARD)
		m.quad(steel, r_br, r_tr, m_tr, m_br, Vector3.BACK)
		m.quad(steel, m_br, m_tr, t_tr, t_br, Vector3.BACK)
		m.quad(steel, t_bl, t_br, t_tr, t_tl, Vector3.RIGHT)


static func _add_mast_plate_decals(m: MeshBuilder, mat: Material, xform: Callable) -> void:
	# Side plates (+/-Z faces) and front plate (+X face) on the upper orange mast housing
	var y_lo := 1.08
	var y_hi := 1.72
	for side: float in [-1.0, 1.0]:
		var z := side * 0.127
		var a: Vector3 = xform.call(Vector3(-0.075, y_lo, z))
		var b: Vector3 = xform.call(Vector3(0.075, y_lo, z))
		var c: Vector3 = xform.call(Vector3(0.075, y_hi, z))
		var d: Vector3 = xform.call(Vector3(-0.075, y_hi, z))
		var n := Vector3(0, 0, side)
		m.quad(mat, a, b, c, d, n, n, n, n, n,
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	var fx := 0.092
	var fa: Vector3 = xform.call(Vector3(fx, y_lo, -0.105))
	var fb: Vector3 = xform.call(Vector3(fx, y_lo, 0.105))
	var fc: Vector3 = xform.call(Vector3(fx, y_hi, 0.105))
	var fd: Vector3 = xform.call(Vector3(fx, y_hi, -0.105))
	var fn := Vector3.RIGHT
	m.quad(mat, fa, fb, fc, fd, fn, fn, fn, fn, fn,
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))


static func _add_box_face_decal(m: MeshBuilder, mat: Material, center: Vector3, span: Vector3,
		normal: Vector3, uv_tile: float) -> void:
	var n := normal.normalized()
	var t_u := Vector3(0, 0, span.z if span.z > 0.001 else span.x).normalized()
	if absf(n.z) > 0.5:
		t_u = Vector3.RIGHT
	elif absf(n.x) > 0.5:
		t_u = Vector3.BACK
	var half_u := (span.z if absf(n.x) > 0.5 else span.x) * 0.5
	var half_v := span.y * 0.5
	var u := t_u * half_u
	var v := Vector3.UP * half_v
	m.quad(mat, center - u - v, center + u - v, center + u + v, center - u + v, n, n, n, n, n,
		Vector2(0, uv_tile), Vector2(uv_tile, uv_tile), Vector2(uv_tile, 0), Vector2(0, 0))


static func _bar(m: MeshBuilder, mat: Material, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(axis.z) > 0.95 else Vector3.BACK
	if absf(axis.dot(ref)) > 0.95:
		ref = Vector3.UP
	var u := axis.cross(ref).normalized() * (width * 0.5)
	var v := axis.cross(u).normalized() * (depth * 0.5)
	var pts: Array[Vector3] = [
		a - u - v, a + u - v, a + u + v, a - u + v,
		b - u - v, b + u - v, b + u + v, b - u + v,
	]
	var c := (a + b) * 0.5
	for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		var p0: Vector3 = pts[face[0]]
		var p1: Vector3 = pts[face[1]]
		var p2: Vector3 = pts[face[2]]
		var p3: Vector3 = pts[face[3]]
		var n := ((p0 + p1 + p2 + p3) * 0.25 - c).normalized()
		m.quad(mat, p0, p1, p2, p3, n)


static func _tube(m: MeshBuilder, mat: Material, a: Vector3, b: Vector3, radius: float, sectors: int) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	for i in sectors:
		var aa := TAU * i / sectors
		var ab := TAU * (i + 1) / sectors
		var p := u * cos(aa) + v * sin(aa)
		var q := u * cos(ab) + v * sin(ab)
		m.quad(mat, a + p * radius, a + q * radius, b + q * radius, b + p * radius, (p + q).normalized(), p, q, q, p)


static func _bevel_box(m: MeshBuilder, mat: Material, center: Vector3, size: Vector3, bevel: float) -> void:
	_bevel_box_xform(m, mat, center, size, bevel, func(p: Vector3) -> Vector3: return p)


static func _bevel_box_xform(m: MeshBuilder, mat: Material, center: Vector3, size: Vector3, bevel: float, xform: Callable) -> void:
	var half := size * 0.5
	var r := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.88)
	var core := half - Vector3.ONE * r
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side: float in [-1.0, 1.0]:
			var grid_u: Array[float] = [-half[u], -core[u], core[u], half[u]]
			var grid_v: Array[float] = [-half[v], -core[v], core[v], half[v]]
			for i in 3:
				for j in 3:
					var pts: Array[Vector3] = []
					var nrms: Array[Vector3] = []
					for pair: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
						var p := Vector3.ZERO
						p[axis] = half[axis] * side
						p[u] = grid_u[pair.x]
						p[v] = grid_v[pair.y]
						var anchor := p.clamp(-core, core)
						var nrm := (p - anchor).normalized()
						var local_pt := center + anchor + nrm * r
						var pt_xform: Vector3 = xform.call(local_pt)
						var n_xform: Vector3 = (xform.call(local_pt + nrm * 0.01) - pt_xform).normalized()
						pts.append(pt_xform)
						nrms.append(n_xform)
					var out_v := Vector3.ZERO
					out_v[axis] = side
					var out_xform: Vector3 = (xform.call(center + out_v * 0.01) - xform.call(center)).normalized()
					m.quad(mat, pts[0], pts[1], pts[2], pts[3], out_xform, nrms[0], nrms[1], nrms[2], nrms[3])


static func _get_hazard_texture() -> ImageTexture:
	if _cached_textures.has("hazard"):
		return _cached_textures["hazard"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var amber := Color("dfa020")
	var blk := Color("191c1f")
	for y in s:
		for x in s:
			var band := int(floor(float(x + y) / 32.0)) % 2
			img.set_pixel(x, y, blk if band == 0 else amber)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cached_textures["hazard"] = tex
	return tex


static func _get_mast_badge_texture() -> ImageTexture:
	if _cached_textures.has("mast_badge"):
		return _cached_textures["mast_badge"]
	var w := 128
	var h := 256
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	var orange := Color("d88c28")
	var dark := Color("1c2024")
	var amber := Color("e5aa24")
	var red := Color("cc3628")
	img.fill(orange)
	# Vertical recessed edge grooves + lower black-yellow hazard stripe zone
	for y in h:
		for x in w:
			if x < 5 or x > w - 6:
				img.set_pixel(x, y, orange.darkened(0.20))
			elif y >= 186 and y <= 248:
				var band := int(floor(float(x + y) / 20.0)) % 2
				img.set_pixel(x, y, dark if band == 0 else amber)
	# Crisp dark separator line above hazard band
	for x in range(6, w - 6):
		for yy in range(181, 185):
			img.set_pixel(x, yy, dark)
	# Upward red safety triangle near lower-right above hazard strip
	for dy in 22:
		for dx in range(-dy / 2, dy / 2 + 1):
			var px := 104 + dx
			var py := 146 + dy
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, red)
	# Bold high-contrast dark charcoal stenciled "LK-P 243" reading upward
	_draw_text_vertical(img, "LK-P 243", 52, 168, 3, dark)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cached_textures["mast_badge"] = tex
	return tex


static func _get_side_243_texture(mirror_arrow: bool) -> ImageTexture:
	var key := "side_243_%s" % str(mirror_arrow)
	if _cached_textures.has(key):
		return _cached_textures[key]
	var w := 144
	var h := 60
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	var orange := Color("d88c28")
	var trim := Color("edeae0")
	var shadow := Color("8d5210")
	img.fill(orange)
	# Tight crisp white bordered stencil badge box matching orange plate edges seamlessly
	for y in range(4, h - 4):
		for x in range(4, w - 4):
			var border := x < 9 or x >= w - 9 or y < 9 or y >= h - 9
			if border:
				img.set_pixel(x, y, trim)
			elif y == 9 or y == h - 10 or x == 9 or x == w - 10:
				img.set_pixel(x, y, shadow)
	# Arrow chevron next to "243"
	for dy in range(-10, 11):
		var span := 10 - absi(dy)
		for dx in span + 1:
			var ax := (124 - dx) if mirror_arrow else (20 + dx)
			img.set_pixel(ax, 30 + dy, trim)
	var text_x := 22 if mirror_arrow else 44
	_draw_text_horizontal(img, "243", text_x, 18, 5, trim)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cached_textures[key] = tex
	return tex


const FONT_3X5 := {
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"L": ["100", "100", "100", "100", "111"],
	"K": ["101", "101", "110", "101", "101"],
	"P": ["111", "101", "111", "100", "100"],
	"-": ["000", "000", "111", "000", "000"],
	" ": ["000", "000", "000", "000", "000"],
}


static func _draw_text_horizontal(img: Image, text: String, x0: int, y0: int, scale: int, col: Color) -> void:
	var cx := x0
	for ch_idx in text.length():
		var glyph: Array = FONT_3X5.get(text[ch_idx], FONT_3X5[" "])
		for row in 5:
			for c in 3:
				if glyph[row][c] == "1":
					for sy in scale:
						for sx in scale:
							var px := cx + c * scale + sx
							var py := y0 + row * scale + sy
							if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
								img.set_pixel(px, py, col)
		cx += 4 * scale


static func _draw_text_vertical(img: Image, text: String, x0: int, y_bottom: int, scale: int, col: Color) -> void:
	var cy := y_bottom
	for ch_idx in text.length():
		var glyph: Array = FONT_3X5.get(text[ch_idx], FONT_3X5[" "])
		for row in 5:
			for c in 3:
				if glyph[row][c] == "1":
					for sy in scale:
						for sx in scale:
							var px := x0 + row * scale + sx
							var py := cy - c * scale - sy
							if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
								img.set_pixel(px, py, col)
		cy -= 4 * scale
