extends RefCounted
## High-bay industrial warehouse kit for Chapter 1-2 (Storage Rooms):
## Giant multi-tier pallet racks, caged IBC totes, dark military cases,
## olive tactical crates, corrugated shutters, exhaust turbines, overhead gantries,
## floor zebra lanes, and animated west roller shutter bays.

const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const METAL_NOR := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_NormalGL.png"
const METAL_ROUGH := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Roughness.png"
const IRON_DIFF := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png"
const IRON_NOR := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png"
const IRON_ROUGH := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png"
const WOOD_DIFF := "res://art/Dream/ReceptionLobby/walnut_veneer/albedo.jpg"
const WOOD_NOR := "res://art/Dream/ReceptionLobby/walnut_veneer/normal.jpg"
const WOOD_ROUGH := "res://art/Dream/ReceptionLobby/walnut_veneer/roughness.jpg"

static var _rack_mesh_cache: Dictionary = {}
static var _stack_mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


class MeshBuilder extends RefCounted:
	var surfaces: Dictionary = {}

	func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
			uva := Vector2.INF, uvb := Vector2.INF, uvc := Vector2.INF, uvd := Vector2.INF) -> void:
		_tri(mat, a, b, c, outward, uva, uvb, uvc)
		_tri(mat, a, c, d, outward, uva, uvc, uvd)

	func _tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, outward: Vector3,
			uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
		if (b - a).cross(c - a).length_squared() < 1e-11:
			return
		var n := outward.normalized() if outward.length_squared() > 1e-10 else (b - a).cross(c - a).normalized()
		if (c - a).cross(b - a).dot(n) < 0.0:
			var tmp_p := b; b = c; c = tmp_p
			var tmp_u := uvb; uvb = uvc; uvc = tmp_u
		if not surfaces.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			surfaces[mat] = st
		var tool: SurfaceTool = surfaces[mat]
		var dom := n.abs()
		for v: Array in [[a, uva], [b, uvb], [c, uvc]]:
			var p: Vector3 = v[0]
			var uv: Vector2 = v[1]
			if uv == Vector2.INF:
				if dom.x > maxf(dom.y, dom.z):
					uv = Vector2(p.z, p.y)
				elif dom.y > dom.z:
					uv = Vector2(p.x, p.z)
				else:
					uv = Vector2(p.x, p.y)
			tool.set_normal(n)
			tool.set_uv(uv)
			tool.add_vertex(p)

	func box(mat: Material, center: Vector3, size: Vector3) -> void:
		_emit_box(mat, center, size, false)

	func box_uv(mat: Material, center: Vector3, size: Vector3) -> void:
		_emit_box(mat, center, size, true)

	func cylinder(mat: Material, bottom: Vector3, radius: float, height: float, capped := true) -> void:
		const SIDES := 12
		for i in SIDES:
			var angle := TAU * i / SIDES
			var next_angle := TAU * (i + 1) / SIDES
			var a := bottom + Vector3(cos(angle), 0, sin(angle)) * radius
			var b := bottom + Vector3(cos(next_angle), 0, sin(next_angle)) * radius
			var rise := Vector3.UP * height
			var normal := Vector3(cos((angle + next_angle) * 0.5), 0, sin((angle + next_angle) * 0.5))
			quad(mat, a, b, b + rise, a + rise, normal)
			if capped:
				_tri(mat, bottom, b, a, Vector3.DOWN, Vector2.INF, Vector2.INF, Vector2.INF)
				_tri(mat, bottom + rise, a + rise, b + rise, Vector3.UP, Vector2.INF, Vector2.INF, Vector2.INF)

	func _emit_box(mat: Material, center: Vector3, size: Vector3, unit_uv: bool) -> void:
		var h := size * 0.5
		var p000 := center + Vector3(-h.x, -h.y, -h.z)
		var p100 := center + Vector3(h.x, -h.y, -h.z)
		var p110 := center + Vector3(h.x, h.y, -h.z)
		var p010 := center + Vector3(-h.x, h.y, -h.z)
		var p001 := center + Vector3(-h.x, -h.y, h.z)
		var p101 := center + Vector3(h.x, -h.y, h.z)
		var p111 := center + Vector3(h.x, h.y, h.z)
		var p011 := center + Vector3(-h.x, h.y, h.z)
		if not unit_uv:
			quad(mat, p010, p110, p111, p011, Vector3.UP)
			quad(mat, p001, p101, p100, p000, Vector3.DOWN)
			quad(mat, p100, p101, p111, p110, Vector3.RIGHT)
			quad(mat, p001, p000, p010, p011, Vector3.LEFT)
			quad(mat, p001, p011, p111, p101, Vector3.BACK)
			quad(mat, p100, p110, p010, p000, Vector3.FORWARD)
			return
		var tl := Vector2(0.0, 0.0)
		var tr := Vector2(1.0, 0.0)
		var br := Vector2(1.0, 1.0)
		var bl := Vector2(0.0, 1.0)
		quad(mat, p010, p110, p111, p011, Vector3.UP, tl, tr, br, bl)
		quad(mat, p001, p101, p100, p000, Vector3.DOWN, tl, tr, br, bl)
		quad(mat, p100, p101, p111, p110, Vector3.RIGHT, bl, br, tr, tl)
		quad(mat, p001, p000, p010, p011, Vector3.LEFT, bl, br, tr, tl)
		quad(mat, p001, p011, p111, p101, Vector3.BACK, bl, tl, tr, br)
		quad(mat, p100, p110, p010, p000, Vector3.FORWARD, bl, tl, tr, br)

	func bar(mat: Material, a: Vector3, b: Vector3, thickness: float) -> void:
		var axis := b - a
		var len_v := axis.length()
		if len_v < 1e-5:
			return
		var dir := axis / len_v
		var ref := Vector3.UP if absf(dir.y) < 0.92 else Vector3.RIGHT
		var u := dir.cross(ref).normalized() * (thickness * 0.5)
		var v := dir.cross(u).normalized() * (thickness * 0.5)
		var c := (a + b) * 0.5
		var pts: Array[Vector3] = [
			a - u - v, a + u - v, a + u + v, a - u + v,
			b - u - v, b + u - v, b + u + v, b - u + v,
		]
		for f: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
			var p0: Vector3 = pts[f[0]]
			var p1: Vector3 = pts[f[1]]
			var p2: Vector3 = pts[f[2]]
			var p3: Vector3 = pts[f[3]]
			var n := ((p0 + p1 + p2 + p3) * 0.25 - c).normalized()
			quad(mat, p0, p1, p2, p3, n)

	func bake() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for st: SurfaceTool in surfaces.values():
			st.generate_tangents()
			st.index()
			st.commit(mesh)
		return mesh


