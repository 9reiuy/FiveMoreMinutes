extends RefCounted
## Builds Level 1-1 in Arknights: Endfield clean tech-brutalist aesthetic (no glass enclosure over H06,
## no stairs descending to 1F base platform): dark damp 1F hangar bay + exposed H06 + crisp off-white
## suspended East/North L-corridors with crosshair glass balustrade on left and stencil walls + fake doors on right.

const L := preload("res://scripts/testing/h06_chapter/h06_base_layout.gd")
const MAT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const M := preload("res://scripts/testing/maintenance_environment.gd")
const CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const OPTICS := preload("res://scripts/dream/office_light_optics.gd")
const H06_MODEL := "res://art/Dream/H06/crawler_h06.glb"
const ACTOR_EDGE := 4 | (1 << 6)

var world: Node3D
var floor_root: Node3D
var wall_root: Node3D
var cutout := CUTOUT.new()
var m: MAT
var mech: Node3D
var mech_anim: AnimationPlayer
var _spot_pin: SpotLight3D
var _spot_key: SpotLight3D
var _spot_rim: SpotLight3D
var _bay_bounce: OmniLight3D
var _conduit_pool: OmniLight3D
var _standby_glow: OmniLight3D
var _reveal_tween: Tween
var _spotlight_revealed := false


func _init(owner_world: Node3D, defer_atrium_surfaces := false) -> void:
	world = owner_world
	floor_root = Node3D.new()
	floor_root.name = "AtriumLoopFloors"
	world.floor_root.add_child(floor_root)
	wall_root = Node3D.new()
	wall_root.name = "AtriumLoopArchitecture"
	world.wall_root.add_child(wall_root)
	m = MAT.new(cutout, world.global_transform.affine_inverse(), defer_atrium_surfaces)
	if world.get_meta(&"h06_resource_reuse",true):
		if not world.has_meta(&"h06_scenery_assets"):world.set_meta(&"h06_scenery_assets",{})
		m._quat_cache=world.get_meta(&"h06_scenery_assets")


func build() -> void:
	_build_1f_hangar_platform_and_piers()
	_build_endfield_hangar_hardware_and_h06()
	_build_suspended_corridors_and_stairs()
	_build_corridor_glass_balustrades()
	_build_right_walls_and_fake_doors()
	_build_walkability_colliders()
	_build_endfield_signage()
	_build_weathering_details()


func build_lighting(ceiling_root: Node3D) -> void:
	configure_environment()
	_build_atrium_lighting(ceiling_root)


func configure_environment() -> void:
	M.configure_environment(world)
	var env := world.get_node_or_null("Lighting/WorldEnvironment") as WorldEnvironment
	if env != null and env.environment != null:
		var e := env.environment
		e.background_color = Color("020508")
		e.ambient_light_color = Color("8ea4b0")
		e.ambient_light_energy = 0.068
		e.ssao_enabled = true
		e.ssao_radius = 1.25
		e.ssao_intensity = 1.15
		e.ssr_enabled = true
		e.ssr_max_steps = 48
		e.glow_enabled = true
		e.glow_intensity = 0.14
		e.glow_bloom = 0.06
		e.glow_hdr_threshold = 0.92

	var key := world.get_node_or_null("Lighting/KeyLight") as DirectionalLight3D
	if key != null:
		key.show()
		key.light_color = Color("adc0cc")
		key.light_energy = 0.11
		key.shadow_enabled = false


func _build_atrium_lighting(ceiling_root: Node3D) -> void:
	var light_root := Node3D.new()
	light_root.name = "AtriumLightingGrid"
	ceiling_root.add_child(light_root)

	# Subdued weak corridor sconces (low-key industrial lighting until player enters SE overlook)
	for ez: float in [3.55, 0.8, -2.5, -6.5]:
		var ey := L.ground_height(Vector2(5.5, ez))
		_corridor_wall_sconce(light_root, Vector3(7.36, ey + 2.66, ez), Vector3(0.14, 0.05, 1.15), Vector3(-0.72, -0.36, 0.0), Color("b8ced6"), 0.56, ez == 0.8 or ez == -6.5, ey)
	_omni(light_root, "SELandingPool", Vector3(5.8, L.CORRIDOR_ENTRY_Y + 2.35, 5.8), Color("b4cad2"), 0.48, 5.6, 1.35, false)

	for nx: float in [4.2, 0.1, -4.1, -7.2]:
		var ny := L.ground_height(Vector2(nx, -6.5))
		_corridor_wall_sconce(light_root, Vector3(nx, ny + 2.70, -8.34), Vector3(1.15, 0.05, 0.14), Vector3(0.0, -0.36, 0.72), Color("bad0d8"), 0.58, nx == 0.1 or nx == -4.1, ny)

	_omni(light_root, "EntrySpurPool", Vector3(9.6, L.CORRIDOR_ENTRY_Y + 2.20, 6.0), Color("b4cad2"), 0.52, 5.2, 1.35, false)

	# Overhead spotlight projectors mounted cleanly on architectural parapet edges
	_spot_canister(light_root, "BayParapetProjectorN", Vector3(-3.0, 5.88, -8.36), Vector3(-3.0, 0.50, 1.5))
	_spot_canister(light_root, "BayParapetProjectorE", Vector3(7.52, 5.06, -0.6), Vector3(-3.0, 0.50, 1.5))

	# Overhead theatrical H06 spotlights (start OFF in silhouette; triggered on SE entry)
	_spot_pin = _spot(light_root, "H06OverheadPin", Vector3(-3.0, 7.6, 0.8), Vector3(-3.0, 0.40, 1.5), Color("f4f9fc"), 0.0, 16.0, 26.0)
	_spot_key = _spot(light_root, "H06OverheadKey", Vector3(-0.6, 6.9, -0.7), Vector3(-3.0, 0.45, 1.5), Color("e6f2f6"), 0.0, 16.5, 36.0)
	_spot_rim = _spot(light_root, "H06OverheadRim", Vector3(-6.8, 5.2, 3.8), Vector3(-3.0, 0.50, 1.4), Color("ecd282"), 0.0, 14.5, 34.0)
	_bay_bounce = _omni(light_root, "H06BayBounce", Vector3(-3.0, 2.2, 1.5), Color("b4cad4"), 0.0, 7.4, 1.24, false)

	# Standby silhouette accents before reveal
	_standby_glow = _omni(light_root, "H06StandbyGlow", Vector3(-2.8, 1.45, 1.5), Color("b8322a"), 0.34, 2.8, 1.35, false)
	_conduit_pool = _omni(light_root, "ConduitWestPool", Vector3(-8.8, 2.10, 1.5), Color("a2bac4"), 0.16, 5.4, 1.34, false)
	_omni(light_root, "SouthDeckPool", Vector3(-2.8, 1.85, 7.6), Color("96acb6"), 0.08, 5.6, 1.38, false)
	_omni(light_root, "UnderGalleryPool", Vector3(2.2, 1.25, -1.5), Color("8ba2ac"), 0.10, 5.2, 1.38, false)

	# Subtle muted warm glow inside dark smoked office windows (201-205)
	for pos: Vector3 in [
		Vector3(8.05, 2.55, 1.7),
		Vector3(8.05, 3.05, -2.4),
		Vector3(8.05, 3.35, -6.7),
		Vector3(0.0, 3.35, -9.0),
		Vector3(-4.1, 4.15, -9.0),
	]:
		_omni(light_root, "SmokedOfficeBounce", pos, Color("cfa262"), 0.18, 2.4, 1.45, false)


