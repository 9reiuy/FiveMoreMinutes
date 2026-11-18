extends RefCounted
## Unified 1-4 Logistics Hub & North-East Exit-Corner Armory Workshop matching the Chapter 1-1 / 1-2 / 1-3 industrial art direction.
## Uses security_room_pbr.gdshader, warehouse_art.gd, facility_fittings.gd, MiniForklift3D, workbench.obj, and calibrated Quaternius/Office props.

const LOGISTICS_DECK_SHADER := preload("res://scripts/testing/h06_chapter/logistics_deck.gdshader")
const ARMORY_BRICK_SHADER := preload("res://scripts/testing/h06_chapter/armory_brick.gdshader")
const SECURITY_PBR_SHADER := preload("res://scripts/testing/h06_chapter/security_room_pbr.gdshader")
const WAREHOUSE := preload("res://scripts/testing/h06_chapter/warehouse_art.gd")
const FREIGHT := preload("res://scripts/testing/h06_chapter/freight_art.gd")
const MINI_FORKLIFT_SCRIPT := preload("res://scripts/dream/props/mini_forklift_3d.gd")
const OFFICE := preload("res://scripts/dream/office_furniture_catalog.gd")
const DETAILS := preload("res://scripts/dream/office_detail_art.gd")
const CAMERA_FEEDS := preload("res://art/Dream/office_lowpoly/h06_camera_feeds.res")
const CASE_BOARD_TEX := preload("res://art/Dream/office_lowpoly/h06_case_board.res")

# Floor PBR Textures
const CONCRETE_DIFF := "res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Diffuse.res"
const CONCRETE_NOR := "res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_nor_gl.res"
const CONCRETE_ROUGH := "res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Rough.res"
const STONE_DIFF := "res://art/Dream/ReceptionLobby/NaturalStone01/albedo.png"
const STONE_NOR := "res://art/Dream/ReceptionLobby/NaturalStone01/normal.png"
const STONE_ROUGH := "res://art/Dream/ReceptionLobby/NaturalStone01/roughness.png"

# CC0 PBR Surface Library Maps (matching security_room.gd)
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
const RL_CABAN_DIFF := "res://art/Dream/ReceptionLobby/caban/diff.jpg"
const RL_CABAN_NOR := "res://art/Dream/ReceptionLobby/caban/nor_gl.jpg"
const RL_CABAN_ROUGH := "res://art/Dream/ReceptionLobby/caban/rough.jpg"

# Calibrated CC0 Scenes & Furniture Assets
const QUAT_EXTRA := "res://art/Dream/CC0/AtriumLoop11/quaternius/"
const KENNEY := "res://art/Dream/office_lowpoly/kenney/"
const FILE_DRAWERS := "res://scenes/dream/3d/props/filing_cabinet_01_visual_3d.tscn"
const WORKBENCH_OBJ := "res://art/story/chapter1/workbench.obj"

static var _mat_cache: Dictionary = {}
static var _floor_mat_cache: ShaderMaterial
static var _white_tex: Texture2D
static var _brick_counter_mat: ShaderMaterial


static func floor_material() -> ShaderMaterial:
	if _floor_mat_cache != null:
		return _floor_mat_cache
	var mat := ShaderMaterial.new()
	mat.shader = LOGISTICS_DECK_SHADER
	mat.set_shader_parameter("deck_albedo", load(RL_MET12_DIFF))
	mat.set_shader_parameter("deck_normal", load(RL_MET12_NOR))
	mat.set_shader_parameter("deck_rough", load(RL_MET12_ROUGH))
	mat.set_shader_parameter("iron_albedo", load(RL_IRON_DIFF))
	mat.set_shader_parameter("iron_normal", load(RL_IRON_NOR))
	mat.set_shader_parameter("iron_rough", load(RL_IRON_ROUGH))
	mat.set_shader_parameter("view_opening", Vector4.ZERO)
	mat.set_shader_parameter("passage_end_fade", Vector4.ZERO)
	mat.set_shader_parameter("passage_z_fade", Vector4.ZERO)
	mat.set_shader_parameter("fade_floor", 0.0)
	_floor_mat_cache = mat
	return _floor_mat_cache


static func materials() -> Dictionary:
	if not _mat_cache.is_empty():
		return _mat_cache
	if _white_tex == null:
		var w_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		w_img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(w_img)

	var met12_mid := Vector3(0.679, 0.729, 0.789)
	var sage_green := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("3c5a48"), 0.56, 2.0, true, Vector2(0.32, 0.58), 0.70, 0.22, 0.22, 0.0, Color("5a7363"), Color("1d2b22"), 0.036, 0.65)
	var enamel := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("bec6bc"), 0.56, 2.2, true, Vector2(0.30, 0.56), 0.72, 0.22, 0.22, 0.0, Color("9aa39c"), Color("46524b"), 0.036, 0.65)
	var charcoal := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("282e30"), 0.54, 2.2, true, Vector2(0.46, 0.78), 0.72, 0.18, 0.18, 0.0, Color("4a5256"), Color("161a1c"), 0.032, 0.55)
	var slate_mid := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("9ca59d"), 0.56, 2.2, true, Vector2(0.32, 0.60), 0.72, 0.24, 0.22, 0.0, Color("7b847d"), Color("3c4540"), 0.036, 0.65)
	var slate_light := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("cbd2c8"), 0.58, 2.0, true, Vector2(0.32, 0.58), 0.70, 0.20, 0.20, 0.0, Color("a2aba3"), Color("525d56"), 0.036, 0.60)
	var desk_top_enamel := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("bcc4ba"), 0.62, 1.9, true, Vector2(0.28, 0.54), 0.65, 0.16, 0.18, 0.0, Color("9aa299"), Color("4f5a53"), 0.034, 0.50)
	var desk_top_dark := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("c4cbc1"), 0.62, 1.9, true, Vector2(0.28, 0.54), 0.65, 0.16, 0.18, 0.0, Color("a0a89f"), Color("556058"), 0.034, 0.50)
	var pegboard_steel := _make_cc0_pbr(RL_MET12_DIFF, RL_MET12_NOR, RL_MET12_ROUGH, RL_MET12_MET, met12_mid, Color("747b78"), 0.34, 2.4, true, Vector2(0.42, 0.70), 0.78, 0.24, 0.24, 0.0, Color("8e9692"), Color("232729"), 0.028, 0.45)

	var stone_mid := Vector3(0.590, 0.576, 0.558)
	var stone_sill := _make_cc0_pbr(STONE_DIFF, STONE_NOR, STONE_ROUGH, "", stone_mid, Color("c2c8be"), 0.96, 2.0, false, Vector2(0.38, 0.68), 0.65, 0.04, 0.18, 0.0, Color("949c95"), Color("505853"), 0.032, 0.50)

	var walnut := _make_cc0_pbr(RL_WALNUT_DIFF, RL_WALNUT_NOR, RL_WALNUT_ROUGH, "", Vector3(0.260, 0.143, 0.080), Color("855a3c"), 0.38, 3.2, false, Vector2(0.36, 0.68), 0.95, 0.02, 0.18, 0.0, Color("ae7b52"), Color("281b12"), 0.030, 0.45)
	var walnut_prop := _prop_override(walnut)
	var steel_bright := _make_cc0_pbr(RL_IRON_DIFF, RL_IRON_NOR, RL_IRON_ROUGH, RL_IRON_MET, Vector3(0.544, 0.562, 0.562), Color("b4bec2"), 0.55, 2.8, false, Vector2(0.22, 0.52), 0.78, 0.86, 0.22, 0.0, Color("ccd4d8"), Color("3e4844"), 0.028, 0.50)
	var brushed_iron_prop := _prop_override(steel_bright)
	var charcoal_prop := _prop_override(charcoal)

	var caban_mid := Vector3(0.624, 0.132, 0.01)
	var worn_fabric := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("44564e"), 0.35, 2.6, true, Vector2(0.76, 0.94), 0.72, 0.02, 0.16, 0.0, Color("313d37"), Color("1b2320"), 0.024, 0.45)
	var worn_fabric_prop := _prop_override(worn_fabric)
	var olive_mat := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("5a7366"), 0.28, 2.4, true, Vector2(0.70, 0.90), 0.62, 0.02, 0.14, 0.0, Color("45594f"), Color("233029"), 0.020, 0.40)
	var cork := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("9a8668"), 0.26, 2.6, true, Vector2(0.84, 0.96), 0.75, 0.0, 0.14, 0.0, Color("b5a082"), Color("483c2b"), 0.024, 0.35)
	var cardboard_outer := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("b49b7c"), 0.42, 2.4, true, Vector2(0.82, 0.96), 0.72, 0.0, 0.16, 0.0, Color("cbb394"), Color("4d3d2b"), 0.024, 0.0)
	var cardboard_inner := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("8a7054"), 0.42, 2.4, true, Vector2(0.85, 0.97), 0.72, 0.0, 0.16, 0.0, Color("a28668"), Color("3a2b1c"), 0.024, 0.0)
	var red_binder := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("9d3330"), 0.34, 2.2, true, Vector2(0.58, 0.84), 0.50, 0.02, 0.12, 0.0, Color("b44a46"), Color("481715"), 0.016, 0.0)
	var manual_teal := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("4b6b5d"), 0.34, 2.2, true, Vector2(0.55, 0.82), 0.45, 0.02, 0.12, 0.0, Color("618373"), Color("23342c"), 0.016, 0.0)
	var blue_tarp := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("294e6f"), 0.40, 2.2, true, Vector2(0.68, 0.90), 0.62, 0.02, 0.14, 0.0, Color("3c688f"), Color("182d40"), 0.020, 0.0)
	var can_red := _make_cc0_pbr(RL_IRON_DIFF, RL_IRON_NOR, RL_IRON_ROUGH, RL_IRON_MET, Vector3(0.544, 0.562, 0.562), Color("96322f"), 0.30, 2.4, true, Vector2(0.32, 0.58), 0.40, 0.35, 0.14, 0.0, Color("b9c2c7"), Color("351715"), 0.015, 0.25)
	var cable_black := _make_cc0_pbr(RL_CABAN_DIFF, RL_CABAN_NOR, RL_CABAN_ROUGH, "", caban_mid, Color("202527"), 0.30, 2.0, true, Vector2(0.64, 0.88), 0.48, 0.06, 0.16, 0.0, Color("31373c"), Color("0f1113"), 0.015, 0.0)

	var plaster_mid := Vector3(0.060, 0.066, 0.074)
	var paper := _make_cc0_pbr(PH_PLASTER_DIFF, PH_PLASTER_NOR, PH_PLASTER_ROUGH, "", plaster_mid, Color("dedcd0"), 0.72, 1.4, true, Vector2(0.86, 0.96), 0.24, 0.0, 0.12, 0.0, Color("eae8dc"), Color("a8a395"), 0.010, 0.25)

	if _brick_counter_mat == null:
		_brick_counter_mat = ShaderMaterial.new()
		_brick_counter_mat.shader = ARMORY_BRICK_SHADER

	var green_led := StandardMaterial3D.new()
	green_led.albedo_color = Color("76f28e")
	green_led.emission_enabled = true
	green_led.emission = Color("5ce67a")
	green_led.emission_energy_multiplier = 2.4
	green_led.roughness = 0.22

	var amber_led := StandardMaterial3D.new()
	amber_led.albedo_color = Color("f0b446")
	amber_led.emission_enabled = true
	amber_led.emission = Color("ffc65a")
	amber_led.emission_energy_multiplier = 2.2
	amber_led.roughness = 0.24

	var glass_smoked := StandardMaterial3D.new()
	glass_smoked.albedo_color = Color(0.10, 0.14, 0.16, 0.62)
	glass_smoked.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_smoked.roughness = 0.48
	glass_smoked.metallic_specular = 0.14
	glass_smoked.cull_mode = BaseMaterial3D.CULL_DISABLED

	var wh: Dictionary = WAREHOUSE.materials()
	var fr: Dictionary = FREIGHT.materials()

	_mat_cache = {
		"sage_green": sage_green,
		"enamel": enamel,
		"charcoal": charcoal,
		"charcoal_prop": charcoal_prop,
		"slate_mid": slate_mid,
		"slate_light": slate_light,
		"desk_top_enamel": desk_top_enamel,
		"desk_top_dark": desk_top_dark,
		"pegboard": _prop_override(pegboard_steel),
		"slate_mid_prop": _prop_override(slate_mid),
		"stone_sill": stone_sill,
		"walnut": walnut,
		"walnut_prop": walnut_prop,
		"steel_bright": steel_bright,
		"brushed_iron_prop": brushed_iron_prop,
		"worn_fabric": worn_fabric,
		"worn_fabric_prop": worn_fabric_prop,
		"olive_mat": olive_mat,
		"cork": cork,
		"cardboard_outer": cardboard_outer,
		"cardboard_inner": cardboard_inner,
		"red_binder": _prop_override(red_binder),
		"manual_teal": manual_teal,
		"manual_teal_prop": _prop_override(manual_teal),
		"blue_tarp": blue_tarp,
		"can_red": can_red,
		"can_red_prop": _prop_override(can_red),
		"cable_black": cable_black,
		"paper": paper,
		"brick": _brick_counter_mat,
		"green_led": green_led,
		"amber_led": amber_led,
		"glass": glass_smoked,
		# Reuse 1-2 / 1-3 calibrated industrial materials seamlessly
		"steel_dark": wh.steel_dark,
		"steel_mid": wh.steel_mid,
		"safety_yellow": wh.safety_yellow,
		"rack_orange": wh.rack_orange,
		"dark_crate": wh.dark_crate,
		"olive_crate": wh.olive_crate,
		"tan_carton": wh.tan_carton,
		"timber": wh.timber,
		"tote_white": wh.tote_white,
		"hazard": wh.hazard,
		"stripe_white": wh.stripe_white,
		"corrugated": wh.corrugated,
		"beacon_red": wh.beacon_red,
		"beacon_green": wh.beacon_green,
		"trench_steel": fr.trench_steel,
		"pipe_rusted": fr.pipe_rusted,
		"rail_metal": fr.rail_metal,
	}
	return _mat_cache


