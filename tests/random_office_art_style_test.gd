extends SceneTree

const THEME = preload("res://scripts/dream/dream_room_environment_theme.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const DECOR = preload("res://scripts/dream/office_random_room_decor.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	for archetype in ["open_office", "small_office", "meeting_small", "conference_large", "manager", "archive", "server", "pantry", "restroom", "lounge", "reception", "storage", "printing", "elevator_lobby", "corridor"]:
		var room := {"id": 3, "archetype": archetype, "grid_rect": Rect2i(2, 5, 12, 8), "office_visual_style": THEME.style_for_room({"archetype": archetype})}
		_check(not THEME.approved_key(room).is_empty(), archetype + " approved material mapping")
		_check(THEME.get_sample_base_floor_material(room) != null, archetype + " floor available")
		var walls: Dictionary = {}
		var states: Dictionary = {}
		for x in range(2, 14):
			var edge_key := "H:%d:5" % x
			walls[edge_key] = {"axis": "H", "x": x, "y": 5}
			states[edge_key] = "GLASS_WINDOW" if x == 3 else "WALL"
		var fixture: Node3D = DECOR.build(room, [{"outward": Vector2i.UP, "inside_cell": Vector2i(6, 5), "opening_cells": 2}], walls, .5, states)
		_check(fixture.get_child_count() > 0 or archetype == "open_office", archetype + " available solid wall receives fixture")
		for child in fixture.get_children():
			var mesh := child as MeshInstance3D
			_check(mesh != null and is_equal_approx(mesh.position.z, 4.7925), archetype + " fixture back .02 from wall face")
			_check(mesh.position.x != 3, archetype + " fixture cannot mount on glass")
			_check(Vector2(mesh.position.x, mesh.position.z).distance_to(Vector2(6, 5)) >= 2.5, archetype + " fixture outside door clearance")
		fixture.free()
		_check(not room.has("authored_sample"), archetype + " sample identity untouched")
	for kind in CATALOG.DEFINITIONS:
		var approved: Node3D = CATALOG.make_visual_for_style(kind, "approved_room")
		_check(approved != null and approved.get_child_count() > 0, kind + " approved visual available")
		approved.free()
	var office := {"archetype": "open_office", "office_visual_style": "approved_office"}
	var sample := {"archetype": "open_office", "authored_sample": true, "sample_key": "office"}
	_check(THEME.get_sample_base_floor_material(office) == THEME.get_sample_base_floor_material(sample), "approved office shares accepted floor")
	_check(THEME.get_sample_wall_material(office) == THEME.get_sample_wall_material(sample), "approved office shares accepted wall")
	_check_mount_faces()
	print("RANDOM_ART_STYLE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _check_mount_faces() -> void:
	var room := {"id": 5, "archetype": "lounge", "office_visual_style": "approved_room", "grid_rect": Rect2i(2, 5, 12, 12)}
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var walls: Dictionary = {}
		var states: Dictionary = {}
		var horizontal: bool = direction.y != 0
		var start := 2 if horizontal else 5
		for slot in range(start, start + 12):
			var cell := Vector2i(slot, 5 if direction.y < 0 else 16) if horizontal else Vector2i(2 if direction.x < 0 else 13, slot)
			var edge: Dictionary = DECOR.EDGES._edge_from_inside(cell, direction)
			var edge_key: String = DECOR.EDGES._edge_key(edge)
			walls[edge_key] = edge
			states[edge_key] = "WALL"
		var inside := Vector2i(6, 5 if direction.y < 0 else 16) if horizontal else Vector2i(2 if direction.x < 0 else 13, 9)
		var fixture: Node3D = DECOR.build(room, [{"outward": direction, "inside_cell": inside}], walls, .5, states)
		_check(fixture.get_child_count() == 1, "wall direction %s has mount" % direction)
		if fixture.get_child_count() == 1:
			var display := fixture.get_child(0) as MeshInstance3D
			var expected: float = 4.7925 if direction.y < 0 else 16.2075 if direction.y > 0 else 1.7925 if direction.x < 0 else 13.2075
			_check(is_equal_approx(display.position.z if horizontal else display.position.x, expected), "wall direction %s correct face plane" % direction)
		fixture.free()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
