extends RefCounted
## Metres on the five-colour plan. Positive Z is south; both red visits occupy the same hangar.
const ATRIUM := preload("res://scripts/testing/h06_chapter/h06_base_layout.gd")
enum Region { GALLERY, WEST, FREIGHT, STAFF, ARENA }
enum Visit { GALLERY, WEST, EMPTY_HANGAR, FREIGHT, STAFF, ARENA }
const REGION_FOR_VISIT := [Region.GALLERY,Region.WEST,Region.GALLERY,Region.FREIGHT,Region.STAFF,Region.ARENA]
const LIFT_ENTRY := Vector2(38.,-8.)
const BRIDGE_WIDTH := 5.2
const BRIDGE_LENGTH := 17.0
const ARENA_BRIDGE := Rect2(LIFT_ENTRY-Vector2(BRIDGE_WIDTH*.5,0.),Vector2(BRIDGE_WIDTH,BRIDGE_LENGTH))
const ARENA_DECK := Rect2(LIFT_ENTRY-Vector2(14.,21.2),Vector2(28.,21.2))
const ARENA_DROP_HEIGHT := 13.5
const UPPER := {
	"spur":Rect2(7.5,4.5,4,3), "east":Rect2(3.5,-8.5,4,17), "north":Rect2(-8.5,-8.5,12,4),
	"206":Rect2(-7.05,-10.5,2,2), "observation":Rect2(-10.5,-22.5,19,12),
	"monitor_threshold":Rect2(-7.5,-23.75,4,1.25), "west_threshold":Rect2(-7.5,-25,4,1.25),
	"calibration":Rect2(-12.5,-37,17.5,12), "guard":Rect2(-26,-37,13.5,14.5),
	"inspection":Rect2(-46,-37,20,14.5), "archive":Rect2(-46,-22.5,17,19.5),
	"pump":Rect2(-29,-22.5,16.5,19.5), "stair":Rect2(-22,-3,7,9.5),
	"landing":Rect2(-25,6.5,14.2,3)
}
const LOWER := {
	"landing":Rect2(-25,6.5,14.2,3), "receiving":Rect2(-46,-3,21,12.5),
	"hangar":ATRIUM.BASE_SLAB_RECT, "bay_apron":Rect2(-12.5,3.55,1.7,5.95),
	"search":Rect2(-12.5,9.5,14.75,4.5),
	"understairs":Rect2(4.5,-.25,4,3.5), "secret_mouth":Rect2(8.5,.1,3,2.8),
	"secret":Rect2(11.5,-6.5,11.5,16),
	"west_bank":Rect2(-12.5,14,24,6.5), "pit":Rect2(-12.5,20.5,24,1.8),
	"east_bank":Rect2(-12.5,22.3,24,9.7), "sorting":Rect2(-12.5,32,24,23),
	"loading":Rect2(-9,55,31,12), "outbound":Rect2(7,67,15,19),
	"transfer_floor":Rect2(7,86,73,16), "inbound":Rect2(63,65,17,21),
	"return_dock":Rect2(54,55,26,10), "return_bay":Rect2(54,37,15,18),
	"dispatch":Rect2(47,26.5,22,10.5),"fire_door_apron":Rect2(47,37,7,6),
	"lockers":Rect2(38,22,9,17), "canteen":Rect2(25,22,13,9),
	"clinic":Rect2(25,31,7,8), "armory":Rect2(32,31,6,8),
	"duty":Rect2(25,13,22,9), "arena_link":Rect2(36.25,9,3.5,4),
	"arena":ARENA_DECK, "boarding_bridge":ARENA_BRIDGE
}
const VISIT_ROOMS := [
	["spur","east","north","206","observation","monitor_threshold","understairs","secret_mouth","secret"],
	["west_threshold","calibration","guard","inspection","archive","pump","stair","landing","receiving"],
	["hangar","bay_apron","search","secret_mouth","secret"],
	["west_bank","pit","east_bank","sorting","loading","outbound","transfer_floor","inbound","return_dock","return_bay","dispatch","fire_door_apron"],
	["lockers","canteen","clinic","armory","duty","arena_link"],["arena","boarding_bridge"]
]
const ENTRY_DEPTH := .58
const PASSAGES := [
	{"at":Vector2(-5.5,-23.75),"forward":Vector2.UP,"width":4.0,"height":3.04},
	{"at":Vector2(-10.8,8),"forward":Vector2.RIGHT,"width":3.0,"height":0.0},
	{"at":Vector2(.5,14),"forward":Vector2.DOWN,"width":3.5,"height":0.0},
	{"at":Vector2(47,34),"forward":Vector2.LEFT,"width":4.0,"height":0.0},
	{"at":Vector2(38,9),"forward":Vector2.UP,"width":3.5,"height":0.0}
]
const HATCH := Vector2(6.05,2.35)
const LADDER_FOOT := Vector2(6.05,1.40)
const SERVICE_FACADE_X := 9.08
const RETURN_AIR_WALLS := {
	"North": Rect2(-10.8,-9.5,14.3,5.05),
	"EastNorth": Rect2(3.5,-9.5,5.0,9.05),
	"EastSouth": Rect2(3.5,3.35,5.0,6.15)
}
const SERVICE_DECK := Rect2(11.5,-6.5,11.5,6.7)
const SERVICE_STEPS := Rect2(16.0,.2,2.6,1.65)
const SERVICE_RISE := .90
const MODEL_BENCH := Vector2(20.9,-2.43)
const SERVICE_FIXTURES := {
	"PressureTank":Rect2(12.35,-5.17,2.26,2.26), "OilDrums":Rect2(14.99,-6.13,1.82,1.07),
	"TwinSinks":Rect2(17.32,-6.25,2.76,.85), "SteelLockers":Rect2(20.47,-6.22,2.23,.89),
	"Cartons":Rect2(16.1,-4.67,1.24,.73), "PrototypeCart":Rect2(19.87,-3.03,2.06,1.20)}
