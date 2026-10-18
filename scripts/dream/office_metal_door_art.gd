extends RefCounted
## Display geometry only; leaf body, hinge and swept collision remain authoritative.
static var panels: Dictionary = {}
static func panel(width: float, height: float, depth: float, window: bool) -> Mesh:
	var key := str(Vector3(width,height,depth))+str(window)
	if panels.has(key): return panels[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var opening_w := width*.28
	var opening_h := height*.24
	var opening_y := height*.18
	var parts: Array = [[Vector3(width,height,depth),Vector3.ZERO]]
	if window:
		var low := opening_y-opening_h*.5
		var high := opening_y+opening_h*.5
		parts = [[Vector3(width,low+height*.5,depth),Vector3(0,(low-height*.5)*.5,0)], [Vector3(width,height*.5-high,depth),Vector3(0,(high+height*.5)*.5,0)]]
		for side in [-1,1]: parts.append([Vector3((width-opening_w)*.5,opening_h,depth),Vector3(side*(width+opening_w)*.25,opening_y,0)])
	for part in parts:
		var box := BoxMesh.new()
		box.size=part[0]
		st.append_from(box,0,Transform3D(Basis.IDENTITY,part[1]))
	panels[key]=st.commit()
	return panels[key]
