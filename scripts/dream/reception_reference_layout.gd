extends "res://scripts/dream/reception_lobby_art.gd"
const FURNITURE_FINISH=preload("res://scripts/dream/reception_furniture_materials.gd")
const STONE_EDGES=preload("res://scripts/dream/reception_stone_edges.gd")
const COUNTER_TOP_HEIGHT := .78
const COUNTER_DROP := 1.10-COUNTER_TOP_HEIGHT
const CUTAWAY_EDGE_HEIGHT := .18
## The supplied atrium layout: foreground service desk, broad stairs,
## raised access gates, six side lifts and a closed ring service counter.

func build(target: Node3D) -> void:
	room=target
	_lower_cutaway_edges()
	_style_counter();_carpets();_waiting_bays();_reference_structure();_access_gates();_information_stands();_tarot_alcove()
	FURNITURE_FINISH.apply(room)
	for wall in room.wall_root.get_children():
		wall.wall_mesh.set_instance_shader_parameter(&"surface_floor_y",wall.position.y)
	for mesh in room.props_root.find_children("*","MeshInstance3D",true,false):
		mesh.layers|=LOBBY_FURNITURE_SHADOW_LAYER
		if mesh.material_override is ShaderMaterial and mesh.material_override.shader==SURFACE:
			var point:Vector2=Vector2(mesh.global_position.x,mesh.global_position.z)
			mesh.set_instance_shader_parameter(&"surface_floor_y",room.get_lobby_floor_height(point))

func _lower_cutaway_edges() -> void:
	# Keep the full wall and shadow caster. Only its camera-facing section is
	# lowered: the shared 30% cutoff leaves a 1.5m blocker in this 5m-high lobby.
	var profiles:Dictionary={}
	for wall in room.wall_root.get_children():
		if not wall.cutaway_mode:continue
		var source:Mesh=wall.wall_mesh.mesh
		if not profiles.has(source):
			var cut:=ArrayMesh.new()
			var scale_y:=CUTAWAY_EDGE_HEIGHT/source.get_aabb().size.y
			for surface in source.get_surface_count():
				var arrays:=source.surface_get_arrays(surface)
				var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for i in points.size():points[i].y*=scale_y
				arrays[Mesh.ARRAY_VERTEX]=points
				cut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			profiles[source]=cut
		wall.set_office_cutaway_profile(wall.shadow_mesh.mesh,profiles[source],section_material)

func build_floor_foundation(target: Node3D) -> void:
	room=target
	box(room.floor_root,"LobbyFoundation",Vector3(24,.28,10),Vector3(11.5,-.15,15.5),section_material)
	box(room.floor_root,"ConcourseFoundation",Vector3(13,.28,11),Vector3(12,-.15,5),section_material)
	box(room.floor_root,"RaisedConcourse",Vector3(13,.6,11),Vector3(12,.3,5),floor_material)
	for step in room.STAIR_COUNT:
		var height: float=room.CONCOURSE_HEIGHT-float(step)*.1
		var depth: float=(room.STAIR_BOTTOM_Z-room.STAIR_TOP_Z)/room.STAIR_COUNT
		var z: float=room.STAIR_TOP_Z+(float(step)+.5)*depth
		box(room.floor_root,"BroadStair%02d"%step,Vector3(13,height,depth),Vector3(12,height*.5,z),floor_material)
		box(room.floor_root,"StairNosing%02d"%step,Vector3(13,.025,.025),Vector3(12,height-.013,z+depth*.5-.015),section_material,false)