const SERVICE_RAILS := [Rect2(11.65,.11,4.35,.15),Rect2(18.60,.11,4.25,.15)]
const CARGO_FRAME_X := [18.65,26.15,33.65,41.15]
const CARGO_FRAME_NORTH := 28.7
const CARGO_FRAME_SOUTH := 38.85
const CARGO_BRACED_BAYS := [0,2]
const CARGO_RAILS := [Rect2(20.80,30.55,5.40,.13),Rect2(27.10,30.55,3.80,.13),
	Rect2(36.85,30.55,3.80,.13),Rect2(21.6,36.6,6.55,.13),Rect2(39.10,36.6,4.40,.13)]
const CARGO_CAGE := Rect2(38.65,37.75,7.00,2.82)
const CARGO_PIPE_RACK := Rect2(20.4,26.2,8.8,1.25)
const SHIPMENT_FRAMES := [14.10,18.05,22.00]
const SHIPMENT_WEST := 33.40
const SHIPMENT_EAST := 43.10
const SHIPMENT_FENCE := Rect2(43.02,13.50,.16,9.55)
const SHIPMENT_RAILS := [Rect2(34.20,13.55,.15,3.22),Rect2(34.20,20.2,.15,2.82)]
const FORKLIFT_START := Vector2(-2.60,-30.50)
const FORKLIFT_HEADING := PI
const WEST_BOLLARD_RADIUS := 0.20
const WEST_STAIR_BOLLARDS: Array[Vector2] = [
	Vector2(-21.5, -3.70), Vector2(-20.3, -3.70), Vector2(-19.1, -3.70),
	Vector2(-17.9, -3.70), Vector2(-16.7, -3.70), Vector2(-15.5, -3.70)
]
const WATCH_FIXTURES := {
	"WindowHeater":Rect2(-10.25,-22.35,2.55,.72),
	"CameraDesk":Rect2(-3.20,-22.12,3.30,1.08),
	"UtilityFridge":Rect2(.26,-22.26,.98,.92),
	"OperatorDesk":Rect2(-4.05,-16.45,3.45,1.28),
	"CopierUnit":Rect2(-.52,-16.12,1.12,1.28),
	"CameraChair":Rect2(-1.78,-20.89,.68,.70), "OperatorChair":Rect2(-2.78,-15.02,.68,.70),
	"EquipmentRack":Rect2(-10.19,-19.82,.86,1.78),
	"RearPartition":Rect2(1.45,-22.48,.15,3.71), "FrontPartition":Rect2(1.45,-13.40,.15,2.90),
	"CredenzaBank":Rect2(1.88,-22.28,3.92,.90),
	"RecordStacks":Rect2(6.02,-22.28,2.28,.96), "DrawerBank":Rect2(7.32,-20.65,1.02,4.90),
	"SortingDesk":Rect2(3.62,-14.17,2.60,1.15), "OpenCrateStation":Rect2(6.62,-13.65,1.35,1.05),
	"CaseBoard":Rect2(4.55,-19.95,1.90,.56)
}
const RELAY_CONSOLE := Vector2(2.7,7.9)
const MEDICINE := Vector2(27.6,35.8)
const RACK := {"assault_rifle":Vector2(41.7,14.65),"shotgun":Vector2(43.5,14.45),"mp5":Vector2(45.3,14.65)}
const UPPER_GATES := ["calibration","pump"]
const GATE_VISIT := {"calibration":Visit.WEST,"pump":Visit.WEST,"cargo_access":Visit.EMPTY_HANGAR,"refuge":Visit.STAFF,"arena":Visit.ARENA,"boarding":Visit.ARENA}
const GATES := {
	"calibration":Rect2(-12.65,-32.2,.3,5.1),
	"pump":Rect2(-22,-3.15,7,.3),"cargo_access":Rect2(-1.25,13.84,3.5,.32),
	"refuge":Rect2(46.84,32,.32,4),"arena":Rect2(36.25,8.84,3.5,.32),
	"boarding":Rect2(LIFT_ENTRY-Vector2(BRIDGE_WIDTH*.5,.10),Vector2(BRIDGE_WIDTH,.20))
}
# Only the calibration checkpoint separates the entry bay from the continuous loop-connected warehouse floor.
const WEST_WALLS := [
	Rect2(-12.6,-37,.2,4.8),Rect2(-12.6,-27.1,.2,4.6)
]
const WEST_SHUTTER_BAYS := {
	"inspection": {"z": -28.8, "width": 4.6, "lower": false, "pocket_x": -49.2,
		"spawns": [[Vector2(-46.8, -29.6), "lucille"], [Vector2(-45.8, -28.8), "basic"], [Vector2(-46.6, -27.7), "lucille"]]},
	"archive": {"z": -14.8, "width": 4.8, "lower": false, "pocket_x": -49.2,
		"spawns": [[Vector2(-46.8, -15.6), "lucille"], [Vector2(-45.7, -14.0), "", &"scientist"]]},
	"receiving": {"z": 3.2, "width": 4.8, "lower": true, "pocket_x": -49.2,
		"spawns": [[Vector2(-46.8, 2.4), "lucille"], [Vector2(-45.6, 3.8), "basic"]]},
}
const STAFF_SCREENS := []
const LOW_GATE := Rect2(-6.4,38,3,.55)
# The animated H06 sweeps a 4.28 m radius at any yaw. Reserve the outer 37 cm for wall skins and clearance.
const CRAWLER_RADIUS := 4.65
const CRAWLER_HEIGHT := 3.50
const REAR_DOCK := Rect2(-12.5,3.55,12.0,10.45)
const REAR_GATE := Rect2(-12.4,13.86,10.9,.26)
const EXHIBIT_TRANSFER: Array[Vector2] = [Vector2(-3,1.6),Vector2(-3,4.8),Vector2(-4.20,6.6),
	Vector2(-5.10,8),Vector2(-6.0,9)]
