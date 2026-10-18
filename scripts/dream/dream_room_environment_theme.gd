class_name DreamRoomEnvironmentTheme
extends RefCounted

## DreamRoomEnvironmentTheme
## Maps room archetypes to distinct floor, wall, and accent materials/patterns.
## Preserves deterministic caching and Compatibility renderer constraints.

const FLOOR_B_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_pixel_light_material.tres")
const FLOOR_A_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_a_pixel_light_material.tres")
const CONFERENCE_CARPET_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_conference_carpet_material.tres")
const STORAGE_ACCENT_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_storage_accent_material.tres")
const LOUNGE_ACCENT_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_lounge_accent_material.tres")
const WALL_A_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_wall_pixel_light_material.tres")
const WALL_B_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_wall_b_pixel_light_material.tres")

static func get_base_floor_material(archetype: String) -> Material:
	return _office_material(archetype, false)

static var _office_materials: Dictionary = {}
static var _sample_lounge_rug: Material
static var _sample_floors: Dictionary = {}

const SAMPLE_FLOOR_COLORS := {
	"office": Color(.34, .39, .44),
	"conference": Color(.34, .36, .39),
	"manager": Color(.39, .36, .33),
	"archive": Color(.52, .49, .44),
	"server": Color(.48, .53, .56),
	"pantry": Color(.56, .58, .53),
	"restroom": Color(.57, .62, .59),
	"lounge": Color(.43, .40, .37),
	"reception": Color(.52, .53, .51),
	"lift": Color(.49, .52, .53),
}

static func style_for_room(room: Dictionary) -> String:
	return "approved_office" if String(room.get("archetype", "")) in ["open_office", "office"] else "approved_room"

static func approved_key(room: Dictionary) -> String:
	if bool(room.get("authored_sample", false)):
		return String(room.get("sample_key", ""))
	if String(room.get("office_visual_style", "")) not in ["approved_office", "approved_room"]:
		return ""
	var archetype := String(room.get("archetype", ""))
	match archetype:
		"open_office", "office": return "office"
		"conference_large", "meeting_small", "conference": return "conference"
		"small_office", "manager", "executive": return "manager"
		"storage", "archive": return "archive"
		"elevator_lobby": return "lift"
		"printing": return "reception"
		_: return archetype

static func get_sample_base_floor_material(room: Dictionary) -> Material:
	var archetype := String(room.get("archetype", ""))
	var key := approved_key(room)
	if key.is_empty():
		return get_base_floor_material(archetype)
	if not bool(room.get("authored_sample",false)):
		var cache_key := "hard_"+key
		if not _sample_floors.has(cache_key):
			var color: Color = SAMPLE_FLOOR_COLORS.get(key,profile(archetype).floor)
			var style := "wet_tiles" if key in ["pantry","restroom"] else "office_tiles"
			_sample_floors[cache_key]=preload("res://scripts/dream/office_pixel_materials.gd").make(color,style)
		return _sample_floors[cache_key]
	if key == "office" and preload("res://scripts/dream/office_low_pixel_art.gd").enabled:
		return preload("res://scripts/dream/office_low_pixel_art.gd").surface("floor")
	if not SAMPLE_FLOOR_COLORS.has(key):
		return get_base_floor_material(archetype)
	if not _sample_floors.has(key):
		var style := "floor_carpet" if key in ["office", "conference", "manager", "lounge"] else "floor_tile"
		var material := preload("res://scripts/dream/office_pixel_materials.gd").make(SAMPLE_FLOOR_COLORS[key], style)
		_sample_floors[key] = material
	return _sample_floors[key]

static var _sample_office_wall: Material

static func get_sample_wall_material(room: Dictionary) -> Material:
	var archetype := String(room.get("archetype", ""))
	if approved_key(room) != "office":
		var key := approved_key(room)
		return get_wall_material(key if not bool(room.get("authored_sample", false)) and not key.is_empty() else archetype)
	if preload("res://scripts/dream/office_low_pixel_art.gd").enabled:
		return preload("res://scripts/dream/office_low_pixel_art.gd").surface("wall")
	return get_wall_material(archetype)

static func profile(archetype: String) -> Dictionary:
	var floor_color := Color(.34, .39, .44)
	var wall_color := Color(.66, .68, .67)
	var pattern := 1
	var light := Color(.96, .97, 1.0)
	match archetype:
		"conference", "conference_large", "meeting_small":
			floor_color = Color(.27, .29, .32)
			wall_color = Color(.57, .52, .45)
		"small_office":
			floor_color = Color(.35, .40, .36)
		"manager", "executive", "lounge":
			floor_color = Color(.37, .32, .28)
			wall_color = Color(.66, .60, .50)
			light = Color(1.0, .91, .79)
		"pantry":
			floor_color = Color(.58, .56, .49)
			wall_color = Color(.58, .66, .59)
			pattern = 2
			light = Color(1.0, .96, .86)
		"restroom":
			floor_color = Color(.58, .63, .61)
			wall_color = Color(.48, .59, .53)
			pattern = 2
		"archive", "storage":
			floor_color = Color(.40, .38, .33)
			pattern = 4
		"server":
			floor_color = Color(.25, .29, .33)
			pattern = 4
			light = Color(.85, .93, 1.0)
		"printing", "reception", "elevator_lobby", "corridor":
			floor_color = Color(.50, .52, .51)
			pattern = 4
	return {"floor": floor_color, "wall": wall_color, "pattern": pattern, "light": light}

