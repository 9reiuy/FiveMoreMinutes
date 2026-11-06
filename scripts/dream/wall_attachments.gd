extends RefCounted
## Only creators of wall-mounted objects opt in. Nearby floor furniture is
## never inferred to be wall-supported by proximity, height or furniture kind.
const GROUP := &"generated_wall_attachments"

static func bind(world: Node3D, attachment: Node, edge: Dictionary) -> void:
	if not is_instance_valid(world) or not is_instance_valid(attachment) or edge.is_empty(): return
	var key: String = world._edge_key(edge)
	attachment.set_meta(&"wall_fixture_edge", edge.duplicate(true))
	attachment.set_meta(&"wall_support_edge_key", key)
	attachment.set_meta(&"wall_attachment_world", weakref(world))
	attachment.set_meta(&"wall_attachment_floor", world.get_current_floor_token())
	attachment.add_to_group(GROUP)

static func bind_at_pose(world: Node3D, attachment: Node3D, position: Vector2, yaw: float) -> void:
	# Fixed authored fixtures expose a known wall-facing plane, unlike furniture.
	# Resolve that declared mounting plane against actual architecture once.
	var normal := Vector2(sin(yaw), cos(yaw))
	var axis := "H" if absf(normal.y) >= absf(normal.x) else "V"
	var best: Dictionary = {}
	# The fixed sample keeps a one-cell interior staging border; its declared
	# wall signs can sit 1.06 cells from the actual structural plane.
	var distance := 1.15
	for edge: Dictionary in world.wall_edges.values():
		if String(edge.axis) != axis: continue
		var center: Vector2 = world._edge_gameplay_position(edge) / world.CELL_PIXELS
		var delta := position - center
		var across := absf(delta.y) if axis == "H" else absf(delta.x)
		var along := absf(delta.x) if axis == "H" else absf(delta.y)
		if along <= .5 and across < distance:
			distance = across
			best = edge
	if not best.is_empty(): bind(world, attachment, best)

static func remove(world: Node3D, key: String) -> void:
	for attachment in world.get_tree().get_nodes_in_group(GROUP):
		if not is_instance_valid(attachment) or attachment.is_queued_for_deletion(): continue
		var owner: WeakRef = attachment.get_meta(&"wall_attachment_world", null)
		if owner == null or owner.get_ref() != world: continue
		if int(attachment.get_meta(&"wall_attachment_floor", -1)) != world.get_current_floor_token(): continue
		if String(attachment.get_meta(&"wall_support_edge_key", "")) != key: continue
		# Flying/spent cylinders have already left their mounting and keep their
		# own gameplay lifetime; deleting their former wall must not recall them.
		if attachment.is_in_group(&"fire_extinguishers") and bool(attachment.get("broken")): continue
		attachment.free()

static func refresh_floor_token(world: Node3D) -> void:
	# Restored floor nodes keep their exact support bindings under a fresh token.
	for attachment in world.get_tree().get_nodes_in_group(GROUP):
		var owner: WeakRef = attachment.get_meta(&"wall_attachment_world", null)
		if owner != null and owner.get_ref() == world:
			attachment.set_meta(&"wall_attachment_floor", world.get_current_floor_token())