const TRENCH_BRIDGE := Rect2(-12.5,20.5,11.2,1.8)
const HEAVY_GATE := Rect2(1.0,38,10.2,.55)
const PARTITIONS := [Rect2(-12.5,38,6.1,.55),Rect2(-3.4,38,4.4,.55),Rect2(11.2,38,.3,.55)]
const ROLLER := Rect2(54.65,46.4,3.9,1.1)
const BELT := Rect2(43,96.65,1.1,4.60)
const MACHINE_APRON := Rect2(52.45,26.5,11.10,16.0)
const MACHINE_RAMP := Rect2(52.45,-1.5,11.10,28.0)
const HOIST_DECK := Rect2(52.45,-11.15,11.10,9.65)
const HOIST_BRIDGE := Rect2(40.0,-10.9,12.45,10.8)
const HOIST_Y := 7.0
# Three work areas share one uninterrupted cross-dock floor. Line markings face the open aisle.
const CROSS_DOCK_BAYS := [Rect2(16,96.3,12,4.8),Rect2(35.2,86.5,13.4,2.25),Rect2(60,96.4,12,4.5)]
const PROPS := {
	"sample_table":[Rect2(-7.7,-29.1,3.1,1.15),.92],
	"desk":[Rect2(-21.8,-34.2,3.1,1.2),.95],
	"warehouse_rack_calib_e":[Rect2(1.4,-35.8,1.85,8.6),3.85],
	"warehouse_cargo_calib_sw":[Rect2(-11.8,-26.8,3.6,1.45),1.65],
	"warehouse_rack_guard_n":[Rect2(-24.2,-36.5,9.2,1.75),3.85],
	"warehouse_rack_guard_mid":[Rect2(-22.2,-26.0,5.4,1.80),3.85],
	"warehouse_cargo_insp_nw":[Rect2(-44.6,-35.2,4.0,1.50),1.15],
	"warehouse_rack_insp_mid":[Rect2(-36.8,-28.4,7.6,1.85),3.90],
	"warehouse_cargo_insp_s":[Rect2(-36.2,-25.4,6.2,1.75),1.85],
	"warehouse_rack_arch_nw":[Rect2(-45.2,-25.2,1.85,6.4),3.85],
	"warehouse_rack_arch_mid":[Rect2(-36.4,-21.5,6.2,1.85),3.90],
	"warehouse_cargo_arch_island":[Rect2(-35.8,-18.5,5.2,1.65),1.75],
	"warehouse_rack_arch_s1":[Rect2(-45.2,-11.4,1.85,6.2),3.90],
	"warehouse_rack_arch_s2":[Rect2(-36.4,-12.0,6.2,1.80),3.90],
	"warehouse_cargo_arch_sw":[Rect2(-42.5,-5.2,5.8,1.80),1.85],
	"warehouse_rack_pump_ne":[Rect2(-21.6,-20.0,4.8,1.85),3.90],
	"warehouse_cargo_pump_mid":[Rect2(-21.2,-17.2,4.2,1.55),1.80],
	"warehouse_silo":[Rect2(-14.7,-14.5,1.7,1.8),4.10],
	"warehouse_rack_recv_n":[Rect2(-42.5,-2.15,6.8,1.80),3.90],
	"warehouse_rack_recv_s":[Rect2(-34.2,2.0,6.4,1.85),3.90],
	"warehouse_cargo_recv":[Rect2(-41.8,5.8,5.8,2.00),1.80],
	"trailer":[Rect2(6.1,16,4.1,1.45),.82],"pallets":[Rect2(-11.95,32,1.6,3.2),.9],
	"cage_a":[Rect2(-11.55,35.25,2.05,2.25),1.7],"cage_b":[Rect2(-10.4,43,2,3.6),1.55],
	"trailer_long":[Rect2(-7.4,57,2.5,6),.85],"pallets_low":[Rect2(-7.7,64.1,3.1,2),1.35],
	"pallets_stack":[Rect2(-3.7,64.1,2.7,2),1.0],"pallets_out":[Rect2(19.35,72.4,2.6,5.4),1.2],
	"forklift":[Rect2(-4.04,-31.21,2.88,1.42),2.72],"cage_east":[Rect2(54.4,51.0,1.2,3.2),1.35],
	"cage_in":[Rect2(77.0,56.5,2.4,5.0),1.4],"cage_crossdock":[Rect2(10.5,97.4,3.6,2.4),1.2],
	"pallets_weigh":[Rect2(17.4,97.2,2.3,2.2),.65],"dispatch_vessels":[Rect2(62.3,98.1,6.4,1.45),1.25],
	"clinic_cot":[Rect2(25.5,37.3,2.4,1.05),.66],"clinic_cot_b":[Rect2(28.5,37.3,2.4,1.05),.66]
}
const WAVES := {
	"guard":[[Vector2(-17.8,-29.6),"lucille",&"engineer"],[Vector2(-22.2,-26.8),"basic"]],
	"inspection":[[Vector2(-46.8,-29.6),"lucille"],[Vector2(-45.8,-28.8),"basic"],[Vector2(-46.6,-27.7),"lucille"]],
	"archive":[[Vector2(-46.8,-15.6),"lucille"],[Vector2(-45.7,-14.0),"",&"scientist"]],
	"pump":[[Vector2(-26.8,-11.2),"basic"],[Vector2(-16.2,-14.5),"lucille",&"engineer"]]
}
const CHASE_PATH: Array[Vector2] = [EXHIBIT_TRANSFER[-1],Vector2(-6.95,12.4),Vector2(-6.95,25.4),Vector2(-5.25,27.6),
	Vector2(-.5,30.0),Vector2(5.9,34.45),Vector2(6.1,38),Vector2(6.1,57.7),
	Vector2(9.0,61.5),Vector2(13.15,63.3),Vector2(13.15,91.25),Vector2(70.4,91.25),
	Vector2(70.4,61),Vector2(63.6,59.5),Vector2(63.6,40.2),Vector2(61.8,36),Vector2(58,32)]
