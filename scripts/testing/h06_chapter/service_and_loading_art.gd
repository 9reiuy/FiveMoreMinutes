extends RefCounted
## Furnishings for the under-stair plant room and the staffed loading bay.
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const TRANSIT := preload("res://scripts/testing/transit_concourse_area.gd")
const TRAINING := preload("res://scripts/story/tutorial_training_facility_art.gd")
const TILES := preload("res://shaders/dream3d/transit_surfaces.gdshader")
const OFFICE := "res://art/Dream/office_lowpoly/kenney/"

var fittings: FITTINGS
var kit: KIT
var plaster := TRAINING.surface(0,Color("c8c6ba"))
var wall_tile := ShaderMaterial.new()
var floor_tile: ShaderMaterial
var access_floor: ShaderMaterial
var access_wall: ShaderMaterial
var rusty := TRAINING.surface(5,Color("97654e"))
var steel := TRAINING.surface(5,Color("52595a"))
var yellow := TRAINING.surface(5,Color("e2b82c"))
var dark := TRAINING.surface(5,Color("393e40"))
var blue := TRAINING.surface(5,Color("586563"))
var dock_floor: ShaderMaterial

func _init(f: FITTINGS) -> void:
	fittings = f
	kit = f.kit
	wall_tile.shader = TILES
	wall_tile.set_shader_parameter("face_colour",Color("d1cbc0"))
	wall_tile.set_shader_parameter("joint_colour",Color("908a7b"))
	wall_tile.set_shader_parameter("tile_span",Vector2(.33,.33))
	wall_tile.set_shader_parameter("joint_width",.008)
	wall_tile.set_shader_parameter("wall_surface",true)
	wall_tile.set_shader_parameter("wear",.32)
	floor_tile = wall_tile.duplicate() as ShaderMaterial
	floor_tile.set_shader_parameter("wall_surface",false)
	floor_tile.set_shader_parameter("face_colour",Color("a49f8f"))
	floor_tile.set_shader_parameter("joint_colour",Color("716e62"))
	floor_tile.set_shader_parameter("tile_span",Vector2(.79,.79))
	dock_floor = f.floor_material(FITTINGS.Deck.FREIGHT).duplicate() as ShaderMaterial
	dock_floor.set_shader_parameter("base",Color("51575b"))
	dock_floor.set_shader_parameter("slab_span",Vector2(2.1,1.55))
	dock_floor.set_shader_parameter("loading_lane",true)

func prepare_access() -> void:
	var mouth: Rect2 = PLAN.LOWER.secret_mouth
	var fade := Vector2(mouth.position.x+.28,mouth.end.x-.18)
	access_floor = floor_tile.duplicate() as ShaderMaterial
	access_floor.set_shader_parameter("west_fade",fade)
	access_wall = wall_tile.duplicate() as ShaderMaterial
	access_wall.set_shader_parameter("west_fade",fade)

func utility_wall(parent: Node3D, r: Rect2, outward: Vector2) -> void:
	var height := .64 if outward==Vector2.DOWN else 4.49
	var wall := MeshInstance3D.new()
	wall.name = "PlantRoomWall"
	wall.mesh = TRANSIT.top_black_wall(Rect2(-r.size*.5,r.size),Vector2i(outward),height,plaster,kit.cutout.top_black)
	var center := r.get_center()
	wall.position = Vector3(center.x,0,center.y)
	parent.add_child(wall)
	kit.cutout.register_mesh(wall)
	var face := center-outward*(minf(r.size.x,r.size.y)*.5+.020)
	var run := maxf(r.size.x,r.size.y)
	var h := minf(height-.055,2.39)
	var size := Vector3(.027,h,run-.028) if outward.x!=0 else Vector3(run-.028,h,.027)
	kit.box(parent,"GlazedTileDado",size,Vector3(face.x,h*.5,face.y),wall_tile,true)

