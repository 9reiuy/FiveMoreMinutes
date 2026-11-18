extends RefCounted
## Arknights: Endfield-inspired architectural PBR materials (FiveMinuteMore 32px/m calibrated shaders,
## clean off-white precast concrete, dark charcoal steel & grate pit, safety yellow hairline trim, stencil graphics).

const SURFACE_SHADER := preload("res://shaders/dream3d/atrium_loop_surface.gdshader")
const TRANSIT_SHADER := preload("res://shaders/dream3d/transit_surfaces.gdshader")
const M := preload("res://scripts/testing/maintenance_environment.gd")

const PH_LOOP_DIR := "res://art/Dream/CC0/AtriumLoop11/polyhaven/"
const PH_BASE_DIR := "res://art/Dream/CC0/PolyHavenResearch/"
const QUAT_EXTRA_DIR := "res://art/Dream/CC0/AtriumLoop11/quaternius/"
const QUAT_STD_DIR := "res://art/Dream/CC0/QuaterniusSciFiStandard/"

var cutout: RefCounted
var _building_inv := Transform3D.IDENTITY

var base_concrete: ShaderMaterial
var pit_grate: ShaderMaterial
var pier_concrete: ShaderMaterial
var corridor_floor: ShaderMaterial
var wall_composite: ShaderMaterial
var wall_precast_charcoal: ShaderMaterial
var pit_plinth_floor: ShaderMaterial

var endfield_yellow: StandardMaterial3D
var endfield_yellow_emit: StandardMaterial3D
var endfield_white_tube: StandardMaterial3D
var stencil_backing: StandardMaterial3D
var dark_bulkhead: StandardMaterial3D
var burgundy_placard: StandardMaterial3D
var steel_mullion: StandardMaterial3D
var steel_rail: StandardMaterial3D
var steel_beam: StandardMaterial3D
var door_frame: StandardMaterial3D
var door_leaf: StandardMaterial3D
var office_interior_wall: StandardMaterial3D

var glass_corridor_rail: StandardMaterial3D
var glass_smoked_office: StandardMaterial3D

var ceiling_diffuser: StandardMaterial3D
var spot_lens_mat: StandardMaterial3D
var bay_beacon_emit: StandardMaterial3D
var decal_oil_stain: StandardMaterial3D
var decal_scuff_streak: StandardMaterial3D
var decal_wall_drip: StandardMaterial3D
var decal_rust_patch: StandardMaterial3D
var decal_crack: StandardMaterial3D
var exit_green: StandardMaterial3D
var monitor_glow: StandardMaterial3D
var black_cap: Material

var _unit_box: BoxMesh
var _unit_quad: QuadMesh
var _pipes: Dictionary = {}
var _quat_cache: Dictionary = {}
var _quat_mat_cache: Dictionary = {}
var _glass_rail_cache: Dictionary = {}
static var procedural_cache_enabled := true
static var _procedural_materials: Dictionary = {}

func _cached_procedural(key: Array) -> StandardMaterial3D:
	if procedural_cache_enabled and _procedural_materials.has(key):
		# Only immutable texture data is shared. Region-specific material edits
		# must never change another region or the cached prototype.
		return _procedural_materials[key].duplicate() as StandardMaterial3D
	return null

func _remember_procedural(key: Array, material: StandardMaterial3D) -> StandardMaterial3D:
	if procedural_cache_enabled: _procedural_materials[key]=material.duplicate()
	return material


func _init(owner_cutout: RefCounted, building_inv := Transform3D.IDENTITY, defer_atrium_surfaces := false) -> void:
	cutout = owner_cutout
	_building_inv = building_inv
	black_cap = cutout.top_black if cutout != null else M.wall_top_black()
	exit_green = _std(Color("1c874f"), 0.48, 0.04, Color("26c774"), 0.78)
	monitor_glow = _std(Color("265460"), 0.34, 0.0, Color("428c9e"), 0.55)
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_unit_quad = QuadMesh.new()
	_unit_quad.size = Vector2.ONE
	if not defer_atrium_surfaces:
		prepare_window_finishes()
		prepare_atrium_surfaces()
		prepare_atrium_finishes()
		prepare_atrium_weathering()


