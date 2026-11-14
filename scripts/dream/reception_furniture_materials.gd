extends RefCounted
## Reception-only material assignments. Geometry, UVs, collisions and lights
## remain owned by the existing layout. Metro's generator is a read-only study.
const BASE=preload("res://scripts/dream/reception_lobby_art.gd")
const FINISH=preload("res://shaders/dream3d/reception_furniture_pbr.gdshader")
const UPHOLSTERY=preload("res://shaders/dream3d/reception_upholstery.gdshader")
const FABRIC_ALBEDO=preload("res://art/Dream/ReceptionLobby/caban/diff.jpg")
const FABRIC_NORMAL=preload("res://art/Dream/ReceptionLobby/caban/nor_gl.jpg")
const FABRIC_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/caban/rough.jpg")
const IRON_ALBEDO=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png")
const IRON_NORMAL=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png")
const IRON_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png")
const IRON_METALNESS=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Metallic.png")
const METAL_SOURCE="res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_%s.png"
const METAL_TEXTURES={
	"Color":preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Color.png"),
	"NormalGL":preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_NormalGL.png"),
	"Roughness":preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Roughness.png"),
	"Metalness":preload("res://art/Dream/ReceptionLobby/metro_metal012/Metal012_1K-PNG_Metalness.png")
}
static var finishes: Dictionary={}

static func metal_map(channel: String) -> Texture2D:
	var source: String=METAL_SOURCE%channel
	var texture:Texture2D=METAL_TEXTURES[channel]
	texture.set_meta(&"source_file",source)
	texture.set_meta(&"normal_convention","OpenGL +Y" if channel=="NormalGL" else "not_normal")
	return texture

static func upholstery() -> ShaderMaterial:
	if finishes.has("upholstery"):return finishes["upholstery"]
	var result:=ShaderMaterial.new();result.shader=UPHOLSTERY;result.resource_name="LobbyFinish_upholstery"
	result.set_shader_parameter("atlas",BASE.ART.texture())
	result.set_shader_parameter("fabric_albedo",FABRIC_ALBEDO)
	result.set_shader_parameter("fabric_normal",FABRIC_NORMAL)
	result.set_shader_parameter("fabric_roughness",FABRIC_ROUGHNESS)
	result.set_shader_parameter("upholstery_tint",Color("666e69"))
	result.set_meta(&"surface_category","upholstery")
	finishes["upholstery"]=result
	return result

