extends RefCounted
## Approved production VFX. The visual manager belongs to its generated floor.
const SMOKE=preload("res://scripts/dream/nyangeon_footstep_smoke.gd")
const MANAGER_NAME:=&"FootstepSmoke"
static func install(world: Node3D)->Node3D:
	var owner_root: Node=world.get("floor_root")
	if not is_instance_valid(owner_root): owner_root=world
	var existing:=owner_root.get_node_or_null(NodePath(String(MANAGER_NAME)))
	if is_instance_valid(existing): return existing
	var smoke:=SMOKE.new(); smoke.name=MANAGER_NAME
	owner_root.add_child(smoke); smoke.configure(world)
	return smoke
