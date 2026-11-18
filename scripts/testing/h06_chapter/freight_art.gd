extends RefCounted
## Suspended open-work metal grating catwalks, broken side guardrails, bottomless black chasm depths,
## collapsible shaky floor plates, giant submerged pipes, and flickering industrial lights for Chapter 1-3.

const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const WAREHOUSE := preload("res://scripts/testing/h06_chapter/warehouse_art.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const GRATE_SHADER := preload("res://scripts/testing/h06_chapter/freight_grate_deck.gdshader")
const ABYSS_SHADER := preload("res://scripts/testing/h06_chapter/freight_abyss_fade.gdshader")
const HAZARD_SHADER := preload("res://scripts/testing/h06_chapter/freight_hazard_zone.gdshader")
const PAINTED_STEEL := preload("res://scripts/testing/h06_chapter/freight_painted_steel.gdshader")
const WARNING_FONT := preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const KENNEY_DIR := "res://art/Dream/CC0/AtriumLoop11/kenney/"
const QUAT_DIR := "res://art/Dream/CC0/AtriumLoop11/quaternius/"
const SCIFI_DIR := "res://art/Dream/CC0/QuaterniusSciFiStandard/"
const CONTAINER_MODELS := {
	"container": KENNEY_DIR + "container.glb",
	"container_wide": KENNEY_DIR + "container-wide.glb",
	"container_tall": KENNEY_DIR + "container-tall.glb",
}
const CONTAINER_TINTS := {
	"orange": Color("ba542c"),
	"slate": Color("546e7d"),
	"olive": Color("586e49"),
	"ochre": Color("bd8b30"),
	"navy": Color("466178"),
}

const COLLAPSE_DELAY := 1.15
const BAY_HALF_W := 0.82
static var _container_mat_cache: Dictionary = {}

## North shaft backdrop ribs (confined strictly to North wall backdrops behind entrances/windows/ramp).
const BUTTRESS_BAYS: Array[Array] = [
	[Vector3(15.0, 0.0, 55.0), Vector2.UP],
	[Vector3(19.8, 0.0, 55.0), Vector2.UP],
	[Vector3(25.4, 0.0, 86.0), Vector2.UP],
	[Vector3(30.8, 0.0, 86.0), Vector2.UP],
	[Vector3(53.0, 0.0, 86.0), Vector2.UP],
	[Vector3(58.6, 0.0, 86.0), Vector2.UP],
	[Vector3(72.5, 0.0, 55.0), Vector2.UP],
	[Vector3(77.2, 0.0, 55.0), Vector2.UP],
	[Vector3(50.0, 0.0, 26.5), Vector2.UP],
	[Vector3(66.2, 0.0, 26.5), Vector2.UP],
]

## Seven unstable suspended metal grate plates placed along active green sprint lanes (clear of checkpoints & drops).
const UNSTABLE_PLATES: Array[Rect2] = [
	Rect2(-6.2, 27.2, 2.8, 3.2),
	Rect2(-6.2, 46.0, 3.2, 3.6),
	Rect2(2.8, 58.2, 4.2, 3.8),
	Rect2(10.0, 68.5, 4.4, 4.2),
	Rect2(22.0, 86.8, 4.2, 3.8),
	Rect2(53.5, 86.8, 4.2, 3.8),
	Rect2(62.2, 51.6, 4.4, 3.4),
]

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func materials() -> Dictionary:
	if not _mat_cache.is_empty():
		return _mat_cache
	var wh := WAREHOUSE.materials()
	var met_nor := load(WAREHOUSE.METAL_NOR) as Texture2D
	var met_rough := load(WAREHOUSE.METAL_ROUGH) as Texture2D
	var iron_diff := load(WAREHOUSE.IRON_DIFF) as Texture2D
	var iron_nor := load(WAREHOUSE.IRON_NOR) as Texture2D
	var iron_rough := load(WAREHOUSE.IRON_ROUGH) as Texture2D

	var buttress_red := StandardMaterial3D.new()
	buttress_red.albedo_texture = _buttress_red_tex()
	buttress_red.albedo_color = Color.WHITE
	buttress_red.metallic = 0.28
	buttress_red.roughness = 0.62
	buttress_red.normal_texture = met_nor
	buttress_red.normal_scale = 0.38
	buttress_red.roughness_texture = met_rough
	buttress_red.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var pipe_rusted := StandardMaterial3D.new()
	pipe_rusted.albedo_texture = _rusted_pipe_tex()
	pipe_rusted.albedo_color = Color("9a928a")
	pipe_rusted.metallic = 0.48
	pipe_rusted.roughness = 0.64
	pipe_rusted.normal_texture = iron_nor
	pipe_rusted.normal_scale = 0.42
	pipe_rusted.roughness_texture = iron_rough
	pipe_rusted.uv1_triplanar = true
	pipe_rusted.uv1_scale = Vector3(0.42, 0.42, 0.42)
	pipe_rusted.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var trench_steel := StandardMaterial3D.new()
	trench_steel.albedo_texture = iron_diff
	trench_steel.albedo_color = Color("262d33")
	trench_steel.metallic = 0.58
	trench_steel.roughness = 0.48
	trench_steel.normal_texture = iron_nor
	trench_steel.normal_scale = 0.40
	trench_steel.roughness_texture = iron_rough
	trench_steel.uv1_triplanar = true
	trench_steel.uv1_scale = Vector3(0.60, 0.60, 0.60)

	var trench_rib_dark := StandardMaterial3D.new()
	trench_rib_dark.albedo_color = Color("131619")
	trench_rib_dark.metallic = 0.36
	trench_rib_dark.roughness = 0.72
	trench_rib_dark.normal_texture = met_nor
	trench_rib_dark.normal_scale = 0.30
	trench_rib_dark.uv1_triplanar = true
	trench_rib_dark.uv1_scale = Vector3(0.50, 0.50, 0.50)

	var track_trim := StandardMaterial3D.new()
	track_trim.albedo_texture = iron_diff
	track_trim.albedo_color = Color("465056")
	track_trim.metallic = 0.50
	track_trim.roughness = 0.52
	track_trim.normal_texture = met_nor
	track_trim.normal_scale = 0.34
	track_trim.roughness_texture = met_rough
	track_trim.uv1_triplanar = true
	track_trim.uv1_scale = Vector3(0.75, 0.75, 0.75)

	var belt_tread := StandardMaterial3D.new()
	belt_tread.albedo_texture = _belt_tread_tex()
	belt_tread.albedo_color = Color.WHITE
	belt_tread.metallic = 0.14
	belt_tread.roughness = 0.74
	belt_tread.normal_texture = met_nor
	belt_tread.normal_scale = 0.32
	belt_tread.uv1_triplanar = true
	belt_tread.uv1_scale = Vector3(1.1, 1.1, 1.1)
	belt_tread.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var cage_panel := StandardMaterial3D.new()
	cage_panel.albedo_texture = _cage_slat_tex()
	cage_panel.albedo_color = Color("7b8389")
	cage_panel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cage_panel.alpha_scissor_threshold = 0.45
	cage_panel.cull_mode = BaseMaterial3D.CULL_DISABLED
	cage_panel.metallic = 0.52
	cage_panel.roughness = 0.52
	cage_panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var rail_metal := StandardMaterial3D.new()
	rail_metal.albedo_texture = iron_diff
	rail_metal.albedo_color = Color("8c9690")
	rail_metal.metallic = 0.52
	rail_metal.roughness = 0.44
	rail_metal.normal_texture = met_nor
	rail_metal.normal_scale = 0.30
	rail_metal.uv1_triplanar = true
	rail_metal.uv1_scale = Vector3(0.8, 0.8, 0.8)

	var beacon_amber := StandardMaterial3D.new()
	beacon_amber.albedo_color = Color("cf7426")
	beacon_amber.emission_enabled = true
	beacon_amber.emission = Color("f28829")
	beacon_amber.emission_energy_multiplier = 1.65

	var beacon_alert := StandardMaterial3D.new()
	beacon_alert.albedo_color = Color("c73524")
	beacon_alert.emission_enabled = true
	beacon_alert.emission = Color("ff3b24")
	beacon_alert.emission_energy_multiplier = 2.6

	var abyss_black := StandardMaterial3D.new()
	abyss_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	abyss_black.albedo_color = Color(0.0, 0.0, 0.0, 1.0)

	var abyss_steel := ShaderMaterial.new()
	abyss_steel.shader = ABYSS_SHADER
	abyss_steel.set_shader_parameter("albedo_tint", Color("22282e"))
	abyss_steel.set_shader_parameter("metallic_amt", 0.52)
	abyss_steel.set_shader_parameter("roughness_amt", 0.58)
	abyss_steel.set_shader_parameter("fade_top", -0.6)
	abyss_steel.set_shader_parameter("fade_bottom", -8.8)

	var abyss_pipe := ShaderMaterial.new()
	abyss_pipe.shader = ABYSS_SHADER
	abyss_pipe.set_shader_parameter("albedo_tint", Color("3a4246"))
	abyss_pipe.set_shader_parameter("metallic_amt", 0.56)
	abyss_pipe.set_shader_parameter("roughness_amt", 0.52)
	abyss_pipe.set_shader_parameter("fade_top", -0.8)
	abyss_pipe.set_shader_parameter("fade_bottom", -9.2)

	var abyss_pipe_rust := ShaderMaterial.new()
	abyss_pipe_rust.shader = ABYSS_SHADER
	abyss_pipe_rust.set_shader_parameter("albedo_tint", Color("4e3326"))
	abyss_pipe_rust.set_shader_parameter("metallic_amt", 0.42)
	abyss_pipe_rust.set_shader_parameter("roughness_amt", 0.66)
	abyss_pipe_rust.set_shader_parameter("fade_top", -0.8)
	abyss_pipe_rust.set_shader_parameter("fade_bottom", -9.2)

	_mat_cache = {
		"buttress_red": buttress_red,
		"pipe_rusted": pipe_rusted,
		"trench_steel": trench_steel,
		"trench_rib_dark": trench_rib_dark,
		"track_trim": track_trim,
		"belt_tread": belt_tread,
		"cage_panel": cage_panel,
		"rail_metal": rail_metal,
		"safety_yellow": wh.safety_yellow,
		"hazard": wh.hazard,
		"steel_mid": wh.steel_mid,
		"steel_bright": wh.steel_bright,
		"corrugated": wh.corrugated,
		"beacon_amber": beacon_amber,
		"beacon_alert": beacon_alert,
		"abyss_black": abyss_black,
		"abyss_steel": abyss_steel,
		"abyss_pipe": abyss_pipe,
		"abyss_pipe_rust": abyss_pipe_rust,
	}
	return _mat_cache


static func make_grate_material(local_xz := false, panel_span := Vector2(2.8, 2.4), unstable_wear := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GRATE_SHADER
	mat.set_shader_parameter("metal_normal", load(WAREHOUSE.METAL_NOR))
	mat.set_shader_parameter("metal_rough", load(WAREHOUSE.METAL_ROUGH))
	mat.set_shader_parameter("steel_base", Color("293036"))
	mat.set_shader_parameter("frame_base", Color("33372d"))
	mat.set_shader_parameter("rust_tint", Color("4d2d1b"))
	mat.set_shader_parameter("panel_span", panel_span)
	mat.set_shader_parameter("bar_pitch", 0.165)
	mat.set_shader_parameter("bar_half_width", 0.024)
	mat.set_shader_parameter("unstable_wear", unstable_wear)
	mat.set_shader_parameter("use_local_xz", local_xz)
	mat.set_shader_parameter("passage_end_fade", Vector4(100000.0, 100001.0, 100000.0, 100001.0))
	mat.set_shader_parameter("passage_z_fade", Vector4(100000.0, 100001.0, 100000.0, 100001.0))
	mat.set_shader_parameter("fade_floor", 1.0)
	return mat


## Subtracts a list of axis-aligned holes from an outer floor rectangle cleanly.
static func _rect_minus_holes(outer: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [outer]
	for hole: Rect2 in holes:
		var next_pieces: Array[Rect2] = []
		for r: Rect2 in pieces:
			if not r.intersects(hole):
				next_pieces.append(r)
				continue
			var cut := r.intersection(hole)
			if cut.size.x < 0.005 or cut.size.y < 0.005:
				next_pieces.append(r)
				continue
			if cut.position.x > r.position.x + 0.005:
				next_pieces.append(Rect2(r.position.x, r.position.y, cut.position.x - r.position.x, r.size.y))
			if cut.end.x < r.end.x - 0.005:
				next_pieces.append(Rect2(cut.end.x, r.position.y, r.end.x - cut.end.x, r.size.y))
			if cut.position.y > r.position.y + 0.005:
				next_pieces.append(Rect2(cut.position.x, r.position.y, cut.size.x, cut.position.y - r.position.y))
			if cut.end.y < r.end.y - 0.005:
				next_pieces.append(Rect2(cut.position.x, cut.end.y, cut.size.x, r.end.y - cut.end.y))
		pieces = next_pieces
	return pieces


static func freight_hole_rects() -> Array[Rect2]:
	var holes: Array[Rect2] = []
	holes.append_array(UNSTABLE_PLATES)
	for spec: Dictionary in PLAN.FREIGHT_FRACTURES:
		holes.append(spec.get("cutout_rect", spec.rect))
	return holes


## Builds one room's open-work perforated iron grating platform (or individual modular collapse bay).
static func build_grate_deck_mesh(floor_root: Node3D, node_name: String, rect: Rect2,
		grate_mat: Material, top_y := 0.0, add_corner_stubs := false) -> MeshInstance3D:
	var mats := materials()
	var m_top := WAREHOUSE.MeshBuilder.new()
	var holes := freight_hole_rects()
	var pieces := _rect_minus_holes(rect, holes) if is_zero_approx(top_y) else [rect]
	for r: Rect2 in pieces:
		var p0 := Vector3(r.position.x, top_y, r.position.y)
		var p1 := Vector3(r.end.x, top_y, r.position.y)
		var p2 := Vector3(r.end.x, top_y, r.end.y)
		var p3 := Vector3(r.position.x, top_y, r.end.y)
		m_top.quad(grate_mat, p0, p1, p2, p3, Vector3.UP)

	var deck := MeshInstance3D.new()
	deck.name = node_name
	deck.mesh = m_top.bake()
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	floor_root.add_child(deck)

	# Attach 3D welded steel C-channel perimeter fascia & under-deck joists right beneath the open grating
	var m_frame := WAREHOUSE.MeshBuilder.new()
	var cx := rect.get_center().x
	var cz := rect.get_center().y
	for sz: float in [-1.0, 1.0]:
		for seg: Rect2 in _rect_minus_holes(Rect2(rect.position.x, cz + sz * (rect.size.y * 0.5 - 0.05) - 0.05, rect.size.x, 0.10), holes):
			m_frame.box(mats.trench_steel, Vector3(seg.get_center().x, top_y - 0.11, seg.get_center().y), Vector3(seg.size.x, 0.22, seg.size.y))
	for sx: float in [-1.0, 1.0]:
		for seg: Rect2 in _rect_minus_holes(Rect2(cx + sx * (rect.size.x * 0.5 - 0.05) - 0.05, rect.position.y, 0.10, rect.size.y), holes):
			m_frame.box(mats.trench_steel, Vector3(seg.get_center().x, top_y - 0.11, seg.get_center().y), Vector3(seg.size.x, 0.22, seg.size.y))
	var joist_x := maxi(1, floori(rect.size.x / 3.4))
	for i in range(1, joist_x):
		var jx := lerpf(rect.position.x, rect.end.x, float(i) / float(joist_x))
		for seg: Rect2 in _rect_minus_holes(Rect2(jx - 0.06, rect.position.y, 0.12, rect.size.y), holes):
			m_frame.box(mats.trench_rib_dark, Vector3(seg.get_center().x, top_y - 0.12, seg.get_center().y), Vector3(seg.size.x, 0.18, seg.size.y))
	var joist_z := maxi(1, floori(rect.size.y / 3.4))
	for j in range(1, joist_z):
		var jz := lerpf(rect.position.y, rect.end.y, float(j) / float(joist_z))
		for seg: Rect2 in _rect_minus_holes(Rect2(rect.position.x, jz - 0.06, rect.size.x, 0.12), holes):
			m_frame.box(mats.trench_rib_dark, Vector3(seg.get_center().x, top_y - 0.14, seg.get_center().y), Vector3(seg.size.x, 0.16, seg.size.y))
	if add_corner_stubs:
		for sx: float in [0.12, 0.88]:
			for sz: float in [0.14, 0.86]:
				var sp := Vector2(lerpf(rect.position.x, rect.end.x, sx), lerpf(rect.position.y, rect.end.y, sz))
				if not holes.any(func(h: Rect2): return h.grow(0.35).has_point(sp)):
					m_frame.bar(mats.abyss_steel, Vector3(sp.x, top_y - 0.18, sp.y), Vector3(sp.x, top_y - 3.6, sp.y), 0.26)
	for hole: Rect2 in UNSTABLE_PLATES:
		if not rect.intersects(hole):
			continue
		var hx := hole.get_center().x
		var hz := hole.get_center().y
		for sz: float in [-1.0, 1.0]:
			m_frame.box(mats.safety_yellow, Vector3(hx, top_y - 0.06, hz + sz * (hole.size.y * 0.5 + 0.04)), Vector3(hole.size.x + 0.16, 0.12, 0.08))
		for sx: float in [-1.0, 1.0]:
			m_frame.box(mats.safety_yellow, Vector3(hx + sx * (hole.size.x * 0.5 + 0.04), top_y - 0.06, hz), Vector3(0.08, 0.12, hole.size.y + 0.16))

	var frame_node := MeshInstance3D.new()
	frame_node.name = "SubFrame"
	frame_node.mesh = m_frame.bake()
	frame_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	deck.add_child(frame_node)
	return deck


## Builds interactive shaky metal grate plates that rattle when stepped on and collapse with the player if delayed.
static func build_unstable_plates(floor_root: Node3D) -> Array[Dictionary]:
	var mats := materials()
	var plates: Array[Dictionary] = []
	for i in UNSTABLE_PLATES.size():
		var r: Rect2 = UNSTABLE_PLATES[i]
		var c := r.get_center()
		var root := Node3D.new()
		root.name = "UnstablePlate_%02d" % (i + 1)
		root.position = Vector3(c.x, 0.0, c.y)
		floor_root.add_child(root)

		var hx := r.size.x * 0.5
		var hz := r.size.y * 0.5
		var m_plate := WAREHOUSE.MeshBuilder.new()
		var grate_mat := make_grate_material(true, r.size, 0.72)
		m_plate.quad(grate_mat,
			Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz),
			Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz), Vector3.UP)
		for sz: float in [-1.0, 1.0]:
			m_plate.box(mats.trench_steel, Vector3(0.0, -0.09, sz * (hz - 0.06)), Vector3(r.size.x, 0.18, 0.12))
			m_plate.box(mats.safety_yellow, Vector3(0.0, 0.008, sz * (hz - 0.04)), Vector3(r.size.x * 0.88, 0.014, 0.06))
		for sx: float in [-1.0, 1.0]:
			m_plate.box(mats.trench_steel, Vector3(sx * (hx - 0.06), -0.09, 0.0), Vector3(0.12, 0.18, r.size.y))

		var plate_mesh := MeshInstance3D.new()
		plate_mesh.name = "PlateMesh"
		plate_mesh.mesh = m_plate.bake()
		plate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(plate_mesh)

		# Edge alert LED strips on front/back edges (shift to bright flashing crimson when triggered)
		var lamp_mat := (mats.beacon_amber as StandardMaterial3D).duplicate() as StandardMaterial3D
		var lamp_bars: Array[MeshInstance3D] = []
		for sz: float in [-1.0, 1.0]:
			var bar := KIT.M.box(root, "PlateAlert", Vector3(r.size.x * 0.42, 0.025, 0.05), Vector3(0.0, 0.015, sz * (hz - 0.08)), lamp_mat)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp_bars.append(bar)

		plates.append({
			"id": i + 1,
			"rect": r,
			"node": root,
			"lamp_mat": lamp_mat,
			"state": "idle",
			"timer": 0.0,
			"fall_y": 0.0,
			"fall_vel": 0.0,
		})
	return plates


## Returns true if the exterior wall edge belongs on a North cavern bulkhead rather than sheer abyss catwalk guardrail.
static func is_north_bulkhead_edge(edge: Array) -> bool:
	var key: String = edge[0]
	var n: Vector2 = edge[3]
	if n != Vector2.UP:
		return false
	return key in ["west_bank", "loading", "transfer_floor", "return_dock", "dispatch"]


static func _wall_xform(wall_pos: Vector3, outward_n: Vector2) -> Transform3D:
	var inward := (-outward_n).normalized()
	var tangent := Vector3(inward.y, 0.0, -inward.x)
	var b := Basis(tangent, Vector3.UP, Vector3(inward.x, 0.0, inward.y))
	return Transform3D(b, wall_pos)


static func _emit_local_box(m: WAREHOUSE.MeshBuilder, mat: Material, xf: Transform3D,
		center: Vector3, size: Vector3, unit_uv := false) -> void:
	var h := size * 0.5
	var p := func(lx: float, ly: float, lz: float) -> Vector3:
		return xf * (center + Vector3(lx, ly, lz))
	var n := func(lx: float, ly: float, lz: float) -> Vector3:
		return (xf.basis * Vector3(lx, ly, lz)).normalized()
	var p000: Vector3 = p.call(-h.x, -h.y, -h.z)
	var p100: Vector3 = p.call(h.x, -h.y, -h.z)
	var p110: Vector3 = p.call(h.x, h.y, -h.z)
	var p010: Vector3 = p.call(-h.x, h.y, -h.z)
	var p001: Vector3 = p.call(-h.x, -h.y, h.z)
	var p101: Vector3 = p.call(h.x, -h.y, h.z)
	var p111: Vector3 = p.call(h.x, h.y, h.z)
	var p011: Vector3 = p.call(-h.x, h.y, h.z)
	var u00 := Vector2(0.0, 0.0) if unit_uv else Vector2.INF
	var u10 := Vector2(1.0, 0.0) if unit_uv else Vector2.INF
	var u11 := Vector2(1.0, 1.0) if unit_uv else Vector2.INF
	var u01 := Vector2(0.0, 1.0) if unit_uv else Vector2.INF
	m.quad(mat, p010, p110, p111, p011, n.call(0, 1, 0), u00, u10, u11, u01)
	m.quad(mat, p001, p101, p100, p000, n.call(0, -1, 0), u00, u10, u11, u01)
	m.quad(mat, p100, p101, p111, p110, n.call(1, 0, 0), u01, u11, u10, u00)
	m.quad(mat, p001, p000, p010, p011, n.call(-1, 0, 0), u01, u11, u10, u00)
	m.quad(mat, p001, p011, p111, p101, n.call(0, 0, 1), u01, u00, u10, u11)
	m.quad(mat, p100, p110, p010, p000, n.call(0, 0, -1), u01, u00, u10, u11)


static func split_wall_for_buttresses(a: Vector2, b: Vector2, outward: Vector2) -> Array:
	var vertical := absf(outward.x) > 0.5
	var wall_coord := a.x if vertical else a.y
	var along_a := a.y if vertical else a.x
	var along_b := b.y if vertical else b.x
	var lo_span := minf(along_a, along_b)
	var hi_span := maxf(along_a, along_b)
	var intervals: Array[Vector2] = [Vector2(lo_span, hi_span)]
	for bay: Array in BUTTRESS_BAYS:
		var bn: Vector2 = bay[1]
		if outward.dot(bn) < 0.99:
			continue
		var bp: Vector3 = bay[0]
		var b_wall := bp.x if vertical else bp.z
		if absf(b_wall - wall_coord) > 0.05:
			continue
		var mid := bp.z if vertical else bp.x
		var cut_lo := mid - BAY_HALF_W
		var cut_hi := mid + BAY_HALF_W
		var next_ivs: Array[Vector2] = []
		for iv: Vector2 in intervals:
			if cut_hi <= iv.x or cut_lo >= iv.y:
				next_ivs.append(iv)
				continue
			if cut_lo > iv.x + 0.04:
				next_ivs.append(Vector2(iv.x, cut_lo))
			if cut_hi < iv.y - 0.04:
				next_ivs.append(Vector2(cut_hi, iv.y))
		intervals = next_ivs
	var result: Array = []
	for iv: Vector2 in intervals:
		var p0 := Vector2(wall_coord, iv.x) if vertical else Vector2(iv.x, wall_coord)
		var p1 := Vector2(wall_coord, iv.y) if vertical else Vector2(iv.y, wall_coord)
		result.append([p0, p1])
	return result


static func _emit_local_sloped_rib(m: WAREHOUSE.MeshBuilder, mats: Dictionary, top_black: Material,
		xf: Transform3D) -> void:
	_emit_local_box(m, mats.trench_rib_dark, xf, Vector3(0.0, 2.15, -1.28), Vector3(1.84, 4.30, 0.18))
	for side: float in [-1.0, 1.0]:
		_emit_local_box(m, mats.trench_steel, xf, Vector3(side * 0.80, 2.15, -0.58), Vector3(0.18, 4.30, 1.24))
		_emit_local_box(m, top_black, xf, Vector3(side * 0.80, 4.31, -0.58), Vector3(0.20, 0.10, 1.28))
	_emit_local_box(m, top_black, xf, Vector3(0.0, 4.31, -0.56), Vector3(1.86, 0.10, 1.56))
	_emit_local_box(m, mats.trench_steel, xf, Vector3(0.0, 0.42, 0.14), Vector3(1.24, 0.84, 0.56))
	_emit_local_box(m, mats.safety_yellow, xf, Vector3(0.0, 0.08, 0.43), Vector3(1.18, 0.14, 0.04))

	var slope_angle := -atan2(0.92, 3.95)
	var mid := Vector3(0.0, 2.28, -0.12)
	var shaft_len := Vector2(0.92, 3.95).length()
	var slope_xf := xf * Transform3D(Basis(Vector3.RIGHT, slope_angle), mid)
	_emit_local_box(m, mats.buttress_red, slope_xf, Vector3.ZERO, Vector3(0.80, shaft_len, 0.72), true)
	for side: float in [-1.0, 1.0]:
		_emit_local_box(m, mats.trench_steel, slope_xf, Vector3(side * 0.44, 0.0, 0.02), Vector3(0.10, shaft_len + 0.04, 0.78))
		_emit_local_box(m, mats.track_trim, slope_xf, Vector3(side * 0.30, 0.0, 0.37), Vector3(0.07, shaft_len - 0.18, 0.05))
	_emit_local_box(m, mats.trench_steel, slope_xf, Vector3(0.0, shaft_len * 0.34, 0.32), Vector3(0.88, 0.16, 0.16))
	_emit_local_box(m, mats.trench_steel, xf, Vector3(0.0, 4.08, 0.16), Vector3(1.62, 0.34, 0.52))
	_emit_local_box(m, top_black, xf, Vector3(0.0, 4.30, 0.16), Vector3(1.66, 0.10, 0.56))
	_emit_local_box(m, mats.beacon_amber, xf, Vector3(0.0, 3.92, 0.40), Vector3(0.56, 0.06, 0.05))


static func _add_horizontal_pipe_run(m: WAREHOUSE.MeshBuilder, mats: Dictionary, a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	m.bar(mats.pipe_rusted, a, b, 0.34)
	m.bar(mats.trench_steel, a + Vector3(0.0, 0.36, 0.0), b + Vector3(0.0, 0.36, 0.0), 0.12)
	var span := a.distance_to(b)
	var count := maxi(2, floori(span / 4.2))
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var p := a.lerp(b, t)
		m.bar(mats.trench_steel, p - dir * 0.08, p + dir * 0.08, 0.42)


## Builds modular 4.0-5.5m chase deck bays along the 1-3 U-turn so behind-boss regions collapse seamlessly.
static func build_freight_deck_bays(floor_root: Node3D, grate_mat: Material) -> Array[Dictionary]:
	var mats := materials()
	var areas := PLAN.visit_areas(PLAN.Visit.FREIGHT, true)
	var edges := PLAN.exterior_edges(areas)
	var pit_curbs: Array[Array] = [
		["west_bank", Vector2(-12.5, 20.5), Vector2(-1.3, 20.5), Vector2.DOWN],
		["west_bank", Vector2(4.6, 20.5), Vector2(11.5, 20.5), Vector2.DOWN],
		["east_bank", Vector2(-12.5, 22.3), Vector2(-1.3, 22.3), Vector2.UP],
		["east_bank", Vector2(4.6, 22.3), Vector2(11.5, 22.3), Vector2.UP],
	]

	# Room specs: [key, rect, axis ("x"|"z"), slices, off_start, off_end, reverse, retain_at_end]
	var specs: Array[Array] = [
		["rear_dock", PLAN.REAR_DOCK, "z", 2, 1.5, 4.5, false, false],
		["west_bank", areas["west_bank"], "z", 2, 6.5, 9.8, false, false],
		["east_bank", areas["east_bank"], "z", 2, 14.5, 20.5, false, false],
		["sorting", areas["sorting"], "z", 5, 30.0, 52.5, false, false],
		["loading", areas["loading"], "x", 6, 53.0, 64.5, false, false],
		["outbound", areas["outbound"], "z", 4, 66.0, 81.5, false, false],
		["transfer_floor", areas["transfer_floor"], "x", 14, 88.0, 147.0, false, false],
		["inbound", areas["inbound"], "z", 4, 152.0, 170.5, true, false],
		["return_dock", areas["return_dock"], "x", 5, 175.0, 188.0, true, false],
		["return_bay", areas["return_bay"], "z", 4, 191.5, 205.5, true, false],
		["dispatch", areas["dispatch"], "x", 1, 212.0, 215.0, true, true],
		["fire_door_apron", areas["fire_door_apron"], "x", 1, 214.0, 215.0, true, true],
	]

	var bays: Array[Dictionary] = []
	for spec: Array in specs:
		var r_key: String = spec[0]
		var r: Rect2 = spec[1]
		var axis: String = spec[2]
		var count: int = spec[3]
		var off0 := float(spec[4])
		var off1 := float(spec[5])
		var rev: bool = spec[6]
		var retain: bool = spec[7]
		for i in count:
			var f0 := float(i) / float(count)
			var f1 := float(i + 1) / float(count)
			if rev:
				var tf0 := 1.0 - f1
				var tf1 := 1.0 - f0
				f0 = tf0
				f1 = tf1
			var bay_rect: Rect2
			if axis == "z":
				var y0 := lerpf(r.position.y, r.end.y, f0)
				var y1 := lerpf(r.position.y, r.end.y, f1)
				bay_rect = Rect2(r.position.x, y0, r.size.x, y1 - y0)
			else:
				var x0 := lerpf(r.position.x, r.end.x, f0)
				var x1 := lerpf(r.position.x, r.end.x, f1)
				bay_rect = Rect2(x0, r.position.y, x1 - x0, r.size.y)

			var bay_node := Node3D.new()
			bay_node.name = "FreightBay_%s_%02d" % [r_key, i + 1]
			floor_root.add_child(bay_node)
			var c := bay_rect.get_center()
			# Pivot bay geometry at local origin = bay center so collapsing tilts naturally around bay center
			var local_pivot := Node3D.new()
			local_pivot.name = "BayPivot"
			local_pivot.position = Vector3(c.x, 0.0, c.y)
			bay_node.add_child(local_pivot)

			var shifted := Rect2(bay_rect.position - c, bay_rect.size)
			var deck := _build_grate_deck_local(local_pivot, r_key + ("_%02d" % (i + 1) if count > 1 else ""),
				bay_rect, c, grate_mat, 0.0, not retain)
			_build_bay_guardrails(local_pivot, bay_rect, c, r_key, edges, pit_curbs, mats)

			var t_prog := (float(i) + 1.0) / float(maxi(1, count))
			bays.append({
				"id": "%s_%02d" % [r_key, i + 1],
				"room": r_key,
				"rect": bay_rect,
				"center": c,
				"offset": lerpf(off0, off1, t_prog),
				"retain_at_end": retain,
				"node": bay_node,
				"pivot": local_pivot,
				"deck": deck,
				"attachments": [],
				"bodies_disabled": false,
				"state": "intact",
				"timer": 0.0,
				"fall_y": 0.0,
				"fall_vel": 0.0,
				"tilt_vel": Vector3.ZERO,
			})
	return bays


static func _build_grate_deck_local(pivot: Node3D, node_name: String, world_rect: Rect2, world_center: Vector2,
		grate_mat: Material, top_y: float, add_corner_stubs: bool) -> MeshInstance3D:
	var mats := materials()
	var m_top := WAREHOUSE.MeshBuilder.new()
	var holes := freight_hole_rects()
	var pieces := _rect_minus_holes(world_rect, holes)
	for r: Rect2 in pieces:
		var lr := Rect2(r.position - world_center, r.size)
		var p0 := Vector3(lr.position.x, top_y, lr.position.y)
		var p1 := Vector3(lr.end.x, top_y, lr.position.y)
		var p2 := Vector3(lr.end.x, top_y, lr.end.y)
		var p3 := Vector3(lr.position.x, top_y, lr.end.y)
		m_top.quad(grate_mat, p0, p1, p2, p3, Vector3.UP)

	var deck := MeshInstance3D.new()
	deck.name = node_name
	deck.mesh = m_top.bake()
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(deck)

	var m_frame := WAREHOUSE.MeshBuilder.new()
	var wcx := world_rect.get_center().x
	var wcz := world_rect.get_center().y
	for sz: float in [-1.0, 1.0]:
		for seg: Rect2 in _rect_minus_holes(Rect2(world_rect.position.x, wcz + sz * (world_rect.size.y * 0.5 - 0.05) - 0.05, world_rect.size.x, 0.10), holes):
			var lc := seg.get_center() - world_center
			m_frame.box(mats.trench_steel, Vector3(lc.x, top_y - 0.11, lc.y), Vector3(seg.size.x, 0.22, seg.size.y))
	for sx: float in [-1.0, 1.0]:
		for seg: Rect2 in _rect_minus_holes(Rect2(wcx + sx * (world_rect.size.x * 0.5 - 0.05) - 0.05, world_rect.position.y, 0.10, world_rect.size.y), holes):
			var lc := seg.get_center() - world_center
			m_frame.box(mats.trench_steel, Vector3(lc.x, top_y - 0.11, lc.y), Vector3(seg.size.x, 0.22, seg.size.y))
	var joist_x := maxi(1, floori(world_rect.size.x / 3.4))
	for i in range(1, joist_x):
		var jx := lerpf(world_rect.position.x, world_rect.end.x, float(i) / float(joist_x))
		for seg: Rect2 in _rect_minus_holes(Rect2(jx - 0.06, world_rect.position.y, 0.12, world_rect.size.y), holes):
			var lc := seg.get_center() - world_center
			m_frame.box(mats.trench_rib_dark, Vector3(lc.x, top_y - 0.12, lc.y), Vector3(seg.size.x, 0.18, seg.size.y))
	var joist_z := maxi(1, floori(world_rect.size.y / 3.4))
	for j in range(1, joist_z):
		var jz := lerpf(world_rect.position.y, world_rect.end.y, float(j) / float(joist_z))
		for seg: Rect2 in _rect_minus_holes(Rect2(world_rect.position.x, jz - 0.06, world_rect.size.x, 0.12), holes):
			var lc := seg.get_center() - world_center
			m_frame.box(mats.trench_rib_dark, Vector3(lc.x, top_y - 0.14, lc.y), Vector3(seg.size.x, 0.16, seg.size.y))
	if add_corner_stubs:
		for sx: float in [0.12, 0.88]:
			for sz: float in [0.14, 0.86]:
				var sp := Vector2(lerpf(world_rect.position.x, world_rect.end.x, sx), lerpf(world_rect.position.y, world_rect.end.y, sz))
				if not holes.any(func(h: Rect2): return h.grow(0.35).has_point(sp)):
					var lsp := sp - world_center
					m_frame.bar(mats.abyss_steel, Vector3(lsp.x, top_y - 0.18, lsp.y), Vector3(lsp.x, top_y - 3.6, lsp.y), 0.26)
	for hole: Rect2 in UNSTABLE_PLATES:
		if not world_rect.intersects(hole):
			continue
		var clipped := world_rect.intersection(hole)
		if clipped.size.x < 0.1 or clipped.size.y < 0.1:
			continue
		var hx := hole.get_center().x - world_center.x
		var hz := hole.get_center().y - world_center.y
		for sz: float in [-1.0, 1.0]:
			var gy := hole.get_center().y + sz * (hole.size.y * 0.5 + 0.04)
			if gy >= world_rect.position.y - 0.08 and gy <= world_rect.end.y + 0.08:
				m_frame.box(mats.safety_yellow, Vector3(hx, top_y - 0.06, gy - world_center.y), Vector3(hole.size.x + 0.16, 0.12, 0.08))
		for sx: float in [-1.0, 1.0]:
			var gx := hole.get_center().x + sx * (hole.size.x * 0.5 + 0.04)
			if gx >= world_rect.position.x - 0.08 and gx <= world_rect.end.x + 0.08:
				m_frame.box(mats.safety_yellow, Vector3(gx - world_center.x, top_y - 0.06, hz), Vector3(0.08, 0.12, hole.size.y + 0.16))

	var frame_node := MeshInstance3D.new()
	frame_node.name = "SubFrame"
	frame_node.mesh = m_frame.bake()
	frame_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	deck.add_child(frame_node)
	return deck


static func _build_bay_guardrails(pivot: Node3D, bay_rect: Rect2, world_center: Vector2, room_key: String,
		edges: Array, pit_curbs: Array[Array], mats: Dictionary) -> void:
	var m_rail := WAREHOUSE.MeshBuilder.new()
	for edge: Array in edges:
		if String(edge[0]) != room_key or is_north_bulkhead_edge(edge) or String(edge[0]) == "pit":
			continue
		for seg: Array in PLAN.open_edge(edge, PLAN.Visit.FREIGHT, true):
			var a: Vector2 = seg[1]
			var b: Vector2 = seg[2]
			var n: Vector2 = seg[3]
			var clipped := _clip_axis_seg_to_rect(a, b, bay_rect)
			if clipped.is_empty():
				continue
			var ca: Vector2 = clipped[0]
			var cb: Vector2 = clipped[1]
			var length := ca.distance_to(cb)
			if length < 0.70:
				continue
			var front_face := n.y > 0.5
			var rail_h := 0.46 if front_face else 1.02
			var spans := maxi(1, roundi(length / 2.35))
			for i in spans:
				var p0 := ca.lerp(cb, float(i) / float(spans))
				var p1 := ca.lerp(cb, float(i + 1) / float(spans))
				var span_mid := (p0 + p1) * 0.5
				var blocked_by_prop := false
				for pk: String in ["pallets", "cage_a", "cage_b", "trailer", "trailer_long", "pallets_out", "cage_in", "cage_crossdock", "dispatch_vessels", "cage_east"]:
					if PLAN.PROPS.has(pk) and (PLAN.PROPS[pk][0] as Rect2).grow(0.35).has_point(span_mid):
						blocked_by_prop = true
						break
				if blocked_by_prop:
					continue
				if (room_key == "west_bank" or room_key == "east_bank") and absf(n.y) > 0.5 and absf(span_mid.y - 21.4) < 1.6:
					continue
				var mode_roll := posmod(roundi(span_mid.x * 13.0 + span_mid.y * 29.0 + float(i) * 7.0), 10)
				_emit_guardrail_module(m_rail, mats, p0 - world_center, p1 - world_center, n, rail_h, mode_roll)

	for curb: Array in pit_curbs:
		if String(curb[0]) != room_key:
			continue
		var clipped := _clip_axis_seg_to_rect(curb[1], curb[2], bay_rect)
		if clipped.is_empty():
			continue
		var pn: Vector2 = curb[3]
		_emit_guardrail_module(m_rail, mats, clipped[0] - world_center, clipped[1] - world_center, pn, 0.44 if pn.y > 0 else 0.85, 4)

	var rail_mesh := m_rail.bake()
	if rail_mesh.get_surface_count() > 0:
		var rail_node := MeshInstance3D.new()
		rail_node.name = "BayGuardrails"
		rail_node.mesh = rail_mesh
		rail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pivot.add_child(rail_node)


static func _clip_axis_seg_to_rect(a: Vector2, b: Vector2, r: Rect2) -> Array[Vector2]:
	var vertical := absf(a.x - b.x) < 0.02
	if vertical:
		if a.x < r.position.x - 0.06 or a.x > r.end.x + 0.06:
			return []
		var y0 := maxf(minf(a.y, b.y), r.position.y)
		var y1 := minf(maxf(a.y, b.y), r.end.y)
		if y1 - y0 < 0.25:
			return []
		return [Vector2(a.x, y0), Vector2(a.x, y1)]
	if a.y < r.position.y - 0.06 or a.y > r.end.y + 0.06:
		return []
	var x0 := maxf(minf(a.x, b.x), r.position.x)
	var x1 := minf(maxf(a.x, b.x), r.end.x)
	if x1 - x0 < 0.25:
		return []
	return [Vector2(x0, a.y), Vector2(x1, a.y)]


static func _emit_guardrail_module(m: WAREHOUSE.MeshBuilder, mats: Dictionary,
		a: Vector2, b: Vector2, outward_n: Vector2, height: float, mode_roll: int) -> void:
	# 0,1 = MISSING_GAP (sheared stumps overlooking abyss); 2 = BENT_OUTWARD; 3 = COLLAPSED_TOP; 4..9 = INTACT
	var inset := -outward_n * 0.08
	var p0 := Vector3(a.x + inset.x, 0.0, a.y + inset.y)
	var p1 := Vector3(b.x + inset.x, 0.0, b.y + inset.y)
	var out_3 := Vector3(outward_n.x, 0.0, outward_n.y)

	if mode_roll <= 1:
		# Broken missing guardrail span: jagged sheared stumps + bent kickplate leaving open drop to abyss
		m.bar(mats.rail_metal, p0, p0 + Vector3(0.0, 0.28, 0.0), 0.08)
		m.bar(mats.rail_metal, p1, p1 + Vector3(0.0, 0.20, 0.0) + out_3 * 0.09, 0.08)
		m.bar(mats.safety_yellow, p0 + Vector3(0.0, 0.05, 0.0), p0.lerp(p1, 0.22) + Vector3(0.0, 0.05, 0.0), 0.065)
		return

	if mode_roll == 2:
		# Damaged guardrail bent steeply outward over the pitch-black abyss
		var tilt := Vector3(0.0, height * 0.56, 0.0) + out_3 * 0.78
		m.bar(mats.rail_metal, p0, p0 + Vector3(0.0, height * 0.88, 0.0), 0.08)
		m.bar(mats.rail_metal, p1, p1 + tilt, 0.08)
		m.bar(mats.safety_yellow, p0 + Vector3(0.0, height * 0.86, 0.0), p1 + tilt, 0.072)
		m.bar(mats.rail_metal, p0 + Vector3(0.0, height * 0.44, 0.0), p1 + tilt * 0.52, 0.058)
		return

	if mode_roll == 3:
		# Collapsed section: top yellow handrail snapped loose and slumped onto the grating edge
		m.bar(mats.rail_metal, p0, p0 + Vector3(0.0, height, 0.0), 0.08)
		m.bar(mats.rail_metal, p1, p1 + Vector3(0.0, 0.24, 0.0) + out_3 * 0.12, 0.08)
		m.bar(mats.safety_yellow, p0 + Vector3(0.0, height * 0.94, 0.0), p1 + Vector3(0.0, 0.16, 0.0) + out_3 * 0.14, 0.072)
		m.bar(mats.rail_metal, p0 + Vector3(0.0, height * 0.48, 0.0), p0.lerp(p1, 0.65) + Vector3(0.0, 0.22, 0.0), 0.056)
		return

	# Intact double-bar industrial safety guardrail (galvanized posts + high-visibility weathered yellow top rail)
	m.bar(mats.rail_metal, p0, p0 + Vector3(0.0, height, 0.0), 0.082)
	m.bar(mats.rail_metal, p1, p1 + Vector3(0.0, height, 0.0), 0.082)
	m.bar(mats.safety_yellow, p0 + Vector3(0.0, height * 0.96, 0.0), p1 + Vector3(0.0, height * 0.96, 0.0), 0.072)
	m.bar(mats.rail_metal, p0 + Vector3(0.0, height * 0.50, 0.0), p1 + Vector3(0.0, height * 0.50, 0.0), 0.058)
	m.bar(mats.safety_yellow, p0 + Vector3(0.0, 0.05, 0.0), p1 + Vector3(0.0, 0.05, 0.0), 0.062)


## Builds bottomless black abyss void floor, disappearing support stanchions, and submerged giant chasm pipes.
static func _build_chasm_depths(floor_root: Node3D, wall_root: Node3D, mats: Dictionary) -> Array[Node3D]:
	var turbines: Array[Node3D] = []
	# Pure pitch-black abyss floor below the entire 1-3 suspended facility
	var abyss := KIT.M.box(floor_root, "FreightAbyssVoid", Vector3(145.0, 0.4, 138.0), Vector3(34.0, -14.8, 56.0), mats.abyss_black)
	abyss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var m_sub := WAREHOUSE.MeshBuilder.new()
	# Structural vertical corner pylons live inside each modular bay so they shear and plunge when the bay collapses.
	# Giant criss-crossing coolant pipe mains beneath open grating platforms (visible through holes & past broken rails)
	for pipe_seg: Array in [
		[Vector3(-18.0, -2.4, 18.0), Vector3(16.0, -2.4, 18.0), 0.92, true],
		[Vector3(-18.0, -3.6, 21.4), Vector3(18.0, -3.6, 21.4), 1.05, false],
		[Vector3(-6.0, -2.8, 12.0), Vector3(-6.0, -2.8, 62.0), 0.88, false],
		[Vector3(4.5, -3.5, 12.0), Vector3(4.5, -3.5, 64.0), 0.96, true],
		[Vector3(-16.0, -2.6, 36.0), Vector3(18.0, -2.6, 36.0), 0.84, true],
		[Vector3(-14.0, -3.2, 48.0), Vector3(16.0, -3.2, 48.0), 0.92, false],
		[Vector3(2.0, -2.8, 59.5), Vector3(26.0, -2.8, 59.5), 0.94, true],
		[Vector3(14.0, -3.0, 56.0), Vector3(14.0, -3.0, 106.0), 0.98, false],
		[Vector3(4.0, -2.6, 91.5), Vector3(84.0, -2.6, 91.5), 1.05, true],
		[Vector3(4.0, -4.1, 96.5), Vector3(84.0, -4.1, 96.5), 0.92, false],
		[Vector3(71.0, -2.9, 52.0), Vector3(71.0, -2.9, 105.0), 0.96, false],
		[Vector3(59.0, -2.7, 25.0), Vector3(59.0, -2.7, 62.0), 0.90, true],
		# Heavy submerged coolant pipes flanking outside the open catwalk drop-offs
		[Vector3(-14.2, -1.6, 14.0), Vector3(-14.2, -1.6, 56.0), 0.92, true],
		[Vector3(13.4, -1.8, 14.0), Vector3(13.4, -1.8, 56.0), 0.92, false],
		[Vector3(5.2, -1.7, 67.0), Vector3(5.2, -1.7, 86.0), 0.88, true],
		[Vector3(24.0, -1.8, 55.0), Vector3(24.0, -1.8, 86.0), 0.88, false],
		[Vector3(26.0, -1.8, 103.6), Vector3(56.0, -1.8, 103.6), 0.96, true],
		[Vector3(71.0, -1.8, 36.0), Vector3(71.0, -1.8, 55.0), 0.88, false],
		# Vertical abyss riser stacks plunging into blackness beside platform sides
		[Vector3(-15.2, -0.2, 29.0), Vector3(-15.2, -12.0, 29.0), 0.95, false],
		[Vector3(14.2, -0.2, 34.0), Vector3(14.2, -12.0, 34.0), 0.95, true],
		[Vector3(30.0, -0.4, 104.2), Vector3(30.0, -12.0, 104.2), 1.05, false],
		[Vector3(52.0, -0.4, 104.2), Vector3(52.0, -12.0, 104.2), 1.05, true],
		[Vector3(82.4, -0.2, 74.0), Vector3(82.4, -12.0, 74.0), 0.95, false],
	]:
		var mat: Material = mats.abyss_pipe_rust if pipe_seg[3] else mats.abyss_pipe
		m_sub.bar(mat, pipe_seg[0], pipe_seg[1], pipe_seg[2])

	var sub_node := MeshInstance3D.new()
	sub_node.name = "FreightAbyssStructures"
	sub_node.mesh = m_sub.bake()
	sub_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	floor_root.add_child(sub_node)

	# Large slow-spinning industrial exhaust turbines beneath grating & on North bulkhead walls
	for spec: Array in [
		[Vector3(-2.5, -3.2, 29.5), Vector3(90, 0, 0), 3.6],
		[Vector3(36.0, -3.4, 92.5), Vector3(90, 0, 0), 4.2],
		[Vector3(64.5, -3.2, 54.0), Vector3(90, 0, 0), 3.4],
		[Vector3(28.1, 2.75, 86.10), Vector3.ZERO, 1.9],
		[Vector3(55.8, 2.75, 86.10), Vector3.ZERO, 1.9],
	]:
		var fan := _build_exhaust_fan(wall_root, spec[0], spec[1], float(spec[2]), mats)
		turbines.append(fan)
	return turbines


static func _build_exhaust_fan(parent: Node3D, at: Vector3, rot_deg: Vector3, diam: float, mats: Dictionary) -> Node3D:
	var shroud := Node3D.new()
	shroud.name = "FreightTurbineShroud"
	shroud.position = at
	shroud.rotation_degrees = rot_deg
	parent.add_child(shroud)
	var m_frame := WAREHOUSE.MeshBuilder.new()
	m_frame.box(mats.trench_rib_dark, Vector3(0, 0, -0.08), Vector3(diam, diam, 0.14))
	var r := diam * 0.48
	for s in 8:
		var a0 := TAU * float(s) / 8.0
		var a1 := TAU * float(s + 1) / 8.0
		m_frame.bar(mats.trench_steel, Vector3(cos(a0) * r, sin(a0) * r, 0.05), Vector3(cos(a1) * r, sin(a1) * r, 0.05), 0.14)
	var frame := MeshInstance3D.new()
	frame.mesh = m_frame.bake()
	shroud.add_child(frame)

	var rotor := Node3D.new()
	rotor.name = "TurbineRotor"
	shroud.add_child(rotor)
	var m_blades := WAREHOUSE.MeshBuilder.new()
	for k in 6:
		var ang := TAU * float(k) / 6.0
		var b0 := Vector3.ZERO
		var b1 := Vector3(cos(ang) * diam * 0.44, sin(ang) * diam * 0.44, 0.04)
		m_blades.bar(mats.trench_steel, b0, b1, diam * 0.12)
	m_blades.box(mats.pipe_rusted, Vector3(0, 0, 0.06), Vector3(diam * 0.24, diam * 0.24, 0.16))
	var blades := MeshInstance3D.new()
	blades.mesh = m_blades.bake()
	rotor.add_child(blades)
	return rotor


## Dresses the entire 1-3 suspended metal grating catwalks, broken rails, black chasm, red buttress backdrops & decals.
static func dress_freight_hall(floor_root: Node3D, wall_root: Node3D, fittings: RefCounted, cutout: RefCounted) -> Dictionary:
	var mats := materials()
	var top_black: Material = cutout.top_black
	var m_arch := WAREHOUSE.MeshBuilder.new()

	# North backdrop buttress bays & continuous horizontal overhead pipes behind entrances/windows/ramp
	for bay: Array in BUTTRESS_BAYS:
		_emit_local_sloped_rib(m_arch, mats, top_black, _wall_xform(bay[0], bay[1]))
	for seg: Array in [
		[Vector3(11.6, 1.65, 55.08), Vector3(21.8, 1.65, 55.08)],
		[Vector3(22.1, 1.65, 86.08), Vector3(34.8, 1.65, 86.08)],
		[Vector3(49.2, 1.65, 86.08), Vector3(62.8, 1.65, 86.08)],
		[Vector3(69.2, 1.65, 55.08), Vector3(79.6, 1.65, 55.08)],
	]:
		_add_horizontal_pipe_run(m_arch, mats, seg[0], seg[1])
	for px: float in [-12.25, -1.65]:
		_emit_local_box(m_arch, mats.trench_steel, _wall_xform(Vector3(px, 0.0, 14.0), Vector2.UP), Vector3(0.0, 2.20, 0.16), Vector3(0.36, 4.40, 0.36))
		_emit_local_box(m_arch, mats.safety_yellow, _wall_xform(Vector3(px, 0.0, 14.0), Vector2.UP), Vector3(0.0, 0.55, 0.35), Vector3(0.38, 1.10, 0.05))
		_emit_local_box(m_arch, top_black, _wall_xform(Vector3(px, 0.0, 14.0), Vector2.UP), Vector3(0.0, 4.40, 0.16), Vector3(0.40, 0.10, 0.40))

	var arch_mesh := MeshInstance3D.new()
	arch_mesh.name = "FreightButtressSuperstructure"
	arch_mesh.mesh = m_arch.bake()
	arch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	wall_root.add_child(arch_mesh)

	var turbines := _build_chasm_depths(floor_root, wall_root, mats)
	var unstable := build_unstable_plates(floor_root)
	_build_freight_stencils(wall_root, fittings)
	var clutter := build_freight_clutter(floor_root, fittings, cutout)
	var dyn := build_freight_dynamic_props(floor_root, fittings, cutout)

	return {
		"unstable_plates": unstable,
		"turbines": turbines,
		"clutter": clutter,
		"breakables": dyn.breakables,
		"deck_drops": dyn.deck_drops,
		"fractures": dyn.fractures,
		"chasm_drops": dyn.chasm_drops,
		"boss_beam": dyn.boss_beam,
	}


static func _container_body_material(tint_key: String) -> StandardMaterial3D:
	var cache_key := "iso_body_" + tint_key
	if _container_mat_cache.has(cache_key):
		return _container_mat_cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(WAREHOUSE.IRON_DIFF)
	mat.albedo_color = CONTAINER_TINTS.get(tint_key, Color("3b4d59"))
	mat.metallic = 0.38
	mat.roughness = 0.54
	mat.normal_enabled = true
	mat.normal_texture = load(WAREHOUSE.IRON_NOR)
	mat.normal_scale = 0.48
	mat.roughness_texture = load(WAREHOUSE.IRON_ROUGH)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	_container_mat_cache[cache_key] = mat
	return mat

static func _weathered_container_material(tint_key: String, size: Vector3, frame_steel := false) -> ShaderMaterial:
	var key := [tint_key,size,frame_steel]
	if _container_mat_cache.has(key): return _container_mat_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = PAINTED_STEEL
	mat.set_shader_parameter("iron_color",load(WAREHOUSE.IRON_DIFF))
	mat.set_shader_parameter("iron_roughness",load(WAREHOUSE.IRON_ROUGH))
	mat.set_shader_parameter("iron_normal",load(WAREHOUSE.IRON_NOR))
	mat.set_shader_parameter("half_extents",size*.5)
	mat.set_shader_parameter("frame_steel",frame_steel)
	mat.set_shader_parameter("paint",Color("363e43") if frame_steel else CONTAINER_TINTS.get(tint_key,Color("3b4d59")))
	_container_mat_cache[key] = mat
	return mat


static func spawn_cc0_container(parent: Node3D, _fittings: RefCounted, variant: String, center: Vector3,
		world_size: Vector3, yaw_deg := 0.0, tint_key := "slate", cutout: RefCounted = null, register_cutout := true) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ISOContainer_%s" % variant
	holder.position = center
	holder.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(holder)

	var sx := world_size.x
	var sy := world_size.y
	var sz := world_size.z
	var long_x := sx >= sz
	var length := maxf(sx, sz)
	var width := minf(sx, sz)
	var mats := materials()
	var weathered := variant=="arena_container"
	var body_mat: Material = _weathered_container_material(tint_key,world_size) if weathered else _container_body_material(tint_key)
	var frame_mat: Material = _weathered_container_material(tint_key,world_size,true) if weathered else mats.trench_steel
	var latch_mat: Material = frame_mat if weathered else mats.steel_mid
	var m := WAREHOUSE.MeshBuilder.new()

	# Core corrugated steel box & top roof panel
	m.box(body_mat, Vector3.ZERO, Vector3(sx - 0.12, sy - 0.14, sz - 0.12))
	# Structural ISO corner posts & perimeter longitudinal top/bottom rails
	for px: float in [-0.5, 0.5]:
		for pz: float in [-0.5, 0.5]:
			m.box(frame_mat, Vector3(px * (sx - 0.16), 0.0, pz * (sz - 0.16)), Vector3(0.18, sy, 0.18))
			m.box(mats.safety_yellow, Vector3(px * (sx - 0.17), -sy * 0.5 + 0.12, pz * (sz - 0.17)), Vector3(0.20, 0.24, 0.20))
			m.box(frame_mat, Vector3(px * (sx - 0.17), sy * 0.5 - 0.09, pz * (sz - 0.17)), Vector3(0.20, 0.18, 0.20))
	for side: float in [-0.5, 0.5]:
		for ry: float in [-sy * 0.5 + 0.07, sy * 0.5 - 0.07]:
			if long_x:
				m.box(frame_mat, Vector3(0.0, ry, side * (sz - 0.12)), Vector3(sx - 0.16, 0.14, 0.14))
			else:
				m.box(frame_mat, Vector3(side * (sx - 0.12), ry, 0.0), Vector3(0.14, 0.14, sz - 0.16))
	# Corrugated vertical side wall ribs & stamped roof ribs
	var ribs := clampi(roundi(length / 0.42), 5, 12)
	for i in ribs:
		var t := ((float(i) + 0.5) / float(ribs) - 0.5) * (length - 0.44)
		for side: float in [-1.0, 1.0]:
			if long_x:
				m.box(body_mat, Vector3(t, 0.0, side * (sz * 0.5 - 0.05)), Vector3(0.16, sy - 0.28, 0.08))
			else:
				m.box(body_mat, Vector3(side * (sx * 0.5 - 0.05), 0.0, t), Vector3(0.08, sy - 0.28, 0.16))
		if long_x:
			m.box(body_mat, Vector3(t, sy * 0.5 - 0.05, 0.0), Vector3(0.18, 0.08, width - 0.30))
		else:
			m.box(body_mat, Vector3(0.0, sy * 0.5 - 0.05, t), Vector3(width - 0.30, 0.08, 0.18))
	# Double cargo end-doors with vertical galvanized steel locking bars + industrial hazard stripe
	for bar_off: float in [-0.14, 0.14]:
		if long_x:
			m.box(latch_mat, Vector3(sx * 0.5 - 0.03, 0.0, bar_off * width), Vector3(0.06, sy - 0.30, 0.06))
			m.box(mats.safety_yellow, Vector3(0.0, -sy * 0.5 + 0.24, (sz * 0.5 - 0.02) if bar_off > 0.0 else -(sz * 0.5 - 0.02)), Vector3(length * 0.24, 0.09, 0.03))
		else:
			m.box(latch_mat, Vector3(bar_off * width, 0.0, sz * 0.5 - 0.03), Vector3(0.06, sy - 0.30, 0.06))
			m.box(mats.safety_yellow, Vector3((sx * 0.5 - 0.02) if bar_off > 0.0 else -(sx * 0.5 - 0.02), -sy * 0.5 + 0.24, 0.0), Vector3(0.03, 0.09, length * 0.24))

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "ContainerHull"
	body_mesh.mesh = m.bake()
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(body_mesh)
	if register_cutout and cutout != null:
		cutout.register_mesh(body_mesh)
	return holder


static func _make_hazard_material(zone_size: Vector2, curtain: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HAZARD_SHADER
	mat.set_shader_parameter("zone_size", zone_size)
	mat.set_shader_parameter("curtain_mode", curtain)
	mat.set_shader_parameter("pulse_speed", 4.5 if curtain else 5.2)
	mat.set_shader_parameter("intensity", 1.0)
	return mat


static func _add_warning_label(parent: Node3D, text_str: String, pos: Vector3, rot_deg: Vector3, max_span: float, text_height := 0.28) -> void:
	var lbl := Label3D.new()
	lbl.text = text_str
	lbl.font = WARNING_FONT
	lbl.font_size = 44
	lbl.pixel_size = clampf(text_height / 44.0, 0.004, minf(0.012, max_span / 260.0))
	lbl.modulate = Color(1.0, 0.24, 0.16, 0.94)
	lbl.outline_size = 0
	lbl.shaded = false
	lbl.double_sided = true
	lbl.no_depth_test = false
	lbl.position = pos
	lbl.rotation_degrees = rot_deg
	parent.add_child(lbl)


static func build_holographic_warning_zone(parent: Node3D, rect: Rect2, include_shadow := false) -> Node3D:
	var mats := materials()
	var c := rect.get_center()
	var sx := rect.size.x
	var sz := rect.size.y
	var zone := Node3D.new()
	zone.name = "HoloWarningZone"
	zone.position = Vector3(c.x, 0.036, c.y)
	zone.visible = false
	parent.add_child(zone)

	if include_shadow:
		KIT.M.box(zone, "DropShadow", Vector3(sx * 0.90, 0.016, sz * 0.90), Vector3(0.0, -0.014, 0.0), mats.abyss_black)

	# Ground holographic dashed perimeter + diagonal 45-degree warning chevron projection pad with explicit [0..1] UVs
	var m_pad := WAREHOUSE.MeshBuilder.new()
	var hx := sx * 0.5
	var hz := sz * 0.5
	var pad_mat := _make_hazard_material(rect.size, false)
	m_pad.quad(pad_mat, Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz),
		Vector3.UP, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0))
	var pad_mesh := MeshInstance3D.new()
	pad_mesh.name = "HazardGroundPad"
	pad_mesh.mesh = m_pad.bake()
	pad_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(pad_mesh)

	# Flared translucent red projection curtain walls matching the angled beam rays in ref art (UV.y=0 bottom -> 1 top)
	var m_curt := WAREHOUSE.MeshBuilder.new()
	var curt_mat := _make_hazard_material(rect.size, true)
	var ch := 0.78
	var flare := 0.18
	var u00 := Vector2(0.0, 0.0)
	var u10 := Vector2(1.0, 0.0)
	var u11 := Vector2(1.0, 1.0)
	var u01 := Vector2(0.0, 1.0)
	m_curt.quad(curt_mat, Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(hx + flare, ch, hz + flare), Vector3(-hx - flare, ch, hz + flare), Vector3(0.0, 0.22, 1.0).normalized(), u00, u10, u11, u01)
	m_curt.quad(curt_mat, Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz), Vector3(-hx - flare, ch, -hz - flare), Vector3(hx + flare, ch, -hz - flare), Vector3(0.0, 0.22, -1.0).normalized(), u00, u10, u11, u01)
	m_curt.quad(curt_mat, Vector3(-hx, 0.0, -hz), Vector3(-hx, 0.0, hz), Vector3(-hx - flare, ch, hz + flare), Vector3(-hx - flare, ch, -hz - flare), Vector3(-1.0, 0.22, 0.0).normalized(), u00, u10, u11, u01)
	m_curt.quad(curt_mat, Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz), Vector3(hx + flare, ch, -hz - flare), Vector3(hx + flare, ch, hz + flare), Vector3(1.0, 0.22, 0.0).normalized(), u00, u10, u11, u01)
	var curt_mesh := MeshInstance3D.new()
	curt_mesh.name = "HazardHoloCurtains"
	curt_mesh.mesh = m_curt.bake()
	curt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(curt_mesh)

	# Stenciled "警告 STAY AWAY" projected just inside inner dashed line & along curtain walls like ref art
	var strap := "警告  STAY AWAY" if maxf(sx, sz) < 5.5 else "警告  STAY AWAY  警告"
	var edge_in := minf(0.84, minf(sx, sz) * 0.28)
	if sx >= 2.2:
		_add_warning_label(zone, strap, Vector3(0.0, 0.014, hz - edge_in), Vector3(-90.0, 0.0, 0.0), sx, 0.24)
		_add_warning_label(zone, strap, Vector3(0.0, 0.28, hz + 0.05), Vector3(-12.0, 0.0, 0.0), sx, 0.24)
		_add_warning_label(zone, strap, Vector3(0.0, 0.014, -hz + edge_in), Vector3(-90.0, 180.0, 0.0), sx, 0.24)
	if sz >= 2.6:
		_add_warning_label(zone, strap, Vector3(hx - edge_in, 0.014, 0.0), Vector3(-90.0, 90.0, 0.0), sz, 0.24)
		_add_warning_label(zone, strap, Vector3(hx + 0.05, 0.28, 0.0), Vector3(-12.0, 90.0, 0.0), sz, 0.24)
		_add_warning_label(zone, strap, Vector3(-hx + edge_in, 0.014, 0.0), Vector3(-90.0, -90.0, 0.0), sz, 0.24)

	zone.set_meta("curtain_mat", curt_mat)
	zone.set_meta("pad_mat", pad_mat)
	return zone


