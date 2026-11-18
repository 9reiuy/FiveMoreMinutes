extends Node3D
## Non-combat rooms behind the north walls. The wall's continuous gameplay collider owns the glass.
const M := preload("res://scripts/testing/maintenance_environment.gd")
const FITTINGS := preload("res://scripts/testing/h06_chapter/facility_fittings.gd")
const OFFICE := preload("res://scripts/dream/office_furniture_catalog.gd")
const ENGINEER := preload("res://art/Dream/enemy/Engineer.png")
const SCIENTISTS := [preload("res://art/Dream/enemy/Scientist.png"),preload("res://art/Dream/enemy/Scientist2.png")]
const ACTOR_CONFIG := preload("res://resources/demo_config.tres")
## Complete authored assemblies in column one, including the helmet and both feet.
const ENGINEER_PORTRAIT := Rect2(0,10,32,41)
const SCIENTIST_PORTRAIT := Rect2(0,0,32,35)
const PIXELS_PER_METRE := 32.0
const WINDOWS := {
	"calibration": Rect2(-11,-37,12,5.2), "inspection": Rect2(-42.5,-37,12,5.4),
	"west_bank": Rect2(2.65,14,8.3,5), "transfer_floor": Rect2(35,86,14,6)
}
var room: String
var viewing_area: Rect2
var started := false
var elapsed := 0.0
var actors: Array[Sprite3D] = []
var moving := Node3D.new()
var hoist_cable: MeshInstance3D
var indicator: MeshInstance3D
var signal_material: Material
var clear_material: Material

