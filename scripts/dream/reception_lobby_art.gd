extends RefCounted
## Reception-owned lobby finishes. The room still owns routes and interactions.
const ART=preload("res://scripts/dream/office_room_low_pixel_art.gd")
const SURFACE=preload("res://shaders/dream3d/reception_lobby_surface.gdshader")
const CARPET=preload("res://shaders/dream3d/reception_lobby_carpet.gdshader")
const PILE_DIFFUSE=preload("res://art/Dream/ReceptionLobby/keith333_red_carpet/RedCarpet_S.jpg")
const PILE_NORMAL=preload("res://art/Dream/ReceptionLobby/keith333_red_carpet/RedCarpet_N.jpg")
const STONE_FLOOR_ALBEDO=preload("res://art/Dream/ReceptionLobby/GreyMatteTiles01/albedo.png")
const STONE_FLOOR_NORMAL=preload("res://art/Dream/ReceptionLobby/GreyMatteTiles01/normal.png")
const STONE_FLOOR_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/GreyMatteTiles01/roughness.png")
const STONE_WALL_ALBEDO=preload("res://art/Dream/ReceptionLobby/NaturalStone01/albedo.png")
const STONE_WALL_NORMAL=preload("res://art/Dream/ReceptionLobby/NaturalStone01/normal.png")
const STONE_WALL_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/NaturalStone01/roughness.png")
const WALNUT_ALBEDO=preload("res://art/Dream/ReceptionLobby/walnut_veneer/albedo.jpg")
const WALNUT_NORMAL=preload("res://art/Dream/ReceptionLobby/walnut_veneer/normal.jpg")
const WALNUT_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/walnut_veneer/roughness.jpg")
const LOBBY_FURNITURE_SHADOW_LAYER:=1<<17
var room: Node3D
var floor_material: ShaderMaterial=stone(Color("a3aaa8"),0)
var wall_material: ShaderMaterial=stone(Color("9da8a3"),1)
var wood_material: ShaderMaterial=stone(Color("a27b64"),2)
var counter_material: ShaderMaterial=stone(Color("afb8b3"),0)
var section_material: ShaderMaterial=stone(Color("888f8a"),1)
var trim: StandardMaterial3D=metal(Color("505957"),.68)
var dark: StandardMaterial3D=metal(Color("252a2d"),.70)
var furniture_material: StandardMaterial3D=authored_furniture()
var fixtures: Array[Node3D]=[]