const FREIGHT_EXIT: Array[Vector3] = [Vector3(58,0,32),Vector3(58,0,26.5),
	Vector3(58,HOIST_Y,-1.5),Vector3(58,HOIST_Y,-5.5),Vector3(45.2,HOIST_Y,-5.5)]
const BOSS_MARK := LIFT_ENTRY-Vector2(0.,11.7)

## Functional CC0 multi-tier cargo docks & dockyard equipment framing 1-3 walkways (clear of H06 chassis).
const FREIGHT_CLUTTER: Array[Array] = [
	["equipment_skid", Rect2(8.8, 16.5, 2.4, 3.0), 1.60, 0.0, "slate"],
	["cable_drums", Rect2(-12.3, 24.0, 2.4, 3.4), 1.45, 5.0, "ochre"],
	["pipe_rack", Rect2(-12.3, 29.5, 2.4, 4.0), 1.55, 0.0, ""],
	["double_stack", Rect2(-12.3, 47.0, 2.5, 4.8), 4.20, 0.0, "olive"],
	["barrel_cluster", Rect2(9.0, 40.2, 2.2, 2.2), 1.35, 12.0, ""],
	["double_stack", Rect2(16.2, 56.0, 4.8, 2.3), 4.25, 0.0, "navy"],
	["crane_rack_cargo", Rect2(17.2, 60.8, 2.4, 4.8), 3.30, 0.0, "orange"],
	["equipment_skid", Rect2(-0.5, 63.4, 4.5, 2.2), 1.65, 4.0, "olive"],
	["pipe_rack", Rect2(7.1, 74.5, 2.0, 4.8), 1.60, 0.0, ""],
	["barrel_cluster", Rect2(7.6, 97.4, 2.2, 2.2), 1.35, 16.0, ""],
	["pipe_rack", Rect2(15.0, 97.4, 2.0, 2.4), 1.55, 0.0, ""],
	["barrel_cluster", Rect2(59.2, 97.2, 2.6, 2.4), 1.35, 22.0, ""],
	["double_stack", Rect2(68.5, 97.0, 5.8, 2.6), 4.40, 0.0, "orange"],
	["equipment_skid", Rect2(74.8, 97.0, 4.2, 2.5), 1.65, -6.0, "slate"],
	["double_stack", Rect2(74.4, 56.5, 2.4, 4.8), 4.25, 0.0, "navy"],
	["cable_drums", Rect2(74.5, 62.5, 2.2, 3.0), 1.45, -10.0, ""],
	["cable_drums", Rect2(66.5, 26.8, 2.2, 2.0), 1.45, -6.0, ""],
]

## CC0 container barricades along H06's pursuit corridor that H06 violently blows open during the chase.
const FREIGHT_BREAKABLES: Array[Dictionary] = [
	{"id": "fb_east_bank", "variant": "crane_rack_cargo", "rect": Rect2(-2.6, 28.9, 4.4, 2.2), "height": 2.35, "rot": 0.0, "tint": "orange"},
	{"id": "fb_sorting_main", "variant": "double_stack", "rect": Rect2(3.5, 44.2, 5.2, 2.3), "height": 4.20, "rot": 0.0, "tint": "ochre"},
	{"id": "fb_loading_cut", "variant": "crane_rack_cargo", "rect": Rect2(3.8, 55.3, 4.8, 2.2), "height": 2.75, "rot": 0.0, "tint": "orange"},
	{"id": "fb_transfer_w", "variant": "double_stack", "rect": Rect2(44.5, 89.8, 4.8, 2.2), "height": 4.10, "rot": 0.0, "tint": "slate"},
	{"id": "fb_transfer_e", "variant": "crane_rack_cargo", "rect": Rect2(58.5, 89.8, 4.8, 2.2), "height": 2.65, "rot": 0.0, "tint": "olive"},
	{"id": "fb_return_bay", "variant": "crane_rack_cargo", "rect": Rect2(61.3, 41.2, 2.6, 2.2), "height": 2.75, "rot": 0.0, "tint": "orange"},
]

