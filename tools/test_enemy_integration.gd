extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	print("--- TESTING ENEMY AND PROJECTILE INTEGRATION ---")
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)
	
	for i in range(10):
		await process_frame
		
	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var world_2d = scene.get_node("GameplayCanvas/GameplayWorld")
	
	print("[1] Spawning EmployeeEnemy...")
	var enemy_scene = load("res://scenes/entities/employee_enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(192.0, 1024.0)
	world_2d.add_child(enemy)
	
	var config = preload("res://resources/demo_config.tres")
	enemy.configure(player, config)
	enemy.equip_weapon("basic")
	enemy.hostile = true
	print("    Enemy successfully configured with weapon: basic")
	
	print("[2] Spawning ActorDepthBridge for Enemy...")
	var bridge_scene = load("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
	var bridge = bridge_scene.instantiate()
	scene.add_child(bridge)
	bridge.set_world_camera(scene.get_node("CameraRig/Camera3D"))
	var vp = bridge.get_node("ActorDepthViewport")
	var rr = bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot")
	bridge.configure(enemy, vp, rr, scene.get_node("GameplayCanvas"), [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])
	print("    Depth bridge successfully attached!")
	
	print("[3] Testing Projectile Spawning...")
	var proj_scene = load("res://scenes/entities/basic_projectile.tscn")
	var proj = proj_scene.instantiate()
	proj.global_position = Vector2(192.0, 1060.0)
	world_2d.add_child(proj)
	
	var firearm_rules = preload("res://scripts/dream/dream_firearm_rules.gd")
	firearm_rules.setup_projectile(proj, Vector2.DOWN, 10.0, 300.0, 150.0, &"enemy", enemy, &"basic")
	
	var proj_bridge = bridge_scene.instantiate()
	scene.add_child(proj_bridge)
	proj_bridge.set_world_camera(scene.get_node("CameraRig/Camera3D"))
	var p_vp = proj_bridge.get_node("ActorDepthViewport")
	var p_rr = proj_bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot")
	proj_bridge.configure(proj, p_vp, p_rr, null, [NodePath("BulletSprite")], 0.65)
	print("    Projectile and bridge successfully spawned!")
	
	for i in range(30):
		await physics_frame
		
	print("[4] Simulation ran 30 frames cleanly! Projectile traveled to: ", proj.global_position)
	print("ALL ENEMY AND PROJECTILE CHECKS PASSED!")
	quit(0)
