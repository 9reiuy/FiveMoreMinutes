class_name OfficeSampleFloor
extends RefCounted

const BUILDER = preload("res://scripts/dream/office_level_pack_generator.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const LOGIC = preload("res://scenes/dream/props/desk.tscn")
const CHAIR_LOGIC = preload("res://scenes/dream/props/office_chair_01.tscn")
const ART_REVIEW_ROOMS := ["office", "conference", "pantry", "restroom", "manager", "archive", "server", "lounge", "reception", "lift"]

static func decoration_specs(key: String) -> Array:
	# Fixed small clusters beside furniture. No random scattering or traffic lanes.
	match key:
		"office": return [[0, 3.2, 8.0, .22], [0, 3.65, 8.3, -.3], [3, 10.9, 7.6, .15], [0, 4.7, 12.0, -.18]]
		"conference": return [[0, 3.5, 8.4, -.25], [0, 3.8, 8.75, .12]]
		"pantry": return [[5, 5.1, 1.7, 0.0], [0, 8.0, 8.8, .35]]
		"restroom": return [[0, 8.0, 6.0, .4], [5, 8.5, 6.5, 0.0]]
		"manager": return [[3, 3.0, 5.2, -.12], [0, 9.8, 5.2, .24]]
		"archive": return [[3, 2.8, 4.2, .08], [0, 8.1, 6.0, -.16]]
		"server": return [[15, 2.4, 4.1, 0.0], [15, 8.5, 6.1, 0.0]]
		"lounge": return [[12, 3.5, 5.1, -.13], [0, 7.5, 4.9, .18]]
		"reception": return [[0, 2.2, 5.1, -.08], [13, 7.0, 3.4, 0.0, 1.8, .55]]
		"lift": return [[13, 5.0, 3.0, 0.0, 2.0, .8, .055], [14, 5.0, 1.6, 0.0, 1.7, .8, .055]]
	return []

static func enemy_specs(key: String) -> Array:
	# Positions, facing and patrol roles are authored with the furniture, not
	# sampled from whatever floor space happens to remain.
	match key:
		"office": return [[2, 11, Vector2.RIGHT, "patrol"], [11, 11, Vector2.LEFT, "flank"], [7, 2, Vector2.DOWN, "guard"]]
		"conference": return [[3, 10, Vector2.UP, "flank"], [8, 3, Vector2.LEFT, "guard"]]
		"manager": return [[6, 6, Vector2.UP, "guard"]]
		"archive": return [[5.5, 3.8, Vector2.DOWN, "guard"], [6.8, 7.6, Vector2.LEFT, "flank"]]
		"server": return [[5.5, 4.0, Vector2.DOWN, "guard"], [6.5, 7.7, Vector2.LEFT, "flank"]]
		"pantry": return [[7, 3.5, Vector2.LEFT, "guard"]]
		"restroom": return [[3, 5, Vector2.UP, "guard"]]
		"lounge": return [[4, 9, Vector2.RIGHT, "guard"]]
	return []

static func furniture_specs(key: String) -> Array:
	match key:
		# Kenney chairDesk faces +Z at yaw zero; its 2D rotation is negated by
		# Furniture3DVisual. Zero therefore faces map-down, 180 map-up.
		"office": return [["workstation", 4.2, 5, 0], ["workstation", 4.2, 6.1, 180], ["workstation", 9.8, 5, 0], ["workstation", 9.8, 6.1, 180], ["chair", 4.2, 3.8, 0], ["chair", 4.2, 7.3, 180], ["chair", 9.8, 3.8, 0], ["chair", 9.8, 7.3, 180], ["workstation", 4, 12, 0], ["chair", 4.2, 13.3, 166], ["workstation", 10, 13, 180], ["chair", 10.2, 14.25, 163], ["cabinet", 2, 1, 0], ["cabinet_open", 11, 1, 0]]
		"conference": return [["table", 5.5, 7, 0], ["chair", 4.5, 5.5, 0], ["chair", 6, 5.5, 0], ["chair", 7.5, 5.5, 0], ["chair", 4.3, 8.7, 198], ["chair", 6, 8.5, 180], ["chair", 7.5, 8.5, 180], ["whiteboard", 6, 1, 0], ["cabinet", 10, 1.15, 0]]
		"manager": return [["workstation", 4, 3, 0], ["chair", 4, 4.2, 180], ["cabinet", 8.3, 1.2, 0], ["cabinet_open", 10.2, 1.2, 0], ["sofa", 9.2, 7.5, 180], ["coffee_table", 9.2, 5.7, 0]]
		"archive": return [["shelf", 1.8, 3.0, 315], ["shelf", 9.2, 3.0, 45], ["shelf", 1.8, 5.2, 315], ["shelf", 9.2, 5.2, 45], ["shelf", 1.8, 7.3, 315], ["shelf", 9.2, 7.3, 45], ["sorting_table", 5.5, 1.0, 0]]
		"server": return [["server", 3.2, 3.0, 315], ["server", 7.8, 3.0, 45], ["server", 3.2, 5.2, 315], ["server", 7.8, 5.2, 45], ["server", 3.2, 7.3, 315], ["server", 7.8, 7.3, 45]]
		"pantry": return [["fridge", 1.5, 1, 0], ["appliance_counter", 3, 1, 0], ["sink", 4.5, 1, 0], ["counter", 6, 1, 0], ["dining_table", 7, 6.5, 0], ["chair", 5.65, 6.5, 270], ["chair", 8.35, 6.5, 90], ["chair", 7, 8, 180]]
		"restroom": return [["partition", 4, 1.3, 0], ["toilet", 5, 1.2, 0], ["partition", 6, 1.3, 0], ["stall_door", 5.1, 2.4, 28], ["toilet", 7, 1.2, 0], ["partition", 8, 1.3, 0], ["stall_door", 7.1, 2.4, 28], ["washbasin", 8.6, 5.5, 0]]
		"lounge": return [["sofa", 5.1, 2.2, 0], ["coffee_table", 5.1, 4.6, 0], ["sofa", 5.1, 7.0, 180], ["shelf", 7.8, 1.2, 0], ["plant", 8.7, 7.8, 0]]
		"reception": return [["reception", 3, 3.5, 0], ["chair", 3, 2, 0], ["cabinet", 1.3, 1.2, 0], ["sofa", 11, 3.5, 0], ["coffee_table", 11, 5.1, 0], ["plant", 12.6, 1.2, 0]]
	return []

static func plan(room: Dictionary, doors: Array) -> Dictionary:
	var furniture: Array = []
	var rect: Rect2i = room.grid_rect
	var origin := Vector2(rect.position) * CATALOG.SCALE
	var enemies: Array = []
	for spec in enemy_specs(String(room.sample_key)):
		var position := origin + Vector2(spec[0], spec[1]) * CATALOG.SCALE
		var entry := {"type": &"employee", "ground_position": position, "initial_facing": spec[2], "tactical_role": spec[3]}
		if spec[3] == "patrol":
			entry["patrol_route"] = [position, origin + Vector2(6, 11) * CATALOG.SCALE, origin + Vector2(6, 14) * CATALOG.SCALE, origin + Vector2(2, 14) * CATALOG.SCALE]
		enemies.append(entry)
	for spec in furniture_specs(String(room.sample_key)):
		var local_rect: Rect2 = CATALOG.footprint(String(spec[0]))
		var scene_to_use: PackedScene = CHAIR_LOGIC if String(spec[0]) in ["chair", "office_chair"] else LOGIC
		furniture.append({"scene": scene_to_use, "office_kind": spec[0], "position": origin + Vector2(spec[1], spec[2]) * CATALOG.SCALE, "rotation": deg_to_rad(float(spec[3])), "collision_rect": local_rect, "half_extents": local_rect.size * .5})
	return {"success": true, "furniture_placements": furniture, "enemy_spawns": enemies, "drop_spawns": [], "functional_areas": [], "door_reservation_rects": preload("res://scripts/dream/otxo_room_layout_planner.gd").get_doorway_reservation_rects(doors)}

static func generate(rng: RandomNumberGenerator, _options: Dictionary = {}) -> Dictionary:
	var specs: Array[Dictionary] = []
	for entry in [
		["office", "open_office", Rect2i(-7, -8, 14, 16)],
		["north", "corridor", Rect2i(-11, -12, 22, 4)],
		["south", "corridor", Rect2i(-11, 8, 22, 4)],
		["west", "corridor", Rect2i(-11, -8, 4, 16)],
		["east", "corridor", Rect2i(7, -8, 4, 16)],
		["conference", "conference_large", Rect2i(-23, -12, 12, 14)],
		["manager", "manager", Rect2i(-23, 2, 12, 10)],
		["archive", "archive", Rect2i(-11, -22, 11, 10)],
		["server", "server", Rect2i(0, -22, 11, 10)],
		["pantry", "pantry", Rect2i(11, -12, 10, 10)],
		["restroom", "restroom", Rect2i(11, -2, 10, 8)],
		["lounge", "lounge", Rect2i(11, 6, 10, 10)],
		["reception", "reception", Rect2i(-7, 12, 14, 8)],
		["lift", "elevator_lobby", Rect2i(-5, 20, 10, 8)],
	]:
		specs.append({"key": entry[0], "kind": entry[1], "rect": entry[2]})
	var links := [
		["lift", "reception", -1, "double"], ["reception", "south", -2, "open"],
		["south", "west", -11, "open"], ["south", "east", 7, "open"],
		["north", "west", -11, "open"], ["north", "east", 7, "open"],
		["office", "west", -3, "open"], ["office", "east", 2, "open"],
		["conference", "west", -6, "double"], ["manager", "west", 4, "single"],
		["archive", "north", -8, "single"], ["server", "north", 5, "single"],
		["pantry", "east", -6, "single"], ["restroom", "east", 1, "single"],
		["lounge", "south", 9, "single"],
	]
	return BUILDER.build_from_specs(rng, &"authored_sample", specs, links, [])
