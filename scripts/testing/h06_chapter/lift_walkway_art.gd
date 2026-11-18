extends RefCounted

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const M := preload("res://scripts/testing/maintenance_environment.gd")
const WAREHOUSE := preload("res://scripts/testing/h06_chapter/warehouse_art.gd")
const FREIGHT := preload("res://scripts/testing/h06_chapter/freight_art.gd")

static func build_bridge(art, parent: Node3D, marker: Material) -> void:
	var span := PLAN.ARENA_BRIDGE
	var center := span.get_center()
	var steel := WAREHOUSE.materials()
	var grating := FREIGHT.make_grate_material(true,Vector2(2.6,3.4))
	grating.set_shader_parameter("steel_base",Color("52585b"))
	grating.set_shader_parameter("frame_base",Color("424645"))
	var grate_area := Rect2(span.position+Vector2(0,.23),span.size-Vector2(0,.46))
	FREIGHT.build_grate_deck_mesh(parent,"BoardingGrating",grate_area,grating)
	var entry: Rect2 = PLAN.LOWER.arena_link
	# Keep the near side of the staff doorway in view until the bridge recedes.
	entry.size.y += 2.8
	var entry_center := entry.get_center()
	M.box(parent,"StaffThresholdFloor",Vector3(entry.size.x,.22,entry.size.y),
		Vector3(entry_center.x,-.11,entry_center.y),art.LOGISTICS_HUB.floor_material())
	M.box(parent,"BridgeThresholdAtDeck",Vector3(span.size.x,.18,.23),
		Vector3(center.x,-.09,span.position.y+.115),steel.steel_mid)
	M.box(parent,"BridgeThresholdAtPortal",Vector3(span.size.x,.18,.23),
		Vector3(center.x,-.09,span.end.y-.115),steel.steel_mid)

	var truss := WAREHOUSE.MeshBuilder.new()
	var bay_count := 5
	var bay_length := span.size.y/bay_count
	for side: float in [-1.,1.]:
		var x := center.x+side*(span.size.x*.5-.07)
		truss.box(steel.safety_yellow,Vector3(x,1.18,center.y),Vector3(.21,.17,span.size.y))
		truss.box(steel.safety_yellow,Vector3(x,-.26,center.y),Vector3(.27,.31,span.size.y))
		truss.box(steel.steel_dark,Vector3(x,.10,center.y),Vector3(.18,.20,span.size.y))
		truss.bar(steel.steel_mid,Vector3(x,.47,span.position.y),Vector3(x,.47,span.end.y),.052)
		for index in bay_count+1:
			var z := span.position.y+.09+index*(span.size.y-.18)/bay_count
			truss.box(steel.safety_yellow,Vector3(x,.53,z),Vector3(.15,1.26,.15))
			truss.box(steel.steel_dark,Vector3(x,.087,z),Vector3(.37,.16,.38))
			if index==bay_count: continue
			var next_z := z+(span.size.y-.18)/bay_count
			var start_y := .14 if index%2==0 else 1.11
			truss.bar(steel.safety_yellow,Vector3(x,start_y,z),Vector3(x,1.25-start_y,next_z),.135)
			if index%2==0:
				truss.box(marker,Vector3(x-side*.125,.10,z+.17),Vector3(.10,.037,.32))
		# The tail narrows into the existing doorway behind the trusses.
		var portal_x := entry_center.x+side*entry.size.x*.5
		truss.bar(steel.steel_dark,Vector3(x,.79,span.end.y-.04),Vector3(portal_x,.79,span.end.y+.56),.10)
		truss.box(steel.steel_mid,Vector3(portal_x+side*.14,.70,entry_center.y),Vector3(.28,1.65,entry.size.y))
		truss.box(steel.steel_dark,Vector3(portal_x+side*.14,1.54,entry_center.y),Vector3(.30,.08,entry.size.y))
		art.fittings.fit(parent,"BottomSimple_Straight",Vector3(x,-.42,center.y),Vector3(.23,.14,span.size.y))
	for index in range(1,bay_count):
		var z := span.position.y+index*bay_length
		truss.box(steel.steel_mid,Vector3(center.x,-.43,z),Vector3(span.size.x+.72,.29,.34))
		if index%2==0:
			for side: float in [-1.,1.]:
				var outside := center.x+side*(span.size.x*.5+.24)
				var inside := center.x+side*1.15
				truss.bar(steel.steel_dark,Vector3(outside,-.49,z),Vector3(inside,-2.29,z),.24)
				truss.box(steel.safety_yellow,Vector3(outside,-.66,z),Vector3(.38,.52,.53))
	var braces := MeshInstance3D.new()
	braces.name = "BoardingTrusses"
	braces.mesh = truss.bake()
	parent.add_child(braces)