## Grated floor zones initially walkable that H06 blasts apart with arcing missiles on approach, plunging into the abyss.
const FREIGHT_FRACTURES: Array[Dictionary] = [
	{"id": "frac_wb_bridge", "rect": Rect2(-12.5, 18.0, 11.2, 4.3), "cutout_rect": Rect2(-12.5, 18.0, 11.2, 4.3), "trigger_rect": Rect2(-12.5, 14.0, 12.2, 8.3), "eject_dir": Vector2(1.0, 0.0), "girders_x": [-8.2, -5.7]},
	{"id": "frac_eb_east", "rect": Rect2(3.1, 22.3, 8.4, 15.7), "cutout_rect": Rect2(3.1, 22.3, 8.4, 15.7), "trigger_rect": Rect2(0.2, 22.3, 11.3, 15.7), "eject_dir": Vector2(-1.0, 0.0), "girders_x": [4.9, 7.1]},
	{"id": "frac_out_east", "rect": Rect2(15.2, 67.0, 6.8, 19.0), "cutout_rect": Rect2(15.2, 67.0, 3.5, 19.0), "trigger_rect": Rect2(8.5, 64.5, 13.5, 21.5), "eject_dir": Vector2(-1.0, 0.0)},
	{"id": "frac_tf_mid", "rect": Rect2(28.6, 86.0, 6.4, 10.4), "cutout_rect": Rect2(28.6, 86.0, 6.4, 10.4), "trigger_rect": Rect2(22.2, 86.0, 18.0, 11.2), "eject_dir": Vector2(-1.0, 0.0), "twin_eject": true, "missiles": 2, "girders_z": [89.8, 92.7]},
	{"id": "frac_tf_se_belt", "rect": Rect2(40.3, 92.2, 18.5, 9.8), "cutout_rect": Rect2(40.3, 92.2, 18.5, 9.8), "trigger_rect": Rect2(35.0, 86.0, 22.0, 16.0), "eject_dir": Vector2(0.0, -1.0), "has_belt": true, "missiles": 2},
	{"id": "frac_inb_sw", "rect": Rect2(63.0, 77.0, 11.9, 9.0), "cutout_rect": Rect2(63.0, 77.0, 11.9, 9.0), "trigger_rect": Rect2(60.0, 72.0, 20.0, 20.0), "eject_dir": Vector2(1.0, 0.0), "girders_x": [69.0, 71.8], "missiles": 2},
	{"id": "frac_rb_west", "rect": Rect2(54.0, 42.0, 7.2, 14.8), "cutout_rect": Rect2(54.0, 42.0, 7.2, 14.8), "trigger_rect": Rect2(54.0, 38.0, 15.0, 24.0), "eject_dir": Vector2(1.0, 0.0), "has_roller": true},
]

