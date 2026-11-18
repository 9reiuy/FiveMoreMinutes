extends "res://scripts/testing/h06_chapter/h06_gallery_art.gd"

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const SERVICE_ART := preload("res://scripts/testing/h06_chapter/service_and_loading_art.gd")
const SECURITY_ROOM := preload("res://scripts/testing/h06_chapter/security_room.gd")
const WINDOW := preload("res://scripts/testing/h06_chapter/observation_window.gd")
const HANGAR_CREW := preload("res://scripts/testing/h06_chapter/hangar_crew.gd")
const EVACUATION_SCENE := preload("res://scripts/testing/h06_chapter/evacuation_scene.gd")
const CRAWLER_CARGO := preload("res://scripts/testing/h06_chapter/crawler_cargo.gd")
const MONITORING_SCIENTIST := preload("res://scripts/testing/h06_chapter/security_scientist_event.gd")
const GALLERY_TOP_BLACK := preload("res://scripts/testing/h06_chapter/gallery_top_black.gd")
const TRANSIT := preload("res://scripts/testing/transit_concourse_area.gd")
const TRANSIT_FIXTURES := preload("res://scripts/testing/transit_concourse_fixtures.gd")
const MINI_FORKLIFT := preload("res://scripts/dream/props/mini_forklift_3d.gd")
const FORKLIFT_DRIVE := preload("res://scripts/dream/props/drivable_forklift.gd")
const WAREHOUSE := preload("res://scripts/testing/h06_chapter/warehouse_art.gd")
const FREIGHT := preload("res://scripts/testing/h06_chapter/freight_art.gd")
const LOGISTICS_HUB := preload("res://scripts/testing/h06_chapter/logistics_hub_art.gd")
const INCLINED_LIFT := preload("res://scripts/testing/h06_chapter/inclined_lift.gd")
const PASSAGE_SHADE := preload("res://scripts/testing/h06_chapter/passage_shade.gdshader")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const HANGAR_AMBIENT := .068
const HANGAR_KEY := .11
const HANGAR_AMBIENT_COLOUR := Color("8ea4b0")
var visit: PLAN.Visit
var region: PLAN.Region
var physics_root := Node2D.new()
var lights_root := Node3D.new()
var build_steps: Array[Callable] = []
var live := false
var windows := {}
var lamps := {}
var footprints: Node3D
var freight_ramp: MeshInstance3D
var crawler_floor: Node3D
var crawler_slabs := {}
var upper_bodies: Array[StaticBody2D] = []
var lower_bodies: Array[StaticBody2D] = []
var gates := {}
var closed := {}
var freight_leaf: MeshInstance3D
var freight_stop: StaticBody2D
var rear_leaf: MeshInstance3D
var half_shutter: MeshInstance3D
var hoist_bridge: MeshInstance3D
var inclined_lift: INCLINED_LIFT
var route_arrows: Mesh
var white := M.metal(Color("d2d0c5"),.84)
var charcoal := M.metal(Color("444845"),.83)
var amber := M.metal(Color("e0bd36"),.82)
var mint := M.metal(Color("94b7b3"),.82)
var fittings: FITTINGS
var security_wall: ShaderMaterial
var security_entry_wall: ShaderMaterial
var service_art: SERVICE_ART
var fixture_barriers: Array[Rect2] = []
var staff_fixtures: TRANSIT_FIXTURES
var hangar_service_diffusers: Array[MeshInstance3D] = []
var legs: Array = []
var stair_cover: Array[MeshInstance3D] = []
var under_cover := false
var service_model: Node3D
var model_cycle: Tween
var model_legs: Array = []
var contact_lamps: Array[MeshInstance3D] = []
var secret_visuals: Array[Node3D] = []
var secret_visible := false
var secret_roof: MeshInstance3D
var secret_approach_roof: MeshInstance3D
var hatch_leaf: Node3D
var _hatch_open := false
var hatch_motion: Tween
var threshold_shutter: Node3D
var threshold_open := 0.0
var west_entry_closed := false
var forklift: FORKLIFT_DRIVE
var warehouse_floor: ShaderMaterial
var warehouse_wall: ShaderMaterial
var freight_floor: ShaderMaterial
var freight_wall: ShaderMaterial
var lounge_wall: ShaderMaterial
var unstable_plates: Array[Dictionary] = []
var freight_turbines: Array[Node3D] = []
var freight_flicker_lights: Array[Dictionary] = []
var freight_collapse_bays: Array[Dictionary] = []
var freight_clutter_entries: Array[Dictionary] = []
var freight_searchlight: Dictionary = {}
var freight_breakables: Array[Dictionary] = []
var freight_deck_drops: Array[Dictionary] = []
var freight_fractures: Array[Dictionary] = []
var freight_chasm_drops: Array[Dictionary] = []
var freight_debris: Array[Dictionary] = []
var freight_boss_beam: MeshInstance3D
var west_shutters := {}
var west_shutter_bodies := {}
var west_shutter_tweens := {}
var hangar_crew: Node3D
var evacuation: EVACUATION_SCENE
var arena_cargo: CRAWLER_CARGO
var monitoring_scientist:Node3D
var service_entrance_shade: ShaderMaterial
var service_entrance_surfaces: Dictionary[MeshInstance3D, Material] = {}
var service_room_view := false
var staged_warehouse_squads: Dictionary = {}

func plan_region(id: PLAN.Visit, gate_state: Dictionary) -> void:
	visit = id
	region = PLAN.REGION_FOR_VISIT[id]
	closed = gate_state
	fittings = FITTINGS.new(m)
	if id==PLAN.Visit.GALLERY:
		security_wall = _make_security_wall(Vector4(-10.58,-9.45,7.15,8.60),Vector4(-26.0,-25.0,-11.95,-10.35),0.08,0.96)
		security_entry_wall = _make_security_wall(Vector4.ZERO,Vector4(-10.50,-8.65,1000.0,1001.0),0.08,0.88)
	elif id==PLAN.Visit.WEST:
		warehouse_floor = _make_warehouse_deck()
		warehouse_wall = _make_warehouse_wall()
	elif id==PLAN.Visit.FREIGHT:
		freight_floor = FREIGHT.make_grate_material()
		freight_wall = _make_freight_wall()
	elif id==PLAN.Visit.STAFF:
		lounge_wall = _make_lounge_wall()
	if id in [PLAN.Visit.GALLERY,PLAN.Visit.WEST,PLAN.Visit.EMPTY_HANGAR,PLAN.Visit.STAFF]:
		service_art = SERVICE_ART.new(fittings)
	floor_root.name = "ChapterFloor_1_%d" % (region+1)
	wall_root.name = "ChapterWalls_1_%d" % (region+1)
	lights_root.name = "ChapterLights_1_%d" % (region+1)
	physics_root.name = "ChapterCollision_1_%d" % (region+1)
	world.ceiling_light_root.add_child(lights_root)
	world.collision_root.add_child(physics_root)
	set_live(false)
	if id == PLAN.Visit.ARENA:
		inclined_lift = INCLINED_LIFT.new()
		floor_root.add_child(inclined_lift)
		if world.get_meta(&"h06_cargo_enabled",true):
			arena_cargo = CRAWLER_CARGO.new()
			floor_root.add_child(arena_cargo)
			for i in CRAWLER_CARGO.FOOTPRINTS.size(): build_steps.append(arena_cargo.prepare_slot.bind(self,i))
	if id in [PLAN.Visit.GALLERY,PLAN.Visit.WEST,PLAN.Visit.EMPTY_HANGAR,PLAN.Visit.FREIGHT,PLAN.Visit.STAFF]:
		build_steps.append(m.prepare_window_finishes)
	if id in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]:
		build_steps.append_array([m.prepare_atrium_surfaces,m.prepare_atrium_finishes,m.prepare_atrium_weathering])
		build_steps.append_array([_build_1f_hangar_platform_and_piers,_build_endfield_hangar_hardware_and_h06,
			_build_suspended_corridors_and_stairs,_build_corridor_glass_balustrades.bind(false),_build_right_walls_and_fake_doors,
			_build_endfield_signage,_build_weathering_details,_build_atrium_lighting.bind(lights_root)])
	elif id==PLAN.Visit.WEST:
		build_steps.append_array([m.prepare_atrium_finishes,m.prepare_atrium_weathering])
	elif id==PLAN.Visit.FREIGHT:
		build_steps.append_array([m.prepare_atrium_finishes,m.prepare_atrium_weathering,ensure_chase_crawler])
	elif id==PLAN.Visit.STAFF:
		build_steps.append_array([m.prepare_atrium_finishes,m.prepare_atrium_weathering])
	build_steps.append_array([_build_region_shell,_build_gallery_top_black,_build_region_props,_build_region_features])
	if visit in [PLAN.Visit.STAFF,PLAN.Visit.ARENA] and world.get_meta(&"h06_evacuation_enabled",true):
		build_steps.append(_prepare_evacuation)
	build_steps.append_array([_build_region_lights,_shade_passages])

func _prepare_evacuation() -> void:
	evacuation = EVACUATION_SCENE.new()
	floor_root.add_child(evacuation)
	evacuation.prepare(self,visit==PLAN.Visit.ARENA)
	var steps: Array[Callable] = []
	for i in EVACUATION_SCENE.PORTRAITS.size():
		steps.append(evacuation.prepare_actor.bind(i))
	_prepend_steps(steps)

func _build_gallery_top_black() -> void:
	if region==PLAN.Region.GALLERY and world.get_meta(&"h06_gallery_topblack_enabled",true):
		GALLERY_TOP_BLACK.build(self)
		secret_roof = GALLERY_TOP_BLACK.build_secret_cover(self)

func prepare_step() -> void:
	if not build_steps.is_empty():
		var step: Callable = build_steps.pop_front()
		var started:=Time.get_ticks_usec() if preparation_observer.is_valid() else 0
		step.call()
		if started>0:preparation_observer.call({"label":"build/"+String(step.get_method()),"ms":(Time.get_ticks_usec()-started)*0.001,"visit":int(visit),"remaining":build_steps.size(),"arguments":str(step.get_bound_arguments())})

var preparation_observer:Callable

func prepare_budget(usec: int) -> void:
	var started:=Time.get_ticks_usec()
	while not build_steps.is_empty():
		prepare_step()
		if Time.get_ticks_usec()-started>=usec:break

func _prepend_steps(steps: Array[Callable]) -> void:
	for i in range(steps.size()-1,-1,-1):build_steps.push_front(steps[i])

func configure_environment() -> void:
	super.configure_environment()
	var environment := world.get_node("Lighting/WorldEnvironment") as WorldEnvironment
	environment.environment.ambient_light_color = HANGAR_AMBIENT_COLOUR
	environment.environment.ambient_light_energy = HANGAR_AMBIENT
	var key := world.get_node("Lighting/KeyLight") as DirectionalLight3D
	key.light_color = Color("adc0cc")
	key.light_energy = HANGAR_KEY
	GALLERY_TOP_BLACK.sync_background(self,true)

func _build_1f_hangar_platform_and_piers() -> void:
	# Both hangar visits keep the dark black metallic hangar & corridor finish matching the standalone 1-1 bay.
	m.base_concrete.set_shader_parameter("tint_colour",Color("24292e"))
	m.base_concrete.set_shader_parameter("metallic_amount",.18)
	m.base_concrete.set_shader_parameter("wetness",.52)
	m.base_concrete.set_shader_parameter("wear_amount",.68)
	m.corridor_floor.set_shader_parameter("tint_colour",Color("2b3137"))
	m.corridor_floor.set_shader_parameter("metallic_amount",.22)
	m.corridor_floor.set_shader_parameter("wetness",.46)
	m.corridor_floor.set_shader_parameter("wear_amount",.48)
	m.wall_composite.set_shader_parameter("tint_colour",Color("8d9392"))
	m.wall_composite.set_shader_parameter("metallic_amount",.08)
	m.pit_plinth_floor.set_shader_parameter("tint_colour",Color("292f35"))
	m.pit_plinth_floor.set_shader_parameter("metallic_amount",.18)
	m.pit_plinth_floor.set_shader_parameter("wetness",.56)
	super._build_1f_hangar_platform_and_piers()

func _build_endfield_hangar_hardware_and_h06(_vehicle_exit := true) -> void:
	super._build_endfield_hangar_hardware_and_h06(true)
	m.pit_grate.set_shader_parameter("tint_colour",Color("1e242a"))
	m.pit_grate.set_shader_parameter("metallic_amount",.28)
	m.pit_grate.set_shader_parameter("wetness",.52)
	hangar_service_diffusers = fittings.service_canopy(wall_root,Vector3(-9.0,3.95,.60),5.45,1.11,0.)
	if visit==PLAN.Visit.GALLERY:
		for key: String in ["bay_apron","search"]:
			slab(key,PLAN.LOWER[key],0,.22,m.base_concrete)
	rear_leaf = slab("RearCargoDoor",PLAN.REAR_GATE,4.40,4.40,fittings.shutter)
	cutout.register_tree(rear_leaf)
	_fixture_body("FreightShutter",PLAN.REAR_GATE)

