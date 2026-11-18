extends "res://scripts/dream/elemental_particles_3d.gd"
## Comparison only; excluded from exports with the rest of tests/.
func _ready() -> void:
	super._ready()
	explosion.free()
	explosion = preload("res://scripts/dream/explosion_gas_pool_3d.gd").new()
	explosion.name = "ExplosionParticles"
	add_child(explosion)