func play_spotlight_reveal(immediate := false) -> void:
	if _spotlight_revealed and not immediate:
		return
	_spotlight_revealed = true
	if is_instance_valid(_reveal_tween):
		_reveal_tween.kill()
		_reveal_tween = null
	if immediate:
		if is_instance_valid(_spot_pin): _spot_pin.light_energy = 8.4
		if is_instance_valid(_spot_key): _spot_key.light_energy = 10.6
		if is_instance_valid(_spot_rim): _spot_rim.light_energy = 3.8
		if is_instance_valid(_bay_bounce): _bay_bounce.light_energy = 1.35
		if is_instance_valid(_conduit_pool): _conduit_pool.light_energy = 0.56
		if is_instance_valid(_standby_glow): _standby_glow.light_energy = 0.12
		m.spot_lens_mat.emission_energy_multiplier = 2.6
		return

	_reveal_tween = world.create_tween().set_parallel(true)
	if is_instance_valid(_spot_pin):
		var pin_tw := world.create_tween()
		pin_tw.tween_property(_spot_pin, "light_energy", 5.2, 0.05)
		pin_tw.tween_property(_spot_pin, "light_energy", 1.4, 0.07)
		pin_tw.tween_property(_spot_pin, "light_energy", 8.4, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(m.spot_lens_mat, "emission_energy_multiplier", 2.6, 0.16)
	if is_instance_valid(_spot_key):
		_reveal_tween.tween_property(_spot_key, "light_energy", 10.6, 0.85).set_delay(0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_spot_rim):
		_reveal_tween.tween_property(_spot_rim, "light_energy", 3.8, 0.90).set_delay(0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_bay_bounce):
		_reveal_tween.tween_property(_bay_bounce, "light_energy", 1.35, 0.85).set_delay(0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_conduit_pool):
		_reveal_tween.tween_property(_conduit_pool, "light_energy", 0.56, 0.70).set_delay(0.30)
	if is_instance_valid(_standby_glow):
		_reveal_tween.tween_property(_standby_glow, "light_energy", 0.12, 0.65).set_delay(0.25)


func reset_spotlight_reveal() -> void:
	_spotlight_revealed = false
	if is_instance_valid(_reveal_tween):
		_reveal_tween.kill()
		_reveal_tween = null
	if is_instance_valid(_spot_pin): _spot_pin.light_energy = 0.0
	if is_instance_valid(_spot_key): _spot_key.light_energy = 0.0
	if is_instance_valid(_spot_rim): _spot_rim.light_energy = 0.0
	if is_instance_valid(_bay_bounce): _bay_bounce.light_energy = 0.0
	if is_instance_valid(_conduit_pool): _conduit_pool.light_energy = 0.16
	if is_instance_valid(_standby_glow): _standby_glow.light_energy = 0.34
	m.spot_lens_mat.emission_energy_multiplier = 0.0


func _spot_canister(parent: Node3D, title: String, at: Vector3, look_at_pt: Vector3) -> void:
	var n := Node3D.new()
	n.name = title
	n.position = at
	n.transform = Transform3D(Basis.looking_at((look_at_pt - at).normalized(), Vector3.UP), at)
	parent.add_child(n)
	var body := m.cylinder(n, "SpotBody", 0.12, 0.34, Vector3.ZERO, m.steel_beam, Vector3.FORWARD)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens := m.cylinder(n, "SpotLens", 0.095, 0.04, Vector3(0.0, 0.0, -0.175), m.spot_lens_mat, Vector3.FORWARD)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _corridor_wall_sconce(parent: Node3D, at: Vector3, tube_size: Vector3, light_offset: Vector3,
		col: Color, energy: float, shadows: bool, floor_height: float) -> void:
	var housing := Node3D.new()
	housing.name = "CorridorLightHousing"
	housing.position = at
	parent.add_child(housing)
	var frame := m.box(housing, "SteelBaffle", tube_size + Vector3(0.08, 0.04, 0.08), Vector3(0.0, 0.03, 0.0), m.steel_mullion)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var diffuser := m.box(housing, "TubeDiffuser", tube_size, Vector3.ZERO, m.ceiling_diffuser)
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool := _omni(housing, "FixturePool", light_offset, col, energy, 4.8, 1.38, shadows)
	OPTICS.mark_fixture(housing, pool, [diffuser], floor_height)


func _build_1f_hangar_platform_and_piers() -> void:
	# 1. Deep charcoal-graphite damp 1F Base Hangar Platform (continuous under bay & corridors)
	var base_w := L.BASE_SLAB_RECT.size.x
	var base_d := L.BASE_SLAB_RECT.size.y
	var base_c := L.BASE_SLAB_RECT.get_center()
	m.box(floor_root, "Base1FHangarPlatform", Vector3(base_w, 0.48, base_d),
		Vector3(base_c.x, L.BASE_1F_Y - 0.24, base_c.y), m.base_concrete)

	# Crisp gunmetal steel fascia & thin Endfield yellow safety edge stripes on exposed 1F platform edges
	# Keep their tops under the continuous walking deck and the adjoining aprons.
	var fascia_y := L.BASE_1F_Y - 0.27
	m.box(floor_root, "BaseEdgeNorth", Vector3(base_w + 0.16, 0.50, 0.14), Vector3(base_c.x, fascia_y, L.BASE_SLAB_RECT.position.y - 0.05), m.steel_beam)
	m.box(floor_root, "BaseEdgeSouth", Vector3(base_w + 0.16, 0.50, 0.14), Vector3(base_c.x, fascia_y, L.BASE_SLAB_RECT.end.y + 0.05), m.steel_beam)
	m.box(floor_root, "BaseEdgeWest", Vector3(0.14, 0.50, base_d - 0.04), Vector3(L.BASE_SLAB_RECT.position.x - 0.05, fascia_y, base_c.y), m.steel_beam)
	m.box(floor_root, "BaseEdgeEast", Vector3(0.14, 0.50, base_d - 0.04), Vector3(L.BASE_SLAB_RECT.end.x + 0.05, fascia_y, base_c.y), m.steel_beam)
	m.box(floor_root, "BaseApronTrimS", Vector3(base_w - 0.3, 0.012, 0.09), Vector3(base_c.x, 0.006, L.BASE_SLAB_RECT.end.y - 0.25), m.endfield_yellow)
	m.box(floor_root, "BaseApronTrimW", Vector3(0.09, 0.012, base_d - 0.6), Vector3(L.BASE_SLAB_RECT.position.x + 0.25, 0.006, base_c.y), m.endfield_yellow)

	# Sub-foundation columns underneath the 1F concrete deck
	for px: float in [-9.6, -3.0, 3.6, 7.8]:
		for pz: float in [-8.8, 0.0, 8.8]:
			m.box(floor_root, "SubFoundationPier", Vector3(0.56, 2.20, 0.56), Vector3(px, -1.58, pz), m.dark_bulkhead)

	# Clean matte cool-grey concrete piers holding up East & North suspended corridors
	for px_e: float in [3.85, 7.15]:
		for pz_e: float in [7.8, 4.2, -0.4, -4.6, -8.1]:
			var soffit_y := L.ground_height(Vector2(px_e, pz_e)) - 0.24
			m.box(floor_root, "EastCorridorPier", Vector3(0.32, soffit_y, 0.32), Vector3(px_e, soffit_y * 0.5, pz_e), m.pier_concrete)
			m.box(floor_root, "PierBaseShoe", Vector3(0.46, 0.08, 0.46), Vector3(px_e, 0.04, pz_e), m.steel_beam)

	for px_n: float in [-0.2, -4.2, -8.1]:
		for pz_n: float in [-4.85, -8.15]:
			var soffit_yn := L.ground_height(Vector2(px_n, pz_n)) - 0.24
			m.box(floor_root, "NorthCorridorPier", Vector3(0.32, soffit_yn, 0.32), Vector3(px_n, soffit_yn * 0.5, pz_n), m.pier_concrete)
			m.box(floor_root, "PierBaseShoeN", Vector3(0.46, 0.08, 0.46), Vector3(px_n, 0.04, pz_n), m.steel_beam)

	# Structural struts supporting cantilevered Arrow 1 Entry Spur
	for sx: float in [8.8, 11.1]:
		for sz: float in [4.75, 7.25]:
			m.box(floor_root, "SpurStrut", Vector3(0.24, 3.20, 0.24), Vector3(sx, L.CORRIDOR_ENTRY_Y - 1.84, sz), m.steel_beam)

	# Under-corridor Endfield architectural charcoal bulkhead bays trimmed in hairline safety yellow!
	_build_east_service_wall("UnderGalleryBackEast",7.95,-8.4,7.4,.28,.98,2,m.wall_precast_charcoal,false)
	m.build_top_black_wall(wall_root, "UnderGalleryBackNorth", Vector3(-0.2, 0.98, -8.95), Vector3(16.6, 1.96, 0.28), 4, m.wall_precast_charcoal, false)
	for rx: float in [-5.8, -1.8, 2.0]:
		m.box(wall_root, "UnderArmorPanelN", Vector3(2.85, 1.55, 0.14), Vector3(rx, 0.85, -4.55), m.dark_bulkhead)
		m.box(wall_root, "UnderArmorTrimTopN", Vector3(2.88, 0.035, 0.16), Vector3(rx, 1.63, -4.55), m.endfield_yellow)
		m.box(wall_root, "UnderArmorTrimBotN", Vector3(2.88, 0.035, 0.16), Vector3(rx, 0.06, -4.55), m.endfield_yellow)
	for rz: float in [-1.5, 2.2, 5.8]:
		var armor_y := minf(L.ground_height(Vector2(3.5, rz)) - 0.28, 1.45)
		if armor_y > 0.40:
			m.box(wall_root, "UnderArmorPanelE", Vector3(0.14, armor_y, 2.65), Vector3(3.55, armor_y * 0.5 + 0.02, rz), m.dark_bulkhead)
			m.box(wall_root, "UnderArmorTrimE", Vector3(0.16, 0.035, 2.68), Vector3(3.55, armor_y + 0.02, rz), m.endfield_yellow)

	# Stenciled lower hangar wall tags matching Endfield '02 / 03' industrial markings
	_build_endfield_stencil_panel("UnderBayStencil_02", Vector3(-5.8, 0.90, -4.44), 0.0, 1.95, 0.88, "02")
	_build_endfield_stencil_panel("UnderBayStencil_03", Vector3(3.44, 0.72, 2.2), -90.0, 1.85, 0.80, "03")

	# Perimeter Endfield crosshair glass guardrail along exposed South & West 1F edges
	_build_lower_hangar_rails()


func _build_endfield_hangar_hardware_and_h06(vehicle_exit := false) -> void:
	# 1. Open recessed dark steel grate bay & chamfered test pad on 1F (NO glass box enclosure!)
	var r := L.H06_BAY_RECT
	var cx := r.get_center().x
	var cz := r.get_center().y
	m.box(floor_root, "H06SteelGrateFloor", Vector3(r.size.x, 0.04, r.size.y), Vector3(cx, 0.012, cz), m.pit_grate)

	# Crisp hairline Endfield safety yellow perimeter lines around the open test bay
	for sz: float in [r.position.y, r.end.y]:
		m.box(floor_root, "BayYellowBorderZ", Vector3(r.size.x + 0.12, 0.016, 0.09), Vector3(cx, 0.024, sz), m.endfield_yellow)
	for sx: float in [r.position.x, r.end.x]:
		m.box(floor_root, "BayYellowBorderX", Vector3(0.09, 0.016, r.size.y + 0.12), Vector3(sx, 0.024, cz), m.endfield_yellow)

	# Low open safety curb & dark bollards around open bay corners (zero sightline obstruction!)
	var west_bollard := -9.95 if vehicle_exit else r.position.x - 0.18
	for bx: float in [west_bollard, r.end.x + 0.18]:
		for bz: float in [r.position.y + 0.3, cz, r.end.y - 0.3]:
			m.cylinder(wall_root, "BaySafetyBollard", 0.065, 0.52, Vector3(bx, 0.26, bz), m.dark_bulkhead)
			m.cylinder(wall_root, "BayBollardYellow", 0.070, 0.10, Vector3(bx, 0.44, bz), m.endfield_yellow)
	for cor_x: float in [r.position.x + 0.08, r.end.x - 0.08]:
		for cor_z: float in [r.position.y + 0.08, r.end.y - 0.08]:
			m.box(wall_root, "BayCornerBeacon", Vector3(0.14, 0.05, 0.14), Vector3(cor_x, 0.055, cor_z), m.bay_beacon_emit)

	# Elevated H06 heavy dark steel test plinth + safety yellow edge ticks
	m.box(floor_root, "H06PlinthPad", Vector3(6.2, 0.14, 4.8), Vector3(cx, 0.07, cz), m.pit_plinth_floor)
	m.box(floor_root, "H06PlinthRim", Vector3(6.34, 0.10, 4.94), Vector3(cx, 0.05, cz), m.steel_beam)
	for sx_p: float in [-3.10, 3.10]:
		m.box(floor_root, "H06PadLineX", Vector3(0.08, 0.018, 4.92), Vector3(cx + sx_p, 0.145, cz), m.endfield_yellow)
	for sz_p: float in [-2.40, 2.40]:
		m.box(floor_root, "H06PadLineZ", Vector3(6.28, 0.018, 0.08), Vector3(cx, 0.145, cz + sz_p), m.endfield_yellow)

	_build_west_conduits()

	# 3 slim black portal frames suspending iconic Endfield yellow overhead alignment rings along West bay edge
	var mast_x := -9.0 if vehicle_exit else -7.25
	for mz: float in [-1.8, 0.6, 3.0]:
		m.cylinder(wall_root, "RingMastPoleL", 0.028, 3.84, Vector3(mast_x-.50, 1.92, mz), m.steel_beam)
		m.cylinder(wall_root, "RingMastPoleR", 0.028, 3.84, Vector3(mast_x+.50, 1.92, mz), m.steel_beam)
		m.pipe(wall_root, Vector3(mast_x-.52, 3.84, mz), Vector3(mast_x+.52, 3.84, mz), 0.024, m.steel_beam)
		m.pipe(wall_root, Vector3(mast_x-.50, 0.08, mz), Vector3(mast_x+.50, 0.08, mz), 0.020, m.steel_beam)
		m.pipe(wall_root, Vector3(mast_x, 3.84, mz), Vector3(mast_x, 3.60, mz), 0.020, m.steel_mullion)
		m.torus_ring(wall_root, "EndfieldAlignRing", 0.46, 0.32, Vector3(mast_x, 3.16, mz), m.endfield_yellow_emit, Vector3(90.0, 0.0, 0.0))

	# Clean floor power umbilicals, Endfield technical instrument boxes & low safety cones on 1F platform
	if vehicle_exit:
		_safety_cone(Vector3(2.60,0,6.75))
		_white_instrument_box(Vector3(2.46,0,7.55),14.0)
		_white_instrument_box(Vector3(2.63,0,8.32),-20.0)
	else:
		m.pipe(wall_root, Vector3(-9.05, 0.26, 0.2), Vector3(cx - 2.6, 0.14, 0.2), 0.045, m.dark_bulkhead)
		m.pipe(wall_root, Vector3(-9.05, 0.26, 2.6), Vector3(cx - 2.4, 0.14, 2.6), 0.045, m.dark_bulkhead)
		m.spawn_quaternius(wall_root, "Prop_Cable_1", Vector3(cx - 2.2, 0.03, cz + 3.1), 22.0, Vector3(1.1, 1.0, 1.1), false, true)
		m.spawn_quaternius(wall_root, "Prop_Cable_3", Vector3(cx + 2.4, 0.03, cz - 2.4), -30.0, Vector3(1.0, 1.0, 1.0), false, true)
		_safety_cone(Vector3(-6.4,0,6.75))
		_safety_cone(Vector3(-0.2,0,6.85))
		_white_instrument_box(Vector3(-4.2, 0.0, 7.15), 14.0)
		_white_instrument_box(Vector3(-3.3, 0.0, 7.25), -20.0)
	_safety_cone(Vector3(2.4, 0.0, 4.95), true)
	_place_maintenance_prop(wall_root, "switchgear", Vector3(-9.75, 0.0, -2.5), Vector3(0.68, 1.40, 0.85), 90.0)

	# Exposed H06 Tactical Crawler centered boldly on the open test bay
	_build_crawler(Vector3(cx, 0.14, cz))


func _build_lower_hangar_rails() -> void:
	_glass_rail_span(Vector3(-10.45,0,8.95),Vector3(3.25,0,8.95),.78)
	_glass_rail_span(Vector3(-10.45,0,-3.5),Vector3(-10.45,0,8.95),.85)

func _build_east_service_wall(title: String, x: float, start: float, end: float, depth: float, h: float, faces: int, mat: Material, register: bool) -> void:
	m.build_top_black_wall(wall_root,title,Vector3(x,h*.5,(start+end)*.5),Vector3(depth,h,end-start),faces,mat,register)

func _build_west_conduits() -> void:
	for level_y: float in [0.58, 1.34]:
		m.cylinder(wall_root, "CryoConduitTube", 0.28, 5.4, Vector3(-9.35, level_y, 1.4), m.endfield_white_tube, Vector3.BACK)
		for band_z: float in [-0.6, 1.4, 3.4]:
			m.cylinder(wall_root, "ConduitClampDark", 0.305, 0.22, Vector3(-9.35, level_y, band_z), m.dark_bulkhead, Vector3.BACK)
			m.cylinder(wall_root, "ConduitYellowRing", 0.312, 0.045, Vector3(-9.35, level_y, band_z + 0.14), m.endfield_yellow_emit, Vector3.BACK)
	for leg_z: float in [-0.6, 3.4]:
		m.box(wall_root, "ConduitStanchion", Vector3(0.46, 1.65, 0.18), Vector3(-9.35, 0.82, leg_z), m.steel_beam)


func _build_crawler(at: Vector3) -> void:
	var reuse: bool=world.get_meta(&"h06_resource_reuse",true)
	var packed: PackedScene=world.get_meta(&"h06_crawler_asset") if reuse and world.has_meta(&"h06_crawler_asset") else null
	if packed==null:
		packed=load(H06_MODEL) as PackedScene
		if reuse and packed!=null:world.set_meta(&"h06_crawler_asset",packed)
	if packed != null:
		mech = packed.instantiate() as Node3D
		mech.name = "H06_TacticalCrawler"
		mech.position = at
		mech.rotation.y = deg_to_rad(28.0)
		mech.scale = Vector3(1.44, 1.44, 1.44)
		wall_root.add_child(mech)
		for node: Node in mech.find_children("*", "AnimationPlayer", true, false):
			mech_anim = node as AnimationPlayer
			var anims := mech_anim.get_animation_list()
			if not anims.is_empty():
				mech_anim.play(anims[0])
				mech_anim.seek(0.25, true)
				mech_anim.pause()
				break


func _safety_cone(at: Vector3, knocked := false) -> void:
	var n := Node3D.new()
	n.name = "SafetyCone"
	n.position = at + (Vector3(0.0, 0.105, 0.0) if knocked else Vector3.ZERO)
	if knocked:
		n.rotation_degrees = Vector3(84.0, 38.0, 14.0)
	wall_root.add_child(n)
	m.box(n, "ConeBase", Vector3(0.26, 0.035, 0.26), Vector3(0.0, 0.018, 0.0), m.steel_beam)
	var cone := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.025
	cmesh.bottom_radius = 0.105
	cmesh.height = 0.38
	cmesh.radial_segments = 10
	cone.mesh = cmesh
	cone.material_override = m.endfield_yellow
	cone.position = Vector3(0.0, 0.21, 0.0)
	n.add_child(cone)


func _white_instrument_box(at: Vector3, yaw_deg: float) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = deg_to_rad(yaw_deg)
	wall_root.add_child(n)
	m.box(n, "CaseBody", Vector3(0.42, 0.36, 0.34), Vector3(0.0, 0.18, 0.0), m.endfield_white_tube)
	m.box(n, "CaseTrim", Vector3(0.44, 0.06, 0.36), Vector3(0.0, 0.05, 0.0), m.steel_beam)
	m.box(n, "CaseLabel", Vector3(0.18, 0.08, 0.02), Vector3(0.0, 0.24, 0.175), m.endfield_yellow)


func _build_suspended_corridors_and_stairs() -> void:
	# 1. Entry Spur (Arrow 1: X:[7.5..11.5], Z:[4.5..7.5], Y=1.28)
	_suspended_deck(floor_root, "EntrySpurDeck", Vector3(9.5, L.CORRIDOR_ENTRY_Y, 6.0), Vector2(4.0, 3.0))
	m.box(floor_root, "SpurYellowTrack", Vector3(4.0, 0.014, 0.14), Vector3(9.425, L.CORRIDOR_ENTRY_Y + 0.007, 6.0), m.endfield_yellow)

	# 2. East Suspended SE Landing (X:[3.5..7.5], Z:[3.5..8.5], Y=1.28)
	_suspended_deck(floor_root, "SELandingDeck", Vector3(5.5, L.CORRIDOR_ENTRY_Y, 6.0), Vector2(4.0, 5.0))
	m.box(floor_root, "SECrossTrack", Vector3(2.25, 0.014, 0.14), Vector3(6.30, L.CORRIDOR_ENTRY_Y + 0.007, 6.0), m.endfield_yellow)
	m.box(floor_root, "EastLowerTrack", Vector3(0.14, 0.014, 2.55), Vector3(5.20, L.CORRIDOR_ENTRY_Y + 0.007, 4.78), m.endfield_yellow)

	# 3. East Suspended Ascending Stair Flight (Arrow 2: X:[3.5..7.5], Z: 3.5 -> -2.5, Y: 1.28 -> 2.24)
	_build_stair_flight_z("EastCorridorStair", 5.5, 4.0,
		L.EAST_STAIR_Z_START, L.EAST_STAIR_Z_END, L.CORRIDOR_ENTRY_Y, L.NE_LANDING_Y, L.EAST_STAIR_STEPS, true)

	# 4. NE Corner Landing (X:[1.5..7.5], Z:[-8.5..-2.5], Y=2.24)
	_suspended_deck(floor_root, "NELandingDeckEast", Vector3(5.5, L.NE_LANDING_Y, -5.5), Vector2(4.0, 6.0))
	_suspended_deck(floor_root, "NELandingDeckBridge", Vector3(2.5, L.NE_LANDING_Y, -6.5), Vector2(2.0, 4.0))
	m.box(floor_root, "NETrackNorth", Vector3(0.14, 0.014, 3.75), Vector3(5.20, L.NE_LANDING_Y + 0.007, -4.35), m.endfield_yellow)
	m.box(floor_root, "NETrackTurn", Vector3(3.85, 0.014, 0.14), Vector3(3.35, L.NE_LANDING_Y + 0.007, -6.20), m.endfield_yellow)

	# 5. North Upper Ascending Stair Flight (Arrow 3: Z:[-8.5..-4.5], X: 1.5 -> -2.5, Y: 2.24 -> 3.04)
	_build_stair_flight_x("NorthCorridorStair", -6.5, 4.0,
		L.NORTH_STAIR_X_START, L.NORTH_STAIR_X_END, L.NE_LANDING_Y, L.NW_GALLERY_Y, L.NORTH_STAIR_STEPS, true)

	# 6. NW Upper Gallery (X:[-8.5..-2.5], Z:[-8.5..-4.5], Y=3.04)
	_suspended_deck(floor_root, "NWGalleryDeck", Vector3(-5.5, L.NW_GALLERY_Y, -6.5), Vector2(6.0, 4.0))
	m.box(floor_root, "NWTrackWest", Vector3(5.40, 0.014, 0.14), Vector3(-5.15, L.NW_GALLERY_Y + 0.007, -6.20), m.endfield_yellow)


func _suspended_deck(parent: Node3D, title: String, top_center: Vector3, span_xz: Vector2) -> void:
	m.box(parent, title + "_Tile", Vector3(span_xz.x, 0.08, span_xz.y),
		Vector3(top_center.x, top_center.y - 0.04, top_center.z), m.corridor_floor)
	m.box(parent, title + "_Soffit", Vector3(span_xz.x - 0.04, 0.18, span_xz.y - 0.04),
		Vector3(top_center.x, top_center.y - 0.17, top_center.z), m.wall_precast_charcoal)
	m.box(parent, title + "_SteelFascia", Vector3(span_xz.x + 0.04, 0.11, span_xz.y + 0.04),
		Vector3(top_center.x, top_center.y - 0.12, top_center.z), m.steel_beam)


func _build_stair_flight_z(prefix: String, center_x: float, width: float, z0: float, z1: float, y0: float, y1: float, steps: int, with_yellow := false) -> void:
	var dir := 1.0 if z1 > z0 else -1.0
	var run := absf(z1 - z0)
	var step_d := run / float(steps)
	var step_h := (y1 - y0) / float(steps)
	for i in steps:
		var tread_y := y0 + (float(i) + 1.0) * step_h
		var tread_z := z0 + dir * (float(i) + 0.5) * step_d
		m.box(floor_root, "%s_Step_%d" % [prefix, i], Vector3(width - 0.02, 0.20, step_d + 0.04),
			Vector3(center_x, tread_y - 0.10, tread_z), m.corridor_floor)
		m.box(floor_root, "%s_Nosing_%d" % [prefix, i], Vector3(width - 0.04, 0.022, 0.045),
			Vector3(center_x, tread_y - 0.004, tread_z - dir * (step_d * 0.48)), m.steel_rail)
		if with_yellow:
			m.box(floor_root, "%s_Track_%d" % [prefix, i], Vector3(0.14, 0.012, step_d - 0.10),
				Vector3(5.20, tread_y + 0.006, tread_z), m.endfield_yellow)
	var slope_len := Vector2(run, absf(y1 - y0)).length()
	var angle := atan2(y1 - y0, run) * (-1.0 if dir > 0.0 else 1.0)
	var stringer := m.box(floor_root, prefix + "_Stringer", Vector3(width - 0.08, 0.22, slope_len),
		Vector3(center_x, (y0 + y1) * 0.5 - 0.20, (z0 + z1) * 0.5), m.steel_beam)
	stringer.rotation.x = angle


func _build_stair_flight_x(prefix: String, center_z: float, depth: float, x0: float, x1: float, y0: float, y1: float, steps: int, with_yellow := false) -> void:
	var dir := 1.0 if x1 > x0 else -1.0
	var run := absf(x1 - x0)
	var step_w := run / float(steps)
	var step_h := (y1 - y0) / float(steps)
	for i in steps:
		var tread_y := y0 + (float(i) + 1.0) * step_h
		var tread_x := x0 + dir * (float(i) + 0.5) * step_w
		m.box(floor_root, "%s_Step_%d" % [prefix, i], Vector3(step_w + 0.04, 0.20, depth - 0.02),
			Vector3(tread_x, tread_y - 0.10, center_z), m.corridor_floor)
		m.box(floor_root, "%s_Nosing_%d" % [prefix, i], Vector3(0.045, 0.022, depth - 0.04),
			Vector3(tread_x - dir * (step_w * 0.48), tread_y - 0.004, center_z), m.steel_rail)
		if with_yellow:
			m.box(floor_root, "%s_Track_%d" % [prefix, i], Vector3(step_w - 0.10, 0.012, 0.14),
				Vector3(tread_x, tread_y + 0.006, -6.20), m.endfield_yellow)
	var slope_len := Vector2(run, absf(y1 - y0)).length()
	var angle := atan2(y1 - y0, run) * (1.0 if dir > 0.0 else -1.0)
	var stringer := m.box(floor_root, prefix + "_Stringer", Vector3(slope_len, 0.22, depth - 0.08),
		Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.20, center_z), m.steel_beam)
	stringer.rotation.z = angle


