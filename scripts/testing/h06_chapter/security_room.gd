extends Node3D
## Room 206 (Monitoring & Records). Positions match the chapter plan; Y is relative to the upper deck.
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const SERVICE := preload("res://scripts/testing/h06_chapter/service_and_loading_art.gd")
const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const OFFICE := preload("res://scripts/dream/office_furniture_catalog.gd")
const DETAILS := preload("res://scripts/dream/office_detail_art.gd")
const KENNEY := "res://art/Dream/office_lowpoly/kenney/"
const FILE_DRAWERS := "res://scenes/dream/3d/props/filing_cabinet_01_visual_3d.tscn"
const CAMERA_FEEDS := preload("res://art/Dream/office_lowpoly/h06_camera_feeds.res")
const SECURITY_PBR_SHADER := preload("res://scripts/testing/h06_chapter/security_room_pbr.gdshader")
const PH_PRECAST_DIFF := "res://art/Dream/CC0/AtriumLoop11/polyhaven/precast_concrete_wall_diff_1k.jpg"
const PH_PRECAST_NOR := "res://art/Dream/CC0/AtriumLoop11/polyhaven/precast_concrete_wall_nor_gl_1k.jpg"
const PH_PRECAST_ROUGH := "res://art/Dream/CC0/AtriumLoop11/polyhaven/precast_concrete_wall_rough_1k.jpg"
const PH_PLASTER_DIFF := "res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Diffuse.res"
const PH_PLASTER_NOR := "res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_nor_gl.res"
const PH_PLASTER_ROUGH := "res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Rough.res"
const RL_WALNUT_DIFF := "res://art/Dream/ReceptionLobby/walnut_veneer/albedo.jpg"
const RL_WALNUT_NOR := "res://art/Dream/ReceptionLobby/walnut_veneer/normal.jpg"
const RL_WALNUT_ROUGH := "res://art/Dream/ReceptionLobby/walnut_veneer/roughness.jpg"
const RL_IRON_DIFF := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png"
const RL_IRON_NOR := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png"
const RL_IRON_ROUGH := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png"
const RL_IRON_MET := "res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Metallic.png"
const RL_MET12_DIFF := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Color.png"
const RL_MET12_NOR := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_NormalGL.png"
const RL_MET12_ROUGH := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Roughness.png"
const RL_MET12_MET := "res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Metalness.png"
const RL_STONE_DIFF := "res://art/Dream/ReceptionLobby/NaturalStone01/albedo.png"
const RL_STONE_NOR := "res://art/Dream/ReceptionLobby/NaturalStone01/normal.png"
const RL_STONE_ROUGH := "res://art/Dream/ReceptionLobby/NaturalStone01/roughness.png"
const RL_CABAN_DIFF := "res://art/Dream/ReceptionLobby/caban/diff.jpg"
const RL_CABAN_NOR := "res://art/Dream/ReceptionLobby/caban/nor_gl.jpg"
const RL_CABAN_ROUGH := "res://art/Dream/ReceptionLobby/caban/rough.jpg"
const CONSOLE_STRIP := Vector3(-1.55, 2.38, -22.14)
const FILE_STRIP := Vector3(3.85, 2.46, -22.14)
const SORT_LAMP := Vector3(5.32, 1.44, -13.86)

var kit: KIT
var fittings: FITTINGS
var overhead_diffusers: Array[MeshInstance3D] = []
var sage_green: Material
var enamel: Material
var charcoal: Material
var slate_mid: Material
var slate_light: Material
var desk_top_dark: Material
var desk_top_enamel: Material
var credenza_top: Material
var stone_sill: Material
var walnut: Material
var cork: Material
var olive_mat: Material
var worn_fabric: Material
var worn_fabric_prop: Material
var cardboard_outer: Material
var cardboard_inner: Material
var brushed_iron_prop: Material
var charcoal_prop: Material
var can_red: Material
var red_binder: Material
var manual_teal: Material
var green_led: Material
var caution_yellow: Material
var paper: Material
var steel_bright: Material
var cable_black: Material
var glass: Material
var smoked_glass: Material
var room_scuff_decal: Material
var _white_tex: Texture2D
var blind_pattern: Texture2D


func furnish(facility: FITTINGS, service: SERVICE) -> void:
	fittings = facility
	kit = facility.kit
	_prepare_finishes()

	_build_industrial_desk("CameraDesk", PLAN.WATCH_FIXTURES.CameraDesk, desk_top_enamel, slate_light)
	_build_industrial_desk("OperatorDesk", PLAN.WATCH_FIXTURES.OperatorDesk, desk_top_dark, slate_light)
	_build_industrial_desk("SortingDesk", PLAN.WATCH_FIXTURES.SortingDesk, credenza_top, slate_mid)

	for key: String in ["CameraChair", "OperatorChair"]:
		var r: Rect2 = PLAN.WATCH_FIXTURES[key]
		var c := r.get_center()
		var yaw := 162.0 if key == "OperatorChair" else 184.0
		var chair := fittings.fit(self, KENNEY + "chairDesk.glb", Vector3(c.x, .47, c.y), Vector3(r.size.x, .94, r.size.y), Vector3(0, yaw, 0))
		chair.name = key
		_paint_surface(chair, "carpet", worn_fabric_prop)
		_paint_surface(chair, "metalMedium", brushed_iron_prop)

	_build_west_monitoring()
	_build_hero_operator_island()
	_build_records_room(service)
	for key: String in ["RearPartition", "FrontPartition"]:
		_glazed_partition(PLAN.WATCH_FIXTURES[key])
	_build_overhead_strips()
	_build_stationery_decals()
	_build_room_weathering_decals()