static func build_missile_projectile(parent: Node3D) -> Node3D:
	var mats := materials()
	var msl := Node3D.new()
	msl.name = "BossBreakMissile"
	parent.add_child(msl)
	KIT.M.box(msl, "Body", Vector3(0.18, 0.18, 0.92), Vector3.ZERO, mats.trench_steel)
	KIT.M.box(msl, "Warhead", Vector3(0.14, 0.14, 0.24), Vector3(0.0, 0.0, -0.54), mats.beacon_alert)
	KIT.M.box(msl, "Plume", Vector3(0.12, 0.12, 0.48), Vector3(0.0, 0.0, 0.64), mats.beacon_amber)
	for rot_z: float in [0.0, 90.0]:
		var fin := KIT.M.box(msl, "Fin", Vector3(0.40, 0.03, 0.18), Vector3(0.0, 0.0, 0.34), mats.buttress_red)
		fin.rotation_degrees.z = rot_z
	return msl


static func spawn_functional_cargo_module(parent: Node3D, fittings: RefCounted, style: String, center: Vector3,
		world_size: Vector3, yaw_deg := 0.0, tint_key := "slate", top_tint := "ochre",
		cutout: RefCounted = null, register_cutout := true, with_crane_rig := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = "CargoModule_%s" % style
	holder.position = center
	holder.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(holder)

	var mats := materials()
	var sx := world_size.x
	var sy := world_size.y
	var sz := world_size.z
	var long_x := sx >= sz
	var skids_h := 0.12

	# Industrial steel dunnage skids under every port module so it rests structurally on decking
	for s_off: float in [-0.36, 0.36]:
		if long_x:
			KIT.M.box(holder, "Skid", Vector3(sx * 0.94, skids_h, 0.16), Vector3(0.0, -sy * 0.5 + skids_h * 0.5, s_off * sz), mats.trench_steel)
		else:
			KIT.M.box(holder, "Skid", Vector3(0.16, skids_h, sz * 0.94), Vector3(s_off * sx, -sy * 0.5 + skids_h * 0.5, 0.0), mats.trench_steel)

	if style == "equipment_skid":
		var deck_h := 0.16
		var base_y := -sy * 0.5 + skids_h
		KIT.M.box(holder, "SkidDeck", Vector3(sx * 0.96, deck_h, sz * 0.96), Vector3(0.0, base_y + deck_h * 0.5, 0.0), mats.trench_steel)
		KIT.M.box(holder, "SkidTrim", Vector3(sx * 0.97, 0.05, sz * 0.97), Vector3(0.0, base_y + deck_h, 0.0), mats.safety_yellow)
		var top_base := base_y + deck_h
		if fittings != null:
			var crate_s := Vector3(sx * 0.36, clampf(sy * 0.52, 0.75, 1.35), sz * 0.42)
			var c_node: Node3D = fittings.fit(holder, QUAT_DIR + "Prop_Crate3.scn", Vector3(-sx * 0.24, top_base + crate_s.y * 0.5, -sz * 0.15), crate_s)
			var p_node: Node3D = fittings.fit(holder, QUAT_DIR + "Prop_PipeHolder.scn", Vector3(sx * 0.22, top_base + 0.42, 0.0), Vector3(sx * 0.38, 0.84, sz * 0.68))
			fittings.fit(holder, QUAT_DIR + "Prop_Vent_Small.scn", Vector3(-sx * 0.24, top_base + crate_s.y + 0.22, -sz * 0.15), Vector3(crate_s.x * 0.72, 0.44, crate_s.z * 0.72))
			fittings.fit(holder, QUAT_DIR + "Prop_Cable_3.scn", Vector3(sx * 0.22, top_base + 0.20, sz * 0.24), Vector3(0.85, 0.40, 0.85))
			fittings.barrel(holder, Vector3(-sx * 0.22, top_base + 0.52, sz * 0.26), 0.95, 0.62, true, Color("72563c"), true)
			if register_cutout and cutout != null:
				if is_instance_valid(c_node): cutout.register_tree(c_node)
				if is_instance_valid(p_node): cutout.register_tree(p_node)
	elif style == "crane_rack_cargo":
		var body_h := clampf(sy - skids_h - 0.85, 1.75, 2.35)
		var base_c := -sy * 0.5 + skids_h + body_h * 0.5
		spawn_cc0_container(holder, fittings, style, Vector3(0.0, base_c, 0.0),
			Vector3(sx, body_h, sz), 0.0, tint_key, cutout, register_cutout)
		var roof_y := base_c + body_h * 0.5
		KIT.M.box(holder, "RoofRackDeck", Vector3(sx * 0.92, 0.10, sz * 0.92), Vector3(0.0, roof_y + 0.05, 0.0), mats.trench_steel)
		if fittings != null:
			var crate_w := minf(sx, sz) * 0.62
			var c_top: Node3D = fittings.fit(holder, QUAT_DIR + "Prop_Crate3.scn",
				Vector3(-sx * 0.16 if long_x else 0.0, roof_y + 0.52, 0.0 if long_x else -sz * 0.16),
				Vector3(crate_w, 0.84, crate_w))
			fittings.barrel(holder, Vector3(sx * 0.22 if long_x else 0.0, roof_y + 0.48, 0.0 if long_x else sz * 0.22),
				minf(sx, sz) * 0.68, 0.56, false, Color("8a6a42"), true)
			fittings.fit(holder, QUAT_DIR + "Prop_Cable_3.scn",
				Vector3(sx * 0.10 if long_x else -sx * 0.18, roof_y + 0.25, sz * 0.18 if long_x else sz * 0.08),
				Vector3(0.75, 0.36, 0.75))
			if register_cutout and cutout != null and is_instance_valid(c_top):
				cutout.register_tree(c_top)
	elif style == "double_stack":
		var h1 := clampf((sy - skids_h) * 0.52, 1.85, 2.25)
		var h2 := maxf(1.65, sy - skids_h - h1)
		var y1 := -sy * 0.5 + skids_h + h1 * 0.5
		var y2 := y1 + h1 * 0.5 + h2 * 0.5
		spawn_cc0_container(holder, fittings, "tier1", Vector3(0.0, y1, 0.0),
			Vector3(sx, h1, sz), 0.0, tint_key, cutout, register_cutout)
		var tier2_size := Vector3(sx * (0.86 if long_x else 0.94), h2, sz * (0.94 if long_x else 0.86))
		var shift := Vector3((sx * 0.05) if long_x else 0.0, y2, 0.0 if long_x else (sz * 0.05))
		KIT.M.box(holder, "InterTierTwistFrame", Vector3(tier2_size.x * 1.02, 0.06, tier2_size.z * 1.02),
			Vector3(shift.x, y1 + h1 * 0.5 + 0.01, shift.z), mats.steel_mid)
		spawn_cc0_container(holder, fittings, "tier2", shift, tier2_size, 0.0, top_tint, cutout, register_cutout)
		# Crisp safety-yellow perimeter bumper rails on upper container roof edge so 2-tier stack reads cleanly
		for side_s: float in [-0.47, 0.47]:
			KIT.M.box(holder, "Tier2EdgeTrim", Vector3(tier2_size.x * 0.98, 0.045, 0.10) if long_x else Vector3(0.10, 0.045, tier2_size.z * 0.98),
				shift + Vector3(0.0 if long_x else side_s * tier2_size.x, h2 * 0.5 + 0.015, side_s * tier2_size.z if long_x else 0.0), mats.safety_yellow)
		# Vertical steel service ladder on end wall + rooftop HVAC unit & guardrail
		var lad_at := shift + (Vector3(-tier2_size.x * 0.5 - 0.05, -h2 * 0.35, 0.0) if long_x else Vector3(0.0, -h2 * 0.35, -tier2_size.z * 0.5 - 0.05))
		for s_dir: float in [-0.22, 0.22]:
			var rail := KIT.M.box(holder, "LadderStile", Vector3(0.05, sy * 0.82, 0.05),
				lad_at + (Vector3(0.0, 0.0, s_dir) if long_x else Vector3(s_dir, 0.0, 0.0)), mats.safety_yellow)
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for r_i in 6:
			var rung_y := -sy * 0.38 + float(r_i) * (sy * 0.14)
			KIT.M.box(holder, "LadderRung", Vector3(0.04, 0.04, 0.44) if long_x else Vector3(0.44, 0.04, 0.04),
				Vector3(lad_at.x, rung_y, lad_at.z), mats.steel_mid)
		if fittings != null:
			fittings.fit(holder, QUAT_DIR + "Prop_Vent_Wide.scn",
				shift + Vector3(0.0, h2 * 0.5 + 0.30, 0.0),
				Vector3(minf(tier2_size.x * 0.45, 1.5), 0.56, minf(tier2_size.z * 0.45, 1.5)))
			var rail_n: Node3D = fittings.fit(holder, SCIFI_DIR + "Prop_Rail_4.scn",
				shift + Vector3(0.0, h2 * 0.5 + 0.34, tier2_size.z * 0.44 if long_x else 0.0) + (Vector3(tier2_size.x * 0.44, 0.0, 0.0) if not long_x else Vector3.ZERO),
				Vector3(tier2_size.x * 0.72, 0.64, 0.10) if long_x else Vector3(0.10, 0.64, tier2_size.z * 0.72),
				Vector3(0.0, 0.0 if long_x else 90.0, 0.0))
			if register_cutout and cutout != null and is_instance_valid(rail_n):
				cutout.register_tree(rail_n)
		KIT.M.box(holder, "TierStrobe", Vector3(0.16, 0.14, 0.16), shift + Vector3(tier2_size.x * 0.38, h2 * 0.5 + 0.09, -tier2_size.z * 0.38), mats.beacon_amber)
	else:
		spawn_cc0_container(holder, fittings, style, Vector3(0.0, skids_h * 0.5, 0.0),
			Vector3(sx, sy - skids_h, sz), 0.0, tint_key, cutout, register_cutout)

	if with_crane_rig:
		var spreader := Node3D.new()
		spreader.name = "CraneSpreaderRig"
		holder.add_child(spreader)
		var top_y := sy * 0.5 + 0.34
		KIT.M.box(spreader, "SpreaderBeam", Vector3(sx * 0.90, 0.18, sz * 0.90), Vector3(0.0, top_y, 0.0), mats.safety_yellow)
		KIT.M.box(spreader, "MainHoistLine", Vector3(0.08, 10.5, 0.08), Vector3(0.0, top_y + 5.3, 0.0), mats.steel_mid)
		for cx_s: float in [-0.42, 0.42]:
			for cz_s: float in [-0.42, 0.42]:
				KIT.M.box(spreader, "TwistWire", Vector3(0.045, 0.44, 0.045), Vector3(cx_s * sx, top_y - 0.18, cz_s * sz), mats.trench_steel)
		KIT.M.box(spreader, "CraneStrobe", Vector3(0.20, 0.14, 0.20), Vector3(0.0, top_y + 0.14, 0.0), mats.beacon_amber)

	return holder


static func build_freight_clutter(floor_root: Node3D, fittings: RefCounted, cutout: RefCounted) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if fittings == null:
		return items
	var clutter_root := Node3D.new()
	clutter_root.name = "FreightClutter"
	floor_root.add_child(clutter_root)
	var mats := materials()
	for idx in PLAN.FREIGHT_CLUTTER.size():
		var spec: Array = PLAN.FREIGHT_CLUTTER[idx]
		var kind: String = spec[0]
		var rect: Rect2 = spec[1]
		var height := float(spec[2])
		var rot_deg := float(spec[3])
		var tint_key: String = spec[4]
		var c := rect.get_center()
		var item_node := Node3D.new()
		item_node.name = "FreightClutterItem_%d" % idx
		clutter_root.add_child(item_node)
		if kind == "crate":
			var crate_node: Node3D = fittings.fit(item_node, QUAT_DIR + "Prop_Crate3.scn",
				Vector3(c.x, height * 0.5, c.y), Vector3(rect.size.x * 0.92, height, rect.size.y * 0.92), Vector3(0.0, rot_deg, 0.0))
			if is_instance_valid(crate_node) and cutout != null: cutout.register_tree(crate_node)
		elif kind == "barrel_cluster":
			var pad := KIT.M.box(item_node, "DrumPallet_%d" % idx, Vector3(rect.size.x, 0.12, rect.size.y), Vector3(c.x, 0.06, c.y), mats.trench_steel)
			pad.rotation.y = deg_to_rad(rot_deg)
			for off: Vector2 in [Vector2(-0.28, -0.18), Vector2(0.26, -0.14), Vector2(0.0, 0.20)]:
				var bp := Vector3(c.x + off.x * rect.size.x, 0.12 + (height - 0.12) * 0.5, c.y + off.y * rect.size.y)
				fittings.fit(item_node, "Prop_Barrel_Large", bp, Vector3(0.82, height - 0.12, 0.82), Vector3(0.0, rot_deg, 0.0))
		elif kind == "cable_drums":
			var c_base := KIT.M.box(item_node, "CablePad_%d" % idx, Vector3(rect.size.x, 0.10, rect.size.y), Vector3(c.x, 0.05, c.y), mats.trench_steel)
			c_base.rotation.y = deg_to_rad(rot_deg)
			for s_off: float in [-0.24, 0.24]:
				var d_pos := Vector3(c.x, 0.10 + (height - 0.10) * 0.5, c.y + s_off * rect.size.y) if rect.size.y >= rect.size.x else Vector3(c.x + s_off * rect.size.x, 0.10 + (height - 0.10) * 0.5, c.y)
				fittings.fit(item_node, QUAT_DIR + "Prop_Cable_3.scn", d_pos, Vector3(rect.size.x * 0.72, height - 0.10, rect.size.y * 0.44), Vector3(0.0, rot_deg, 0.0))
		elif kind == "pipe_rack":
			var yaw := 90.0 if rect.size.y > rect.size.x else 0.0
			fittings.pipe_bank(item_node, Vector3(c.x, 0.0, c.y), maxf(rect.size.x, rect.size.y), minf(rect.size.x, rect.size.y), height, yaw, true)
		else:
			spawn_functional_cargo_module(item_node, fittings, kind,
				Vector3(c.x, height * 0.5, c.y), Vector3(rect.size.x, height, rect.size.y),
				rot_deg, tint_key if not tint_key.is_empty() else "slate", "ochre", cutout, true, false)
		items.append({
			"idx": idx,
			"rect": rect,
			"center": c,
			"height": height,
			"tint": tint_key if not tint_key.is_empty() else "slate",
			"node": item_node,
			"scorch": null,
			"body": null,
			"exploded": false,
			"locking": false,
			"lock_timer": 0.0,
			"state": "intact",
		})
	return items


static func build_scorch_pad(parent: Node3D, rect: Rect2) -> Node3D:
	var mats := materials()
	var c := rect.get_center()
	var scorch := Node3D.new()
	scorch.name = "ScorchDebris"
	scorch.visible = false
	parent.add_child(scorch)
	KIT.M.box(scorch, "CharPad", Vector3(rect.size.x * 0.96, 0.025, rect.size.y * 0.96),
		Vector3(c.x, 0.015, c.y), mats.trench_rib_dark)
	for side: float in [-1.0, 1.0]:
		var twisted := KIT.M.box(scorch, "TwistedBeam", Vector3(0.18, 0.16, rect.size.y * 0.85),
			Vector3(c.x + side * (rect.size.x * 0.45), 0.08, c.y), mats.trench_steel)
		twisted.rotation = Vector3(side * 0.16, side * 0.28, 0.12)
	return scorch


static func build_freight_dynamic_props(floor_root: Node3D, fittings: RefCounted, cutout: RefCounted) -> Dictionary:
	var mats := materials()
	var dyn_root := Node3D.new()
	dyn_root.name = "FreightDynamicContainers"
	floor_root.add_child(dyn_root)

	var breakables: Array[Dictionary] = []
	for spec: Dictionary in PLAN.FREIGHT_BREAKABLES:
		var rect: Rect2 = spec.rect
		var c := rect.get_center()
		var h := float(spec.height)
		var group := Node3D.new()
		group.name = "Breakable_" + String(spec.id)
		dyn_root.add_child(group)

		var container := spawn_functional_cargo_module(group, fittings, String(spec.variant),
			Vector3(c.x, h * 0.5, c.y), Vector3(rect.size.x, h, rect.size.y),
			float(spec.rot), String(spec.tint), "ochre", cutout, true, false)
		var lock_mark := KIT.M.box(group, "LockWarningFrame",
			Vector3(rect.size.x + 0.28, 0.06, rect.size.y + 0.28), Vector3(c.x, 0.03, c.y), mats.beacon_alert)
		lock_mark.visible = false
		var scorch := build_scorch_pad(group, rect)

		breakables.append({
			"id": String(spec.id),
			"rect": rect,
			"height": h,
			"tint": String(spec.tint),
			"node": container,
			"scorch": scorch,
			"lock_mark": lock_mark,
			"exploded": false,
			"locking": false,
			"lock_timer": 0.0,
			"body": null,
		})

	var deck_drops: Array[Dictionary] = []
	for spec: Dictionary in PLAN.FREIGHT_DROPS:
		var rect: Rect2 = spec.rect
		var c := rect.get_center()
		var h := float(spec.height)
		var group := Node3D.new()
		group.name = "Drop_" + String(spec.id)
		dyn_root.add_child(group)

		var start_y := 10.6
		var container := spawn_functional_cargo_module(group, fittings, String(spec.variant),
			Vector3(c.x, start_y, c.y), Vector3(rect.size.x, h, rect.size.y),
			0.0, String(spec.tint), String(spec.get("top_tint", "ochre")), cutout, true, true)
		var cable := container.get_node_or_null("CraneSpreaderRig") as Node3D
		container.visible = false

		var reticle := build_holographic_warning_zone(group, rect, true)
		var trig: Rect2 = spec.get("trigger_rect", rect.grow(3.5))

		deck_drops.append({
			"id": String(spec.id),
			"rect": rect,
			"height": h,
			"tint": String(spec.tint),
			"trigger_rect": trig,
			"zone_rect": spec.get("zone_rect", rect),
			"eject_dir": spec.get("eject_dir", Vector2.ZERO),
			"delay": float(spec.get("delay", 0.0)),
			"node": container,
			"cable": cable,
			"reticle": reticle,
			"scorch": null,
			"state": "idle",
			"timer": 0.0,
			"fall_y": start_y,
			"fall_vel": 0.0,
			"exploded": false,
			"locking": false,
			"lock_timer": 0.0,
			"body": null,
		})

	var fractures: Array[Dictionary] = []
	for spec: Dictionary in PLAN.FREIGHT_FRACTURES:
		var zone_r: Rect2 = spec.rect
		var cut_r: Rect2 = spec.get("cutout_rect", zone_r)
		var cc := cut_r.get_center()
		var group := Node3D.new()
		group.name = "Fracture_" + String(spec.id)
		dyn_root.add_child(group)

		# Intact collapsible grated deck panel (sits perfectly flush at y=0 looking identical to walkable floor)
		var slab := Node3D.new()
		slab.name = "BreakawayDeckSlab"
		slab.position = Vector3(cc.x, 0.0, cc.y)
		group.add_child(slab)
		var hx := cut_r.size.x * 0.5
		var hz := cut_r.size.y * 0.5
		var slab_mat := make_grate_material(false, cut_r.size, 0.32)
		var m_slab := WAREHOUSE.MeshBuilder.new()
		m_slab.quad(slab_mat, Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz), Vector3.UP)
		for sz_s: float in [-1.0, 1.0]:
			m_slab.box(mats.trench_steel, Vector3(0.0, -0.11, sz_s * (hz - 0.05)), Vector3(cut_r.size.x, 0.22, 0.10))
		for sx_s: float in [-1.0, 1.0]:
			m_slab.box(mats.trench_steel, Vector3(sx_s * (hx - 0.05), -0.11, 0.0), Vector3(0.10, 0.22, cut_r.size.y))
		var slab_mesh := MeshInstance3D.new()
		slab_mesh.name = "SlabMesh"
		slab_mesh.mesh = m_slab.bake()
		slab_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		slab.add_child(slab_mesh)
		if bool(spec.get("has_belt", false)):
			var belt_m := build_conveyor_assembly(slab, PLAN.BELT, 0.78, true)
			belt_m.position = Vector3(-cc.x, 0.0, -cc.y)
		if bool(spec.get("has_roller", false)):
			var roll_m := build_conveyor_assembly(slab, PLAN.ROLLER, 0.68, false)
			roll_m.position = Vector3(-cc.x, 0.0, -cc.y)

		# Severed pit rim (bent girder stubs + charred H06 steel bridge girders, revealed on missile impact)
		var rim := Node3D.new()
		rim.name = "ShatteredPitRim"
		rim.visible = false
		group.add_child(rim)
		var m_rim := WAREHOUSE.MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(spec.id)
		var edge_teeth := clampi(roundi(maxf(cut_r.size.x, cut_r.size.y) / 1.4), 3, 10)
		for ti in edge_teeth:
			var t := (float(ti) + 0.5) / float(edge_teeth)
			var rx := lerpf(cut_r.position.x + 0.25, cut_r.end.x - 0.25, t)
			var rz := lerpf(cut_r.position.y + 0.25, cut_r.end.y - 0.25, t)
			for side_z: float in [cut_r.position.y + 0.12, cut_r.end.y - 0.12]:
				m_rim.box(mats.trench_rib_dark, Vector3(rx, -0.14, side_z), Vector3(0.16, 0.14, rng.randf_range(0.35, 0.65)))
			for side_x: float in [cut_r.position.x + 0.12, cut_r.end.x - 0.12]:
				m_rim.box(mats.trench_rib_dark, Vector3(side_x, -0.14, rz), Vector3(rng.randf_range(0.35, 0.65), 0.14, 0.16))
		for gx: float in spec.get("girders_x", []):
			m_rim.box(mats.trench_steel, Vector3(gx, -0.16, cc.y), Vector3(0.28, 0.28, cut_r.size.y + 0.15))
		for gz: float in spec.get("girders_z", []):
			m_rim.box(mats.trench_steel, Vector3(cc.x, -0.16, gz), Vector3(cut_r.size.x + 0.15, 0.28, 0.28))
		var rim_mesh := MeshInstance3D.new()
		rim_mesh.name = "ShatteredSteel"
		rim_mesh.mesh = m_rim.bake()
		rim.add_child(rim_mesh)

		var holo := build_holographic_warning_zone(group, cut_r, false)

		fractures.append({
			"id": String(spec.id),
			"rect": zone_r,
			"cutout_rect": cut_r,
			"zone_rect": zone_r,
			"trigger_rect": spec.trigger_rect,
			"eject_dir": spec.get("eject_dir", Vector2.ZERO),
			"twin_eject": bool(spec.get("twin_eject", false)),
			"missile_count": int(spec.get("missiles", 1)),
			"slab": slab,
			"rim": rim,
			"holo": holo,
			"missiles": [],
			"state": "intact",
			"timer": 0.0,
			"fall_y": 0.0,
			"fall_vel": 0.0,
			"tilt_vel": Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.55, 0.55)),
			"body": null,
		})

	var chasm_drops: Array[Dictionary] = []
	for idx in PLAN.FREIGHT_CHASM_DROPS.size():
		var spec: Dictionary = PLAN.FREIGHT_CHASM_DROPS[idx]
		var p3: Vector3 = spec.pos
		var sz: Vector3 = spec.size
		var group := Node3D.new()
		group.name = "ChasmDrop_" + String(spec.id)
		dyn_root.add_child(group)

		var container := spawn_functional_cargo_module(group, fittings, "crane_rack_cargo",
			p3, sz, 0.0, String(spec.tint), "slate", null, false, false)
		KIT.M.box(container, "ChasmBeacon", Vector3(0.18, 0.14, 0.18),
			Vector3(0.0, sz.y * 0.5 + 0.07, 0.0), mats.beacon_amber)
		var cables := Node3D.new()
		cables.name = "HoistCables"
		container.add_child(cables)
		for cx_off: float in [-sz.x * 0.35, sz.x * 0.35]:
			KIT.M.box(cables, "Wire", Vector3(0.045, 9.5, 0.045), Vector3(cx_off, sz.y * 0.5 + 4.75, 0.0), mats.steel_mid)

		chasm_drops.append({
			"id": String(spec.id),
			"min_x": float(spec.min_x),
			"max_x": float(spec.max_x),
			"min_y": float(spec.min_y),
			"max_y": float(spec.max_y),
			"node": container,
			"cables": cables,
			"base_pos": p3,
			"phase": float(idx) * 1.4,
			"state": "hanging",
			"fall_y": p3.y,
			"fall_vel": 0.0,
			"spin": Vector3(0.55 + 0.15 * float(idx), 0.18, 0.42),
		})

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.075
	beam_mesh.bottom_radius = 0.115
	beam_mesh.height = 1.0
	var boss_beam := MeshInstance3D.new()
	boss_beam.name = "BossContainerBlastBeam"
	boss_beam.mesh = beam_mesh
	boss_beam.material_override = mats.beacon_alert
	boss_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boss_beam.visible = false
	dyn_root.add_child(boss_beam)

	return {"breakables": breakables, "deck_drops": deck_drops, "fractures": fractures, "chasm_drops": chasm_drops, "boss_beam": boss_beam}


