extends RefCounted
## Cut-plane coping extends the existing walls into the outside void. The
## glass atrium, all walking decks and both passage mouths remain open.
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const BATCH := preload("res://scripts/testing/h06_chapter/warehouse_art.gd")
const EXTENT := 64.0
const THICKNESS := 0.08
const CLEARANCE := 0.10
const BACKGROUND_KEY := &"h06_background_before_topblack"

static func sync_background(art, initial:=false) -> void:
	if not art.world.get_meta(&"h06_gallery_topblack_enabled",true) or art.world.blockout!=art:return
	var env:Environment=art.world.get_node("Lighting/WorldEnvironment").environment
	if not art.world.has_meta(BACKGROUND_KEY):
		if not initial:return
		art.world.set_meta(BACKGROUND_KEY,env.background_color)
	# Only the clear colour changes. Room illumination and real wall shadows
	# retain their existing values, and other chapter districts restore theirs.
	# The west-wing exit has an open sightline between its deck and black shroud.
	env.background_color=Color.BLACK if art.visit in [PLAN.Visit.GALLERY,PLAN.Visit.WEST,PLAN.Visit.EMPTY_HANGAR] else art.world.get_meta(BACKGROUND_KEY)

static func protected_floors(visit:int) -> Array[Rect2]:
	# The lower exhibit is visible through the upper glass on the first visit.
	var floors:Array[Rect2]=[PLAN.LOWER.hangar.grow(CLEARANCE)]
	for lower:bool in [true,false]:
		for area:Rect2 in PLAN.visit_areas(visit,lower).values():floors.append(area.grow(CLEARANCE))
	if visit==PLAN.Visit.GALLERY:
		floors.append(PLAN.UPPER.west_threshold.grow(CLEARANCE))
	else:
		floors.append(Rect2(-1.25,13.5,3.5,2.0).grow(CLEARANCE))
	return floors

static func _subtract(rect:Rect2, keep:Rect2) -> Array[Rect2]:
	var hit:=rect.intersection(keep)
	if not hit.has_area():return [rect]
	var pieces:Array[Rect2]=[]
	for part:Rect2 in [Rect2(rect.position,Vector2(rect.size.x,hit.position.y-rect.position.y)),
		Rect2(rect.position.x,hit.end.y,rect.size.x,rect.end.y-hit.end.y),
		Rect2(rect.position.x,hit.position.y,hit.position.x-rect.position.x,hit.size.y),
		Rect2(hit.end.x,hit.position.y,rect.end.x-hit.end.x,hit.size.y)]:
		if part.size.x>0.001 and part.size.y>0.001:pieces.append(part)
	return pieces

static func build(art) -> Node3D:
	if art.visit not in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]:return null
	var root:=Node3D.new()
	root.name="GalleryTopBlack"
	art.wall_root.add_child(root)
	var floors:=protected_floors(art.visit)
	var mouth: Rect2 = PLAN.LOWER.secret_mouth
	# The camera sees the low access corridor through the higher facade from the south.
	var facade_x := PLAN.SERVICE_FACADE_X
	var access_sightline := Rect2(facade_x,mouth.position.y-.40,mouth.end.x-facade_x,mouth.size.y+2.0)
	var south_start: float = PLAN.LOWER.bay_apron.position.x if art.visit==PLAN.Visit.EMPTY_HANGAR else -EXTENT
	# Tops match the real wall crowns: 3.04+2.45m monitoring walls,
	# 5.14m east facade, 2.45m ground shell, and 0.65m front cutaway.
	var bands:Array[Array]=[
		["EastFacade",Rect2(facade_x,-9.60,EXTENT-facade_x,14.05),5.14,false],
		["EastEntry",Rect2(8.60,4.45,EXTENT-8.60,5.15),1.93,false],
		["SouthCutaway",Rect2(south_start,9.60,EXTENT-south_start,EXTENT-9.60),0.65,false],
		["PlantNorth",Rect2(11.40,-9.60,11.70,3.0),4.49,true],
		["PlantEast",Rect2(23.10,-6.60,EXTENT-23.10,16.20),4.49,true]]
	if art.visit==PLAN.Visit.GALLERY:
		bands.append_array([
			["GroundWest",Rect2(-EXTENT,-9.60,EXTENT-10.90,19.20),2.45,false],
			["MonitoringNorth",Rect2(-EXTENT,-EXTENT,EXTENT*2.0,EXTENT-22.60),5.49,false],
			["MonitoringWest",Rect2(-EXTENT,-22.60,EXTENT-10.60,12.20),5.49,false],
			["MonitoringEast",Rect2(8.60,-22.60,EXTENT-8.60,13.00),5.49,false],
			["MonitoringFront",Rect2(-10.60,-10.40,19.68,0.80),3.69,false]])
	else:
		bands.append(["ReturnNorth",Rect2(-EXTENT,-EXTENT,EXTENT*2.0,EXTENT-9.60),5.96,false])
	var east_facade: Rect2 = bands[0][1]
	bands.append(["ServiceApproachCover",east_facade.intersection(access_sightline),5.14,false])
	for band:Array in bands:
		var fragments:Array[Rect2]=[band[1]]
		if band[0]=="EastFacade": fragments=_subtract(band[1],access_sightline)
		for floor:Rect2 in floors:
			var remaining:Array[Rect2]=[]
			for piece:Rect2 in fragments:remaining.append_array(_subtract(piece,floor))
			fragments=remaining
		if fragments.is_empty():continue
		var batch:=BATCH.MeshBuilder.new()
		var top:float=band[2]
		for rect:Rect2 in fragments:
			var c:=rect.get_center()
			batch.box(art.cutout.top_black,Vector3(c.x,top-THICKNESS*.5,c.y),Vector3(rect.size.x,THICKNESS,rect.size.y))
		var cap:=MeshInstance3D.new()
		cap.name=band[0]
		cap.mesh=batch.bake()
		# Existing textured walls still own real shadows. Exterior coping is a
		# presentation cut plane and must not change the room's lighting.
		cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap.set_meta(&"topblack_fragments",fragments)
		cap.set_meta(&"topblack_height",top)
		root.add_child(cap)
		# The combined bounds include the carved-out doors. Use actual triangles
		# so those holes never cause a false Occlusion Cutout trigger.
		art.cutout.register_mesh(cap,false,true)
		if band[3]:art._conceal_secret(cap)
		if band[0]=="ServiceApproachCover": art.secret_approach_roof=cap
	# The real door lintel is the only remaining break in the north facade crown.
	var lintel:MeshInstance3D=art.m.box(root,"Door206Crown",Vector3(2.0,0.02,0.66),Vector3(-6.05,5.95,-9.25),art.cutout.top_black)
	lintel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.cutout.register_mesh(lintel)
	return root

static func build_secret_cover(art) -> MeshInstance3D:
	var room: Rect2 = PLAN.LOWER.secret
	var center := room.get_center()
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	# This roof conceals the whole room, so actor cutout slots must leave it intact.
	var cover: MeshInstance3D = art.m.box(art.wall_root,"PlantRoomTopBlack",Vector3(room.size.x,.04,room.size.y),
		Vector3(center.x,4.50,center.y),black)
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cover
