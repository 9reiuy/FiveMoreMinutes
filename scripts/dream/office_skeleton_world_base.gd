extends "res://scripts/dream/dream_3d_random_dungeon.gd"
const ADAPTER = preload("res://scripts/dream/office_skeleton_layout_adapter.gd")
const RUN_GLASS = preload("res://scripts/dream/continuous_office_glass.gd")
const TYPES := ["A1","B2","C3","V3"]
const NATIVE_GENERATOR = preload("res://scripts/dream/office_skeleton_generator.gd")
@export_enum("random", "A1", "B2", "C3", "V3") var native_skeleton_type := "random"
@export var use_native_office_skeletons := true
@export var compact_combat_layout := true
@export_enum("A1","B2","C3","V3") var skeleton_type := "A1"
var layout_file := ""
var preview_topology := ""
var skeleton_source: Dictionary = {}
var glass_runs: Dictionary = {}
var built_glass: Dictionary = {}
var skeleton_plans: Dictionary = {}
var rendered_edge_failures := 0
var _native_compiled_layout: Dictionary = {}
var office_wall_cutaway: RefCounted

func _ready() -> void:
	super._ready()

func regenerate(requested_seed: int = seed) -> bool:
	var success := super.regenerate(requested_seed)
	var controls := get_node_or_null("SkeletonControls")
	if controls != null and controls.has_method("refresh"):
		controls.refresh()
	return success

func _prepare_approved_office_art()->void:
	super._prepare_approved_office_art()
	# Shared by first entry, regeneration and the elevator's staged generator.
	if not skeleton_source.is_empty() and not use_authored_office_sample:
		office_wall_cutaway=preload("res://scripts/dream/office_wall_cutaway.gd").new()
		office_wall_cutaway.configure(self)

func refresh_office_wall_cutaway()->void:
	if office_wall_cutaway!=null: office_wall_cutaway.refresh()

func uses_office_wall_cutaway()->bool:
	return not skeleton_source.is_empty() and not use_authored_office_sample

func _get_skeleton_source() -> Dictionary:
	var options := {"seed":active_seed,"compact":compact_combat_layout,"enhanced_dressing":enhanced_room_dressing}
	if native_skeleton_type != "random": options["type"]=native_skeleton_type
	var generated: Dictionary=NATIVE_GENERATOR.generate_compiled(_rng,options)
	_native_compiled_layout=generated.get("layout",{})
	return generated.get("source",{})

func _generate_building_layout() -> bool:
	_native_compiled_layout={}
	# Fixed sample and non-office 2D/legacy contracts retain their existing path.
	if use_authored_office_sample or not _is_otxo_mansion() or not use_native_office_skeletons:
		skeleton_source.clear()
		glass_runs.clear()
		built_glass.clear()
		skeleton_plans.clear()
		return super._generate_building_layout()
	var raw: Dictionary = _get_skeleton_source()
	if raw.is_empty():
		return false
	# External preview subclasses may supply their own raw source. They keep the
	# original adapter path; only native sources reuse their validated compilation.
	var generated: Dictionary = _native_compiled_layout if not _native_compiled_layout.is_empty() else ADAPTER.compile(raw)
	if generated.is_empty():
		return false
	lazy_room_presentation = false
	skeleton_source = raw
	preview_topology = String(raw.type)
	glass_runs = generated.glass_runs
	built_glass.clear()
	building_rect = generated.building_rect
	floor_shape = generated.floor_shape
	rooms.assign(generated.rooms)
	partitions.assign(generated.partitions)
	corridors.assign(generated.corridors)
	connections.assign(generated.connections)
	floor_cells = generated.floor_cells
	room_cells = generated.room_cells
	corridor_cells = generated.corridor_cells
	wall_edges = generated.wall_edges
	internal_wall_edges = generated.internal_wall_edges
	door_edges = generated.door_edges
	door_opening_edges = generated.door_opening_edges
	glass_wall_edges = generated.glass_wall_edges
	edge_states = generated.edge_states
	spawn_room_id = generated.spawn_room_id
	spawn_cell = generated.spawn_cell
	main_entrance = {"start_cell":spawn_cell}
	_next_door_id = generated.next_door_id
	room_states.clear()
	room_encounters.clear()
	skeleton_plans = generated.plans
	room_layout_plans = skeleton_plans.duplicate(true)
	corridor_states.clear()
	for room in rooms:
		room_states[int(room.id)] = room.state
		room_encounters[int(room.id)] = {"enemy_spawns":[],"drop_spawns":[],"activated":false,"completed":false}
	if not _room_graph_is_connected():
		return false
	_choose_key_and_boss_rooms()
	_reserve_content_routes()
	return _choose_elevator_anchor()