static func build_conveyor_assembly(floor_root: Node3D, rect: Rect2, height: float, belt_style: bool) -> MeshInstance3D:
	var mats := materials()
	var m := WAREHOUSE.MeshBuilder.new()
	var c := rect.get_center()
	var along_x := rect.size.x > rect.size.y
	m.box(mats.trench_steel, Vector3(c.x, height * 0.42, c.y), Vector3(rect.size.x * 0.96, height * 0.80, rect.size.y * 0.96))
	for side: float in [-1.0, 1.0]:
		if along_x:
			m.box(mats.track_trim, Vector3(c.x, height * 0.86, c.y + side * rect.size.y * 0.46), Vector3(rect.size.x, 0.14, 0.09))
			m.box(mats.safety_yellow, Vector3(c.x, height * 0.88, c.y + side * rect.size.y * 0.51), Vector3(rect.size.x * 0.92, 0.05, 0.03))
		else:
			m.box(mats.track_trim, Vector3(c.x + side * rect.size.x * 0.46, height * 0.86, c.y), Vector3(0.09, 0.14, rect.size.y))
			m.box(mats.safety_yellow, Vector3(c.x + side * rect.size.x * 0.51, height * 0.88, c.y), Vector3(0.03, 0.05, rect.size.y * 0.92))
	if belt_style:
		m.box(mats.belt_tread, Vector3(c.x, height - 0.04, c.y), Vector3(rect.size.x * 0.84, 0.08, rect.size.y * 0.94))
		m.box(mats.buttress_red, Vector3(rect.position.x + 0.18, height * 0.52, c.y), Vector3(0.26, 0.34, rect.size.y * 1.04))
		m.box(mats.beacon_amber, Vector3(rect.position.x + 0.04, height * 0.64, c.y), Vector3(0.04, 0.08, 0.24))
	else:
		var count := maxi(4, roundi((rect.size.x if along_x else rect.size.y) / 0.42))
		for i in count:
			var t := (float(i) + 0.5) / float(count)
			if along_x:
				var rx := lerpf(rect.position.x, rect.end.x, t)
				m.box(mats.steel_bright if i % 2 == 0 else mats.steel_mid, Vector3(rx, height - 0.03, c.y), Vector3(0.14, 0.08, rect.size.y * 0.88))
			else:
				var rz := lerpf(rect.position.y, rect.end.y, t)
				m.box(mats.steel_bright if i % 2 == 0 else mats.steel_mid, Vector3(c.x, height - 0.03, rz), Vector3(rect.size.x * 0.88, 0.08, 0.14))
	var node := MeshInstance3D.new()
	node.name = "TransferBeltAssembly" if belt_style else "RollerConveyorAssembly"
	node.mesh = m.bake()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	floor_root.add_child(node)
	return node


