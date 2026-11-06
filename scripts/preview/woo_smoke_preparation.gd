extends "res://scripts/dream/fire_extinguisher_system.gd"
## Loading-only native render carrier. It never discharges gas, spawns tanks,
## advances simulation, or changes the real smoke controller/RNG.

func spawn_wall_tanks() -> void:
	pass

func prepare(owner_world: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	owner_world.floor_root.add_child(self)
	configure(owner_world)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("clip_at_floor", false)
		material.set_shader_parameter("fusion_enabled", false)
		material.set_shader_parameter("collective_fusion", false)
	var camera: Camera3D = owner_world.camera_3d
	var point: Vector3 = owner_world.get_gameplay_world_position(owner_world.player.global_position + Vector2(24, 24), 0.7)
	_commit_puffs([{"at": point, "field_row": 0, "size": 1.0, "seed": 0.5, "alpha": 0.6}], true, camera.global_position, camera.global_basis)