func _prepare_finishes() -> void:
	if kit.dark_bulkhead == null:
		kit.prepare_atrium_finishes()
	if kit.decal_oil_stain == null:
		kit.prepare_atrium_weathering()
	var w_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	w_img.fill(Color.WHITE)
	_white_tex = ImageTexture.create_from_image(w_img)

	# Verified CC0 PBR textures (Poly Haven, cgbookcase, ambientCG) tuned to satin institutional Sevastopol lab enamel/laminate.
	var met12_mid := Vector3(0.679, 0.729, 0.789)
	sage_green = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("3c5a48"), 0.56, 2.0, true, Vector2(0.32, 0.58), 0.70, 0.22, 0.22, 0.0, Color("5a7363"), Color("1d2b22"), 0.036, 0.65)
	enamel = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("bec6bc"), 0.56, 2.2, true, Vector2(0.30, 0.56), 0.72, 0.22, 0.22, 0.0, Color("9aa39c"), Color("46524b"), 0.036, 0.65)
	charcoal = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("282e30"), 0.54, 2.2, true, Vector2(0.46, 0.78), 0.72, 0.18, 0.18, 0.0, Color("4a5256"), Color("161a1c"), 0.032, 0.55)
	slate_mid = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("9ca59d"), 0.56, 2.2, true, Vector2(0.32, 0.60), 0.72, 0.24, 0.22, 0.0, Color("7b847d"), Color("3c4540"), 0.036, 0.65)
	slate_light = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("cbd2c8"), 0.58, 2.0, true, Vector2(0.32, 0.58), 0.70, 0.20, 0.20, 0.0, Color("a2aba3"), Color("525d56"), 0.036, 0.60)
	desk_top_dark = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("c4cbc1"), 0.62, 1.9, true, Vector2(0.28, 0.54), 0.65, 0.16, 0.18, 0.0, Color("a0a89f"), Color("556058"), 0.034, 0.50)
	desk_top_enamel = _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("bcc4ba"), 0.62, 1.9, true, Vector2(0.28, 0.54), 0.65, 0.16, 0.18, 0.0, Color("9aa299"), Color("4f5a53"), 0.034, 0.50)

	var stone_mid := Vector3(0.590, 0.576, 0.558)
	credenza_top = _make_cc0_pbr(RL_STONE_DIFF, RL_STONE_NOR, RL_STONE_ROUGH, "", stone_mid, Color("c8cec4"), 0.96, 2.0, false, Vector2(0.36, 0.66), 0.65, 0.04, 0.18, 0.0, Color("9ba39b"), Color("565f59"), 0.032, 0.50)
	stone_sill = _make_cc0_pbr(RL_STONE_DIFF, RL_STONE_NOR, RL_STONE_ROUGH, "", stone_mid, Color("c2c8be"), 0.96, 2.0, false, Vector2(0.38, 0.68), 0.65, 0.04, 0.18, 0.0, Color("949c95"), Color("505853"), 0.032, 0.50)

	walnut = _make_cc0_pbr(RL_WALNUT_DIFF, RL_WALNUT_NOR, RL_WALNUT_ROUGH, "", Vector3(0.260, 0.143, 0.080), Color("855a3c"), 0.38, 3.2, false, Vector2(0.36, 0.68), 0.95, 0.02, 0.18, 0.0, Color("ae7b52"), Color("281b12"), 0.030, 0.45)
	steel_bright = _make_cc0_pbr(RL_IRON_DIFF, RL_IRON_NOR, RL_IRON_ROUGH, RL_IRON_MET, Vector3(0.544, 0.562, 0.562), Color("b4bec2"), 0.55, 2.8, false, Vector2(0.22, 0.52), 0.78, 0.86, 0.22, 0.0, Color("ccd4d8"), Color("3e4844"), 0.028, 0.50)
	brushed_iron_prop = _prop_override(steel_bright)
	charcoal_prop = _prop_override(charcoal)

	var caban_mid := Vector3(0.624, 0.132, 0.01)
	worn_fabric = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("44564e"), 0.35, 2.6, true, Vector2(0.76, 0.94), 0.72, 0.02, 0.16, 0.0, Color("313d37"), Color("1b2320"), 0.024, 0.45)
	worn_fabric_prop = _prop_override(worn_fabric)
	olive_mat = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("5a7366"), 0.28, 2.4, true, Vector2(0.70, 0.90), 0.62, 0.02, 0.14, 0.0, Color("45594f"), Color("233029"), 0.020, 0.40)
	cork = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("9a8668"), 0.26, 2.6, true, Vector2(0.84, 0.96), 0.75, 0.0, 0.14, 0.0, Color("b5a082"), Color("483c2b"), 0.024, 0.35)
	cardboard_outer = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("b49b7c"), 0.42, 2.4, true, Vector2(0.82, 0.96), 0.72, 0.0, 0.16, 0.0, Color("cbb394"), Color("4d3d2b"), 0.024, 0.0)
	cardboard_inner = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("8a7054"), 0.42, 2.4, true, Vector2(0.85, 0.97), 0.72, 0.0, 0.16, 0.0, Color("a28668"), Color("3a2b1c"), 0.024, 0.0)
	red_binder = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("9d3330"), 0.34, 2.2, true, Vector2(0.58, 0.84), 0.50, 0.02, 0.12, 0.0, Color("b44a46"), Color("481715"), 0.016, 0.0)
	manual_teal = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("4b6b5d"), 0.34, 2.2, true, Vector2(0.55, 0.82), 0.45, 0.02, 0.12, 0.0, Color("618373"), Color("23342c"), 0.016, 0.0)

	var plaster_mid := Vector3(0.060, 0.066, 0.074)
	paper = _make_cc0_pbr(PH_PLASTER_DIFF, PH_PLASTER_NOR, PH_PLASTER_ROUGH, "", plaster_mid, Color("dedcd0"), 0.72, 1.4, true, Vector2(0.86, 0.96), 0.24, 0.0, 0.12, 0.0, Color("eae8dc"), Color("a8a395"), 0.010, 0.25)
	can_red = _make_cc0_pbr(RL_IRON_DIFF, RL_IRON_NOR, RL_IRON_ROUGH, RL_IRON_MET, Vector3(0.544, 0.562, 0.562), Color("96322f"), 0.30, 2.4, true, Vector2(0.32, 0.58), 0.40, 0.35, 0.14, 0.0, Color("b9c2c7"), Color("351715"), 0.015, 0.0)
	cable_black = _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("202527"), 0.30, 2.0, true, Vector2(0.64, 0.88), 0.48, 0.06, 0.16, 0.0, Color("31373c"), Color("0f1113"), 0.015, 0.0)

	var led := StandardMaterial3D.new()
	led.albedo_color = Color("76f28e")
	led.emission_enabled = true
	led.emission = Color("5ce67a")
	led.emission_energy_multiplier = 2.4
	led.roughness = 0.22
	green_led = led

	caution_yellow = kit.endfield_yellow
	glass = kit.glass_corridor_rail
	var smoked := kit.glass_smoked_office.duplicate() as StandardMaterial3D
	smoked.roughness = 0.62
	smoked.metallic_specular = 0.08
	smoked.albedo_color = Color(0.08, 0.11, 0.13, 0.72)
	smoked_glass = smoked

	room_scuff_decal = _make_room_decal("scuff", Color("38433e"), Color("7b867f"), 0.14, 0.88)


func _make_cc0_pbr(albedo_path: String, nor_path: String, rough_path: String, met_path: String, tex_mid: Vector3, tint: Color, repeat_m: float, contrast: float, luma_only: bool, rough_range: Vector2, nor_str: float, metallic: float, wear: float, rust: float, substrate: Color, grime: Color, edge_band_val: float = 0.042, edge_wear_val: float = 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SECURITY_PBR_SHADER
	mat.set_shader_parameter(&"finish_albedo", load(albedo_path))
	mat.set_shader_parameter(&"finish_normal", load(nor_path))
	mat.set_shader_parameter(&"finish_roughness", load(rough_path))
	mat.set_shader_parameter(&"finish_metalness", _white_tex if met_path.is_empty() else load(met_path))
	mat.set_shader_parameter(&"tex_midpoint", tex_mid)
	mat.set_shader_parameter(&"finish_colour", tint)
	mat.set_shader_parameter(&"repeat_metres", repeat_m)
	mat.set_shader_parameter(&"albedo_contrast", contrast)
	mat.set_shader_parameter(&"luma_only", 1.0 if luma_only else 0.0)
	mat.set_shader_parameter(&"roughness_range", rough_range)
	mat.set_shader_parameter(&"normal_strength", nor_str)
	mat.set_shader_parameter(&"metallic_level", metallic)
	mat.set_shader_parameter(&"wear_amount", wear)
	mat.set_shader_parameter(&"rust_amount", rust)
	mat.set_shader_parameter(&"exposed_substrate", substrate)
	mat.set_shader_parameter(&"grime_colour", grime)
	mat.set_shader_parameter(&"edge_band", edge_band_val)
	mat.set_shader_parameter(&"edge_wear", edge_wear_val)
	return mat


func _prop_override(base_mat: Material) -> Material:
	var m := (base_mat as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter(&"edge_wear", 0.0)
	return m


func _make_room_decal(kind: String, primary: Color, secondary: Color, alpha_scale: float, rough: float) -> StandardMaterial3D:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var seed_v := hash("sr_decal_" + kind)
	for y in size:
		var v := float(y) / float(size)
		for x in size:
			var u := float(x) / float(size)
			var centered := Vector2(u - 0.5, v - 0.5) * 2.0
			var edge_fade := 1.0 - smoothstep(0.45, 0.98, centered.length())
			var broad := kit._fbm_periodic(u, v, 4, seed_v)
			var fine := kit._fbm_periodic(u, v, 10, seed_v + 31)
			var col := primary
			var a := 0.0
			if kind == "scuff":
				var track_a := 1.0 - smoothstep(0.03, 0.14, absf(v - 0.34 + (broad - 0.5) * 0.28))
				var track_b := 1.0 - smoothstep(0.03, 0.14, absf(v - 0.64 + (fine - 0.5) * 0.28))
				var streak_var := 0.45 + 0.55 * fine
				var dust := smoothstep(0.46, 0.80, broad) * 0.26
				col = primary.lerp(secondary, clampf(dust * 1.4, 0.0, 0.65))
				a = clampf(((track_a + track_b) * 0.75 * streak_var + dust) * edge_fade, 0.0, 1.0)
			elif kind == "spill":
				var dist := centered.length() + (broad - 0.5) * 0.42
				var pool := 1.0 - smoothstep(0.42, 0.78, dist)
				var rim := smoothstep(0.50, 0.62, dist) * (1.0 - smoothstep(0.68, 0.80, dist))
				col = primary.lerp(secondary, rim * 0.85 + fine * 0.25)
				a = clampf(maxf(pool * 0.82, rim * 0.95) * (1.0 - smoothstep(0.75, 1.0, centered.length())), 0.0, 1.0)
			elif kind == "rust":
				var bloom := smoothstep(0.32, 0.76, broad * 0.58 + fine * 0.42)
				col = primary.lerp(secondary, smoothstep(0.48, 0.84, fine))
				a = clampf(bloom * edge_fade * 1.15, 0.0, 1.0)
			else:
				var col_noise := kit._fbm_periodic(u * 3.0, v * 0.25, 6, seed_v + 17)
				var streak := smoothstep(0.38, 0.76, col_noise * 0.68 + fine * 0.32)
				var top_heavy := smoothstep(1.0, 0.05, v)
				var side_fade := 1.0 - smoothstep(0.55, 0.98, absf(u - 0.5) * 2.0)
				col = primary.lerp(secondary, smoothstep(0.45, 0.82, fine))
				a = clampf(streak * top_heavy * side_fade * 1.15, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a * alpha_scale, 0.0, 0.92)))
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = rough
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.metallic_specular = 0.45 if kind == "spill" else 0.14
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _build_industrial_desk(title: String, r: Rect2, top_mat: Material, body_mat: Material) -> void:
	var c := r.get_center()
	var h := 0.80
	var root := Node3D.new()
	root.name = title
	add_child(root)
	# Clinical cream-putty desktop + dark rubberized perimeter bumper + recessed left hardware bay.
	kit.box(root, "Desktop", Vector3(r.size.x, 0.056, r.size.y), Vector3(c.x, h - 0.028, c.y), top_mat)
	kit.box(root, "DesktopTrim", Vector3(r.size.x + 0.014, 0.024, r.size.y + 0.014), Vector3(c.x, h - 0.062, c.y), charcoal)
	kit.box(root, "Apron", Vector3(r.size.x - 0.14, 0.075, r.size.y - 0.18), Vector3(c.x, h - 0.105, c.y), slate_mid)
	var ped_w := clampf(r.size.x * 0.23, 0.46, 0.68)
	for side: int in [-1, 1]:
		var px := c.x + side * (r.size.x * 0.5 - ped_w * 0.5 - 0.08)
		kit.box(root, "PedestalPlinth", Vector3(ped_w - 0.04, 0.08, r.size.y - 0.18), Vector3(px, 0.04, c.y), charcoal)
		kit.box(root, "Pedestal", Vector3(ped_w, h - 0.14, r.size.y - 0.14), Vector3(px, 0.08 + (h - 0.14) * 0.5, c.y), body_mat)
		if side == -1 and r.size.x > 1.8:
			# Left recessed oscilloscope/instrument bay with brushed trim and indicator readout.
			kit.box(root, "PedInstrFrame", Vector3(ped_w - 0.10, 0.44, 0.028), Vector3(px, 0.40, r.end.y - 0.064), charcoal)
			kit.box(root, "PedInstrLeftBezel", Vector3(ped_w * 0.24, 0.34, 0.018), Vector3(px - ped_w * 0.24, 0.40, r.end.y - 0.048), slate_mid)
			kit.box(root, "PedInstrScreen", Vector3(ped_w * 0.44, 0.32, 0.016), Vector3(px + ped_w * 0.12, 0.40, r.end.y - 0.048), cable_black)
			kit.box(root, "PedInstrLed", Vector3(0.024, 0.024, 0.018), Vector3(px - ped_w * 0.24, 0.50, r.end.y - 0.036), green_led)
		else:
			for row in 3:
				var dy := 0.21 + row * 0.185
				kit.box(root, "DrawerFace", Vector3(ped_w - 0.06, 0.155, 0.022), Vector3(px, dy, r.end.y - 0.065), enamel)
				kit.box(root, "DrawerPull", Vector3(ped_w * 0.38, 0.018, 0.028), Vector3(px, dy + 0.026, r.end.y - 0.052), steel_bright)


