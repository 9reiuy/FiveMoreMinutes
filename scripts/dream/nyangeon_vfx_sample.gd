extends RefCounted
## Compatibility entry for the retained visual captures; production installs itself.
static func install(world: Node3D)->Node3D:
	return preload("res://scripts/dream/combat_vfx.gd").install(world)