func prepare_window_finishes() -> void:
	endfield_yellow_emit = _make_weathered_surface_material("yellow_emit", Color("c4a428"), 0.54, 0.06, Color("b49220"), 0.30)
	endfield_white_tube = _make_weathered_surface_material("white_tube", Color("9ea4a2"), 0.72, 0.06)
	glass_corridor_rail = _make_endfield_crosshair_glass_material()


func prepare_atrium_surfaces() -> void:
	# 1F Hangar Deck: dark damp weathered concrete slabs (3.2m bays) with heavy cracking, dust & oil wear
	base_concrete = _make_ph_shader(
		PH_BASE_DIR + "concrete_floor_worn_001_Diffuse.res",
		PH_BASE_DIR + "concrete_floor_worn_001_nor_gl.res",
		PH_BASE_DIR + "concrete_floor_worn_001_Rough.res",
		Color("2c3237"), Vector2(3.2, 3.2), 0.58, 0.40, 0.04, 0.22, 0.56, false, 0.92, 0.68, 0.009, 0.85
	)

	# Heavy oiled gunmetal steel deck plates in the H06 pit (2.4m plates with rust & grease film)
	pit_grate = _make_ph_shader(
		PH_BASE_DIR + "concrete_floor_worn_001_Diffuse.res",
		PH_BASE_DIR + "concrete_floor_worn_001_nor_gl.res",
		PH_BASE_DIR + "concrete_floor_worn_001_Rough.res",
		Color("21272d"), Vector2(2.4, 2.4), 0.42, 0.36, 0.26, 0.28, 0.52, false, 0.94, 0.78, 0.012, 0.26
	)
	pit_grate.set_shader_parameter(&"rust_colour", Color("2b1b11"))

	# Supporting columns under suspended corridors (weathered industrial precast concrete)
	pier_concrete = _make_ph_shader(
		PH_LOOP_DIR + "precast_concrete_wall_diff_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_nor_gl_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_rough_1k.jpg",
		Color("747b7e"), Vector2(2.4, 2.0), 0.76, 0.34, 0.02, 0.18, 0.52, true, 0.86, 0.48, 0.008, 0.48
	)

	# Suspended Corridor Deck: calm 2.8m weathered dark-slate concrete slabs with traffic dust & cracks
	corridor_floor = _make_ph_shader(
		PH_BASE_DIR + "concrete_floor_worn_001_Diffuse.res",
		PH_BASE_DIR + "concrete_floor_worn_001_nor_gl.res",
		PH_BASE_DIR + "concrete_floor_worn_001_Rough.res",
		Color("454c53"), Vector2(2.8, 2.8), 0.58, 0.38, 0.03, 0.20, 0.54, false, 0.88, 0.56, 0.008, 0.52
	)

	# Right Corridor Walls: matte off-white aged precast concrete panels with runoff streaks & seepage
	wall_composite = _make_ph_shader(
		PH_LOOP_DIR + "precast_concrete_wall_diff_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_nor_gl_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_rough_1k.jpg",
		Color("a3a8a5"), Vector2(3.2, 2.2), 0.78, 0.34, 0.02, 0.18, 0.50, true, 0.82, 0.30, 0.008, 0.46
	)
	wall_composite.set_shader_parameter(&"occlusion_cutout_enabled", true)

	# Charcoal precast structural bulkheads & corridor under-soffit fascia
	wall_precast_charcoal = _make_ph_shader(
		PH_LOOP_DIR + "precast_concrete_wall_diff_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_nor_gl_1k.jpg",
		PH_LOOP_DIR + "precast_concrete_wall_rough_1k.jpg",
		Color("2e3439"), Vector2(2.8, 2.0), 0.76, 0.36, 0.04, 0.22, 0.54, true, 0.88, 0.50, 0.008, 0.72
	)
	pit_plinth_floor = _make_ph_shader(
		PH_BASE_DIR + "concrete_floor_worn_001_Diffuse.res",
		PH_BASE_DIR + "concrete_floor_worn_001_nor_gl.res",
		PH_BASE_DIR + "concrete_floor_worn_001_Rough.res",
		Color("31373c"), Vector2(2.8, 2.8), 0.50, 0.40, 0.08, 0.20, 0.58, false, 0.96, 0.66, 0.009, 0.75
	)


