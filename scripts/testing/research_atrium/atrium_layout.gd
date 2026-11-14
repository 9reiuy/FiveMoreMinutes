extends RefCounted
## Current user sketch: short side entrance, right-hand run, then upper run.
## The two short flights remain on the same level instead of reaching a lower floor.
const PATH := [Vector2(10,7),Vector2(7,7),Vector2(7,-7),Vector2(-7,-7)]
const RECTS := [Rect2i(9,6,3,3),Rect2i(6,-5,3,14),Rect2i(-8,-8,17,3)]
const WIDTH := 3.0
const TOP := 4.6
const FLIGHT_SEGMENTS := [1,2]
const FLIGHTS := 2
const STEPS := 4
const STEP_RUN := .4
const STEP_RISE := .1
const FLIGHT_LENGTH := STEPS*STEP_RUN
const DROP := STEPS*STEP_RISE
const BOTTOM := TOP-FLIGHTS*DROP
const ENTRY := Vector2i(10,7)
const EXIT := Vector2(-7.5,-7)
const BOUNDS := Rect2i(-8,-8,20,17)

static func flight_index(segment: int) -> int:return FLIGHT_SEGMENTS.find(segment)

static func sample(at: Vector2) -> Dictionary:
	var nearest := INF
	var result := {"segment":0,"distance":0.0,"progress":0.0,"height":TOP}
	var accumulated := 0.0
	for i in range(PATH.size()-1):
		var a: Vector2=PATH[i]
		var delta: Vector2=PATH[i+1]-a
		var length:=delta.length()
		var t:=clampf((at-a).dot(delta)/delta.length_squared(),0.0,1.0)
		var squared:=at.distance_squared_to(a+delta*t)
		if squared<nearest:
			nearest=squared
			var along:=length*t
			result={"segment":i,"distance":along,"progress":accumulated+along,"height":height_on(i,along)}
		accumulated+=length
	return result

static func height_on(segment: int,distance: float) -> float:
	var flight:=flight_index(segment)
	if flight<0:return TOP
	var length: float=PATH[segment].distance_to(PATH[segment+1])
	var start: float=(length-FLIGHT_LENGTH)*.5
	var progress:=clampf((distance-start)/FLIGHT_LENGTH,0.0,1.0)
	return TOP-float(flight)*DROP-progress*DROP

static func height_at(at: Vector2) -> float:return float(sample(at).height)

static func cells() -> Dictionary:
	var result: Dictionary={}
	for rect: Rect2i in RECTS:
		for z in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):result[Vector2i(x,z)]=true
	return result

static func source() -> Dictionary:
	var strings: Array[String]=[]
	for cell: Vector2i in cells():strings.append("%d,%d" % [cell.x,cell.y])
	return {"type":"RESEARCH_ATRIUM_11","checks":{"ok":true},
		"bounds":{"x":BOUNDS.position.x,"y":BOUNDS.position.y,"w":BOUNDS.size.x,"h":BOUNDS.size.y},
		"rooms":[{"id":"entry","label":"1-1 / Research Atrium","kind":"reception","cells":strings,
			"bounds":{"x":BOUNDS.position.x,"y":BOUNDS.position.y,"w":BOUNDS.size.x,"h":BOUNDS.size.y}}],
		"anchors":{"entry":"%d,%d" % [ENTRY.x,ENTRY.y]},"doors":[],"furniture":[],"enemies":[],"corridorSegments":[]}
