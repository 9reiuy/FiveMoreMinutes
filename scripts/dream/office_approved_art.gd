extends Node3D
## One floor-owned art bundle; gameplay ownership stays in the existing world.
const FURNITURE = preload("res://scripts/dream/preview/furniture_texture_review.gd")
const FLOORS = preload("res://scripts/dream/preview/sample_floor_texture_review.gd")
const WALLS = preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
const CITY = preload("res://scripts/dream/preview/sample_neon_city.gd")
var world: Node
var furniture: Node
var floors: Node
var walls: Node
var city: Node

func _ready() -> void:
	for spec in [[FURNITURE, "FurnitureTextureReviewCoordinator"], [FLOORS, "SampleFloorTextureReview"], [WALLS, "SampleWallAndDesktopReview"], [CITY, "SampleNeonCity"]]:
		var component: Node = spec[0].new()
		component.name = spec[1]
		component.world = world
		component.production_mode = true
		add_child(component)
	furniture = get_node("FurnitureTextureReviewCoordinator")
	floors = get_node("SampleFloorTextureReview")
	walls = get_node("SampleWallAndDesktopReview")
	city = get_node("SampleNeonCity")
	refresh_assets()

func refresh_assets() -> void:
	if get_parent()!=world.office_art_root: return
	var trace: bool=bool(world.get_meta(&"test_trace_floor_generation",false))
	var timings: Dictionary={}
	var started:=Time.get_ticks_usec() if trace else 0
	# Floor plants create bridges first, then the same approved furniture textures.
	floors.refresh_assets()
	if trace:
		timings["floors_ms"]=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec()
	furniture.refresh_assets()
	if trace:
		timings["furniture_ms"]=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec()
	walls.refresh_assets()
	if trace:
		timings["walls_ms"]=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec()
	if not world.floor_cells.is_empty() and world.room_visibility != null:
		city._build()
	if trace:
		timings["city_ms"]=(Time.get_ticks_usec()-started)/1000.0
		timings["floor"]=world.floor_index
		print("OFFICE_ART_PREPARATION ",JSON.stringify(timings))