static func _make_cc0_pbr(albedo_path: String, nor_path: String, rough_path: String, met_path: String,
		tex_mid: Vector3, tint: Color, repeat_m: float, contrast: float, luma_only: bool,
		rough_range: Vector2, nor_str: float, metallic: float, wear: float, rust: float,
		substrate: Color, grime: Color, edge_band_val := 0.042, edge_wear_val := 1.0) -> ShaderMaterial:
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


static func _prop_override(base_mat: Material) -> Material:
	var m := (base_mat as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter(&"edge_wear", 0.0)
	return m


static func _paint_surface(model: Node, material_name: String, finish: Material) -> void:
	if not is_instance_valid(model):
		return
	for ch: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := ch as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name == material_name:
				mesh.set_surface_override_material(s, finish)


static func _paint_cardboard(model: Node, m: Dictionary) -> void:
	_paint_surface(model, "wood", m.cardboard_outer)
	_paint_surface(model, "woodDark", m.cardboard_inner)


static func _group(parent: Node3D, group_name: String) -> Node3D:
	var grp := Node3D.new()
	grp.name = group_name
	parent.add_child(grp)
	return grp


static func _commit_mb(host, parent: Node3D, node_name: String, mb: RefCounted,
		world_offset := Vector3.ZERO, cutout_reg := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.call("bake") as ArrayMesh
	mi.position = world_offset
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	if cutout_reg and host.cutout != null:
		host.cutout.register_tree(mi)
	return mi


static func _cable_chain(host, parent: Node3D, points: Array, radius: float, mat: Material) -> void:
	for i in range(points.size() - 1):
		host.m.pipe(parent, points[i], points[i + 1], radius, mat)


static func build_clinical_cot(host, parent: Node3D, key: String, r: Rect2, h: float) -> void:
	var m := materials()
	var kit = host.m
	var c := r.get_center()
	var cot := _group(parent, "ClinicalCot_" + key)
	var bed_h := maxf(0.46, h * 0.72)
	var frame_y := 0.24
	# Brushed steel tubular legs & frame
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lx := c.x + sx * (r.size.x * 0.44)
			var lz := c.y + sz * (r.size.y * 0.42)
			kit.pipe(cot, Vector3(lx, 0.0, lz), Vector3(lx, bed_h, lz), 0.028, m.steel_bright)
	# Headboard/footboard hoops
	for sx: float in [-1.0, 1.0]:
		var hx := c.x + sx * (r.size.x * 0.44)
		var top_rail_y := bed_h + (0.28 if sx < 0.0 else 0.14)
		kit.pipe(cot, Vector3(hx, bed_h, r.position.y + r.size.y * 0.08), Vector3(hx, top_rail_y, r.position.y + r.size.y * 0.08), 0.024, m.steel_bright)
		kit.pipe(cot, Vector3(hx, bed_h, r.end.y - r.size.y * 0.08), Vector3(hx, top_rail_y, r.end.y - r.size.y * 0.08), 0.024, m.steel_bright)
		kit.pipe(cot, Vector3(hx, top_rail_y, r.position.y + r.size.y * 0.08), Vector3(hx, top_rail_y, r.end.y - r.size.y * 0.08), 0.024, m.steel_bright)
	# Under-frame box & mattress, blanket & crisp pillow using security_room_pbr
	kit.box(cot, "CotDeck", Vector3(r.size.x - 0.12, 0.08, r.size.y - 0.08), Vector3(c.x, frame_y + 0.08, c.y), m.charcoal)
	kit.box(cot, "Mattress", Vector3(r.size.x - 0.16, 0.16, r.size.y - 0.12), Vector3(c.x, frame_y + 0.20, c.y), m.paper)
	var bl_w := r.size.x * 0.62
	kit.box(cot, "Blanket", Vector3(bl_w, 0.05, r.size.y - 0.10), Vector3(c.x + r.size.x * 0.15, frame_y + 0.30, c.y), m.olive_mat)
	kit.box(cot, "Pillow", Vector3(0.38, 0.09, r.size.y * 0.68), Vector3(r.position.x + 0.34, frame_y + 0.32, c.y), m.paper)
	host.cutout.register_tree(cot)


static func build_hub(host) -> Node3D:
	var root := Node3D.new()
	root.name = "LogisticsHub"
	host.floor_root.add_child(root)
	var m := materials()

	_build_portals_and_windows(host, root, m)
	_build_octagonal_bay_doors(host, root, m)
	_build_sorting_hub_and_conveyors(host, root, m)
	_build_dispatch_control_office(host, root, m)
	_build_forklift_and_receiving_bays(host, root, m)
	_build_medbay_wing(host, root, m)
	_build_south_cargo_vault(host, root, m)
	_build_north_concourse(host, root, m)
	_build_exit_corner_armory(host, root, m)
	_build_ceiling_cove_strips(host, root)

	return root


static func _build_industrial_desk(kit, parent: Node3D, title: String, r: Rect2,
		top_mat: Material, body_mat: Material, m: Dictionary, instr_front_z_sign := 1.0) -> Node3D:
	var c := r.get_center()
	var h := 0.80
	var root := _group(parent, title)
	kit.box(root, "Desktop", Vector3(r.size.x, 0.056, r.size.y), Vector3(c.x, h - 0.028, c.y), top_mat)
	kit.box(root, "DesktopTrim", Vector3(r.size.x + 0.014, 0.024, r.size.y + 0.014), Vector3(c.x, h - 0.062, c.y), m.charcoal)
	kit.box(root, "Apron", Vector3(r.size.x - 0.14, 0.075, r.size.y - 0.18), Vector3(c.x, h - 0.105, c.y), m.slate_mid)
	var ped_w := clampf(r.size.x * 0.23, 0.46, 0.68)
	var front_z := r.end.y - 0.064 if instr_front_z_sign > 0.0 else r.position.y + 0.064
	for side: int in [-1, 1]:
		var px := c.x + side * (r.size.x * 0.5 - ped_w * 0.5 - 0.08)
		kit.box(root, "PedestalPlinth", Vector3(ped_w - 0.04, 0.08, r.size.y - 0.18), Vector3(px, 0.04, c.y), m.charcoal)
		kit.box(root, "Pedestal", Vector3(ped_w, h - 0.14, r.size.y - 0.14), Vector3(px, 0.08 + (h - 0.14) * 0.5, c.y), body_mat)
		if side == -1 and r.size.x > 1.8:
			kit.box(root, "PedInstrFrame", Vector3(ped_w - 0.10, 0.44, 0.028), Vector3(px, 0.40, front_z), m.charcoal)
			kit.box(root, "PedInstrScreen", Vector3(ped_w * 0.44, 0.32, 0.016), Vector3(px + ped_w * 0.12, 0.40, front_z + instr_front_z_sign * 0.016), m.cable_black)
			kit.box(root, "PedInstrLed", Vector3(0.024, 0.024, 0.018), Vector3(px - ped_w * 0.24, 0.50, front_z + instr_front_z_sign * 0.024), m.green_led)
		else:
			for row in 3:
				var dy := 0.21 + row * 0.185
				kit.box(root, "DrawerFace", Vector3(ped_w - 0.06, 0.155, 0.022), Vector3(px, dy, front_z), m.enamel)
				kit.box(root, "DrawerPull", Vector3(ped_w * 0.38, 0.018, 0.028), Vector3(px, dy + 0.026, front_z + instr_front_z_sign * 0.014), m.steel_bright)
	kit.cutout.register_tree(root)
	return root


static func _build_crt_monitor(kit, parent: Node3D, base: Vector3, channel: int, yaw_deg: float, m: Dictionary) -> void:
	var station := _group(parent, "SecurityMonitor")
	station.position = base
	station.rotation.y = deg_to_rad(yaw_deg)
	kit.box(station, "CrtFoot", Vector3(0.76, 0.052, 0.40), Vector3(0.0, 0.026, 0.0), m.charcoal)
	kit.box(station, "CrtLowerDeck", Vector3(0.80, 0.13, 0.42), Vector3(0.0, 0.115, 0.0), m.slate_light)
	kit.box(station, "CrtDriveSlot", Vector3(0.26, 0.030, 0.02), Vector3(-0.16, 0.11, 0.212), m.charcoal)
	kit.box(station, "CrtPowerLed", Vector3(0.022, 0.022, 0.018), Vector3(0.28, 0.11, 0.212), m.green_led)
	kit.box(station, "CrtMainCase", Vector3(0.88, 0.40, 0.34), Vector3(0.0, 0.38, -0.02), m.enamel)
	kit.box(station, "CrtTopCrown", Vector3(0.76, 0.075, 0.26), Vector3(0.0, 0.60, -0.04), m.slate_light)
	kit.box(station, "CrtBezel", Vector3(0.82, 0.36, 0.05), Vector3(0.0, 0.38, 0.14), m.charcoal)
	var video := StandardMaterial3D.new()
	video.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	video.albedo_texture = CAMERA_FEEDS
	video.albedo_color = Color("b8d0cc")
	video.uv1_scale = Vector3(1.0, 0.5, 1.0)
	video.uv1_offset = Vector3(0.0, float(channel) * 0.5, 0.0)
	video.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var scr := kit.quad(station, "CameraPicture", Vector2(0.74, 0.31), Vector3(0.0, 0.38, 0.168), video) as MeshInstance3D
	scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _build_pa_horn(kit, parent: Node3D, at: Vector3, rot_deg: Vector3, m: Dictionary) -> void:
	var horn := _group(parent, "PAHorn")
	horn.position = at
	horn.rotation_degrees = rot_deg
	kit.box(horn, "HornBracket", Vector3(0.06, 0.16, 0.06), Vector3(0.0, 0.02, -0.10), m.charcoal)
	kit.cylinder(horn, "HornDriver", 0.058, 0.14, Vector3(0.0, 0.0, -0.02), m.charcoal, Vector3.BACK)
	kit.cylinder(horn, "HornNeck", 0.082, 0.10, Vector3(0.0, 0.0, 0.08), m.slate_mid, Vector3.BACK)
	kit.cylinder(horn, "HornBell", 0.128, 0.09, Vector3(0.0, 0.0, 0.15), m.charcoal, Vector3.BACK)


static func _build_gooseneck_lamp(host, parent: Node3D, at: Vector3, m: Dictionary) -> void:
	var kit = host.m
	var lamp := _group(parent, "DeskGooseneckLamp")
	kit.cylinder(lamp, "LampFoot", 0.065, 0.030, at + Vector3(0.0, 0.015, 0.0), m.charcoal)
	_cable_chain(host, lamp, [
		at + Vector3(0.0, 0.03, 0.0),
		at + Vector3(-0.04, 0.18, -0.02),
		at + Vector3(-0.02, 0.34, 0.02),
		at + Vector3(0.08, 0.41, 0.07),
	], 0.012, m.steel_bright)
	var head := _group(lamp, "LampHead")
	head.position = at + Vector3(0.11, 0.39, 0.09)
	head.rotation = Vector3(deg_to_rad(32.0), deg_to_rad(28.0), 0.0)
	kit.cylinder(head, "LampShade", 0.050, 0.12, Vector3.ZERO, m.slate_light, Vector3.FORWARD)
	kit.cylinder(head, "LampGlowRim", 0.044, 0.018, Vector3(0.0, 0.0, 0.060), m.paper, Vector3.FORWARD)


static func _build_wall_clock(host, parent: Node3D, at: Vector3, m: Dictionary) -> void:
	var kit = host.m
	kit.cylinder(parent, "ClockRim", 0.25, 0.075, at, m.charcoal, Vector3.BACK)
	kit.cylinder(parent, "ClockFace", 0.228, 0.024, at + Vector3.BACK * 0.046, m.paper, Vector3.BACK)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var tick: MeshInstance3D = kit.box(parent, "DialIndex", Vector3(0.014, 0.040, 0.012),
			at + Vector3(sin(angle) * 0.188, cos(angle) * 0.188, 0.062), m.charcoal)
		tick.rotation.z = -angle
	var pin := at + Vector3.BACK * 0.074
	kit.pipe(parent, pin, pin + Vector3(-0.095, 0.048, 0.0), 0.013, m.charcoal)
	kit.pipe(parent, pin, pin + Vector3(0.056, 0.140, 0.0), 0.010, m.charcoal)


static func _add_bolted_guardrail(host, parent: Node3D, node_name: String, a: Vector3, b: Vector3,
		h := 0.96, yellow_top := true) -> void:
	var m := materials()
	var mb := WAREHOUSE.MeshBuilder.new()
	var span := a.distance_to(b)
	if span < 0.20:
		return
	var top_mat: Material = m.safety_yellow if yellow_top else m.rail_metal
	mb.bar(top_mat, a + Vector3(0.0, h * 0.96, 0.0), b + Vector3(0.0, h * 0.96, 0.0), 0.068)
	mb.bar(m.rail_metal, a + Vector3(0.0, h * 0.50, 0.0), b + Vector3(0.0, h * 0.50, 0.0), 0.052)
	mb.bar(m.safety_yellow, a + Vector3(0.0, 0.045, 0.0), b + Vector3(0.0, 0.045, 0.0), 0.056)
	var posts := maxi(2, ceili(span / 1.85) + 1)
	for i in posts:
		var pt := a.lerp(b, float(i) / float(posts - 1))
		mb.box(m.steel_mid, pt + Vector3(0.0, 0.022, 0.0), Vector3(0.16, 0.044, 0.16))
		mb.bar(m.rail_metal, pt + Vector3(0.0, 0.03, 0.0), pt + Vector3(0.0, h, 0.0), 0.074)
	_commit_mb(host, parent, node_name, mb, Vector3.ZERO, true)


static func _add_cargo_bundle(parent: Node3D, title: String, bottom: Vector3, size: Vector3, seed_id: int) -> void:
	var mats := materials()
	var mb := WAREHOUSE.MeshBuilder.new()
	WAREHOUSE._add_pallet(mb, mats, bottom, Vector2(size.x, size.z))
	var slots := clampi(roundi(size.x / 0.85), 1, 2)
	var sub_h := size.y - 0.12
	for s in slots:
		var ox := 0.0 if slots == 1 else (float(s) - 0.5) * size.x * 0.48
		var cw := (size.x / float(slots)) * 0.90
		var pos := Vector3(bottom.x + ox, bottom.y + 0.12, bottom.z)
		var kind := (seed_id + s) % 3
		if kind == 0:
			WAREHOUSE._add_ibc_tote(mb, mats, pos, Vector3(cw, sub_h, size.z * 0.90))
		elif kind == 1:
			WAREHOUSE._add_military_case(mb, mats, pos, Vector3(cw, sub_h, size.z * 0.90), false)
		else:
			WAREHOUSE._add_olive_crate_pair(mb, mats, pos, Vector3(cw, sub_h, size.z * 0.90))
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = mb.call("bake") as ArrayMesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


static func _build_portals_and_windows(host, parent: Node3D, m: Dictionary) -> void:
	var grp := _group(parent, "LogisticsPortals")
	var top_black: Material = host.cutout.top_black

	# 1. Full exterior top_black shroud matching 1-2 Warehouse (covers outside void completely at wall-top / cutaway levels)
	const EXT_W := -260.0
	const EXT_E := 260.0
	const EXT_N := -260.0
	const EXT_S := 260.0
	var m_shroud := WAREHOUSE.MeshBuilder.new()
	for box_def: Array in [
		# North exterior (z <= 12.92) & arena_link pocket roof cap
		[EXT_W, EXT_E, EXT_N, 8.88, -0.50, 4.20],
		[EXT_W, 36.16, 8.88, 12.92, -0.50, 4.20],
		[39.84, EXT_E, 8.88, 12.92, -0.50, 4.20],
		[36.16, 39.84, 8.88, 12.92, 3.98, 4.20],
		# West exterior (x <= 24.92) & East exterior (x >= 47.08) at full 4.20m wall crown
		[EXT_W, 24.92, 12.92, 39.08, -0.50, 4.20],
		[47.08, EXT_E, 12.92, 39.08, -0.50, 4.20],
		# South cutaway exterior (z >= 39.08) at 0.65m front cutaway height
		[EXT_W, EXT_E, 39.08, EXT_S, -0.50, 0.65],
	]:
		var x0 := float(box_def[0]); var x1 := float(box_def[1])
		var z0 := float(box_def[2]); var z1 := float(box_def[3])
		var yb := float(box_def[4]); var yt := float(box_def[5])
		m_shroud.box(top_black, Vector3((x0 + x1) * 0.5, (yb + yt) * 0.5, (z0 + z1) * 0.5),
			Vector3(x1 - x0, yt - yb, z1 - z0))
	var shroud_mi := _commit_mb(host, grp, "LogisticsExteriorShroud", m_shroud, Vector3.ZERO, false)
	shroud_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 2. High-Bay Bunker Perimeter Pilasters (4.2m), X-Braced Steel Wall Panels, Red Dado Stripe & Overhead Pipe Runs
	var m_cols := WAREHOUSE.MeshBuilder.new()
	for z_p: float in [13.2, 16.8, 20.4, 24.0, 27.6, 31.2, 34.8, 38.6]:
		var cp := Vector3(25.18, 0.0, z_p)
		m_cols.box(m.steel_dark, cp + Vector3(0.0, 2.10, 0.0), Vector3(0.28, 4.20, 0.28))
		m_cols.box(m.safety_yellow, cp + Vector3(0.0, 0.36, 0.0), Vector3(0.32, 0.72, 0.32))
		m_cols.box(top_black, cp + Vector3(0.0, 4.22, 0.0), Vector3(0.34, 0.08, 0.34))
	for x_p: float in [28.6, 32.2, 35.8, 40.0, 43.4, 46.82]:
		var cp := Vector3(x_p, 0.0, 13.18)
		m_cols.box(m.steel_dark, cp + Vector3(0.0, 2.10, 0.0), Vector3(0.28, 4.20, 0.28))
		m_cols.box(m.safety_yellow, cp + Vector3(0.0, 0.36, 0.0), Vector3(0.32, 0.72, 0.32))
		m_cols.box(top_black, cp + Vector3(0.0, 4.22, 0.0), Vector3(0.34, 0.08, 0.34))
	for z_e: float in [16.8, 20.4, 24.4, 29.2, 31.4, 36.4, 38.6]:
		var cp := Vector3(46.82, 0.0, z_e)
		m_cols.box(m.steel_dark, cp + Vector3(0.0, 2.10, 0.0), Vector3(0.28, 4.20, 0.28))
		m_cols.box(m.safety_yellow, cp + Vector3(0.0, 0.36, 0.0), Vector3(0.32, 0.72, 0.32))
		m_cols.box(top_black, cp + Vector3(0.0, 4.22, 0.0), Vector3(0.34, 0.08, 0.34))

	# X-braced dark structural wall bays along West, North & East walls (matching Hell is Us reference)
	var west_z: Array[float] = [13.2, 16.8, 20.4, 24.0, 27.6, 31.2, 34.8, 38.6]
	for wi in range(west_z.size() - 1):
		var z0 := float(west_z[wi]); var z1 := float(west_z[wi + 1])
		m_cols.bar(m.steel_dark, Vector3(25.14, 0.24, z0 + 0.14), Vector3(25.14, 2.20, z1 - 0.14), 0.10)
		m_cols.bar(m.steel_dark, Vector3(25.14, 2.20, z0 + 0.14), Vector3(25.14, 0.24, z1 - 0.14), 0.10)
	for n_pair: Array in [
		[25.2, 28.6], [28.6, 32.2], [32.2, 35.8], [40.0, 43.4], [43.4, 46.8],
	]:
		var x0 := float(n_pair[0]); var x1 := float(n_pair[1])
		m_cols.bar(m.steel_dark, Vector3(x0 + 0.14, 0.24, 13.14), Vector3(x1 - 0.14, 2.20, 13.14), 0.10)
		m_cols.bar(m.steel_dark, Vector3(x0 + 0.14, 2.20, 13.14), Vector3(x1 - 0.14, 0.24, 13.14), 0.10)
	for e_pair: Array in [
		[13.2, 16.8], [16.8, 20.4], [20.4, 24.4], [29.2, 31.4],
	]:
		var z0 := float(e_pair[0]); var z1 := float(e_pair[1])
		m_cols.bar(m.steel_dark, Vector3(46.86, 0.24, z0 + 0.14), Vector3(46.86, 2.20, z1 - 0.14), 0.10)
		m_cols.bar(m.steel_dark, Vector3(46.86, 2.20, z0 + 0.14), Vector3(46.86, 0.24, z1 - 0.14), 0.10)

	# Lower red industrial dado stripe (y=0.76m) & high overhead fire-suppression pipe runs (y=3.55m / 3.80m)
	m_cols.box(m.can_red_prop, Vector3(25.12, 0.76, 25.9), Vector3(0.08, 0.12, 25.2))
	m_cols.box(m.can_red_prop, Vector3(30.5, 0.76, 13.12), Vector3(10.6, 0.12, 0.08))
	m_cols.box(m.can_red_prop, Vector3(43.4, 0.76, 13.12), Vector3(6.8, 0.12, 0.08))
	m_cols.box(m.can_red_prop, Vector3(46.88, 0.76, 18.8), Vector3(0.08, 0.12, 11.2))
	for pipe_run: Array in [
		[Vector3(25.16, 3.60, 13.2), Vector3(25.16, 3.60, 38.6)],
		[Vector3(25.2, 3.60, 13.16), Vector3(46.8, 3.60, 13.16)],
		[Vector3(46.84, 3.60, 13.2), Vector3(46.84, 3.60, 38.6)],
	]:
		m_cols.bar(m.can_red_prop, pipe_run[0], pipe_run[1], 0.14)
		m_cols.bar(m.pipe_rusted, pipe_run[0] + Vector3(0.0, 0.24, 0.0), pipe_run[1] + Vector3(0.0, 0.24, 0.0), 0.09)
	_commit_mb(host, grp, "LogisticsStructuralColumns", m_cols, Vector3.ZERO, true)

	# 3. Perimeter Portals ONLY (East Entrance 46.8, 34.0 & North Exit 38.0, 13.0 — zero interior doorways!)
	var p_mb := WAREHOUSE.MeshBuilder.new()
	var portals := [
		["Portal_AirlockE", Vector3(46.8, 0.0, 34.0), 3.6, 90.0, m.beacon_green],
		["Portal_ExitLink", Vector3(38.0, 0.0, 13.0), 3.5, 0.0, m.beacon_green],
	]
	for p_info: Array in portals:
		var pname: String = p_info[0]
		var ppos: Vector3 = p_info[1]
		var pw: float = float(p_info[2])
		var pyaw: float = float(p_info[3])
		var lmat: Material = p_info[4]
		var arch: Node3D = host.fittings.fit(grp, "Door_Frame_Square",
			ppos + Vector3(0.0, 1.24, 0.0), Vector3(pw + 0.56, 2.48, 0.38), Vector3(0.0, pyaw, 0.0))
		arch.name = pname
		host.cutout.register_tree(arch)
		var along_z := absf(pyaw) > 45.0
		for s: float in [-1.0, 1.0]:
			var off := Vector3(0.0, 0.45, s * (pw * 0.5 + 0.14)) if along_z else Vector3(s * (pw * 0.5 + 0.14), 0.45, 0.0)
			p_mb.box(m.safety_yellow, ppos + off, Vector3(0.42, 0.90, 0.18) if along_z else Vector3(0.18, 0.90, 0.42))
		var h_sz := Vector3(0.44, 0.07, pw * 0.55) if along_z else Vector3(pw * 0.55, 0.07, 0.44)
		p_mb.box(lmat, ppos + Vector3(0.0, 2.38, 0.0), h_sz)
		if along_z:
			p_mb.quad(m.hazard,
				ppos + Vector3(-0.36, 0.009, -pw * 0.46), ppos + Vector3(0.36, 0.009, -pw * 0.46),
				ppos + Vector3(0.36, 0.009, pw * 0.46), ppos + Vector3(-0.36, 0.009, pw * 0.46),
				Vector3.UP, Vector2(0, 0), Vector2(1, 0), Vector2(1, 3), Vector2(0, 3))
		else:
			p_mb.quad(m.hazard,
				ppos + Vector3(-pw * 0.46, 0.009, -0.36), ppos + Vector3(pw * 0.46, 0.009, -0.36),
				ppos + Vector3(pw * 0.46, 0.009, 0.36), ppos + Vector3(-pw * 0.46, 0.009, 0.36),
				Vector3.UP, Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	_commit_mb(host, grp, "PortalTrimAndThresholds", p_mb, Vector3.ZERO, true)
	# Upper wall lintels above doorways so 4.20m top_black perimeter wall crown is continuous
	host.boundary_wall(grp, "PortalLintel_E", Rect2(46.90, 31.95, 0.20, 4.10), 2.46, 1.74, Vector2.RIGHT, host.lounge_wall)
	host.boundary_wall(grp, "PortalLintel_N", Rect2(36.20, 12.90, 3.60, 0.20), 2.46, 1.74, Vector2.UP, host.lounge_wall)


static func _build_octagonal_bay_doors(host, parent: Node3D, m: Dictionary) -> void:
	# Compact High-Bay Corrugated Roller Shutter on East Perimeter Wall (South stays low 0.65m cutaway)
	var grp := _group(parent, "CargoBayDoors")
	var mb := WAREHOUSE.MeshBuilder.new()
	var shutters := [
		[Vector3(46.84, 0.0, 26.8), -90.0, 2.6, m.beacon_red],
	]
	for spec: Array in shutters:
		var pos: Vector3 = spec[0]
		var yaw: float = float(spec[1])
		var w: float = float(spec[2])
		var lamp_m: Material = spec[3]
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos)
		var b_pos := func(lp: Vector3) -> Vector3: return xf * lp
		var fwd := xf.basis.z
		var right := xf.basis.x
		# Jamb columns + yellow bumpers + drum header + yellow safety stripe
		for sx: float in [-1.0, 1.0]:
			var jpos := pos + right * (sx * (w * 0.5 + 0.14))
			FREIGHT._emit_local_box(mb, m.steel_dark, Transform3D(xf.basis, jpos), Vector3(0.0, 1.24, 0.0), Vector3(0.28, 2.48, 0.30))
			FREIGHT._emit_local_box(mb, m.safety_yellow, Transform3D(xf.basis, jpos), Vector3(0.0, 0.45, 0.04), Vector3(0.30, 0.90, 0.32))
		FREIGHT._emit_local_box(mb, m.steel_dark, xf, Vector3(0.0, 2.34, 0.06), Vector3(w + 0.48, 0.36, 0.34))
		FREIGHT._emit_local_box(mb, m.safety_yellow, xf, Vector3(0.0, 2.46, 0.24), Vector3(w + 0.36, 0.10, 0.04))
		FREIGHT._emit_local_box(mb, lamp_m, xf, Vector3(0.0, 2.32, 0.24), Vector3(0.46, 0.12, 0.06))
		# Corrugated curtain face + bottom safety bumper
		var c_bl: Vector3 = b_pos.call(Vector3(-w * 0.5, 0.08, 0.06))
		var c_br: Vector3 = b_pos.call(Vector3(w * 0.5, 0.08, 0.06))
		var c_tr: Vector3 = b_pos.call(Vector3(w * 0.5, 2.22, 0.06))
		var c_tl: Vector3 = b_pos.call(Vector3(-w * 0.5, 2.22, 0.06))
		mb.quad(m.corrugated, c_bl, c_br, c_tr, c_tl, fwd, Vector2(0, 3), Vector2(3, 3), Vector2(3, 0), Vector2(0, 0))
		FREIGHT._emit_local_box(mb, m.safety_yellow, xf, Vector3(0.0, 0.07, 0.08), Vector3(w + 0.04, 0.14, 0.08))
		# Floor hazard apron
		mb.quad(m.hazard,
			b_pos.call(Vector3(-w * 0.52, 0.010, 0.0)), b_pos.call(Vector3(w * 0.52, 0.010, 0.0)),
			b_pos.call(Vector3(w * 0.52, 0.010, 0.85)), b_pos.call(Vector3(-w * 0.52, 0.010, 0.85)),
			Vector3.UP, Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	_commit_mb(host, grp, "CorrugatedShuttersMesh", mb, Vector3.ZERO, true)


static func _build_hell_command_console(kit, host, parent: Node3D, node_name: String,
		pos: Vector3, width: float, yaw_deg: float, screen_tint: Color, m: Dictionary) -> Node3D:
	var con := _group(parent, node_name)
	con.position = pos
	con.rotation.y = deg_to_rad(yaw_deg)

	# Heavy bunker pedestal & drawer bays
	kit.box(con, "ConsoleBase", Vector3(width, 0.70, 0.86), Vector3(0.0, 0.35, -0.02), m.charcoal)
	kit.box(con, "ConsoleApron", Vector3(width - 0.18, 0.08, 0.38), Vector3(0.0, 0.74, 0.24), m.charcoal)
	for sx: float in [-1.0, 1.0]:
		var ex := sx * (width * 0.5 - 0.04)
		kit.box(con, "ConsoleCheek", Vector3(0.08, 0.62, 0.92), Vector3(ex, 0.98, -0.04), m.charcoal)
		kit.box(con, "ConsoleDrawer", Vector3(0.46, 0.54, 0.03), Vector3(sx * (width * 0.5 - 0.32), 0.36, 0.42), m.slate_mid)

	# Sloped 32-deg telemetry hood with glowing green/amber CRT panels & dense LED switch matrices
	var hood := _group(con, "ConsoleSlopedHood")
	hood.position = Vector3(0.0, 0.98, -0.04)
	hood.rotation_degrees = Vector3(-32.0, 0.0, 0.0)
	var iw := width - 0.18
	kit.box(hood, "HoodHousing", Vector3(iw, 0.54, 0.44), Vector3(0.0, 0.04, 0.0), m.charcoal)
	kit.box(hood, "HoodFacePanel", Vector3(iw - 0.10, 0.44, 0.03), Vector3(0.0, 0.04, 0.22), m.slate_mid)

	for s_i in 2:
		var scr_x := (-0.28 + float(s_i) * 0.56) * minf(1.0, iw / 2.4)
		var scr_w := clampf(iw * 0.23, 0.36, 0.56)
		kit.box(hood, "ScreenBezel_%d" % s_i, Vector3(scr_w + 0.06, 0.28, 0.025), Vector3(scr_x, 0.06, 0.235), m.charcoal)
		var video := StandardMaterial3D.new()
		video.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		video.albedo_texture = CAMERA_FEEDS
		video.albedo_color = screen_tint
		video.emission_enabled = true
		video.emission = screen_tint * 0.55
		video.uv1_scale = Vector3(1.0, 0.5, 1.0)
		video.uv1_offset = Vector3(0.0, float(s_i) * 0.5, 0.0)
		video.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var scr := kit.quad(hood, "RadarFeed_%d" % s_i, Vector2(scr_w, 0.22), Vector3(scr_x, 0.06, 0.252), video) as MeshInstance3D
		scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Flanking illuminated switch & gauge matrices + toggle levers on console desk
	var bank_cols := [m.beacon_red, m.green_led, m.amber_led]
	for side_s: float in [-1.0, 1.0]:
		var bx := side_s * (iw * 0.36)
		for row in 3:
			for col in 3:
				var lx := bx + (float(col) - 1.0) * 0.09
				var ly := 0.14 - float(row) * 0.075
				var lmat: Material = bank_cols[(row + col) % 3]
				kit.box(hood, "LedKey", Vector3(0.045, 0.026, 0.02), Vector3(lx, ly, 0.248), lmat)
	for ti in 4:
		var tx := lerpf(-iw * 0.28, iw * 0.28, float(ti) / 3.0)
		kit.box(con, "DeskStripBtn_%d" % ti, Vector3(0.14, 0.022, 0.05), Vector3(tx, 0.785, 0.34), bank_cols[ti % 3])
		kit.pipe(con, Vector3(tx, 0.78, 0.22), Vector3(tx, 0.85, 0.26), 0.011, m.steel_bright)

	host.cutout.register_tree(con)
	return con


static func _build_sorting_hub_and_conveyors(host, parent: Node3D, m: Dictionary) -> void:
	# 1. Command Console Pit Corner Brackets & Minimal Oil Decals
	var floor_mb := WAREHOUSE.MeshBuilder.new()
	WAREHOUSE._add_floor_corner_brackets(floor_mb, m.safety_yellow, Vector2(32.6, 26.7), Vector2(8.4, 7.8), 0.0)
	var markings_mi := MeshInstance3D.new()
	markings_mi.name = "LogisticsFloorMarkings"
	markings_mi.mesh = floor_mb.call("bake") as ArrayMesh
	markings_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(markings_mi)

	var kit = host.m
	if kit.decal_oil_stain != null:
		var decals := _group(parent, "LogisticsWeatheringDecals")
		for idx_oil: Array in [
			[Vector2(2.4, 1.9), Vector3(39.8, 0.008, 32.8), 18.0, kit.decal_oil_stain],
			[Vector2(2.6, 1.8), Vector3(34.5, 0.008, 34.5), -22.0, kit.decal_oil_stain],
			[Vector2(3.4, 1.3), Vector3(37.5, 0.010, 29.0), 86.0, kit.decal_scuff_streak],
		]:
			var dq: MeshInstance3D = kit.quad(decals, "HubDecal", idx_oil[0], idx_oil[1], idx_oil[3], Vector3(-90.0, idx_oil[2], 0.0))
			dq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 2. Front-Right Primary Command Console Bank (SortingHubKiosk at 33.8, 28.6 + twin teal chairs + stacked archive boxes)
	var kiosk_grp := _group(parent, "SortingHubKiosk")
	_build_hell_command_console(kit, host, kiosk_grp, "FrontConsoleR", Vector3(33.8, 0.0, 28.6), 3.0, 0.0, Color("8fffb2"), m)
	for cx: float in [33.1, 34.5]:
		var ch_r: Node3D = host.fittings.fit(kiosk_grp, KENNEY + "chairDesk.glb", Vector3(cx, 0.47, 29.85), Vector3(0.62, 0.94, 0.62), Vector3(0.0, 180.0, 0.0))
		_paint_surface(ch_r, "carpet", m.worn_fabric_prop)
		_paint_surface(ch_r, "metalMedium", m.brushed_iron_prop)
	# Stacked archive cardboard boxes at front-right corner of Primary Console (matching Hell is Us reference!)
	for b_spec: Array in [
		[Vector3(35.38, 0.22, 29.18), Vector3(0.42, 0.40, 0.36), 6.0],
		[Vector3(35.80, 0.20, 29.10), Vector3(0.38, 0.36, 0.34), -8.0],
		[Vector3(35.56, 0.58, 29.15), Vector3(0.40, 0.34, 0.32), 14.0],
	]:
		var abox: Node3D = host.fittings.fit(kiosk_grp, KENNEY + "cardboardBoxClosed.glb", b_spec[0], b_spec[1], Vector3(0.0, float(b_spec[2]), 0.0))
		_paint_cardboard(abox, m)
		host.cutout.register_tree(abox)
	host._fixture_body("SortingHubKiosk", Rect2(32.2, 27.9, 3.2, 1.4))

	# 3. Front-Left Command Console (ConveyorChute_SW at 30.4, 28.6) & Rear-Right Command Console (ConveyorChute_SE at 34.0, 24.8)
	var sw_grp := _group(parent, "ConveyorChute_SW")
	_build_hell_command_console(kit, host, sw_grp, "FrontConsoleL", Vector3(30.4, 0.0, 28.6), 2.6, 0.0, Color("7cffaa"), m)
	var ch_sw: Node3D = host.fittings.fit(sw_grp, KENNEY + "chairDesk.glb", Vector3(30.4, 0.47, 29.85), Vector3(0.62, 0.94, 0.62), Vector3(0.0, 180.0, 0.0))
	_paint_surface(ch_sw, "carpet", m.worn_fabric_prop)
	_paint_surface(ch_sw, "metalMedium", m.brushed_iron_prop)
	var sw_mb := WAREHOUSE.MeshBuilder.new()
	WAREHOUSE._add_olive_crate_pair(sw_mb, m, Vector3(28.55, 0.0, 28.6), Vector3(0.95, 0.72, 0.76))
	_commit_mb(host, sw_grp, "ConsoleFlankCrates", sw_mb, Vector3.ZERO, true)
	host._fixture_body("ConveyorChute_SW", Rect2(29.0, 27.9, 2.8, 1.4))

	var se_grp := _group(parent, "ConveyorChute_SE")
	_build_hell_command_console(kit, host, se_grp, "RearConsoleR", Vector3(34.0, 0.0, 24.8), 2.8, 0.0, Color("ffb370"), m)
	var ch_se: Node3D = host.fittings.fit(se_grp, KENNEY + "chairDesk.glb", Vector3(34.0, 0.47, 26.05), Vector3(0.62, 0.94, 0.62), Vector3(0.0, 180.0, 0.0))
	_paint_surface(ch_se, "carpet", m.worn_fabric_prop)
	_paint_surface(ch_se, "metalMedium", m.brushed_iron_prop)
	host._fixture_body("ConveyorChute_SE", Rect2(32.5, 24.1, 3.0, 1.4))

	# 4. Overhead Cable-Tray Gantry Beam spanning rear of Command Pit (x=28.5..36.2, z=23.35, y=2.55m)
	var arm_grp := _group(parent, "OverheadConveyorArm")
	var amb := WAREHOUSE.MeshBuilder.new()
	for px: float in [28.6, 36.1]:
		amb.box(m.steel_dark, Vector3(px, 1.28, 23.35), Vector3(0.24, 2.56, 0.24))
		amb.box(m.safety_yellow, Vector3(px, 0.36, 23.35), Vector3(0.28, 0.72, 0.28))
	amb.bar(m.steel_dark, Vector3(28.5, 2.55, 23.35), Vector3(36.2, 2.55, 23.35), 0.22)
	amb.bar(m.rack_orange, Vector3(28.5, 2.38, 23.35), Vector3(36.2, 2.38, 23.35), 0.09)
	_commit_mb(host, arm_grp, "OverheadCableTrayMesh", amb, Vector3.ZERO, true)
	host._fixture_body("OverheadArmPillar", Rect2(28.45, 23.20, 0.35, 0.35))


static func _build_dispatch_control_office(host, parent: Node3D, m: Dictionary) -> void:
	# Rear-Left Command Console (30.4, 24.8) + 4 Tall Black Server/Patch Racks (z=23.35) + Arching Orange Cables
	var kit = host.m
	var grp := _group(parent, "DispatchControlOffice")
	_build_hell_command_console(kit, host, grp, "RearConsoleL", Vector3(30.4, 0.0, 24.8), 2.6, 0.0, Color("ff9e64"), m)
	var ch_rl: Node3D = host.fittings.fit(grp, KENNEY + "chairDesk.glb", Vector3(30.4, 0.47, 26.05), Vector3(0.62, 0.94, 0.62), Vector3(0.0, 180.0, 0.0))
	_paint_surface(ch_rl, "carpet", m.worn_fabric_prop)
	_paint_surface(ch_rl, "metalMedium", m.brushed_iron_prop)

	# 4 Tall Black Patch/Server Racks backing the rear command row + upper indicator boxes + arching cable bundles
	for ri in 4:
		var rx := 29.6 + float(ri) * 1.72
		var pat := Vector3(rx, 0.0, 23.35)
		kit.box(grp, "ServerPatchBox_%d" % ri, Vector3(1.16, 1.88, 0.74), pat + Vector3(0.0, 0.94, 0.0), m.charcoal, true)
		kit.box(grp, "ServerTopDeck_%d" % ri, Vector3(1.10, 0.38, 0.68), pat + Vector3(0.0, 2.08, 0.0), m.slate_mid, true)
		for l_col in 4:
			var lx := -0.34 + float(l_col) * 0.22
			kit.box(grp, "PatchLed_%d_%d" % [ri, l_col], Vector3(0.08, 0.04, 0.02),
				pat + Vector3(lx, 2.12, 0.35), m.green_led if l_col % 2 == 0 else m.amber_led)
		var srv: Node3D = OFFICE.make_visual("server", true)
		srv.name = "CommandServer_%d" % ri
		srv.position = pat + Vector3(0.0, 0.0, 0.10)
		srv.scale = Vector3(0.82, 0.96, 0.62)
		grp.add_child(srv)
		host.cutout.register_tree(srv)
		# Arching orange/yellow power umbilical feeding server top -> rear console back
		_cable_chain(host, grp, [
			pat + Vector3(-0.14, 1.92, 0.36),
			pat + Vector3(-0.18, 1.62, 0.72),
			pat + Vector3(-0.14, 1.02, 1.05),
		], 0.032, m.rack_orange)
		_cable_chain(host, grp, [
			pat + Vector3(0.16, 1.88, 0.36),
			pat + Vector3(0.18, 1.54, 0.76),
			pat + Vector3(0.14, 0.96, 1.08),
		], 0.026, m.safety_yellow)

	host._fixture_body("CommandRearConsoleL", Rect2(29.0, 24.1, 2.8, 1.4))
	host._fixture_body("CommandServerRow", Rect2(28.9, 22.9, 6.7, 0.95))


static func _build_forklift_and_receiving_bays(host, parent: Node3D, m: Dictionary) -> void:
	var kit = host.m
	# 1. South Utility Forklift Bay (34.8, 36.8)
	var fk_grp := _group(parent, "ForkliftCorridorBay")
	var fk := MINI_FORKLIFT_SCRIPT.new() as Node3D
	fk.name = "LogisticsForkliftHero"
	fk.position = Vector3(34.8, 0.0, 36.8)
	fk.scale = Vector3.ONE * 0.80
	fk.process_mode = Node.PROCESS_MODE_DISABLED
	fk_grp.add_child(fk)
	host.cutout.register_tree(fk)
	host._fixture_body("LogisticsForklift", Rect2(33.8, 35.9, 2.60, 1.65))

	# 2. East Red-Core Reactor/Telemetry Pillar (42.2, 26.8) — Hell is Us Right Focal Landmark!
	var pods_grp := _group(parent, "ReceivingPods")
	var rp := Vector3(42.2, 0.0, 26.8)
	kit.box(pods_grp, "ReactorRedTrim", Vector3(2.28, 0.05, 2.28), rp + Vector3(0.0, 0.025, 0.0), m.can_red)
	kit.box(pods_grp, "ReactorPlinth", Vector3(2.10, 0.14, 2.10), rp + Vector3(0.0, 0.08, 0.0), m.charcoal, true)
	var leg_mb := WAREHOUSE.MeshBuilder.new()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			leg_mb.bar(m.steel_dark, rp + Vector3(sx * 0.94, 0.14, sz * 0.94), rp + Vector3(sx * 0.36, 1.38, sz * 0.36), 0.16)
			leg_mb.bar(m.steel_mid, rp + Vector3(sx * 0.34, 1.38, sz * 0.34), rp + Vector3(sx * 0.34, 2.95, sz * 0.34), 0.10)
	_commit_mb(host, pods_grp, "ReactorStabilizerFrame", leg_mb, Vector3.ZERO, true)
	kit.box(pods_grp, "ReactorCoreHousing", Vector3(0.92, 1.05, 0.92), rp + Vector3(0.0, 0.72, 0.0), m.charcoal, true)
	kit.box(pods_grp, "ReactorTransceiver", Vector3(0.84, 0.72, 0.96), rp + Vector3(0.88, 0.78, 0.0), m.slate_mid, true)
	kit.box(pods_grp, "ReactorTransceiverStripe", Vector3(0.86, 0.08, 0.98), rp + Vector3(0.88, 1.08, 0.0), m.amber_led)
	kit.cylinder(pods_grp, "ReactorCrimsonCore", 0.30, 1.15, rp + Vector3(0.0, 2.02, 0.0), m.beacon_red)
	kit.cylinder(pods_grp, "ReactorAmberRingLo", 0.35, 0.10, rp + Vector3(0.0, 1.50, 0.0), m.amber_led)
	kit.cylinder(pods_grp, "ReactorAmberRingHi", 0.35, 0.10, rp + Vector3(0.0, 2.52, 0.0), m.amber_led)
	kit.box(pods_grp, "ReactorCrownCap", Vector3(1.06, 0.28, 1.06), rp + Vector3(0.0, 2.98, 0.0), m.charcoal, true)
	host._fixture_body("ReceivingReactorPillar", Rect2(41.0, 25.6, 2.40, 2.40))

	# 3. Bundled Orange/Yellow/Charcoal Floor Trunk Cables (Reactor 41.2, 26.8 -> Consoles 35.5, 24.8/28.6) & East Cargo Bundle
	var rec_grp := _group(parent, "ReceivingVestibule")
	for ci in 5:
		var z_off := (float(ci) - 2.0) * 0.14
		var cmat: Material = m.rack_orange if ci % 2 == 0 else (m.safety_yellow if ci == 1 else m.charcoal_prop)
		var r_c := 0.032 if ci % 2 == 0 else 0.024
		_cable_chain(host, rec_grp, [
			Vector3(41.3, 0.032, 26.8 + z_off),
			Vector3(39.4, 0.030, 26.8 + z_off * 1.4),
			Vector3(37.6, 0.028, 26.7 + z_off * 1.6),
			Vector3(35.4, 0.030, 28.2 + z_off if ci >= 2 else 25.1 + z_off),
		], r_c, cmat)
		if ci < 3:
			_cable_chain(host, rec_grp, [
				Vector3(42.2 + z_off * 0.8, 0.028, 27.9),
				Vector3(43.4 + z_off, 0.028, 28.4),
				Vector3(45.2 + z_off, 0.028, 28.9),
			], 0.026, cmat)
	_add_cargo_bundle(rec_grp, "ReceivingCratesSEMesh", Vector3(45.2, 0.0, 37.1), Vector3(1.85, 1.22, 1.65), 501)
	host._fixture_body("ReceivingCratesSE", Rect2(44.2, 36.2, 2.00, 1.80))


static func _build_medbay_wing(host, parent: Node3D, m: Dictionary) -> void:
	var kit = host.m
	# SW Corner Clinical Bay (25..32 x 31..39) keeping MEDICINE at (27.6, 35.8)
	var grp := _group(parent, "MedBayFittings")
	kit.box(grp, "MedCounterBase", Vector3(0.92, 0.44, 2.80), Vector3(25.65, 0.22, 34.0), m.sage_green, true)
	kit.box(grp, "MedCounterUpper", Vector3(0.92, 0.40, 2.80), Vector3(25.65, 0.64, 34.0), m.enamel, true)
	kit.box(grp, "MedCounterSill", Vector3(0.98, 0.045, 2.88), Vector3(25.65, 0.86, 34.0), m.stone_sill)
	host.fittings.fit(grp, KENNEY + "bathroomSink.glb", Vector3(25.65, 1.06, 33.15), Vector3(0.75, 0.88, 0.96), Vector3(0.0, 90.0, 0.0))
	kit.pipe(grp, Vector3(25.25, 0.95, 33.15), Vector3(25.25, 1.32, 33.15), 0.032, m.steel_bright)
	_build_crt_monitor(kit, grp, Vector3(25.65, 0.88, 34.45), 0, 90.0, m)

	kit.box(grp, "MedCabBody", Vector3(0.96, 1.32, 0.84), Vector3(25.70, 1.34, 31.4), m.slate_mid, true)
	kit.box(grp, "MedCabDado", Vector3(0.98, 0.68, 0.85), Vector3(25.70, 0.34, 31.4), m.charcoal, true)
	kit.box(grp, "MedCabLatch", Vector3(0.04, 0.14, 0.08), Vector3(26.19, 1.18, 31.4), m.can_red)

	var bin: Node3D = host.fittings.fit(grp, KENNEY + "trashcan.glb", Vector3(25.55, 0.40, 36.1), Vector3(0.46, 0.72, 0.46))
	_paint_surface(bin, "metal", m.can_red)
	_paint_surface(bin, "metalDark", m.charcoal_prop)

	host._fixture_body("MedCounterNW", Rect2(25.15, 32.5, 1.05, 3.0))
	host._fixture_body("MedLockersNE", Rect2(25.2, 30.9, 1.05, 1.0))


static func _build_south_cargo_vault(host, parent: Node3D, m: Dictionary) -> void:
	# SE Perimeter Wall Storage Rack (38.0..43.4 x 36.8..38.45) — 1-2 Giant Steel Warehouse Rack
	var grp := _group(parent, "SouthCargoVault")
	var rack_rect := Rect2(38.0, 36.8, 5.4, 1.65)
	WAREHOUSE.build_giant_rack(grp, rack_rect, 0.0, 2.65, 494, host.cutout)
	host._fixture_body("VaultRack_38", rack_rect)


static func _build_north_concourse(host, parent: Node3D, m: Dictionary) -> void:
	# Elevated Yellow-Steel Mezzanine Catwalk (y=2.25m) along West & NW Perimeter + Under-Balcony Storage Racks
	var kit = host.m
	var grp := _group(parent, "NorthConcourse")

	# 1. Two 1-2 Giant Steel Storage Racks beneath North-West Mezzanine (y=0.0..2.12m)
	WAREHOUSE.build_giant_rack(grp, Rect2(25.4, 13.5, 4.2, 1.55), 0.0, 2.12, 701, host.cutout)
	WAREHOUSE.build_giant_rack(grp, Rect2(30.2, 13.5, 4.2, 1.55), 0.0, 2.12, 702, host.cutout)
	host._fixture_body("NorthMemoRacks", Rect2(25.3, 13.4, 9.20, 1.75))

	# Recessed Steel Maintenance Ladder at NW Balcony East End (35.2, 13.45)
	var lad := Vector3(35.2, 0.0, 13.45)
	kit.box(grp, "AlcoveFrame", Vector3(1.10, 2.40, 0.44), lad + Vector3(0.0, 1.20, 0.0), m.charcoal, true)
	for sx: float in [-0.32, 0.32]:
		kit.pipe(grp, lad + Vector3(sx, 0.08, 0.25), lad + Vector3(sx, 2.38, 0.25), 0.028, m.steel_bright)
	for ri in 7:
		var ry := 0.28 + float(ri) * 0.31
		kit.pipe(grp, lad + Vector3(-0.32, ry, 0.25), lad + Vector3(0.32, ry, 0.25), 0.022, m.steel_bright)
	host._fixture_body("AccessLadderAlcove", Rect2(34.6, 13.05, 1.35, 0.85))

	# 2. Elevated Yellow Mezzanine Deck, Support Columns, Knee Braces, Handrails, Draped Blue Tarp & Upper Cargo
	var mez := _group(grp, "MezzanineCatwalk")
	var my := 2.25
	var mb := WAREHOUSE.MeshBuilder.new()
	# Deck slabs at y=2.25m (West leg 25.2..28.0 x 13.2..31.2 + NW wrap 28.0..35.6 x 13.2..16.0)
	mb.box(m.steel_dark, Vector3(26.6, my, 22.2), Vector3(2.8, 0.14, 18.0))
	mb.box(m.steel_dark, Vector3(31.8, my, 14.6), Vector3(7.6, 0.14, 2.8))
	# Heavy yellow structural fascia girders & underside beams
	mb.box(m.safety_yellow, Vector3(27.95, my - 0.08, 23.5), Vector3(0.18, 0.24, 15.4))
	mb.box(m.safety_yellow, Vector3(31.75, my - 0.08, 15.95), Vector3(7.7, 0.24, 0.18))
	mb.box(m.safety_yellow, Vector3(26.6, my - 0.08, 31.12), Vector3(2.8, 0.24, 0.18))
	mb.box(m.safety_yellow, Vector3(35.52, my - 0.08, 14.6), Vector3(0.18, 0.24, 2.8))

	# Support I-beam columns + diagonal knee braces (thin 0.20m footprints with matching post colliders)
	for post_pt: Vector2 in [
		Vector2(27.95, 16.0), Vector2(27.95, 20.0), Vector2(27.95, 24.0), Vector2(27.95, 28.0), Vector2(27.95, 31.1),
		Vector2(30.2, 15.95), Vector2(34.6, 15.95),
	]:
		mb.box(m.safety_yellow, Vector3(post_pt.x, my * 0.5, post_pt.y), Vector3(0.20, my, 0.20))
		mb.bar(m.safety_yellow, Vector3(post_pt.x, my - 0.55, post_pt.y), Vector3(post_pt.x - (0.45 if post_pt.x < 28.5 else 0.0), my - 0.10, post_pt.y - (0.45 if post_pt.y < 16.5 else 0.0)), 0.09)
		if post_pt.y > 16.5 or post_pt.x > 29.0:
			host._fixture_body("MezzPost_%d_%d" % [int(post_pt.x * 10), int(post_pt.y * 10)], Rect2(post_pt.x - 0.16, post_pt.y - 0.16, 0.32, 0.32))
	_commit_mb(host, mez, "MezzanineStructureMesh", mb, Vector3.ZERO, true)

	# Continuous yellow handrails along upper catwalk rim (y=2.32..3.25m)
	_add_bolted_guardrail(host, mez, "MezzRailWest", Vector3(27.94, my + 0.06, 15.96), Vector3(27.94, my + 0.06, 31.12), 0.94, true)
	_add_bolted_guardrail(host, mez, "MezzRailNorth", Vector3(27.94, my + 0.06, 15.96), Vector3(35.52, my + 0.06, 15.96), 0.94, true)
	_add_bolted_guardrail(host, mez, "MezzRailSouthCap", Vector3(25.25, my + 0.06, 31.12), Vector3(27.94, my + 0.06, 31.12), 0.94, true)
	_add_bolted_guardrail(host, mez, "MezzRailEastCap", Vector3(35.52, my + 0.06, 13.25), Vector3(35.52, my + 0.06, 15.96), 0.94, true)

	# Draped blue canvas tarp hanging over center west mezzanine railing (exact Hell is Us motif)
	kit.box(mez, "MezzBlueTarpTop", Vector3(0.24, 0.12, 2.55), Vector3(27.95, my + 0.94, 21.85), m.blue_tarp)
	kit.box(mez, "MezzBlueTarpDrop", Vector3(0.10, 0.86, 2.48), Vector3(28.04, my + 0.50, 21.85), m.blue_tarp)

	# Upper catwalk drums, pallet crates & stacked cardboard boxes
	host.fittings.barrel(mez, Vector3(26.2, my + 0.52, 26.8), 0.90, 0.54, true, Color("2e628f"), true)
	host.fittings.barrel(mez, Vector3(26.85, my + 0.52, 27.3), 0.90, 0.54, true, Color("2e628f"), true)
	host.fittings.barrel(mez, Vector3(26.4, my + 0.52, 29.4), 0.90, 0.54, true, Color("9e342d"), true)
	var mez_crates := WAREHOUSE.build_cargo_stack(mez, Rect2(29.2, 13.6, 3.2, 1.75), my + 0.07, 1.05, 709, host.cutout)
	mez_crates.name = "MezzUpperCrates"
	_add_cargo_bundle(mez, "MezzWestCrates", Vector3(26.4, my + 0.07, 18.2), Vector3(1.45, 0.78, 1.15), 703)
	host.cutout.register_tree(mez)


static func _add_3d_armory_weapon_relief(mb: RefCounted, origin: Vector3, yaw: float, mode: int, m: Dictionary) -> void:
	# Multi-part 3D firearms & tactical gear silhouettes in relief on angled pegboard panels (zero 2D PNG planes!)
	var b := Basis(Vector3.UP, yaw)
	var emit_part := func(mat: Material, lp: Vector3, lsz: Vector3, tilt_z := 0.0) -> void:
		var lb := Basis(Vector3.FORWARD, tilt_z)
		var xf := Transform3D(b * lb, origin + b * lp)
		FREIGHT._emit_local_box(mb, mat, xf, Vector3.ZERO, lsz)

	if mode == 0:
		# Tactical kevlar vest + pouches + combat rifle + twin sidearms + carbine
		emit_part.call(m.olive_crate, Vector3(-0.54, 0.04, 0.11), Vector3(0.42, 0.54, 0.07))
		emit_part.call(m.steel_dark, Vector3(-0.54, -0.06, 0.145), Vector3(0.32, 0.16, 0.04))
		# Assault Rifle upper row
		emit_part.call(m.steel_dark, Vector3(0.24, 0.24, 0.105), Vector3(0.56, 0.10, 0.06))
		emit_part.call(m.steel_bright, Vector3(0.56, 0.26, 0.105), Vector3(0.26, 0.038, 0.038))
		emit_part.call(m.charcoal, Vector3(0.06, 0.23, 0.105), Vector3(0.22, 0.12, 0.05))
		emit_part.call(m.charcoal, Vector3(0.24, 0.13, 0.105), Vector3(0.075, 0.16, 0.045), 0.18)
		# Pistols mid row
		for px: float in [0.12, 0.46]:
			emit_part.call(m.steel_bright, Vector3(px, -0.01, 0.105), Vector3(0.24, 0.075, 0.045))
			emit_part.call(m.charcoal, Vector3(px - 0.07, -0.07, 0.105), Vector3(0.065, 0.11, 0.04), -0.22)
		# Lower tactical carbine
		emit_part.call(m.steel_dark, Vector3(0.28, -0.24, 0.105), Vector3(0.74, 0.10, 0.06))
		emit_part.call(m.walnut_prop, Vector3(-0.02, -0.24, 0.105), Vector3(0.22, 0.11, 0.055))
	elif mode == 1:
		# Center Panel: Heavy sniper rifle with optic, battle rifle, & submachine gun
		for row_idx in 3:
			var ry := 0.26 - float(row_idx) * 0.24
			var rw := 0.96 - float(row_idx % 2) * 0.16
			emit_part.call(m.steel_dark, Vector3(-0.08, ry, 0.105), Vector3(rw * 0.66, 0.095, 0.06))
			emit_part.call(m.steel_bright, Vector3(rw * 0.34, ry + 0.018, 0.105), Vector3(rw * 0.34, 0.035, 0.035))
			emit_part.call(m.charcoal, Vector3(-0.08, ry + 0.08, 0.105), Vector3(0.24, 0.048, 0.045))
			emit_part.call(m.walnut_prop if row_idx == 1 else m.charcoal, Vector3(-0.42, ry - 0.015, 0.105), Vector3(0.22, 0.11, 0.055))
			emit_part.call(m.steel_dark, Vector3(0.02, ry - 0.09, 0.105), Vector3(0.065, 0.13, 0.04), 0.15)
	else:
		# Right Panel: Walnut-stock combat shotguns & drum-fed launcher
		for row_idx in 2:
			var ry := 0.24 - float(row_idx) * 0.24
			emit_part.call(m.steel_dark, Vector3(0.04, ry + 0.02, 0.105), Vector3(0.68, 0.075, 0.055))
			emit_part.call(m.walnut_prop, Vector3(-0.34, ry - 0.01, 0.105), Vector3(0.26, 0.11, 0.055))
			emit_part.call(m.steel_bright, Vector3(0.32, ry - 0.02, 0.105), Vector3(0.24, 0.04, 0.04))
		# Drum-fed heavy launcher bottom row
		emit_part.call(m.steel_dark, Vector3(0.0, -0.22, 0.105), Vector3(0.72, 0.11, 0.065))
		emit_part.call(m.olive_crate, Vector3(-0.06, -0.24, 0.115), Vector3(0.18, 0.18, 0.085))


static func _build_exit_corner_armory(host, parent: Node3D, m: Dictionary) -> void:
	# Wall-Free Open North-East Weapon Corner (40.5..46.6 x 13.3..19.5) — No enclosing walls!
	var kit = host.m

	# 3-Panel Orthogonal Gun Pegboard Wall along North Perimeter Wall + Overhead Hoods + Aligned Pickup Counters
	var rack_grp := _group(parent, "ArmoryPegAndLamps")
	var rack_mb := WAREHOUSE.MeshBuilder.new()
	var panels := [
		[Vector3(41.7, 1.42, 13.55), 0.0, 0, Vector2(41.7, 14.45)],
		[Vector3(43.5, 1.42, 13.55), 0.0, 1, Vector2(43.5, 14.45)],
		[Vector3(45.3, 1.42, 13.55), 0.0, 2, Vector2(45.3, 14.45)],
	]
	for p_info: Array in panels:
		var pc: Vector3 = p_info[0]
		var yaw: float = float(p_info[1])
		var mode: int = int(p_info[2])
		var rack_slot: Vector2 = p_info[3]

		var panel := _group(parent, "ArmoryPegPanel_%d" % mode)
		panel.position = pc
		panel.rotation.y = yaw
		var pb := WAREHOUSE.MeshBuilder.new()
		pb.box(m.steel_dark, Vector3.ZERO, Vector3(1.80, 1.24, 0.12))
		pb.box(m.pegboard, Vector3(0.0, 0.0, 0.045), Vector3(1.66, 1.10, 0.06))
		for bar_y: float in [-0.36, -0.12, 0.12, 0.36]:
			pb.box(m.charcoal_prop, Vector3(0.0, bar_y, 0.078), Vector3(1.56, 0.024, 0.018))
		for hk_x: float in [-0.55, -0.22, 0.18, 0.54]:
			for hk_y: float in [-0.24, 0.02, 0.26]:
				pb.box(m.brushed_iron_prop, Vector3(hk_x, hk_y, 0.090), Vector3(0.024, 0.024, 0.028))
		_commit_mb(host, panel, "PanelBacking_%d" % mode, pb, Vector3.ZERO, false)
		_add_3d_armory_weapon_relief(rack_mb, pc, yaw, mode, m)

		var diffusers: Array[MeshInstance3D] = []
		for l_off: float in [-0.42, 0.42]:
			var l_at := Vector3(l_off, 0.78, 0.26)
			host.fittings.fit(panel, "Prop_Light_Wide", l_at, Vector3(0.56, 0.11, 0.22), Vector3.ZERO)
			var lens := kit.box(panel, "HoodDiffuser", Vector3(0.46, 0.035, 0.14), l_at + Vector3(0.0, -0.042, 0.0), host.fittings.lamp) as MeshInstance3D
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			diffusers.append(lens)
		if mode == 1:
			var weapon_spot: SpotLight3D = host._spot(host.lights_root, "ArmoryWeaponSpot",
				Vector3(43.5, 3.85, 16.35), Vector3(43.5, 0.85, 14.45), Color("ffe6be"), 5.6, 12.0, 45.0)
			weapon_spot.spot_attenuation = 1.15
			weapon_spot.light_specular = 0.65
			host.OPTICS.mark_fixture(panel, weapon_spot, diffusers)

		var rx := rack_slot.x
		var rz := rack_slot.y
		rack_mb.box(m.steel_dark, Vector3(rx, 0.28, rz - 0.10), Vector3(1.56, 0.56, 0.62))
		rack_mb.box(m.steel_mid, Vector3(rx, 0.55, rz - 0.06), Vector3(1.62, 0.04, 0.68))
		rack_mb.box(m.walnut_prop, Vector3(rx, 0.585, rz - 0.04), Vector3(1.64, 0.055, 0.70))
		rack_mb.box(m.safety_yellow, Vector3(rx, 0.59, rz + 0.30), Vector3(1.56, 0.045, 0.05))
		host._fixture_body("ArmoryRackCounter_%d" % mode, Rect2(rx - 0.82, rz - 0.46, 1.64, 0.64))

	_commit_mb(host, rack_grp, "ArmoryPegWeaponsAndCountersMesh", rack_mb, Vector3.ZERO, false)
	_build_crt_monitor(kit, rack_grp, Vector3(46.46, 1.56, 15.20), 1, -90.0, m)

	# Open Corner Gunsmith Workbench (ArmoryWorkbench at 43.3, 17.65 over crimson floor emblem)
	var wb_grp := _group(parent, "ArmoryWorkbench")
	var wb_mesh := load(WORKBENCH_OBJ) as Mesh
	if wb_mesh != null:
		var wb_aabb := wb_mesh.get_aabb()
		var wb_holder := _group(wb_grp, "WorkbenchMeshRoot")
		wb_holder.position = Vector3(43.3, 0.44, 17.65)
		var wb_mi := MeshInstance3D.new()
		wb_mi.name = "GunsmithWorkbenchObj"
		wb_mi.mesh = wb_mesh
		wb_mi.scale = Vector3(2.40 / maxf(wb_aabb.size.x, 0.001), 0.88 / maxf(wb_aabb.size.y, 0.001), 1.04 / maxf(wb_aabb.size.z, 0.001))
		wb_mi.position = -wb_aabb.get_center() * wb_mi.scale
		wb_mi.material_override = m.walnut_prop
		wb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		wb_holder.add_child(wb_mi)
		host.cutout.register_tree(wb_holder)

	var wb_props := WAREHOUSE.MeshBuilder.new()
	var wc := Vector3(43.3, 0.0, 17.65)
	wb_props.box(m.can_red_prop, wc + Vector3(-0.76, 1.03, -0.10), Vector3(0.46, 0.30, 0.28))
	wb_props.box(m.brushed_iron_prop, wc + Vector3(-0.76, 1.08, 0.05), Vector3(0.36, 0.025, 0.02))
	wb_props.box(m.steel_dark, wc + Vector3(0.08, 0.93, 0.02), Vector3(0.58, 0.09, 0.12))
	wb_props.box(m.walnut_prop, wc + Vector3(-0.14, 0.93, 0.02), Vector3(0.22, 0.10, 0.08))
	wb_props.box(m.steel_mid, wc + Vector3(0.86, 0.98, -0.12), Vector3(0.22, 0.18, 0.20))
	WAREHOUSE._add_olive_crate_pair(wb_props, m, wc + Vector3(0.0, 0.0, 0.0), Vector3(0.76, 0.42, 0.58))
	_commit_mb(host, wb_grp, "WorkbenchSurfaceTools", wb_props, Vector3.ZERO, true)
	host._fixture_body("ArmoryWorkbench", Rect2(42.05, 17.05, 2.70, 1.25))

	# Clean East Wall Gun Lockers + Single Corner Ammo Bundle (46.22, 16.5..17.6 & 45.6, 19.2)
	var rs_grp := _group(parent, "ArmoryRightLockers")
	for li in 2:
		var lz := 16.55 + float(li) * 1.10
		if host.service_art != null:
			var lck := _group(rs_grp, "ArmoryGunLocker_%d" % li)
			kit.box(lck, "LockerShell", Vector3(0.76, 1.98, 0.98), Vector3(46.22, 0.99, lz), m.slate_mid, true)
			kit.box(lck, "LockerDado", Vector3(0.77, 0.64, 0.99), Vector3(46.22, 0.32, lz), m.charcoal, true)
			kit.box(lck, "LockerInterior", Vector3(0.04, 1.80, 0.84), Vector3(45.84, 1.00, lz), m.charcoal, true)
			var door := _group(lck, "LockerLeaf")
			door.position = Vector3(45.82, 0.0, lz - 0.42)
			door.rotation.y = -0.58 if li == 0 else -0.15
			kit.box(door, "SteelLeaf", Vector3(0.045, 1.84, 0.82), Vector3(0.0, 1.00, 0.41), m.slate_mid)
			kit.box(door, "DoorLatch", Vector3(0.05, 0.16, 0.035), Vector3(-0.02, 0.96, 0.72), m.steel_bright)
		var cap_mb := WAREHOUSE.MeshBuilder.new()
		WAREHOUSE._add_military_case(cap_mb, m, Vector3(46.22, 1.98, lz), Vector3(0.68, 0.34, 0.86), false)
		_commit_mb(host, rs_grp, "ArmoryLockerTopCase_%d" % li, cap_mb, Vector3.ZERO, true)

	_add_cargo_bundle(rs_grp, "ArmoryRightAmmo", Vector3(45.6, 0.0, 19.2), Vector3(1.40, 0.76, 0.90), 801)
	host._fixture_body("ArmoryRightLockers", Rect2(44.85, 15.9, 1.85, 3.90))


static func _build_ceiling_cove_strips(host, parent: Node3D) -> void:
	var grp := _group(parent, "CeilingLightFixtures")
	var standby_lens := StandardMaterial3D.new()
	standby_lens.albedo_color = Color("3a4244")
	standby_lens.emission_enabled = true
	standby_lens.emission = Color("9daeb3")
	standby_lens.emission_energy_multiplier = 1.05
	standby_lens.roughness = 0.35
	for s: Array in [
		[Vector3(29.5, 3.85, 13.24), 0.0],
		[Vector3(43.5, 3.85, 13.24), 0.0],
		[Vector3(25.24, 3.85, 22.0), 90.0],
		[Vector3(25.24, 3.85, 32.0), 90.0],
		[Vector3(46.76, 3.85, 21.0), -90.0],
		[Vector3(46.76, 3.85, 30.5), -90.0],
	]:
		var mount: Vector3 = s[0]
		var yaw: float = float(s[1])
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), mount)
		host.fittings.fit(grp, "Prop_Light_Wide", mount, Vector3(2.2, 0.14, 0.24), Vector3(0.0, yaw, 0.0))
		var lens: MeshInstance3D = host.m.box(grp, "WallWashDiffuser", Vector3(1.96, 0.045, 0.10), xf * Vector3(0.0, -0.045, 0.08), standby_lens)
		lens.rotation.y = deg_to_rad(yaw)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pool: OmniLight3D = host._omni(grp, "CoveFixturePool", xf * Vector3(0,-.32,.53),
			standby_lens.emission, .42, 5.0, 1.55, false)
		host.OPTICS.mark_fixture(grp, pool, [lens])


static func build_hub_lights(host, root: Node3D) -> void:
	var omnis := [
		["ArmoryCounterBounce", Vector3(43.5, 2.15, 15.25), Color("ffd8a8"), 1.35, 5.4, 1.20],
		["ReactorCoreGlow", Vector3(42.2, 2.10, 26.8), Color("ff3824"), 1.15, 7.2, 1.18],
		["CommandPitScreenGlow", Vector3(33.2, 2.10, 25.5), Color("68b888"), 0.75, 7.5, 1.20],
		["MedBayIndicator", Vector3(28.0, 2.50, 35.2), Color("68a8d8"), 0.70, 6.8, 1.20],
		["SouthForkliftRim", Vector3(36.5, 2.80, 34.5), Color("788c98"), 0.55, 7.5, 1.22],
		["MezzanineCatwalkRim", Vector3(28.5, 3.40, 19.5), Color("8c7e68"), 0.52, 7.5, 1.22],
	]
	for spec: Array in omnis:
		var lamp: OmniLight3D = host._omni(
			root, String(spec[0]), spec[1], spec[2],
			float(spec[3]), float(spec[4]), float(spec[5]), false
		)
		if is_instance_valid(lamp):
			lamp.light_specular = 0.25 if String(spec[0]) == "ArmoryCounterBounce" else 0.14
