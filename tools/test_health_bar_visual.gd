extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTING BILLBOARD HEALTH BAR ===")
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	var bridges_root = scene.get_node("ActorDepthBridges")
	var hb_script = preload("res://scripts/dream/units/billboard_health_bar.gd")

	for idx in range(enemy_root.get_child_count()):
		var enemy = enemy_root.get_child(idx)
		var hb = hb_script.new()
		bridges_root.add_child(hb)
		hb.position = Vector3(enemy.global_position.x / 32.0, 1.45, enemy.global_position.y / 32.0)
		hb.redraw(enemy.current_health, 10.0)
		print("Attached health bar to enemy %d (%s) at %s" % [idx, enemy.name, hb.position])

	for i in range(10):
		await physics_frame

	print("Health bar test PASSED!")
	quit(0)