func prepare_atrium_finishes() -> void:
	# Weathered industrial paint and metal.
	endfield_yellow = _make_weathered_surface_material("yellow_paint", Color("b69322"), 0.68, 0.06)
	stencil_backing = _make_weathered_surface_material("stencil_panel", Color("a9afac"), 0.78, 0.04)
	dark_bulkhead = _make_weathered_surface_material("weathered_metal", Color("21262b"), 0.66, 0.34)
	burgundy_placard = _make_weathered_surface_material("burgundy_placard", Color("4e1b20"), 0.76, 0.05)

	steel_mullion = _make_weathered_surface_material("weathered_metal", Color("1c2024"), 0.58, 0.42)
	steel_rail = _make_weathered_surface_material("weathered_metal", Color("2e353a"), 0.52, 0.44)
	steel_beam = _make_weathered_surface_material("weathered_metal", Color("181c20"), 0.70, 0.38)
	door_frame = _make_weathered_surface_material("weathered_metal", Color("1a1e22"), 0.64, 0.36)
	door_leaf = _make_weathered_surface_material("door_metal", Color("282e33"), 0.60, 0.38)
	office_interior_wall = _std(Color("22282d"), 0.86, 0.02)

	glass_smoked_office = _glass(Color(0.12, 0.16, 0.20, 0.54), 0.16, 0.62)

	# Weak subdued corridor tube emission; spotlights start unlit until triggered
	ceiling_diffuser = _std(Color("9cb4bc"), 0.58, 0.0, Color("90b8c4"), 1.05)
	spot_lens_mat = _std(Color("1a2228"), 0.22, 0.18, Color("e8f4fa"), 0.0)
	spot_lens_mat.emission_enabled = true
	spot_lens_mat.emission = Color("e8f4fa")
	spot_lens_mat.emission_energy_multiplier = 0.0
	bay_beacon_emit = _std(Color("8a221d"), 0.42, 0.0, Color("c83428"), 0.75)


func prepare_atrium_weathering() -> void:
	decal_oil_stain = _make_grime_decal_material("oil")
	decal_scuff_streak = _make_grime_decal_material("scuff")
	decal_wall_drip = _make_grime_decal_material("drip")
	decal_rust_patch = _make_grime_decal_material("rust")
	decal_crack = _make_grime_decal_material("crack")


func _make_ph_shader(diff_p: String, nor_p: String, rough_p: String, tint: Color, span: Vector2,
		rough: float, ndepth: float, met: float, seam: float, contrast: float, wall: bool,
		wear := 0.78, wet := 0.54, seam_w := 0.008, crack := 0.65) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE_SHADER
	mat.set_shader_parameter(&"albedo_tex", load(diff_p))
	mat.set_shader_parameter(&"normal_tex", load(nor_p))
	mat.set_shader_parameter(&"rough_tex", load(rough_p))
	mat.set_shader_parameter(&"building_inv", _building_inv)
	mat.set_shader_parameter(&"tint_colour", tint)
	mat.set_shader_parameter(&"tile_span", span)
	mat.set_shader_parameter(&"roughness_bias", rough)
	mat.set_shader_parameter(&"normal_depth", ndepth)
	mat.set_shader_parameter(&"metallic_amount", met)
	mat.set_shader_parameter(&"seam_strength", seam)
	mat.set_shader_parameter(&"seam_width", seam_w)
	mat.set_shader_parameter(&"tex_contrast", contrast)
	mat.set_shader_parameter(&"wear_amount", wear)
	mat.set_shader_parameter(&"wetness", wet)
	mat.set_shader_parameter(&"crack_strength", crack)
	mat.set_shader_parameter(&"is_wall", wall)
	return mat