func _build_corridor_glass_balustrades(close_entry_end := true) -> void:
	# Left side of travel overlooking H06 + continuous south/west edge guardrails (SE apron stair removed!)
	_glass_rail_span(Vector3(3.52, L.CORRIDOR_ENTRY_Y, 8.45), Vector3(3.52, L.CORRIDOR_ENTRY_Y, 3.50), 1.02)
	_glass_rail_span(Vector3(3.52, L.CORRIDOR_ENTRY_Y, 3.50), Vector3(3.52, L.NE_LANDING_Y, -2.50), 1.02)
	_glass_rail_span(Vector3(3.52, L.NE_LANDING_Y, -2.50), Vector3(3.52, L.NE_LANDING_Y, -4.52), 1.02)

	_glass_rail_span(Vector3(3.52, L.NE_LANDING_Y, -4.52), Vector3(1.50, L.NE_LANDING_Y, -4.52), 1.02)
	_glass_rail_span(Vector3(1.50, L.NE_LANDING_Y, -4.52), Vector3(-2.50, L.NW_GALLERY_Y, -4.52), 1.02)
	_glass_rail_span(Vector3(-2.50, L.NW_GALLERY_Y, -4.52), Vector3(-8.45, L.NW_GALLERY_Y, -4.52), 1.02)

	# Entry Spur floating bridge guardrails & solid continuous SE landing South parapet (no stair cutout!)
	_glass_rail_span(Vector3(7.55, L.CORRIDOR_ENTRY_Y, 4.55), Vector3(11.45, L.CORRIDOR_ENTRY_Y, 4.55), 0.96)
	_glass_rail_span(Vector3(7.55, L.CORRIDOR_ENTRY_Y, 7.45), Vector3(11.45, L.CORRIDOR_ENTRY_Y, 7.45), 0.78)
	_glass_rail_span(Vector3(3.55, L.CORRIDOR_ENTRY_Y, 8.45), Vector3(7.45, L.CORRIDOR_ENTRY_Y, 8.45), 0.78)
	_glass_rail_span(Vector3(7.45, L.CORRIDOR_ENTRY_Y, 7.45), Vector3(7.45, L.CORRIDOR_ENTRY_Y, 8.45), 0.78)
	if close_entry_end:
		_glass_rail_span(Vector3(11.45, L.CORRIDOR_ENTRY_Y, 4.55), Vector3(11.45, L.CORRIDOR_ENTRY_Y, 7.45), 0.88)