static func material(profile: String) -> ShaderMaterial:
	assert(profile in ["counter_wood","counter_top","table_wood","table_frame","satin_steel","coated_frame","coated_kick","gate_steel","gate_kick","gate_reader"])
	if finishes.has(profile):return finishes[profile]
	var result:=ShaderMaterial.new();result.shader=FINISH;result.resource_name="LobbyFinish_"+profile
	var albedo: Texture2D=metal_map("Color")
	var normal: Texture2D=metal_map("NormalGL")
	var roughness: Texture2D=metal_map("Roughness")
	var metalness_map:Texture2D=metal_map("Metalness")
	var tint:=Color("62747d");var limits:=Vector2(.32,.56)
	var metres:=Vector2(1.5,1.5);var normal_scale:=.18;var metalness:=0.0;var contrast:=1.0;var anisotropy:=0.0
	var midpoint:=Vector3(.65,.65,.65)
	var age:=0.0;var wear:=.65;var exposed:=Vector3(.025,.018,.010)
	var touch:=0.0
	match profile:
		"counter_wood":
			albedo=BASE.WALNUT_ALBEDO;normal=BASE.WALNUT_NORMAL;roughness=BASE.WALNUT_ROUGHNESS
			tint=Color("ccad90");limits=Vector2(.42,.66);metres=Vector2(3.2,1.6);normal_scale=.30
			midpoint=Vector3(.215,.128,.073);contrast=1.45
			age=.65
		"counter_top":
			albedo=BASE.STONE_WALL_ALBEDO;normal=BASE.STONE_WALL_NORMAL;roughness=BASE.STONE_WALL_ROUGHNESS
			tint=Color("e6ddcb");limits=Vector2(.28,.43);metres=Vector2(2.4,2.4);normal_scale=.18;contrast=.65
			age=.4;wear=.45;exposed=Vector3(.02,.02,.018)
		"table_wood":
			albedo=BASE.WALNUT_ALBEDO;normal=BASE.WALNUT_NORMAL;roughness=BASE.WALNUT_ROUGHNESS
			tint=Color("d8c5ae");limits=Vector2(.42,.67);metres=Vector2(1.1,.75);normal_scale=.35
			midpoint=Vector3(.215,.128,.073);contrast=2.0
			age=1.;wear=.85
		"table_frame":
			age=.6;wear=.8;exposed=Vector3(.05,.055,.055)
		"coated_kick":
			tint=Color("29343b");limits=Vector2(.42,.66)
		"satin_steel":
			tint=Color("d8dfe0");limits=Vector2(.26,.48);metres=Vector2(1.6,1.6);normal_scale=.22;metalness=1.0;anisotropy=.4
		"gate_steel":
			albedo=IRON_ALBEDO;normal=IRON_NORMAL;roughness=IRON_ROUGHNESS;metalness_map=IRON_METALNESS
			tint=Color("aab4b3");limits=Vector2(.30,.50);metres=Vector2(1.2,1.2);normal_scale=.22;metalness=.8;anisotropy=.45
			age=.8;wear=.85;touch=.65;exposed=Vector3(.03,.032,.032)
		"gate_kick":
			tint=Color("29343b");limits=Vector2(.48,.72);age=.8;wear=.9;exposed=Vector3(.04,.045,.05)
		"gate_reader":
			tint=Color("29312f");limits=Vector2(.28,.48);age=.65;wear=.8;touch=1.;exposed=Vector3(.03,.032,.032)
	result.set_shader_parameter("finish_albedo",albedo)
	result.set_shader_parameter("finish_normal",normal)
	result.set_shader_parameter("finish_roughness",roughness)
	result.set_shader_parameter("finish_metalness",metalness_map)
	result.set_shader_parameter("finish_colour",tint)
	result.set_shader_parameter("roughness_range",limits)
	result.set_shader_parameter("repeat_metres",metres)
	result.set_shader_parameter("normal_strength",normal_scale)
	result.set_shader_parameter("metallic_level",metalness)
	result.set_shader_parameter("albedo_contrast",contrast)
	result.set_shader_parameter("albedo_midpoint",midpoint)
	result.set_shader_parameter("anisotropy_strength",anisotropy)
	result.set_shader_parameter("wear_amount",wear)
	result.set_shader_parameter("furniture_age",age)
	result.set_shader_parameter("exposed_substrate",exposed)
	result.set_shader_parameter("handling_marks",touch)
	result.set_meta(&"surface_category",profile)
	result.set_meta(&"reference_method","Metro_Level finish-specific roughness and sourced PBR maps")
	finishes[profile]=result
	return result

static func assign(mesh: MeshInstance3D, profile: String, records: Array) -> void:
	records.append({"node":mesh,"previous":mesh.material_override,"profile":profile})
	mesh.material_override=material(profile)
	var bounds:=mesh.get_aabb()
	mesh.set_instance_shader_parameter(&"wear_bounds_center",bounds.get_center())
	mesh.set_instance_shader_parameter(&"wear_bounds_half",bounds.size*.5)

static func apply(room: Node) -> Array:
	var records: Array=[]
	for mesh in room.reception_desk.get_node("Structure").get_children():
		if not mesh is MeshInstance3D:continue
		if mesh.has_meta(&"ring_counter_segment"):assign(mesh,"counter_wood",records)
		elif String(mesh.name).begins_with("TopCap"):assign(mesh,"counter_top",records)
		elif String(mesh.name).begins_with("RecessedKick"):assign(mesh,"coated_kick",records)
	for name in ["WaitingTable","EastWaitingTable"]:
		var table: Node=room.props_root.get_node(name)
		for mesh in table.find_children("*","MeshInstance3D",true,false):assign(mesh,"table_wood" if mesh.name==&"StoneTableCap" else "table_frame",records)
	for name in ["WaitingBench","EastWaitingBench"]:
		var sofa:MeshInstance3D=room.props_root.get_node(String(name)+"/AuthoredSurfaceMesh")
		records.append({"node":sofa,"previous":sofa.material_override,"profile":"upholstery"})
		sofa.material_override=upholstery()
	for index in 4:
		var gate:Node=room.props_root.get_node("AccessGate%d"%index)
		assign(gate.get_node("BrushedGateBody"),"gate_steel",records)
		assign(gate.get_node("GatePlinth"),"gate_kick",records)
		assign(gate.get_node("DarkReader"),"gate_reader",records)
	for name in ["DeskLampBase","DeskLampStem"]:assign(room.props_root.get_node(name),"satin_steel",records)
	for index in 2:
		var stand: Node=room.props_root.get_node("LobbyInformationStand%d"%index)
		for name in ["SolidFrame","StandFoot"]:assign(stand.get_node(name),"coated_frame",records)
	return records