func _build_atrium_lighting(ceiling_root: Node3D) -> void:
	super._build_atrium_lighting(ceiling_root)
	var sources: Array[Dictionary] = []
	for diffuser in hangar_service_diffusers:
		# Keep the existing cutout material on the canopy geometry.
		sources.append({"mesh": weakref(diffuser), "bounds": diffuser.get_aabb(), "material": fittings.lamp})
	if not sources.is_empty():
		OPTICS.mark_sources(hangar_service_diffusers[0].get_parent_node_3d(), _conduit_pool, sources, 0.0)

func _build_west_conduits() -> void:
	fittings.pipe_bank(wall_root,Vector3(-9.35,0,1.4),5.4,1.15,1.68,90.)

func _build_lower_hangar_rails() -> void:
	_glass_rail_span(Vector3(2.40,0,8.95),Vector3(3.25,0,8.95),.78)
	_glass_rail_span(Vector3(-10.45,0,-3.5),Vector3(-10.45,0,3.0),.85)

func _build_east_service_wall(title: String,x: float,start: float,end: float,depth: float,h: float,faces: int,mat: Material,register: bool) -> void:
	var mouth: Rect2 = PLAN.LOWER.secret_mouth
	var is_outer_shell := title=="EastCorridorOuterShell"
	if is_outer_shell:
		# Start the outer skin at the service mouth. The inner east panels end
		# before this line, including their shared-height tops and end faces.
		var outside := x+depth*.5
		depth = outside-mouth.position.x
		x = outside-depth*.5
	for span: Vector2 in [Vector2(start,mouth.position.y),Vector2(mouth.end.y,end)]:
		var span_faces := faces
		if is_outer_shell and span.y==mouth.position.y: span_faces |= 8
		super._build_east_service_wall(title,x,span.x,span.y,depth,h,span_faces,mat,register)
	if h>1.68:
		m.build_top_black_wall(wall_root,title+"Lintel",Vector3(x,(h+1.68)*.5,mouth.get_center().y),
			Vector3(depth,h-1.68,mouth.size.y),faces,mat,register)

func _build_crawler(at: Vector3) -> void:
	if visit==PLAN.Visit.EMPTY_HANGAR: return
	super._build_crawler(at)
	if not is_instance_valid(mech): return
	legs = _leg_rig(mech)

func _leg_rig(model: Node3D) -> Array:
	var rig := []
	for side: String in ["L","R"]:
		for index in 3:
			var prefix := "Leg_%s_%s_" % [side,["Front","Mid","Rear"][index]]
			var hip := model.find_child(prefix+"HipPitch",true,false) as Node3D
			var root := model.find_child(prefix+"Root",true,false) as Node3D
			if is_instance_valid(hip) and is_instance_valid(root):
				rig.append([root,root.quaternion,hip,hip.quaternion,(index+(1 if side=="R" else 0))%2,-1 if side=="R" else 1])
	return rig

func ensure_chase_crawler() -> void:
	if is_instance_valid(mech): return
	var spawn: Vector2 = PLAN.CHASE_PATH[0]
	_build_crawler(Vector3(spawn.x,0,spawn.y))
	mech.hide()

func take_crawler(previous) -> void:
	mech = previous.mech
	mech_anim = previous.mech_anim
	legs = previous.legs
	mech.reparent(wall_root,true)
	if previous.visit==PLAN.Visit.FREIGHT:
		crawler_floor = Node3D.new()
		crawler_floor.name = "DepartingCrawlerDeck"
		floor_root.add_child(crawler_floor)
		for bay: Dictionary in previous.freight_collapse_bays:
			if String(bay.state) == "intact" and is_instance_valid(bay.get("node")):
				var bay_node := bay.node as Node3D
				bay_node.reparent(crawler_floor,true)
				crawler_slabs[bay_node] = bay.rect
	elif is_instance_valid(previous.crawler_floor):
		crawler_floor = previous.crawler_floor
		crawler_slabs = previous.crawler_slabs
		crawler_floor.reparent(floor_root,true)
		previous.crawler_floor = null
		previous.crawler_slabs = {}
	update_crawler_deck()

func update_crawler_deck() -> void:
	if not is_instance_valid(crawler_floor): return
	var feet := Vector2(mech.position.x,mech.position.z)
	if feet.y<PLAN.MACHINE_RAMP.end.y-PLAN.CRAWLER_RADIUS:
		crawler_floor.queue_free()
		crawler_floor = null
		crawler_slabs.clear()
		return
	# Only the floor still beneath the legs survives the personnel fire door closing.
	for deck: Node3D in crawler_slabs:
		var slab_rect: Rect2 = crawler_slabs[deck]
		deck.visible = visit!=PLAN.Visit.STAFF and feet.distance_to(feet.clamp(slab_rect.position,slab_rect.end))<=PLAN.CRAWLER_RADIUS+.35

func _build_region_shell() -> void:
	var built_freight_bays := false
	if region==PLAN.Region.GALLERY: service_art.prepare_access()
	for upper: bool in [true,false]:
		var areas := PLAN.visit_areas(visit,not upper)
		for key: String in areas:
			if key in ["spur","east","north","hangar","understairs","monitor_threshold","west_threshold"]: continue
			if key in ["arena","boarding_bridge"]: continue
			if not upper and key=="landing": continue
			var r: Rect2 = areas[key]
			if key == "stair":
				var step_mat: Material = warehouse_floor if visit==PLAN.Visit.WEST and warehouse_floor!=null else white
				var nosing_mat: Material = m.endfield_yellow if visit==PLAN.Visit.WEST and m.endfield_yellow!=null else amber
				for i in 16:
					var step := Rect2(r.position+Vector2(0,i*r.size.y/16.0),Vector2(r.size.x,r.size.y/16.0))
					var step_top := 3.04*(15-i)/15.0
					slab("StaffStep",step,step_top,.21,step_mat)
					if visit==PLAN.Visit.WEST:
						slab("StaffStepNosing",Rect2(step.position.x,step.end.y-.07,step.size.x,.07),step_top+.008,.025,nosing_mat)
			else:
				var top := PLAN.upper_height(r.get_center()) if upper else 0.0
				if key == "pit": top = -1.0
				if visit==PLAN.Visit.FREIGHT and not upper and freight_floor!=null:
					if key=="pit": continue
					if not built_freight_bays:
						built_freight_bays = true
						freight_collapse_bays = FREIGHT.build_freight_deck_bays(floor_root,freight_floor)
					continue
				var finish := FITTINGS.Deck.LAB
				if visit==PLAN.Visit.STAFF: finish = FITTINGS.Deck.STAFF
				if visit==PLAN.Visit.FREIGHT: finish = FITTINGS.Deck.FREIGHT
				if key=="pit": finish = FITTINGS.Deck.GRAPHITE
				var material := fittings.floor_material(finish)
				if visit==PLAN.Visit.WEST and warehouse_floor!=null and not key in ["observation","206","secret"]:
					material = warehouse_floor
				elif visit==PLAN.Visit.FREIGHT and freight_floor!=null:
					material = freight_floor
				elif key=="observation":
					material = _make_security_deck(Vector2(2.40,2.40),Color("74818a"),0.92,Vector4(-10.58,-9.45,7.15,8.60),Vector4(-26.0,-25.0,-11.95,-10.35),0.08)
				elif key=="206" and visit==PLAN.Visit.GALLERY:
					material = _make_security_deck(Vector2(2.0,2.0),Color("7b8891"),0.84,Vector4.ZERO,Vector4(-10.50,-8.65,1000.0,1001.0),0.08)
				if key=="secret": material = service_art.floor_tile
				elif key=="secret_mouth": material = service_art.access_floor
				elif key in ["duty","canteen","lockers","clinic","arena_link","armory"]: material = LOGISTICS_HUB.floor_material()
				var deck := slab(key,r,top,.22,material)
				if key in ["secret","secret_mouth"]: _conceal_secret(deck)
				if FITTINGS.SERVICE_GRATES.has(key) and visit!=PLAN.Visit.STAFF: fittings.set_grate(deck,FITTINGS.SERVICE_GRATES[key])
		for e: Array in PLAN.exterior_edges(areas):
			var wall_start := wall_root.get_child_count()
			for segment: Array in PLAN.open_edge(e,visit,not upper): _outline(segment,upper)
			if e[0] in ["secret","secret_mouth"]:
				for i in range(wall_start,wall_root.get_child_count()): _conceal_secret(wall_root.get_child(i))
	if visit in [PLAN.Visit.GALLERY,PLAN.Visit.WEST]: _build_west_threshold()
	if visit>0:
		var gate: Dictionary = PLAN.PASSAGES[visit-1]
		var across: Vector2 = gate.forward.orthogonal().abs()
		var size := across*(float(gate.width)+.35) + (gate.forward as Vector2).abs()*.16
		var entry_rect := Rect2(gate.at-size*.5,size)
		add_body("OneWayEntrance",entry_rect,visit==PLAN.Visit.WEST)
		if visit!=PLAN.Visit.WEST: fixture_barriers.append(entry_rect)
	if visit<PLAN.Visit.ARENA:
		# Guide the player's collision circle across the short dark lip before the far walls become active.
		var exit: Dictionary = PLAN.PASSAGES[visit]
		var forward: Vector2 = exit.forward
		var across := forward.orthogonal()
		var size := forward.abs()*.90+across.abs()*.16
		for side in [-1,1]:
			var center: Vector2 = exit.at+forward*.45+across*(float(exit.width)*.5+.08)*side
			add_body("PassageGuide",Rect2(center-size*.5,size),visit==PLAN.Visit.GALLERY)

func _build_region_props() -> void:
	if not world.get_meta(&"h06_streaming_budget",true):
		for key: String in PLAN.PROPS: _build_region_prop(key)
		_build_forklift()
		return
	var steps:Array[Callable]=[]
	for key: String in PLAN.PROPS:
		if key=="forklift":continue
		var at:Vector2=(PLAN.PROPS[key][0] as Rect2).get_center()
		if PLAN.visit_contains(visit,at,false) or PLAN.visit_contains(visit,at,true):steps.append(_build_region_prop.bind(key))
	steps.append(_build_forklift)
	_prepend_steps(steps)

func _build_region_prop(key: String) -> void:
	if key == "forklift": return
	var r: Rect2 = PLAN.PROPS[key][0]
	var upper := PLAN.visit_contains(visit,r.get_center(),false)
	if not upper and not PLAN.visit_contains(visit,r.get_center(),true): return
	var floor_y := 3.04 if upper else 0.0
	var h: float = PLAN.PROPS[key][1]
	if key in ["pump_a","pump_b","bench","trailer","trailer_long","dispatch_vessels"]:
		var along_z := r.size.y>r.size.x
		var center := r.get_center()
		fittings.pipe_bank(floor_root,Vector3(center.x,floor_y,center.y),maxf(r.size.x,r.size.y),minf(r.size.x,r.size.y),h,90. if along_z else 0.,visit==PLAN.Visit.FREIGHT)
	elif key.begins_with("warehouse_rack_"):
		WAREHOUSE.build_giant_rack(floor_root,r,floor_y,h,hash(key),cutout)
	elif key.begins_with("warehouse_cargo_"):
		WAREHOUSE.build_cargo_stack(floor_root,r,floor_y,h,hash(key),cutout)
	elif key=="warehouse_silo":
		pass
	elif key in ["desk","records_desk","sample_table"]:
		var table_center := r.get_center()
		var base_mat: Material = m.steel_beam if visit==PLAN.Visit.WEST and m.steel_beam!=null else charcoal
		var top_mat: Material = (m.steel_rail if m.steel_rail!=null else fittings.graphite) if visit==PLAN.Visit.WEST else white
		var trim_mat: Material = m.endfield_yellow if m.endfield_yellow!=null else amber
		slab("BenchInset",r.grow(-.13),floor_y+h-.13,h-.13,base_mat)
		slab("WorkSurface",r,floor_y+h,.12,top_mat)
		if visit==PLAN.Visit.WEST:
			slab("WorkTrim",Rect2(r.position.x,r.end.y-.045,r.size.x,.045),floor_y+h+.005,.045,trim_mat)
		if key=="desk" or key=="records_desk":
			fittings.fit(floor_root,"Prop_Computer",Vector3(table_center.x-.52,floor_y+h+.27,table_center.y),Vector3(.53,.54,.33))
		elif key=="sample_table":
			fittings.barrel(floor_root,Vector3(table_center.x,floor_y+h+.20,table_center.y),1.37,.40)
	elif key.begins_with("archive_rack"):
		fittings.archive_shelf(floor_root,r,floor_y,h)
	elif key.begins_with("cage"):
		if visit==PLAN.Visit.FREIGHT:
			FREIGHT.build_freight_cage(floor_root,key,r,h,cutout)
		else:
			slab(key,r,floor_y+.14,.14,charcoal)
			for x: float in [r.position.x+.06,r.end.x-.06]:
				for z: float in [r.position.y+.06,r.end.y-.06]:
					M.box(floor_root,"CagePost",Vector3(.09,h,.09),Vector3(x,floor_y+h*.5,z),charcoal)
			slab("CageFrame",r,floor_y+h,.09,charcoal)
			var cage_center := r.get_center()
			fittings.packed_pallet(floor_root,Vector3(cage_center.x,floor_y+.14,cage_center.y),Vector3(r.size.x*.79,h*.64,r.size.y*.72))
	elif key.begins_with("pallets"):
		if visit==PLAN.Visit.FREIGHT:
			WAREHOUSE.build_cargo_stack(floor_root,r,floor_y,h,hash(key),cutout)
		else:
			var load_center := r.get_center()
			fittings.packed_pallet(floor_root,Vector3(load_center.x,floor_y,load_center.y),Vector3(r.size.x,h,r.size.y))
	elif key.begins_with("clinic_cot"):
		if visit==PLAN.Visit.STAFF:
			LOGISTICS_HUB.build_clinical_cot(self,floor_root,key,r,h)
		else:
			slab("CotBase",r,h-.12,h-.12,charcoal)
			slab("Mattress",r,h,.12,white)
			slab("Blanket",Rect2(r.position.x+.58,r.position.y+.05,r.size.x-.64,r.size.y-.10),h+.03,.04,mint)
			slab("Pillow",Rect2(r.position+Vector2(.10,.09),Vector2(.46,r.size.y-.18)),h+.08,.08,mint)
	else:
		slab(key,r,floor_y+h,h,charcoal)
	add_body(key,r,upper)