func _glass_rail_span(a: Vector3, b: Vector3, h: float) -> void:
	var delta := b - a
	var flat_len := Vector2(delta.x, delta.z).length()
	if flat_len < 0.05:
		return
	var posts := maxi(2, int(ceilf(flat_len / 1.5)) + 1)
	for i in posts:
		var p := a.lerp(b, float(i) / float(posts - 1))
		m.box(wall_root, "RailPost", Vector3(0.055, h, 0.055), p + Vector3(0.0, h * 0.5, 0.0), m.steel_mullion)
	m.pipe(wall_root, a + Vector3(0.0, h, 0.0), b + Vector3(0.0, h, 0.0), 0.026, m.steel_rail)
	m.pipe(wall_root, a + Vector3(0.0, 0.08, 0.0), b + Vector3(0.0, 0.08, 0.0), 0.018, m.steel_mullion)

	var mid := (a + b) * 0.5 + Vector3(0.0, h * 0.5, 0.0)
	var yaw := atan2(-delta.z, delta.x)
	var slope_len := delta.length()
	var tilt := atan2(delta.y, flat_len)
	var panel_w := slope_len - 0.04
	var panel_h := h - 0.16
	var panel := m.quad(wall_root, "BalustradeGlass", Vector2(panel_w, panel_h), mid, m.glass_rail_for_span(panel_w, panel_h))
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.rotation.y = yaw
	panel.rotation.z = tilt


