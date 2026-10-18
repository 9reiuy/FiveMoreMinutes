extends "res://scripts/dream/firearm_impact_visual_3d.gd"
## Exact previous factory lifetime, diagnostic only; no gameplay override.
func _get_particle_mesh() -> QuadMesh:
	return _create_particle_mesh()
