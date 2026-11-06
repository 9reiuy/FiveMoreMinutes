extends "res://scripts/dream/office_skeleton_world_base.gd"
## Only the independent lab opts into test policy. Production stays untouched.
var lab_native_layout := false
var lab_furniture := true
var lab_enemy_count := 8
var lab_enemy_archetypes: Array[StringName] = [&"employee"]
var lab_ai := true
var lab_special_units := false
var lab_cutout := true
var lab_invulnerable := true
var lab_cutout_usec := 0
var lab_whitebox := true
## Diagnostic ablations, deliberately absent from every production world.
var lab_probe_flags: Dictionary = {}

func disperse_smoke_segment(from:Vector2,to:Vector2)->void:
	if not lab_probe_flags.get("skip_smoke_disperse",false): super.disperse_smoke_segment(from,to)

func spawn_black_blood(at_position:Vector2,direction:Vector2=Vector2.ZERO,lethal:bool=false,source_room_id:int=-1,intensity:float=1.0,droplet_multiplier:float=1.0,speed_multiplier:float=1.0,spread_multiplier:float=1.0)->bool:
	# Report handled so callers do not create a fallback stain in an exclusion.
	if lab_probe_flags.get("skip_blood",false): return true
	return super.spawn_black_blood(at_position,direction,lethal,source_room_id,intensity,droplet_multiplier,speed_multiplier,spread_multiplier)

func spawn_weapon_muzzle(at_position:Vector2,direction:Vector2,effect_kind:StringName,source_actor:Node2D=null)->void:
	if not lab_probe_flags.get("skip_muzzle",false): super.spawn_weapon_muzzle(at_position,direction,effect_kind,source_actor)

func _get_skeleton_source() -> Dictionary:
	if lab_native_layout: return super._get_skeleton_source()
	return preload("res://scripts/testing/lab_layout.gd").build()

func _validate_layout() -> Dictionary:
	if lab_native_layout: return super._validate_layout()
	# Production requires >= 8 rooms and a badge carrier for progression. The
	# four-room lab has no progression, but keeps actual graph/floor validation.
	var report := _validate_floor_connectivity()
	report["graph"] = _room_graph_is_connected()
	report["sides"] = _validate_door_sides()
	# Adapter OPEN spans retain an opening descriptor in door_edges. The older
	# BSP edge validator rejects that; the skeleton renderer validates them.
	report["valid"] = rooms.size()==4 and bool(report.graph) and bool(report.all_floor_reachable) and bool(report.all_room_centers_reachable) and bool(report.sides)
	return report

func _spawn_room_encounter(_room_id: int) -> void:
	pass # Bounded explicit population: room entry must not replenish it.

func _spawn_special_units() -> void:
	if lab_special_units: super._spawn_special_units()

func _spawn_room_furniture(room_filter: int = -1) -> void:
	if lab_furniture: super._spawn_room_furniture(room_filter)

func _update_occlusion_cutouts() -> void:
	if not lab_cutout: return
	var start := Time.get_ticks_usec()
	super._update_occlusion_cutouts()
	lab_cutout_usec += Time.get_ticks_usec() - start

func set_lab_cutout(enabled: bool) -> void:
	lab_cutout = enabled
	_last_cutout_slots.clear()
	if not enabled:
		for slot in 8: RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % slot, Vector4.ZERO)

func populate_lab() -> void:
	# Approved dressing can add plants outside the primary furniture generator.
	# Remove those too for a true zero-furniture sampling window (not load timing).
	if not lab_furniture:
		for prop in furniture_root.get_children():
			for bridge in actor_depth_bridges_root.get_children():
				if bridge.has_meta(&"source_actor") and bridge.get_meta(&"source_actor")==prop: bridge.free()
			prop.free()
		furniture_count=0
	var positions: Array[Dictionary] = []
	for room in rooms:
		if int(room.id) == spawn_room_id: continue
		var available: Array = room.get("usable_cells", []).duplicate()
		available.sort_custom(func(a: Vector2i,b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
		for cell: Vector2i in available:
			if cell.x % 3 != 1 or cell.y % 3 != 1: continue
			positions.append({"room":int(room.id),"position":Vector2(cell)*32.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = active_seed ^ 0x1AB
	for i in range(positions.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Dictionary = positions[i]; positions[i] = positions[j]; positions[j] = swap
	for i in mini(lab_enemy_count,positions.size()):
		var slot: Dictionary = positions[i]
		var archetype := lab_enemy_archetypes[i % lab_enemy_archetypes.size()]
		var enemy := _spawn_regular_employee(slot.room,slot.position,archetype,false,"assault_rifle" if i%3==0 else "basic")
		if is_instance_valid(enemy) and not lab_ai: enemy.process_mode=Node.PROCESS_MODE_DISABLED
	if not lab_ai:
		for enemy in enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	for room in rooms: reveal_room(int(room.id))
	player_has_left_elevator_cab = true
	if lab_whitebox: apply_whitebox()

func apply_whitebox() -> void:
	# Local material overrides, never mutation of a shared imported resource.
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("b9c4cc"); floor_material.roughness = 1.0
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("e0e5e8"); wall_material.roughness = 1.0
	var prop_material := StandardMaterial3D.new()
	prop_material.albedo_color = Color("66879c"); prop_material.roughness = 1.0
	_paint_static(floor_root, floor_material)
	for wall in wall_root.get_children():
		if not wall.has_method("shatter"): _paint_static(wall,wall_material)
	for bridge in actor_depth_bridges_root.get_children():
		if not bridge.has_meta(&"source_actor"): continue
		var source: Variant = bridge.get_meta(&"source_actor")
		if is_instance_valid(source) and source.get_meta(&"content_kind",&"") == &"furniture": _paint_static(bridge,prop_material)
	var grid := ImmediateMesh.new()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; ink.albedo_color = Color("6b8492")
	grid.surface_begin(Mesh.PRIMITIVE_LINES,ink)
	for x in range(29):
		grid.surface_add_vertex(Vector3(x-.5,.035,-.5)); grid.surface_add_vertex(Vector3(x-.5,.035,23.5))
	for y in range(25):
		grid.surface_add_vertex(Vector3(-.5,.035,y-.5)); grid.surface_add_vertex(Vector3(27.5,.035,y-.5))
	grid.surface_end()
	var carrier := MeshInstance3D.new(); carrier.mesh = grid
	carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; floor_root.add_child(carrier)
	var environment: Environment = get_node("Lighting/WorldEnvironment").environment.duplicate()
	environment.ambient_light_energy = .8; get_node("Lighting/WorldEnvironment").environment = environment
	for i in rooms.size():
		var label := Label3D.new()
		label.text = "%02d" % (i+1); label.font_size = 32; label.pixel_size = .012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(rooms[i].grid_rect.position.x+1,1.8,rooms[i].grid_rect.position.y+1)
		floor_root.add_child(label)

func _paint_static(node: Node, material: Material) -> void:
	if node.name in [&"FireExtinguisherSystem", &"BurningEffects"]: return
	if node is GeometryInstance3D: node.material_override = material
	for child in node.get_children(): _paint_static(child,material)

func station_position(index: int) -> Vector2:
	if rooms.is_empty(): return Vector2.ZERO
	var room: Dictionary = rooms[clampi(index,0,rooms.size()-1)]
	var target := Vector2(room.center_cell)*32.0
	var result := target
	var best := INF
	for c: Vector2i in room.get("usable_cells", []):
		var distance := (Vector2(c)*32.0).distance_squared_to(target)
		if distance < best: best=distance; result=Vector2(c)*32.0
	return result