static func build_freight_cage(floor_root: Node3D, key: String, rect: Rect2, height: float, cutout: RefCounted) -> void:
	var mats := materials()
	var m := WAREHOUSE.MeshBuilder.new()
	var c := rect.get_center()
	m.box(mats.trench_steel, Vector3(c.x, 0.07, c.y), Vector3(rect.size.x, 0.14, rect.size.y))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.box(mats.trench_steel, Vector3(c.x + sx * (rect.size.x * 0.5 - 0.06), height * 0.5, c.y + sz * (rect.size.y * 0.5 - 0.06)), Vector3(0.11, height, 0.11))
	m.box(mats.trench_steel, Vector3(c.x, height - 0.05, c.y), Vector3(rect.size.x, 0.10, rect.size.y))
	m.box(mats.safety_yellow, Vector3(c.x, height - 0.05, rect.end.y + 0.01), Vector3(rect.size.x * 0.96, 0.06, 0.03))
	for sz: float in [-1.0, 1.0]:
		var z := c.y + sz * (rect.size.y * 0.5 - 0.02)
		m.quad(mats.cage_panel, Vector3(rect.position.x, 0.14, z), Vector3(rect.end.x, 0.14, z),
			Vector3(rect.end.x, height - 0.10, z), Vector3(rect.position.x, height - 0.10, z), Vector3(0, 0, sz),
			Vector2(0, 2), Vector2(rect.size.x, 2), Vector2(rect.size.x, 0), Vector2(0, 0))
	for sx: float in [-1.0, 1.0]:
		var x := c.x + sx * (rect.size.x * 0.5 - 0.02)
		m.quad(mats.cage_panel, Vector3(x, 0.14, rect.position.y), Vector3(x, 0.14, rect.end.y),
			Vector3(x, height - 0.10, rect.end.y), Vector3(x, height - 0.10, rect.position.y), Vector3(sx, 0, 0),
			Vector2(0, 2), Vector2(rect.size.y, 2), Vector2(rect.size.y, 0), Vector2(0, 0))
	var frame := MeshInstance3D.new()
	frame.name = "FreightCage_" + key
	frame.mesh = m.bake()
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	floor_root.add_child(frame)
	WAREHOUSE.build_cargo_stack(floor_root, rect.grow(-0.16), 0.14, maxf(0.65, height * 0.72), hash(key), cutout)


