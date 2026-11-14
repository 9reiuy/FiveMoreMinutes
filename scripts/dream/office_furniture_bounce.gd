extends Node3D
## Room-local indirect light for furniture sides and caps. The existing floor
## circuit and structural shadow shell stay authoritative. No emission.
const NODE_NAME := "FurnitureBounceNightLighting"
const RECEIVER := 1 << 14
const ARCHITECTURE := 1 << 12
const ROOF := 1 << 17
const LAYERS = preload("res://scripts/dream/render_layer_mask.gd")
var world: Node3D
var enabled := true
var records: Array[Dictionary] = []
var receivers: Array[Dictionary] = []
var registered: Dictionary = {}
var update_left := 0.0
var floor_token := -1

static func install(owner_world: Node3D) -> Node3D:
	if not owner_world.has_method("uses_office_night_lighting") or not owner_world.uses_office_night_lighting(): return null
	if not owner_world.has_method("get_current_floor_token") or owner_world.has_node("ChapterTraining"): return null
	var host: Node3D = owner_world.ceiling_light_root
	if not is_instance_valid(host): return null
	var existing: Node3D = host.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var component: Node3D = load("res://scripts/dream/office_furniture_bounce.gd").new()
	component.name = NODE_NAME; host.add_child(component); component.setup(owner_world)
	return component

static func uninstall(owner_world: Node3D) -> void:
	var host: Node3D = owner_world.get("ceiling_light_root")
	if not is_instance_valid(host): return
	var component: Node3D = host.get_node_or_null(NODE_NAME)
	if component != null: component.restore(); component.free()

func setup(owner_world: Node3D) -> void:
	world = owner_world; floor_token = world.get_current_floor_token()
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if is_receiver(mesh): register_receiver(mesh)
	var sources: Dictionary = {}
	for source in world.ceiling_light_root.find_children("RoomFill", "OmniLight3D", true, false):
		var holder: Node3D = source.get_parent()
		if not String(holder.name).begins_with("NightLightingRoom"): continue
		var room_id: int = holder.get_meta(&"dream_room_id", -1)
		if not sources.has(room_id): sources[room_id] = []
		sources[room_id].append(weakref(source))
	# Furniture placement cells are inset from the walls. Use the full room
	# floor so wall-adjacent sofas/cabinets are inside the bounce perimeter.
	var room_cells: Dictionary = {}
	for cell: Vector2i in world.floor_cells:
		var room_id: int = world.room_cells.get(cell, -1)
		if not sources.has(room_id): continue
		if not room_cells.has(room_id): room_cells[room_id] = []
		room_cells[room_id].append(cell)
	for room_id in room_cells:
		var cells: Array = room_cells[room_id]
		var low := Vector2(INF, INF); var high := Vector2(-INF, -INF)
		for cell in cells: low = low.min(Vector2(cell)); high = high.max(Vector2(cell))
		var center := (low + high) * .5; var span := high - low
		for end in [Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Vector2.ONE]:
			var desired: Vector2 = low + span * end
			var closest := Vector2(cells[0])
			for cell in cells:
				if Vector2(cell).distance_squared_to(desired) < closest.distance_squared_to(desired): closest = Vector2(cell)
			var point: Vector2 = closest + (end * 2.0 - Vector2.ONE) * .30
			var light := OmniLight3D.new(); light.name = "RoomBounce%d" % int(room_id)
			light.light_specular = 0.0
			light.omni_range = maxf(5.0, point.distance_to(center) + span.length() * .6)
			light.omni_attenuation = 0.0; light.shadow_enabled = true
			light.shadow_caster_mask = ARCHITECTURE | ROOF
			light.light_cull_mask = RECEIVER | ARCHITECTURE | ROOF
			# Opt out of the mirror registrar expanding masks to every floor.
			light.set_meta(&"ground_readability_only", true)
			light.shadow_bias = .025; light.shadow_normal_bias = .05
			# The former ankle-height sources could not reach upward-facing caps.
			# Keep these same four sources inside the ceiling shadow shell, so
			# cabinet tops/accessory sides receive real, circuit-driven fill too.
			add_child(light); light.global_position = world.get_gameplay_world_position(point * 32.0, minf(2.35, world.wall_height - .25))
			records.append({"light":light, "sources":sources[room_id]})
	get_tree().node_added.connect(on_node_added)
	sync()

func is_receiver(mesh: MeshInstance3D) -> bool:
	if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return false
	var ancestor: Node = mesh
	while ancestor != null and ancestor != world:
		if ancestor is Furniture3DVisual:
			return is_instance_valid(ancestor.visual_instance) and (ancestor.visual_instance == mesh or ancestor.visual_instance.is_ancestor_of(mesh))
		if String(ancestor.name).to_lower().contains("door"): return true
		ancestor = ancestor.get_parent()
	return false

func on_node_added(node: Node) -> void:
	if node is MeshInstance3D and is_instance_valid(world) and world.is_ancestor_of(node):
		register_late.call_deferred(weakref(node))

func register_late(reference: WeakRef) -> void:
	var mesh: MeshInstance3D = reference.get_ref()
	if is_instance_valid(mesh) and mesh.is_inside_tree() and is_instance_valid(world) and world.is_ancestor_of(mesh) and is_receiver(mesh): register_receiver(mesh)

func register_receiver(mesh: MeshInstance3D) -> void:
	if registered.has(mesh.get_instance_id()): return
	registered[mesh.get_instance_id()] = true
	receivers.append({"mesh":weakref(mesh), "had_layer":bool(mesh.layers & RECEIVER)})
	LAYERS.apply(mesh, mesh.layers | RECEIVER)

func set_enabled(value: bool) -> void:
	enabled = value; sync()

func _process(delta: float) -> void:
	update_left -= delta
	if update_left > 0.0: return
	update_left = .10; sync()

func sync() -> void:
	var powered: bool = enabled and is_instance_valid(world) and world.get_current_floor_token() == floor_token
	if powered:
		for cabinet in get_tree().get_nodes_in_group(&"floor_power_switches"):
			if world.is_ancestor_of(cabinet) and not cabinet.powered: powered = false
	for record: Dictionary in records:
		var energy := 0.0; var tint := Color.WHITE
		for reference: WeakRef in record.sources:
			var source: OmniLight3D = reference.get_ref()
			if is_instance_valid(source) and source.is_visible_in_tree() and source.layers != 0 and source.light_energy > energy:
				energy = source.light_energy; tint = source.light_color
		record.light.light_energy = energy * 2.25 if powered else 0.0
		record.light.light_color = tint; record.light.visible = powered and energy > 0.0

func restore() -> void:
	if is_inside_tree() and get_tree().node_added.is_connected(on_node_added): get_tree().node_added.disconnect(on_node_added)
	for receiver: Dictionary in receivers:
		var mesh: MeshInstance3D = receiver.mesh.get_ref()
		if is_instance_valid(mesh) and not receiver.had_layer: LAYERS.apply(mesh, mesh.layers & ~RECEIVER)
	for record: Dictionary in records:
		if is_instance_valid(record.light): record.light.free()
	records.clear(); receivers.clear(); registered.clear()

func _exit_tree() -> void:
	restore()