static func stone(colour: Color, kind: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=SURFACE
	material.set_shader_parameter("surface_colour",colour)
	material.set_shader_parameter("surface_kind",kind)
	material.set_shader_parameter("surface_albedo",WALNUT_ALBEDO if kind==2 else STONE_FLOOR_ALBEDO if kind==0 else STONE_WALL_ALBEDO)
	material.set_shader_parameter("surface_normal",WALNUT_NORMAL if kind==2 else STONE_FLOOR_NORMAL if kind==0 else STONE_WALL_NORMAL)
	material.set_shader_parameter("surface_roughness",WALNUT_ROUGHNESS if kind==2 else STONE_FLOOR_ROUGHNESS if kind==0 else STONE_WALL_ROUGHNESS)
	material.set_shader_parameter("tile_metres",Vector2(1.8,1.8) if kind==2 else Vector2(4.0,10.0) if kind==0 else Vector2(2.4,2.4))
	return material

static func metal(colour: Color, roughness: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=colour
	material.roughness=roughness;material.metallic=.22;material.metallic_specular=.3
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

static func authored_furniture() -> StandardMaterial3D:
	# Preserve the authored atlas/UVs; use native lighting without the old
	# light_noise_contour function. Never change the shared material or globals.
	var material:=StandardMaterial3D.new();material.albedo_texture=ART.texture()
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness=1.0;material.metallic_specular=0.0
	return material

static func textile(colour: Color) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=colour
	material.roughness=1.0;material.metallic_specular=0.0
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

static func wool(colour: Color) -> ShaderMaterial:
	# Use the author's complete photographic carpet and matching normal map.
	# No histogram reconstruction, mirrored crop or synthetic nap field.
	var material:=ShaderMaterial.new();material.shader=CARPET
	material.set_shader_parameter("fabric_colour",colour)
	material.set_shader_parameter("carpet_albedo",PILE_DIFFUSE)
	material.set_shader_parameter("pile_normal",PILE_NORMAL)
	material.set_meta(&"source_author","Keith333")
	material.set_meta(&"source_url","https://opengameart.org/content/carpet-texture-red-seamless-texture-with-normalmap")
	material.set_meta(&"source_license","CC-BY-3.0")
	return material

func build(target: Node3D) -> void:
	room=target
	_style_counter();_carpets();_lounge();_staff_storage();_plants();_architecture();_tarot_alcove()
	# Ceiling lights add solid furniture shadows. Wall shadows remain owned by
	# the integrated linear fixtures, avoiding grazing ceiling self-shadows.
	for object_name in ["ReceptionDesk3D","WaitingBench","WaitingTable","Planter0","Planter1"]:
		var object: Node3D=room.props_root.get_node(object_name)
		for mesh in object.find_children("*","MeshInstance3D",true,false):
			mesh.layers|=LOBBY_FURNITURE_SHADOW_LAYER

func build_floor_foundation(target: Node3D) -> void:
	box(target.floor_root,"LobbyFoundation",Vector3(14,.28,8),Vector3(6.5,-.15,3.5),section_material)
	box(target.floor_root,"VestibuleFoundation",Vector3(3,.28,3),Vector3(15,-.15,4),section_material)

func box(parent: Node3D, title: String, size: Vector3, point: Vector3, material: Material, shadow: bool=true) -> MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=title
	var shape:=BoxMesh.new();shape.size=size;visual.mesh=shape
	visual.position=point;visual.material_override=material;parent.add_child(visual)
	if not shadow:visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual

func prop(kind: String, point: Vector2, yaw: float, footprint: Vector2, label: String) -> Node3D:
	var item: Node3D=ART.make_visual(kind)
	item.name=label;item.position=Vector3(point.x,0,point.y);item.rotation.y=yaw
	item.set_meta(&"lobby_kind",kind);room.props_root.add_child(item)
	for mesh in item.find_children("*","MeshInstance3D",true,false):mesh.material_override=furniture_material
	var size:=Vector2(footprint.y,footprint.x) if absf(sin(yaw))>.5 else footprint
	room._spawn_wall_collision(point*32.0,size*32.0,label+"Collider")
	return item

func _style_counter() -> void:
	for item in room.reception_desk.find_children("*","MeshInstance3D",true,false):
		var old: ShaderMaterial=item.material_override as ShaderMaterial
		if old!=null and old.shader.resource_path=="res://shaders/dream3d/office_pixel_surface.gdshader":
			var finish:=StandardMaterial3D.new()
			finish.albedo_color=old.get_shader_parameter("base_color")
			finish.albedo_texture=old.get_shader_parameter("pixel_texture")
			finish.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			finish.roughness=.9;finish.metallic_specular=.08
			if bool(old.get_shader_parameter("glow")):
				finish.emission_enabled=true;finish.emission=finish.albedo_color
				finish.emission_energy_multiplier=.6
			item.material_override=finish
		match String(item.name):
			"TopCapCounter","WestUpperCap","EastUpperCap":
				item.material_override=counter_material
				if item.name=="TopCapCounter":
					var slab:=BoxMesh.new();slab.size=Vector3(3.8,.16,.82)
					item.mesh=slab;item.position.y=1.02
			"FrontModestyPanel","WestEndCap","EastEndCap","WestPedestal","KneewellBackboard":item.material_override=wall_material
			"BasePlinth":item.material_override=dark
			"StandFoot","StandStem","StandHinge","StandLogo","ClipboardClip","PenStand":item.material_override=trim
	box(room.reception_desk,"BrassReveal",Vector3(3.32,.025,.018),Vector3(0,.15,.565),trim,false)
	box(room.reception_desk,"StoneSockle",Vector3(3.64,.18,1.13),Vector3(0,.09,0),section_material)
	box(room.reception_desk,"CounterStoneReturn",Vector3(.24,1.10,1.4),Vector3(-1.82,.55,.15),wall_material)
	room._spawn_wall_collision(Vector2(room.RECEPTION_DESK_POS_3D.x-1.82,room.RECEPTION_DESK_POS_3D.z+.15)*32,Vector2(.24,1.4)*32,"CounterStoneReturnCollider")

func _carpets() -> void:
	# Broad red runners leave the monolithic counter seated on open stone.
	_carpet("ArrivalRunner",PackedVector2Array([
		Vector2(.6,-.5),Vector2(2.4,-.5),Vector2(2.4,3.7),Vector2(16.3,3.7),
		Vector2(16.3,5.4),Vector2(.6,5.4)]),Color("c7b6b8"))
	_carpet("WaitingRug",PackedVector2Array([
		Vector2(8.8,5.65),Vector2(12.6,5.65),Vector2(12.6,7.35),Vector2(8.8,7.35)]),Color("c7b6b8"))

func _carpet(title: String, outline: PackedVector2Array, colour: Color) -> void:
	var visual:=MeshInstance3D.new();visual.name=title
	var inner:=PackedVector2Array()
	for index in outline.size():
		# The authored footprint is rectilinear; this is the exact inset miter.
		var incoming: Vector2=(outline[index]-outline[(index-1+outline.size())%outline.size()]).normalized()
		var outgoing: Vector2=(outline[(index+1)%outline.size()]-outline[index]).normalized()
		inner.append(outline[index]+Vector2(-incoming.y-outgoing.y,incoming.x+outgoing.x)*.04)
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices:=Geometry2D.triangulate_polygon(inner)
	for index in range(0,indices.size(),3):
		var a:=_carpet_point(inner[indices[index]],.034)
		var b:=_carpet_point(inner[indices[index+1]],.034)
		var c:=_carpet_point(inner[indices[index+2]],.034)
		_carpet_triangle(builder,[a,b,c],[1.0,1.0,1.0])
	var bottom_indices:=Geometry2D.triangulate_polygon(outline)
	for index in range(0,bottom_indices.size(),3):
		_carpet_triangle(builder,[
			_carpet_point(outline[bottom_indices[index+2]],.002),
			_carpet_point(outline[bottom_indices[index+1]],.002),
			_carpet_point(outline[bottom_indices[index]],.002)],[.4,.4,.4])
	for index in outline.size():
		var next: int=(index+1)%outline.size()
		var a:=_carpet_point(outline[index],.022);var b:=_carpet_point(outline[next],.022)
		var c:=_carpet_point(inner[next],.034);var d:=_carpet_point(inner[index],.034)
		_carpet_triangle(builder,[a,b,c],[.68,.68,.96])
		_carpet_triangle(builder,[a,c,d],[.68,.96,.96])
		var bottom_a:=_carpet_point(outline[index],.002);var bottom_b:=_carpet_point(outline[next],.002)
		_carpet_triangle(builder,[bottom_a,bottom_b,b],[.38,.38,.50])
		_carpet_triangle(builder,[bottom_a,b,a],[.38,.50,.50])
	builder.generate_tangents();visual.mesh=builder.commit()
	visual.material_override=wool(colour)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;room.props_root.add_child(visual)

func _carpet_point(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x,height,point.y)

func _carpet_triangle(builder: SurfaceTool, points: Array, tones: Array) -> void:
	var normal: Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
	for index in 3:
		builder.set_normal(normal);builder.set_uv(Vector2(points[index].x,points[index].z))
		builder.set_color(Color(tones[index],tones[index],tones[index],1.0))
		builder.add_vertex(points[index])

func _lounge() -> void:
	var sofa:=prop("sofa",Vector2(10.7,6.8),PI,Vector2(2.1,.85),"WaitingBench")
	# Thicker cushions and a real plinth, keeping the approved footprint/UVs.
	var display: MeshInstance3D=sofa.get_node("AuthoredSurfaceMesh")
	var arrays:=display.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		var v:=vertices[index]
		if absf(v.y-.5125)<.0001:v.y=.50
		elif absf(v.y-.5675)<.0001:v.y=.65
		elif absf(v.y-.86)<.0001:v.y=1.02
		elif absf(v.y-.665)<.0001:v.y=.80
		vertices[index]=v
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var thickened:=ArrayMesh.new();thickened.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	display.mesh=thickened
	var upholstery:=furniture_material.duplicate() as StandardMaterial3D
	upholstery.albedo_color=Color("7d8480");display.material_override=upholstery
	box(sofa,"BenchPlinth",Vector3(2.14,.12,.84),Vector3(0,.16,0),wood_material)
	var table:=prop("coffee_table",Vector2(10.7,5.9),0,Vector2(1.3,.75),"WaitingTable")
	for mesh in table.find_children("*","MeshInstance3D",true,false):mesh.material_override=dark
	box(room.props_root,"WaitingTableBook",Vector3(.28,.035,.23),Vector3(10.5,.455,5.9),counter_material,false)

func _staff_storage() -> void:
	# Flush storage replaces the extra office workstation and loose chair.
	var storage:=Node3D.new();storage.name="StaffStorage";room.props_root.add_child(storage)
	storage.position=Vector3(12,0,.12)
	box(storage,"CabinetBody",Vector3(1.4,1.12,.34),Vector3(0,.56,-.1),wall_material)
	box(storage,"StoneTop",Vector3(1.43,.07,.38),Vector3(0,1.155,-.1),counter_material)
	for side in [-1.0,1.0]:
		box(storage,"Door",Vector3(.665,.91,.035),Vector3(side*.347,.59,.09),wall_material)
		box(storage,"Handle",Vector3(.025,.18,.03),Vector3(side*.11,.72,.12),trim,false)
	room._spawn_wall_collision(Vector2(12,.12)*32,Vector2(1.43,.66)*32,"StaffStorageCollider")

func _plants() -> void:
	for index in 2:
		var point:=Vector2(.6,6.7) if index==0 else Vector2(12.9,6.7)
		var plant:=prop("plant",point,0,Vector2(.72,.72),"Planter%d"%index)
		plant.set_meta(&"lobby_kind","plant")
		box(plant,"StonePlanterSleeve",Vector3(.72,.38,.72),Vector3(0,.19,0),wall_material)
		box(plant,"PlanterRim",Vector3(.75,.035,.75),Vector3(0,.4,0),trim,false)

func _architecture() -> void:
	box(room.props_root,"UpperStoneBeam",Vector3(14,.38,.76),Vector3(6.5,3.16,-.16),section_material)
	box(room.props_root,"MezzanineFascia",Vector3(10.2,.28,.46),Vector3(8.25,1.68,-.12),section_material)
	for index in 11:
		box(room.props_root,"UpperWalnutPanel%d"%index,Vector3(.735,1.26,.16),Vector3(4.65+index*.755,2.46,-.24),wood_material)
	box(room.props_root,"WestUpperWalnut",Vector3(.16,1.26,6.6),Vector3(-.32,2.46,3),wood_material)
	for joint in 8:box(room.props_root,"WestVeneerJoint",Vector3(.012,1.26,.025),Vector3(-.232,2.46,.5+joint*.755),dark,false)
	box(room.props_root,"WestStoneSoffit",Vector3(.42,.28,6.6),Vector3(-.22,1.68,3),section_material)
	for z in [1.05,6.5]:box(room.props_root,"EastUpperWalnut",Vector3(.16,1.26,2.0),Vector3(13.30,2.46,z),wood_material)
	for x in [4.2,11.0,13.35]:
		box(room.props_root,"StonePier",Vector3(.72,3.36,.68),Vector3(x,1.68,-.10),wall_material)
		box(room.props_root,"PierStoneCap",Vector3(.76,.075,.72),Vector3(x,3.3975,-.10),section_material,false)
		for height in [1.1,2.2]:box(room.props_root,"PierJoint",Vector3(.72,.012,.012),Vector3(x,height,.245),section_material,false)
		room._spawn_wall_collision(Vector2(x,-.10)*32,Vector2(.72,.68)*32,"LobbyStonePierCollider")
	var title:=Label3D.new();title.name="ReceptionIdentity";title.text="R E C E P T I O N"
	title.font_size=32;title.pixel_size=.0075;title.position=Vector3(8,1.32,-.215)
	title.modulate=Color("c9c3b5");title.outline_size=0;title.shaded=true
	title.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;room.props_root.add_child(title)

func _tarot_alcove() -> void:
	var p: Vector3=room.RECEPTION_DESK_POS_3D
	box(room.props_root,"TarotDeskMat",Vector3(1.65,.012,.38),p+Vector3(0,1.108,.33),dark,false)
	for index in 3:_card(index,p+Vector3(-.44+index*.44,1.28,.31))
	box(room.props_root,"DeskLampBase",Vector3(.27,.035,.22),p+Vector3(-1.15,1.13,.23),trim)
	box(room.props_root,"DeskLampStem",Vector3(.035,.32,.035),p+Vector3(-1.15,1.30,.23),trim)
	box(room.props_root,"DeskLampShade",Vector3(.36,.14,.25),p+Vector3(-1.15,1.49,.23),dark)
	var diffuser:=metal(Color("d4bd91"),.65);diffuser.emission_enabled=true
	diffuser.emission=Color("d8bb82");diffuser.emission_energy_multiplier=.6
	box(room.props_root,"DeskLampDiffuser",Vector3(.27,.018,.19),p+Vector3(-1.15,1.412,.23),diffuser,false)

func _card(index: int, point: Vector3) -> void:
	var pixels:=Image.create(8,12,false,Image.FORMAT_RGB8);pixels.fill(Color("b9ad90"))
	for y in range(1,11):
		for x in range(1,7):
			var ink:=Color("283744")
			var mark: bool=(absi(x-3)+absi(y-5)<3) if index==0 else (x in [2,3] and y in range(3,8)) if index==1 else (y==5 or x==3) and y in range(3,8)
			if mark:ink=Color("c3a36b")
			pixels.set_pixel(x,y,ink)
	var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(pixels)
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;material.roughness=1.;material.metallic_specular=0
	var mesh:=MeshInstance3D.new();mesh.name="OriginalTarotCard%d"%index
	var quad:=QuadMesh.new();quad.size=Vector2(.25,.375);mesh.mesh=quad;mesh.material_override=material
	mesh.position=point;mesh.rotation_degrees.x=-28;room.props_root.add_child(mesh)

func build_lighting(target: Node3D) -> void:
	room=target
	_linear_fixture("LiftSoffit",Vector3(1.5,2.72,-.15),0,2.15,1.45)
	_linear_fixture("ReceptionSoffit",Vector3(8,1.65,-.015),0,4.8,1.25)
	_linear_fixture("ArrivalSoffit",Vector3(15.5,2.62,2.72),0,1.8,1.35)
	_linear_fixture("WaitingSoffit",Vector3(13.28,2.5,6.35),-PI*.5,1.5,1.0)
	_ceiling_grid()
	_ceiling_fixture("LobbyCeilingWest",Vector3(4.0,3.05,1.9))
	_ceiling_fixture("LobbyCeilingEast",Vector3(10.5,3.05,1.9))
	# Ceiling bounce belongs to the cut-away roof, above the visible wall caps.
	var fill:=OmniLight3D.new();fill.name="LobbyCeilingBounce"
	fill.position=Vector3(7.3,3.8,6.2);fill.light_color=Color("e3e2da")
	fill.light_energy=.85;fill.omni_range=18;fill.omni_attenuation=1.4
	fill.light_specular=.3;fill.light_cull_mask=15;fill.shadow_enabled=false
	room.lighting_root.add_child(fill)
	var task:=OmniLight3D.new();task.name="ReceptionDeskTaskLight"
	task.position=room.RECEPTION_DESK_POS_3D+Vector3(-1.15,1.39,.66)
	task.light_color=Color("dfcfb1");task.light_energy=1.05;task.omni_range=3.6
	task.omni_attenuation=1.4;task.light_cull_mask=15;task.light_specular=.6
	room.lighting_root.add_child(task)

func _linear_fixture(title: String, point: Vector3, yaw: float, width: float, energy: float) -> void:
	var fixture:=Node3D.new();fixture.name=title;fixture.position=point;fixture.rotation.y=yaw
	room.lighting_root.add_child(fixture);fixtures.append(fixture)
	fixture.set_meta(&"lobby_recessed_linear_light",true)
	box(fixture,"RecessedHousing",Vector3(width,.09,.16),Vector3.ZERO,dark,false)
	var glass:=textile(Color("e4e3db"));glass.emission_enabled=true
	glass.emission=Color("e6e3d9");glass.emission_energy_multiplier=1.2
	box(fixture,"LinearDiffuser",Vector3(width-.1,.035,.05),Vector3(0,-.04,.085),glass,false)
	var light:=OmniLight3D.new();light.name="Pool";light.position=Vector3(0,-.12,.25)
	light.light_color=Color("e6e3d9");light.light_energy=energy;light.omni_range=6.0;light.omni_attenuation=1.3
	light.light_specular=1;light.light_cull_mask=15;light.shadow_caster_mask=15
	# At 640x360 the stochastic soft-shadow taps made upholstery look speckled.
	# The broad ceiling wash softens contrast without noisy shadow penumbras.
	light.shadow_enabled=true;light.shadow_bias=.03;light.shadow_normal_bias=.32;light.shadow_blur=0.0
	fixture.add_child(light)

func _ceiling_grid() -> void:
	var grid:=Node3D.new();grid.name="ReferenceCeilingGrid";room.lighting_root.add_child(grid)
	box(grid,"ConnectedRoofFrame",Vector3(6.6,.1,1.25),Vector3(7.9,3.24,.42),dark,false)
	var opal:=textile(Color("e4e1d5"));opal.emission_enabled=true;opal.emission=Color("e4e1d5")
	opal.emission_energy_multiplier=.85;opal.cull_mode=BaseMaterial3D.CULL_DISABLED
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 2:
		for column in 10:
			var x:=5.2+column*.6;var z:=.15+row*.5
			_carpet_triangle(builder,[Vector3(x-.24,3.296,z-.18),Vector3(x+.24,3.296,z-.18),Vector3(x-.24,3.296,z+.18)],[1.,1.,1.])
			_carpet_triangle(builder,[Vector3(x+.24,3.296,z+.18),Vector3(x+.24,3.296,z-.11),Vector3(x-.17,3.296,z+.18)],[1.,1.,1.])
	var panels:=MeshInstance3D.new();panels.name="TriangularOpalPanels";panels.mesh=builder.commit();panels.material_override=opal
	panels.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;grid.add_child(panels)

func _ceiling_fixture(title: String, point: Vector3) -> void:
	var fixture:=Node3D.new();fixture.name=title;fixture.position=point
	room.lighting_root.add_child(fixture)
	fixture.set_meta(&"lobby_ceiling_diffuser",true)
	box(fixture,"CeilingRose",Vector3(.15,.05,.15),Vector3(0,.22,0),trim)
	box(fixture,"PendantStem",Vector3(.035,.20,.035),Vector3(0,.12,0),dark)
	box(fixture,"SolidBronzeHousing",Vector3(.92,.23,.66),Vector3.ZERO,trim)
	var glass:=textile(Color("f1e8d7"));glass.emission_enabled=true
	glass.emission=Color("fff0d9");glass.emission_energy_multiplier=.6
	box(fixture,"RecessedOpalPanel",Vector3(.78,.045,.52),Vector3(0,-.13,0),glass,false)
	var light:=SpotLight3D.new();light.name="SoftCeilingWash"
	light.position.y=-.13;light.rotation_degrees.x=-90
	light.light_color=Color("e6e3d9");light.light_energy=1.8 if title.ends_with("West") else 1.5;light.light_specular=.6
	light.spot_range=10.0;light.spot_angle=78.0
	light.spot_attenuation=.4;light.spot_angle_attenuation=.25
	light.light_cull_mask=15;light.shadow_caster_mask=LOBBY_FURNITURE_SHADOW_LAYER
	light.shadow_enabled=true;light.shadow_blur=0;light.shadow_bias=.10;light.shadow_normal_bias=.8
	fixture.add_child(light)
	# This Camera cuts the roof away. Its downlights remain active, while roof
	# hardware must not float over the floor or conceal a walking character.
	for housing in fixture.find_children("*","MeshInstance3D",true,false):housing.hide()

func _cylinder(parent: Node3D, title: String, radius: float, height: float, point: Vector3, material: Material) -> void:
	var mesh:=MeshInstance3D.new();mesh.name=title;mesh.position=point
	var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius
	shape.height=height;shape.radial_segments=8;shape.rings=1
	mesh.mesh=shape;mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