func build_utility(parent: Node3D) -> void:
	var y := PLAN.SERVICE_RISE
	var rect := PLAN.SERVICE_DECK
	var c := rect.get_center()
	const TILE_HEIGHT := .04
	kit.box(parent,"RaisedPlantFloor",Vector3(rect.size.x,y-TILE_HEIGHT,rect.size.y),Vector3(c.x,(y-TILE_HEIGHT)*.5,c.y),plaster)
	kit.box(parent,"PlantFloorTiles",Vector3(rect.size.x,TILE_HEIGHT,rect.size.y),Vector3(c.x,y-TILE_HEIGHT*.5,c.y),floor_tile)
	var stairs := PLAN.SERVICE_STEPS
	for i in 5:
		var h := y*(5-i)/5.
		var z := stairs.position.y+(i+.5)*stairs.size.y/5.
		kit.box(parent,"PlantStairTread",Vector3(stairs.size.x,h,stairs.size.y/5.),Vector3(stairs.get_center().x,h*.5,z),floor_tile)
		kit.box(parent,"WornNosing",Vector3(stairs.size.x-.02,.034,.055),Vector3(stairs.get_center().x,h-.012,z+stairs.size.y*.10-.023),plaster)
	for rail: Rect2 in PLAN.SERVICE_RAILS: _guardrail(parent,rail,y,rusty)
	var tank_at: Vector2 = PLAN.SERVICE_FIXTURES.PressureTank.get_center()
	var core := Vector3(tank_at.x,y,tank_at.y)
	for i in 3:
		var dir := Vector3(sin(TAU*i/3.),0,cos(TAU*i/3.))
		var foot := core+dir*.95
		kit.pipe(parent,foot+Vector3.UP*.09,core+dir*.75+Vector3.UP*.74,.067,rusty)
		kit.cylinder(parent,"TankFoot",.14,.06,foot+Vector3.UP*.045,rusty)
	var vessel := fittings.barrel(parent,core+Vector3.UP*1.87,2.69,2.18,true,Color("91af86"),true)
	vessel.name = "CeladonPressureTank"
	kit.torus_ring(parent,"CoverSeam",1.10,1.04,core+Vector3.UP*3.02,rusty)
	var port := core+Vector3(0,1.14,1.07)
	kit.cylinder(parent,"SightGlass",.245,.12,port,steel,Vector3.BACK)
	kit.torus_ring(parent,"InspectionFlange",.31,.235,port+Vector3.BACK*.08,rusty,Vector3(90,0,0))
	kit.torus_ring(parent,"TankValve",.145,.109,port+Vector3(.45,.46,-.01),rusty,Vector3(90,0,0))
	for x: float in [15.40,16.38]:
		fittings.barrel(parent,Vector3(x,y+.62,-5.65),1.24,.86,true,Color("687272"),true)
	for x: float in [17.99,19.42]:
		var basin := fittings.fit(parent,OFFICE+"bathroomSink.glb",Vector3(x,y+.70,-5.79),Vector3(1.11,1.02,.75))
		basin.name = "WallBasin_%d" % roundi(x)
		kit.pipe(parent,Vector3(x,y+.15,-6.05),Vector3(x,y+.58,-6.05),.051,steel)
		kit.pipe(parent,Vector3(x,y+1.03,-6.03),Vector3(x,y+1.35,-6.03),.033,steel)
		kit.pipe(parent,Vector3(x,y+1.33,-6.03),Vector3(x,y+1.33,-5.77),.032,steel)
	for i in 3: _locker(parent,Vector3(20.86+i*.74,y,-5.76),i==1)
	fittings.fit(parent,OFFICE+"cardboardBoxOpen.scn",Vector3(16.62,y+.28,-4.27),Vector3(.96,.56,.64),Vector3(0,-9,0))
	fittings.fit(parent,OFFICE+"cardboardBoxClosed.glb",Vector3(17.18,y+.23,-4.42),Vector3(.52,.46,.52),Vector3(0,16,0))
	for i in 2:
		var offset := Vector3(0,3.46+i*.42,-5.93-i*.22)
		kit.pipe(parent,Vector3(12.05,0,0)+offset,Vector3(22.75,0,0)+offset,.095+i*.024,rusty)
		for x: float in [13,16.8,20.65,22.37]:
			kit.pipe(parent,Vector3(x-.05,0,0)+offset,Vector3(x+.05,0,0)+offset,.114+i*.025,steel)
	for x: float in [13.0,16.8,20.65]:
		kit.box(parent,"PipeSaddle",Vector3(.085,.09,.71),Vector3(x,3.50,-6.06),rusty)
		kit.pipe(parent,Vector3(x,3.12,-6.37),Vector3(x,3.52,-5.76),.036,rusty)
	for p: Vector2 in [Vector2(13.35,-.94),Vector2(21.9,-.64),Vector2(18.45,3.63)]:
		var top := y if rect.has_point(p) else .0
		kit.cylinder(parent,"CastDrain",.245,.019,Vector3(p.x,top+.014,p.y),rusty)
		for i in range(-2,3):
			kit.box(parent,"DrainSlot",Vector3(.044,.009,.285-absf(i)*.04),Vector3(p.x+i*.073,top+.024,p.y),dark)