func _style_counter() -> void:
	# Four independent solids surround a genuinely open staff well. The old
	# solid desk/proxy is not instantiated or hidden beneath this counter.
	var structure:=Node3D.new();structure.name="Structure";room.reception_desk.add_child(structure)
	for segment in [["Front",Vector2(0,0),Vector2(7.2,.7)],["Back",Vector2(0,-2.9),Vector2(7.2,.7)],["West",Vector2(-3.25,-1.45),Vector2(.7,2.2)],["East",Vector2(3.25,-1.45),Vector2(.7,2.2)]]:
		var centre: Vector2=segment[1];var size: Vector2=segment[2]
		var body_height:=COUNTER_TOP_HEIGHT-.17
		var body:=box(structure,"Counter"+String(segment[0]),Vector3(size.x,body_height,size.y),Vector3(centre.x,.10+body_height*.5,centre.y),wall_material)
		body.set_meta(&"ring_counter_segment",true)
		var cap:=box(structure,"TopCapCounter" if segment[0]=="Front" else "TopCap"+String(segment[0]),Vector3(size.x+.035,.16,size.y+.035),Vector3(centre.x,COUNTER_TOP_HEIGHT-.08,centre.y),counter_material)
		cap.mesh=STONE_EDGES.slab(Vector3(size.x+.035,.16,size.y+.035))
		box(structure,"RecessedKick"+String(segment[0]),Vector3(size.x-.10,.12,size.y-.10),Vector3(centre.x,.06,centre.y),dark)
		var bronze:=FURNITURE_FINISH.material("satin_steel").duplicate() as ShaderMaterial
		bronze.set_shader_parameter("finish_colour",Color("a88d5d"));bronze.set_shader_parameter("roughness_range",Vector2(.38,.62))
		box(structure,"CounterMetalReveal"+String(segment[0]),Vector3(size.x+.02,.06,size.y+.02),Vector3(centre.x,.59,centre.y),bronze)
		room._spawn_wall_collision((Vector2(7.2,17.8)+centre)*32,size*32,"RingCounter"+String(segment[0])+"Collider")

func _carpets() -> void:
	_carpet("ArrivalRunner",PackedVector2Array([Vector2(15,14),Vector2(22.4,14),Vector2(22.4,20.4),Vector2(15,20.4)]),Color("c7b6b8"))
	var west: float=room.CONCOURSE_WEST_X+.05
	var east: float=room.CONCOURSE_EAST_X-.05
	_carpet("LiftHallCarpet",PackedVector2Array([Vector2(west,-.45),Vector2(east,-.45),Vector2(east,room.STAIR_TOP_Z-.02),Vector2(west,room.STAIR_TOP_Z-.02)]),Color("c7b6b8"))

func _tarot_alcove() -> void:
	super._tarot_alcove()
	room.props_root.get_node("TarotDeskMat").free()
	for item in room.props_root.get_children():
		if String(item.name).begins_with("DeskLamp"):
			item.position.y-=COUNTER_DROP

func _card(_index: int, _point: Vector3) -> void:
	# The lobby no longer builds the decorative tabletop cards.
	pass

func _carpet_point(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x,height+room.get_lobby_floor_height(point),point.y)

func _carpet(node_name: String, outline: PackedVector2Array, colour: Color) -> void:
	super._carpet(node_name,outline,colour)
	var visual:MeshInstance3D=room.props_root.get_node(NodePath(node_name))
	visual.set_meta(&"walkable_surface_outline",outline)
	visual.set_meta(&"walkable_surface_lift",.034)

func _waiting_bays() -> void:
	for index in 2:
		var x:=2.4 if index==0 else 21.0
		var sofa:=prop("sofa",Vector2(x,12.0),0,Vector2(2.1,.85),"WaitingBench" if index==0 else "EastWaitingBench")
		var display: MeshInstance3D=sofa.get_node("AuthoredSurfaceMesh")
		var upholstery:=furniture_material.duplicate() as StandardMaterial3D
		upholstery.albedo_color=Color("666e69");display.material_override=upholstery
		box(sofa,"SolidBenchPlinth",Vector3(2.14,.18,.84),Vector3(0,.16,0),dark)
		var table:=prop("coffee_table",Vector2(x,13.1),0,Vector2(1.3,.75),"WaitingTable" if index==0 else "EastWaitingTable")
		for mesh in table.find_children("*","MeshInstance3D",true,false):mesh.material_override=dark
		box(table,"StoneTableCap",Vector3(1.36,.06,.78),Vector3(0,.45,0),counter_material)
		var plant:=prop("plant",Vector2(6.4 if index==0 else 17.8,9.6),0,Vector2(.7,.7),"Planter%d"%index)
		plant.position.y=.6
		box(plant,"SquareStonePlanter",Vector3(.66,.5,.66),Vector3(0,.25,0),wall_material)

