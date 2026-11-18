extends RefCounted
## Authoritative layout, walkability, and elevation model for Level 1-1:
## Elevated suspended L-corridor (Arrow 1 -> Arrow 2 -> Arrow 3) above an open 1F base platform & exposed H06 bay.

const BASE_1F_Y := 0.00
const CORRIDOR_ENTRY_Y := 1.28
const NE_LANDING_Y := 2.24
const NW_GALLERY_Y := 3.04

# Walkable suspended corridor sections only (no stairs descending to 1F base platform)
const SPUR_ENTRY := Rect2i(8, 5, 4, 3)          # X:[8..11],   Z:[5..7]  -> [7.5..11.5]   x [4.5..7.5]   (Y=1.28)
const CORRIDOR_EAST := Rect2i(4, -8, 4, 17)     # X:[4..7],    Z:[-8..8] -> [3.5..7.5]    x [-8.5..8.5]  (1.28 -> 2.24)
const CORRIDOR_NORTH := Rect2i(-8, -8, 12, 4)   # X:[-8..3],   Z:[-8..-5]-> [-8.5..3.5]   x [-8.5..-4.5] (2.24 -> 3.04)

const ALL_SECTIONS: Array[Rect2i] = [
	SPUR_ENTRY,
	CORRIDOR_EAST,
	CORRIDOR_NORTH,
]

const SPAWN_CELL := Vector2i(10, 6)

# Visual 1F platform & exposed H06 floor bay bounds (no enclosing glass box)
const BASE_SLAB_RECT := Rect2(-10.8, -9.5, 19.3, 19.0) # X:[-10.8..8.5], Z:[-9.5..9.5]
const H06_BAY_RECT := Rect2(-7.8, -2.8, 9.6, 8.8)      # X:[-7.8..1.8],  Z:[-2.8..6.0]

# Suspended corridor stair flights
const EAST_STAIR_Z_START := 3.50
const EAST_STAIR_Z_END := -2.50
const EAST_STAIR_STEPS := 8

const NORTH_STAIR_X_START := 1.50
const NORTH_STAIR_X_END := -2.50
const NORTH_STAIR_STEPS := 6


static func is_walkable_cell(cell: Vector2i) -> bool:
	for rect: Rect2i in ALL_SECTIONS:
		if rect.has_point(cell):
			return true
	return false


static func ground_height(xz: Vector2) -> float:
	# Entry spur (Arrow 1) + East suspended corridor + ascending flight (Arrow 2)
	if xz.x >= 3.5:
		if xz.y >= EAST_STAIR_Z_START:
			return CORRIDOR_ENTRY_Y
		if xz.y <= EAST_STAIR_Z_END:
			return NE_LANDING_Y
		var t_east := clampf((EAST_STAIR_Z_START - xz.y) / (EAST_STAIR_Z_START - EAST_STAIR_Z_END), 0.0, 1.0)
		return lerpf(CORRIDOR_ENTRY_Y, NE_LANDING_Y, t_east)

	# North upper suspended gallery + upper stair flight (Arrow 3)
	if xz.x >= NORTH_STAIR_X_START:
		return NE_LANDING_Y
	if xz.x <= NORTH_STAIR_X_END:
		return NW_GALLERY_Y
	var t_north := clampf((NORTH_STAIR_X_START - xz.x) / (NORTH_STAIR_X_START - NORTH_STAIR_X_END), 0.0, 1.0)
	return lerpf(NE_LANDING_Y, NW_GALLERY_Y, t_north)


static func layout_source() -> Dictionary:
	var cells: Array[String] = []
	var seen := {}
	var min_x := 999
	var min_y := 999
	var max_x := -999
	var max_y := -999
	for rect: Rect2i in ALL_SECTIONS:
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, z)
				if seen.has(c):
					continue
				seen[c] = true
				cells.append("%d,%d" % [x, z])
				min_x = mini(min_x, x)
				min_y = mini(min_y, z)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, z)
	var bounds := {"x": min_x, "y": min_y, "w": max_x - min_x + 1, "h": max_y - min_y + 1}
	return {
		"type": "ATRIUM_LOOP_1_1",
		"checks": {"ok": true},
		"bounds": bounds,
		"rooms": [{
			"id": "entry",
			"label": "1-1 Endfield Hangar Corridor",
			"kind": "open_office",
			"cells": cells,
			"bounds": bounds,
		}],
		"anchors": {"entry": "%d,%d" % [SPAWN_CELL.x, SPAWN_CELL.y]},
		"doors": [],
		"furniture": [],
		"enemies": [],
	}