func _hash_i(ix: int, iy: int, seed_v: int) -> float:
	var n: int = (ix * 374761393 + iy * 668265263 + seed_v * 1442695041) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


func _smooth_noise_periodic(fx: float, fy: float, px_period: int, py_period: int, seed_v: int) -> float:
	var px := posmod(floori(fx), px_period)
	var py := posmod(floori(fy), py_period)
	var nx := (px + 1) % px_period
	var ny := (py + 1) % py_period
	var tx := fx - floorf(fx)
	var ty := fy - floorf(fy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := lerpf(_hash_i(px, py, seed_v), _hash_i(nx, py, seed_v), tx)
	var b := lerpf(_hash_i(px, ny, seed_v), _hash_i(nx, ny, seed_v), tx)
	return lerpf(a, b, ty)


func _fbm_periodic(u: float, v: float, base_cells: int, seed_v: int, cells_y := -1) -> float:
	var cy := base_cells if cells_y <= 0 else cells_y
	var val := _smooth_noise_periodic(u * float(base_cells), v * float(cy), base_cells, cy, seed_v) * 0.55
	val += _smooth_noise_periodic(u * float(base_cells * 2), v * float(cy * 2), base_cells * 2, cy * 2, seed_v + 19) * 0.30
	val += _smooth_noise_periodic(u * float(base_cells * 4), v * float(cy * 4), base_cells * 4, cy * 4, seed_v + 47) * 0.15
	return val


func _make_weathered_surface_material(kind: String, base_col: Color, rough: float, met: float,
		emit_col := Color.BLACK, emit_energy := 0.0) -> StandardMaterial3D:
	## World-triplanar procedural paint chipping, soot streaks, rust dust, and scratches for architectural parts.
	var key: Array=["surface",kind,base_col,rough,met,emit_col,emit_energy]
	var cached:=_cached_procedural(key)
	if cached!=null:return cached
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var seed_v := hash("surf_" + kind + "_" + base_col.to_html())
	for y in size:
		var v := float(y) / float(size)
		for x in size:
			var u := float(x) / float(size)
			var broad := _fbm_periodic(u, v, 4, seed_v)
			var detail := _fbm_periodic(u, v, 8, seed_v + 71)
			var grit := _hash_i(x, y, seed_v + 13)
			var c := base_col

			if kind == "yellow_paint" or kind == "yellow_emit":
				# Faded safety paint with dark concrete/asphalt wear chips & wheel grime
				var chip_mask := smoothstep(0.62, 0.72, broad * 0.65 + detail * 0.45)
				var soot := smoothstep(0.55, 0.85, detail)
				c = base_col * lerpf(0.84, 1.08, broad)
				c = c.lerp(Color("4e4628"), soot * 0.42)
				if kind == "yellow_paint" and chip_mask > 0.35:
					c = c.lerp(Color("24282b"), (chip_mask - 0.35) * 1.15)
				elif grit > 0.90:
					c = c.darkened(0.22)
			elif kind == "white_tube" or kind == "stencil_panel":
				# Soot smudges, vertical leak film, rust flecks, and dusty corner darkening
				var v_streak := _fbm_periodic(u, v, 8, seed_v + 31, 2)
				var rust_dot := smoothstep(0.74, 0.88, broad * 0.5 + grit * 0.55)
				c = base_col * lerpf(0.82, 1.05, detail)
				c = c.lerp(Color("45433d"), clampf((v_streak - 0.46) * 1.1, 0.0, 0.42))
				c = c.lerp(Color("5b3420"), rust_dot * 0.36)
				if grit > 0.94:
					c = c.lerp(Color("2b2f32"), 0.45)
			elif kind == "burgundy_placard":
				var stain := smoothstep(0.54, 0.82, broad)
				c = base_col * lerpf(0.82, 1.06, detail)
				c = c.lerp(Color("241516"), stain * 0.42)
			else:
				# Brushed weathered steel / dark doors with rust pockets & edge grime
				var streak_h := _fbm_periodic(u, v, 4, seed_v + 101, 8)
				var rust_pocket := smoothstep(0.64, 0.84, broad * 0.7 + detail * 0.35)
				c = base_col * lerpf(0.78, 1.16, streak_h)
				c = c.lerp(Color("3f2314"), rust_pocket * 0.38)
				if kind == "door_metal":
					var drip := smoothstep(0.56, 0.84, _fbm_periodic(u, v, 8, seed_v + 211, 2))
					c = c.lerp(Color("151719"), drip * 0.44)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))

	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex
	m.roughness = rough
	m.metallic = met
	m.metallic_specular = 0.26
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_texture = tex
		m.emission_energy_multiplier = emit_energy
	return _remember_procedural(key,m)