func _build_right_walls_and_fake_doors() -> void:
	const EAST_WALL_TOP_Y := 5.14
	const NORTH_WALL_TOP_Y := 5.96

	_build_east_service_wall("EastCorridorOuterShell",8.75,-9.55,4.45,.66,EAST_WALL_TOP_Y,2 | 4,m.wall_composite,true)
	_build_north_shell(NORTH_WALL_TOP_Y)
	m.build_top_black_wall(wall_root, "NWEndCapWall", Vector3(-8.68, L.NW_GALLERY_Y + (NORTH_WALL_TOP_Y - L.NW_GALLERY_Y) * 0.5, -6.5),
		Vector3(0.36, NORTH_WALL_TOP_Y - L.NW_GALLERY_Y, 4.20), 1 | 4 | 8, m.wall_composite)

	m.build_top_black_wall(wall_root, "EastRoofParapet", Vector3(7.98, (4.38 + EAST_WALL_TOP_Y) * 0.5, -2.05), Vector3(0.92, EAST_WALL_TOP_Y - 4.38, 13.0), 2, m.wall_composite)
	m.build_top_black_wall(wall_root, "NorthRoofParapet", Vector3(-0.35, (5.24 + NORTH_WALL_TOP_Y) * 0.5, -8.92), Vector3(17.6, NORTH_WALL_TOP_Y - 5.24, 0.92), 1 | 2 | 4, m.wall_composite)

	for pz_col: float in [4.35, 0.25, -3.75, -8.40]:
		var yc := L.ground_height(Vector2(7.35, pz_col))
		m.spawn_quaternius(wall_root, "Column_Astra", Vector3(7.42, yc, pz_col), 90.0, Vector3(0.65, 0.92, 0.42), true, false)
	for px_col: float in [3.50, -1.40, -5.00, -8.35]:
		var xn := L.ground_height(Vector2(px_col, -8.35))
		m.spawn_quaternius(wall_root, "Column_Astra", Vector3(px_col, xn, -8.42), 0.0, Vector3(0.65, 0.92, 0.42), true, false)

	# EAST WALL: clean matte off-white concrete + fake doors 201..203 + dark smoked windows + Endfield '01'/'02' stencils
	_build_fake_door_bay_east(3.55, L.ground_height(Vector2(7.3, 3.55)), EAST_WALL_TOP_Y, "201", m.endfield_yellow, true)
	_build_smoked_window_bay_east(1.65, L.ground_height(Vector2(7.3, 1.65)), EAST_WALL_TOP_Y, 2.25, "OfficeBay201", false)
	_build_solid_panel_east(4.18, 0.54, L.CORRIDOR_ENTRY_Y, EAST_WALL_TOP_Y)

	_build_fake_door_bay_east(-0.65, L.ground_height(Vector2(7.3, -0.65)), EAST_WALL_TOP_Y, "202", m.endfield_yellow, false)
	_build_smoked_window_bay_east(-2.35, L.ground_height(Vector2(7.3, -2.35)), EAST_WALL_TOP_Y, 2.10, "OfficeBay202", true)

	_build_fake_door_bay_east(-4.80, L.NE_LANDING_Y, EAST_WALL_TOP_Y, "203", m.endfield_yellow, false)
	_build_smoked_window_bay_east(-6.70, L.NE_LANDING_Y, EAST_WALL_TOP_Y, 2.40, "OfficeBay203", false)
	m.spawn_quaternius(wall_root, "Prop_Vent_Wide", Vector3(7.42, L.NE_LANDING_Y + 2.48, -6.70), 90.0, Vector3(0.85, 0.85, 0.85), false, true)

	# NORTH WALL: giant bold '02 //' and '03 //' Endfield concrete stencil bays + 204/205/206 fake doors
	_build_solid_panel_north(5.50, 3.80, L.NE_LANDING_Y, NORTH_WALL_TOP_Y)
	_build_endfield_stencil_panel("Stencil_02_NE", Vector3(4.95, L.NE_LANDING_Y + 1.50, -8.41), 0.0, 2.35, 0.92, "02")
	_place_maintenance_prop(wall_root, "switchgear", Vector3(6.6, L.NE_LANDING_Y, -8.12), Vector3(0.75, 1.25, 0.42), 0.0)
	m.spawn_quaternius(wall_root, "Prop_Vent_Wide", Vector3(5.2, L.NE_LANDING_Y + 2.45, -8.40), 0.0, Vector3(0.95, 0.85, 0.85), false, true)

	_build_fake_door_bay_north(2.45, L.NE_LANDING_Y, NORTH_WALL_TOP_Y, "204", m.burgundy_placard, "DR. AMARAL  204")
	_build_smoked_window_bay_north(-0.15, L.ground_height(Vector2(-0.15, -8.3)), NORTH_WALL_TOP_Y, 2.50, "OfficeBay204", true)

	_build_fake_door_bay_north(-2.65, L.NW_GALLERY_Y, NORTH_WALL_TOP_Y, "205", m.endfield_yellow, "")
	_build_smoked_window_bay_north(-4.15, L.NW_GALLERY_Y, NORTH_WALL_TOP_Y, 1.65, "OfficeBay205", false)
	_build_fake_door_bay_north(-6.05, L.NW_GALLERY_Y, NORTH_WALL_TOP_Y, "206", m.endfield_yellow, "")
	_build_solid_panel_north(-7.60, 1.70, L.NW_GALLERY_Y, NORTH_WALL_TOP_Y)
	_build_endfield_stencil_panel("Stencil_03_NW", Vector3(-8.46, L.NW_GALLERY_Y + 1.45, -6.50), 90.0, 2.35, 0.92, "03")
	m.spawn_quaternius(wall_root, "Prop_Vent_Wide", Vector3(-7.4, L.NW_GALLERY_Y + 2.42, -8.40), 0.0, Vector3(0.85, 0.85, 0.85), false, true)


