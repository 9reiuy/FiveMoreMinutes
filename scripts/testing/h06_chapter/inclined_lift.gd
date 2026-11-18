extends Node3D
## Combat uses the level deck as its coordinate frame. The shaft sections move
## past that frame at the same grade as the physical guides.

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const M := preload("res://scripts/testing/maintenance_environment.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const WALKWAY := preload("res://scripts/testing/h06_chapter/lift_walkway_art.gd")
const DECK_SHADER := preload("res://scripts/testing/h06_chapter/inclined_lift_deck.gdshader")
const TRAVEL_STREAM := preload("res://sfx/h06/lift_motor.res")
const TRAVEL_DB := -12.0
const PLATFORM_PANEL := preload("res://art/Dream/CC0/QuaterniusSciFiStandard/Platform_Metal2.scn")
const CABLE_SPUR := "res://art/Dream/CC0/AtriumLoop11/quaternius/Prop_Cable_3.scn"
const CRUISE_SPEED := 3.35
const ARRIVAL_TIME := 3.1
const SHAFT_NORTH := PLAN.ARENA_DECK.position.y-28.2
const SHELL_BASE := -10.0
const SHELL_RIM := 42.0
const WALL_THICKNESS := .76
const WALL_CLEARANCE := 2.26
const LASER_WALL_LAYER := 1 << 10
const LASER_WALL_LIGHT_OFFSET := .64
const BAY_LENGTH := 6.4
const BAY_COUNT := 12
const WORK_BEAM_NEAR_Z := PLAN.ARENA_DECK.position.y+8.0
const WORK_LAMP_OFFSET := Vector3(.21,6.35,-1.48)
const SERVICE_LAMP_OFFSET := Vector3(-.21,3.45,1.31)
const WORK_BEAM_ENERGY := 17.2
const SERVICE_BEAM_ENERGY := 5.3
const GUIDE_GRADE := 6.0/10.4
const RAIL_HALF_GAUGE := 4.7
const FRONT_RAIL_LEVEL := -1.03
const RAIL_HEAD_WIDTH := .52
const RAIL_HEAD_TOP := .32
const SHUDDER_CYCLES := 3.25
enum Travel { DOCKED, ASCENDING, ARRIVING, UPPER }

var travel_age := 0.0
var travel := Travel.DOCKED
var distance := 0.0
var speed := 0.0
var arrival_speed := 0.0
var deck_vertical_offset := 0.0
var _shudder_amplitude := 0.0
var _shudder_duration := 0.0
var _shudder_elapsed := 0.0
var lower_landing: Node3D
var shaft_bays: Array[Node3D] = []
var _laser_deck: ShaderMaterial
var _laser_segments := PackedVector4Array()
var _laser_wall_lights: Array[OmniLight3D] = []
var work_beam: SpotLight3D
var service_beam: SpotLight3D
var work_origin: Vector3
var service_origin: Vector3
var is_docked: bool:
	get: return travel == Travel.DOCKED
var rim_material := M.metal(Color("30383f"), .81)
var guide_material := M.metal(Color("a7aca9"), .56)
var frame_material := M.metal(Color("21252b"), .89)
var handrail_material := M.metal(Color("cd693e"), .77)
var carriage_paint := M.metal(Color("b29845"),.81)
var service_pipe := M.metal(Color("5e6669"),.49)
var cable_rubber := M.metal(Color("373c3e"),.86)
var cable_jacket := M.metal(Color("ac673d"),.83)
var signal_material := M.metal(Color("ff8553"), .78)
var dock_light := M.metal(Color("eff4e4"), .78)
var deck_light := M.metal(Color("ffbd65"), .78)
var platform_mesh: Mesh
var panel_transform: Transform3D
var panel_bounds: AABB
var travel_audio: AudioStreamPlayer3D
var _sfx_manager: Node

func _ready() -> void:
	name = "InclinedCargoPlatform"
	_sfx_manager = get_tree().root.get_node_or_null("SFXManager")
	travel_audio = AudioStreamPlayer3D.new()
	travel_audio.name = "TravelMotor"
	travel_audio.stream = TRAVEL_STREAM
	travel_audio.bus = &"Environment"
	travel_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	travel_audio.max_polyphony = 1
	travel_audio.max_distance = 34.0
	travel_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	travel_audio.panning_strength = 0.55
	var center := PLAN.ARENA_DECK.get_center()
	travel_audio.position = Vector3(center.x, -0.4, center.y)
	add_child(travel_audio)
	visibility_changed.connect(_stop_audio_when_hidden)

func build(art: RefCounted) -> void:
	signal_material.emission_enabled = true
	signal_material.emission = Color("ef552c")
	signal_material.emission_energy_multiplier = 1.25
	dock_light.emission_enabled = true
	dock_light.emission = Color("dde6ed")
	dock_light.emission_energy_multiplier = 1.4
	deck_light.emission_enabled = true
	deck_light.emission = Color("ffbc64")
	deck_light.emission_energy_multiplier = 1.45
	var source := PLATFORM_PANEL.instantiate() as Node3D
	add_child(source)
	source.hide()
	var visual := source as MeshInstance3D
	if visual == null:
		visual = source.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	platform_mesh = visual.mesh
	panel_transform = global_transform.affine_inverse()*visual.global_transform
	panel_bounds = panel_transform*visual.get_aabb()
	source.queue_free()
	_build_deck(art)
	_build_shaft(art)
	_build_laser_lights()
	_present_travel()

func _deck_finish(size: Vector2) -> ShaderMaterial:
	var finish := ShaderMaterial.new()
	finish.shader = DECK_SHADER
	finish.set_shader_parameter("worn_surface", load(FITTINGS.CONCRETE+"Diffuse.res"))
	finish.set_shader_parameter("panel_trim", (platform_mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture)
	finish.set_shader_parameter("deck_half", size*.5)
	finish.set_shader_parameter("dock_half_width", PLAN.BRIDGE_WIDTH*.5)
	return finish

func _build_deck(art: RefCounted) -> void:
	var area := PLAN.ARENA_DECK
	var middle := area.get_center()
	var at := Vector3(middle.x,0,middle.y)
	M.box(self,"DeckSheet",Vector3(area.size.x-.05,.15,area.size.y-.05),at-Vector3.UP*.10,frame_material)
	# Batch the original CC0 meshes. Each panel keeps its vertices and trim UVs;
	# the entire top shares one set of markings and one moving transform.
	var count := Vector2i(ceili(area.size.x/4.),ceili(area.size.y/4.))
	var step := area.size/Vector2(count)
	var basis := Basis.from_scale(Vector3(step.x/panel_bounds.size.x,1.,step.y/panel_bounds.size.z))
	var pivot := panel_bounds.get_center()
	pivot.y = panel_bounds.end.y
	var batch := SurfaceTool.new()
	for z in count.y:
		for x in count.x:
			var offset := Vector2(x+.5,z+.5)*step-area.size*.5
			batch.append_from(platform_mesh,0,Transform3D(basis,Vector3(offset.x,0.,offset.y)-basis*pivot)*panel_transform)
	var deck := MeshInstance3D.new()
	deck.name = "OnePieceBattleDeck"
	deck.mesh = batch.commit()
	_laser_deck = _deck_finish(area.size)
	deck.material_override = _laser_deck
	deck.position = at
	add_child(deck)
	_build_deck_frame(area)
	for side: float in [-1.0, 1.0]:
		var deck_edge := middle.x+side*area.size.x*.5
		var x := deck_edge-side*.19
		for section in 5:
			var z := area.position.y+(section+.5)*area.size.y/5.
			art.fittings.fit(self,"BottomSimple_Straight",Vector3(x,.044,z),Vector3(.18,.092,area.size.y/5.-.022))
		for z: float in [area.position.y+1.4,middle.y,area.end.y-1.4]:
			M.box(self, "InsetDeckMarker", Vector3(.10,.037,.33), Vector3(x-side*.66,.008,z), deck_light)
	for z: float in [area.position.y+2.35,area.end.y-5.8]:
		M.box(self,"BogieCrossbeam",Vector3(RAIL_HALF_GAUGE*2.+1.45,.42,.88),Vector3(middle.x,-.63,z),frame_material)
		for side: float in [-1.,1.]:
			_build_carriage(art,middle.x+side*RAIL_HALF_GAUGE,z)
	for side: float in [-1.,1.]:
		var side_x := middle.x+side*(PLAN.BRIDGE_WIDTH*.5+.19)
		M.box(self,"FlushDockingLight",Vector3(.18,.032,.40),Vector3(side_x,.010,area.end.y-.23),dock_light)
	_build_deck_guardrails(area)

func _build_deck_frame(area: Rect2) -> void:
	var frame := WALKWAY.WAREHOUSE.MeshBuilder.new()
	var inside := area.grow(-.18)
	var corners := PackedVector2Array([inside.position,Vector2(inside.end.x,inside.position.y),
		inside.end,Vector2(inside.position.x,inside.end.y)])
	for side in corners.size():
		var start := corners[side]
		var end := corners[(side+1)%corners.size()]
		for y: float in [-.15,-.83]:
			frame.bar(guide_material,Vector3(start.x,y,start.y),Vector3(end.x,y,end.y),.22)
		var bays := ceili(start.distance_to(end)/3.6)
		for index in bays:
			var a := start.lerp(end,float(index)/bays)
			var b := start.lerp(end,float(index+1)/bays)
			frame.box(guide_material,Vector3(a.x,-.49,a.y),Vector3(.30,.72,.30))
			var top := a.lerp(b,.38 if index%2==0 else .62)
			var bottom := b if index%2==0 else a
			frame.bar(rim_material,Vector3(top.x,-.22,top.y),Vector3(bottom.x,-.79,bottom.y),.18)
	var visual := MeshInstance3D.new()
	visual.name = "OpenDeckFrame"
	visual.mesh = frame.bake()
	add_child(visual)

func _build_deck_guardrails(area: Rect2) -> void:
	var edge := area.grow(-.28)
	var entry := PLAN.LIFT_ENTRY
	var half_width := PLAN.BRIDGE_WIDTH*.5
	var bevel := .55
	# Start on one side of the opening and wrap around to the other side.
	var path := PackedVector2Array([
		Vector2(entry.x-half_width,edge.end.y),Vector2(edge.position.x+bevel,edge.end.y),
		Vector2(edge.position.x,edge.end.y-bevel),Vector2(edge.position.x,edge.position.y+bevel),
		Vector2(edge.position.x+bevel,edge.position.y),Vector2(edge.end.x-bevel,edge.position.y),
		Vector2(edge.end.x,edge.position.y+bevel),Vector2(edge.end.x,edge.end.y-bevel),
		Vector2(edge.end.x-bevel,edge.end.y),Vector2(entry.x+half_width,edge.end.y)
	])
	var rails := WALKWAY.WAREHOUSE.MeshBuilder.new()
	for index in path.size()-1:
		_add_rail_span(rails,path[index],path[index+1])
	_add_rail_post(rails,path[-1])
	var visual := MeshInstance3D.new()
	visual.name = "PlatformGuardrails"
	visual.mesh = rails.bake()
	add_child(visual)

func _add_rail_span(rails, start: Vector2, end: Vector2) -> void:
	rails.bar(handrail_material,Vector3(start.x,1.02,start.y),Vector3(end.x,1.02,end.y),.082)
	rails.bar(rim_material,Vector3(start.x,.52,start.y),Vector3(end.x,.52,end.y),.041)
	var posts := ceili(start.distance_to(end)/3.45)
	for index in posts:
		_add_rail_post(rails,start.lerp(end,float(index)/posts))

func _add_rail_post(rails, at: Vector2) -> void:
	rails.box(rim_material,Vector3(at.x,.50,at.y),Vector3(.084,1.,.084))
	rails.box(guide_material,Vector3(at.x,.033,at.y),Vector3(.24,.065,.24))

func _build_carriage(art: RefCounted, x: float, z: float) -> void:
	var y := guide_axis_height(z)
	var carriage := Node3D.new()
	carriage.name = "DeckGuideCarriage"
	carriage.position = Vector3(x,y,z)
	carriage.rotation.x = atan(GUIDE_GRADE)
	add_child(carriage,true)
	M.box(carriage,"GuideSaddle",Vector3(1.04,.22,1.52),Vector3(0,RAIL_HEAD_TOP+.11,0),carriage_paint)
	for cheek: float in [-1.,1.]:
		M.box(carriage,"RailCaptureJaw",Vector3(.21,.65,1.52),Vector3(cheek*(RAIL_HEAD_WIDTH*.5+.118),.10,0),rim_material)
	art.fittings.fit(carriage,"Prop_PipeHolder",Vector3(0,.61,0),Vector3(.72,.22,.82))
	var saddle := carriage.position+Vector3(0,.53,0)
	for offset: float in [-.73,.73]:
		var sill := Vector3(x,-.64,z+offset)
		var support := M.box(self,"CarriageToDeckBrace",Vector3(.36,.31,sill.distance_to(saddle)+.22),
			(sill+saddle)*.5,rim_material)
		support.look_at(to_global(saddle))

func _build_shaft(art: RefCounted) -> void:
	var walls: Node3D = art.wall_root
	var area := PLAN.ARENA_DECK
	var mid_x := area.get_center().x
	lower_landing = Node3D.new()
	lower_landing.name = "BoardingBridge"
	walls.add_child(lower_landing)
	WALKWAY.build_bridge(art,lower_landing,dock_light)
	var shaft_walls: ShaderMaterial = art.fittings.graphite_wall.duplicate()
	shaft_walls.set_shader_parameter("enamel", Color("a2a39e"))
	shaft_walls.set_shader_parameter("panel_pitch", 3.2)
	shaft_walls.set_shader_parameter("weathering", .52)
	shaft_walls.set_shader_parameter("albedo_contrast", 1.72)
	shaft_walls.set_shader_parameter("roughness_map", load(FITTINGS.CONCRETE+"Rough.res"))
	shaft_walls.set_shader_parameter("attached_finish",true)
	for index in BAY_COUNT:
		var bay := Node3D.new()
		bay.name = "ShaftBay%d"%index
		walls.add_child(bay)
		shaft_bays.append(bay)
		for side: float in [-1.,1.]:
			var edge := mid_x+side*area.size.x*.5
			var wall_face := edge+side*WALL_CLEARANCE
			_build_outer_wall(art,bay,wall_face+side*WALL_THICKNESS*.5,side,shaft_walls)
			if index%2==0: _build_wall_light(art,bay,wall_face,side)
		_build_guideway(art,bay,mid_x,index%2==0)

func _build_outer_wall(art: RefCounted, bay: Node3D, x: float, side: float, finish: ShaderMaterial) -> void:
	var suffix := "West" if side<0. else "East"
	var footprint := Rect2(x-WALL_THICKNESS*.5,-BAY_LENGTH*.5,WALL_THICKNESS,BAY_LENGTH)
	var wall: MeshInstance3D = art.boundary_wall(bay,"OuterShaftWall"+suffix,footprint,SHELL_BASE,
		SHELL_RIM-SHELL_BASE,Vector2(side,0),finish,true)
	wall.layers |= LASER_WALL_LAYER
	# The rim is above the gameplay frustum. Keep the concrete face vertical
	# and its sloped top and bottom flush with neighbouring bays.
	wall.basis = Basis(Vector3.RIGHT,Vector3.UP,Vector3(0.,-GUIDE_GRADE,1.))
	var z := BAY_LENGTH*.5-.42
	var joint_y := SHELL_RIM-GUIDE_GRADE*z
	var cover := M.box(bay,"OuterWallJointCover"+suffix,Vector3(.08,SHELL_RIM-SHELL_BASE,.20),
		Vector3(x-side*WALL_THICKNESS*.5+side*.026,joint_y-(SHELL_RIM-SHELL_BASE)*.5,z),rim_material)
	cover.basis = wall.basis
	cover.layers |= LASER_WALL_LAYER
	art.cutout.register_mesh(cover,true)

func _build_laser_lights() -> void:
	_laser_segments.resize(6)
	for index in _laser_segments.size():
		var light := OmniLight3D.new()
		light.name = "LaserWallImpact%d" % (index+1)
		light.light_cull_mask = LASER_WALL_LAYER
		light.light_color = Color("ff4435")
		light.light_energy = 3.2
		light.light_indirect_energy = 0.0
		light.light_volumetric_fog_energy = 0.0
		light.omni_range = 2.55
		light.omni_attenuation = 1.65
		light.hide()
		add_child(light)
		_laser_wall_lights.append(light)

func set_laser_illumination(a: Vector3, b: Vector3, index: int, wall_side: float, max_range: float) -> Vector3:
	var area := PLAN.ARENA_DECK
	var center := area.get_center()
	_laser_segments[index] = Vector4(a.x-center.x,a.z-center.y,b.x-center.x,b.z-center.y)
	var impact := _laser_wall_contact(a,b,wall_side,max_range)
	var light := _laser_wall_lights[index]
	if impact != b:
		light.position = impact-Vector3(wall_side*LASER_WALL_LIGHT_OFFSET,0,0)
	light.visible = impact != b
	return impact

func _laser_wall_contact(a: Vector3, b: Vector3, side: float, max_range: float) -> Vector3:
	var span := b-a
	if side == 0.0 or span.x*side <= .001 or span.length_squared() < .001: return b
	# Continue the visible ray from the marked deck-side barrier to the actual shaft face.
	var area := PLAN.ARENA_DECK
	var wall_x := area.get_center().x+side*(area.size.x*.5+WALL_CLEARANCE)
	var impact := a+span*((wall_x-a.x)/span.x)
	if a.distance_squared_to(impact) > max_range*max_range: return b
	if impact.z < SHAFT_NORTH or impact.z > SHAFT_NORTH+BAY_COUNT*BAY_LENGTH: return b
	var height := impact.y+_shaft_grade_at(impact.z)+deck_vertical_offset
	if height < SHELL_BASE or height > SHELL_RIM: return b
	return impact

func apply_laser_illumination(ray_count: int) -> void:
	if ray_count > 0:
		_laser_deck.set_shader_parameter("laser_segments", _laser_segments)
	_laser_deck.set_shader_parameter("laser_count", ray_count)
	for index in range(ray_count, _laser_wall_lights.size()):
		_laser_wall_lights[index].hide()

func _build_wall_light(art: RefCounted, walls: Node3D, face: float, side: float) -> void:
	var work_light := side < 0.0
	var mount := Vector3(face,0,0)+(WORK_LAMP_OFFSET if work_light else SERVICE_LAMP_OFFSET)
	var tint := Color("c2dddd") if work_light else Color("ffc18a")
	var lamp: Node3D = art.fittings.fit(walls,"Prop_Light_Wide",mount,
		Vector3(1.85,.17,.34),Vector3(0,-side*90,0))
	art.cutout.register_tree(lamp,true)
	var diffuser := M.box(walls,"ServiceLampDiffuser",Vector3(.22,.055,1.59),
		mount+Vector3(-side*.21,-.085,0),dock_light if work_light else deck_light)
	var light_cover := M.box(walls,"BeaconLens",Vector3(.073,.155,.135),
		mount+Vector3(side*.14,-.18,1.28),signal_material)
	art.cutout.register_mesh(light_cover,true)
	var pool: OmniLight3D = art._omni(walls,"PassingServiceGlow",mount+Vector3(-side*.89,-.47,.10),tint,
		1.65 if work_light else 3.55, 6.2 if work_light else 9.6,1.5,false)
	art.OPTICS.mark_fixture(walls, pool, [diffuser], 0.0)

func _build_guideway(art: RefCounted, bay: Node3D, center: float, lit: bool) -> void:
	var length := BAY_LENGTH*Vector2(1.,GUIDE_GRADE).length()
	var guideway := Node3D.new()
	guideway.name = "CentralInclinedGuideway"
	guideway.position = Vector3(center,guide_axis_height(PLAN.ARENA_DECK.get_center().y),0)
	guideway.rotation.x = atan(GUIDE_GRADE)
	bay.add_child(guideway)
	for side: float in [-1.,1.]:
		var track := Node3D.new()
		track.name = "WestRail" if side<0. else "EastRail"
		track.position.x = side*RAIL_HALF_GAUGE
		guideway.add_child(track)
		M.box(track,"RailWeb",Vector3(.25,.58,length),Vector3(0,-.075,0),rim_material)
		M.box(track,"RailFoot",Vector3(.58,.13,length),Vector3(0,-.365,0),frame_material)
		M.box(track,"RunningSurface",Vector3(RAIL_HEAD_WIDTH,.14,length),Vector3(0,RAIL_HEAD_TOP-.07,0),guide_material)
		M.box(track,"InclinedFoundation",Vector3(1.32,.72,length),Vector3(0,-.985,0),rim_material)
		art.fittings.fit(track,"BottomSimple_Straight",Vector3(side*.44,-.56,0),Vector3(.26,.18,length))
	for slot in 4:
		var z := ((slot+.5)/4.-.5)*length
		M.box(guideway,"CrossSleeper",Vector3(RAIL_HALF_GAUGE*2.+5.1,.21,.42),Vector3(0,-.53,z),rim_material)
		for x: float in [-RAIL_HALF_GAUGE-.43,RAIL_HALF_GAUGE+.43]:
			M.box(guideway,"RailFastener",Vector3(.22,.18,.34),Vector3(x,-.36,z),carriage_paint)
	_build_guideway_services(art,guideway,length)
	if lit:
		var lamp_at := Vector3(-RAIL_HALF_GAUGE-1.16,.38,-.77)
		var lens := M.box(guideway,"GuideInspectionLens",Vector3(.10,.075,.48),lamp_at,dock_light)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art._omni(guideway,"GuidewayWash",lamp_at+Vector3(.25,.32,0),Color("7ea7bb"),2.35,7.2,1.68,false)

func _build_guideway_services(art: RefCounted, guideway: Node3D, length: float) -> void:
	var half := length*.5
	var services := Node3D.new()
	services.name = "GuidewayServices"
	guideway.add_child(services)
	for side: float in [-1.,1.]:
		for offset: float in [.96,1.89]:
			var radius := .39 if offset<1. else .29
			var x := side*(RAIL_HALF_GAUGE+offset)
			var axis := Vector3(x,-.25,0.)
			var a := axis-Vector3.FORWARD*half
			var b := axis+Vector3.FORWARD*half
			M.pipe(services,a,b,radius,service_pipe)
			var flange := M.cylinder(services,"PipeFlange",radius+.085,.24,axis+Vector3(0,0,half-.68),guide_material)
			flange.rotation.x = PI*.5
		var holder_x := side*(RAIL_HALF_GAUGE+1.4)
		art.fittings.fit(services,"Prop_PipeHolder",Vector3(holder_x,-.53,-half+.43),Vector3(1.98,.28,.34))
	M.box(services,"CableTray",Vector3(1.70,.19,length),Vector3(0,-.47,0),frame_material)
	for side: float in [-1.,1.]:
		M.box(services,"CableTrayLips",Vector3(.11,.22,length),Vector3(side*.83,-.34,0),rim_material)
	for strand in 5:
		var x := (strand-2)*.255
		var jacket := cable_jacket if strand==1 else cable_rubber
		M.pipe(services,Vector3(x,-.255,half),Vector3(x,-.255,-half),.105,jacket)
	M.box(services,"CableRetainer",Vector3(1.54,.094,.23),Vector3(0,-.118,-half+.28),guide_material)
	var junction := Vector3(1.46,-.27,-half+1.08)
	M.box(services,"CableJunction",Vector3(.74,.37,.72),junction,rim_material)
	M.box(services,"JunctionPlate",Vector3(.50,.038,.52),junction+Vector3.UP*.20,guide_material)
	art.fittings.fit(services,CABLE_SPUR,Vector3(.92,-.222,junction.z+.29),Vector3(.93,.25,.95))

func build_board_gate(art: RefCounted) -> Node3D:
	var entry := PLAN.LIFT_ENTRY-Vector2(0.,.28)
	var half_width := Vector2(PLAN.BRIDGE_WIDTH*.5,0)
	var rails := WALKWAY.WAREHOUSE.MeshBuilder.new()
	_add_rail_span(rails,entry-half_width,entry+half_width)
	var railing := MeshInstance3D.new()
	railing.name = "DockSafetyRail"
	railing.mesh = rails.bake()
	add_child(railing)
	art.cutout.register_mesh(railing,true)
	return railing

func light_shaft(art: RefCounted) -> void:
	var entry := PLAN.LIFT_ENTRY
	var dock: SpotLight3D = art._spot(lower_landing,"DockHeaderLamp",Vector3(entry.x+2.,4.35,entry.y+2.65),
		Vector3(entry.x-.40,0.,entry.y-.55),Color("f1bb83"),4.8,15.0,52.0)
	dock.spot_angle_attenuation = 1.9
	dock.shadow_reverse_cull_face = true
	dock.shadow_blur = .95
	var bridge := PLAN.ARENA_BRIDGE
	for z: float in [bridge.end.y-2.,bridge.get_center().y]:
		art._omni(lower_landing,"BridgeWorkLight",Vector3(entry.x,3.45,z),Color("c7d8db"),2.6,8.5,1.55,false)
	var deck := PLAN.ARENA_DECK
	var mid_x := deck.get_center().x
	art._omni(self,"CargoBayFill",Vector3(mid_x,5.2,deck.get_center().y+2.4),Color("b2c7d8"),1.6,20.,1.42,false)
	work_origin = Vector3(deck.position.x-WALL_CLEARANCE,0,0)+WORK_LAMP_OFFSET+Vector3(.42,-.17,.12)
	service_origin = Vector3(deck.end.x+WALL_CLEARANCE,0,0)+SERVICE_LAMP_OFFSET+Vector3(-.52,-.21,0)
	work_beam = art._spot(art.lights_root,"ShaftWorkBeam",work_origin,
		Vector3(mid_x+3.15,-.5,WORK_LAMP_OFFSET.z+4.15),Color("c2dddd"),WORK_BEAM_ENERGY,26.5,42.0)
	work_beam.spot_angle_attenuation = 2.0
	work_beam.shadow_reverse_cull_face = true
	work_beam.shadow_bias = .065
	work_beam.shadow_blur = .85
	service_beam = art._spot(art.lights_root,"ShaftServiceRim",service_origin,
		Vector3(mid_x+1.9,.7,SERVICE_LAMP_OFFSET.z-2.6),Color("ffd5ae"),SERVICE_BEAM_ENERGY,18.5,36.0)
	service_beam.spot_angle_attenuation = 2.1
	service_beam.shadow_enabled = false
	_sync_shaft_beams()

func start_ascent() -> void:
	if travel != Travel.DOCKED: return
	travel = Travel.ASCENDING
	travel_age = 0.
	_start_shudder(.16,.42)

func shake_on_landing() -> void:
	_start_shudder(.34,.67)

func _start_shudder(amplitude: float, duration: float) -> void:
	_shudder_amplitude = amplitude
	_shudder_duration = duration
	_shudder_elapsed = 0.

func _advance_shudder(delta: float) -> void:
	if _shudder_duration <= 0.: return
	_shudder_elapsed += delta
	var progress := minf(_shudder_elapsed/_shudder_duration,1.)
	var decay := 1.-progress
	deck_vertical_offset = -_shudder_amplitude*sin(progress*TAU*SHUDDER_CYCLES)*decay*decay
	if progress >= 1.: _shudder_duration = 0.

func advance(delta: float) -> void:
	if travel in [Travel.DOCKED,Travel.UPPER]: return
	travel_age += delta
	if travel == Travel.ASCENDING:
		speed = move_toward(speed,CRUISE_SPEED,delta*3.8)
	else:
		speed = arrival_speed*(1.-smoothstep(0.,ARRIVAL_TIME,travel_age))
		if travel_age>=ARRIVAL_TIME: travel = Travel.UPPER
	distance += speed*delta
	_advance_shudder(delta)
	_present_travel()
	_update_travel_audio()

func _update_travel_audio() -> void:
	if not is_instance_valid(travel_audio):
		return
	if speed <= 0.01 or not is_visible_in_tree():
		stop_travel_audio()
		return
	var speed_ratio := clampf(speed / CRUISE_SPEED, 0.02, 1.0)
	var gameplay_pitch := float(_sfx_manager.current_gameplay_audio_pitch) if is_instance_valid(_sfx_manager) else 1.0
	travel_audio.volume_db = TRAVEL_DB + linear_to_db(speed_ratio)
	travel_audio.pitch_scale = clampf(gameplay_pitch * lerpf(0.86, 1.0, speed_ratio), 0.05, 3.0)
	if not travel_audio.playing:
		travel_audio.play()

func _stop_audio_when_hidden() -> void:
	if not is_visible_in_tree():
		stop_travel_audio()

func stop_travel_audio() -> void:
	if is_instance_valid(travel_audio) and travel_audio.playing:
		travel_audio.stop()

func _present_travel() -> void:
	# The level deck frame carries actors and effects together. Apply the
	# elevator's vertical shudder to the shaft in reverse.
	var shaft_heave := -deck_vertical_offset
	lower_landing.position = Vector3(0,-distance*GUIDE_GRADE+shaft_heave,distance)
	lower_landing.visible = distance<17.
	var span := BAY_COUNT*BAY_LENGTH
	for index in shaft_bays.size():
		var z := SHAFT_NORTH+fposmod((index+.5)*BAY_LENGTH+distance,span)
		shaft_bays[index].position = Vector3(0,-_shaft_grade_at(z)+shaft_heave,z)
	if is_instance_valid(work_beam): _sync_shaft_beams()

func _sync_shaft_beams() -> void:
	# The narrow beams follow the installed lights on the bay passing above the
	# deck. Fade at the handoff and reuse one shadow map through the entire ride.
	var far_z := WORK_BEAM_NEAR_Z-2.0*BAY_LENGTH
	for index in range(0,shaft_bays.size(),2):
		var offset := shaft_bays[index].position
		if offset.z < far_z or offset.z >= WORK_BEAM_NEAR_Z: continue
		var exposure := smoothstep(far_z,far_z+2.65,offset.z)*(1.0-smoothstep(WORK_BEAM_NEAR_Z-2.15,WORK_BEAM_NEAR_Z,offset.z))
		work_beam.position = work_origin+offset
		work_beam.light_energy = WORK_BEAM_ENERGY*exposure
		service_beam.position = service_origin+offset
		service_beam.light_energy = SERVICE_BEAM_ENERGY*exposure
		return

func _shaft_grade_at(z: float) -> float:
	return (z-PLAN.ARENA_DECK.get_center().y)*GUIDE_GRADE

func guide_axis_height(z: float) -> float:
	return FRONT_RAIL_LEVEL+(PLAN.ARENA_DECK.position.y-z)*GUIDE_GRADE

func snap_to_dock() -> void:
	stop_travel_audio()
	distance = 0.
	speed = 0.
	travel_age = 0.
	travel = Travel.DOCKED
	_shudder_duration = 0.
	deck_vertical_offset = 0.
	_present_travel()

func finish_ascent() -> void:
	arrival_speed = maxf(speed,CRUISE_SPEED*.7)
	travel_age = 0.
	travel = Travel.ARRIVING