static func _build_freight_stencils(wall_root: Node3D, fittings: RefCounted) -> void:
	if fittings == null:
		return
	var placard := StandardMaterial3D.new()
	placard.albedo_color = Color("6b716e")
	placard.roughness = 0.80
	for st: Array in [
		["01", Vector3(23.2, 2.95, 86.14)],
		["02", Vector3(50.8, 2.95, 86.14)],
		["03", Vector3(64.7, 2.95, 26.64)],
	]:
		var at: Vector3 = st[1]
		KIT.M.box(wall_root, "BayPlacard_" + st[0], Vector3(1.15, 0.72, 0.04), at, placard)
		fittings.stencil(wall_root, st[0], at + Vector3(0.0, 0.0, 0.03), 0.54)


static func _finalize_tex(key: String, img: Image) -> ImageTexture:
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _buttress_red_tex() -> ImageTexture:
	if _tex_cache.has("buttress_red"):
		return _tex_cache["buttress_red"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var red := Color("7d231f")
	var dark := Color("361412")
	var primer := Color("484d50")
	var yellow := Color("b6861e")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4603
	for y in s:
		for x in s:
			var edge := x < 12 or x >= s - 12 or y < 8 or y >= s - 8
			var c := red
			if edge:
				c = dark.lerp(primer, 0.35)
			if y >= 14 and y <= 28 and x >= 18 and x <= s - 18:
				var diag := int(floor(float(x + y) / 14.0)) % 2
				c = yellow if diag == 0 else Color("1c1e20")
			if absf(float(x - 64)) < 2.0 and y > 32:
				c = c.darkened(0.28)
			var soot := clampf((float(y) - 82.0) / 46.0, 0.0, 1.0) * 0.45
			c = c.lerp(Color("191a1b"), soot)
			if rng.randf() < 0.04:
				c = c.lerp(primer, 0.48)
			var n := rng.randf_range(-0.04, 0.035)
			img.set_pixel(x, y, Color(clampf(c.r + n, 0.0, 1.0), clampf(c.g + n, 0.0, 1.0), clampf(c.b + n, 0.0, 1.0), 1.0))
	return _finalize_tex("buttress_red", img)


static func _rusted_pipe_tex() -> ImageTexture:
	if _tex_cache.has("rusted_pipe"):
		return _tex_cache["rusted_pipe"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var steel := Color("3e4448")
	var oxide := Color("593624")
	var soot := Color("1c1e20")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4637
	for y in s:
		var ty := float(y) / float(s) * TAU
		for x in s:
			var tx := float(x) / float(s) * TAU
			var mottle := 0.5 + 0.3 * sin(tx * 2.0 + ty) + 0.2 * cos(ty * 3.0 - tx * 2.0)
			var c := steel.lerp(oxide, clampf(mottle, 0.0, 0.85))
			if (x % 32) < 3:
				c = soot
			var wear := rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, Color(clampf(c.r + wear, 0.0, 1.0), clampf(c.g + wear, 0.0, 1.0), clampf(c.b + wear, 0.0, 1.0), 1.0))
	return _finalize_tex("rusted_pipe", img)


static func _belt_tread_tex() -> ImageTexture:
	if _tex_cache.has("belt_tread"):
		return _tex_cache["belt_tread"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4673
	for y in s:
		for x in s:
			var chev := (int(floor((absf(float(x - 64)) + float(y)) / 14.0)) % 2) == 0
			var c := Color("25292d") if chev else Color("171a1d")
			var w := rng.randf_range(-0.025, 0.025)
			img.set_pixel(x, y, Color(clampf(c.r + w, 0.0, 1.0), clampf(c.g + w, 0.0, 1.0), clampf(c.b + w, 0.0, 1.0), 1.0))
	return _finalize_tex("belt_tread", img)


static func _cage_slat_tex() -> ImageTexture:
	if _tex_cache.has("cage_slat"):
		return _tex_cache["cage_slat"]
	var s := 64
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var wire := (x % 8) < 2 or (y % 8) < 2
			img.set_pixel(x, y, Color("5a6268") if wire else Color(0.0, 0.0, 0.0, 0.0))
	return _finalize_tex("cage_slat", img)


## Spawns ballistic corrugated steel & frame shards when H06 blows up a path container.
static func spawn_container_debris(floor_root: Node3D, origin: Vector3, push_dir: Vector2,
		container_size: Vector3, tint_key: String, active_debris: Array[Dictionary], weathered := false) -> void:
	if not is_instance_valid(floor_root):
		return
	var mats := materials()
	var panel_mat: Material
	if weathered:
		panel_mat = _weathered_container_material(tint_key,Vector3(.95,.26,1.18))
	else:
		var steel := StandardMaterial3D.new()
		steel.albedo_color = CONTAINER_TINTS.get(tint_key, Color("6b7680")).darkened(0.28)
		steel.metallic = 0.55
		steel.roughness = 0.52
		panel_mat = steel
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(origin)
	var forward := Vector3(push_dir.x, 0.0, push_dir.y).normalized() if push_dir.length_squared() > 0.001 else Vector3.FORWARD

	for i in 16:
		var is_beam := (i % 4) == 0
		var shard_size := Vector3(rng.randf_range(0.22, 0.42), rng.randf_range(0.14, 0.24), rng.randf_range(0.95, 1.65)) if is_beam else Vector3(rng.randf_range(0.65, 1.35), 0.12, rng.randf_range(0.55, 1.15))
		var offset := Vector3(
			rng.randf_range(-container_size.x * 0.42, container_size.x * 0.42),
			rng.randf_range(0.25, container_size.y * 0.90),
			rng.randf_range(-container_size.z * 0.42, container_size.z * 0.42)
		)
		var shard := KIT.M.box(floor_root, "BlastShard_%d" % i, shard_size, origin + offset, mats.safety_yellow if i % 5 == 0 else (mats.trench_steel if is_beam else panel_mat))
		shard.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, TAU), rng.randf_range(-0.6, 0.6))
		var out := (Vector3(offset.x, 0.0, offset.z).normalized() + forward * 0.85).normalized()
		var speed := rng.randf_range(5.5, 12.5)
		active_debris.append({
			"node": shard,
			"vel": Vector3(out.x * speed, rng.randf_range(4.8, 10.2), out.z * speed),
			"spin": Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-5.0, 5.0), rng.randf_range(-6.0, 6.0)),
			"age": 0.0,
			"settled": false,
		})