func _locker(parent: Node3D, base: Vector3, open: bool) -> void:
	kit.box(parent,"LockerCase",Vector3(.71,1.98,.71),base+Vector3(0,.99,0),blue)
	kit.box(parent,"LockerInterior",Vector3(.62,1.82,.025),base+Vector3(0,1.01,.365),dark)
	var leaf := Node3D.new()
	leaf.name = "LockerDoor"
	parent.add_child(leaf)
	leaf.position = base+Vector3(-.31,0,.388)
	leaf.rotation.y = -.68 if open else 0.
	kit.box(leaf,"SteelDoor",Vector3(.62,1.85,.047),Vector3(.31,1.00,0),blue)
	for j in 4: kit.box(leaf,"PressedVent",Vector3(.30,.024,.013),Vector3(.31,1.64-j*.055,.027),dark)
	kit.box(leaf,"Latch",Vector3(.034,.15,.05),Vector3(.52,.94,.043),steel)

func _guardrail(parent: Node3D, rect: Rect2, base: float, finish: Material) -> void:
	var run := Vector2.RIGHT if rect.size.x>=rect.size.y else Vector2.DOWN
	var half := maxf(rect.size.x,rect.size.y)*.5-.07
	var a := rect.get_center()-run*half
	var b := rect.get_center()+run*half
	for h: float in [.49,.96]:
		kit.pipe(parent,Vector3(a.x,base+h,a.y),Vector3(b.x,base+h,b.y),.038,finish)
	var spans := maxi(1,ceili(a.distance_to(b)/2.15))
	for i in spans+1:
		var p := a.lerp(b,float(i)/spans)
		kit.box(parent,"BoltedRailFoot",Vector3(.18,.046,.19),Vector3(p.x,base+.023,p.y),steel)
		kit.pipe(parent,Vector3(p.x,base+.04,p.y),Vector3(p.x,base+.96,p.y),.043,finish)

