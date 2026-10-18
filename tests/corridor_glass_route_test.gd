extends SceneTree
const WORLD=preload("res://scripts/dream/office_skeleton_world_base.gd")
const ADAPTER=preload("res://scripts/dream/office_skeleton_layout_adapter.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	for type in ["A1","B2","C3","V3"]:
		for value in [120,42001,42002]:
			var world=WORLD.new(); world.native_skeleton_type=type
			check(world.generate_layout_only(value),"Native floor generates "+type+"/"+str(value))
			var data: Dictionary=world.skeleton_source
			check(data.doors.all(func(d: Dictionary) -> bool: return not bool(d.glass) or ADAPTER.corridor_crossing_span(data.corridorSegments,d).is_empty()),"No generated glass crosses corridor endpoint")
			check(world._room_graph_is_connected(),"Connectivity is preserved")
			check(world.glass_wall_edges.size()>0,"Side glass remains present")
			if type=="V3":
				var exits: Array=data.doors.filter(func(d: Dictionary) -> bool: return "crosshall" in [String(d.a),String(d.b)] and "main" in [String(d.a),String(d.b)] and not bool(d.glass))
				check(not exits.is_empty() and bool(exits[0].open) and int(exits[0].width)>=3,"Former blocked sky corridor end is a usable open entrance")
			world.free()
	# Defensive compilation of a legacy source is exercised with the original
	# glass edge on the new native floor; it must not resurrect blocking glass.
	var legacy=WORLD.new(); legacy.native_skeleton_type="V3"; legacy.generate_layout_only(120)
	var raw: Dictionary=legacy.skeleton_source.duplicate(true)
	var old_door: Dictionary=raw.doors.filter(func(d: Dictionary) -> bool: return "crosshall" in [String(d.a),String(d.b)] and "main" in [String(d.a),String(d.b)] and not bool(d.glass))[0].duplicate(true)
	old_door.glass=true; old_door.open=false; old_door.start=int(old_door.start)+1; old_door.width=int(old_door.width)-2
	raw.doors=raw.doors.filter(func(d: Dictionary) -> bool: return not ("crosshall" in [String(d.a),String(d.b)] and "main" in [String(d.a),String(d.b)]))
	raw.doors.append(old_door)
	var layout := ADAPTER.compile(raw)
	check(layout.door_edges.values().any(func(e: Dictionary) -> bool: return String(e.get("door_style",""))=="open" and int(e.get("opening_cells",0))>=4),"Legacy blocked source compiles to full-width open route")
	var key := "V:%d:%d" % [int(old_door.line),int(old_door.start)]
	check(not layout.glass_wall_edges.has(key),"Legacy corridor glass is absent from compiled collision edges")
	legacy.free()
	print("CORRIDOR_GLASS_ROUTE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