func _make_grime_decal_material(kind: String) -> StandardMaterial3D:
	## Procedural transparent oil, chalk-dust scuff, soot/rust water drip, rust scab, or fracture decal.
	var key: Array=["grime",kind]
	var cached:=_cached_procedural(key)
	if cached!=null:return cached
	var size := 128 if kind == "crack" else 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var seed_v := hash("decal_" + kind)
	var rough := 0.50
	if kind == "oil":
		rough = 0.08
	elif kind == "scuff":
		rough = 0.88
	elif kind == "drip":
		rough = 0.78
	elif kind == "rust":
		rough = 0.92
	elif kind == "crack":
		rough = 0.94

	for y in size:
		var v := float(y) / float(size - 1)
		var ny := v * 2.0 - 1.0
		for x in size:
			var u := float(x) / float(size - 1)
			var nx := u * 2.0 - 1.0
			var f1 := _fbm_periodic(u, v, 5, seed_v)
			var f2 := _fbm_periodic(u, v, 10, seed_v + 37)
			var jitter := _hash_i(x, y, seed_v + 5)
			var col := Color(0.08, 0.09, 0.10)
			var a := 0.0

			if kind == "drip":
				# Multi-stream tapered runoff trails dark near source (top) & warm rust edges
				var streams := _fbm_periodic(u, v, 7, seed_v + 17, 2)
				var top_mask := clampf(1.0 - pow(v, 1.35), 0.0, 1.0)
				var side_mask := clampf(1.0 - absf(nx) * 1.15, 0.0, 1.0)
				var trail := smoothstep(0.38, 0.72, streams * 0.78 + f2 * 0.30)
				col = Color("161310").lerp(Color("3a2315"), clampf(f1 * 0.85, 0.0, 0.65))
				a = trail * top_mask * side_mask * 0.86
			elif kind == "scuff":
				# Chalky pale concrete dust + dark tread scrape tracks visible on dark slate decks
				var streak := clampf(1.0 - ny * ny * 2.8, 0.0, 1.0) * clampf(1.0 - nx * nx * 1.12, 0.0, 1.0)
				var track_ribs := sin(ny * 10.0 + f1 * 4.0) * 0.5 + 0.5
				col = Color("222528").lerp(Color("7d8286"), clampf(f2 * 1.25 - 0.12, 0.0, 1.0))
				a = streak * clampf(track_ribs * 0.55 + f1 * 0.65, 0.0, 1.0) * 0.72
			elif kind == "oil":
				# Multi-lobe glossy dark oil spill with amber-brown perimeter sheen
				var r := Vector2(nx, ny).length()
				var edge := r + (f1 - 0.5) * 0.62
				var core := 1.0 - smoothstep(0.28, 0.82, edge)
				col = Color("1e140c").lerp(Color("050709"), clampf(core * 1.35, 0.0, 1.0))
				a = clampf(core * 0.90, 0.0, 0.88)
			elif kind == "rust":
				# Muted dark iron-oxide rust & oily mineral stain (natural dark umber-brown, non-red!)
				var r_rust := Vector2(nx, ny).length() + (f1 - 0.5) * 0.72
				var body := 1.0 - smoothstep(0.24, 0.88, r_rust)
				col = Color("3a2416").lerp(Color("171310"), smoothstep(0.32, 0.78, f2))
				a = clampf(body * (0.48 + jitter * 0.28), 0.0, 0.72)
			elif kind == "crack":
				# Crisp multi-branch concrete fracture fissures at 128px resolution
				var f3 := _fbm_periodic(u, v, 16, seed_v + 91)
				var warp_u := u + (f1 - 0.5) * 0.18 + (f3 - 0.5) * 0.05
				var warp_v := v + (f2 - 0.5) * 0.18 + (f3 - 0.5) * 0.05
				var c1 := absf((warp_v - 0.52) - (warp_u - 0.5) * 0.24 + (f1 - 0.5) * 0.12)
				var c2 := absf((warp_u - 0.52) * 0.78 + (warp_v - 0.44) * 0.62 + (f2 - 0.5) * 0.14)
				var line1 := 1.0 - smoothstep(0.004, 0.015, c1)
				var line2 := (1.0 - smoothstep(0.004, 0.013, c2)) * (1.0 if u >= 0.36 else 0.0)
				var falloff := clampf(1.0 - Vector2(nx, ny).length() * 1.04, 0.0, 1.0)
				col = Color("101214").lerp(Color("5c6164"), clampf((c1 * 48.0 - 0.4) * 0.4, 0.0, 0.45))
				a = clampf(maxf(line1, line2) * falloff * 0.88, 0.0, 0.86)

			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 0.90)))

	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.12 if kind == "oil" else 0.0
	m.metallic_specular = 0.85 if kind == "oil" else 0.16
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	return _remember_procedural(key,m)