func _reference_structure() -> void:
	box(room.props_root,"NorthStructuralBeam",Vector3(13,.42,.88),Vector3(12,5.59,-.12),section_material)
	# The raised rear balcony and parapet reproduce the reference's rear mass.
	box(room.props_root,"RearMezzanineSlab",Vector3(13,.30,1.8),Vector3(12,3.35,.25),section_material)
	box(room.props_root,"RearStoneParapet",Vector3(13,.92,.23),Vector3(12,3.96,1.12),wall_material)
	box(room.props_root,"RearParapetWoodCap",Vector3(13.1,.07,.29),Vector3(12,4.455,1.12),wood_material,false)
	box(room.props_root,"RearWoodFascia",Vector3(13,.36,.12),Vector3(12,3.12,1.10),wood_material)
	for x in [room.CONCOURSE_WEST_X,room.CONCOURSE_EAST_X]:
		for z in [-.10,10.5]:
			var pier:=box(room.props_root,"AtriumStonePier",Vector3(.90,5.2,.90),Vector3(x,3.2,z),wall_material)
			pier.set_meta(&"reference_stone_pier",true)
			if z>0:box(room.props_root,"PierPedestal",Vector3(.98,.6,.98),Vector3(x,.3,z),wall_material)
			box(room.props_root,"PierStoneCap",Vector3(.96,.09,.96),Vector3(x,5.845,z),section_material,false)
			for y in [1.9,3.4,4.9]:box(room.props_root,"PierJoint",Vector3(.91,.012,.012),Vector3(x,y,z+.456),section_material,false)
			room._spawn_wall_collision(Vector2(x,z)*32,Vector2(.9,.9)*32,"AtriumPierCollider")
		box(room.props_root,"SideAtriumBeam",Vector3(.78,.52,10.9),Vector3(x,5.54,5),wood_material)
	# The near roof section is cut away for the game's overhead Camera, so the
	# actual rear access gates remain readable beneath this structural span.
	box(room.props_root,"CutawayFrontAtriumBeam",Vector3(13.7,.52,.74),Vector3(12,5.54,10.5),wood_material).hide()
	for panel in 17:
		box(room.props_root,"UpperNorthWalnutPanel",Vector3(.735,2.0,.16),Vector3(5.92+panel*.755,4.65,-.25),wood_material)
	for bank in 2:
		var side: float=room.CONCOURSE_WEST_X+.18 if bank==0 else room.CONCOURSE_EAST_X-.18
		box(room.props_root,"SideUpperWalnut",Vector3(.16,1.8,11),Vector3(side,4.7,5),wood_material)
		box(room.props_root,"SideStoneSoffit",Vector3(.55,.16,11),Vector3(side,3.74,5),section_material)
		for joint in 14:box(room.props_root,"WalnutVerticalJoint",Vector3(.02,1.8,.018),Vector3(side+(.09 if bank==0 else -.09),4.7,-.2+joint*.755),dark,false)
		for end_z in [-.3,10.3]:box(room.props_root,"LiftBankEndReturn",Vector3(.32,3.2,.4),Vector3(room.CONCOURSE_WEST_X if bank==0 else room.CONCOURSE_EAST_X,2.2,end_z),wall_material)
	for x in [room.CONCOURSE_WEST_X+.2,room.CONCOURSE_EAST_X-.2]:_stair_rail(x)