func _build_north_shell(height: float) -> void:
	m.build_top_black_wall(wall_root, "NorthCorridorOuterShell", Vector3(-0.20, height * 0.5, -9.25), Vector3(18.5, height, 0.66), 1 | 2 | 4, m.wall_composite)


func _build_solid_panel_east(center_z: float, span_z: float, base_y: float, top_y: float) -> void:
	var h := top_y - base_y
	m.build_top_black_wall(wall_root, "EastSolidPanel", Vector3(7.98, base_y + h * 0.5, center_z), Vector3(0.96, h, span_z), 2, m.wall_composite)


func _build_solid_panel_north(center_x: float, span_x: float, base_y: float, top_y: float) -> void:
	var h := top_y - base_y
	m.build_top_black_wall(wall_root, "NorthSolidPanel", Vector3(center_x, base_y + h * 0.5, -8.92), Vector3(span_x, h, 0.96), 4, m.wall_composite)


func _build_fake_door_bay_east(z_center: float, floor_y: float, top_y: float, room_code: String, accent_mat: Material, with_exit: bool) -> void:
	var h := top_y - floor_y
	m.build_top_black_wall(wall_root, "DoorSurroundE_" + room_code, Vector3(8.04, floor_y + h * 0.5, z_center), Vector3(0.88, h, 1.38), 2, m.wall_composite)
	m.box(wall_root, "DoorFrameE_" + room_code, Vector3(0.16, 2.28, 1.14), Vector3(7.55, floor_y + 1.14, z_center), m.door_frame)
	m.box(wall_root, "DoorLeafE_" + room_code, Vector3(0.08, 2.18, 0.96), Vector3(7.58, floor_y + 1.09, z_center), m.door_leaf)
	m.box(wall_root, "DoorVisionSlitE_" + room_code, Vector3(0.09, 0.85, 0.10), Vector3(7.57, floor_y + 1.42, z_center - 0.24), m.glass_smoked_office)
	m.box(wall_root, "DoorHandleE_" + room_code, Vector3(0.05, 0.16, 0.04), Vector3(7.52, floor_y + 1.02, z_center + 0.34), m.steel_rail)
	m.box(wall_root, "DoorKickPlateE_" + room_code, Vector3(0.09, 0.26, 0.92), Vector3(7.57, floor_y + 0.14, z_center), m.steel_beam)

	_build_room_plaque("PlaqueE_" + room_code, Vector3(7.48, floor_y + 1.56, z_center + 0.78), -90.0, room_code, accent_mat)

	if with_exit:
		m.box(wall_root, "ExitBracketE", Vector3(0.28, 0.06, 0.06), Vector3(7.32, floor_y + 2.48, z_center), m.steel_mullion)
		var ex := m.box(wall_root, "ExitBladeE", Vector3(0.38, 0.20, 0.05), Vector3(7.24, floor_y + 2.38, z_center), m.exit_green)
		ex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_fake_door_bay_north(x_center: float, floor_y: float, top_y: float, room_code: String, accent_mat: Material, header_label: String) -> void:
	var h := top_y - floor_y
	m.build_top_black_wall(wall_root, "DoorSurroundN_" + room_code, Vector3(x_center, floor_y + h * 0.5, -8.98), Vector3(1.38, h, 0.88), 4, m.wall_composite)
	m.box(wall_root, "DoorFrameN_" + room_code, Vector3(1.14, 2.28, 0.16), Vector3(x_center, floor_y + 1.14, -8.48), m.door_frame)
	m.box(wall_root, "DoorLeafN_" + room_code, Vector3(0.96, 2.18, 0.08), Vector3(x_center, floor_y + 1.09, -8.52), m.door_leaf)
	m.box(wall_root, "DoorVisionSlitN_" + room_code, Vector3(0.10, 0.85, 0.09), Vector3(x_center - 0.24, floor_y + 1.42, -8.50), m.glass_smoked_office)
	m.box(wall_root, "DoorHandleN_" + room_code, Vector3(0.04, 0.16, 0.05), Vector3(x_center + 0.34, floor_y + 1.02, -8.46), m.steel_rail)
	m.box(wall_root, "DoorKickPlateN_" + room_code, Vector3(0.92, 0.26, 0.09), Vector3(x_center, floor_y + 0.14, -8.50), m.steel_beam)

	_build_room_plaque("PlaqueN_" + room_code, Vector3(x_center - 0.78, floor_y + 1.56, -8.42), 0.0, room_code, accent_mat)

	if not header_label.is_empty():
		m.box(wall_root, "AmaralPlacardBg", Vector3(1.70, 0.34, 0.06), Vector3(x_center, floor_y + 2.48, -8.44), m.burgundy_placard)
		var lbl := Label3D.new()
		lbl.text = header_label
		lbl.font_size = 24
		lbl.pixel_size = 0.0074
		lbl.outline_size = 0
		lbl.modulate = Color("d8dcd9")
		lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		lbl.position = Vector3(x_center, floor_y + 2.48, -8.40)
		wall_root.add_child(lbl)


func _build_smoked_window_bay_east(z_center: float, floor_y: float, top_y: float, span_z: float, title: String, with_server: bool) -> void:
	# Endfield charcoal lower kickboard + crisp hairline yellow sill strip beneath smoked office window
	var header_y0 := floor_y + 2.16
	var header_h := maxf(0.45, top_y - header_y0)
	m.build_top_black_wall(wall_root, title + "_Sill", Vector3(7.80, floor_y + 0.42, z_center), Vector3(0.50, 0.84, span_z), 2, m.wall_composite)
	m.build_top_black_wall(wall_root, title + "_Header", Vector3(7.98, header_y0 + header_h * 0.5, z_center), Vector3(0.86, header_h, span_z), 2, m.wall_composite)
	m.box(wall_root, title + "_AlcoveFloor", Vector3(0.95, 0.10, span_z - 0.04), Vector3(8.02, floor_y + 0.05, z_center), m.office_interior_wall)
	m.box(wall_root, title + "_CharcoalKick", Vector3(0.06, 0.78, span_z - 0.08), Vector3(7.53, floor_y + 0.40, z_center), m.dark_bulkhead)
	m.box(wall_root, title + "_YellowTrim", Vector3(0.08, 0.04, span_z - 0.08), Vector3(7.52, floor_y + 0.78, z_center), m.endfield_yellow)
	m.box(wall_root, title + "_SillCap", Vector3(0.14, 0.06, span_z - 0.04), Vector3(7.56, floor_y + 0.84, z_center), m.steel_mullion)
	m.box(wall_root, title + "_Mullion", Vector3(0.10, 1.32, 0.07), Vector3(7.56, floor_y + 1.50, z_center), m.steel_mullion)
	var win := m.box(wall_root, title + "_Glass", Vector3(0.025, 1.28, span_z - 0.08), Vector3(7.57, floor_y + 1.50, z_center), m.glass_smoked_office)
	win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if with_server:
		_place_maintenance_prop(wall_root, "switchgear", Vector3(8.16, floor_y + 0.10, z_center + 0.32), Vector3(0.45, 1.65, 0.68), -90.0)
	_build_dark_workstation_prop(Vector3(8.08, floor_y + 0.10, z_center - 0.25), -90.0)


func _build_smoked_window_bay_north(x_center: float, floor_y: float, top_y: float, span_x: float, title: String, executive: bool) -> void:
	var header_y0 := floor_y + 2.16
	var header_h := maxf(0.45, top_y - header_y0)
	m.build_top_black_wall(wall_root, title + "_Sill", Vector3(x_center, floor_y + 0.42, -8.72), Vector3(span_x, 0.84, 0.50), 4, m.wall_composite)
	m.build_top_black_wall(wall_root, title + "_Header", Vector3(x_center, header_y0 + header_h * 0.5, -8.92), Vector3(span_x, header_h, 0.86), 4, m.wall_composite)
	m.box(wall_root, title + "_AlcoveFloor", Vector3(span_x - 0.04, 0.10, 0.95), Vector3(x_center, floor_y + 0.05, -8.96), m.office_interior_wall)
	m.box(wall_root, title + "_CharcoalKick", Vector3(span_x - 0.08, 0.78, 0.06), Vector3(x_center, floor_y + 0.40, -8.46), m.dark_bulkhead)
	m.box(wall_root, title + "_YellowTrim", Vector3(span_x - 0.08, 0.04, 0.08), Vector3(x_center, floor_y + 0.78, -8.45), m.endfield_yellow)
	m.box(wall_root, title + "_SillCap", Vector3(span_x - 0.04, 0.06, 0.14), Vector3(x_center, floor_y + 0.84, -8.48), m.steel_mullion)
	m.box(wall_root, title + "_Mullion", Vector3(0.07, 1.32, 0.10), Vector3(x_center, floor_y + 1.50, -8.48), m.steel_mullion)
	var win := m.box(wall_root, title + "_Glass", Vector3(span_x - 0.08, 1.28, 0.025), Vector3(x_center, floor_y + 1.50, -8.49), m.glass_smoked_office)
	win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_dark_workstation_prop(Vector3(x_center - (0.35 if executive else 0.0), floor_y + 0.10, -8.96), 0.0)
	if executive:
		m.spawn_quaternius(wall_root, "Prop_Computer", Vector3(x_center + 0.55, floor_y + 0.82, -8.98), 180.0, Vector3(0.45, 0.45, 0.45), false, true)