static func materials() -> Dictionary:
	if not _mat_cache.is_empty():
		return _mat_cache
	var met_nor := load(METAL_NOR) as Texture2D
	var met_rough := load(METAL_ROUGH) as Texture2D
	var iron_diff := load(IRON_DIFF) as Texture2D
	var iron_nor := load(IRON_NOR) as Texture2D
	var iron_rough := load(IRON_ROUGH) as Texture2D
	var wood_diff := load(WOOD_DIFF) as Texture2D
	var wood_nor := load(WOOD_NOR) as Texture2D
	var wood_rough := load(WOOD_ROUGH) as Texture2D

	var steel_dark := StandardMaterial3D.new()
	steel_dark.albedo_color = Color("2b3137")
	steel_dark.albedo_texture = iron_diff
	steel_dark.metallic = 0.46
	steel_dark.roughness = 0.56
	steel_dark.normal_texture = met_nor
	steel_dark.normal_scale = 0.42
	steel_dark.roughness_texture = met_rough
	steel_dark.uv1_triplanar = true
	steel_dark.uv1_scale = Vector3(0.55, 0.55, 0.55)

	var steel_mid := StandardMaterial3D.new()
	steel_mid.albedo_color = Color("5d6770")
	steel_mid.albedo_texture = iron_diff
	steel_mid.metallic = 0.65
	steel_mid.roughness = 0.46
	steel_mid.normal_texture = iron_nor
	steel_mid.normal_scale = 0.42
	steel_mid.roughness_texture = iron_rough
	steel_mid.uv1_triplanar = true
	steel_mid.uv1_scale = Vector3(0.75, 0.75, 0.75)

	var steel_bright := StandardMaterial3D.new()
	steel_bright.albedo_color = Color("99a3ab")
	steel_bright.albedo_texture = iron_diff
	steel_bright.metallic = 0.80
	steel_bright.roughness = 0.36
	steel_bright.normal_texture = iron_nor
	steel_bright.normal_scale = 0.35
	steel_bright.roughness_texture = iron_rough
	steel_bright.uv1_triplanar = true
	steel_bright.uv1_scale = Vector3(0.95, 0.95, 0.95)

	var safety_yellow := StandardMaterial3D.new()
	safety_yellow.albedo_texture = _scuffed_paint_tex("paint_yellow", Color("c99626"), Color("6c5218"), 4301)
	safety_yellow.albedo_color = Color.WHITE
	safety_yellow.metallic = 0.14
	safety_yellow.roughness = 0.64
	safety_yellow.normal_texture = met_nor
	safety_yellow.normal_scale = 0.32
	safety_yellow.roughness_texture = met_rough
	safety_yellow.uv1_triplanar = true
	safety_yellow.uv1_scale = Vector3(0.85, 0.85, 0.85)
	safety_yellow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var rack_orange := StandardMaterial3D.new()
	rack_orange.albedo_texture = _scuffed_paint_tex("paint_orange", Color("af5820"), Color("5a2e16"), 4307)
	rack_orange.albedo_color = Color.WHITE
	rack_orange.metallic = 0.18
	rack_orange.roughness = 0.62
	rack_orange.normal_texture = met_nor
	rack_orange.normal_scale = 0.32
	rack_orange.roughness_texture = met_rough
	rack_orange.uv1_triplanar = true
	rack_orange.uv1_scale = Vector3(0.75, 0.75, 0.75)
	rack_orange.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var dark_crate := StandardMaterial3D.new()
	dark_crate.albedo_texture = _crate_panel_tex("dark_crate", Color("262c33"), Color("171b20"), Color("4a5460"), true)
	dark_crate.albedo_color = Color.WHITE
	dark_crate.metallic = 0.12
	dark_crate.roughness = 0.70
	dark_crate.normal_texture = met_nor
	dark_crate.normal_scale = 0.38
	dark_crate.roughness_texture = met_rough
	dark_crate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var olive_crate := StandardMaterial3D.new()
	olive_crate.albedo_texture = _crate_panel_tex("olive_crate", Color("45563e"), Color("283324"), Color("9ca06a"), false)
	olive_crate.albedo_color = Color.WHITE
	olive_crate.metallic = 0.08
	olive_crate.roughness = 0.74
	olive_crate.normal_texture = met_nor
	olive_crate.normal_scale = 0.34
	olive_crate.roughness_texture = met_rough
	olive_crate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var tan_carton := StandardMaterial3D.new()
	tan_carton.albedo_texture = _carton_tex()
	tan_carton.albedo_color = Color.WHITE
	tan_carton.metallic = 0.0
	tan_carton.roughness = 0.90
	tan_carton.normal_texture = iron_nor
	tan_carton.normal_scale = 0.18
	tan_carton.roughness_texture = iron_rough
	tan_carton.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("9c7d58")
	timber.albedo_texture = wood_diff
	timber.metallic = 0.0
	timber.roughness = 0.88
	timber.normal_texture = wood_nor
	timber.normal_scale = 0.28
	timber.roughness_texture = wood_rough
	timber.uv1_triplanar = true
	timber.uv1_scale = Vector3(1.5, 1.5, 1.5)

	var tote_white := StandardMaterial3D.new()
	tote_white.albedo_texture = _tote_tex()
	tote_white.albedo_color = Color.WHITE
	tote_white.metallic = 0.04
	tote_white.roughness = 0.48
	tote_white.roughness_texture = met_rough
	tote_white.normal_texture = met_nor
	tote_white.normal_scale = 0.16
	tote_white.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var hazard := StandardMaterial3D.new()
	hazard.albedo_texture = _hazard_tex()
	hazard.roughness = 0.76
	hazard.roughness_texture = met_rough
	hazard.metallic = 0.06
	hazard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var stripe_white := StandardMaterial3D.new()
	stripe_white.albedo_texture = _chipped_paint_tex()
	stripe_white.albedo_color = Color("a6afb4")
	stripe_white.roughness = 0.92
	stripe_white.roughness_texture = iron_rough
	stripe_white.normal_texture = met_nor
	stripe_white.normal_scale = 0.24
	stripe_white.metallic = 0.02
	stripe_white.uv1_triplanar = true
	stripe_white.uv1_scale = Vector3(0.70, 0.70, 0.70)
	stripe_white.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var corrugated := StandardMaterial3D.new()
	corrugated.albedo_texture = _corrugated_tex()
	corrugated.albedo_color = Color("7b858d")
	corrugated.metallic = 0.56
	corrugated.roughness = 0.58
	corrugated.roughness_texture = iron_rough
	corrugated.normal_texture = met_nor
	corrugated.normal_scale = 0.34
	corrugated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var oil_scuff := StandardMaterial3D.new()
	oil_scuff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	oil_scuff.albedo_color = Color(0.05, 0.06, 0.07, 0.34)
	oil_scuff.roughness = 0.94
	oil_scuff.metallic = 0.04

	var glass_dark := StandardMaterial3D.new()
	glass_dark.albedo_color = Color("111519")
	glass_dark.metallic = 0.15
	glass_dark.roughness = 0.85

	var beacon_red := StandardMaterial3D.new()
	beacon_red.albedo_color = Color("c72c28")
	beacon_red.emission_enabled = true
	beacon_red.emission = Color("e8322c")
	beacon_red.emission_energy_multiplier = 2.0

	var beacon_green := StandardMaterial3D.new()
	beacon_green.albedo_color = Color("28ba6e")
	beacon_green.emission_enabled = true
	beacon_green.emission = Color("32e088")
	beacon_green.emission_energy_multiplier = 2.2

	_mat_cache = {
		"steel_dark": steel_dark,
		"steel_mid": steel_mid,
		"steel_bright": steel_bright,
		"safety_yellow": safety_yellow,
		"rack_orange": rack_orange,
		"dark_crate": dark_crate,
		"olive_crate": olive_crate,
		"tan_carton": tan_carton,
		"timber": timber,
		"tote_white": tote_white,
		"hazard": hazard,
		"stripe_white": stripe_white,
		"corrugated": corrugated,
		"oil_scuff": oil_scuff,
		"dark_cavity": glass_dark,
		"beacon_red": beacon_red,
		"beacon_green": beacon_green,
	}
	return _mat_cache