func _build_west_monitoring() -> void:
	# Under-window unit with clean putty enamel upper + sage green lower plinth + stone sill.
	var hr: Rect2 = PLAN.WATCH_FIXTURES.WindowHeater
	var hc := hr.get_center()
	kit.box(self, "WindowCabinetBody", Vector3(hr.size.x, 0.44, hr.size.y), Vector3(hc.x, 0.54, hc.y), enamel)
	kit.box(self, "WindowCabinetDado", Vector3(hr.size.x + 0.01, 0.32, hr.size.y + 0.01), Vector3(hc.x, 0.16, hc.y), sage_green)
	kit.box(self, "WindowSill", Vector3(hr.size.x + 0.06, 0.045, hr.size.y + 0.06), Vector3(hc.x, 0.78, hc.y), stone_sill)
	for i in 5:
		kit.box(self, "RadiatorLouvre", Vector3(0.28, 0.32, 0.02), Vector3(hc.x - 0.55 + i * 0.34, 0.52, hr.end.y + 0.008), steel_bright)

	# Venetian blind window + clean putty slats + center mullion.
	var blind := Vector3(-8.92, 1.55, -22.34)
	kit.box(self, "BlindBacking", Vector3(2.38, 1.12, 0.05), blind + Vector3(0, 0, -0.02), slate_light)
	kit.box(self, "BlindRecess", Vector3(2.38, 1.12, 0.07), blind, charcoal)
	kit.box(self, "BlindMullion", Vector3(0.055, 1.12, 0.11), blind + Vector3(0, 0, 0.05), steel_bright)
	for i in 11:
		var louvre := kit.box(self, "BlindSlat", Vector3(2.26, 0.052, 0.095), blind + Vector3(0, -0.49 + i * 0.098, 0.07), slate_light)
		louvre.rotation.x = -0.25
	for offset: float in [-0.82, 0.82]:
		kit.box(self, "LadderTape", Vector3(0.018, 1.06, 0.016), blind + Vector3(offset, 0, 0.135), paper)

	# Framed "生行" calligraphy plaque mounted cleanly above the Venetian blinds.
	var sign_pos := Vector3(-8.92, 2.24, -22.29)
	kit.box(self, "SignFrameOuter", Vector3(1.06, 0.34, 0.036), sign_pos, walnut)
	kit.box(self, "SignPaper", Vector3(0.96, 0.25, 0.042), sign_pos + Vector3(0, 0, 0.004), paper)
	var sign_lbl := Label3D.new()
	sign_lbl.name = "CalligraphyLabel"
	sign_lbl.text = "生  行"
	sign_lbl.font_size = 42
	sign_lbl.pixel_size = 0.0042
	sign_lbl.outline_size = 0
	sign_lbl.modulate = Color("23272b")
	sign_lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign_lbl.position = sign_pos + Vector3(0, -0.01, 0.030)
	add_child(sign_lbl)

	# Exhaust unit + PA loudspeaker horn high on west monitoring wall.
	var blower_pos := Vector3(-9.82, 1.00, -21.92)
	kit.box(self, "ExhaustBlower", Vector3(0.56, 0.42, 0.46), blower_pos, slate_light)
	kit.cylinder(self, "BlowerIntake", 0.145, 0.05, blower_pos + Vector3(0, 0.01, 0.235), charcoal, Vector3.BACK)
	kit.cylinder(self, "BlowerHub", 0.055, 0.06, blower_pos + Vector3(0, 0.01, 0.242), enamel, Vector3.BACK)
	_cable_chain([
		Vector3(-9.84, 1.20, -21.95),
		Vector3(-9.94, 1.48, -22.02),
		Vector3(-9.96, 1.78, -22.10),
		Vector3(-9.82, 1.98, -22.19),
		Vector3(-9.54, 1.98, -22.24),
	], 0.048, charcoal)
	_build_pa_horn(Vector3(-10.12, 2.18, -20.85), Vector3(0.0, -32.0, -14.0))

	# North-center CameraDesk monitors (2 feeds) + keyboards + tidy lab items.
	_screen(Vector3(-2.36, 0.80, -21.74), 0, 8.0)
	_screen(Vector3(-0.98, 0.80, -21.78), 1, -9.0)
	fittings.fit(self, KENNEY + "computerKeyboard.scn", Vector3(-1.66, 0.84, -21.26), Vector3(0.57, 0.065, 0.21))
	kit.box(self, "ConsoleNotePad", Vector3(0.24, 0.014, 0.30), Vector3(-2.98, 0.81, -21.40), manual_teal)
	kit.box(self, "ConsoleOpenSheet", Vector3(0.20, 0.010, 0.26), Vector3(-2.72, 0.81, -21.34), paper)
	kit.cylinder(self, "ConsoleMug", 0.042, 0.095, Vector3(-0.46, 0.85, -21.38), slate_light)

	# Tall clean Sevastopol cream-and-sage louvered locker in NE corner next to partition.
	_build_utility_fridge(PLAN.WATCH_FIXTURES.UtilityFridge)

	# West wall recorder server racks + louvered locker trim.
	var rack: Rect2 = PLAN.WATCH_FIXTURES.EquipmentRack
	for i in 2:
		var unit := OFFICE.make_visual("server", true)
		unit.name = "RecorderRack"
		add_child(unit)
		unit.rotation.y = PI * 0.5
		unit.scale = Vector3(0.83, 1.0, 0.96)
		unit.position = Vector3(rack.get_center().x, 0.0, rack.position.y + 0.45 + 0.86 * i)
		kit.cutout.register_tree(unit)