## Overhead gantry-rigged multi-tier cargo modules & equipment skids that drop upon approaching remaining bay mouths.
const FREIGHT_DROPS: Array[Dictionary] = [
	# Zone 2: east_bank west crane bay
	{"id": "drop_eb_w_n", "variant": "double_stack", "rect": Rect2(-9.1, 22.3, 2.5, 7.8), "height": 4.25, "tint": "slate", "top_tint": "orange", "trigger_rect": Rect2(-12.5, 22.3, 9.5, 15.7), "zone_rect": Rect2(-12.5, 22.3, 5.9, 15.7), "eject_dir": Vector2(1.0, 0.0), "delay": 0.0},
	{"id": "drop_eb_w_s", "variant": "crane_rack_cargo", "rect": Rect2(-9.1, 30.0, 2.5, 8.0), "height": 3.15, "tint": "olive", "trigger_rect": Rect2(-12.5, 22.3, 9.5, 15.7), "zone_rect": Rect2(-12.5, 22.3, 5.9, 15.7), "eject_dir": Vector2(1.0, 0.0), "delay": 0.08},
	# Zone 4: sorting west crane bay
	{"id": "drop_sort_w_n", "variant": "double_stack", "rect": Rect2(-9.1, 38.5, 2.5, 8.4), "height": 4.30, "tint": "orange", "top_tint": "slate", "trigger_rect": Rect2(-12.5, 38.5, 10.5, 16.8), "zone_rect": Rect2(-12.5, 38.5, 5.9, 16.75), "eject_dir": Vector2(1.0, 0.0), "delay": 0.0},
	{"id": "drop_sort_w_s", "variant": "crane_rack_cargo", "rect": Rect2(-9.1, 46.8, 2.5, 8.45), "height": 3.15, "tint": "olive", "trigger_rect": Rect2(-12.5, 38.5, 10.5, 16.8), "zone_rect": Rect2(-12.5, 38.5, 5.9, 16.75), "eject_dir": Vector2(1.0, 0.0), "delay": 0.08},
	# Zone 5: sorting east crane divider & loading north cap
	{"id": "drop_sort_e_n", "variant": "double_stack", "rect": Rect2(-1.7, 38.5, 2.5, 8.4), "height": 4.25, "tint": "slate", "top_tint": "ochre", "trigger_rect": Rect2(-6.5, 38.5, 11.5, 19.5), "zone_rect": Rect2(-1.7, 38.5, 10.5, 18.7), "eject_dir": Vector2(-1.0, 0.0), "delay": 0.0},
	{"id": "drop_sort_e_s", "variant": "crane_rack_cargo", "rect": Rect2(-1.7, 46.8, 2.5, 8.4), "height": 3.20, "tint": "navy", "trigger_rect": Rect2(-6.5, 38.5, 11.5, 19.5), "zone_rect": Rect2(-1.7, 38.5, 10.5, 18.7), "eject_dir": Vector2(-1.0, 0.0), "delay": 0.08},
	{"id": "drop_load_cap", "variant": "equipment_skid", "rect": Rect2(0.7, 54.8, 3.3, 2.4), "height": 1.85, "tint": "orange", "trigger_rect": Rect2(-6.5, 48.0, 14.0, 15.0), "zone_rect": Rect2(0.7, 54.8, 8.0, 2.6), "eject_dir": Vector2(0.0, 1.0), "delay": 0.04},
	# Zone 7: transfer_floor southwest crane bay
	{"id": "drop_tf_sw_n1", "variant": "double_stack", "rect": Rect2(7.0, 92.2, 8.0, 2.35), "height": 4.35, "tint": "navy", "top_tint": "orange", "trigger_rect": Rect2(7.0, 84.5, 19.0, 17.5), "zone_rect": Rect2(7.0, 92.2, 16.0, 9.8), "eject_dir": Vector2(0.0, -1.0), "delay": 0.0},
	{"id": "drop_tf_sw_n2", "variant": "crane_rack_cargo", "rect": Rect2(14.9, 92.2, 8.1, 2.35), "height": 3.25, "tint": "slate", "trigger_rect": Rect2(7.0, 84.5, 19.0, 17.5), "zone_rect": Rect2(7.0, 92.2, 16.0, 9.8), "eject_dir": Vector2(0.0, -1.0), "delay": 0.06},
	{"id": "drop_tf_sw_e", "variant": "double_stack", "rect": Rect2(20.6, 94.45, 2.4, 7.6), "height": 4.20, "tint": "olive", "top_tint": "ochre", "trigger_rect": Rect2(15.0, 88.0, 13.5, 14.0), "zone_rect": Rect2(7.0, 92.2, 16.0, 9.8), "eject_dir": Vector2(1.0, 0.0), "delay": 0.05},
	# Zone 9-East: transfer_floor southeast multi-tier gantry bay
	{"id": "drop_tf_se_1", "variant": "double_stack", "rect": Rect2(58.7, 92.2, 7.2, 2.4), "height": 4.35, "tint": "ochre", "top_tint": "slate", "trigger_rect": Rect2(50.0, 86.0, 24.0, 16.0), "zone_rect": Rect2(58.7, 92.2, 21.3, 9.8), "eject_dir": Vector2(0.0, -1.0), "delay": 0.0},
	{"id": "drop_tf_se_2", "variant": "crane_rack_cargo", "rect": Rect2(65.8, 92.2, 7.2, 2.4), "height": 3.25, "tint": "orange", "trigger_rect": Rect2(56.0, 86.0, 24.0, 16.0), "zone_rect": Rect2(58.7, 92.2, 21.3, 9.8), "eject_dir": Vector2(0.0, -1.0), "delay": 0.06},
	{"id": "drop_tf_se_3", "variant": "double_stack", "rect": Rect2(72.9, 92.2, 7.1, 2.4), "height": 4.25, "tint": "navy", "top_tint": "olive", "trigger_rect": Rect2(62.0, 86.0, 18.0, 16.0), "zone_rect": Rect2(58.7, 92.2, 21.3, 9.8), "eject_dir": Vector2(0.0, -1.0), "delay": 0.11},
	# Zone 11: return_dock northeast gantry depot
	{"id": "drop_rd_s1", "variant": "crane_rack_cargo", "rect": Rect2(69.1, 68.6, 5.5, 2.4), "height": 3.20, "tint": "orange", "trigger_rect": Rect2(61.5, 55.0, 18.5, 23.0), "zone_rect": Rect2(69.1, 55.0, 10.9, 16.0), "eject_dir": Vector2(0.0, 1.0), "delay": 0.0},
	{"id": "drop_rd_s2", "variant": "equipment_skid", "rect": Rect2(74.5, 68.6, 5.5, 2.4), "height": 1.95, "tint": "slate", "trigger_rect": Rect2(61.5, 55.0, 18.5, 23.0), "zone_rect": Rect2(69.1, 55.0, 10.9, 16.0), "eject_dir": Vector2(0.0, 1.0), "delay": 0.05},
	{"id": "drop_rd_w1", "variant": "double_stack", "rect": Rect2(69.1, 55.0, 2.4, 6.9), "height": 4.30, "tint": "navy", "top_tint": "slate", "trigger_rect": Rect2(61.5, 55.0, 18.5, 23.0), "zone_rect": Rect2(69.1, 55.0, 10.9, 16.0), "eject_dir": Vector2(-1.0, 0.0), "delay": 0.09},
	{"id": "drop_rd_w2", "variant": "crane_rack_cargo", "rect": Rect2(69.1, 61.8, 2.4, 6.9), "height": 3.15, "tint": "olive", "trigger_rect": Rect2(61.5, 55.0, 18.5, 23.0), "zone_rect": Rect2(69.1, 55.0, 10.9, 16.0), "eject_dir": Vector2(-1.0, 0.0), "delay": 0.14},
	# Zone 13: dispatch north crane ramp apron
	{"id": "drop_disp_w", "variant": "crane_rack_cargo", "rect": Rect2(47.0, 29.0, 7.4, 2.4), "height": 3.20, "tint": "olive", "trigger_rect": Rect2(47.0, 26.5, 22.0, 12.0), "zone_rect": Rect2(47.0, 26.5, 22.0, 4.9), "eject_dir": Vector2(0.0, 1.0), "delay": 0.0},
	{"id": "drop_disp_m", "variant": "double_stack", "rect": Rect2(54.3, 29.0, 7.4, 2.4), "height": 4.35, "tint": "orange", "top_tint": "slate", "trigger_rect": Rect2(47.0, 26.5, 22.0, 12.0), "zone_rect": Rect2(47.0, 26.5, 22.0, 4.9), "eject_dir": Vector2(0.0, 1.0), "delay": 0.05},
	{"id": "drop_disp_e", "variant": "equipment_skid", "rect": Rect2(61.6, 29.0, 7.4, 2.4), "height": 2.00, "tint": "ochre", "trigger_rect": Rect2(47.0, 26.5, 22.0, 12.0), "zone_rect": Rect2(47.0, 26.5, 22.0, 4.9), "eject_dir": Vector2(0.0, 1.0), "delay": 0.10},
]