static func build_stair_bollards(parent: Node3D, positions: Array[Vector2], floor_y: float, base_radius: float) -> MeshInstance3D:
	var mats := materials()
	var paint := (mats.steel_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
	paint.albedo_color = Color("101519")
	paint.metallic = 0.18
	paint.roughness = 0.68
	var builder := MeshBuilder.new()
	for at in positions:
		var foot := Vector3(at.x, floor_y + 0.012, at.y)
		builder.cylinder(paint, foot, base_radius, 0.028)
		# Colour bands are actual sections of the post, with no overlapping surfaces.
		var levels := [0.04, 0.23, 0.38, 0.55, 0.70, 0.87, 1.02, 1.12]
		for band in levels.size() - 1:
			var mat: Material = mats.safety_yellow if band % 2 == 1 else paint
			builder.cylinder(mat, foot + Vector3.UP * levels[band], 0.14, levels[band + 1] - levels[band], false)
		builder.cylinder(paint, foot + Vector3.UP * 1.105, 0.146, 0.035)
		for bolt in 4:
			var angle := PI * 0.25 + bolt * PI * 0.5
			var offset := Vector3(cos(angle), 0, sin(angle)) * (base_radius - 0.028)
			builder.cylinder(mats.steel_mid, foot + offset + Vector3.UP * 0.028, 0.018, 0.015)
		for edge in 8:
			var a := TAU * edge / 8
			var b := TAU * (edge + 1) / 8
			var eye := foot + Vector3.UP * 1.195
			builder.bar(paint, eye + Vector3(cos(a), sin(a), 0) * 0.063,
				eye + Vector3(cos(b), sin(b), 0) * 0.063, 0.018)
	var mesh := MeshInstance3D.new()
	mesh.name = "StairSafetyBollards"
	mesh.mesh = builder.bake()
	parent.add_child(mesh)
	return mesh


static func build_giant_rack(parent: Node3D, rect: Rect2, base_y: float, height: float,
		seed_id: int, cutout: RefCounted) -> MeshInstance3D:
	var along_z := rect.size.y > rect.size.x
	var run_len := maxf(rect.size.x, rect.size.y)
	var depth := minf(rect.size.x, rect.size.y)
	var key := "%.2f_%.2f_%.2f_%d" % [run_len, depth, height, seed_id]
	var mesh: ArrayMesh
	if _rack_mesh_cache.has(key):
		mesh = _rack_mesh_cache[key]
	else:
		mesh = _bake_giant_rack_mesh(run_len, depth, height, seed_id)
		_rack_mesh_cache[key] = mesh

	var node := MeshInstance3D.new()
	node.name = "GiantWarehouseRack_%d" % seed_id
	node.mesh = mesh
	var center := rect.get_center()
	node.position = Vector3(center.x, base_y, center.y)
	if along_z:
		node.rotation.y = PI * 0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	cutout.register_tree(node)
	return node


static func build_cargo_stack(parent: Node3D, rect: Rect2, base_y: float, height: float,
		seed_id: int, cutout: RefCounted) -> MeshInstance3D:
	var along_z := rect.size.y > rect.size.x
	var run_len := maxf(rect.size.x, rect.size.y)
	var depth := minf(rect.size.x, rect.size.y)
	var key := "%.2f_%.2f_%.2f_%d" % [run_len, depth, height, seed_id]
	var mesh: ArrayMesh
	if _stack_mesh_cache.has(key):
		mesh = _stack_mesh_cache[key]
	else:
		mesh = _bake_cargo_stack_mesh(run_len, depth, height, seed_id)
		_stack_mesh_cache[key] = mesh

	var node := MeshInstance3D.new()
	node.name = "WarehouseCargoStack_%d" % seed_id
	node.mesh = mesh
	var center := rect.get_center()
	node.position = Vector3(center.x, base_y, center.y)
	if along_z:
		node.rotation.y = PI * 0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	cutout.register_tree(node)
	return node


static func _bake_giant_rack_mesh(length: float, depth: float, height: float, seed_id: int) -> ArrayMesh:
	var mats := materials()
	var m := MeshBuilder.new()
	var bays := clampi(roundi(length / 2.2), 2, 4)
	var half_x := length * 0.5
	var half_z := depth * 0.5
	var col_w := 0.12

	# Vertical steel H-frame uprights + diagonal end cross-bracing + safety-yellow floor impact guards
	for i in bays + 1:
		var x := -half_x + col_w * 0.5 + (length - col_w) * float(i) / float(bays)
		for sz: float in [-1.0, 1.0]:
			var z := sz * (half_z - col_w * 0.5)
			m.box(mats.steel_dark, Vector3(x, height * 0.5, z), Vector3(col_w, height, col_w))
			# Bolted yellow base impact boot
			m.box(mats.safety_yellow, Vector3(x, 0.24, z), Vector3(col_w + 0.05, 0.48, col_w + 0.05))
			m.box(mats.steel_dark, Vector3(x, 0.02, z), Vector3(col_w + 0.09, 0.04, col_w + 0.09))
		# Transverse frame ties & diagonal truss bracing across depth
		var za := -half_z + col_w * 0.5
		var zb := half_z - col_w * 0.5
		for y_tie: float in [0.22, height * 0.45, height * 0.88]:
			m.box(mats.steel_mid, Vector3(x, y_tie, 0.0), Vector3(0.06, 0.07, depth - col_w))
		m.bar(mats.steel_mid, Vector3(x, 0.25, za), Vector3(x, height * 0.45, zb), 0.045)
		m.bar(mats.steel_mid, Vector3(x, height * 0.45, zb), Vector3(x, height * 0.88, za), 0.045)

	# 3 heavy pallet storage tiers loaded with mixed cargo matching reference concept art
	var tier_heights: Array[float] = [0.20, height * 0.36, height * 0.68]
	var tier_space := height * 0.30
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_id * 7919 + 17)

	for t_idx in tier_heights.size():
		var deck_y := tier_heights[t_idx]
		for sz: float in [-1.0, 1.0]:
			m.box(mats.rack_orange, Vector3(0.0, deck_y - 0.045, sz * (half_z - 0.055)), Vector3(length, 0.11, 0.08))
		# Wire/steel deck grating & center support runners
		m.box(mats.steel_dark, Vector3(0.0, deck_y + 0.015, 0.0), Vector3(length - 0.14, 0.03, depth - 0.12))
		for bar_i in range(1, bays * 3):
			var bx := lerpf(-half_x + 0.18, half_x - 0.18, float(bar_i) / float(bays * 3))
			m.box(mats.steel_mid, Vector3(bx, deck_y + 0.025, 0.0), Vector3(0.05, 0.03, depth - 0.14))

		# Populate each bay on this tier with authentic cargo bundles
		for b_idx in bays:
			var bx0 := -half_x + col_w + (length - 2.0 * col_w) * float(b_idx) / float(bays)
			var bx1 := -half_x + col_w + (length - 2.0 * col_w) * float(b_idx + 1) / float(bays)
			var bay_w := bx1 - bx0 - 0.12
			var mid_x := (bx0 + bx1) * 0.5
			var roll := rng.randf()
			if t_idx == 2 and roll < 0.22:
				# Sparse top bay with smaller loose cartons so silhouette varies naturally
				_add_pallet(m, mats, Vector3(mid_x, deck_y + 0.03, 0.0), Vector2(bay_w * 0.85, depth * 0.82))
				_add_carton_cluster(m, mats, Vector3(mid_x, deck_y + 0.14, 0.0), Vector3(bay_w * 0.78, tier_space * 0.52, depth * 0.76), rng)
				continue
			var slots := 2 if bay_w > 1.75 else 1
			for s in slots:
				var sx := mid_x if slots == 1 else lerpf(bx0 + bay_w * 0.26, bx1 - bay_w * 0.26, float(s))
				var sw := (bay_w / float(slots)) * 0.88
				var sd := depth * 0.84
				var base := Vector3(sx, deck_y + 0.03, rng.randf_range(-0.04, 0.04))
				var kind := rng.randi_range(0, 3)
				if kind == 0:
					_add_ibc_tote(m, mats, base, Vector3(sw, tier_space * 0.78, sd))
				elif kind == 1:
					_add_military_case(m, mats, base, Vector3(sw, tier_space * 0.74, sd), true)
				elif kind == 2:
					_add_olive_crate_pair(m, mats, base, Vector3(sw, tier_space * 0.72, sd))
				else:
					_add_pallet(m, mats, base, Vector2(sw, sd))
					_add_carton_cluster(m, mats, base + Vector3(0, 0.11, 0), Vector3(sw * 0.92, tier_space * 0.64, sd * 0.90), rng)

	return m.bake()


static func _bake_cargo_stack_mesh(length: float, depth: float, height: float, seed_id: int) -> ArrayMesh:
	var mats := materials()
	var m := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_id * 4099 + 93)
	var cols := clampi(roundi(length / 1.45), 1, 4)
	var rows := clampi(roundi(depth / 1.30), 1, 2)
	var cell_x := length / float(cols)
	var cell_z := depth / float(rows)

	for r in rows:
		for c in cols:
			var cx := -length * 0.5 + (float(c) + 0.5) * cell_x
			var cz := -depth * 0.5 + (float(r) + 0.5) * cell_z
			var foot := Vector3(cx, 0.0, cz)
			var w := cell_x * 0.90
			var d := cell_z * 0.88
			var stack_h := height * rng.randf_range(0.76, 1.0)
			var layers := 2 if stack_h > 1.28 else 1
			var kind := (seed_id + c + r * 2) % 3
			var lh := stack_h / float(layers)
			for layer in layers:
				var p := foot + Vector3(rng.randf_range(-0.04, 0.04), float(layer) * lh, rng.randf_range(-0.04, 0.04))
				if kind == 0:
					_add_ibc_tote(m, mats, p, Vector3(w, lh * 0.94, d))
				elif kind == 1:
					_add_military_case(m, mats, p, Vector3(w, lh * 0.94, d), (c + layer) % 2 == 0)
				else:
					_add_olive_crate_pair(m, mats, p, Vector3(w, lh * 0.92, d))
	return m.bake()


static func _add_pallet(m: MeshBuilder, mats: Dictionary, bottom: Vector3, size: Vector2) -> void:
	for sx: float in [-0.38, 0.0, 0.38]:
		m.box(mats.timber, bottom + Vector3(sx * size.x, 0.045, 0.0), Vector3(0.08, 0.09, size.y))
	for i in 4:
		var tz := lerpf(-0.38, 0.38, float(i) / 3.0) * size.y
		m.box(mats.timber, bottom + Vector3(0.0, 0.10, tz), Vector3(size.x, 0.024, size.y * 0.18))


static func _add_ibc_tote(m: MeshBuilder, mats: Dictionary, bottom: Vector3, size: Vector3) -> void:
	_add_pallet(m, mats, bottom, Vector2(size.x, size.z))
	var tank_h := size.y - 0.12
	var tank_c := bottom + Vector3(0.0, 0.12 + tank_h * 0.5, 0.0)
	# Molded white translucent chemical container + black screw fill cap
	m.box_uv(mats.tote_white, tank_c, Vector3(size.x * 0.88, tank_h * 0.90, size.z * 0.88))
	m.box(mats.steel_dark, bottom + Vector3(0.0, 0.12 + tank_h * 0.92, 0.0), Vector3(size.x * 0.18, 0.04, size.z * 0.18))
	# Signature outer tubular metallic cage rails (top/mid/corner bars)
	var hx := size.x * 0.48
	var hz := size.z * 0.48
	var y0 := bottom.y + 0.12
	var y1 := bottom.y + size.y * 0.96
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.box(mats.steel_bright, Vector3(bottom.x + sx * hx, (y0 + y1) * 0.5, bottom.z + sz * hz), Vector3(0.032, y1 - y0, 0.032))
	for ratio: float in [0.15, 0.52, 0.95]:
		var ry := lerpf(y0, y1, ratio)
		for sz: float in [-1.0, 1.0]:
			m.box(mats.steel_bright, Vector3(bottom.x, ry, bottom.z + sz * hz), Vector3(size.x * 0.96, 0.026, 0.026))
		for sx: float in [-1.0, 1.0]:
			m.box(mats.steel_bright, Vector3(bottom.x + sx * hx, ry, bottom.z), Vector3(0.026, 0.026, size.z * 0.96))


static func _add_military_case(m: MeshBuilder, mats: Dictionary, bottom: Vector3, size: Vector3, add_pallet_base := false) -> void:
	var y_start := bottom.y
	if add_pallet_base:
		_add_pallet(m, mats, bottom, Vector2(size.x, size.z))
		y_start += 0.115
	var h := size.y - (0.115 if add_pallet_base else 0.0)
	var mid := Vector3(bottom.x, y_start + h * 0.5, bottom.z)
	m.box_uv(mats.dark_crate, mid, Vector3(size.x * 0.94, h * 0.88, size.z * 0.94))
	# Chamfered overlapping lid & vertical protective rib ridges
	m.box(mats.steel_dark, Vector3(bottom.x, y_start + h * 0.91, bottom.z), Vector3(size.x * 0.98, h * 0.12, size.z * 0.98))
	for rx: float in [-0.30, 0.0, 0.30]:
		m.box(mats.steel_mid, Vector3(bottom.x + rx * size.x, y_start + h * 0.48, bottom.z), Vector3(0.045, h * 0.72, size.z * 0.97))
	m.box(mats.steel_bright, Vector3(bottom.x, y_start + h * 0.68, bottom.z + size.z * 0.49), Vector3(size.x * 0.18, 0.035, 0.025))