func build_loading_bay(parent: Node3D) -> void:
	for x: float in PLAN.CARGO_FRAME_X:
		var frame := Node3D.new()
		frame.name = "LoadingPortal_%d" % roundi(x)
		parent.add_child(frame)
		frame.position.x = x
		for z: float in [PLAN.CARGO_FRAME_NORTH,PLAN.CARGO_FRAME_SOUTH]:
			fittings.fit(frame,"Column_Simple",Vector3(0,1.77,z),Vector3(.34,3.54,.39))
			kit.box(frame,"ColumnBase",Vector3(.62,.25,.65),Vector3(0,.125,z),dark)
			kit.box(frame,"Flange",Vector3(.50,.11,.62),Vector3(0,3.43,z),steel)
		var middle := (PLAN.CARGO_FRAME_NORTH+PLAN.CARGO_FRAME_SOUTH)*.5
		var span := PLAN.CARGO_FRAME_SOUTH-PLAN.CARGO_FRAME_NORTH+.49
		kit.box(frame,"BeamWeb",Vector3(.105,.32,span),Vector3(0,3.63,middle),steel)
		for h: float in [3.45,3.81]:
			kit.box(frame,"IBeamFlange",Vector3(.36,.07,span),Vector3(0,h,middle),dark)
		var lamp_at := Vector3(-.30,3.36,middle)
		fittings.fit(frame,"Prop_Light_Wide",lamp_at,Vector3(3.75,.16,.26),Vector3(0,90,0))
		kit.box(frame,"FluorescentLens",Vector3(.17,.09,3.47),lamp_at+Vector3(-.10,-.038,0),fittings.lamp)
		kit.cutout.register_tree(frame)
	# Longitudinal steel and cross-bracing belong to the pipe side. The centre aisle stays open.
	var first: float = PLAN.CARGO_FRAME_X.front()
	var last: float = PLAN.CARGO_FRAME_X.back()
	for z: float in [PLAN.CARGO_FRAME_NORTH,PLAN.CARGO_FRAME_SOUTH]:
		kit.box(parent,"LongitudinalSteel",Vector3(last-first+.35,.19,.14),Vector3((last+first)*.5,3.70,z),dark,true)
	for i in PLAN.CARGO_BRACED_BAYS:
		var a: float = PLAN.CARGO_FRAME_X[i]
		var b: float = PLAN.CARGO_FRAME_X[i+1]
		for ends: Vector2 in [Vector2(.48,3.38),Vector2(3.38,.48)]:
			kit.pipe(parent,Vector3(a,ends.x,PLAN.CARGO_FRAME_NORTH),Vector3(b,ends.y,PLAN.CARGO_FRAME_NORTH),.068,steel)
	for rail: Rect2 in PLAN.CARGO_RAILS: _guardrail(parent,rail,0.,yellow)
	var rack := PLAN.CARGO_PIPE_RACK
	var middle := rack.get_center()
	for side in [-1,1]:
		var start := Vector3(rack.position.x,.79,middle.y+side*.33)
		kit.pipe(parent,start,start+Vector3.RIGHT*rack.size.x,.244,rusty)
		for i in 4:
			var at := start+Vector3.RIGHT*(.50+i*2.4)
			kit.pipe(parent,at-Vector3.RIGHT*.048,at+Vector3.RIGHT*.048,.278,steel)
	for x: float in [middle.x-3.24,middle.x,middle.x+3.24]:
		fittings.fit(parent,"Prop_PipeHolder",Vector3(x,.29,middle.y),Vector3(.39,.58,rack.size.y))
	var cage := PLAN.CARGO_CAGE
	var a := cage.position
	var b := cage.end
	mesh_panel(parent,a,Vector2(b.x,a.y))
	mesh_panel(parent,Vector2(b.x,a.y),b)
	mesh_panel(parent,Vector2(a.x,b.y),a)
	fittings.packed_pallet(parent,Vector3(a.x+1.18,0,a.y+1.58),Vector3(1.71,1.14,1.26))
	var skid := Vector3(a.x+3.56,0,a.y+1.53)
	fittings.pallet_base(parent,skid,Vector2(1.67,1.14))
	for side in [-1,1]:
		fittings.barrel(parent,skid+Vector3(side*.393,.72,0),1.10,.68,true,Color("778c8a"),true)
	fittings.packed_pallet(parent,Vector3(a.x+5.70,0,a.y+1.58),Vector3(1.32,.69,1.10))
	for p: Vector2 in [Vector2(43.70,36.69),Vector2(20.77,30.63),Vector2(36.78,30.62)]:
		kit.cylinder(parent,"ImpactBollard",.094,.78,Vector3(p.x,.39,p.y),rusty)
		kit.cylinder(parent,"ReflectiveBand",.097,.21,Vector3(p.x,.59,p.y),plaster)
	for x: float in [38.78,42.05,45.53]:
		var light_at := Vector3(x,1.41,a.y+.064)
		kit.box(parent,"CageLightHousing",Vector3(.125,1.62,.15),light_at,dark)
		kit.box(parent,"CageLightTube",Vector3(.066,1.48,.06),light_at+Vector3.BACK*.090,fittings.lamp)
	_build_shipment_lane(parent)
	for p: Vector2 in [Vector2(16.5,16.4),Vector2(18.2,16.8)]:
		fittings.packed_pallet(parent,Vector3(p.x,0,p.y),Vector3(1.47,1.20,1.17))