func _std(albedo: Color, rough: float, met: float, emit := Color.BLACK, emit_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = met
	m.metallic_specular = 0.24
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	return m


func _glass(albedo: Color, rough: float, spec: float) -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = albedo
	g.roughness = rough
	g.metallic = 0.06
	g.metallic_specular = spec
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	return g


func _make_endfield_crosshair_glass_material() -> StandardMaterial3D:
	## Aged balustrade glass with reticle ticks plus bottom condensation grime & dust specks.
	var key: Array=["crosshair_glass"]
	var cached:=_cached_procedural(key)
	if cached!=null:return cached
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		for x in w:
			var u := float(x) / float(w - 1)
			var dust := _fbm_periodic(u, v, 6, 409)
			var sill_grime := clampf((v - 0.68) * 3.1, 0.0, 1.0) * (0.4 + dust * 0.6)
			var col := Color(0.68, 0.74, 0.75).lerp(Color(0.32, 0.34, 0.32), sill_grime * 0.75)
			var a := clampf(0.14 + sill_grime * 0.26 + maxf(0.0, dust - 0.62) * 0.20, 0.12, 0.44)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	var mark := Color(0.14, 0.17, 0.19, 0.68)
	for cx: int in [16, 48]:
		_fill_rect(img, cx - 3, 32, 7, 1, mark)
		_fill_rect(img, cx, 29, 1, 7, mark)
	var tex := ImageTexture.create_from_image(img)
	var g := _glass(Color.WHITE, 0.18, 0.64)
	g.albedo_texture = tex
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return _remember_procedural(key,g)


func glass_rail_for_span(width: float, height: float) -> StandardMaterial3D:
	var tiles := maxf(1.0, roundf(width / maxf(0.35, height)))
	var key := int(tiles)
	if not _glass_rail_cache.has(key):
		var m_clone := glass_corridor_rail.duplicate() as StandardMaterial3D
		m_clone.uv1_scale = Vector3(float(key), 1.0, 1.0)
		_glass_rail_cache[key] = m_clone
	return _glass_rail_cache[key]


func quad(parent: Node3D, title: String, size_xy: Vector2, at: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = _unit_quad
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3(size_xy.x, size_xy.y, 1.0)
	parent.add_child(mi)
	return mi


func box(parent: Node3D, title: String, size: Vector3, at: Vector3, mat: Material, register := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = _unit_box
	mi.material_override = mat
	mi.position = at
	mi.scale = size
	parent.add_child(mi)
	if register and cutout != null:
		cutout.register_mesh(mi)
	return mi


func cylinder(parent: Node3D, title: String, radius: float, length: float, at: Vector3, mat: Material, axis := Vector3.UP) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 1.0
	cyl.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = at
	if axis != Vector3.UP:
		mi.quaternion = Quaternion(Vector3.UP, axis.normalized())
	mi.scale = Vector3(1.0, length, 1.0)
	parent.add_child(mi)
	return mi


func torus_ring(parent: Node3D, title: String, outer_r: float, inner_r: float, at: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var tor := TorusMesh.new()
	tor.outer_radius = outer_r
	tor.inner_radius = inner_r
	tor.rings = 32
	tor.ring_segments = 12
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = tor
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func pipe(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, register := false) -> MeshInstance3D:
	var delta := b - a
	if delta.length_squared() < 0.0001:
		return null
	if not _pipes.has(radius):
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 1.0
		cyl.radial_segments = 12
		_pipes[radius] = cyl
	var mi := MeshInstance3D.new()
	mi.name = "RailPipe"
	mi.mesh = _pipes[radius]
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, delta.normalized())
	mi.scale.y = delta.length()
	parent.add_child(mi)
	if register and cutout != null:
		cutout.register_mesh(mi)
	return mi


func build_top_black_wall(parent: Node3D, title: String, center: Vector3, size: Vector3, outward_sides: int, mat: Material, register := true) -> MeshInstance3D:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var st_face := SurfaceTool.new()
	st_face.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_face.set_material(mat)
	var st_cap := SurfaceTool.new()
	st_cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_cap.set_material(black_cap)

	var p000 := Vector3(-hx, -hy, -hz)
	var p100 := Vector3(hx, -hy, -hz)
	var p110 := Vector3(hx, hy, -hz)
	var p010 := Vector3(-hx, hy, -hz)
	var p001 := Vector3(-hx, -hy, hz)
	var p101 := Vector3(hx, -hy, hz)
	var p111 := Vector3(hx, hy, hz)
	var p011 := Vector3(-hx, hy, hz)

	_quad(st_cap, p010, p110, p111, p011, Vector3.UP)
	_quad(st_cap if (outward_sides & 1) != 0 else st_face, p000, p010, p011, p001, Vector3.LEFT)
	_quad(st_cap if (outward_sides & 2) != 0 else st_face, p101, p111, p110, p100, Vector3.RIGHT)
	_quad(st_cap if (outward_sides & 4) != 0 else st_face, p100, p110, p010, p000, Vector3.FORWARD)
	_quad(st_cap if (outward_sides & 8) != 0 else st_face, p001, p011, p111, p101, Vector3.BACK)

	var mesh := st_face.commit(st_cap.commit())
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = mesh
	mi.position = center
	parent.add_child(mi)
	if register and cutout != null:
		cutout.register_mesh(mi)
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0, 1)); st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1, 1)); st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0)); st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0, 1)); st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0)); st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0, 0)); st.add_vertex(d)