func _build_utility_fridge(r: Rect2) -> void:
	var c := r.get_center()
	var h := 2.04
	var fridge := Node3D.new()
	fridge.name = "UtilityFridge"
	add_child(fridge)
	kit.box(fridge, "FridgeBody", Vector3(r.size.x, h - 0.69, r.size.y), Vector3(c.x, 0.69 + (h - 0.69) * 0.5, c.y), slate_light, true)
	kit.box(fridge, "FridgeDadoBand", Vector3(r.size.x + 0.008, 0.69, r.size.y + 0.008), Vector3(c.x, 0.345, c.y), sage_green, true)
	for row_y: float in [1.74, 1.82, 1.90]:
		kit.box(fridge, "FridgeTopVent", Vector3(r.size.x * 0.62, 0.028, 0.02), Vector3(c.x, row_y, r.end.y + 0.008), charcoal, true)
	for dy: float in [0.69, 1.42]:
		kit.box(fridge, "FridgeDoorSeam", Vector3(r.size.x - 0.02, 0.020, 0.02), Vector3(c.x, dy, r.end.y + 0.008), charcoal, true)
	for handle_y: float in [0.98, 1.56]:
		kit.box(fridge, "FridgeHandle", Vector3(0.032, 0.22, 0.032), Vector3(r.position.x + 0.14, handle_y, r.end.y + 0.018), charcoal, true)
	kit.box(fridge, "FridgeLatchPlate", Vector3(0.11, 0.07, 0.018), Vector3(r.position.x + 0.16, 1.24, r.end.y + 0.012), slate_mid)


func _build_hero_operator_island() -> void:
	# Security Monitor #3 (keeps exact total CameraPicture count = 3) in sloped cream Sevastopol casing.
	_screen(Vector3(-2.30, 0.80, -16.12), 0, -4.0)
	fittings.fit(self, KENNEY + "computerKeyboard.scn", Vector3(-2.30, 0.84, -15.58), Vector3(0.57, 0.065, 0.21))

	# Clean left field telemetry console + tidy archival binder stack on west wing of OperatorDesk.
	var tele_pos := Vector3(-3.68, 0.96, -15.92)
	kit.box(self, "TelemetryConsole", Vector3(0.54, 0.32, 0.42), tele_pos, slate_light)
	kit.box(self, "TelemetryBaseTrim", Vector3(0.56, 0.04, 0.44), Vector3(-3.68, 0.82, -15.92), charcoal)
	kit.box(self, "TelemetryFace", Vector3(0.42, 0.19, 0.02), tele_pos + Vector3(0, 0.02, 0.21), charcoal)
	kit.box(self, "TelemetryGlow", Vector3(0.22, 0.11, 0.016), tele_pos + Vector3(-0.06, 0.02, 0.222), kit.monitor_glow)
	kit.box(self, "TelemetryLed", Vector3(0.024, 0.024, 0.018), tele_pos + Vector3(0.14, 0.04, 0.222), green_led)
	kit.box(self, "DeskRadioBox", Vector3(0.32, 0.12, 0.22), Vector3(-3.30, 0.86, -15.48), slate_mid)
	kit.box(self, "DeskRadioFace", Vector3(0.26, 0.07, 0.016), Vector3(-3.30, 0.86, -15.365), charcoal)

	# Clamped gooseneck desk lamp left of the CRT + silver mugs + muted sage workstation pad.
	_build_gooseneck_lamp(Vector3(-2.98, 0.80, -15.96))
	kit.cylinder(self, "DeskMugMain", 0.042, 0.095, Vector3(-2.82, 0.85, -15.58), slate_light)
	kit.cylinder(self, "DeskMugSmall", 0.036, 0.075, Vector3(-2.72, 0.84, -15.48), charcoal)
	kit.box(self, "OliveDeskMat", Vector3(0.76, 0.010, 0.50), Vector3(-2.30, 0.805, -15.44), olive_mat)
	for i in 3:
		var layer := kit.box(self, "MessyPaper_%d" % i, Vector3(0.24, 0.010, 0.30), Vector3(-3.04, 0.808 + i * 0.011, -15.42), paper)
		layer.rotation.y = -0.14 + float(i) * 0.11

	# Right of hero CRT: iconic glowing green Status Beacon post + steel lab canisters + teal manual.
	var beacon := Vector3(-1.74, 0.80, -15.96)
	kit.box(self, "BeaconBase", Vector3(0.18, 0.055, 0.18), beacon + Vector3(0, 0.028, 0), charcoal)
	kit.cylinder(self, "BeaconShaft", 0.026, 0.34, beacon + Vector3(0, 0.21, 0), steel_bright)
	kit.cylinder(self, "BeaconCollar", 0.048, 0.04, beacon + Vector3(0, 0.37, 0), charcoal)
	kit.cylinder(self, "BeaconGreenLight", 0.032, 0.055, beacon + Vector3(0, 0.415, 0), green_led)
	for cx: float in [-1.58, -1.48]:
		kit.cylinder(self, "DeskCanister", 0.038, 0.11, Vector3(cx, 0.855, -15.86 + (cx + 1.58) * 0.3), steel_bright)
	kit.box(self, "DeskManualCover", Vector3(0.24, 0.018, 0.30), Vector3(-1.54, 0.812, -15.40), manual_teal)
	kit.box(self, "DeskManualPages", Vector3(0.22, 0.012, 0.28), Vector3(-1.54, 0.822, -15.40), paper)

	# Central Structural Column in cream-putty + sage green dado + Wall Clock + Intercom + PA Horn.
	var col_x := -1.32
	var col_z := -16.22
	kit.box(self, "PowerColumnPlinth", Vector3(0.28, 0.07, 0.28), Vector3(col_x, 0.035, col_z), charcoal, true)
	kit.box(self, "PowerColumnDado", Vector3(0.25, 0.62, 0.25), Vector3(col_x, 0.38, col_z), sage_green, true)
	kit.box(self, "PowerColumn", Vector3(0.24, 1.66, 0.24), Vector3(col_x, 1.52, col_z), slate_light, true)
	kit.box(self, "PowerColumnCap", Vector3(0.30, 0.06, 0.30), Vector3(col_x, 2.38, col_z), charcoal, true)
	_wall_clock(Vector3(col_x, 2.02, col_z + 0.145))
	_build_pa_horn(Vector3(col_x - 0.18, 2.16, col_z + 0.02), Vector3(0.0, 125.0, -14.0))

	kit.box(self, "ColumnOutletStrip", Vector3(0.16, 0.34, 0.06), Vector3(col_x, 1.48, col_z + 0.145), enamel)
	for i in 3:
		kit.box(self, "OutletSocket_%d" % i, Vector3(0.085, 0.045, 0.018), Vector3(col_x, 1.38 + i * 0.085, col_z + 0.172), charcoal)
	kit.box(self, "ColumnBreakerBox", Vector3(0.20, 0.24, 0.09), Vector3(col_x, 1.06, col_z + 0.145), slate_mid)
	kit.box(self, "ColumnBreakerLed", Vector3(0.022, 0.022, 0.016), Vector3(col_x + 0.055, 1.12, col_z + 0.186), green_led)

	_cable_chain([
		Vector3(col_x - 0.02, 1.42, col_z + 0.17),
		Vector3(col_x - 0.14, 1.15, col_z + 0.24),
		Vector3(col_x - 0.28, 0.92, col_z + 0.36),
		Vector3(-1.72, 0.82, -15.96),
	], 0.012, cable_black)

	# Cream-putty Copier / Scanner + neat trashcan beside desk island.
	_build_copier_unit(PLAN.WATCH_FIXTURES.CopierUnit)
	var desk_bin := fittings.fit(self, KENNEY + "trashcan.glb", Vector3(-4.26, 0.25, -15.32), Vector3(0.38, 0.50, 0.38))
	desk_bin.name = "DeskWasteBin"
	_paint_surface(desk_bin, "metal", brushed_iron_prop)
	_paint_surface(desk_bin, "metalDark", charcoal_prop)