static func tick_container_debris(delta: float, active_debris: Array[Dictionary], deck := Rect2()) -> void:
	for idx in range(active_debris.size() - 1, -1, -1):
		var d: Dictionary = active_debris[idx]
		var node := d.node as Node3D
		d.age = float(d.age) + delta
		if not is_instance_valid(node) or float(d.age) > 5.5:
			if is_instance_valid(node):
				node.queue_free()
			active_debris.remove_at(idx)
			continue
		if d.settled:
			if float(d.age) > 4.2:
				var fade := clampf(1.0 - (float(d.age) - 4.2) / 1.3, 0.02, 1.0)
				node.scale = Vector3.ONE * fade
			continue
		var vel: Vector3 = d.vel
		vel.y -= 24.0 * delta
		node.position += vel * delta
		node.rotation += Vector3(d.spin) * delta
		if node.position.y <= 0.12 and vel.y < 0.0:
			var p2 := Vector2(node.position.x, node.position.z)
			var over_deck := deck.has_point(p2) if deck.has_area() else PLAN.visit_contains(PLAN.Visit.FREIGHT,p2,true)
			if over_deck:
				node.position.y = 0.12
				vel.y = -vel.y * 0.25
				vel.x *= 0.45
				vel.z *= 0.45
				if absf(vel.y) < 1.1:
					vel = Vector3.ZERO
					d.settled = true
		d.vel = vel