func spawn_quaternius(parent: Node3D, model_name: String, pos: Vector3, yaw_deg := 0.0, scl := Vector3.ONE, register := false, use_extra := true) -> Node3D:
	var path := (QUAT_EXTRA_DIR if use_extra else QUAT_STD_DIR) + model_name + ".scn"
	if not _quat_cache.has(path):
		_quat_cache[path] = load(path) as PackedScene
	var packed := _quat_cache[path] as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	node.name = model_name
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	node.scale = scl
	parent.add_child(node)
	_calibrate_industrial_node(node, register)
	return node


func _calibrate_industrial_node(root: Node, register: bool) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is StandardMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				if not _quat_mat_cache.has(mat):
					var cloned := mat.duplicate() as StandardMaterial3D
					cloned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
					cloned.albedo_color = Color(cloned.albedo_color.r * 0.68, cloned.albedo_color.g * 0.67, cloned.albedo_color.b * 0.64, cloned.albedo_color.a)
					cloned.roughness = maxf(cloned.roughness, 0.78)
					cloned.metallic = minf(cloned.metallic, 0.16)
					cloned.metallic_specular = 0.20
					_quat_mat_cache[mat] = cloned
				m.set_surface_override_material(s, _quat_mat_cache[mat])
		if register and cutout != null:
			cutout.register_mesh(m)