func _stair_rail(x: float) -> void:
	for z in [10.65,11.65,12.65]:
		var floor_y: float=room.get_lobby_floor_height(Vector2(x,z))
		box(room.props_root,"StairRailPost",Vector3(.065,1.0,.065),Vector3(x,floor_y+.5,z),dark)
	var a:=Vector3(x,1.64,10.55);var b:=Vector3(x,1.04,12.92)
	var rail:=box(room.props_root,"StairHandrail",Vector3(.09,.075,a.distance_to(b)),(a+b)*.5,dark)
	rail.look_at(b,Vector3.UP)
	room._spawn_wall_collision(Vector2(x,11.75)*32,Vector2(.12,2.4)*32,"StairRailCollider")

func _access_gates() -> void:
	var steel:=metal(Color("aab4b3"),.3);steel.metallic=.72
	var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.33,.47,.46,.26)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=.25;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var ready:=textile(Color("69c6a2"));ready.emission_enabled=true;ready.emission=Color("69c6a2");ready.emission_energy_multiplier=1.0
	for index in 4:
		var x:=8.55+index*2.3
		var gate:=Node3D.new();gate.name="AccessGate%d"%index;gate.position=Vector3(x,.6,room.STAIR_TOP_Z-.8)
		gate.set_meta(&"reference_access_gate",true);room.props_root.add_child(gate)
		box(gate,"GatePlinth",Vector3(.48,.12,1.55),Vector3(0,.06,0),dark)
		box(gate,"BrushedGateBody",Vector3(.36,1.05,1.4),Vector3(0,.645,0),steel)
		box(gate,"DarkReader",Vector3(.39,.06,.45),Vector3(0,1.20,.32),dark)
		box(gate,"ReadyStrip",Vector3(.25,.02,.06),Vector3(0,1.24,.48),ready,false)
		# Wings are visibly retracted along the bodies; the three lanes stay open.
		box(gate,"RetractedGlassWing",Vector3(.035,.68,.88),Vector3(.25,.81,-.10),glass,false)
		room._spawn_wall_collision(Vector2(x,gate.position.z)*32,Vector2(.48,1.55)*32,"AccessGateCollider")

func _information_stands() -> void:
	var paper:=textile(Color("bfc0ae"));var ink:=textile(Color("4c5b60"));var red:=textile(Color("603738"))
	for index in 2:
		var root:=Node3D.new();root.name="LobbyInformationStand%d"%index;root.position=Vector3(11.4+index*.66,0,17.5);room.props_root.add_child(root)
		box(root,"StandFoot",Vector3(.5,.06,.42),Vector3(0,.03,0),dark)
		box(root,"SolidFrame",Vector3(.44,1.7,.11),Vector3(0,.91,0),trim)
		box(root,"PrintedPaper",Vector3(.38,1.53,.018),Vector3(0,.92,.065),paper,false)
		box(root,"PrintHeader",Vector3(.32,.20,.008),Vector3(0,1.51,.079),red,false)
		for line in 5:box(root,"PrintedLine",Vector3(.29,.04,.008),Vector3(0,1.24-line*.19,.079),ink,false)
		room._spawn_wall_collision(Vector2(root.position.x,root.position.z)*32,Vector2(.5,.42)*32,"InformationStandCollider")

