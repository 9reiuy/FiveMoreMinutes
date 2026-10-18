extends RefCounted
## Cached, visual-only detail batches. Attached to the real moving furniture bridge.
const MATERIALS = preload("res://scripts/dream/office_pixel_materials.gd")
static var meshes: Dictionary = {}

static func furniture(kind: String) -> Node3D:
	var parts: Array = []
	match kind:
		"workstation", "desk":
			parts = [[Vector3(.32,.045,.24),Vector3(.70,.78,-.22),"paper"], [Vector3(.30,.03,.23),Vector3(.69,.816,-.22),"folder"], [Vector3(.10,.15,.10),Vector3(-.88,.815,.28),"cream"], [Vector3(.04,.20,.04),Vector3(-.88,.89,.28),"ink"]]
		"table", "dining_table":
			parts = [[Vector3(.36,.04,.28),Vector3(-.85,.79,-.36),"folder"], [Vector3(.28,.025,.21),Vector3(.75,.787,-.36),"paper"], [Vector3(.10,.14,.10),Vector3(.94,.84,.35),"cream"]]
		"coffee_table":
			parts = [[Vector3(.25,.035,.20),Vector3(.30,.455,-.17),"folder"], [Vector3(.09,.11,.09),Vector3(-.38,.475,.22),"cream"]]
		"reception":
			parts = [[Vector3(.32,.055,.26),Vector3(-1.0,1.075,.15),"folder"], [Vector3(.27,.025,.22),Vector3(-.99,1.115,.15),"paper"], [Vector3(.20,.035,.12),Vector3(.2,1.067,-.25),"ink"]]
		"cabinet", "shelf":
			var top := 1.9 if kind == "shelf" else 1.85
			parts = [[Vector3(.40,.18,.30),Vector3(.30,top+.09,0),"folder"], [Vector3(.30,.14,.30),Vector3(-.30,top+.07,0),"paper"]]
		"counter", "appliance_counter":
			parts = [[Vector3(.20,.22,.18),Vector3(.40,1.0,.05),"cream"], [Vector3(.24,.035,.22),Vector3(-.4,.91,.05),"paper"]]
			parts.append_array([[Vector3(.17,.14,.17),Vector3(.1,.95,.05),"metal"],[Vector3(.12,.02,.12),Vector3(.1,1.035,.05),"ink"],[Vector3(.08,.10,.08),Vector3(-.12,.93,.14),"cream"]])
		"copier":
			parts=[[Vector3(.28,.05,.23),Vector3(-.32,1.18,.08),"paper"],[Vector3(.20,.025,.17),Vector3(-.32,1.215,.08),"folder"]]
		_: return null
	return _batch("DeskDetails_"+kind,parts)

static func wall_fixture(kind: String) -> Node3D:
	var parts: Array = []
	if kind == "fire":
		parts = [[Vector3(.48,.64,.12),Vector3.ZERO,"red"], [Vector3(.34,.44,.015),Vector3(0,.015,.068),"ink"], [Vector3(.07,.20,.025),Vector3(.13,0,.08),"cream"], [Vector3(.27,.08,.025),Vector3(0,.24,.08),"paper"]]
	elif kind == "pipe":
		parts = [[Vector3(.075,1.25,.075),Vector3(-.18,0,0),"metal"], [Vector3(.45,.075,.075),Vector3(.01,.59,0),"metal"], [Vector3(.14,.06,.10),Vector3(-.18,-.38,.01),"ink"], [Vector3(.14,.06,.10),Vector3(-.18,.35,.01),"ink"]]
	elif kind == "clock":
		parts=[[Vector3(.48,.48,.08),Vector3.ZERO,"ink"],[Vector3(.40,.40,.02),Vector3(0,0,.05),"paper"],[Vector3(.025,.15,.02),Vector3(0,.05,.07),"ink"],[Vector3(.12,.025,.02),Vector3(.045,0,.07),"ink"]]
	else: return null
	return _batch("WallDetail_"+kind,parts)

static func _batch(key: String, parts: Array) -> Node3D:
	var colors := {"paper":Color("d4d0b9"),"folder":Color("698490"),"cream":Color("bbb8a5"),"ink":Color("29383e"),"metal":Color("718087"),"red":Color("8c4037")}
	if not meshes.has(key):
		var builders: Dictionary = {}
		for part in parts:
			var tone: String = part[2]
			if not builders.has(tone):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				builders[tone] = tool
			var box := BoxMesh.new()
			box.size = part[0]
			builders[tone].append_from(box,0,Transform3D(Basis.IDENTITY,part[1]))
		var variants: Dictionary = {}
		for tone in builders: variants[tone]=builders[tone].commit()
		meshes[key]=variants
	var root := Node3D.new()
	root.name=key
	root.set_meta(&"visual_only_dressing",true)
	for tone in meshes[key]:
		var display := MeshInstance3D.new()
		display.mesh=meshes[key][tone]
		display.material_override=MATERIALS.make(colors[tone],"paint",true)
		display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(display)
	return root