func build(key: String, height: float, art) -> void:
	room = key
	name = "Window_"+key
	var bay: Rect2 = WINDOWS[key]
	var w := bay.size.x
	var depth := bay.size.y
	var end := w*.5
	position = Vector3(bay.get_center().x,height,bay.position.y)
	viewing_area = Rect2(bay.position-Vector2(1,.05),Vector2(w+2,8.3))
	if key=="west_bank":
		# See dispatch from the entire freight doorway, including a straight run out of the hangar.
		viewing_area = Rect2(-1.30,14,12.85,5.85)
	var fittings: FITTINGS = art.fittings
	var is_warehouse := key in ["calibration","inspection"] and art.warehouse_floor != null
	var is_freight := key in ["west_bank","transfer_floor"] and art.freight_floor != null
	var floor_mat: Material = art.FREIGHT.materials().trench_steel if is_freight else (art.warehouse_floor if is_warehouse else fittings.floor_material(FITTINGS.Deck.LAB))
	var wall_mat: Material = art.freight_wall if is_freight and art.freight_wall != null else (art.warehouse_wall if is_warehouse and art.warehouse_wall != null else art.white)
	var end_mat: Material = wall_mat if (is_warehouse or is_freight) and wall_mat != art.white else art.charcoal
	var deck := M.box(self,"Floor",Vector3(w,.18,depth),Vector3(0,-.09,-depth*.5),floor_mat)
	fittings.set_grate(deck,Rect2(bay.position.x+.44,bay.position.y-depth+.49,1.20,depth-1.08))
	# The transfer gantry/motor reaches 3.35 m; its enclosure must clear it.
	var shell_h := 4.42 if is_warehouse else (3.70 if key=="transfer_floor" else 2.88)
	var shell_y := -.22 if is_warehouse else -.18
	art.boundary_wall(self,"BackWall",Rect2(-end-.10,-depth-.10,w+.20,.20),shell_y,shell_h,Vector2.UP,wall_mat)
	for side in [-1,1]:
		art.boundary_wall(self,"RoomEnd",Rect2(side*end-.10,-depth,.20,depth+.10),shell_y,shell_h,Vector2(side,0),end_mat)
		M.box(self,"WindowJamb",Vector3(.09,2.45,.13),Vector3(side*end,1.225,0),art.charcoal)
	if is_warehouse:
		art.boundary_wall(self,"WindowHeaderWall",Rect2(-end-.10,-.10,w+.20,.20),2.46,1.74,Vector2.UP,wall_mat)
		var top_black: Material = art.cutout.top_black
		var back_cap := M.box(self,"WindowBackCoping",Vector3(w+1.50,shell_h,.75),Vector3(0.0,shell_y+shell_h*.5,-depth-.46),top_black)
		back_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for side in [-1,1]:
			var side_cap := M.box(self,"WindowSideCoping",Vector3(.75,shell_h,depth+.85),Vector3(side*(end+.46),shell_y+shell_h*.5,-depth*.5-.42),top_black)
			side_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var roof_top := shell_y+shell_h
	if not is_warehouse:
		art.boundary_wall(self,"WindowHeaderWall",Rect2(-end-.10,-.10,w+.20,.20),2.46,roof_top-2.46,Vector2.UP,wall_mat)
	var roof := M.box(self,"TopBlackCeiling",Vector3(w+.20,.08,depth+.20),Vector3(0,roof_top-.04,-depth*.5),art.cutout.top_black)
	# A visual cut-plane closure, like the existing chapter TopBlack coping:
	# retain the original lighting and the full glass viewing aperture below.
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.cutout.register_mesh(roof)
	M.box(self,"Sill",Vector3(w,.28,.19),Vector3(0,.14,0),art.charcoal)
	M.box(self,"Headrail",Vector3(w,.09,.15),Vector3(0,2.42,0),art.charcoal)
	var glass := M.box(self,"Glass",Vector3(w-.12,2.1,.035),Vector3(0,1.34,0),art.m.glass_corridor_rail)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: float in [-w*.18,w*.18]:
		M.box(self,"Mullion",Vector3(.045,2.17,.08),Vector3(x,1.34,0),art.charcoal)
	fittings.service_canopy(self,Vector3(0,2.61,-depth+.49),w-.53,.69,90.)
	clear_material = art.m.exit_green
	signal_material = art.m.endfield_yellow_emit
	indicator = M.box(self,"StatusLamp",Vector3(.46,.18,.10),Vector3(end-.63,1.9,-depth+.12),clear_material)
	add_child(moving)
	actors.append(_worker(&"engineer",Vector3(-2.4,0,-1.9)))
	actors.append(_worker(&"scientist",Vector3(2.05,0,-2.7),WINDOWS.keys().find(room)%SCIENTISTS.size()))
	match room:
		"calibration":
			M.box(self,"TestBed",Vector3(3.4,.69,1.14),Vector3(0,.36,-3.0),art.charcoal)
			fittings.barrel(self,Vector3(0,.97,-3),2.1,.55)
			fittings.alignment_gate(self,Vector3(-end+1.07,0,-depth+.85),1.77,2.28)
			M.box(moving,"Scanner",Vector3(.18,.12,1.2),Vector3(0,1.35,-3),art.m.monitor_glow)
			M.box(moving,"Carriage",Vector3(.2,.98,.18),Vector3(0,.89,-3.53),art.amber)
			M.box(self,"ScanRail",Vector3(3.12,.07,.11),Vector3(0,.81,-3.57),art.amber)
		"inspection":
			M.box(moving,"Trolley",Vector3(1.25,.14,.84),Vector3(0,.29,-2.15),art.charcoal)
			fittings.fit(moving,FITTINGS.CARTON,Vector3(0,.67,-2.15),Vector3(.89,.62,.63))
			fittings.pipe_bank(self,Vector3(-end+2.35,0,-depth+.70),3.6,1.12,1.45)
			var sign := Vector3(.40,1.29,-depth+.27)
			M.box(self,"InspectionNumberPlate",Vector3(1.93,1.10,.036),sign,art.white)
			fittings.stencil(self,"02",sign+Vector3(0,0,.025),.92)
			for z: float in [-2.46,-1.83]:
				M.pipe(moving,Vector3(-.55,.32,z),Vector3(-.68,.93,z),.045,art.white)
				for x: float in [-.46,.46]:
					var wheel := M.cylinder(moving,"Caster",.135,.085,Vector3(x,.135,z),art.charcoal)
					wheel.rotation.x = PI*.5
			M.pipe(moving,Vector3(-.68,.93,-2.46),Vector3(-.68,.93,-1.83),.045,art.white)
			M.box(self,"LiftMouth",Vector3(1.55,1.95,.12),Vector3(end-1.05,.975,-depth+.12),art.charcoal)
		"west_bank":
			var desk := OFFICE.make_visual_for_style("workstation","approved_room")
			desk.name = "DutyWorkstation"
			desk.position = Vector3(-1,0,-3.8)
			add_child(desk)
			M.box(self,"EscapeDoor",Vector3(1.6,2,.15),Vector3(end-1,.99,-depth+.10),art.charcoal)
		"transfer_floor":
			M.box(self,"Gantry",Vector3(4.4,.2,.3),Vector3(0,3.2,-3.8),art.m.steel_beam if is_freight and art.m.steel_beam!=null else art.amber)
			M.box(self,"HoistMotor",Vector3(.60,.34,.7),Vector3(0,3.18,-3.55),art.charcoal)
			hoist_cable = M.box(self,"HoistCable",Vector3(.075,1,.075),Vector3(0,2.4,-3.3),art.charcoal if is_freight else art.white)
			for x: float in [-2.15,2.15]:
				M.box(self,"GantryPost",Vector3(.16,3.2,.22),Vector3(x,1.6,-3.8),art.charcoal)
			M.box(moving,"Cradle",Vector3(2.3,.13,1.25),Vector3(0,.16,-3.3),art.amber)
			fittings.barrel(moving,Vector3(0,.65,-3.3),1.76,.82,false,Color("4e5658") if is_freight else Color(.87,.85,.79),is_freight)
			M.box(moving,"Spreader",Vector3(1.8,.09,.10),Vector3(0,1.60,-3.3),art.amber)
			for x: float in [-.85,.85]:
				M.box(moving,"Sling",Vector3(.055,1.3,.055),Vector3(x,.93,-3.3),art.charcoal if is_freight else art.white)
	if is_freight:
		var fm: Dictionary = art.FREIGHT.materials()
		for rx: float in [-w * 0.34, w * 0.34]:
			M.box(self,"WindowRedRib",Vector3(0.54,2.55,0.34),Vector3(rx,1.28,-depth+0.18),fm.buttress_red)
		M.box(self,"WindowBackPipe",Vector3(w-0.4,0.26,0.26),Vector3(0,1.72,-depth+0.14),fm.pipe_rusted)
	_pose(0)
	set_physics_process(false)

