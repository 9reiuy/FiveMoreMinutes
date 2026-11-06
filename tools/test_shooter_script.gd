extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTING SHOOTER SCENE INSTANTIATION ===")
	var shooter_scene: PackedScene = preload("res://scenes/entities/corridor_end_shooter.tscn")
	var shooter = shooter_scene.instantiate()
	root.add_child(shooter)
	
	var player = Node2D.new()
	player.global_position = Vector2(192.0, 1152.0)
	root.add_child(player)
	
	var config = preload("res://resources/demo_config.tres")
	shooter.configure(
		player,
		config.base_enemy_health,
		0.0,
		Rect2(0, 0, 384, 1216),
		config.enemy_separation_strength,
		config.enemy_separation_radius,
		config
	)
	
	for i in range(10):
		await physics_frame
		
	print("Shooter class: ", shooter.get_class(), " Script: ", shooter.get_script().resource_path)
	print("Shooter health: ", shooter.current_health, " Weapon: ", shooter.held_weapon_id)
	print("Shooter test PASSED!")
	quit(0)