## Hanging CC0 containers outside catwalk edges that snap their crane cables and plunge tumbling into the abyss.
const FREIGHT_CHASM_DROPS: Array[Dictionary] = [
	{"id": "chasm_west_bank", "variant": "container", "pos": Vector3(-14.2, 2.2, 27.5), "size": Vector3(2.3, 2.25, 4.4), "tint": "orange", "min_y": 22.0, "max_y": 35.0, "min_x": -13.0, "max_x": 12.0},
	{"id": "chasm_sorting_east", "variant": "container_wide", "pos": Vector3(13.8, 2.6, 46.5), "size": Vector3(2.4, 2.35, 4.8), "tint": "slate", "min_y": 39.5, "max_y": 56.0, "min_x": -13.0, "max_x": 12.0},
	{"id": "chasm_outbound_west", "variant": "container_tall", "pos": Vector3(4.5, 2.6, 76.0), "size": Vector3(2.3, 2.70, 4.6), "tint": "ochre", "min_y": 67.0, "max_y": 86.0, "min_x": 6.5, "max_x": 22.5},
	{"id": "chasm_transfer_south", "variant": "container_wide", "pos": Vector3(33.5, 2.4, 104.2), "size": Vector3(5.0, 2.35, 2.4), "tint": "olive", "min_y": 86.0, "max_y": 103.0, "min_x": 20.0, "max_x": 55.0},
	{"id": "chasm_return_west", "variant": "container", "pos": Vector3(51.8, 2.4, 48.0), "size": Vector3(2.3, 2.25, 4.4), "tint": "navy", "min_y": 38.0, "max_y": 62.0, "min_x": 54.0, "max_x": 80.5},
]

static func visit_areas(visit: int, lower: bool) -> Dictionary:
	var source := LOWER if lower else UPPER
	var areas := {}
	for key: String in VISIT_ROOMS[visit]:
		if source.has(key): areas[key] = source[key]
	return areas

static func visit_contains(visit: int, p: Vector2, lower: bool) -> bool:
	var deck := LOWER if lower else UPPER
	for key: String in VISIT_ROOMS[visit]:
		if deck.has(key) and (deck[key] as Rect2).has_point(p): return true
	return false

static func behind_service_roof(feet: Vector2) -> bool:
	return LOWER.secret.has_point(feet) or (feet.x >= SERVICE_FACADE_X and LOWER.secret_mouth.has_point(feet))

static func passage_coordinates(index: int, p: Vector2) -> Vector2:
	var gate: Dictionary = PASSAGES[index]
	var direction: Vector2 = gate.forward
	var offset: Vector2 = p - gate.at
	return Vector2(offset.dot(direction),offset.dot(direction.orthogonal()))

static func visit_cells(visit: int) -> Dictionary:
	var cells := {}
	for key: String in VISIT_ROOMS[visit]:
		var r: Rect2 = UPPER[key] if UPPER.has(key) else LOWER[key]
		for z in range(ceili(r.position.y), ceili(r.end.y)):
			for x in range(ceili(r.position.x), ceili(r.end.x)): cells[Vector2i(x,z)] = &"building"
	if visit==Visit.WEST:
		# The rendered shutter pockets are real walkable floor. Their curtain
		# collision still blocks passage until the corresponding door opens.
		for bay:Dictionary in WEST_SHUTTER_BAYS.values():
			for z in range(ceili(float(bay.z)-float(bay.width)*.5),ceili(float(bay.z)+float(bay.width)*.5)):
				for x in range(ceili(float(bay.pocket_x)),-46):cells[Vector2i(x,z)]=&"building"
	return cells

static func contains(areas: Dictionary, point: Vector2) -> bool:
	for rect: Rect2 in areas.values():
		if rect.has_point(point): return true
	return false

static func upper_height(p: Vector2) -> float:
	if UPPER.stair.grow(.02).has_point(p):
		return ATRIUM.NW_GALLERY_Y*(1.-clampf((p.y-UPPER.stair.position.y)/UPPER.stair.size.y,0,1))
	if UPPER.landing.grow(.02).has_point(p): return 0
	if p.y < -8.5 or p.x < -8.5: return ATRIUM.NW_GALLERY_Y
	return ATRIUM.ground_height(p)

static func lower_height(p: Vector2) -> float:
	if SERVICE_DECK.has_point(p): return SERVICE_RISE
	if SERVICE_STEPS.has_point(p): return SERVICE_RISE*(SERVICE_STEPS.end.y-p.y)/SERVICE_STEPS.size.y
	return 0.0

## Neighbouring visits can share an entire side. Leave only the authored threshold open.
static func open_edge(edge: Array, visit: int, lower: bool) -> Array:
	var segments := [edge]
	var openings := []
	for index in [visit-1,visit]:
		if index<0 or index>=PASSAGES.size(): continue
		openings.append(PASSAGES[index])
	if visit==Visit.EMPTY_HANGAR and lower and edge[0]=="search" and edge[3]==Vector2.DOWN:
		openings.append({"at":Vector2(REAR_GATE.get_center().x,LOWER.search.end.y),"width":REAR_GATE.size.x,"forward":Vector2.DOWN,"height":0.})
	if visit==Visit.FREIGHT and lower and edge[3]==Vector2.UP:
		if edge[0]=="west_bank":
			openings.append({"at":Vector2(REAR_GATE.get_center().x,LOWER.west_bank.position.y),"width":REAR_GATE.size.x,"forward":Vector2.UP,"height":0.})
		if edge[0]=="dispatch":
			openings.append({"at":Vector2(MACHINE_RAMP.get_center().x,LOWER.dispatch.position.y),"width":MACHINE_RAMP.size.x,"forward":Vector2.UP,"height":0.})
	if visit==Visit.WEST:
		for bay: Dictionary in WEST_SHUTTER_BAYS.values():
			openings.append({"at":Vector2(-46.0,bay.z),"width":bay.width,"forward":Vector2.LEFT,"height":0.0 if bay.lower else 3.04})
	for door: Dictionary in openings:
		if (door.height==0.0)!=lower: continue
		var n: Vector2 = edge[3]
		if absf(n.dot(door.forward))<.99 or absf((door.at-edge[1]).dot(n))>.015: continue
		var along := Vector2.RIGHT if n.x==0 else Vector2.DOWN
		var mid := along.dot(door.at)
		var cut_lo: float = mid-door.width*.5
		var cut_hi: float = mid+door.width*.5
		var remaining := []
		for part: Array in segments:
			var lo := along.dot(part[1])
			var hi := along.dot(part[2])
			if cut_hi<=lo or cut_lo>=hi:
				remaining.append(part)
				continue
			if cut_lo>lo+.005: remaining.append([part[0],part[1],part[1]+along*(cut_lo-lo),n])
			if cut_hi<hi-.005: remaining.append([part[0],part[2]-along*(hi-cut_hi),part[2],n])
		segments=remaining
	return segments