func _build_shipment_lane(parent: Node3D) -> void:
	var lane := Node3D.new()
	lane.name = "OutboundShipmentLane"
	parent.add_child(lane)
	var center := (PLAN.SHIPMENT_WEST+PLAN.SHIPMENT_EAST)*.5
	var width := PLAN.SHIPMENT_EAST-PLAN.SHIPMENT_WEST+.38
	for z: float in PLAN.SHIPMENT_FRAMES:
		for x: float in [PLAN.SHIPMENT_WEST,PLAN.SHIPMENT_EAST]:
			fittings.fit(lane,"Column_Simple",Vector3(x,1.72,z),Vector3(.28,3.44,.31))
			kit.box(lane,"AnchorBase",Vector3(.43,.16,.47),Vector3(x,.08,z),steel)
		kit.box(lane,"CrossBeamWeb",Vector3(width,.27,.09),Vector3(center,3.46,z),steel)
		for h: float in [3.30,3.62]:
			kit.box(lane,"CrossBeamFlange",Vector3(width,.055,.27),Vector3(center,h,z),dark)
		var lamp := Vector3(center,3.16,z+.25)
		fittings.fit(lane,"Prop_Light_Wide",lamp,Vector3(3.4,.14,.28))
		kit.box(lane,"SuspendedStrip",Vector3(3.19,.07,.12),lamp+Vector3(0,-.045,.13),fittings.lamp)
		var vertical := Vector3(PLAN.SHIPMENT_EAST-.13,1.63,z+.14)
		kit.box(lane,"InspectionLight",Vector3(.09,1.89,.095),vertical,fittings.lamp)
	var wire := PLAN.SHIPMENT_FENCE
	mesh_panel(lane,Vector2(wire.get_center().x,wire.position.y),Vector2(wire.get_center().x,wire.end.y))
	for rail: Rect2 in PLAN.SHIPMENT_RAILS: _guardrail(lane,rail,0.,yellow)
	kit.cutout.register_tree(lane)

func mesh_panel(parent: Node3D, from: Vector2, to: Vector2, bottom := .13, height := 1.93, pitch := .30) -> void:
	var run := from.distance_to(to)
	var frame := Node3D.new()
	frame.name = "ChainLinkPanel"
	parent.add_child(frame)
	frame.position = Vector3(from.x,bottom,from.y)
	frame.rotation.y = -atan2(to.y-from.y,to.x-from.x)
	var net := TRAINING.BoxBatch.new()
	for i in range(-ceili(height/pitch),ceili(run/pitch)+1):
		var start := i*pitch
		var left := maxf(0,start)
		var right := minf(run,start+height)
		if right<=left+.009: continue
		for sign_y in [-1,1]:
			var yl := left-start if sign_y==1 else height-(left-start)
			var yr := right-start if sign_y==1 else height-(right-start)
			net.box(Vector3((left+right)*.5,(yl+yr)*.5,0),Vector3((right-left)*sqrt(2.),.026,.027),
				Basis(Vector3.BACK,atan2(yr-yl,right-left)))
	var grid := MeshInstance3D.new()
	grid.name = "WovenWire"
	grid.mesh = net.build()
	grid.material_override = steel
	frame.add_child(grid)
	for y: float in [0.,height]:
		kit.box(frame,"FenceChannel",Vector3(run,.065,.07),Vector3(run*.5,y,0),steel)
	var spans := ceili(run/2.45)
	for i in spans+1:
		kit.box(frame,"FencePost",Vector3(.075,height+.15,.075),Vector3(run*i/spans,height*.48,0),steel)
	kit.cutout.register_tree(frame)