func _build_dark_workstation_prop(base_pos: Vector3, yaw_deg: float) -> void:
	var root := Node3D.new()
	root.position = base_pos
	root.rotation.y = deg_to_rad(yaw_deg)
	wall_root.add_child(root)
	m.box(root, "DeskTop", Vector3(1.10, 0.05, 0.55), Vector3(0.0, 0.72, 0.0), m.steel_beam)
	for lx: float in [-0.48, 0.48]:
		m.box(root, "DeskLeg", Vector3(0.06, 0.70, 0.48), Vector3(lx, 0.35, 0.0), m.dark_bulkhead)
	for mx: float in [-0.22, 0.22]:
		m.box(root, "MonFrame", Vector3(0.36, 0.24, 0.04), Vector3(mx, 0.90, -0.14), m.dark_bulkhead)
		var scr := m.box(root, "MonScreen", Vector3(0.32, 0.20, 0.015), Vector3(mx, 0.90, -0.115), m.monitor_glow)
		scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.box(root, "ChairSeat", Vector3(0.40, 0.08, 0.40), Vector3(0.0, 0.44, 0.28), m.steel_mullion)
	m.box(root, "ChairBack", Vector3(0.38, 0.46, 0.07), Vector3(0.0, 0.70, 0.46), m.steel_mullion)


func _build_walkability_colliders() -> void:
	# Boundary colliders wrapping every outer edge of the suspended L-corridor walkability region
	var cells := {}
	for rect: Rect2i in L.ALL_SECTIONS:
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, z)] = true

	var t := 0.26
	for outward: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var tangent := Vector2i(absi(outward.y), absi(outward.x))
		for cell: Vector2i in cells:
			var neighbor := cell + outward
			if cells.has(neighbor):
				continue
			var prev := cell - tangent
			if cells.has(prev) and not cells.has(prev + outward):
				continue
			var end := cell + tangent
			while cells.has(end) and not cells.has(end + outward):
				end += tangent
			var center_xz := Vector2(cell) + Vector2(outward) * 0.5 + Vector2(end - cell - tangent) * 0.5
			var size_xz := Vector2(end - cell) + Vector2(outward).abs() * t
			_add_box_collider("Bound_%d_%d_%d_%d" % [cell.x, cell.y, outward.x, outward.y],
				Rect2(center_xz - size_xz * 0.5, size_xz), ACTOR_EDGE)


func _build_endfield_signage() -> void:
	var board := Node3D.new()
	board.name = "DirectoryMapBoard"
	board.position = Vector3(-4.65, L.NW_GALLERY_Y + 0.54, -4.55)
	wall_root.add_child(board)
	m.box(board, "BoardFrame", Vector3(2.38, 1.38, 0.06), Vector3.ZERO, m.steel_beam)
	m.quad(board, "BoardFace", Vector2(2.26, 1.26), Vector3(0.0, 0.0, 0.036), m.make_directory_board_material())
	for sx: float in [-0.75, 0.75]:
		m.box(board, "BoardMountLeg", Vector3(0.06, 0.58, 0.06), Vector3(sx, -0.78, 0.0), m.steel_mullion)


func _build_weathering_details() -> void:
	var grime_root := Node3D.new()
	grime_root.name = "AtriumWeatheringDecals"
	floor_root.add_child(grime_root)

	# 1. Oil & hydraulic fluid spills under H06 legs, belly, pit floor (y=0.040) & plinth (y=0.149)
	var oil_spots := [
		[Vector3(-3.0, 0.149, 1.5), Vector2(3.1, 2.5), 18.0],
		[Vector3(-4.9, 0.149, 0.1), Vector2(1.7, 1.4), -26.0],
		[Vector3(-4.8, 0.149, 3.0), Vector2(1.8, 1.4), 34.0],
		[Vector3(-1.2, 0.149, 0.2), Vector2(1.5, 1.3), -12.0],
		[Vector3(-1.1, 0.149, 2.9), Vector2(1.9, 1.5), 42.0],
		[Vector3(-6.2, 0.040, 4.3), Vector2(2.2, 1.7), 12.0],
		[Vector3(0.4, 0.040, -1.6), Vector2(2.1, 1.6), -35.0],
		[Vector3(-0.2, 0.040, 4.2), Vector2(2.0, 1.4), 68.0],
		[Vector3(-9.1, 0.012, 0.3), Vector2(2.0, 1.4), 8.0],
		[Vector3(-9.1, 0.012, 2.8), Vector2(1.9, 1.5), -14.0],
		[Vector3(-9.6, 0.012, -1.8), Vector2(1.5, 1.3), 24.0],
	]
	for item: Array in oil_spots:
		var q := m.quad(grime_root, "BayOilStain", item[1], item[0], m.decal_oil_stain, Vector3(-90.0, item[2], 0.0))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 2. Chalky concrete scuffing & worn-paint breakup across corridor walkways, stair landings, yellow stripes & 1F deck
	var scuffs := [
		[Vector3(9.4, L.CORRIDOR_ENTRY_Y + 0.018, 6.0), Vector2(2.2, 0.85), 6.0],
		[Vector3(7.1, L.CORRIDOR_ENTRY_Y + 0.018, 6.0), Vector2(1.8, 0.75), -14.0],
		[Vector3(5.6, L.CORRIDOR_ENTRY_Y + 0.018, 6.0), Vector2(2.3, 0.90), 28.0],
		[Vector3(5.3, L.CORRIDOR_ENTRY_Y + 0.018, 4.2), Vector2(1.8, 0.80), 85.0],
		[Vector3(5.3, L.NE_LANDING_Y + 0.018, -3.5), Vector2(1.9, 0.85), 94.0],
		[Vector3(5.1, L.NE_LANDING_Y + 0.018, -6.1), Vector2(2.3, 0.90), -32.0],
		[Vector3(2.4, L.NE_LANDING_Y + 0.018, -7.8), Vector2(1.6, 0.75), 4.0],
		[Vector3(3.1, L.NE_LANDING_Y + 0.018, -6.2), Vector2(1.8, 0.75), 8.0],
		[Vector3(-3.0, L.NW_GALLERY_Y + 0.018, -6.2), Vector2(2.4, 0.88), 11.0],
		[Vector3(-5.8, L.NW_GALLERY_Y + 0.018, -6.2), Vector2(2.2, 0.82), -15.0],
		[Vector3(-6.0, L.NW_GALLERY_Y + 0.018, -7.6), Vector2(1.8, 0.78), -18.0],
		[Vector3(6.9, L.CORRIDOR_ENTRY_Y + 0.018, 3.55), Vector2(1.4, 0.75), 90.0],
		[Vector3(6.9, L.NE_LANDING_Y + 0.018, -4.8), Vector2(1.4, 0.75), 90.0],
		[Vector3(-3.0, 0.012, 7.2), Vector2(2.8, 1.1), 16.0],
	]
	for item_s: Array in scuffs:
		var qs := m.quad(grime_root, "CorridorScuff", item_s[1], item_s[0], m.decal_scuff_streak, Vector3(-90.0, item_s[2], 0.0))
		qs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 3. Sharp concrete fracture cracks on high-load landings, plinth corners & 1F deck
	var cracks := [
		[Vector3(-5.2, 0.148, 3.2), Vector2(2.2, 1.8), 22.0],
		[Vector3(-0.7, 0.148, -0.3), Vector2(2.0, 1.6), -48.0],
		[Vector3(6.4, L.CORRIDOR_ENTRY_Y + 0.016, 6.6), Vector2(1.9, 1.5), 14.0],
		[Vector3(6.0, L.NE_LANDING_Y + 0.016, -4.9), Vector2(2.1, 1.6), -64.0],
		[Vector3(-4.6, L.NW_GALLERY_Y + 0.016, -5.6), Vector2(2.3, 1.7), 32.0],
		[Vector3(-6.8, 0.010, 7.0), Vector2(2.6, 2.0), -18.0],
		[Vector3(1.6, 0.010, 6.2), Vector2(2.4, 1.9), 41.0],
	]
	for item_c: Array in cracks:
		var qc := m.quad(grime_root, "FloorCrack", item_c[1], item_c[0], m.decal_crack, Vector3(-90.0, item_c[2], 0.0))
		qc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 4. Prominent vertical water-runoff, soot & rust seepage stains down concrete walls, under sconces, vents & signage
	var wall_drips := [
		# North Corridor Wall (inner solid wall face at z=-8.44, decals placed flush at z=-8.38..-8.41)
		[Vector3(4.95, L.NE_LANDING_Y + 1.05, -8.38), Vector2(2.1, 1.25), 0.0],
		[Vector3(5.20, L.NE_LANDING_Y + 1.78, -8.37), Vector2(1.4, 1.45), 0.0],
		[Vector3(4.20, L.NE_LANDING_Y + 1.85, -8.39), Vector2(1.1, 1.75), 0.0],
		[Vector3(2.45, L.NE_LANDING_Y + 2.02, -8.39), Vector2(1.5, 0.75), 0.0],
		[Vector3(0.10, L.NE_LANDING_Y + 2.55, -8.39), Vector2(1.2, 0.85), 0.0],
		[Vector3(-4.10, L.NW_GALLERY_Y + 2.48, -8.39), Vector2(1.2, 0.82), 0.0],
		[Vector3(-7.40, L.NW_GALLERY_Y + 1.65, -8.38), Vector2(1.5, 1.65), 0.0],
		# NW West Cap Wall (+X inward at x=-8.50)
		[Vector3(-8.44, L.NW_GALLERY_Y + 0.95, -6.50), Vector2(2.0, 1.15), 90.0],
		[Vector3(-8.44, L.NW_GALLERY_Y + 1.95, -5.20), Vector2(1.2, 1.60), 90.0],
		# East Corridor Wall (-X inward: solid x=7.50, sill kick x=7.49)
		[Vector3(7.45, L.CORRIDOR_ENTRY_Y + 1.65, 4.18), Vector2(0.8, 2.2), -90.0],
		[Vector3(7.46, L.CORRIDOR_ENTRY_Y + 2.48, 1.65), Vector2(1.8, 0.85), -90.0],
		[Vector3(7.46, L.NE_LANDING_Y + 2.48, -2.35), Vector2(1.7, 0.85), -90.0],
		[Vector3(7.45, L.NE_LANDING_Y + 1.90, -6.70), Vector2(1.5, 1.30), -90.0],
		# Under-corridor pit bulkhead walls facing central H06 pit
		[Vector3(-5.80, 0.85, -4.41), Vector2(2.4, 1.45), 0.0],
		[Vector3(-1.80, 0.85, -4.46), Vector2(2.2, 1.40), 0.0],
		[Vector3(2.00, 0.85, -4.46), Vector2(2.0, 1.40), 0.0],
		[Vector3(3.41, 0.72, 2.20), Vector2(2.1, 1.25), -90.0],
		[Vector3(3.46, 0.72, 5.80), Vector2(1.9, 1.20), -90.0],
	]
	for item_w: Array in wall_drips:
		var qw := m.quad(grime_root, "WallDripStain", item_w[1], item_w[0], m.decal_wall_drip, Vector3(0.0, item_w[2], 0.0))
		qw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 5. Aged iron-oxide rust blotches around stanchions, floor vents, door thresholds & pit edges
	var rust_spots := [
		[Vector3(-9.35, 0.014, -0.6), Vector2(1.6, 1.5), 24.0],
		[Vector3(-9.35, 0.014, 3.4), Vector2(1.6, 1.5), -19.0],
		[Vector3(-7.8, 0.041, 2.2), Vector2(1.8, 1.2), 90.0],
		[Vector3(-6.1, 0.149, 1.5), Vector2(1.1, 1.8), 14.0],
		[Vector3(0.1, 0.149, 1.6), Vector2(1.0, 1.7), -22.0],
		[Vector3(1.8, 0.041, -0.5), Vector2(1.6, 1.1), -82.0],
		[Vector3(-4.2, 0.014, 7.15), Vector2(1.3, 1.2), 15.0],
		[Vector3(6.6, L.NE_LANDING_Y + 0.014, -7.85), Vector2(1.2, 1.0), 12.0],
	]
	for item_r: Array in rust_spots:
		var qr := m.quad(grime_root, "RustPatch", item_r[1], item_r[0], m.decal_rust_patch, Vector3(-90.0, item_r[2], 0.0))
		qr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 6. Weathered maintenance floor hatches and service cable on the 1F apron
	for hatch_pos: Vector3 in [Vector3(-8.4, 0.008, 6.2), Vector3(1.9, 0.008, 7.6)]:
		m.box(grime_root, "MaintenanceHatchFrame", Vector3(1.25, 0.014, 1.25), hatch_pos, m.steel_beam)
		m.box(grime_root, "MaintenanceHatchPlate", Vector3(1.08, 0.018, 1.08), hatch_pos, m.dark_bulkhead)
		var hr := m.quad(grime_root, "HatchRust", Vector2(1.75, 1.75), hatch_pos + Vector3(0.0, 0.006, 0.0), m.decal_rust_patch, Vector3(-90.0, 28.0, 0.0))
		hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	m.spawn_quaternius(wall_root, "Prop_Cable_1", Vector3(-8.5, 0.01, 4.3), 75.0, Vector3(1.1, 1.0, 1.1), false, true)