func _worker(role: StringName, feet: Vector3, variant := 0) -> Sprite3D:
	var actor := Sprite3D.new()
	actor.name = "Engineer" if role==&"engineer" else "Scientist"
	actor.texture = ENGINEER if role==&"engineer" else SCIENTISTS[variant]
	actor.region_enabled = true
	actor.region_rect = ENGINEER_PORTRAIT if role==&"engineer" else SCIENTIST_PORTRAIT
	# Match the ordinary Player/Employee presentation scale, rather than
	# shrinking different-height portraits to a miniature fixed height.
	actor.pixel_size = float(ACTOR_CONFIG.player_visual_scale) / PIXELS_PER_METRE
	# Put the sole on the billboard pivot so it stays planted at every camera angle.
	actor.offset = Vector2(0,actor.region_rect.size.y*.5)
	actor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	actor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	actor.shaded = false
	actor.position = feet
	add_child(actor)
	return actor

func approach() -> void:
	if not started:
		started = true
		set_physics_process(true)

func finish() -> void:
	started = true
	elapsed = 4.5
	_pose(elapsed)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	elapsed = minf(4.5,elapsed+delta)
	_pose(elapsed)
	if elapsed>=4.5: set_physics_process(false)

func _walk(actor: Sprite3D, a: Vector2, b: Vector2, t: float) -> void:
	var progress := smoothstep(0,1,t)
	var at := a.lerp(b,progress)
	var step_lift := absf(sin(progress*a.distance_to(b)*4.4))*.022 if progress>0 and progress<1 else 0.
	actor.position = Vector3(at.x,step_lift,at.y)
	actor.flip_h = b.x>a.x

func _pose(t: float) -> void:
	match room:
		"calibration":
			moving.position.x = lerpf(-1.4,1.4,smoothstep(.55,3.6,t))
			_walk(actors[0],Vector2(-2.6,-1.85),Vector2(-1.65,-1.72),t/1.25)
			_walk(actors[1],Vector2(2.6,-2.95),Vector2(1.65,-2.3),(t-2.0)/1.6)
		"inspection":
			moving.position.x = lerpf(-2.15,2.45,smoothstep(.2,3.8,t))
			_walk(actors[0],Vector2(-3.15,-2.1),Vector2(1.45,-2.1),(t-.2)/3.6)
			_walk(actors[1],Vector2(2.0,-2.4),Vector2(3.8,-3.75),t/2.1)
		"west_bank":
			_walk(actors[0],Vector2(-1.8,-1.80),Vector2(3.56,-4.4),(t-.22)/2.4)
			_walk(actors[1],Vector2(.6,-1.65),Vector2(3.56,-4.4),(t-.85)/2.5)
			actors[0].visible = t<2.65
			actors[1].visible = t<3.38
		"transfer_floor":
			moving.position.y = 1.24*smoothstep(.7,3.7,t)
			var sling_top := moving.position.y+1.6
			hoist_cable.scale.y = 3.02-sling_top
			hoist_cable.position.y = (3.02+sling_top)*.5
			_walk(actors[0],Vector2(-2.6,-2.2),Vector2(-3.7,-3.5),t/1.5)
			_walk(actors[1],Vector2(1.9,-2.2),Vector2(3.6,-2.7),(t-.4)/2.0)
	indicator.material_override = signal_material if t>.35 and (t<3.8 or room=="west_bank") else clear_material