func _plan_otxo_room_layout(room_id: int) -> Dictionary:
	if skeleton_source.is_empty(): return super._plan_otxo_room_layout(room_id)
	# Encounter initialization intentionally clears the base cache. The imported
	# Functional groups belong to this floor, not a generic procedural fallback.
	var plan: Dictionary = skeleton_plans.get(room_id,{})
	room_layout_plans[room_id] = plan
	return plan

func _validate_rendered_edge_nodes() -> void:
	if skeleton_source.is_empty():
		super._validate_rendered_edge_nodes()
		return
	rendered_edge_failures = 0
	for key in edge_states:
		var state := String(edge_states[key])
		var has_wall := wall_root.get_node_or_null("Wall_"+String(key).replace(":","_")) != null
		var has_door := door_root.get_node_or_null("Door_"+String(key).replace(":","_")) != null
		if state == "GLASS_WINDOW":
			has_wall = wall_root.get_node_or_null("GlassCell_"+String(key).replace(":","_")) != null
		var e: Dictionary = door_edges.get(key,{})
		var physical := not e.is_empty() and String(e.get("door_style","")) not in ["open","elevator"]
		var valid := (state == "WALL" or state == "GLASS_WINDOW") and has_wall and not has_door
		valid = valid or (state in ["OPEN","DOOR_OPENING"] and not has_wall and not has_door)
		valid = valid or (state == "DOOR" and not has_wall and has_door == physical)
		if not valid:
			rendered_edge_failures += 1
			push_error("Skeleton edge presentation mismatch: " + String(key))

func _is_interior_open_office_edge(_edge: Dictionary) -> bool:
	if skeleton_source.is_empty(): return super._is_interior_open_office_edge(_edge)
	# Explicit per-edge states own skeleton boundaries, not full-frontage removal.
	return false

func _stash_current_floor_for_rollback() -> void:
	super._stash_current_floor_for_rollback()
	# These immutable presentation inputs belong to the same transaction as
	# floor_cells and edge_states; restore them after a failed native generation.
	for property in ["skeleton_source","glass_runs","built_glass","skeleton_plans","preview_topology","office_wall_cutaway"]:
		var value: Variant = get(property)
		_stashed_runtime_state[property] = value.duplicate(true) if value is Dictionary else value

func _rebuild_active_room_presentation() -> void:
	built_glass.clear()
	super._rebuild_active_room_presentation()

func _build_glass_window(edge: Dictionary, key: String) -> void:
	var group := String(edge.get("preview_glass_group",""))
	if group.is_empty():
		super._build_glass_window(edge,key)
		return
	if built_glass.has(key):
		return
	built_glass[key] = true
	var section: Dictionary = glass_runs[group]
	var first: Dictionary = edge.duplicate(true)
	first["preview_run_width"] = 1
	var offset: int = int(edge.y)-int(section.edge.y) if String(edge.axis) == "V" else int(edge.x)-int(section.edge.x)
	# Vertical panes rotate +90 degrees: local left is the high-Z end.
	first["run_first"] = offset == (int(section.width)-1 if String(edge.axis) == "V" else 0)
	first["run_last"] = offset == (0 if String(edge.axis) == "V" else int(section.width)-1)
	var pane := RUN_GLASS.new()
	pane.name = "GlassCell_" + key.replace(":","_")
	pane.position = _edge_world_position(first)
	pane.set_meta(&"edge",first)
	wall_root.add_child(pane)
	pane.configure_window(first,key,wall_height,wall_thickness,collision_root)
	pane.window_shattered.connect(_on_glass_window_shattered)

func _on_glass_window_shattered(window: Node3D) -> void:
	var edge: Dictionary = window.get("edge_data")
	var width := int(edge.get("preview_run_width",1))
	for i in width:
		var segment := edge.duplicate(true)
		if String(edge.axis) == "V":
			segment.y = int(edge.y)+i
		else:
			segment.x = int(edge.x)+i
		var key := _edge_key(segment)
		wall_edges.erase(key)
		internal_wall_edges.erase(key)
		glass_wall_edges.erase(key)
		edge_states[key] = &"OPEN"
	super._on_glass_window_shattered(window)

func _build_walls() -> void:
	super._build_walls()
	# Wall fixtures are display-only and die with the generated wall root.
	for fixture in skeleton_source.get("decor",[]):
		var plate := MeshInstance3D.new()
		plate.name = "WallFixture_" + String(fixture.kind)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.12,.38,.06) if String(fixture.kind) == "管线" else Vector3(.5,.42,.06)
		plate.mesh = mesh
		plate.material_override = preload("res://scripts/dream/office_furniture_catalog.gd").material(Color(.55,.23,.18) if String(fixture.kind) == "消防箱" else Color(.38,.46,.49))
		plate.position = Vector3(float(fixture.x)-.5-float(fixture.dx)*.28,1.45,float(fixture.y)-.5-float(fixture.dy)*.28)
		plate.rotation.y = PI*.5 if int(fixture.dx) != 0 else 0
		wall_root.add_child(plate)