func _build_endfield_stencil_panel(title: String, at: Vector3, yaw_deg: float, width: float, height: float, code: String) -> void:
	var panel := Node3D.new()
	panel.name = title
	panel.position = at
	panel.rotation.y = deg_to_rad(yaw_deg)
	wall_root.add_child(panel)

	m.box(panel, "BackingPlate", Vector3(width, height, 0.03), Vector3.ZERO, m.stencil_backing)
	for edge_x: float in [-width * 0.5 + 0.015, width * 0.5 - 0.015]:
		m.box(panel, "EdgeTrim", Vector3(0.03, height, 0.036), Vector3(edge_x, 0.0, 0.002), m.steel_mullion)

	var digits := Label3D.new()
	digits.text = code
	digits.font_size = 96
	digits.pixel_size = 0.0048 * (height / 0.90)
	digits.outline_size = 0
	digits.modulate = Color("181b1e")
	digits.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	digits.position = Vector3(-width * 0.27, 0.04, 0.022)
	panel.add_child(digits)

	for i in 3:
		var line_w := width * (0.28 if i < 2 else 0.18)
		m.box(panel, "SpecLine_%d" % i, Vector3(line_w, height * 0.042, 0.010),
			Vector3(width * 0.03 - (0.04 if i == 2 else 0.0), height * (0.14 - float(i) * 0.12), 0.020), m.steel_rail)

	for s in 3:
		var slash := m.box(panel, "HazardSlash_%d" % s, Vector3(width * 0.052, height * 0.56, 0.012),
			Vector3(width * 0.24 + float(s) * width * 0.088, 0.02, 0.021), m.dark_bulkhead)
		slash.rotation_degrees.z = -24.0

	m.box(panel, "YellowTag", Vector3(width * 0.24, height * 0.065, 0.012),
		Vector3(-width * 0.29, -height * 0.36, 0.021), m.endfield_yellow)


func _build_room_plaque(title: String, at: Vector3, yaw_deg: float, room_code: String, accent_mat: Material) -> void:
	var plaque := Node3D.new()
	plaque.name = title
	plaque.position = at
	plaque.rotation.y = deg_to_rad(yaw_deg)
	wall_root.add_child(plaque)

	m.box(plaque, "PlaqueBody", Vector3(0.42, 0.22, 0.04), Vector3.ZERO, m.dark_bulkhead)
	m.box(plaque, "PlaqueAccent", Vector3(0.42, 0.045, 0.044), Vector3(0.0, 0.085, 0.002), accent_mat)
	var lbl := Label3D.new()
	lbl.text = room_code
	lbl.font_size = 32
	lbl.pixel_size = 0.0040
	lbl.outline_size = 0
	lbl.modulate = Color("d8dcd9")
	lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	lbl.position = Vector3(0.0, -0.02, 0.026)
	plaque.add_child(lbl)


func _place_maintenance_prop(parent: Node3D, kind: String, at: Vector3, size: Vector3, yaw_deg: float) -> void:
	var n := M.prop_visual(kind, size)
	n.position = at
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)


func _omni(parent: Node3D, title: String, at: Vector3, col: Color, energy: float,
		radius: float, atten: float, shadows: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = title
	l.position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = atten
	l.shadow_enabled = shadows
	l.light_cull_mask = 15
	parent.add_child(l)
	return l


func _spot(parent: Node3D, title: String, at: Vector3, look_at_pt: Vector3,
		col: Color, energy: float, radius: float, angle: float) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.name = title
	s.position = at
	s.light_color = col
	s.light_energy = energy
	s.spot_range = radius
	s.spot_angle = angle
	s.spot_attenuation = 1.05
	s.shadow_enabled = true
	s.light_cull_mask = 15
	s.transform = Transform3D(Basis.looking_at((look_at_pt - at).normalized(), Vector3.UP), at)
	parent.add_child(s)
	return s


func _add_box_collider(title: String, rect: Rect2, layer_mask: int) -> void:
	var body := StaticBody2D.new()
	body.name = title
	body.position = rect.get_center() * world.CELL_PIXELS
	body.collision_layer = layer_mask
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = rect.size * world.CELL_PIXELS
	shape.shape = box_shape
	body.add_child(shape)
	world.collision_root.add_child(body)