func _build_gooseneck_lamp(at: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "DeskGooseneckLamp"
	add_child(lamp)
	kit.cylinder(lamp, "LampFoot", 0.068, 0.032, at + Vector3(0, 0.016, 0), charcoal)
	_cable_chain([
		at + Vector3(0.0, 0.03, 0.0),
		at + Vector3(-0.04, 0.18, -0.02),
		at + Vector3(-0.02, 0.34, 0.02),
		at + Vector3(0.08, 0.41, 0.07),
	], 0.012, steel_bright)
	var head := Node3D.new()
	head.position = at + Vector3(0.11, 0.39, 0.09)
	head.rotation = Vector3(deg_to_rad(32.0), deg_to_rad(28.0), 0.0)
	lamp.add_child(head)
	kit.cylinder(head, "LampShade", 0.052, 0.125, Vector3.ZERO, slate_light, Vector3.FORWARD)
	kit.cylinder(head, "LampGlowRim", 0.046, 0.018, Vector3(0, 0, 0.062), paper, Vector3.FORWARD)


func _build_pa_horn(at: Vector3, rot_deg: Vector3) -> void:
	var horn := Node3D.new()
	horn.name = "PAHorn"
	horn.position = at
	horn.rotation_degrees = rot_deg
	add_child(horn)
	kit.box(horn, "HornBracket", Vector3(0.06, 0.16, 0.06), Vector3(0, 0.02, -0.10), charcoal)
	kit.cylinder(horn, "HornDriver", 0.058, 0.14, Vector3(0, 0, -0.02), charcoal, Vector3.BACK)
	kit.cylinder(horn, "HornNeck", 0.082, 0.10, Vector3(0, 0, 0.08), slate_mid, Vector3.BACK)
	kit.cylinder(horn, "HornBell", 0.128, 0.09, Vector3(0, 0, 0.15), charcoal, Vector3.BACK)


func _build_desk_pistol(_at: Vector3, _yaw_deg: float) -> void:
	pass


func _build_open_laptop(_at: Vector3, _yaw_deg: float) -> void:
	pass


func _build_copier_unit(r: Rect2) -> void:
	var c := r.get_center()
	var copier := Node3D.new()
	copier.name = "CopierUnit"
	add_child(copier)
	kit.box(copier, "CopierBase", Vector3(r.size.x, 0.14, r.size.y - 0.10), Vector3(c.x, 0.07, c.y), charcoal)
	kit.box(copier, "CopierLowerDado", Vector3(r.size.x - 0.01, 0.24, r.size.y - 0.11), Vector3(c.x, 0.26, c.y), sage_green)
	kit.box(copier, "CopierBody", Vector3(r.size.x, 0.34, r.size.y - 0.10), Vector3(c.x, 0.54, c.y), slate_light)
	kit.box(copier, "CopierMidTrim", Vector3(r.size.x + 0.02, 0.05, r.size.y - 0.08), Vector3(c.x, 0.72, c.y), charcoal)
	kit.box(copier, "CopierScannerDeck", Vector3(r.size.x - 0.06, 0.12, r.size.y - 0.16), Vector3(c.x - 0.02, 0.80, c.y - 0.02), enamel)
	kit.box(copier, "CopierFeederLid", Vector3(r.size.x - 0.16, 0.08, r.size.y - 0.26), Vector3(c.x - 0.05, 0.90, c.y - 0.03), slate_light)
	for y_seam: float in [0.28, 0.50]:
		kit.box(copier, "CopierTrayLine", Vector3(r.size.x - 0.14, 0.016, 0.02), Vector3(c.x, y_seam, r.end.y - 0.042), charcoal)
	kit.box(copier, "CopierOutputStack", Vector3(0.24, 0.028, 0.32), Vector3(r.end.x - 0.06, 0.68, c.y + 0.12), paper)
	kit.box(copier, "CopierStatusLed", Vector3(0.035, 0.022, 0.022), Vector3(c.x + 0.22, 0.85, r.end.y - 0.12), green_led)
	var touch := kit.box(copier, "CopierTouchScreen", Vector3(0.22, 0.04, 0.16), Vector3(r.end.x - 0.10, 0.85, r.end.y - 0.22), kit.monitor_glow)
	touch.rotation.x = 0.45

	_cable_chain([
		Vector3(r.end.x, 0.06, c.y + 0.25),
		Vector3(r.end.x + 0.32, 0.015, c.y + 0.38),
		Vector3(1.10, 0.015, -14.85),
		Vector3(1.68, 0.015, -14.95),
		Vector3(2.38, 0.015, -15.32),
	], 0.014, cable_black)


func _build_records_room(service: SERVICE) -> void:
	# Clean cream-putty Sevastopol steel filing & cupboard bank on the right sage floor zone.
	var cr: Rect2 = PLAN.WATCH_FIXTURES.CredenzaBank
	var cc := cr.get_center()
	var left_w := cr.size.x * 0.44
	var left_x := cr.position.x + left_w * 0.5
	var right_w := cr.size.x * 0.54
	var right_x := cr.end.x - right_w * 0.5
	kit.box(self, "CredenzaPlinth", Vector3(cr.size.x - 0.04, 0.06, cr.size.y - 0.06), Vector3(cc.x, 0.03, cc.y), charcoal)
	kit.box(self, "CredenzaCabinetLeft", Vector3(left_w, 0.76, cr.size.y), Vector3(left_x, 0.44, cc.y), slate_light)
	kit.box(self, "CredenzaCabinetRight", Vector3(right_w, 0.76, cr.size.y), Vector3(right_x, 0.44, cc.y), slate_light)
	kit.box(self, "CredenzaCounterTop", Vector3(cr.size.x + 0.05, 0.04, cr.size.y + 0.05), Vector3(cc.x, 0.84, cc.y), credenza_top)

	# Left filing module: slim closed upper drawer + lower drawer pulled ajar revealing folders.
	kit.box(self, "CredenzaLeftTopDrawer", Vector3(left_w - 0.08, 0.16, 0.024), Vector3(left_x, 0.69, cr.end.y + 0.008), enamel)
	kit.box(self, "CredenzaLeftTopPull", Vector3(0.24, 0.022, 0.028), Vector3(left_x, 0.70, cr.end.y + 0.024), steel_bright)
	kit.box(self, "CredenzaAjarRecess", Vector3(left_w - 0.12, 0.42, 0.06), Vector3(left_x, 0.34, cr.end.y - 0.01), charcoal)
	var ajar_z := cr.end.y + 0.24
	kit.box(self, "CredenzaAjarSideL", Vector3(0.024, 0.28, 0.32), Vector3(left_x - left_w * 0.42, 0.28, cr.end.y + 0.08), slate_mid)
	kit.box(self, "CredenzaAjarSideR", Vector3(0.024, 0.28, 0.32), Vector3(left_x + left_w * 0.42, 0.28, cr.end.y + 0.08), slate_mid)
	kit.box(self, "CredenzaAjarFront", Vector3(left_w - 0.10, 0.36, 0.03), Vector3(left_x, 0.32, ajar_z), enamel)
	kit.box(self, "CredenzaAjarPull", Vector3(0.24, 0.022, 0.03), Vector3(left_x, 0.38, ajar_z + 0.02), steel_bright)
	for fi in 6:
		var folder_mat := red_binder if fi % 3 == 0 else (manual_teal if fi % 3 == 1 else paper)
		kit.box(self, "AjarFolder_%d" % fi, Vector3(left_w - 0.24, 0.24, 0.028), Vector3(left_x, 0.33, cr.end.y + 0.04 + fi * 0.032), folder_mat)

	# Right filing module: 3 horizontal drawers on top + 2 neat vertical cupboard doors below.
	for row in 3:
		var dy := 0.70 - row * 0.125
		kit.box(self, "CredenzaDrawer_%d" % row, Vector3(right_w - 0.08, 0.105, 0.024), Vector3(right_x, dy, cr.end.y + 0.008), enamel)
		kit.box(self, "CredenzaDrawerPull_%d" % row, Vector3(0.24, 0.018, 0.028), Vector3(right_x, dy, cr.end.y + 0.022), steel_bright)
	for di in 2:
		var dx := right_x + (di - 0.5) * (right_w * 0.48)
		kit.box(self, "CredenzaDoor_%d" % di, Vector3(right_w * 0.45, 0.29, 0.024), Vector3(dx, 0.22, cr.end.y + 0.008), enamel)
		kit.box(self, "CredenzaHandle_%d" % di, Vector3(0.024, 0.09, 0.026), Vector3(dx + (0.14 if di == 0 else -0.14), 0.24, cr.end.y + 0.022), steel_bright)

	# Retro-clinical desktop equipment atop CredenzaBank (compact CRT unit + tape deck + binders + lab bottles).
	var pc_pos := Vector3(3.26, 0.86, -21.86)
	kit.box(self, "RecordsPCBase", Vector3(0.56, 0.12, 0.40), pc_pos + Vector3(0, 0.06, -0.04), slate_light)
	kit.box(self, "RecordsPCMonitor", Vector3(0.46, 0.34, 0.32), pc_pos + Vector3(0, 0.29, -0.05), enamel)
	kit.box(self, "RecordsPCBezel", Vector3(0.38, 0.26, 0.03), pc_pos + Vector3(0, 0.29, 0.115), charcoal)
	kit.box(self, "RecordsPCLed", Vector3(0.025, 0.022, 0.02), pc_pos + Vector3(0.20, 0.07, 0.165), green_led)
	kit.box(self, "RecordsTapeDeck", Vector3(0.48, 0.14, 0.28), Vector3(4.28, 0.93, -21.86), charcoal)
	kit.box(self, "RecordsTapeFace", Vector3(0.42, 0.09, 0.02), Vector3(4.28, 0.93, -21.715), slate_mid)
	kit.box(self, "RecordsDeckFiles", Vector3(0.38, 0.16, 0.30), Vector3(2.34, 0.94, -21.84), manual_teal)
	kit.box(self, "RecordsDeckTopSheets", Vector3(0.32, 0.04, 0.26), Vector3(2.34, 1.04, -21.84), paper)
	for bi in 2:
		kit.box(self, "RecordBinderBox_%d" % bi, Vector3(0.24, 0.34, 0.30), Vector3(4.84 + bi * 0.26, 1.03, -21.88), slate_light if bi == 0 else red_binder)
	var water := OFFICE.make_visual("water_dispenser", true)
	water.name = "WaterDispenser"
	add_child(water)
	water.position = Vector3(5.50, 0.86, -21.84)
	water.scale = Vector3(0.84, 0.68, 0.84)

	# Clean 3x2 cream-putty recessed modular wall cubbies + wall intercom + ceiling vent above Credenza.
	var cubby_z := -22.24
	kit.box(self, "UpperCubbyHousing", Vector3(2.58, 0.86, 0.22), Vector3(3.60, 1.72, cubby_z - 0.06), slate_mid, true)
	kit.box(self, "UpperVentHeader", Vector3(2.58, 0.22, 0.22), Vector3(3.60, 2.28, cubby_z - 0.06), slate_light, true)
	for ci in 6:
		var col := ci % 3
		var row := ci / 3
		var cx := 2.78 + col * 0.82
		var cy := 1.92 - row * 0.40
		kit.box(self, "CubbyRecess_%d" % ci, Vector3(0.74, 0.34, 0.04), Vector3(cx, cy, cubby_z + 0.04), charcoal)
		kit.box(self, "CubbyDoor_%d" % ci, Vector3(0.68, 0.30, 0.04), Vector3(cx, cy, cubby_z + 0.06), slate_light)
		kit.box(self, "CubbySlot_%d" % ci, Vector3(0.26, 0.042, 0.025), Vector3(cx, cy + 0.08, cubby_z + 0.082), charcoal)
	kit.box(self, "EastWallIntercom", Vector3(0.28, 0.36, 0.05), Vector3(5.26, 1.56, -22.34), enamel)
	kit.box(self, "EastWallIntercomGrille", Vector3(0.18, 0.14, 0.02), Vector3(5.26, 1.62, -22.31), charcoal)
	kit.box(self, "EastWallIntercomLed", Vector3(0.025, 0.025, 0.02), Vector3(5.20, 1.46, -22.31), green_led)

	# Clean steel shelving bays (`RecordStacks`) + muted cartons on NE/East walls (keeping exact colliders).
	var cage: Rect2 = PLAN.WATCH_FIXTURES.RecordStacks
	var bay := cage.size.x / 2.0
	for i in 2:
		var bx := cage.position.x + (i + 0.5) * bay
		var bz := cage.get_center().y
		kit.box(self, "LockerTopCap", Vector3(bay - 0.04, 0.08, cage.size.y), Vector3(bx, 2.10, bz), slate_light, true)
		kit.box(self, "LockerSideLeft", Vector3(0.06, 2.12, cage.size.y), Vector3(bx - bay * 0.48, 1.06, bz), slate_mid, true)
		kit.box(self, "LockerSideRight", Vector3(0.06, 2.12, cage.size.y), Vector3(bx + bay * 0.48, 1.06, bz), slate_mid, true)
		for tier: int in [0, 1, 2]:
			var level := 0.12 + tier * 0.62
			kit.box(self, "LockerShelf", Vector3(bay - 0.08, 0.05, cage.size.y - 0.06), Vector3(bx, level, bz), slate_mid)
			_paint_cardboard(fittings.fit(self, KENNEY + "cardboardBoxClosed.glb", Vector3(bx - 0.18, level + 0.22, bz), Vector3(0.56, 0.36, 0.54)))
			fittings.fit(self, KENNEY + "books.scn", Vector3(bx + 0.26, level + 0.18, bz + 0.04), Vector3(0.32, 0.30, 0.40))
		service.mesh_panel(self, Vector2(bx - bay * 0.45, cage.end.y + 0.02), Vector2(bx + bay * 0.45, cage.end.y + 0.02), 0.58, 1.98, 0.20)
		kit.box(self, "LockerLowerSolid", Vector3(bay - 0.08, 0.48, 0.04), Vector3(bx, 0.26, cage.end.y), sage_green)
		kit.box(self, "KeepOutTape", Vector3(bay - 0.06, 0.07, 0.03), Vector3(bx, 0.58, cage.end.y + 0.035), enamel)
		_paint_cardboard(fittings.fit(self, KENNEY + "cardboardBoxClosed.glb", Vector3(bx - 0.04, 2.34, bz + 0.02), Vector3(0.92, 0.40, 0.64)))

	# East wall wire-mesh rack + filing drawer units (`DrawerBank`).
	var drawers: Rect2 = PLAN.WATCH_FIXTURES.DrawerBank
	for i in 3:
		var z := drawers.end.y - (i + 0.5) * 0.96
		var cabinet := fittings.fit(self, FILE_DRAWERS, Vector3(drawers.get_center().x, 0.71, z), Vector3(0.84, 1.42, 0.92), Vector3(0, -90, 0))
		kit.cutout.register_tree(cabinet)
	var east_cage_z := drawers.position.y + 0.95
	kit.box(self, "EastCageTop", Vector3(0.88, 0.08, 1.80), Vector3(drawers.get_center().x, 2.08, east_cage_z), slate_light, true)
	service.mesh_panel(self, Vector2(drawers.position.x - 0.02, east_cage_z - 0.85), Vector2(drawers.position.x - 0.02, east_cage_z + 0.85), 0.12, 1.98, 0.21)
	_paint_cardboard(fittings.fit(self, KENNEY + "cardboardBoxClosed.glb", Vector3(drawers.get_center().x, 2.32, east_cage_z - 0.35), Vector3(0.70, 0.38, 0.82)))

	# Clamped task lamp on SortingDesk.
	var bracket := SORT_LAMP + Vector3(0.13, -0.64, -0.14)
	kit.box(self, "LampClamp", Vector3(0.16, 0.10, 0.13), bracket, charcoal)
	var elbow := bracket + Vector3(0.0, 0.44, 0.0)
	kit.pipe(self, bracket, elbow, 0.024, slate_light)
	kit.pipe(self, elbow, SORT_LAMP, 0.024, slate_light)
	fittings.fit(self, "Prop_Light_Wide", SORT_LAMP, Vector3(0.45, 0.094, 0.12))
	var desk_lens := kit.box(self, "TaskLens", Vector3(0.35, 0.019, 0.069), SORT_LAMP + Vector3(0.0, -0.047, 0.035), paper)
	var cool_lamp := StandardMaterial3D.new()
	cool_lamp.albedo_color = Color("d8ece6")
	cool_lamp.emission_enabled = true
	cool_lamp.emission = Color("cce8e0")
	cool_lamp.emission_energy_multiplier = 0.85
	desk_lens.material_override = cool_lamp
	desk_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Foreground SE open shipping crate on clean putty cart.
	var cr_se: Rect2 = PLAN.WATCH_FIXTURES.OpenCrateStation
	var sc := cr_se.get_center()
	kit.box(self, "CrateCart", Vector3(cr_se.size.x, 0.42, cr_se.size.y), Vector3(sc.x, 0.21, sc.y), slate_light)
	_paint_cardboard(fittings.fit(self, KENNEY + "cardboardBoxOpen.scn", Vector3(sc.x, 0.65, sc.y), Vector3(0.84, 0.46, 0.68), Vector3(0, -24, 0)))
	kit.box(self, "OpenCartonSheets", Vector3(0.46, 0.08, 0.36), Vector3(sc.x, 0.56, sc.y), paper)

	_case_board()


func _case_board() -> void:
	var bounds: Rect2 = PLAN.WATCH_FIXTURES.CaseBoard
	var at := bounds.get_center()
	var holder := Node3D.new()
	holder.name = "ArchivePlanBoard"
	holder.position = Vector3(at.x, 0.0, at.y)
	holder.rotation.y = deg_to_rad(-24.0)
	add_child(holder)

	var board := OFFICE.make_visual("whiteboard", true)
	board.name = "WhiteboardMesh"
	holder.add_child(board)
	board.position = Vector3(0.0, 0.31, 0.0)
	board.scale = Vector3(0.95, 0.80, 1.0)
	for offset: float in [-0.72, 0.72]:
		kit.pipe(holder, Vector3(offset, 0.06, 0.0), Vector3(offset, 0.56, 0.0), 0.030, charcoal)
		kit.box(holder, "BoardFoot", Vector3(0.09, 0.07, 0.51), Vector3(offset, 0.055, 0.0), charcoal)
	var pinned_files := StandardMaterial3D.new()
	pinned_files.albedo_texture = preload("res://art/Dream/office_lowpoly/h06_case_board.res")
	pinned_files.roughness = 0.93
	kit.quad(holder, "HangarFile", Vector2(1.74, 1.00), Vector3(0.0, 1.09, 0.12), pinned_files)
	for corner: Vector2 in [Vector2(-0.74, 1.50), Vector2(0.74, 1.50)]:
		kit.box(holder, "BoardTape", Vector3(0.11, 0.04, 0.014), Vector3(corner.x, corner.y, 0.13), paper)
	kit.cutout.register_tree(board)


func _build_overhead_strips() -> void:
	for mount: Vector3 in [CONSOLE_STRIP, FILE_STRIP]:
		var housing := kit.box(self, "StripHousing", Vector3(2.10, 0.10, 0.28), mount, slate_light)
		var lens := kit.box(self, "StripDiffuser", Vector3(1.92, 0.04, 0.14), mount + Vector3(0.0, -0.055, 0.06), fittings.lamp)
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overhead_diffusers.append(lens)
	for x: float in [-0.71, 0.71]:
		kit.pipe(self, FILE_STRIP + Vector3(x, 0.0, -0.35), FILE_STRIP + Vector3(x, 0.0, 0.0), 0.026, enamel)


func _build_stationery_decals() -> void:
	var stationery := DETAILS.room_decorations([
		[0, -3.45, -16.00, 0.09, 0.69, 0.70, 0.925],
		[3, -1.15, -15.66, -0.15, 0.61, 0.62, 0.815],
		[2, -0.94, -15.98, 0.0, 0.47, 0.47, 0.817],
		[0, -2.74, -21.42, -0.19, 0.52, 0.62, 0.816],
		[12, 4.92, -13.52, 0.10, 1.16, 0.84, 0.815],
		[3, 4.02, -13.66, -0.13, 0.81, 0.82, 0.925],
		[1, -1.66, -21.26, 0.0, 0.64, 0.42, 0.879],
		[1, -2.22, -15.60, 0.0, 0.64, 0.42, 0.879],
	], Vector2.ZERO)
	var print_ink := StandardMaterial3D.new()
	print_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	print_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	print_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	print_ink.albedo_texture = DETAILS.material().get_shader_parameter("detail_atlas")
	print_ink.albedo_color = Color("c4c6c2")
	print_ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stationery.material_override = print_ink
	add_child(stationery)
	for base: Vector3 in [Vector3(4.02, 0.80, -13.66)]:
		for i in 3:
			var stack := kit.box(self, "CasePapers", Vector3(0.41, 0.034, 0.49), base + Vector3.UP * (0.021 + i * 0.039), paper)
			stack.rotation.y = -0.10 + i * 0.075


func _screen(base: Vector3, channel: int, yaw: float) -> void:
	var station := Node3D.new()
	station.name = "SecurityMonitor"
	add_child(station)
	station.position = base
	station.rotation.y = deg_to_rad(yaw)
	# Retro 1970s Sevastopol sloped cream-putty CRT housing + dark stepped turntable pedestal.
	kit.box(station, "CrtFoot", Vector3(0.84, 0.055, 0.44), Vector3(0.0, 0.028, 0.0), charcoal)
	kit.box(station, "CrtLowerDeck", Vector3(0.88, 0.14, 0.46), Vector3(0.0, 0.125, 0.0), slate_light)
	kit.box(station, "CrtDriveSlot", Vector3(0.28, 0.032, 0.02), Vector3(-0.18, 0.12, 0.232), charcoal)
	kit.box(station, "CrtPowerLed", Vector3(0.022, 0.022, 0.018), Vector3(0.32, 0.12, 0.232), green_led)
	kit.box(station, "CrtMainCase", Vector3(0.98, 0.44, 0.36), Vector3(0.0, 0.415, -0.02), enamel)
	kit.box(station, "CrtTopCrown", Vector3(0.84, 0.08, 0.28), Vector3(0.0, 0.66, -0.04), slate_light)
	kit.box(station, "CrtBezel", Vector3(0.92, 0.40, 0.05), Vector3(0.0, 0.42, 0.15), charcoal)
	var video := StandardMaterial3D.new()
	video.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	video.albedo_texture = CAMERA_FEEDS
	video.albedo_color = Color("b8d0cc")
	video.uv1_scale = Vector3(1.0, 0.5, 1.0)
	video.uv1_offset = Vector3(0.0, channel * 0.5, 0.0)
	video.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var screen := kit.quad(station, "CameraPicture", Vector2(0.84, 0.35), Vector3(0.0, 0.42, 0.178), video)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _wall_clock(at: Vector3) -> void:
	kit.cylinder(self, "ClockRim", 0.265, 0.08, at, charcoal, Vector3.BACK)
	kit.cylinder(self, "ClockFace", 0.242, 0.025, at + Vector3.BACK * 0.050, paper, Vector3.BACK)
	for i in 12:
		var angle := TAU * i / 12.0
		var tick := kit.box(self, "DialIndex", Vector3(0.015, 0.043, 0.012), at + Vector3(sin(angle) * 0.201, cos(angle) * 0.201, 0.068), charcoal)
		tick.rotation.z = -angle
	var pin := at + Vector3.BACK * 0.080
	kit.pipe(self, pin, pin + Vector3(-0.104, 0.054, 0.0), 0.014, charcoal)
	kit.pipe(self, pin, pin + Vector3(0.061, 0.152, 0.0), 0.010, charcoal)


func _cable_chain(points: Array, radius: float, mat: Material) -> void:
	for i in range(points.size() - 1):
		kit.pipe(self, points[i], points[i + 1], radius, mat)


func _paint_cardboard(model: Node3D) -> void:
	_paint_surface(model, "wood", cardboard_outer)
	_paint_surface(model, "woodDark", cardboard_inner)


func _paint_surface(model: Node3D, material_name: String, finish: Material) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name == material_name:
				mesh.set_surface_override_material(s, finish)


func _glazed_partition(r: Rect2) -> void:
	var c := r.get_center()
	kit.box(self, "PartitionPlinth", Vector3(r.size.x, 0.65, r.size.y), Vector3(c.x, 0.325, c.y), enamel, true)
	var pane := kit.box(self, "WiredPartitionGlass", Vector3(0.026, 1.25, r.size.y - 0.10), Vector3(c.x, 1.275, c.y), glass)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.box(self, "PartitionTop", Vector3(0.11, 0.055, r.size.y), Vector3(c.x, 1.92, c.y), charcoal, true)
	for z: float in [r.position.y + 0.035, c.y, r.end.y - 0.035]:
		kit.box(self, "GlazingBar", Vector3(0.085, 1.90, 0.052), Vector3(c.x, 0.95, z), charcoal, true)


func _build_room_weathering_decals() -> void:
	var root := Node3D.new()
	root.name = "Room206WorkingClutter"
	add_child(root)
	# Subtle light foot-traffic scuff only (zero derelict rust, heavy floor cracks, oil spills or wall runoff).
	var floor_decals := [
		[room_scuff_decal, Vector3(-2.30, 0.008, -14.28), Vector2(1.40, 0.68), Vector3(-90.0, 22.0, 0.0)],
		[room_scuff_decal, Vector3(-1.55, 0.008, -20.02), Vector2(1.30, 0.64), Vector3(-90.0, -14.0, 0.0)],
		[room_scuff_decal, Vector3(0.95, 0.008, -17.35), Vector2(1.80, 0.72), Vector3(-90.0, -6.0, 0.0)],
		[room_scuff_decal, Vector3(3.35, 0.008, -20.65), Vector2(1.80, 0.70), Vector3(-90.0, 4.0, 0.0)],
	]
	for spec: Array in floor_decals:
		var q := kit.quad(root, "SubtleTrafficScuff", spec[2], spec[1], spec[0], spec[3])
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Clean working-lab loose white sheets, illustrated manuals & dropped folders across foreground and Records bay.
	var loose_sheets := [
		[Vector3(-2.54, 0.009, -14.12), Vector2(0.24, 0.32), 0.36, paper],
		[Vector3(-2.12, 0.011, -14.28), Vector2(0.22, 0.30), -0.48, paper],
		[Vector3(-1.38, 0.010, -14.52), Vector2(0.26, 0.34), 0.85, manual_teal],
		[Vector3(-3.08, 0.009, -14.78), Vector2(0.24, 0.31), -0.22, paper],
		[Vector3(1.75, 0.009, -18.85), Vector2(0.28, 0.34), 0.62, paper],
		[Vector3(2.15, 0.011, -19.20), Vector2(0.25, 0.32), -0.74, red_binder],
		[Vector3(2.42, 0.013, -19.12), Vector2(0.23, 0.30), 0.25, paper],
		[Vector3(1.92, 0.010, -17.65), Vector2(0.24, 0.31), -0.18, paper],
		[Vector3(2.68, 0.011, -17.95), Vector2(0.27, 0.33), 1.12, paper],
		[Vector3(3.12, 0.009, -18.42), Vector2(0.25, 0.32), -0.56, manual_teal],
		[Vector3(3.45, 0.011, -17.30), Vector2(0.26, 0.34), 0.42, paper],
		[Vector3(2.90, 0.012, -16.85), Vector2(0.24, 0.30), 0.96, red_binder],
		[Vector3(3.62, 0.010, -16.45), Vector2(0.26, 0.32), -0.35, paper],
	]
	for sh: Array in loose_sheets:
		var sheet := kit.box(root, "FloorSheet", Vector3(sh[1].x, 0.006, sh[1].y), sh[0], sh[3])
		sheet.rotation.y = sh[2]
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for man_pos: Array in [
		[Vector3(-2.36, 0.012, -13.95), 0.28, manual_teal, red_binder],
		[Vector3(2.46, 0.012, -18.30), -0.52, red_binder, manual_teal],
		[Vector3(3.28, 0.012, -17.78), 0.84, manual_teal, caution_yellow],
	]:
		_build_open_floor_manual(root, man_pos[0], man_pos[1], man_pos[2], man_pos[3])


func _build_open_floor_manual(parent: Node3D, at: Vector3, yaw: float, accent_a: Material, accent_b: Material) -> void:
	var mag := Node3D.new()
	mag.name = "OpenFloorManual"
	mag.position = at
	mag.rotation.y = yaw
	parent.add_child(mag)
	var left_page := kit.box(mag, "ManualPageL", Vector3(0.22, 0.008, 0.30), Vector3(-0.112, 0.006, 0.0), paper)
	left_page.rotation.z = 0.08
	left_page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var right_page := kit.box(mag, "ManualPageR", Vector3(0.22, 0.008, 0.30), Vector3(0.112, 0.006, 0.0), paper)
	right_page.rotation.z = -0.08
	right_page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate_a := kit.box(mag, "ManualPlateA", Vector3(0.14, 0.006, 0.14), Vector3(-0.11, 0.012, -0.04), accent_a)
	plate_a.rotation.z = 0.08
	plate_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate_b := kit.box(mag, "ManualPlateB", Vector3(0.14, 0.006, 0.11), Vector3(0.11, 0.012, 0.04), accent_b)
	plate_b.rotation.z = -0.08
	plate_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func light_workstations(art) -> void:
	var root: Node3D = art.lights_root
	var deck := Vector3.UP * position.y
	var console: SpotLight3D = art._spot(root, "CameraConsolePool", deck + CONSOLE_STRIP + Vector3(0.0, -0.10, 0.24), deck + Vector3(-1.55, 0.64, -20.85), Color("cde6e2"), 2.25, 6.2, 56.0)
	art.OPTICS.mark_fixture(self, console, [overhead_diffusers[0]], position.y)
	art._spot(root, "HeroIslandPool", deck + Vector3(-2.15, 2.48, -16.10), deck + Vector3(-2.20, 0.60, -15.35), Color("d6ece8"), 2.95, 6.8, 66.0)
	art._omni(root, "MonitorSpill", deck + Vector3(-2.18, 1.24, -15.72), Color("b8e0d8"), 0.86, 3.40, 1.35, false)
	art._omni(root, "BlindsSignFill", deck + Vector3(-8.85, 2.04, -21.58), Color("cbe2df"), 0.92, 4.20, 1.30, false)
	art._omni(root, "NorthWallWash", deck + Vector3(-4.25, 2.02, -21.25), Color("bfd9d5"), 0.72, 5.60, 1.30, false)
	var records: SpotLight3D = art._spot(root, "RecordsShelfPool", deck + Vector3(3.65, 2.42, -19.65), deck + Vector3(3.75, 0.85, -21.85), Color("d4ebe6"), 2.85, 6.8, 66.0)
	art.OPTICS.mark_fixture(self, records, [overhead_diffusers[1]], position.y)
	art._spot(root, "WhiteboardPool", deck + Vector3(5.25, 2.42, -18.25), deck + Vector3(5.85, 0.85, -20.30), Color("cde4df"), 2.05, 5.8, 60.0)
	art._omni(root, "GlassCabinetPool", deck + Vector3(3.60, 2.04, -21.65), Color("d8ece8"), 0.82, 2.25, 1.2, false)
	art._spot(root, "SortingLampPool", deck + SORT_LAMP + Vector3(-0.10, -0.09, 0.05), deck + Vector3(4.92, 0.78, -13.45), Color("dff0ea"), 1.60, 3.60, 52.0)
	art._omni(root, "EastAisleFill", deck + Vector3(3.15, 2.15, -17.55), Color("bfe0d8"), 0.78, 5.40, 1.35, false)
	var spill: SpotLight3D = art._spot(root, "LightThroughBlinds", deck + Vector3(-8.95, 1.62, -22.15), deck + Vector3(-7.30, 0.04, -18.80), Color("c4e0dc"), 3.0, 6.75, 31.0)
	if blind_pattern == null:
		var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / 64.0
				var side := smoothstep(0.02, 0.20, minf(uv.x, 1.0 - uv.x))
				var band := smoothstep(0.13, 0.35, absf(fposmod(uv.y * 6.0, 1.0) - 0.5))
				var feather := smoothstep(0.04, 0.20, minf(uv.y, 1.0 - uv.y))
				mask.set_pixel(x, y, Color.WHITE * (side * feather * (0.06 + 0.94 * band)))
		mask.generate_mipmaps()
		blind_pattern = ImageTexture.create_from_image(mask)
	spill.light_projector = blind_pattern