func _build_forklift() -> void:
	var state: Dictionary = world.get("forklift_restore_state")
	if state.is_empty():
		if visit != PLAN.Visit.WEST: return
	elif int(state.get("visit", -1)) != visit:
		return
	var at: Vector2 = state.get("position", PLAN.FORKLIFT_START)
	var height := float(state.get("height", PLAN.upper_height(at)))
	var model := MINI_FORKLIFT.new()
	model.position = Vector3(at.x, height, at.y)
	model.rotation.y = -float(state.get("heading", PLAN.FORKLIFT_HEADING))
	floor_root.add_child(model)
	cutout.register_tree(model,true)
	forklift = FORKLIFT_DRIVE.new()
	forklift.name = "DrivableForklift"
	forklift.configure(world, model, height)
	physics_root.add_child(forklift)
	forklift.restore_state(state)
	forklift.set_active(live)

func _build_freight() -> void:
	var fm := FREIGHT.materials()
	var built: Dictionary = FREIGHT.dress_freight_hall(floor_root,wall_root,fittings,cutout)
	unstable_plates.assign(built.unstable_plates)
	freight_turbines.assign(built.turbines)
	freight_clutter_entries.assign(built.clutter)
	freight_breakables.assign(built.breakables)
	freight_deck_drops.assign(built.deck_drops)
	freight_fractures.assign(built.fractures)
	freight_chasm_drops.assign(built.chasm_drops)
	freight_boss_beam = built.boss_beam
	freight_debris.clear()
	for i in PLAN.FREIGHT_CLUTTER.size():
		var cl_body := _dynamic_freight_body("FreightClutter_%d" % i, PLAN.FREIGHT_CLUTTER[i][1], true)
		if i < freight_clutter_entries.size():
			freight_clutter_entries[i]["body"] = cl_body
	for entry: Dictionary in freight_breakables:
		entry.body = _dynamic_freight_body("FreightBreakable_" + String(entry.id), entry.rect, true)
	for entry: Dictionary in freight_deck_drops:
		entry.body = _dynamic_freight_body("FreightDrop_" + String(entry.id), entry.rect, false)
	for entry: Dictionary in freight_fractures:
		entry.body = _dynamic_freight_body("FreightFracture_" + String(entry.id), entry.rect, false)
	for bay: Rect2 in PLAN.CROSS_DOCK_BAYS:
		slab("DockMark",Rect2(bay.position,Vector2(.07,bay.size.y)),.018,.014,fm.safety_yellow)
		slab("DockMark",Rect2(bay.end-Vector2(.07,bay.size.y),Vector2(.07,bay.size.y)),.018,.014,fm.safety_yellow)
		slab("DockMark",Rect2(bay.position+Vector2(0,bay.size.y-.07),Vector2(bay.size.x,.07)),.018,.014,fm.safety_yellow)
	for r: Rect2 in PLAN.PARTITIONS:
		_divider("Bulkhead",r,0,1.8,false,freight_wall if freight_wall!=null else fittings.wall)
	var low: Rect2 = PLAN.LOW_GATE
	var c := low.get_center()
	half_shutter = slab("HalfShutter",low,2.5,1.55,fittings.shutter)
	fittings.service_canopy(wall_root,Vector3(c.x,2.65,c.y),low.size.x+.2,.62,90.)
	slab("RollEdge",low,.99,.04,fm.safety_yellow)
	for x: float in [low.position.x,low.end.x-.10]:
		slab("ShutterGuide",Rect2(x,low.position.y-.05,.13,.67),2.55,2.55,fm.trench_steel)
	for z: float in [low.position.y-.14,low.end.y+.10]:
		slab("ShutterThreshold",Rect2(low.position.x,z,low.size.x,.09),.025,.025,fm.safety_yellow)
	add_body("RollOnly",low,false)
	var hg := PLAN.HEAVY_GATE
	freight_leaf = slab("FreightShutter",hg,4.40,4.40,fittings.shutter)
	freight_stop = add_body("Freight",hg,false)
	for hx: float in [hg.position.x-.18,hg.end.x+.18]:
		M.box(wall_root,"HeavyGateJamb",Vector3(.36,4.50,.68),Vector3(hx,2.25,hg.get_center().y),fm.trench_steel)
		M.box(wall_root,"HeavyGateTrim",Vector3(.38,.90,.72),Vector3(hx,.45,hg.get_center().y),fm.safety_yellow)
	M.box(wall_root,"HeavyGateLintel",Vector3(hg.size.x+.72,.32,.72),Vector3(hg.get_center().x,4.58,hg.get_center().y),fm.buttress_red)
	var trench: Rect2 = PLAN.LOWER.pit
	var plate := PLAN.TRENCH_BRIDGE
	add_body("Trench",Rect2(plate.end.x,trench.position.y,trench.end.x-plate.end.x,trench.size.y),false)
	for z: float in [trench.position.y-.14,trench.end.y]:
		slab("JumpLip",Rect2(trench.position.x,z,trench.size.x,.14),.024,.02,fm.safety_yellow)
	add_body("Roller",PLAN.ROLLER,false)
	add_body("TransferBelt",PLAN.BELT,false)
	rear_leaf = slab("RearCargoDoor",PLAN.REAR_GATE,4.40,4.40,fittings.shutter)
	# RearDock grated deck bay is built as part of freight_collapse_bays in _build_region_shell
	add_body("RearPersonnelLimit",PLAN.REAR_GATE,false)
	add_body("RampPersonnelLimit",Rect2(PLAN.MACHINE_RAMP.position.x,PLAN.MACHINE_RAMP.end.y-.1,PLAN.MACHINE_RAMP.size.x,.20),false)
	_build_freight_ramp()

func _divider(title: String, r: Rect2, floor_y: float, h: float, upper: bool, wall_mat: Material = null) -> void:
	var center := r.get_center()
	m.build_top_black_wall(floor_root,title,Vector3(center.x,floor_y+h*.5,center.y),
		Vector3(r.size.x,h,r.size.y),0,wall_mat if wall_mat!=null else fittings.wall)
	add_body(title,r,upper)

func _build_freight_ramp() -> void:
	var r := PLAN.MACHINE_RAMP
	var center := r.get_center()
	var ramp_mat: Material = _make_freight_deck() if visit==PLAN.Visit.FREIGHT else fittings.floor_material(FITTINGS.Deck.FREIGHT)
	freight_ramp = M.box(floor_root,"FreightRamp",Vector3(r.size.x,.26,Vector2(PLAN.HOIST_Y,r.size.y).length()),
		Vector3(center.x,PLAN.HOIST_Y*.5-.13,center.y),ramp_mat)
	freight_ramp.rotation.x = atan2(PLAN.HOIST_Y,r.size.y)
	fittings.set_grate(freight_ramp,Rect2(r.position.x+.56,r.position.y+.25,.90,r.size.y-.50))

func _build_hoist() -> void:
	var deck := slab("HoistDeck",PLAN.HOIST_DECK,PLAN.HOIST_Y,.25,fittings.floor_material(FITTINGS.Deck.FREIGHT))
	fittings.set_grate(deck,PLAN.HOIST_DECK.grow(-.30))
	var bridge := PLAN.HOIST_BRIDGE
	hoist_bridge = slab("HoistBridge",bridge,PLAN.HOIST_Y,.25,fittings.floor_material(FITTINGS.Deck.GRAPHITE))
	fittings.set_grate(hoist_bridge,bridge.grow(-.19))
	for z: float in [bridge.position.y+.07,bridge.end.y-.17]:
		var edge := slab("HoistEdge",Rect2(bridge.position.x,z,bridge.size.x,.10),PLAN.HOIST_Y+.025,.025,amber)
		edge.reparent(hoist_bridge,true)
	for z: float in [bridge.position.y+.15,bridge.end.y-.53]:
		slab("HoistSupport",Rect2(PLAN.HOIST_DECK.position.x+.04,z,.34,.34),6.75,6.75,charcoal)

func _build_region_features() -> void:
	if world.hangar_crew_enabled and visit in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]:
		hangar_crew = HANGAR_CREW.new()
		floor_root.add_child(hangar_crew)
		hangar_crew.build(self,visit==PLAN.Visit.EMPTY_HANGAR)
	for key: String in PLAN.GATES:
		if PLAN.GATE_VISIT[key]==visit: build_gate(key)
	for room: String in WINDOW.WINDOWS:
		if not room in PLAN.VISIT_ROOMS[visit]: continue
		var scene := WINDOW.new()
		floor_root.add_child(scene)
		scene.build(room,3.04 if PLAN.UPPER.has(room) else 0.0,self)
		windows[room] = scene
	match visit:
		PLAN.Visit.GALLERY:
			_build_secret()
			var room := SECURITY_ROOM.new()
			room.name = "SecurityAndRecords"
			floor_root.add_child(room)
			room.position.y = PLAN.upper_height(PLAN.UPPER.observation.get_center())
			room.furnish(fittings,service_art)
			monitoring_scientist=MONITORING_SCIENTIST.new()
			floor_root.add_child(monitoring_scientist)
			monitoring_scientist.build(self,room)
			for key: String in PLAN.WATCH_FIXTURES:
				add_body(key,PLAN.WATCH_FIXTURES[key],true)
		PLAN.Visit.WEST:
			_build_west_warehouse()
		PLAN.Visit.EMPTY_HANGAR:
			_console("cargo_access",PLAN.RELAY_CONSOLE,0)
			signal_used("cargo_access")
			for edge: String in PLAN.RETURN_AIR_WALLS:
				_fixture_body("ReturnHangarAirWall"+edge,PLAN.RETURN_AIR_WALLS[edge])
			_build_tracks()
			_build_secret()
		PLAN.Visit.FREIGHT:
			_build_freight()
		PLAN.Visit.STAFF:
			for screen: Rect2 in PLAN.STAFF_SCREENS:
				var is_ctrl_window := absf(screen.position.x - 22.5) < 0.05 and absf(screen.size.y - 4.10) < 0.05
				var div_h := 0.94 if is_ctrl_window else 2.44
				_divider("StaffPartition",screen,0,div_h,false,lounge_wall)
			LOGISTICS_HUB.build_hub(self)
			_console("clinic",PLAN.MEDICINE,0)
		PLAN.Visit.ARENA:
			inclined_lift.build(self)
	_build_arrows()

func _fixture_body(title: String, rect: Rect2) -> void:
	fixture_barriers.append(rect)
	add_body(title,rect,false)