## Builds the H06 Boss real shadow-casting overhead floodlight projected from Boss head turret.
static func build_h06_searchlight(lights_root: Node3D) -> Dictionary:
	var rig := Node3D.new()
	rig.name = "H06PursuitSearchlightRig"
	rig.visible = false
	lights_root.add_child(rig)

	# Genuine shadow-enabled wide SpotLight3D positioned atop Boss's head so containers/pillars/walls occlude it cleanly.
	var spot := SpotLight3D.new()
	spot.name = "H06PursuitSpotlight"
	spot.light_color = Color("f2f8ff")
	spot.light_energy = 32.0
	spot.spot_range = 34.0
	spot.spot_angle = 52.0
	spot.spot_attenuation = 0.72
	spot.spot_angle_attenuation = 1.65
	spot.shadow_enabled = true
	spot.shadow_reverse_cull_face = true
	spot.shadow_bias = 0.025
	spot.shadow_normal_bias = 0.05
	spot.shadow_blur = 0.35
	spot.light_cull_mask = 15
	rig.add_child(spot)

	var bulb := MeshInstance3D.new()
	bulb.name = "HeadSensorLamp"
	var bm := SphereMesh.new()
	bm.radius = 0.09
	bm.height = 0.18
	bm.radial_segments = 10
	bm.rings = 6
	bulb.mesh = bm
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color("f2f8ff")
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color("e2f2ff")
	bulb_mat.emission_energy_multiplier = 5.0
	bulb.material_override = bulb_mat
	rig.add_child(bulb)

	return {
		"root": rig,
		"spot": spot,
		"bulb": bulb,
		"bulb_mat": bulb_mat,
	}