func make_directory_board_material() -> StandardMaterial3D:
	var key: Array=["directory_board"]
	var cached:=_cached_procedural(key)
	if cached!=null:return cached
	var w := 384
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("a5aba7"))
	_stroke_rect(img, 2, 2, w - 4, h - 4, Color("202529"))
	_fill_rect(img, 0, 0, w, 24, Color("1d2125"))
	_fill_rect(img, 14, 9, 148, 5, Color("c4a422"))
	_fill_rect(img, 272, 36, 96, 30, Color("561d23"))

	var dark := Color("20252a")
	var yellow := Color("c4a422")
	var bay_bg := Color("6e7578")
	_fill_rect(img, 18, 86, 146, 144, bay_bg)
	_stroke_rect(img, 18, 86, 146, 144, dark)
	_fill_rect(img, 30, 102, 88, 92, Color("2d3338"))
	_stroke_rect(img, 30, 102, 88, 92, yellow)

	_fill_rect(img, 192, 86, 174, 144, bay_bg)
	_stroke_rect(img, 192, 86, 174, 144, dark)
	_fill_rect(img, 202, 70, 128, 16, yellow)
	_fill_rect(img, 314, 70, 18, 148, yellow)
	_fill_rect(img, 332, 180, 28, 18, yellow)
	_fill_circle(img, 323, 188, 6, Color("9a2424"))

	# Weathering film, water streaks & scratched glass grime over directory signage
	for py in h:
		var v := float(py) / float(h - 1)
		for px in w:
			var u := float(px) / float(w - 1)
			var c := img.get_pixel(px, py)
			var grime := _fbm_periodic(u, v, 5, 811)
			var edge := maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
			var corner_stain := smoothstep(0.60, 0.96, edge) * smoothstep(0.35, 0.78, grime)
			var water_streak := smoothstep(0.58, 0.80, _fbm_periodic(u, v * 0.22, 8, 907)) * clampf(1.2 - v * 0.6, 0.0, 1.0) * 0.28
			c = c.lerp(Color("4c4234"), clampf(corner_stain * 0.65 + water_streak, 0.0, 0.55))
			if absf((u - 0.15) - (v - 0.4) * 0.45) < 0.004 and u > 0.12 and u < 0.48:
				c = c.lerp(Color("323639"), 0.55)
			img.set_pixel(px, py, c)

	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.74
	m.metallic = 0.06
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.12
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return _remember_procedural(key,m)


func _fill_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	for y in range(maxi(0, ry), mini(img.get_height(), ry + rh)):
		for x in range(maxi(0, rx), mini(img.get_width(), rx + rw)):
			img.set_pixel(x, y, col)


func _stroke_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	_fill_rect(img, rx, ry, rw, 2, col)
	_fill_rect(img, rx, ry + rh - 2, rw, 2, col)
	_fill_rect(img, rx, ry, 2, rh, col)
	_fill_rect(img, rx + rw - 2, ry, 2, rh, col)


func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var rr := r * r
	for y in range(maxi(0, cy - r), mini(img.get_height(), cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(img.get_width(), cx + r + 1)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rr:
				img.set_pixel(x, y, col)