static func _office_material(archetype: String, wall: bool) -> Material:
	var key := archetype + ("_wall" if wall else "_floor")
	if not _office_materials.has(key):
		var data := profile(archetype)
		var style := "paint" if wall else ("fabric" if data.pattern == 1 else ("wood" if data.pattern == 3 else "tile"))
		var material := preload("res://scripts/dream/office_pixel_materials.gd").make(data.wall if wall else data.floor, style)
		if wall:
			material = material.duplicate()
			material.set_shader_parameter("wall_surface", true)
		_office_materials[key] = material
	return _office_materials[key]

static func _legacy_base_floor_material(archetype: String) -> Material:
	match archetype:
		"open_office", "office":
			return FLOOR_B_MATERIAL
		"conference", "lounge", "executive", "storage":
			return FLOOR_A_MATERIAL
		_:
			return FLOOR_B_MATERIAL

static func get_accent_floor_material(archetype: String) -> Material:
	match archetype:
		"conference":
			# Conference uses custom deep cold-gray wool carpet for boardroom table zone
			return CONFERENCE_CARPET_MATERIAL
		"lounge", "executive":
			# Lounge uses custom bordered mat material
			return LOUNGE_ACCENT_MATERIAL
		"storage":
			# Storage uses custom low-contrast boundary line material
			return STORAGE_ACCENT_MATERIAL
		_:
			return FLOOR_B_MATERIAL

static func get_sample_accent_floor_material(room: Dictionary) -> Material:
	if not bool(room.get("authored_sample",false)) and approved_key(room) in ["lounge","manager","reception"]:
		return preload("res://scripts/dream/office_pixel_materials.gd").make(Color(.54,.44,.34),"rug")
	if approved_key(room) == "lounge":
		if _sample_lounge_rug == null:
			_sample_lounge_rug = preload("res://scripts/dream/office_pixel_materials.gd").make(Color(.44, .41, .37), "fabric")
		return _sample_lounge_rug
	var key := approved_key(room)
	return get_accent_floor_material(key if not key.is_empty() else String(room.get("archetype", "")))

static func get_wall_material(archetype: String) -> Material:
	return _office_material(archetype, true)

static func _legacy_wall_material(archetype: String) -> Material:
	match archetype:
		"open_office", "office", "conference", "lobby":
			return WALL_A_MATERIAL
		"lounge", "executive", "storage", "security":
			return WALL_B_MATERIAL
		_:
			return WALL_A_MATERIAL

static func has_accent_pattern(archetype: String) -> bool:
	return archetype in ["conference", "lounge", "executive", "storage"]

static func is_accent_cell(cell: Vector2i, room: Dictionary, functional_areas: Variant = null) -> bool:
	var archetype := String(room.get("archetype", ""))
	if not bool(room.get("authored_sample", false)):
		var key := approved_key(room)
		if not key.is_empty():
			archetype = key
		# Carpet follows actual seating groups, not room centre or vacant floor only.
		if not key.is_empty():
			if key not in ["lounge","manager","reception"] or String(room.get("sample_key",""))=="smoking": return false
			if functional_areas is Array:
				for area in functional_areas:
					if area is Dictionary and area.get("category","")=="seating":
						var center: Vector2i=area.center_cell
						if Rect2i(center-Vector2i.ONE,Vector2i(3,3)).has_point(cell):
							return (room.get("shape_cells",[]) as Array).has(cell)
			return false
	if not has_accent_pattern(archetype):
		return false
	if bool(room.get("authored_sample", false)) and String(room.get("sample_key", "")) == "lounge":
		var rug_rect := Rect2i(room.grid_rect.position + Vector2i(1, 2), Vector2i(5, 4))
		return rug_rect.has_point(cell) and (room.get("usable_cells", []) as Array).has(cell)

	var usable: Array = room.get("usable_cells", [])
	if usable.is_empty() or not usable.has(cell):
		return false

	if functional_areas is Array:
		for area_var in (functional_areas as Array):
			if area_var is Dictionary:
				var area: Dictionary = area_var
				var cat := String(area.get("category", ""))
				var center_c: Vector2i = area.get("center_cell", Vector2i.ZERO)
				if archetype == "conference" and cat == "conference_table":
					var rug_rect := Rect2i(center_c - Vector2i(2, 1), Vector2i(5, 3))
					if rug_rect.has_point(cell):
						return true
				elif archetype in ["lounge", "executive"] and cat == "seating":
					var mat_rect := Rect2i(center_c - Vector2i(1, 1), Vector2i(3, 3))
					if mat_rect.has_point(cell):
						return true
				elif archetype == "storage" and (cat == "storage" or cat == "cargo_cluster"):
					var cargo_rect := Rect2i(center_c - Vector2i(1, 1), Vector2i(3, 3))
					if cargo_rect.has_point(cell):
						return true
	elif functional_areas is Dictionary:
		var accent_rects_variant: Variant = (functional_areas as Dictionary).get("accent_rects", [])
		if accent_rects_variant is Array:
			for r in (accent_rects_variant as Array):
				if r is Rect2i and (r as Rect2i).has_point(cell):
					return true

	# Fallback geometric heuristic based on center_cell if layout plan didn't supply explicit rects
	var center_c: Vector2i = room.get("center_cell", Vector2i.ZERO)
	match archetype:
		"conference":
			var rug_rect := Rect2i(center_c - Vector2i(2, 1), Vector2i(5, 3))
			return rug_rect.has_point(cell)
		"lounge", "executive":
			var mat_rect := Rect2i(center_c - Vector2i(1, 1), Vector2i(3, 3))
			return mat_rect.has_point(cell)
		"storage":
			var cargo_rect := Rect2i(center_c - Vector2i(1, 1), Vector2i(3, 3))
			return cargo_rect.has_point(cell)

	return false