func _build_secret() -> void:
	# Two treads and their nosings are the actual moving hatch. Leave the stringers at the sides.
	hatch_leaf = Node3D.new()
	hatch_leaf.name = "UnderStairHatch"
	hatch_leaf.position = Vector3(6.74,1.50,2.75)
	floor_root.add_child(hatch_leaf)
	for index in [0,1]:
		for kind in ["Step","Nosing"]:
			var piece := floor_root.get_node("EastCorridorStair_%s_%d" % [kind,index]) as MeshInstance3D
			var size := piece.get_aabb().size * piece.scale
			var start := piece.position.x-size.x*.5
			var end := piece.position.x+size.x*.5
			for span: Vector2 in [Vector2(start,5.36),Vector2(5.36,6.74),Vector2(6.74,end)]:
				var part := M.box(floor_root,kind,Vector3(span.y-span.x,size.y,size.z),
					Vector3((span.x+span.y)*.5,piece.position.y,piece.position.z),piece.get_active_material(0))
				if span.x==5.36: part.reparent(hatch_leaf,true)
			piece.free()
	var stringer := floor_root.get_node("EastCorridorStair_Stringer") as MeshInstance3D
	var beam := stringer.get_aabb().size * stringer.scale
	for x: float in [3.70,7.30]:
		var steel := M.box(floor_root,"StairSideStringer",Vector3(.20,beam.y,beam.z),
			Vector3(x,stringer.position.y,stringer.position.z),m.steel_beam)
		steel.rotation = stringer.rotation
	stringer.free()
	M.box(hatch_leaf,"RecessedPull",Vector3(.28,.018,.08),Vector3(-.93,.025,-.33),m.steel_mullion)
	for side in [-1,1]:
		var x: float = PLAN.LADDER_FOOT.x+side*.30
		M.pipe(floor_root,Vector3(x,.06,1.72),Vector3(x,1.45,2.15),.032,amber)
	for i in 5:
		var t := (i+.45)/5.
		M.box(floor_root,"LadderRung",Vector3(.59,.045,.055),Vector3(PLAN.LADDER_FOOT.x,.06+t*1.39,1.72+t*.43),m.steel_rail)
	var at := PLAN.MODEL_BENCH
	var table: Rect2 = PLAN.SERVICE_FIXTURES.PrototypeCart
	var prop_start := floor_root.get_child_count()
	var plant := Node3D.new()
	plant.name = "UnderStairPlantRoom"
	floor_root.add_child(plant)
	service_art.build_utility(plant)
	var y := PLAN.SERVICE_RISE
	for x in [-1,1]:
		for z in [-1,1]:
			m.box(plant,"TrolleyLeg",Vector3(.08,.61,.08),Vector3(at.x+x*.88,y+.33,at.y+z*.46),service_art.steel)
	slab("TrolleyShelf",table.grow(-.10),y+.21,.07,charcoal)
	slab("PrototypeTurntable",table,y+.67,.10,service_art.steel)
	for x in [-1,1]:
		for z in [-1,0,1]:
			var lamp := slab("TripodContact",Rect2(at+Vector2(x*.90-.04,z*.36-.045),Vector2(.08,.09)),y+.686,.018,charcoal)
			contact_lamps.append(lamp)
	for key: String in PLAN.SERVICE_FIXTURES: _fixture_body(key,PLAN.SERVICE_FIXTURES[key])
	for rail: Rect2 in PLAN.SERVICE_RAILS: _fixture_body("PlantDeckGuardrail",rail)
	for x: float in [PLAN.SERVICE_STEPS.position.x,PLAN.SERVICE_STEPS.end.x]:
		_fixture_body("StairCheek",Rect2(x-.045,PLAN.SERVICE_STEPS.position.y,.09,PLAN.SERVICE_STEPS.size.y-.15))
	for i in range(prop_start,floor_root.get_child_count()): _conceal_secret(floor_root.get_child(i))
	# Only cut overhead architecture near the hatch when the player really is underneath it.
	for root: Node3D in [floor_root,wall_root]:
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if hatch_leaf.is_ancestor_of(mesh) or (is_instance_valid(mech) and mech.is_ancestor_of(mesh)): continue
			if mesh==secret_roof or mesh.has_meta(&"topblack_fragments"): continue
			var bounds := mesh.global_transform*mesh.get_aabb()
			if bounds.position.y>.67 and bounds.intersects(AABB(Vector3(3.25,.70,-.5),Vector3(6.05,6.1,4.06))):
				if not secret_visuals.any(func(part: Node3D): return part==mesh or part.is_ancestor_of(mesh)): stair_cover.append(mesh)

func open_hatch(open: bool) -> void:
	if not is_instance_valid(hatch_leaf): return
	if open and not _hatch_open and hatch_leaf.is_visible_in_tree():
		SFX.play_world_sfx_3d(&"h06_hatch_open", hatch_leaf.global_position, 0.0, 22.0)
	_hatch_open = open
	if hatch_motion and hatch_motion.is_valid(): hatch_motion.kill()
	hatch_motion = hatch_leaf.create_tween()
	hatch_motion.tween_property(hatch_leaf,"rotation:z",-1.45 if open else 0.,.26)

func service_view(lower: bool,feet: Vector2) -> void:
	var reveal := lower and PLAN.behind_service_roof(feet)
	if reveal!=secret_visible:
		secret_visible=reveal
		for visual in secret_visuals: visual.visible=reveal
		if is_instance_valid(service_model): service_model.visible=reveal
		if is_instance_valid(secret_roof): secret_roof.visible=not reveal
		if is_instance_valid(secret_approach_roof): secret_approach_roof.visible=not reveal
		if is_instance_valid(hangar_crew) and hangar_crew.escape!=null:
			hangar_crew.escape.sync_room_visibility(reveal)
	var underneath := lower and Rect2(3.10,-.65,8.9,4.45).has_point(feet)
	if under_cover!=underneath:
		under_cover=underneath
		for mesh in stair_cover: mesh.visible = not underneath
	var inside: bool = lower and PLAN.LOWER.secret.has_point(feet)
	if service_room_view != inside:
		service_room_view = inside
		for mesh: MeshInstance3D in service_entrance_surfaces:
			mesh.material_overlay = service_entrance_shade if inside else service_entrance_surfaces[mesh]
	if reveal and feet.x>9.25 and not is_instance_valid(service_model):
		service_model=(load(H06_MODEL) as PackedScene).instantiate() as Node3D
		service_model.name="H06BenchPrototype"
		service_model.position=Vector3(PLAN.MODEL_BENCH.x,PLAN.SERVICE_RISE+.683,PLAN.MODEL_BENCH.y)
		service_model.scale=Vector3.ONE*.245
		service_model.rotation.y=.55
		floor_root.add_child(service_model)
		model_legs=_leg_rig(service_model)

func _conceal_secret(node: Node3D) -> void:
	secret_visuals.append(node)
	node.hide()

