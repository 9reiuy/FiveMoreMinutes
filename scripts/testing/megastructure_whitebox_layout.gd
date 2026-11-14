extends RefCounted
## Original 12x38 m whitebox, turned into a 38x12 m left-to-right level.
## The two boundaries below retain the original funnels and three alcoves.
const WEST := [Vector2(0,0),Vector2(0,8),Vector2(4,10),Vector2(4,12),Vector2(2.5,13),Vector2(2.5,14),Vector2(4,15),Vector2(4,22),Vector2(2.5,23),Vector2(2.5,24),Vector2(4,25),Vector2(4,28),Vector2(0,30),Vector2(0,38)]
const EAST := [Vector2(12,0),Vector2(12,8),Vector2(8,10),Vector2(8,17),Vector2(9.5,18),Vector2(9.5,19),Vector2(8,20),Vector2(8,28),Vector2(12,30),Vector2(12,38)]
const EASTER_EGG := preload("res://scripts/testing/level01_easter_layout.gd")

static func horizontal(point: Vector2) -> Vector2:
	return Vector2(37.5-point.y,point.x-.5)

static func outline() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in WEST: polygon.append(horizontal(point))
	for index in range(EAST.size()-1,-1,-1): polygon.append(horizontal(EAST[index]))
	return polygon

static func solid_boundaries() -> Array[PackedVector2Array]:
	# Close each side outside its inner contour, never across playable floor.
	var north := PackedVector2Array([Vector2(38,-1),Vector2(-1,-1)])
	for index in range(WEST.size()-1,-1,-1): north.append(horizontal(WEST[index]))
	var south := PackedVector2Array([Vector2(-1,12),Vector2(38,12)])
	for point in EAST: south.append(horizontal(point))
	return [north,south]

static func build() -> Dictionary:
	var data := {"type":"MEGASTRUCTURE_HORIZONTAL", "checks":{"ok":true},
		"bounds":{"x":0,"y":0,"w":38,"h":12}, "rooms":[], "anchors":{},
		"doors":[], "furniture":[], "enemies":[], "decor":[], "corridorSegments":[]}
	var specs := [["entry","01 左侧入场","reception",Rect2i(0,0,8,12)],
		["corridor","02 战术走廊","open_office",Rect2i(8,0,22,12)],
		["arena","03 右侧交战与出口","open_office",Rect2i(30,0,8,12)]]
	var playable := outline()
	for spec in specs:
		var rect: Rect2i = spec[3]
		var cells: Array[String] = []
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if Geometry2D.is_point_in_polygon(Vector2(x,y),playable): cells.append("%d,%d" % [x,y])
		data.rooms.append({"id":spec[0],"label":spec[1],"kind":spec[2],"cells":cells,
			"bounds":{"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}})
		data.anchors[spec[0]]="%d,6" % rect.get_center().x
	data.doors=[{"a":"entry","b":"corridor","vertical":true,"line":8,"start":4,"width":4,"glass":false,"open":true},
		{"a":"corridor","b":"arena","vertical":true,"line":30,"start":4,"width":4,"glass":false,"open":true}]
	# Keep the original room anchors, encounter bounds and 38m main route.
	# The optional unlit floor belongs to the same entry region for unloading.
	for y in EASTER_EGG.HEIGHT:
		for x in range(EASTER_EGG.MIN_X,0): data.rooms[0].cells.append("%d,%d" % [x,y])
	data.bounds = {"x":EASTER_EGG.MIN_X,"y":0,"w":38-EASTER_EGG.MIN_X,"h":12}
	# Maintenance equipment is authored by maintenance_environment.gd. No office
	# catalog or random furniture placement is used by this enclosed service level.
	return data

static func encounter(room: String) -> Array:
	var slots := {"corridor":[[16.125,5.5,"employee","lucille"],
		[21.75,5.5,"employee","lucille"],[27.375,5.5,"employee","lucille"]],
		"arena":[[35,5.5,"employee","basic"]]}
	var result: Array=[]
	for slot in slots.get(room,[]):
		result.append({"type":StringName(slot[2]),"weapon_id":slot[3],"skin_index":0,
			"ground_position":Vector2(slot[0],slot[1])*32.0,"initial_facing":Vector2.LEFT,"badge_carrier":false})
	return result