static func _add_olive_crate_pair(m: MeshBuilder, mats: Dictionary, bottom: Vector3, size: Vector3) -> void:
	_add_pallet(m, mats, bottom, Vector2(size.x, size.z))
	var sub_h := (size.y - 0.12) * 0.92
	var cols := 2 if size.x > 0.95 else 1
	for i in cols:
		var ox := 0.0 if cols == 1 else (float(i) - 0.5) * size.x * 0.47
		var cw := (size.x / float(cols)) * 0.88
		m.box_uv(mats.olive_crate, bottom + Vector3(ox, 0.12 + sub_h * 0.5, 0.0), Vector3(cw, sub_h, size.z * 0.86))
		m.box(mats.steel_dark, bottom + Vector3(ox, 0.12 + sub_h * 0.90, 0.0), Vector3(cw * 1.03, sub_h * 0.14, size.z * 0.89))
		m.box(mats.safety_yellow, bottom + Vector3(ox, 0.12 + sub_h * 0.52, size.z * 0.44), Vector3(cw * 0.36, 0.04, 0.02))


static func _add_carton_cluster(m: MeshBuilder, mats: Dictionary, bottom: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	for sx: float in [-0.24, 0.24]:
		for sz: float in [-0.22, 0.22]:
			if rng.randf() < 0.20:
				continue
			var h := size.y * rng.randf_range(0.65, 1.0)
			m.box_uv(mats.tan_carton, bottom + Vector3(sx * size.x, h * 0.5, sz * size.z),
				Vector3(size.x * 0.44, h, size.z * 0.42))


## Builds one giant left-wall (West x=-46) animated corrugated roller shutter door + black-faded depth pocket & top_black cap.
static func build_west_shutter_bay(floor_root: Node3D, wall_root: Node3D, floor_y: float,
		key: String, z_center: float, width: float, cutout: RefCounted, wall_mat: Material, floor_mat: Material) -> Dictionary:
	var mats := materials()
	var pocket_x0 := -49.2
	var pocket_x1 := -46.0
	var pocket_len := pocket_x1 - pocket_x0
	var h := 4.20

	# Recessed pocket floor fading smoothly to black depth by x=-48.1
	var pocket_floor := KIT.M.box(floor_root, "WestBayFloor_" + key, Vector3(pocket_len, 0.22, width + 0.20),
		Vector3((pocket_x0 + pocket_x1) * 0.5, floor_y - 0.11, z_center), floor_mat)
	pocket_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Recessed pocket enclosure capped flush at h=4.20 with top_black + black interior abyss soffit/backplane
	var m_pocket := MeshBuilder.new()
	var black_cap: Material = cutout.top_black
	# Solid unshaded pitch-black back wall x=-49.2 & full top_black roof slab sealing alcove from above
	_wall_seg_x(m_pocket, black_cap, black_cap, Vector3(pocket_x0 - 0.12, floor_y, z_center), Vector3(0.24, h, width + 0.48))
	m_pocket.box(black_cap, Vector3((pocket_x0 + pocket_x1) * 0.5 - 0.06, floor_y + (h + 3.05) * 0.5, z_center), Vector3(pocket_len + 0.26, h - 3.05, width + 0.48))
	for sz: float in [-1.0, 1.0]:
		var wz := z_center + sz * (width * 0.5 + 0.12)
		_wall_seg_x(m_pocket, black_cap, wall_mat, Vector3((pocket_x0 + pocket_x1) * 0.5, floor_y, wz), Vector3(pocket_len, h, 0.24))
	# Structural dark steel portal jamb columns, side guide channels & top_black-capped shutter drum hood
	for sz: float in [-1.0, 1.0]:
		var jz := z_center + sz * (width * 0.5 + 0.12)
		_wall_seg_x(m_pocket, black_cap, mats.steel_dark, Vector3(pocket_x1 + 0.08, floor_y, jz), Vector3(0.32, 3.25, 0.28))
		m_pocket.box(mats.safety_yellow, Vector3(pocket_x1 + 0.18, floor_y + 0.55, jz), Vector3(0.14, 1.10, 0.16))
	_wall_seg_x(m_pocket, black_cap, mats.steel_dark, Vector3(pocket_x1 + 0.10, floor_y + 2.77, z_center), Vector3(0.42, 0.56, width + 0.48))
	m_pocket.box(mats.safety_yellow, Vector3(pocket_x1 + 0.32, floor_y + 2.86, z_center), Vector3(0.05, 0.14, width + 0.36))
	# Striped yellow-black floor threshold apron extending inside warehouse floor
	m_pocket.quad(mats.hazard,
		Vector3(pocket_x1 - 0.15, floor_y + 0.012, z_center - width * 0.52),
		Vector3(pocket_x1 + 1.45, floor_y + 0.012, z_center - width * 0.52),
		Vector3(pocket_x1 + 1.45, floor_y + 0.012, z_center + width * 0.52),
		Vector3(pocket_x1 - 0.15, floor_y + 0.012, z_center + width * 0.52),
		Vector3.UP, Vector2(0, 0), Vector2(2, 0), Vector2(2, 5), Vector2(0, 5))

	var frame_node := MeshInstance3D.new()
	frame_node.name = "WestShutterBay_" + key
	frame_node.mesh = m_pocket.bake()
	frame_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	wall_root.add_child(frame_node)

	# Moving corrugated metal shutter curtain leaf
	var leaf_pivot := Node3D.new()
	leaf_pivot.name = "WestShutterCurtain_" + key
	leaf_pivot.position = Vector3(pocket_x1 + 0.02, floor_y + 2.74, z_center)
	wall_root.add_child(leaf_pivot)
	var m_leaf := MeshBuilder.new()
	m_leaf.quad(mats.corrugated,
		Vector3(0.05, -2.74, -width * 0.5), Vector3(0.05, -2.74, width * 0.5),
		Vector3(0.05, 0.0, width * 0.5), Vector3(0.05, 0.0, -width * 0.5),
		Vector3.RIGHT, Vector2(0, 4), Vector2(4, 4), Vector2(4, 0), Vector2(0, 0))
	m_leaf.box(mats.steel_mid, Vector3(0.0, -1.37, 0.0), Vector3(0.09, 2.74, width))
	m_leaf.box(mats.safety_yellow, Vector3(0.04, -2.66, 0.0), Vector3(0.11, 0.14, width + 0.04))
	var leaf_mesh := MeshInstance3D.new()
	leaf_mesh.name = "ShutterSlats"
	leaf_mesh.mesh = m_leaf.bake()
	leaf_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	leaf_pivot.add_child(leaf_mesh)
	cutout.register_tree(leaf_mesh,true)

	# Beacon lamp above shutter (turns red -> green when opened)
	var beacon := MeshInstance3D.new()
	beacon.name = "ShutterBeacon_" + key
	var box_m := BoxMesh.new()
	box_m.size = Vector3(0.12, 0.16, 0.34)
	beacon.mesh = box_m
	beacon.material_override = mats.beacon_red
	beacon.position = Vector3(pocket_x1 + 0.34, floor_y + 3.12, z_center)
	wall_root.add_child(beacon)

	return {
		"key": key,
		"curtain": leaf_pivot,
		"beacon": beacon,
		"open": false,
		"z_center": z_center,
		"width": width,
		"x": pocket_x1,
	}


static func _wall_seg_x(m: MeshBuilder, top_mat: Material, side_mat: Material, base_center: Vector3, size: Vector3) -> void:
	var h := size.y
	var c := base_center + Vector3(0, h * 0.5, 0)
	var hx := size.x * 0.5
	var hy := h * 0.5
	var hz := size.z * 0.5
	var p000 := c + Vector3(-hx, -hy, -hz)
	var p100 := c + Vector3(hx, -hy, -hz)
	var p110 := c + Vector3(hx, hy, -hz)
	var p010 := c + Vector3(-hx, hy, -hz)
	var p001 := c + Vector3(-hx, -hy, hz)
	var p101 := c + Vector3(hx, -hy, hz)
	var p111 := c + Vector3(hx, hy, hz)
	var p011 := c + Vector3(-hx, hy, hz)
	m.quad(top_mat, p010, p110, p111, p011, Vector3.UP)
	m.quad(side_mat, p100, p101, p111, p110, Vector3.RIGHT)
	m.quad(side_mat, p001, p000, p010, p011, Vector3.LEFT)
	m.quad(side_mat, p001, p011, p111, p101, Vector3.BACK)
	m.quad(side_mat, p100, p110, p010, p000, Vector3.FORWARD)


## Dresses the entire 1-2 warehouse shell: structural columns, high-bay shutters, exhaust turbines,
## overhead perimeter crane gantry, white zebra crosswalk lanes, and right-corner tank silo.
static func dress_warehouse_shell(floor_root: Node3D, wall_root: Node3D, fittings: RefCounted,
		cutout: RefCounted, upper_y: float) -> void:
	var mats := materials()
	var m_floor := MeshBuilder.new()
	var m_arch := MeshBuilder.new()

	var exclusions: Array[Rect2] = []
	for g_var: Variant in fittings.SERVICE_GRATES.values():
		if g_var is Rect2:
			exclusions.append((g_var as Rect2).grow(0.20))

	# Crisp painted white zebra crosswalk stripes strictly off all floor exhaust grates & clear of yellow rails
	for zebra: Array in [
		[Vector2(-11.4, -30.5), Vector2(-8.4, -30.5), 1.45, false, upper_y],
		[Vector2(-22.2, -30.5), Vector2(-15.8, -30.5), 1.45, false, upper_y],
		[Vector2(-38.3, -25.4), Vector2(-38.3, -19.6), 1.45, true, upper_y],
		[Vector2(-35.4, -14.2), Vector2(-25.2, -14.2), 1.65, false, upper_y],
		[Vector2(-15.0, -24.5), Vector2(-15.0, -17.5), 1.45, true, upper_y],
		[Vector2(-34.8, -5.2), Vector2(-24.8, -5.2), 1.45, false, upper_y],
		[Vector2(-42.5, 4.4), Vector2(-35.2, 4.4), 1.8, false, 0.0],
	]:
		exclusions.append(_add_zebra_lane(m_floor, mats.stripe_white, zebra[0], zebra[1], float(zebra[2]), bool(zebra[3]), float(zebra[4])))

	# Paired metallic twin guide tracks flush on clean concrete lanes (never overlapping floor grates or runway rails)
	for dx: float in [-0.20, 0.20]:
		for track_v: Array in [[-43.4 + dx, upper_y, -28.8, 5.6], [-43.4 + dx, upper_y, -14.8, 5.6]]:
			m_floor.box(mats.steel_mid, Vector3(float(track_v[0]), float(track_v[1]) + 0.008, float(track_v[2])), Vector3(0.11, 0.016, float(track_v[3])))
			exclusions.append(Rect2(float(track_v[0]) - 0.055, float(track_v[2]) - float(track_v[3]) * 0.5, 0.11, float(track_v[3])).grow(0.14))
	for dz: float in [-0.22, 0.22]:
		for track_h: Array in [[-31.2, upper_y, -33.0 + dz, 8.6], [-29.8, upper_y, -22.6 + dz, 12.0], [-18.6, upper_y, -14.8 + dz, 4.8], [-38.5, 0.0, 3.0 + dz, 7.0]]:
			m_floor.box(mats.steel_mid, Vector3(float(track_h[0]), float(track_h[1]) + 0.008, float(track_h[2])), Vector3(float(track_h[3]), 0.016, 0.11))
			exclusions.append(Rect2(float(track_h[0]) - float(track_h[3]) * 0.5, float(track_h[2]) - 0.055, float(track_h[3]), 0.11).grow(0.14))

	# Yellow floor corner L-brackets around East Pump Silo equipment pad (free of grates and zebra lanes)
	_add_floor_corner_brackets(m_floor, mats.safety_yellow, Vector2(-13.85, -13.6), Vector2(2.30, 2.30), upper_y)
	# Yellow forklift ramming runway warning lines & directional chevrons around closed warehouse loop (clipped against all other floor layers)
	_build_forklift_runway_markings(m_floor, mats.safety_yellow, mats.hazard, upper_y, exclusions)

	# Heavy structural steel perimeter I-beam columns with top_black wall caps aligned at 4.20 m
	var top_black: Material = cutout.top_black
	for x_col: float in [-45.75, -38.8, -32.2, -25.8, -20.2, -14.5, -9.0, -2.5, 4.75]:
		_wall_seg_x(m_arch, top_black, mats.steel_dark, Vector3(x_col, upper_y, -36.82), Vector3(0.38, 4.20, 0.34))
		m_arch.box(mats.safety_yellow, Vector3(x_col, upper_y + 0.45, -36.75), Vector3(0.42, 0.90, 0.38))

	# West/Left warehouse wall columns (top_black capped), safety bollards & horizontal pipe runs
	for z_col: float in [-34.2, -25.4, -18.8, -10.8, -4.4]:
		_wall_seg_x(m_arch, top_black, mats.steel_dark, Vector3(-45.82, upper_y, z_col), Vector3(0.34, 4.20, 0.38))
		m_arch.box(mats.safety_yellow, Vector3(-45.74, upper_y + 0.45, z_col), Vector3(0.38, 0.90, 0.42))
	for z_bollard: float in [-31.5, -26.1, -17.6, -12.0]:
		m_arch.box(mats.steel_dark, Vector3(-45.40, upper_y + 0.50, z_bollard), Vector3(0.24, 1.00, 0.24))
		m_arch.box(mats.safety_yellow, Vector3(-45.40, upper_y + 0.72, z_bollard), Vector3(0.26, 0.46, 0.26))
	for py: float in [2.65, 3.15]:
		m_arch.bar(mats.steel_bright, Vector3(-45.80, upper_y + py, -36.5), Vector3(-45.80, upper_y + py, -3.5), 0.10)

	# Lower Receiving dock West/North structural columns (top_black capped) & shutter bollards
	for z_low: float in [-1.8, 0.4, 6.0, 8.6]:
		_wall_seg_x(m_arch, top_black, mats.steel_dark, Vector3(-45.82, 0.0, z_low), Vector3(0.34, 4.20, 0.38))
		m_arch.box(mats.safety_yellow, Vector3(-45.74, 0.45, z_low), Vector3(0.38, 0.90, 0.42))
	for z_b_low: float in [0.4, 6.0]:
		m_arch.box(mats.steel_dark, Vector3(-45.40, 0.50, z_b_low), Vector3(0.24, 1.00, 0.24))
		m_arch.box(mats.safety_yellow, Vector3(-45.40, 0.72, z_b_low), Vector3(0.26, 0.46, 0.26))
	m_arch.bar(mats.steel_bright, Vector3(-45.80, 2.85, -2.5), Vector3(-45.80, 2.85, 8.8), 0.10)

	# Corrugated high-bay shutter panels along the non-window north wall segments
	for bay_x: float in [-23.4, -18.2, -13.2]:
		var by := upper_y + 2.05
		m_arch.box(mats.steel_dark, Vector3(bay_x, by, -36.86), Vector3(3.6, 3.3, 0.16))
		m_arch.quad(mats.corrugated,
			Vector3(bay_x - 1.65, by - 1.5, -36.76), Vector3(bay_x + 1.65, by - 1.5, -36.76),
			Vector3(bay_x + 1.65, by + 1.5, -36.76), Vector3(bay_x - 1.65, by + 1.5, -36.76),
			Vector3.BACK, Vector2(0, 3), Vector2(3, 3), Vector2(3, 0), Vector2(0, 0))
		m_arch.box(mats.safety_yellow, Vector3(bay_x, upper_y + 3.56, -36.74), Vector3(3.65, 0.12, 0.22))

	# Recessed circular industrial ventilation exhaust turbines mounted high along north wall
	for fan_x: float in [-44.2, -28.6, 2.8]:
		var fy := upper_y + 3.25
		var fz := -36.78
		m_arch.box(mats.steel_mid, Vector3(fan_x, fy, fz), Vector3(1.55, 1.55, 0.16))
		m_arch.box(mats.dark_cavity, Vector3(fan_x, fy, fz + 0.04), Vector3(1.24, 1.24, 0.12))
		for k in 6:
			var a := TAU * float(k) / 6.0
			var p0 := Vector3(fan_x, fy, fz + 0.08)
			var p1 := Vector3(fan_x + cos(a) * 0.56, fy + sin(a) * 0.56, fz + 0.08)
			m_arch.bar(mats.steel_mid, p0, p1, 0.09)
		m_arch.box(mats.steel_dark, Vector3(fan_x, fy, fz + 0.11), Vector3(0.26, 0.26, 0.10))

	# North-bay overhead bridge-crane rail beam (with top_black cap) & suspended cargo hoist carriage
	var rail_y := upper_y + 3.92
	_wall_seg_x(m_arch, top_black, mats.steel_dark, Vector3(-21.0, rail_y - 0.17, -35.3), Vector3(48.0, 0.34, 0.42))
	m_arch.box(mats.rack_orange, Vector3(-21.0, rail_y - 0.12, -35.06), Vector3(48.0, 0.10, 0.12))
	for crane_x: float in [-31.5, -16.5]:
		m_arch.box(mats.steel_mid, Vector3(crane_x, rail_y - 0.36, -35.1), Vector3(2.1, 0.38, 1.15))
		m_arch.box(mats.safety_yellow, Vector3(crane_x, rail_y - 0.52, -35.1), Vector3(1.6, 0.10, 1.22))
		for sx: float in [-0.6, 0.6]:
			m_arch.bar(mats.steel_bright, Vector3(crane_x + sx, rail_y - 0.55, -35.1), Vector3(crane_x + sx, rail_y - 1.25, -35.1), 0.04)
		_add_military_case(m_arch, mats, Vector3(crane_x, rail_y - 1.95, -35.1), Vector3(1.35, 0.72, 0.92), false)

	# Bolted collar rings, east-wall steel I-beam columns (top_black capped) & manifold conduit around East Pump silo
	for z_east: float in [-21.0, -16.2, -10.8, -5.2]:
		_wall_seg_x(m_arch, top_black, mats.steel_dark, Vector3(-12.68, upper_y, z_east), Vector3(0.34, 4.20, 0.38))
		m_arch.box(mats.safety_yellow, Vector3(-12.75, upper_y + 0.45, z_east), Vector3(0.38, 0.90, 0.42))
	for py_east: float in [2.60, 3.15]:
		m_arch.bar(mats.steel_bright, Vector3(-12.70, upper_y + py_east, -22.2), Vector3(-12.70, upper_y + py_east, -3.4), 0.10)
	for ry: float in [0.95, 2.25, 3.55]:
		m_arch.box(mats.steel_dark, Vector3(-13.85, upper_y + ry, -13.6), Vector3(1.58, 0.12, 1.58))
	m_arch.bar(mats.steel_bright, Vector3(-13.05, upper_y + 0.4, -13.6), Vector3(-13.05, upper_y + 3.8, -13.6), 0.12)
	m_arch.bar(mats.safety_yellow, Vector3(-13.85, upper_y + 3.6, -13.6), Vector3(-12.75, upper_y + 3.6, -13.6), 0.10)

	# Continuous bold top_black outer coping parapets framing the entire 1-2 warehouse cut plane
	_build_top_black_shell(m_arch, top_black, upper_y)

	# Floor details mesh (zebra lanes + recessed twin steel guide rails)
	var floor_decals := MeshInstance3D.new()
	floor_decals.name = "WarehouseFloorMarkings"
	floor_decals.mesh = m_floor.bake()
	floor_decals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_root.add_child(floor_decals)

	# Perimeter high-bay architectural structures (north/west/east walls never occlude player from south camera)
	var arch_mesh := MeshInstance3D.new()
	arch_mesh.name = "WarehouseHighBaySuperstructure"
	arch_mesh.mesh = m_arch.bake()
	arch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	wall_root.add_child(arch_mesh)

	# Tall vertical silver-grey pressure tank silo & piping in East Pump corner (like ref image right silo)
	var silo_at := Vector3(-13.85, upper_y + 2.05, -13.6)
	var silo: Node3D = fittings.barrel(wall_root, silo_at, 4.10, 1.48, true, Color("8a969c"), false)
	silo.name = "WarehouseVerticalSilo"
	cutout.register_tree(silo)

	_build_floor_and_wall_weathering(floor_root, wall_root, fittings, upper_y)


static func _add_floor_corner_brackets(m: MeshBuilder, mat: Material, center: Vector2, size: Vector2, floor_y: float) -> void:
	var arm := 0.42
	var thick := 0.09
	var y := floor_y + 0.005
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.box(mat, Vector3(center.x + sx * (hx - arm * 0.5), y, center.y + sz * hz), Vector3(arm, 0.010, thick))
			m.box(mat, Vector3(center.x + sx * hx, y, center.y + sz * (hz - arm * 0.5)), Vector3(thick, 0.010, arm))


static func _build_top_black_shell(m: MeshBuilder, top_black: Material, upper_y: float) -> void:
	var emit_black := func(x0: float, x1: float, z0: float, z1: float, y_bot: float, y_top: float) -> void:
		m.box(top_black, Vector3((x0 + x1) * 0.5, (y_bot + y_top) * 0.5, (z0 + z1) * 0.5),
			Vector3(x1 - x0, y_top - y_bot, z1 - z0))

	const EXT_W := -260.0
	const EXT_E := 180.0
	const EXT_N := -260.0
	const EXT_S := 180.0
	var abyss_bot := -0.40
	var up_bot := upper_y - 0.22
	var up_top := upper_y + 4.20
	var up_cut := upper_y + 0.65
	var lo_top := 4.20
	var lo_cut := 0.65

	# Full exterior top_black shroud matching Prologue 0-3 (covers outside void completely at wall-top / cutaway levels)
	var exterior_slabs: Array[Array] = [
		# North of z=-37: seamless roof apron wrapping cleanly around Window_inspection & Window_calibration
		[EXT_W, EXT_E, EXT_N, -42.42, abyss_bot, up_top],
		[-11.05, 1.05, -42.42, -42.22, abyss_bot, up_top],
		[EXT_W, -42.52, -42.42, -37.00, abyss_bot, up_top],
		[-30.48, -11.02, -42.42, -37.00, abyss_bot, up_top],
		[1.02, EXT_E, -42.42, -37.00, abyss_bot, up_top],
		# Upper Calibration East exterior (x >= +5) & Guard/Pump East perimeter coping wall
		[5.02, EXT_E, -37.00, -24.98, abyss_bot, up_top],
		[-12.48, -11.65, -24.98, -2.90, up_bot, up_top],
		# West Upper exterior (x <= -46, z in [-37, -3]) split cleanly behind & over inspection/archive shutter pockets
		[EXT_W, -49.25, -37.00, -3.00, abyss_bot, up_top],
		[-49.25, -46.02, -37.00, -31.15, abyss_bot, up_top],
		[-49.25, -46.02, -26.45, -17.25, abyss_bot, up_top],
		[-49.25, -46.02, -12.35, -3.00, abyss_bot, up_top],
		[-49.25, -46.02, -31.15, -26.45, upper_y + 3.98, up_top],
		[-49.25, -46.02, -17.25, -12.35, upper_y + 3.98, up_top],
		# Upper South cutaway aprons (Calibration south flanking west_threshold + East of Pump & Stair down to +6.5)
		[-11.65, -7.55, -25.00, -20.50, abyss_bot, up_cut],
		[-3.45, EXT_E, -25.00, -20.50, abyss_bot, up_cut],
		[-7.55, -3.45, -22.48, -20.50, abyss_bot, upper_y],
		[-11.65, EXT_E, -20.50, -3.00, abyss_bot, up_cut],
		[-14.98, EXT_E, -3.00, 6.50, abyss_bot, up_cut],
		# Upper Threshold Pocket roof side coping flanking (-7.5..-3.5, -25..-22.5)
		[-8.25, -7.55, -24.25, -22.50, up_bot, upper_y + 2.45],
		[-3.45, -2.75, -24.25, -22.50, up_bot, upper_y + 2.45],
		# Upper-to-Lower retaining cutaway ledge above Receiving north side
		[-46.02, -22.02, -3.00, -2.25, up_bot, up_cut],
		# West Lower exterior (x <= -46, z in [-3, +9.5]) split around receiving shutter pocket
		[EXT_W, -49.25, -3.00, 9.50, abyss_bot, lo_top],
		[-49.25, -46.02, -3.00, 0.75, abyss_bot, lo_top],
		[-49.25, -46.02, 5.65, 9.50, abyss_bot, lo_top],
		[-49.25, -46.02, 0.75, 5.65, 3.98, lo_top],
		# Receiving-Stair exterior spacer & Lower South / Passage-1 East cutaway aprons
		[-25.00, -22.02, -3.00, -2.00, abyss_bot, up_cut],
		[-25.00, -22.02, -2.00, 6.50, abyss_bot, lo_top],
		[-9.60, EXT_E, 6.50, 9.50, abyss_bot, lo_cut],
		[EXT_W, EXT_E, 9.50, EXT_S, abyss_bot, lo_cut],
	]
	for box_def: Array in exterior_slabs:
		emit_black.call(float(box_def[0]), float(box_def[1]), float(box_def[2]),
			float(box_def[3]), float(box_def[4]), float(box_def[5]))


static func _build_floor_and_wall_weathering(floor_root: Node3D, wall_root: Node3D, fittings: RefCounted, upper_y: float) -> void:
	var kit: KIT = fittings.get("kit") if fittings else null
	if kit != null:
		var decals := Node3D.new()
		decals.name = "WarehouseWeatheringDecals"
		floor_root.add_child(decals)
		var place_decal := func(tag: String, sz: Vector2, pos: Vector3, mat: Material, rot_deg: Vector3) -> void:
			if mat == null:
				return
			var mi := kit.quad(decals, tag, sz, pos, mat, rot_deg)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var idx := 0
		for oil: Array in [
			[Vector2(2.6, 1.9), Vector3(-3.8, upper_y + 0.008, -29.0), 18.0],
			[Vector2(2.8, 2.0), Vector3(-19.5, upper_y + 0.008, -29.8), -24.0],
			[Vector2(2.6, 2.1), Vector3(-38.0, upper_y + 0.008, -29.0), 35.0],
			[Vector2(2.4, 2.0), Vector3(-38.2, upper_y + 0.008, -15.0), -14.0],
			[Vector2(3.0, 2.4), Vector3(-14.2, upper_y + 0.008, -13.9), 12.0],
			[Vector2(2.8, 2.2), Vector3(-38.2, 0.008, 3.4), -28.0],
			[Vector2(2.5, 1.8), Vector3(-29.5, 0.008, 2.8), 22.0],
		]:
			idx += 1
			place_decal.call("WhOil_%02d" % idx, oil[0], oil[1], kit.decal_oil_stain, Vector3(-90.0, oil[2], 0.0))

		idx = 0
		for scuff: Array in [
			[Vector2(3.4, 1.4), Vector3(-8.5, upper_y + 0.010, -31.8), 90.0],
			[Vector2(4.0, 1.5), Vector3(-28.0, upper_y + 0.010, -31.8), 86.0],
			[Vector2(3.6, 1.4), Vector3(-42.8, upper_y + 0.010, -23.0), 4.0],
			[Vector2(3.6, 1.4), Vector3(-42.8, upper_y + 0.010, -9.0), -3.0],
			[Vector2(3.8, 1.4), Vector3(-29.2, upper_y + 0.010, -22.2), 92.0],
			[Vector2(3.6, 1.5), Vector3(-18.2, upper_y + 0.010, -14.8), 78.0],
			[Vector2(3.6, 1.4), Vector3(-34.2, upper_y + 0.010, -6.2), 88.0],
			[Vector2(3.8, 1.4), Vector3(-36.0, 0.010, 4.2), 85.0],
		]:
			idx += 1
			place_decal.call("WhScuff_%02d" % idx, scuff[0], scuff[1], kit.decal_scuff_streak, Vector3(-90.0, scuff[2], 0.0))

		idx = 0
		for crack: Array in [
			[Vector2(2.2, 1.6), Vector3(-10.5, upper_y + 0.007, -26.4), 15.0],
			[Vector2(2.4, 1.7), Vector3(-26.4, upper_y + 0.007, -30.5), -32.0],
			[Vector2(2.2, 1.6), Vector3(-39.6, upper_y + 0.007, -18.2), 52.0],
			[Vector2(2.5, 1.7), Vector3(-19.0, upper_y + 0.007, -12.6), -18.0],
			[Vector2(2.2, 1.6), Vector3(-33.5, 0.007, 1.8), 28.0],
		]:
			idx += 1
			place_decal.call("WhCrack_%02d" % idx, crack[0], crack[1], kit.decal_crack, Vector3(-90.0, crack[2], 0.0))

		idx = 0
		for rust: Array in [
			[Vector2(1.8, 1.8), Vector3(-44.8, upper_y + 0.009, -28.8), 10.0],
			[Vector2(1.8, 1.8), Vector3(-44.8, upper_y + 0.009, -15.2), -20.0],
			[Vector2(2.0, 2.0), Vector3(-13.8, upper_y + 0.009, -14.8), 35.0],
			[Vector2(1.8, 1.8), Vector3(-44.8, 0.009, 3.2), 15.0],
		]:
			idx += 1
			place_decal.call("WhRust_%02d" % idx, rust[0], rust[1], kit.decal_rust_patch, Vector3(-90.0, rust[2], 0.0))

		idx = 0
		for drip: Array in [
			[Vector2(2.4, 2.8), Vector3(-41.6, upper_y + 1.45, -36.88), 0.0],
			[Vector2(2.4, 2.8), Vector3(-29.0, upper_y + 1.45, -36.88), 0.0],
			[Vector2(2.4, 2.8), Vector3(-10.8, upper_y + 1.45, -36.88), 0.0],
			[Vector2(2.4, 2.8), Vector3(0.2, upper_y + 1.45, -36.88), 0.0],
			[Vector2(2.2, 2.8), Vector3(-45.88, upper_y + 1.45, -35.5), 90.0],
			[Vector2(2.2, 2.8), Vector3(-45.88, upper_y + 1.45, -22.1), 90.0],
			[Vector2(2.2, 2.8), Vector3(-45.88, upper_y + 1.45, -7.6), 90.0],
		]:
			idx += 1
			place_decal.call("WhWallDrip_%02d" % idx, drip[0], drip[1], kit.decal_wall_drip, Vector3(0.0, drip[2], 0.0))

	if fittings != null:
		fittings.stencil(wall_root, "01", Vector3(-23.4, upper_y + 3.82, -36.68), 0.44)
		fittings.stencil(wall_root, "02", Vector3(-18.2, upper_y + 3.82, -36.68), 0.44)
		fittings.stencil(wall_root, "03", Vector3(-13.2, upper_y + 3.82, -36.68), 0.44)
		fittings.stencil(wall_root, "04", Vector3(-13.85, upper_y + 2.65, -12.76), 0.48)


static func _add_zebra_lane(m: MeshBuilder, mat: Material, start: Vector2, end: Vector2, width: float, vertical: bool, floor_y: float) -> Rect2:
	var length := start.distance_to(end)
	var count := maxi(3, floori(length / 0.68))
	var sx := width if vertical else 0.36
	var sz := 0.36 if vertical else width
	var lane_rect := Rect2()
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var p := start.lerp(end, t)
		m.box(mat, Vector3(p.x, floor_y + 0.006, p.y), Vector3(sx, 0.012, sz))
		var bar_rect := Rect2(p.x - sx * 0.5, p.y - sz * 0.5, sx, sz)
		lane_rect = bar_rect if i == 0 else lane_rect.merge(bar_rect)
	return lane_rect.grow(0.16)


static func _build_forklift_runway_markings(m: MeshBuilder, yellow_mat: Material, hazard_mat: Material,
		floor_y: float, base_exclusions: Array[Rect2]) -> void:
	const HALF_W := 1.18
	const LINE_W := 0.13
	const MITER := LINE_W * 0.5
	var exclusions: Array[Rect2] = base_exclusions.duplicate()

	# Breakable barrier crash threshold hazard band on concrete either side of the calibration gate
	for hx: float in [-12.20, -12.95]:
		m.box(hazard_mat, Vector3(hx, floor_y + 0.008, -29.65), Vector3(0.30, 0.012, 4.90))
	exclusions.append(Rect2(-13.18, -32.16, 1.22, 5.02))

	# Outer & inner closed-loop runway boundary rails (exact watertight corners, miter-matched)
	for h_rail: Array in [
		# Outer North straight + Entry Spur top rail (continuous to start bay)
		[-38.3 - HALF_W - MITER, -1.9 + MITER, -30.5 - HALF_W],
		# Entry Spur bottom rail (east of East return lane)
		[-15.0 + HALF_W - MITER, -1.9 + MITER, -30.5 + HALF_W],
		# Inner North straight bottom rail
		[-38.3 + HALF_W - MITER, -15.0 - HALF_W + MITER, -30.5 + HALF_W],
		# Inner Mid crossover top rail
		[-26.8 - HALF_W - MITER, -15.0 - HALF_W + MITER, -22.1 - HALF_W],
		# Outer Mid crossover bottom rail
		[-26.8 + HALF_W - MITER, -15.0 + HALF_W + MITER, -22.1 + HALF_W],
		# Inner South straight top rail
		[-38.3 + HALF_W - MITER, -26.8 - HALF_W + MITER, -7.8 - HALF_W],
		# Outer South straight bottom rail
		[-38.3 - HALF_W - MITER, -26.8 + HALF_W + MITER, -7.8 + HALF_W],
	]:
		_add_clipped_stripe(m, yellow_mat, float(h_rail[0]), float(h_rail[1]), float(h_rail[2]), true, LINE_W, floor_y, exclusions)

	for v_rail: Array in [
		# Outer West straight left rail
		[-30.5 - HALF_W - MITER, -7.8 + HALF_W + MITER, -38.3 - HALF_W],
		# Inner West straight right rail
		[-30.5 + HALF_W - MITER, -7.8 - HALF_W + MITER, -38.3 + HALF_W],
		# Inner Pump return left rail
		[-22.1 - HALF_W - MITER, -7.8 - HALF_W + MITER, -26.8 - HALF_W],
		# Outer Pump return right rail (west of Pump floor grate)
		[-22.1 + HALF_W - MITER, -7.8 + HALF_W + MITER, -26.8 + HALF_W],
		# Inner East return left rail
		[-30.5 + HALF_W - MITER, -22.1 - HALF_W + MITER, -15.0 - HALF_W],
		# Outer East return right rail
		[-30.5 + HALF_W - MITER, -22.1 + HALF_W + MITER, -15.0 + HALF_W],
		# Forklift start bay rear bumper line
		[-30.5 - HALF_W - MITER, -30.5 + HALF_W + MITER, -1.9],
	]:
		_add_clipped_stripe(m, yellow_mat, float(v_rail[0]), float(v_rail[1]), float(v_rail[2]), false, LINE_W, floor_y, exclusions)

	# Directional yellow runway chevrons placed strictly on clean bare concrete between exclusions
	for arrow: Array in [
		[Vector2(-3.5, -30.5), Vector2.LEFT],
		[Vector2(-14.2, -30.5), Vector2.LEFT],
		[Vector2(-28.0, -30.5), Vector2.LEFT],
		[Vector2(-33.6, -30.5), Vector2.LEFT],
		[Vector2(-38.3, -26.6), Vector2.DOWN],
		[Vector2(-38.3, -17.5), Vector2.DOWN],
		[Vector2(-38.3, -11.2), Vector2.DOWN],
		[Vector2(-34.6, -7.8), Vector2.RIGHT],
		[Vector2(-29.8, -7.8), Vector2.RIGHT],
		[Vector2(-26.8, -11.0), Vector2.UP],
		[Vector2(-26.8, -17.4), Vector2.UP],
		[Vector2(-21.8, -22.1), Vector2.RIGHT],
		[Vector2(-18.0, -22.1), Vector2.RIGHT],
		[Vector2(-15.0, -26.5), Vector2.UP],
	]:
		_add_runway_chevron(m, yellow_mat, arrow[0], arrow[1], floor_y, exclusions)


static func _add_clipped_stripe(m: MeshBuilder, mat: Material, a0: float, a1: float, fixed: float,
		horizontal: bool, width: float, floor_y: float, exclusions: Array[Rect2]) -> void:
	var lo := minf(a0, a1)
	var hi := maxf(a0, a1)
	var spans: Array[Vector2] = [Vector2(lo, hi)]
	var hw := width * 0.5
	for rect: Rect2 in exclusions:
		var cross_ok := fixed + hw >= rect.position.y and fixed - hw <= rect.end.y if horizontal else fixed + hw >= rect.position.x and fixed - hw <= rect.end.x
		if not cross_ok:
			continue
		var c0 := rect.position.x if horizontal else rect.position.y
		var c1 := rect.end.x if horizontal else rect.end.y
		var next_spans: Array[Vector2] = []
		for seg: Vector2 in spans:
			if c1 <= seg.x or c0 >= seg.y:
				next_spans.append(seg)
			else:
				if c0 - seg.x > 0.14:
					next_spans.append(Vector2(seg.x, c0))
				if seg.y - c1 > 0.14:
					next_spans.append(Vector2(c1, seg.y))
		spans = next_spans
	for seg: Vector2 in spans:
		var seg_len := seg.y - seg.x
		if seg_len < 0.14:
			continue
		var mid := (seg.x + seg.y) * 0.5
		if horizontal:
			m.box(mat, Vector3(mid, floor_y + 0.008, fixed), Vector3(seg_len, 0.012, width))
		else:
			m.box(mat, Vector3(fixed, floor_y + 0.008, mid), Vector3(width, 0.012, seg_len))


static func _add_runway_chevron(m: MeshBuilder, mat: Material, center: Vector2, dir: Vector2,
		floor_y: float, exclusions: Array[Rect2]) -> void:
	var chev_bounds := Rect2(center - Vector2(0.55, 0.55), Vector2(1.10, 1.10))
	for rect: Rect2 in exclusions:
		if rect.intersects(chev_bounds):
			return
	var fwd := Vector3(dir.x, 0.0, dir.y).normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var y := floor_y + 0.014
	var c := Vector3(center.x, y, center.y)
	for wing_sign: float in [-1.0, 1.0]:
		var s := side * wing_sign
		var tip := c + fwd * 0.34
		var tip_back := c + fwd * 0.12
		var arm_outer := c - fwd * 0.30 + s * 0.62
		var arm_inner := c - fwd * 0.48 + s * 0.46
		m.quad(mat, arm_outer, tip, tip_back, arm_inner, Vector3.UP)


static func _finalize_tex(key: String, img: Image) -> ImageTexture:
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _hazard_tex() -> ImageTexture:
	if _tex_cache.has("hazard"):
		return _tex_cache["hazard"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var amber := Color("b6861e")
	var dark := Color("161a1e")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4099
	for y in s:
		for x in s:
			var band := int(floor(float(x + y) / 32.0)) % 2
			var col: Color = dark if band == 0 else amber
			var scuff := -0.10 if rng.randf() < 0.06 else 0.0
			var wear := rng.randf_range(-0.07, 0.04) + scuff
			img.set_pixel(x, y, Color(clampf(col.r + wear, 0.0, 1.0), clampf(col.g + wear, 0.0, 1.0), clampf(col.b + wear, 0.0, 1.0), 1.0))
	return _finalize_tex("hazard", img)


static func _corrugated_tex() -> ImageTexture:
	if _tex_cache.has("corrugated"):
		return _tex_cache["corrugated"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4129
	for y in s:
		var ty := float(y) / float(s) * TAU
		var rib := 0.72 + 0.28 * sin(ty * 8.0)
		var seam := 0.72 if (y % 16) < 2 else 1.0
		var v_base := clampf(rib * seam, 0.34, 1.0)
		for x in s:
			var tx := float(x) / float(s) * TAU
			var streak := maxf(0.0, sin(tx * 3.0 + 0.6) * cos(tx * 5.0 - 0.4))
			var grime := 1.0 - streak * 0.22 + rng.randf_range(-0.04, 0.03)
			var v := clampf(v_base * grime, 0.25, 1.0)
			var rust := streak * 0.08 * clampf(0.5 + 0.5 * sin(ty * 2.0 + tx), 0.0, 1.0)
			img.set_pixel(x, y, Color(v * 0.85 + rust, v * 0.90 + rust * 0.35, v * 0.94 - rust * 0.2, 1.0))
	return _finalize_tex("corrugated", img)


static func _scuffed_paint_tex(key: String, base_col: Color, scuff_col: Color, seed_val: int) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in s:
		var ty := float(y) / float(s) * TAU
		for x in s:
			var tx := float(x) / float(s) * TAU
			var mottle := 0.5 + 0.28 * sin(tx * 2.0 + ty) + 0.22 * cos(ty * 3.0 - tx * 2.0)
			var chip := clampf((mottle - 0.72) * 2.4, 0.0, 0.45)
			if rng.randf() < 0.035:
				chip = maxf(chip, rng.randf_range(0.35, 0.72))
			var c := base_col.lerp(scuff_col, chip)
			var grain := rng.randf_range(-0.035, 0.035)
			img.set_pixel(x, y, Color(clampf(c.r + grain, 0.0, 1.0), clampf(c.g + grain, 0.0, 1.0), clampf(c.b + grain, 0.0, 1.0), 1.0))
	return _finalize_tex(key, img)


static func _chipped_paint_tex() -> ImageTexture:
	if _tex_cache.has("chipped_paint"):
		return _tex_cache["chipped_paint"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var paint := Color(0.92, 0.94, 0.95, 1.0)
	var asphalt := Color(0.42, 0.46, 0.49, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4211
	for y in s:
		var ty := float(y) / float(s) * TAU
		for x in s:
			var tx := float(x) / float(s) * TAU
			var wear_wave := 0.5 + 0.5 * sin(tx * 2.0 + ty * 3.0) * cos(tx * 3.0 - ty)
			var tread := clampf(sin(tx * 4.0 + ty * 2.0) * 0.5 + 0.5, 0.0, 1.0)
			var mix_amt := 0.06 + (0.28 if wear_wave > 0.80 else 0.0)
			if rng.randf() < 0.09:
				mix_amt = maxf(mix_amt, rng.randf_range(0.30, 0.65))
			mix_amt = clampf(mix_amt + tread * 0.10, 0.0, 0.72)
			var c := paint.lerp(asphalt, mix_amt)
			var n := rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(clampf(c.r + n, 0.0, 1.0), clampf(c.g + n, 0.0, 1.0), clampf(c.b + n, 0.0, 1.0), 1.0))
	return _finalize_tex("chipped_paint", img)


static func _crate_panel_tex(key: String, base: Color, recess: Color, stamp: Color, tech_ribs: bool) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4339 if tech_ribs else 4349
	for y in s:
		for x in s:
			var border := x < 10 or x >= s - 10 or y < 10 or y >= s - 10
			var groove := (x >= 10 and x < 13) or (x >= s - 13 and x < s - 10) or (y >= 10 and y < 13) or (y >= s - 13 and y < s - 10)
			var c := base
			if groove:
				c = recess.darkened(0.18)
			elif not border:
				c = base.lerp(recess, 0.35)
				if tech_ribs and ((x > 26 and x < 34) or (x > 94 and x < 102)):
					c = base.lightened(0.08)
			if y >= 54 and y <= 62 and x >= 18 and x <= 58:
				c = stamp
			elif x >= 80 and x <= 108 and y >= 22 and y <= 38:
				c = stamp.lerp(Color(0.84, 0.85, 0.82), 0.35)
				if (x % 4) == 0 and y >= 26 and y <= 35:
					c = recess.darkened(0.35)
			var dusty := clampf((float(y) - 94.0) / 34.0, 0.0, 1.0) * 0.22
			c = c.lerp(Color(0.24, 0.23, 0.21), dusty)
			var wear := rng.randf_range(-0.035, 0.030)
			if rng.randf() < 0.018:
				wear -= 0.09
			img.set_pixel(x, y, Color(clampf(c.r + wear, 0.0, 1.0), clampf(c.g + wear, 0.0, 1.0), clampf(c.b + wear, 0.0, 1.0), 1.0))
	return _finalize_tex(key, img)


static func _carton_tex() -> ImageTexture:
	if _tex_cache.has("carton"):
		return _tex_cache["carton"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var kraft := Color("a58256")
	var seam := Color("694f31")
	var tape := Color("84623a")
	var label := Color("d6d0c0")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	for y in s:
		var flute := 0.025 * sin(float(y) * 0.45)
		for x in s:
			var c := kraft
			if x < 4 or x >= s - 4 or y < 4 or y >= s - 4 or absf(float(x - 64)) < 1.5:
				c = seam
			elif absi(x - 64) < 9 and (y < 24 or y > 104 or absi(y - 64) < 28):
				c = tape
			elif x >= 16 and x <= 48 and y >= 18 and y <= 38:
				c = label
				if y >= 22 and y <= 34 and x >= 20 and x <= 44 and ((x % 3) == 0):
					c = Color("222528")
			var damp := clampf((float(y) - 102.0) / 26.0, 0.0, 1.0) * 0.20
			c = c.lerp(Color("4e4030"), damp)
			var grain := rng.randf_range(-0.04, 0.04) + flute
			img.set_pixel(x, y, Color(clampf(c.r + grain, 0.0, 1.0), clampf(c.g + grain, 0.0, 1.0), clampf(c.b + grain, 0.0, 1.0), 1.0))
	return _finalize_tex("carton", img)


static func _tote_tex() -> ImageTexture:
	if _tex_cache.has("tote"):
		return _tex_cache["tote"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var upper := Color("cbd2d6")
	var filled := Color("aeb8bc")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4507
	for y in s:
		for x in s:
			var c := upper if y < 56 else filled
			if y >= 55 and y <= 57:
				c = Color("6b767c")
			elif x >= 58 and x <= 70 and (y % 12) < 2 and y >= 24 and y <= 110:
				c = Color("4b545a")
			elif x >= 82 and x <= 108 and y >= 22 and y <= 44:
				c = Color("d8dcde") if y < 33 else Color("c78d24")
			var grime := clampf((float(y) - 96.0) / 32.0, 0.0, 1.0) * 0.16
			c = c.lerp(Color("5d615e"), grime)
			var n := rng.randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(clampf(c.r + n, 0.0, 1.0), clampf(c.g + n, 0.0, 1.0), clampf(c.b + n, 0.0, 1.0), 1.0))
	return _finalize_tex("tote", img)