func run_service_model() -> void:
	if not is_instance_valid(service_model) or (model_cycle and model_cycle.is_running()): return
	model_cycle = service_model.create_tween().set_parallel()
	model_cycle.tween_property(service_model,"rotation:y",service_model.rotation.y+TAU,4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	model_cycle.tween_method(_prototype_stride,0.,1.,4.8)

func _prototype_stride(t: float) -> void:
	_pose_legs(model_legs,t*TAU*3.0,smoothstep(0,.08,t)*(1.-smoothstep(.90,1.,t)))
	var planted := 0 if sin(t*TAU*3.0)>=0.0 else 1
	for i in contact_lamps.size():
		contact_lamps[i].material_override = m.endfield_yellow_emit if t<1.0 and i%2==planted else charcoal

func _build_tracks() -> void:
	footprints = Node3D.new()
	floor_root.add_child(footprints)
	var trail := Curve2D.new()
	for point: Vector2 in PLAN.EXHIBIT_TRANSFER: trail.add_point(point)
	trail.add_point(PLAN.REAR_GATE.get_center())
	var pad := Rect2(L.H06_BAY_RECT.get_center()-Vector2(3.17,2.47),Vector2(6.34,4.94))
	for i in floori(trail.get_baked_length()/1.1):
		var d := .35+i*1.1
		var center := trail.sample_baked(d)
		var forward := center.direction_to(trail.sample_baked(d+.35))
		var side := -1 if i%2 else 1
		var point := center+forward.orthogonal()*2.85*side
		var y := .162 if pad.has_point(point) else (.045 if L.H06_BAY_RECT.has_point(point) else .025)
		var foot := M.box(footprints,"Tread",Vector3(.42,.012,.73),Vector3(point.x,y,point.y),charcoal)
		foot.rotation.y = atan2(forward.x,forward.y)+side*.25
func _build_arrows() -> void:
	var upper_marks := [Vector3(-18.5,-5,180)] if visit==PLAN.Visit.WEST else [Vector3(-6.05,-10,0),Vector3(-5.5,-20,0),Vector3(-9.5,-29,90),Vector3(-24,-30.8,90),
		Vector3(-38.6,-24.5,180),Vector3(-31.5,-14.2,-90),Vector3(-18.5,-5,180)]
	for mark: Vector3 in upper_marks:
		if PLAN.visit_contains(visit,Vector2(mark.x,mark.y),false): _arrow(Vector3(mark.x,3.065,mark.y),mark.z)
	for mark: Vector3 in [Vector3(-14,8,-90),Vector3(.5,11,180),Vector3(.5,18.6,180),Vector3(-5,34.4,180),
			Vector3(-2,51.4,180),Vector3(10,61,-90),Vector3(12.5,78,180),Vector3(22,89,-90),
			Vector3(55,88,-90),Vector3(69,75,0),Vector3(63,52,0),Vector3(54.5,41,90),Vector3(51,34,90),
			Vector3(43.2,34,90),Vector3(38.0,23.5,0),Vector3(38,15.5,0)]:
		if PLAN.visit_contains(visit,Vector2(mark.x,mark.y),true): _arrow(Vector3(mark.x,.025,mark.y),mark.z)

func _console(key: String, at: Vector2, y: float) -> void:
	var r := Rect2(at-Vector2(.63,.32),Vector2(1.26,.64))
	slab("Station",r,y+.88,.88,charcoal)
	lamps[key] = slab("StationPanel",r.grow(-.11),y+.94,.06,m.monitor_glow)
	add_body("Station",r,PLAN.UPPER_GATES.has(key))
	if key=="clinic":
		slab("MedicalCross",Rect2(at.x-.24,at.y-.055,.48,.11),y+.951,.012,white)
		slab("MedicalCross",Rect2(at.x-.055,at.y-.23,.11,.46),y+.952,.013,white)

func signal_used(key: String) -> void:
	if lamps.has(key): lamps[key].material_override = m.exit_green

func stride(phase: float,strength: float) -> void:
	_pose_legs(legs,phase,strength)

func _pose_legs(rig: Array,phase: float,strength: float) -> void:
	for leg: Array in rig:
		var t: float = phase+leg[4]*PI
		leg[0].quaternion = leg[1]*Quaternion(Vector3.UP,sin(t)*.115*leg[5]*strength)
		leg[2].quaternion = leg[3]*Quaternion(Vector3.BACK,maxf(0,cos(t))*.14*strength)

func _build_walkability_colliders() -> void:
	pass # The two chapter elevations have separate continuous perimeters.

func _build_north_shell(height: float) -> void:
	for span: Vector2 in [Vector2(-9.45,-7.05),Vector2(-5.05,9.05)]:
		m.build_top_black_wall(wall_root,"NorthShell",Vector3((span.x+span.y)*.5,height*.5,-9.25),
			Vector3(span.y-span.x,height,.66),7,m.wall_composite)
	m.box(wall_root,"Lintel206",Vector3(2,.3,.66),Vector3(-6.05,5.79,-9.25),m.steel_beam)
	# One flush concrete face between the retained pane beside 206 and the east stencil bay.
	var west := -3.325
	var east := 3.60
	_build_solid_panel_north((west+east)*.5,east-west,0.0,height)

func _build_fake_door_bay_north(x: float,y: float,top: float,code: String,accent: Material,caption: String) -> void:
	if code in ["204","205"]: return
	if code != "206":
		super._build_fake_door_bay_north(x,y,top,code,accent,caption)
		return
	for side in [-1,1]:
		m.box(wall_root,"Jamb206",Vector3(.12,2.35,.21),Vector3(x+side*.87,y+1.175,-8.53),m.steel_mullion)
	m.box(wall_root,"Header206",Vector3(1.86,.12,.21),Vector3(x,y+2.35,-8.53),m.endfield_yellow)
	_build_room_plaque("PlaqueN_206",Vector3(x-1.0,y+1.56,-8.42),0,"206",accent)

func _build_smoked_window_bay_north(x: float,y: float,top: float,width: float,title: String,with_server: bool) -> void:
	if title!="OfficeBay204":
		super._build_smoked_window_bay_north(x,y,top,width,title,with_server)

func _make_security_wall(end_fade: Vector4, z_fade: Vector4, fade_min: float, _weather_level: float) -> ShaderMaterial:
	var mat := fittings.wall.duplicate() as ShaderMaterial
	mat.set_shader_parameter("enamel",Color("b9c1b7"))
	mat.set_shader_parameter("dado_color",Color("395846"))
	mat.set_shader_parameter("plaster_albedo",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Diffuse.res"))
	mat.set_shader_parameter("surface_normal",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_nor_gl.res"))
	mat.set_shader_parameter("roughness_map",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Rough.res"))
	mat.set_shader_parameter("normal_depth",0.26)
	mat.set_shader_parameter("weathering",0.0)
	mat.set_shader_parameter("plaster_blend",0.0)
	mat.set_shader_parameter("institutional_panel",1.0)
	mat.set_shader_parameter("panel_pitch",1.65)
	mat.set_shader_parameter("passage_end_fade",end_fade)
	mat.set_shader_parameter("passage_z_fade",z_fade)
	mat.set_shader_parameter("fade_floor",fade_min)
	return mat


func _make_security_deck(span: Vector2, base_col: Color, _wear_level: float, end_fade: Vector4, z_fade: Vector4, fade_min: float) -> ShaderMaterial:
	var mat := fittings.floor_material(FITTINGS.Deck.LAB).duplicate() as ShaderMaterial
	mat.set_shader_parameter("concrete",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Diffuse.res"))
	mat.set_shader_parameter("surface_normal",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_nor_gl.res"))
	mat.set_shader_parameter("roughness_map",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Rough.res"))
	mat.set_shader_parameter("base",base_col.lerp(Color("b6beb4"),0.72))
	mat.set_shader_parameter("slab_span",Vector2(1.45,1.45) if span.x >= 2.2 else Vector2(1.35,1.35))
	mat.set_shader_parameter("tex_repeat",2.90)
	mat.set_shader_parameter("tex_midpoint",Vector3(0.093,0.094,0.089))
	mat.set_shader_parameter("albedo_contrast",1.38)
	mat.set_shader_parameter("seam_strength",0.58)
	mat.set_shader_parameter("fastener_strength",0.0)
	mat.set_shader_parameter("normal_depth",0.28)
	mat.set_shader_parameter("wear_strength",0.10)
	mat.set_shader_parameter("green_zone_rect",Vector4(1.48,-22.5,8.5,-10.5))
	mat.set_shader_parameter("green_zone_color",Color("739182"))
	mat.set_shader_parameter("passage_end_fade",end_fade)
	mat.set_shader_parameter("passage_z_fade",z_fade)
	mat.set_shader_parameter("fade_floor",fade_min)
	return mat


func _make_heavy_wall(enamel_col: Color, dado_col: Color, weathering_amt: float, plaster_amt: float) -> ShaderMaterial:
	var mat := fittings.wall.duplicate() as ShaderMaterial
	mat.set_shader_parameter("enamel",enamel_col)
	mat.set_shader_parameter("dado_color",dado_col)
	mat.set_shader_parameter("plaster_albedo",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Diffuse.res"))
	mat.set_shader_parameter("surface_normal",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_nor_gl.res"))
	mat.set_shader_parameter("roughness_map",load("res://art/Dream/CC0/PolyHavenResearch/plastered_wall_05_Rough.res"))
	mat.set_shader_parameter("normal_depth",0.46)
	mat.set_shader_parameter("weathering",weathering_amt)
	mat.set_shader_parameter("plaster_blend",plaster_amt)
	mat.set_shader_parameter("institutional_panel",0.0)
	mat.set_shader_parameter("panel_pitch",2.0)
	mat.set_shader_parameter("passage_end_fade",Vector4(100000.0,100001.0,100000.0,100001.0))
	mat.set_shader_parameter("passage_z_fade",Vector4(100000.0,100001.0,100000.0,100001.0))
	mat.set_shader_parameter("fade_floor",1.0)
	return mat


func _make_heavy_deck(base_col: Color, span: Vector2, repeat: float, contrast: float,
		seam: float, fastener: float, normal_d: float, wear: float) -> ShaderMaterial:
	var mat := fittings.floor_material(FITTINGS.Deck.LAB).duplicate() as ShaderMaterial
	mat.set_shader_parameter("concrete",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Diffuse.res"))
	mat.set_shader_parameter("surface_normal",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_nor_gl.res"))
	mat.set_shader_parameter("roughness_map",load("res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_Rough.res"))
	mat.set_shader_parameter("base",base_col)
	mat.set_shader_parameter("slab_span",span)
	mat.set_shader_parameter("tex_repeat",repeat)
	mat.set_shader_parameter("tex_midpoint",Vector3(0.093,0.094,0.089))
	mat.set_shader_parameter("albedo_contrast",contrast)
	mat.set_shader_parameter("seam_strength",seam)
	mat.set_shader_parameter("fastener_strength",fastener)
	mat.set_shader_parameter("normal_depth",normal_d)
	mat.set_shader_parameter("wear_strength",wear)
	mat.set_shader_parameter("green_zone_rect",Vector4(0.0,0.0,-1.0,-1.0))
	mat.set_shader_parameter("passage_end_fade",Vector4(100000.0,100001.0,100000.0,100001.0))
	mat.set_shader_parameter("passage_z_fade",Vector4(100000.0,100001.0,100000.0,100001.0))
	mat.set_shader_parameter("fade_floor",1.0)
	return mat


func _make_lounge_wall() -> ShaderMaterial:
	return _make_heavy_wall(Color("4e585e"),Color("1e2529"),0.54,0.24)


func _make_warehouse_wall() -> ShaderMaterial:
	return _make_heavy_wall(Color("4a545d"),Color("20262c"),0.62,0.26)


func _make_warehouse_deck() -> ShaderMaterial:
	return _make_heavy_deck(Color("31383f"),Vector2(2.8,2.4),4.2,2.25,0.90,0.55,0.58,0.84)


func _make_freight_wall() -> ShaderMaterial:
	return _make_heavy_wall(Color("3b444a"),Color("181d21"),0.72,0.30)


func _make_freight_deck() -> ShaderMaterial:
	var mat := _make_heavy_deck(Color("2b3237"),Vector2(2.6,2.2),4.4,2.35,0.92,0.65,0.60,0.88)
	mat.set_shader_parameter("safety",Color("b6861e"))
	return mat


func _build_west_warehouse() -> void:
	for divider: Rect2 in PLAN.WEST_WALLS:
		var a := Vector2(divider.position.x,divider.get_center().y) if divider.size.x>divider.size.y else Vector2(divider.get_center().x,divider.position.y)
		var b := Vector2(divider.end.x,divider.get_center().y) if divider.size.x>divider.size.y else Vector2(divider.get_center().x,divider.end.y)
		var curb := slab("WarehouseFenceCurb",divider,3.04+.18,.18,m.steel_beam if m.steel_beam!=null else charcoal)
		var rail := slab("WarehouseFenceRail",divider.grow(.02),3.04+1.08,.075,m.endfield_yellow if m.endfield_yellow!=null else amber)
		cutout.register_tree(curb)
		cutout.register_tree(rail)
		service_art.mesh_panel(floor_root,a,b,3.04+.16,1.98,0.28)
		add_body("TestingBulkhead",divider,true)
	WAREHOUSE.dress_warehouse_shell(floor_root,wall_root,fittings,cutout,3.04)
	var bollards := WAREHOUSE.build_stair_bollards(floor_root, PLAN.WEST_STAIR_BOLLARDS, 3.04, PLAN.WEST_BOLLARD_RADIUS)
	cutout.register_mesh(bollards)
	for index in PLAN.WEST_STAIR_BOLLARDS.size():
		var body := StaticBody2D.new()
		body.name = "StairSafetyBollard_%02d" % index
		body.position = PLAN.WEST_STAIR_BOLLARDS[index] * world.CELL_PIXELS
		body.collision_layer = ACTOR_EDGE if live and not lower_active else 0
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = PLAN.WEST_BOLLARD_RADIUS * world.CELL_PIXELS
		shape.shape = circle
		body.add_child(shape)
		physics_root.add_child(body)
		upper_bodies.append(body)
	west_shutters.clear()
	west_shutter_bodies.clear()
	west_shutter_tweens.clear()
	var pocket_wall := warehouse_wall.duplicate() as ShaderMaterial
	pocket_wall.set_shader_parameter("passage_end_fade",Vector4(-48.1,-46.05,100000.0,100001.0))
	pocket_wall.set_shader_parameter("fade_floor",0.0)
	var pocket_floor := warehouse_floor.duplicate() as ShaderMaterial
	pocket_floor.set_shader_parameter("passage_end_fade",Vector4(-48.1,-46.05,100000.0,100001.0))
	pocket_floor.set_shader_parameter("fade_floor",0.0)
	for bay_key: String in PLAN.WEST_SHUTTER_BAYS:
		var bay: Dictionary = PLAN.WEST_SHUTTER_BAYS[bay_key]
		var floor_y := 0.0 if bay.lower else 3.04
		var built := WAREHOUSE.build_west_shutter_bay(floor_root,wall_root,floor_y,bay_key,bay.z,bay.width,cutout,pocket_wall,pocket_floor)
		built["lower"] = bay.lower
		west_shutters[bay_key] = built
		var pocket_x: float = bay.pocket_x
		var half_w := float(bay.width)*.5
		var upper := not bool(bay.lower)
		add_body("WestBayBack_"+bay_key,Rect2(pocket_x-.25,bay.z-half_w-.25,.25,bay.width+.5),upper)
		for sz: float in [-1.0,1.0]:
			add_body("WestBayWall_"+bay_key,Rect2(pocket_x,bay.z+sz*(half_w+.12)-.12,-46.0-pocket_x,.24),upper)
		west_shutter_bodies[bay_key] = add_body("WestShutterStop_"+bay_key,Rect2(-46.16,bay.z-half_w,.32,bay.width),upper)
	for parked: Array in [[Vector2(-13.8,-35.6),3.04,PI*0.72],[Vector2(-26.3,1.2),0.0,-PI*0.72]]:
		var p: Vector2 = parked[0]
		var fy: float = parked[1]
		var park_model := MINI_FORKLIFT.new()
		park_model.name = "ParkedWarehouseForklift"
		park_model.position = Vector3(p.x,fy,p.y)
		park_model.rotation.y = float(parked[2])
		floor_root.add_child(park_model)
		cutout.register_tree(park_model,true)
		add_body("ParkedForkliftBody",Rect2(p.x-.85,p.y-.85,1.70,1.70),fy>1.0)


func is_west_shutter_open(key: String) -> bool:
	return west_shutters.has(key) and bool(west_shutters[key].open)


func open_west_shutter(key: String, instant := false) -> void:
	_set_west_shutter_open(key,true,instant)


func close_west_shutter(key: String, instant := false) -> void:
	_set_west_shutter_open(key,false,instant)


func is_west_shutter_closed(key: String) -> bool:
	return west_shutters.has(key) and not bool(west_shutters[key].open) and not bool(west_shutters[key].get("moving",false))


func _set_west_shutter_open(key: String, opened: bool, instant: bool) -> void:
	if not west_shutters.has(key): return
	var bay: Dictionary = west_shutters[key]
	if bool(bay.open)==opened and not instant: return
	bay.open = opened
	# Keep the physical stop and AI's floor-edge graph in the same state.
	# Preserve existing edge data across both open/close cycles.
	var layout:Dictionary=PLAN.WEST_SHUTTER_BAYS[key]
	if not bay.has("navigation_edges"):bay.navigation_edges={}
	for z in range(ceili(float(layout.z)-float(layout.width)*.5),ceili(float(layout.z)+float(layout.width)*.5)):
		var edge:Dictionary={"axis":"V","x":-46,"y":z}
		var edge_key:String=world._edge_key(edge)
		if not bay.navigation_edges.has(edge_key):bay.navigation_edges[edge_key]=world.wall_edges.get(edge_key,edge).duplicate(true)
		if opened:world.wall_edges.erase(edge_key)
		else:world.wall_edges[edge_key]=bay.navigation_edges[edge_key]
	world.employee_path_cache.clear()
	if is_instance_valid(bay.beacon):
		bay.beacon.material_override = WAREHOUSE.materials().beacon_green if opened else WAREHOUSE.materials().beacon_red
	if west_shutter_bodies.has(key) and is_instance_valid(west_shutter_bodies[key]):
		var body: StaticBody2D = west_shutter_bodies[key]
		var blocked:bool=not opened and live and bool(bay.lower)==lower_active
		body.collision_layer = ACTOR_EDGE if blocked else 0
		(body.get_child(0) as CollisionShape2D).set_deferred("disabled",not blocked)
	if not is_instance_valid(bay.curtain): return
	if west_shutter_tweens.has(key) and west_shutter_tweens[key] and (west_shutter_tweens[key] as Tween).is_valid():
		(west_shutter_tweens[key] as Tween).kill()
	var target:float=.05 if opened else 1.0
	if instant:
		bay.curtain.scale.y = target
		bay.moving = false
		return
	bay.moving = true
	var tween: Tween = bay.curtain.create_tween()
	west_shutter_tweens[key] = tween
	tween.tween_property(bay.curtain,"scale:y",target,.46 if opened else .52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opened else Tween.EASE_IN_OUT)
	tween.tween_callback(func()->void:bay.moving=false)


func _build_west_threshold() -> void:
	# Both streamed rooms own the same visible reveal. Only the active copy is displayed.
	var pocket: Rect2 = PLAN.UPPER.monitor_threshold.merge(PLAN.UPPER.west_threshold)
	var y := PLAN.upper_height(pocket.get_center())
	var pocket_fade := Vector4(-24.65,-22.55,1000.0,1001.0) if visit==PLAN.Visit.GALLERY else Vector4(-1000.0,-999.0,-24.65,-22.55)
	var pocket_deck := _make_security_deck(Vector2(2.40,2.40),Color("74818a"),0.92,Vector4.ZERO,pocket_fade,0.0)
	var pocket_wall := _make_security_wall(Vector4.ZERO,pocket_fade,0.0,0.88)
	slab("WestThresholdFloor",pocket,y,.22,pocket_deck)
	for side: int in [-1,1]:
		var x := pocket.position.x if side<0 else pocket.end.x
		var r := Rect2(x-.10,pocket.position.y-.02,.20,pocket.size.y+.04)
		boundary_wall(wall_root,"ThresholdReturn",r,y-.22,2.67,Vector2(side,0),pocket_wall)
		var inner := x-side*.112
		m.box(wall_root,"RecessSkirting",Vector3(.033,.20,pocket.size.y),Vector3(inner,y+.10,pocket.get_center().y),fittings.graphite,true)
		var lamp_pos := Vector3(inner-side*.045,y+1.43,pocket.get_center().y-side*.48)
		m.box(wall_root,"RecessLampHousing",Vector3(.075,.56,.14),lamp_pos,fittings.graphite)
		m.box(wall_root,"RecessLamp",Vector3(.018,.45,.08),lamp_pos-Vector3(side*.042,0,0),fittings.lamp)
	for z: float in [pocket.position.y+.055,pocket.end.y-.055]:
		m.box(floor_root,"FlushSill",Vector3(pocket.size.x-.22,.014,.07),Vector3(pocket.get_center().x,y+.004,z),m.steel_mullion)
	var center := Vector3(pocket.get_center().x,y,pocket.get_center().y)
	const HEAD := 2.13
	if visit==PLAN.Visit.WEST:
		var hood_mat: Material = cutout.top_black
		var hood := m.box(wall_root,"RecessRollerHousing",Vector3(4.12,.26,.29),center+Vector3.UP*(HEAD+.12),hood_mat,true)
		hood.material_overlay = null
	else:
		m.box(wall_root,"RecessRollerHousing",Vector3(4.12,.26,.29),center+Vector3.UP*(HEAD+.12),fittings.graphite,true)
	for side: int in [-1,1]:
		m.box(wall_root,"RollerGuide",Vector3(.09,HEAD,.13),center+Vector3(side*1.90,HEAD*.5,0),m.steel_mullion,true)
	threshold_shutter = Node3D.new()
	threshold_shutter.name = "WestSecurityShutter"
	wall_root.add_child(threshold_shutter)
	threshold_shutter.position = center+Vector3.UP*HEAD
	m.box(threshold_shutter,"RollingSlats",Vector3(3.80,HEAD,.063),Vector3.DOWN*HEAD*.5,fittings.shutter)
	m.box(threshold_shutter,"BottomRail",Vector3(3.80,.07,.085),Vector3.DOWN*(HEAD-.035),fittings.graphite)
	for side: int in [-1,1]:
		m.box(threshold_shutter,"DoorReflector",Vector3(.36,.053,.081),Vector3(side*1.40,-HEAD+.31,0),m.steel_rail)
	threshold_open = 1.0 if visit==PLAN.Visit.WEST else 0.0
	threshold_shutter.scale.y = lerpf(1.0,.025,threshold_open)
	if visit==PLAN.Visit.GALLERY:
		# A sightline through the opening shows the actual first tiles of the west wing
		# even before its gameplay/lighting roots take ownership.
		var tiles := fittings.floor_material(FITTINGS.Deck.LAB).duplicate() as ShaderMaterial
		tiles.set_shader_parameter("view_opening",Vector4(pocket.position.x+.10,pocket.end.x-.10,center.z,y+HEAD))
		var peek := slab("CalibrationThroughOpening",PLAN.UPPER.calibration,y,.22,tiles)
		fittings.set_grate(peek,FITTINGS.SERVICE_GRATES.calibration)

func update_west_threshold(p: Vector2, delta: float) -> void:
	if not is_instance_valid(threshold_shutter): return
	var door := PLAN.passage_coordinates(0,p)
	if visit==PLAN.Visit.WEST and door.x>2.05: west_entry_closed = true
	var open := not west_entry_closed if visit==PLAN.Visit.WEST else door.x> -3.0 and absf(door.y)<2.55
	if visit==PLAN.Visit.GALLERY and world.staff_story.monitoring_shutter_open:open=true
	var next := move_toward(threshold_open,1.0 if open else 0.0,delta*(3.7 if open else 2.55))
	if is_equal_approx(threshold_open,next): return
	threshold_open = next
	threshold_shutter.scale.y = lerpf(1.0,.025,next)

func slab(title: String,r: Rect2,top: float,h: float,mat: Material) -> MeshInstance3D:
	var p := r.get_center()
	return M.box(floor_root,title,Vector3(r.size.x,h,r.size.y),Vector3(p.x,top-h*.5,p.y),mat)

func boundary_wall(parent: Node3D,title: String,r: Rect2,y: float,h: float,outward: Vector2,finish: Material,moving := false) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = title
	# The prologue mesh assigns the room finish only to the interior face.
	var loading_hall := visit==PLAN.Visit.STAFF and r.get_center().y<41.01
	var inner: Material = fittings.graphite_wall if finish==charcoal or loading_hall else fittings.wall
	if finish is ShaderMaterial: inner = finish
	wall.mesh = TRANSIT.top_black_wall(Rect2(-r.size*.5,r.size),Vector2i(outward),h,inner,cutout.top_black)
	var center := r.get_center()
	wall.position = Vector3(center.x,y,center.y)
	parent.add_child(wall)
	cutout.register_mesh(wall,moving)
	if not loading_hall and not (finish is ShaderMaterial): fittings.wall_cladding(parent,r,y,h,outward)
	return wall

func _outline(e: Array,upper: bool) -> void:
	var a: Vector2 = e[1]
	var b: Vector2 = e[2]
	var n: Vector2 = e[3]
	var r := Rect2(a.min(b), (b-a).abs()).grow(.10)
	var perimeter := add_body("Perimeter",r,upper)
	if e[0] in ["monitor_threshold","west_threshold"]: return
	if not upper and visit==PLAN.Visit.EMPTY_HANGAR:
		var west_edge: bool = n==Vector2.LEFT and e[0] in ["hangar","bay_apron","search"]
		var apron_return: bool = n==Vector2.UP and e[0]=="bay_apron"
		if west_edge or apron_return: return
	if e[0]=="secret":
		if n.x!=0.0:
			# Butt the long sides into the end walls, and leave the portal free of overlapping end caps.
			var room: Rect2 = PLAN.LOWER.secret
			var lo := a.y+.10 if is_equal_approx(a.y,room.position.y) else a.y
			var hi := b.y-.10 if is_equal_approx(b.y,room.end.y) else b.y
			r = Rect2(r.position.x,lo,r.size.x,hi-lo)
		service_art.utility_wall(wall_root,r,n)
		return
	if e[0]=="secret_mouth" and n.x==0.0:
		var access_wall := Rect2(a.x,r.position.y,b.x-a.x-.10,r.size.y)
		var height := 1.68 if n==Vector2.UP else .65
		boundary_wall(wall_root,"PlantAccessWall",access_wall,-.22,height+.22,n,service_art.access_wall)
		return
	if e[0] == "arena":
		if n.x != 0.0: perimeter.set_meta(&"h06_shaft_wall_side", n.x)
		return
	if e[0]=="boarding_bridge": return
	if e[0]=="landing":
		# Both floor plans include the foot of the stairs. Its visible boundary is on the ground floor.
		if upper or n==Vector2.UP: return
	if n==Vector2.UP and WINDOW.WINDOWS.has(e[0]):
		var panel: Rect2 = WINDOW.WINDOWS[e[0]]
		if a.x < panel.end.x and b.x > panel.position.x:
			var y := 3.04 if upper else 0.0
			var is_tall_win := visit==PLAN.Visit.WEST or visit==PLAN.Visit.FREIGHT
			var win_h := 4.42 if is_tall_win else 2.67
			var win_mat: Material = warehouse_wall if visit==PLAN.Visit.WEST and warehouse_wall!=null else (freight_wall if visit==PLAN.Visit.FREIGHT and freight_wall!=null else white)
			for span: Vector2 in [Vector2(a.x,minf(b.x,panel.position.x)),Vector2(maxf(a.x,panel.end.x),b.x)]:
				if span.y>span.x:
					boundary_wall(wall_root,"WindowReturn",Rect2(span.x,a.y-.10,span.y-span.x,.20),y-.22,win_h,n,win_mat)
			return
	if e[0] in ["spur","east","north","understairs"] or (not upper and e[0]=="pit"): return
	if e[0]=="hangar" and n in [Vector2.UP,Vector2.RIGHT]: return # Original facade.
	# Lower front edges keep the working surface legible in the standing camera.
	var tall_wall_h := 4.42 if visit==PLAN.Visit.WEST else (4.35 if visit==PLAN.Visit.FREIGHT else (4.20 if visit==PLAN.Visit.STAFF else 2.45))
	var front_wall_h := .87 if visit==PLAN.Visit.WEST else .65
	var height := front_wall_h if n.y > 0 else tall_wall_h
	var y := PLAN.upper_height((a+b)*.5) if upper else 0.0
	if e[0]=="stair":
		height = .16
		var rail := M.box(floor_root,"StairStringer",Vector3(.13,height,a.distance_to(b)*1.050),
			Vector3(a.x,1.53,(a.y+b.y)*.5),amber)
		rail.rotation.x = atan2(3.04,9.5)
	else:
		var wall_finish: Material = warehouse_wall if visit==PLAN.Visit.WEST and warehouse_wall!=null else (freight_wall if visit==PLAN.Visit.FREIGHT and freight_wall!=null else (lounge_wall if visit==PLAN.Visit.STAFF and lounge_wall!=null else white))
		if e[0]=="observation" and security_wall!=null: wall_finish = security_wall
		elif e[0]=="206" and security_entry_wall!=null: wall_finish = security_entry_wall
		if visit==PLAN.Visit.FREIGHT:
			if FREIGHT.is_north_bulkhead_edge(e):
				for seg: Array in FREIGHT.split_wall_for_buttresses(a,b,n):
					var sa: Vector2 = seg[0]
					var sb: Vector2 = seg[1]
					var sr := Rect2(sa.min(sb),(sb-sa).abs()).grow(.10)
					boundary_wall(wall_root,"Wall",sr,y-.22,height+.22,n,wall_finish)
			elif e[0]=="dispatch" and n==Vector2.LEFT:
				boundary_wall(wall_root,"Wall",r,y-.22,height+.22,n,wall_finish)
		else:
			boundary_wall(wall_root,"Wall",r,y-.22,height+.22,n,wall_finish)

func add_body(title: String,r: Rect2,upper: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = r.get_center()*world.CELL_PIXELS
	body.collision_layer = ACTOR_EDGE if live and upper!=lower_active else 0
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size*world.CELL_PIXELS
	shape.shape = box
	body.add_child(shape)
	physics_root.add_child(body)
	(upper_bodies if upper else lower_bodies).append(body)
	return body

func build_gate(key: String) -> void:
	var r: Rect2 = PLAN.GATES[key]
	var upper := PLAN.UPPER_GATES.has(key)
	if key == "boarding":
		var railing := inclined_lift.build_board_gate(self)
		gates[key] = [add_body("DockSafetyRailBody",r,false),railing,false]
		return
	var floor_y := 3.04 if upper else 0.0
	if key=="calibration":
		var wm := WAREHOUSE.materials()
		var intact := Node3D.new()
		intact.name = "CalibrationBarrierIntact"
		floor_root.add_child(intact)
		var cx := r.get_center().x
		var cz := r.get_center().y
		var len_z := r.size.y - 0.16
		var steel_mat: Material = m.steel_beam if m.steel_beam!=null else charcoal
		M.box(intact,"BarrierCurb",Vector3(.20,.18,len_z),Vector3(cx,floor_y+.09,cz),steel_mat)
		for rail_y: float in [floor_y+.56,floor_y+1.06]:
			M.box(intact,"BarrierHazardRail",Vector3(.11,.15,len_z),Vector3(cx,rail_y,cz),wm.hazard)
		service_art.mesh_panel(intact,Vector2(cx,r.position.y+.08),Vector2(cx,r.end.y-.08),floor_y+.18,.92,.28)
		for idx in 4:
			var pz := lerpf(r.position.y+.10,r.end.y-.10,float(idx)/3.0)
			M.box(intact,"BarrierStanchion",Vector3(.16,1.22,.16),Vector3(cx,floor_y+.61,pz),wm.safety_yellow if idx in [0,3] else steel_mat)
			if idx in [0,3]:
				M.box(intact,"BarrierBeacon",Vector3(.12,.14,.12),Vector3(cx,floor_y+1.29,pz),wm.beacon_red)
		cutout.register_tree(intact)

		var broken := Node3D.new()
		broken.name = "CalibrationBarrierBroken"
		broken.visible = false
		floor_root.add_child(broken)
		for side_z: float in [-1.0,1.0]:
			var stump_z := r.position.y+.10 if side_z<0.0 else r.end.y-.10
			var stump := M.box(broken,"BentBarrierPost",Vector3(.16,.78,.16),Vector3(cx-.14,floor_y+.36,stump_z),wm.safety_yellow)
			stump.rotation = Vector3(side_z*.22,0.0,.42)
			var shard := M.box(broken,"ShatteredBarrierRail",Vector3(.14,.13,1.65),Vector3(cx-1.05,floor_y+.07,stump_z+side_z*.18),wm.hazard)
			shard.rotation = Vector3(.08,deg_to_rad(90.0+side_z*24.0),.12)
		cutout.register_tree(broken)
		gates[key] = [add_body("Gate_"+key,r,upper),intact,upper,broken]
		return
	var leaf := slab("Gate_"+key,r,2.1+floor_y,2.1,fittings.shutter)
	var bar := slab("GateBand",r.grow(.018),floor_y+1.02,.10,amber)
	bar.reparent(leaf,true)
	gates[key] = [add_body("Gate_"+key,r,upper),leaf,upper]

func set_gate(key: String,locked: bool) -> void:
	if not closed.has(key) and not gates.has(key): return
	closed[key] = locked
	if not gates.has(key): return
	var g: Array = gates[key]
	var body: StaticBody2D = g[0]
	var gate_active: bool = live and locked and (bool(g[2]) != lower_active)
	body.collision_layer = ACTOR_EDGE if gate_active else 0
	var shape := body.get_child(0) as CollisionShape2D
	if shape != null: shape.disabled = not gate_active
	g[1].visible = locked
	if g.size()>=4 and is_instance_valid(g[3]):
		g[3].visible = not locked

var lower_active := false
func set_lower(enabled: bool) -> void:
	lower_active = enabled
	if is_instance_valid(forklift): forklift.set_active(live)
	if is_instance_valid(footprints): footprints.visible = enabled
	for body in upper_bodies: body.collision_layer = ACTOR_EDGE if live and not enabled else 0
	for body in lower_bodies: body.collision_layer = ACTOR_EDGE if live and enabled else 0
	for bay_key: String in west_shutter_bodies:
		var bay: Dictionary = west_shutters[bay_key]
		var body: StaticBody2D = west_shutter_bodies[bay_key]
		if not is_instance_valid(body): continue
		var layer_match := (bool(bay.lower) == enabled)
		var blocked:bool=live and not bool(bay.open) and layer_match
		body.collision_layer = ACTOR_EDGE if blocked else 0
		(body.get_child(0) as CollisionShape2D).set_deferred("disabled",not blocked)
	for key: String in gates: set_gate(key,closed[key])
	for entry: Dictionary in freight_clutter_entries:
		set_freight_body_enabled(entry.get("body") as StaticBody2D, not bool(entry.get("exploded", false)))
	for entry: Dictionary in freight_breakables:
		set_freight_body_enabled(entry.get("body") as StaticBody2D, not bool(entry.exploded))
	for entry: Dictionary in freight_deck_drops:
		set_freight_body_enabled(entry.get("body") as StaticBody2D, String(entry.state) in ["bounce","landed"])
	for entry: Dictionary in freight_fractures:
		set_freight_body_enabled(entry.get("body") as StaticBody2D, String(entry.state) in ["shattering","broken"])

func _dynamic_freight_body(title: String, r: Rect2, initial_active: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = r.get_center()*world.CELL_PIXELS
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size*world.CELL_PIXELS
	shape.shape = box
	body.add_child(shape)
	physics_root.add_child(body)
	set_freight_body_enabled(body, initial_active)
	return body

func set_freight_body_enabled(body: StaticBody2D, active: bool) -> void:
	if not is_instance_valid(body): return
	var blocked := live and lower_active and active
	body.collision_layer = ACTOR_EDGE if blocked else 0
	var shape := body.get_child(0) as CollisionShape2D
	if shape != null: shape.set_deferred("disabled", not blocked)

func set_live(enabled: bool) -> void:
	live = enabled
	if is_instance_valid(monitoring_scientist):monitoring_scientist.set_active(enabled)
	if not enabled and is_instance_valid(evacuation): evacuation.deactivate()
	for root: Node in [floor_root,wall_root,lights_root,physics_root]:
		root.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		root.set("visible",enabled)
	set_lower(lower_active)
	if enabled:
		# The same activation is used behind the loading screen to warm each district.
		world.level_msaa_3d = Viewport.MSAA_2X if visit == PLAN.Visit.WEST else Viewport.MSAA_DISABLED
		GALLERY_TOP_BLACK.sync_background(self)

func activate_hangar_crew() -> void:
	if live and is_instance_valid(hangar_crew): hangar_crew.activate()

func _shade_passages() -> void:
	# The shaft has a lit, open walkway leading out from the staff portal.
	if visit==PLAN.Visit.ARENA: return
	var entrance: Dictionary = PLAN.PASSAGES[visit-1] if visit>0 else {"at":Vector2(11.5,6),"forward":Vector2.LEFT,"width":3.0,"height":1.28}
	var mouths := [] if visit in [PLAN.Visit.WEST,PLAN.Visit.EMPTY_HANGAR] else [entrance]
	if visit<PLAN.Visit.ARENA and visit not in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]:
		mouths.append(PLAN.PASSAGES[visit])
	var shade := ShaderMaterial.new()
	shade.shader = PASSAGE_SHADE
	if visit==PLAN.Visit.GALLERY: shade.render_priority = 1
	shade.set_shader_parameter("passage_end_fade",Vector4(0.13,2.35,100000,100001))
	var bounds: Array[AABB] = []
	for i in mouths.size():
		var door: Dictionary = mouths[i]
		var center: Vector2 = door.at
		var dir: Vector2 = door.forward
		var h: float = door.height
		var half_width: float = door.width*.5
		shade.set_shader_parameter("mouth_"+str(i),Vector4(center.x,center.y,dir.x,dir.y))
		shade.set_shader_parameter("limits_"+str(i),Vector2(half_width,h))
		var radius := dir.abs()*2.4+dir.orthogonal().abs()*(half_width+.5)
		bounds.append(AABB(Vector3(center.x-radius.x,h-.55,center.y-radius.y),Vector3(2*radius.x,3.5,2*radius.y)))
	if visit==PLAN.Visit.EMPTY_HANGAR:
		var door: Dictionary = PLAN.PASSAGES[visit]
		var center: Vector2 = door.at
		var half_width: float = door.width*.5
		var fade_start := center.y-2.65
		shade.set_shader_parameter("south_exit",Vector4(center.x,half_width,fade_start,center.y-.20))
		bounds.append(AABB(Vector3(center.x-half_width-.55,-.55,fade_start),
			Vector3(2.0*half_width+1.10,3.20,center.y-fade_start+.25)))
		var hangar: Rect2 = PLAN.LOWER.hangar
		var apron: Rect2 = PLAN.LOWER.bay_apron
		var west_fade_width := 1.65
		shade.set_shader_parameter("west_hangar_edge",Vector4(hangar.position.x,apron.position.x,apron.position.y,west_fade_width))
		var west_min := Vector3(apron.position.x-.20,-.55,hangar.position.y-.20)
		var west_end := Vector3(hangar.position.x+west_fade_width,.30,PLAN.LOWER.search.end.y+.20)
		bounds.append(AABB(west_min,west_end-west_min))
	if region==PLAN.Region.GALLERY:
		service_entrance_shade = shade.duplicate() as ShaderMaterial
		service_entrance_shade.render_priority = 3
		service_entrance_shade.set_shader_parameter("service_entrance", Vector2(PLAN.SERVICE_FACADE_X+.18,PLAN.LOWER.secret.position.x))
		service_entrance_shade.set_shader_parameter("service_passage_z", Vector2(PLAN.LOWER.secret_mouth.position.y,PLAN.LOWER.secret_mouth.end.y))
	for root: Node3D in [floor_root,wall_root]:
		for visual: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			if visual.mesh==null or (is_instance_valid(mech) and mech.is_ancestor_of(visual)): continue
			var box := visual.global_transform*visual.get_aabb()
			for volume in bounds:
				if volume.intersects(box):
					visual.material_overlay = shade
					break
			# Looking back from inside exposes the outer lintel and hangar deck
			# behind the access tiles. Give those surfaces the same westward fade.
			if service_entrance_shade != null and box.position.x < PLAN.LOWER.secret.position.x and box.end.z > -9.5 and box.position.z < 10.0:
				if not visual.has_meta(&"topblack_fragments") and visual != secret_roof:
					service_entrance_surfaces[visual] = visual.material_overlay

func breach_freight() -> void:
	freight_leaf.scale.y = .095
	freight_leaf.position.y = 4.43
	(freight_stop.get_child(0) as CollisionShape2D).set_deferred("disabled",true)

func reveal_roll_opening(feet: Vector2) -> void:
	if not is_instance_valid(half_shutter): return
	var near_shutter := PLAN.LOW_GATE.grow(1.7).has_point(feet)
	half_shutter.transparency = .66 if near_shutter else 0.0

func reveal_hoist_floor(feet: Vector2) -> void:
	var under_bridge := PLAN.HOIST_BRIDGE.grow(2.55).has_point(feet)
	if is_instance_valid(hoist_bridge): hoist_bridge.transparency = .84 if under_bridge else 0.0
	if is_instance_valid(freight_ramp): freight_ramp.transparency = .87 if PLAN.MACHINE_RAMP.has_point(feet) else 0.0

func _arrow(point: Vector3,yaw: float) -> void:
	if route_arrows == null:
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,white if visit==PLAN.Visit.STAFF else fittings.paint)
		for p: Vector2 in [Vector2(0,-.66),Vector2(.34,-.17),Vector2(-.34,-.17),
				Vector2(-.095,-.09),Vector2(.095,-.09),Vector2(.095,.57),Vector2(-.095,-.09),Vector2(.095,.57),Vector2(-.095,.57)]:
			mesh.surface_set_normal(Vector3.UP)
			mesh.surface_add_vertex(Vector3(p.x,0,p.y))
		mesh.surface_end()
		route_arrows = mesh
	var arrow := MeshInstance3D.new()
	arrow.mesh = route_arrows
	arrow.position = point
	arrow.rotation.y = deg_to_rad(yaw)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_root.add_child(arrow)

func _mount_warehouse_fixture(light: OmniLight3D) -> void:
	# The warehouse work pools already exist. Show the suspended housings at
	# those positions without adding another light or another shadow caster.
	var housing := M.box(light, "SuspendedWorkLight", Vector3(1.45,.13,.31), Vector3(0,.20,0), fittings.graphite)
	var finish := fittings.lamp.duplicate() as StandardMaterial3D
	finish.emission = light.light_color
	var diffuser := M.box(housing, "WorkLightDiffuser", Vector3(1.22,.042,.19), Vector3(0,.076,0), finish)
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var at := Vector2(light.position.x, light.position.z)
	var deck_height := PLAN.upper_height(at) if PLAN.visit_contains(visit, at, false) else 0.0
	OPTICS.mark_fixture(housing, light, [diffuser], deck_height)


func _build_region_lights() -> void:
	if inclined_lift != null:
		inclined_lift.light_shaft(self)
		return
	var root := lights_root
	var work_lights := [Vector3(-19,7,-30),
		Vector3(-37,7,-31),Vector3(-40,7,-13),Vector3(-32,7,-8),Vector3(-21,7,-14),Vector3(-18,6,-3),
		Vector3(-15,4,8),Vector3(-34,4,3),Vector3(.5,4,11),Vector3(4,5,17),Vector3(-7,5,18),Vector3(1,5,27),
		Vector3(-6,5,33),Vector3(6,5,42),Vector3(-4,5,49),Vector3(0,5,60),Vector3(13,5,63),
		Vector3(12.5,5,77),Vector3(15,5,91),Vector3(32,5,91),Vector3(45,5,90),Vector3(59,5,93),
		Vector3(71,5,88),Vector3(71,5,75),Vector3(68,5,61),Vector3(61,5,50),Vector3(62,5,39),Vector3(51,5,34),
		Vector3(32,6,-3),Vector3(44,6,-8),Vector3(38,4,-14)]
	for rec: Vector3 in work_lights:
		var at := Vector2(rec.x,rec.z)
		if PLAN.visit_contains(visit,at,true) or PLAN.visit_contains(visit,at,false):
			var work_col := Color("627986") if visit==PLAN.Visit.FREIGHT else Color("f3f3ef")
			var work_energy := 0.54 if visit==PLAN.Visit.FREIGHT else 2.2
			var work_range := 9.5 if visit==PLAN.Visit.FREIGHT else 12.0
			_omni(root,"WorkLight",rec,work_col,work_energy,work_range,1.15,at==Vector2(-37,-31))
	if visit==PLAN.Visit.WEST:
		var inspection_lamp := _omni(root, "WarehouseBayLight", Vector3(-4.5, 6.8, -30.0),
			Color("dbe7ef"), 2.6, 15.0, 1.25, true)
		inspection_lamp.shadow_opacity = 0.55
		inspection_lamp.shadow_blur = 1.65
		_mount_warehouse_fixture(inspection_lamp)
		for wh_light: Array in [
			[Vector3(-19.5,7.2,-30.5),Color("dbe7ef"),2.8,16.0],
			[Vector3(-32.5,7.2,-30.5),Color("dbe7ef"),2.8,16.0],
			[Vector3(-44.8,6.5,-28.8),Color("ffb25e"),2.4,11.0],
			[Vector3(-44.8,6.5,-14.8),Color("ffb25e"),2.4,11.0],
			[Vector3(-38.0,7.2,-14.8),Color("dbe7ef"),2.8,16.0],
			[Vector3(-21.5,7.2,-14.2),Color("dbe7ef"),2.8,16.0],
			[Vector3(-16.0,6.8,-13.8),Color("cde0ea"),2.2,13.0],
			[Vector3(-44.8,3.6,3.2),Color("ffb25e"),2.4,11.0],
			[Vector3(-35.5,4.4,3.2),Color("dbe7ef"),2.6,15.0],
			[Vector3(-22.5,4.2,7.2),Color("dbe7ef"),2.2,13.0]]:
			var bay_light := _omni(root,"WarehouseBayLight",wh_light[0],wh_light[1],float(wh_light[2]),float(wh_light[3]),1.25,false)
			_mount_warehouse_fixture(bay_light)
	if visit==PLAN.Visit.GALLERY:
		var room: SECURITY_ROOM = floor_root.get_node("SecurityAndRecords")
		room.light_workstations(self)
	if visit==PLAN.Visit.WEST:
		_spot(root,"SampleInspectionLight",Vector3(-6.5,6.20,-31.2),Vector3(-6.03,3.88,-28.40),Color("d2dfdf"),2.55,6.9,39.)
		_omni(root,"CalibrationPanelBounce",Vector3(-7.6,6.15,-30.5),Color("f4d48c"),1.45,10.5,1.25,false)
	if visit in [PLAN.Visit.GALLERY,PLAN.Visit.WEST]:
		# The shielded pilot points into the recess. It cannot wash either room.
		var mouth: Vector2 = PLAN.PASSAGES[PLAN.Visit.GALLERY].at
		for side: int in [-1,1]:
			_omni(root,"RecessPilot",Vector3(mouth.x+side*1.73,4.43,mouth.y-side*.48),Color("d4dedc"),.54,3.20,1.38,false)
	if visit==PLAN.Visit.STAFF:
		LOGISTICS_HUB.build_hub_lights(self,root)
	if visit in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]:
		_omni(root,"ServiceHatchLamp",Vector3(8.55,.95,1.6),Color("ffe6a6"),.85,3.6,1.2,false)
		_conceal_secret(_omni(root,"PlantRoomLight",Vector3(16.2,4.1,-.9),Color("eee6d3"),1.85,9.8,1.10,false))
		_conceal_secret(_spot(root,"PlantTaskLight",Vector3(18.8,4.8,-1.5),Vector3(20.1,1.2,-4.4),Color("e1e9e2"),3.05,9,55))
	if visit==PLAN.Visit.FREIGHT:
		freight_flicker_lights.clear()
		_spot(root,"CargoWorkLight",Vector3(4,7,59),Vector3(12,0,62),Color("e8b88a"),2.6,18,52)
		# Dim sub-platform chasm lights illuminating giant submerged pipes & turbines through open grate holes
		for sub_glow: Array in [
			[Vector3(-1.5,-2.6,21.4),Color("e87b2c"),1.75,9.5],
			[Vector3(-2.5,-3.2,30.0),Color("497f94"),1.85,11.0],
			[Vector3(-14.2,-1.5,29.0),Color("548ca0"),1.60,9.5],
			[Vector3(13.4,-1.6,34.0),Color("e87b2c"),1.55,9.5],
			[Vector3(2.0,-2.8,59.5),Color("d9742a"),1.65,10.5],
			[Vector3(5.2,-1.6,76.0),Color("548ca0"),1.55,9.5],
			[Vector3(14.0,-3.2,74.0),Color("497f94"),1.75,11.0],
			[Vector3(24.0,-1.6,66.0),Color("e87b2c"),1.55,9.5],
			[Vector3(36.0,-3.2,92.0),Color("d9742a"),2.15,13.5],
			[Vector3(58.0,-3.0,91.0),Color("497f94"),1.85,12.0],
			[Vector3(64.5,-3.0,53.5),Color("d9742a"),1.75,11.0],
			[Vector3(71.0,-1.6,46.0),Color("548ca0"),1.55,9.5],
		]:
			_omni(root,"FreightAbyssGlow",sub_glow[0],sub_glow[1],float(sub_glow[2]),float(sub_glow[3]),1.28,false)

		# Sparse dim overhead pools + stuttering failing lamps over walkways and unstable plates
		var flicker_specs: Array[Array] = [
			[Vector3(1.5,5.0,17.2),Color("96b8c4"),1.55,10.5,0.7],
			[Vector3(-2.0,5.2,24.8),Color("f2a050"),1.65,11.0,2.1],
			[Vector3(-4.8,5.2,37.2),Color("f2a050"),1.65,11.5,3.1],
			[Vector3(-4.2,5.2,47.2),Color("9ab8c2"),1.55,11.0,3.8],
			[Vector3(3.8,5.2,59.5),Color("f2a050"),1.70,11.5,5.2],
			[Vector3(12.2,5.2,70.5),Color("9ab8c2"),1.60,11.0,6.4],
			[Vector3(24.8,5.6,89.2),Color("f2a050"),1.85,12.5,8.1],
			[Vector3(41.5,5.6,92.0),Color("94b0bc"),1.50,12.0,9.5],
			[Vector3(55.5,5.6,89.2),Color("f2a050"),1.85,12.5,11.3],
			[Vector3(70.5,5.2,72.0),Color("9ab8c2"),1.55,11.5,12.7],
			[Vector3(62.5,5.2,53.5),Color("f2a050"),1.65,11.5,14.1],
			[Vector3(57.8,5.6,33.5),Color("e8b88a"),1.75,12.0,15.6],
		]
		for spec: Array in flicker_specs:
			var lpos: Vector3 = spec[0]
			var lcol: Color = spec[1]
			var base_e: float = spec[2]
			var lrange: float = spec[3]
			var seed_v: float = spec[4]
			var bulb_mat := StandardMaterial3D.new()
			bulb_mat.albedo_color = lcol
			bulb_mat.emission_enabled = true
			bulb_mat.emission = lcol
			bulb_mat.emission_energy_multiplier = 2.0
			var lnode := _omni(root,"FreightFlickerLight",lpos,lcol,base_e,lrange,1.25,false)
			var bulkhead := lpos.z < 19.0 or (lpos.z > 84.0 and lpos.z < 91.0)
			var hood_at := Vector3(lpos.x, 3.55, 14.18 if lpos.z < 19.0 else 86.18) if bulkhead else lpos + Vector3.UP * .20
			var hood := M.box(root,"FlickerHood",Vector3(0.46,0.08,0.18),hood_at+Vector3(0,0.06,0),fittings.graphite)
			hood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var bulb := M.box(root,"FlickerBulb",Vector3(0.36,0.05,0.10),hood_at+Vector3(0,.064,.096),bulb_mat)
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			OPTICS.mark_fixture(hood, lnode, [bulb])
			freight_flicker_lights.append({
				"light": lnode,
				"base": base_e,
				"mat": bulb_mat,
				"seed": seed_v,
				"pos": Vector2(lpos.x, lpos.z),
				"killed": false,
			})
		for f_spot: Array in [
			[Vector3(28.1,6.4,91.0),Vector3(28.1,2.2,86.1),Color("ffc78f"),3.4,15.0,48.0],
			[Vector3(55.8,6.4,91.0),Vector3(55.8,2.2,86.1),Color("ffc78f"),3.4,15.0,48.0],
		]:
			_spot(root,"FreightButtressSpot",f_spot[0],f_spot[1],f_spot[2],float(f_spot[3]),float(f_spot[4]),float(f_spot[5]))
		freight_searchlight = FREIGHT.build_h06_searchlight(root)
		_finalize_freight_collapse_bays()


func _freight_bay_at_point(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for bay: Dictionary in freight_collapse_bays:
		var r: Rect2 = bay.rect
		if r.grow(0.22).has_point(p):
			var d := p.distance_squared_to(bay.center)
			if d < best_d:
				best_d = d
				best = bay
	return best


func _finalize_freight_collapse_bays() -> void:
	if freight_collapse_bays.is_empty():
		return
	var skip_prefixes := ["FreightBay_", "FreightAbyss", "FreightClutter", "FreightDynamicContainers", "UnstablePlate_", "FreightRamp", "RearCargoDoor", "FreightShutter"]
	var floor_children: Array[Node] = []
	for ch: Node in floor_root.get_children():
		floor_children.append(ch)
	for ch: Node in floor_children:
		if not (ch is Node3D):
			continue
		var cname := String(ch.name)
		var skip := false
		for pref: String in skip_prefixes:
			if cname.begins_with(pref):
				skip = true
				break
		if skip:
			continue
		var n3 := ch as Node3D
		if n3.position.y < -0.5 or n3.position.y > 4.2:
			continue
		var bay := _freight_bay_at_point(Vector2(n3.position.x, n3.position.z))
		if bay.is_empty() or bool(bay.retain_at_end):
			continue
		var pivot := bay.get("pivot") as Node3D
		if is_instance_valid(pivot):
			n3.reparent(pivot, true)
			(bay.attachments as Array).append(n3)
	for item: Dictionary in freight_clutter_entries:
		var c_node := item.get("node") as Node3D
		if not is_instance_valid(c_node):
			continue
		var bay := _freight_bay_at_point(item.center)
		if bay.is_empty() or bool(bay.retain_at_end):
			continue
		var pivot := bay.get("pivot") as Node3D
		if is_instance_valid(pivot):
			c_node.reparent(pivot, true)
			item["bay_id"] = bay.id
	for bay: Dictionary in freight_collapse_bays:
		bay["lights"] = []
	for fl: Dictionary in freight_flicker_lights:
		var bay := _freight_bay_at_point(fl.get("pos", Vector2.INF))
		if not bay.is_empty() and not bool(bay.retain_at_end):
			(bay.lights as Array).append(fl)


func tick_freight_effects(delta: float, time_sec: float) -> void:
	FREIGHT.tick_container_debris(delta, freight_debris)
	for fan: Node3D in freight_turbines:
		if is_instance_valid(fan):
			fan.rotation.z += delta * 1.45
	for fl: Dictionary in freight_flicker_lights:
		var light := fl.get("light") as OmniLight3D
		if not is_instance_valid(light):
			continue
		if bool(fl.get("killed", false)):
			light.light_energy = 0.0
			var m_dead := fl.get("mat") as StandardMaterial3D
			if m_dead != null:
				m_dead.emission_energy_multiplier = 0.0
			continue
		var s: float = fl.seed
		var t := time_sec + s
		var slow := 0.55 + 0.45 * sin(t * 2.7)
		var buzz := sin(t * 29.0) * cos(t * 43.0)
		var factor := slow
		if buzz < -0.52:
			factor = 0.08
		elif buzz > 0.62:
			factor = 1.32
		light.light_energy = float(fl.base) * factor
		var mat := fl.get("mat") as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = maxf(0.12, factor * 1.8)