func build_lighting(target: Node3D) -> void:
	room=target
	_linear_fixture("UpperHallSoffit",Vector3(13.0,3.0,1.3),0,8.6,2.4)
	_linear_fixture("WestGallerySoffit",Vector3(room.CONCOURSE_WEST_X+.35,3.7,5),PI*.5,9.5,2.6)
	_linear_fixture("EastGallerySoffit",Vector3(room.CONCOURSE_EAST_X-.35,3.7,5),-PI*.5,9.5,2.6)
	_linear_fixture("AtriumBeamSoffit",Vector3(12.1,5.235,10.46),0,12.0,1.1)
	for hardware in room.lighting_root.get_node("AtriumBeamSoffit").find_children("*","MeshInstance3D",true,false):hardware.hide()
	for fixture in fixtures:fixture.get_node("Pool").omni_range=9.0
	_reference_ceiling_grid()
	for entry in [["LobbyCeilingWest",Vector3(6,5.7,17.0)],["LobbyCeilingEast",Vector3(18,5.7,17.0)],["RearCeilingWest",Vector3(7.5,5.7,7.0)],["RearCeilingEast",Vector3(17,5.7,7.0)]]:
		_ceiling_fixture(entry[0],entry[1])
		var light: SpotLight3D=room.lighting_root.get_node(String(entry[0])+"/SoftCeilingWash")
		light.light_energy=2.8 if entry[0]=="LobbyCeilingWest" else 2.1;light.spot_range=16.0;light.light_specular=.28
		light.light_color=Color("ead9be") if entry[0]=="LobbyCeilingWest" else Color("ccd5d7")
		# A 156-degree shadow frustum caused horizontal self-shadow bands on the
		# tall stone piers. Four narrower lights retain real cast shadows.
		light.spot_angle=55.0
		# Closed furniture casts from its back faces. Front-face shadow depth
		# incorrectly self-occluded the low stone cap, producing a large disc.
		light.shadow_reverse_cull_face=true
		light.shadow_bias=.5;light.shadow_normal_bias=1.2
	var fill:=OmniLight3D.new();fill.name="LobbyCeilingBounce";fill.position=Vector3(12,6.3,16)
	fill.light_color=Color("e3e2da");fill.light_energy=.95;fill.omni_range=29;fill.omni_attenuation=1.4;fill.light_specular=.22;fill.light_cull_mask=15
	room.lighting_root.add_child(fill)
	var task:=OmniLight3D.new();task.name="ReceptionDeskTaskLight";task.position=room.RECEPTION_DESK_POS_3D+Vector3(-1.15,1.39-COUNTER_DROP,.66)
	task.light_color=Color("dfcfb1");task.light_energy=1.05;task.omni_range=3.6;task.light_cull_mask=15
	room.lighting_root.add_child(task)
	for x in [2.4,21.0]:_lounge_wall_wash(x)

func _lounge_wall_wash(x:float) -> void:
	var fixture:=Node3D.new();fixture.name="LoungeWallWash";fixture.position=Vector3(x,1.75,10.73);room.lighting_root.add_child(fixture)
	box(fixture,"BronzeHousing",Vector3(.84,.11,.11),Vector3.ZERO,trim,false)
	var glass:=textile(Color("d5bd91"));glass.emission_enabled=true;glass.emission=Color("e5d0a4");glass.emission_energy_multiplier=.6
	box(fixture,"RecessedGlass",Vector3(.72,.035,.02),Vector3(0,-.03,.065),glass,false)
	var light:=OmniLight3D.new();light.name="WallAndSeatWash";light.position=Vector3(0,.10,.36)
	light.light_color=Color("e5d4b9");light.light_energy=1.8;light.omni_range=4.8;light.omni_attenuation=1.15;light.light_specular=.15;light.light_cull_mask=15
	fixture.add_child(light)

func _reference_ceiling_grid() -> void:
	var root:=Node3D.new();root.name="ReferenceCeilingGrid";room.lighting_root.add_child(root)
	box(root,"ConnectedRoofFrame",Vector3(13,.12,2.2),Vector3(12,5.78,.6),dark,false)
	var opal:=textile(Color("e4e1d5"));opal.emission_enabled=true;opal.emission=Color("e4e1d5");opal.emission_energy_multiplier=.85;opal.cull_mode=BaseMaterial3D.CULL_DISABLED
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 3:
		for column in 12:
			var x:=6.17+column*1.06;var z:=-.05+row*.60
			_carpet_triangle(builder,[Vector3(x-.44,5.846,z-.22),Vector3(x+.44,5.846,z-.22),Vector3(x-.44,5.846,z+.22)],[1.,1.,1.])
			_carpet_triangle(builder,[Vector3(x+.44,5.846,z+.22),Vector3(x+.44,5.846,z-.12),Vector3(x-.28,5.846,z+.22)],[1.,1.,1.])
	var panels:=MeshInstance3D.new();panels.name="TriangularOpalPanels";panels.mesh=builder.commit();panels.material_override=opal;panels.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(panels)