## Obstacles as seen by the vehicle. Personnel-only security lines are not part of its road.
static func crawler_obstacles() -> Array[Rect2]:
	var floors := visit_areas(Visit.FREIGHT,true)
	floors["rear_dock"] = REAR_DOCK
	floors["ramp"] = MACHINE_RAMP
	floors["upper_dock"] = HOIST_DECK
	floors["hoist_bridge"] = HOIST_BRIDGE
	var result: Array[Rect2] = []
	for edge: Array in exterior_edges(floors):
		var a: Vector2 = edge[1]
		var b: Vector2 = edge[2]
		result.append(Rect2(a.min(b),(b-a).abs()).grow(.105))
	for name: String in PROPS:
		var r: Rect2 = PROPS[name][0]
		if visit_contains(Visit.FREIGHT,r.get_center(),true): result.append(r)
	result.append_array(PARTITIONS)
	result.append_array([LOW_GATE,ROLLER,BELT])
	var dock := LOWER.west_bank as Rect2
	var staff_door := GATES.cargo_access as Rect2
	result.append(Rect2(dock.position.x,dock.position.y-.10,REAR_GATE.position.x-dock.position.x,.20))
	result.append(Rect2(REAR_GATE.end.x,dock.position.y-.10,staff_door.position.x-REAR_GATE.end.x,.20))
	var pit: Rect2 = LOWER.pit
	result.append(Rect2(TRENCH_BRIDGE.end.x,pit.position.y,pit.end.x-TRENCH_BRIDGE.end.x,pit.size.y))
	return result

static func crawler_clear(p: Vector2, obstacles: Array[Rect2]) -> bool:
	if not (visit_contains(Visit.FREIGHT,p,true) or REAR_DOCK.has_point(p) or MACHINE_RAMP.has_point(p) or HOIST_DECK.has_point(p) or HOIST_BRIDGE.has_point(p)): return false
	for r: Rect2 in obstacles:
		if p.distance_squared_to(p.clamp(r.position,r.end))<CRAWLER_RADIUS*CRAWLER_RADIUS: return false
	return true

static func ramp_height(z: float) -> float:
	return HOIST_Y*clampf((MACHINE_RAMP.end.y-z)/MACHINE_RAMP.size.y,0.,1.)

static func skeleton() -> Dictionary:
	var cells := {}
	var bounds := Rect2i(ATRIUM.SPAWN_CELL, Vector2i.ONE)
	for rect: Rect2 in UPPER.values() + LOWER.values():
		for z in range(ceili(rect.position.y), ceili(rect.end.y)):
			for x in range(ceili(rect.position.x), ceili(rect.end.x)):
				cells["%d,%d" % [x,z]] = true
				bounds = bounds.merge(Rect2i(x,z,1,1))
	var extent := {"x":bounds.position.x, "y":bounds.position.y, "w":bounds.size.x, "h":bounds.size.y}
	return {"type":"H06_CHAPTER", "checks":{"ok":true}, "bounds":extent,
		"rooms":[{"id":"entry","label":"H06","kind":"open_office","bounds":extent,"cells":cells.keys()}],
		"anchors":{"entry":"10,6"}, "doors":[], "furniture":[], "enemies":[]}

## Keep a continuous wall wherever the rectangular floor pieces have no neighbour.
static func exterior_edges(areas: Dictionary) -> Array:
	var edges: Array = []
	for key: String in areas:
		var r: Rect2 = areas[key]
		for n: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var vertical := n.x != 0
			var at := (r.position.x if n.x < 0 else r.end.x) if vertical else (r.position.y if n.y < 0 else r.end.y)
			var lo := r.position.y if vertical else r.position.x
			var hi := r.end.y if vertical else r.end.x
			var cuts := PackedFloat64Array([lo, hi])
			for other: Rect2 in areas.values():
				for t: float in ([other.position.y,other.end.y] if vertical else [other.position.x,other.end.x]):
					if t > lo+.001 and t < hi-.001 and not cuts.has(t): cuts.append(t)
			cuts.sort()
			var start := INF
			for i in range(cuts.size()-1):
				var mid := (cuts[i]+cuts[i+1])*.5
				var p := Vector2(at,mid) if vertical else Vector2(mid,at)
				var exterior := not contains(areas,p+n*.015)
				if exterior and is_inf(start): start = cuts[i]
				if not is_inf(start) and (not exterior or i == cuts.size()-2):
					var stop := cuts[i+1] if exterior else cuts[i]
					var a := Vector2(at,start) if vertical else Vector2(start,at)
					var b := Vector2(at,stop) if vertical else Vector2(stop,at)
					edges.append([key,a,b,n])
					start = INF
	return edges
