extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	for f in range(10):
		await physics_frame
		print("FRAME %d:" % f)
		for idx in range(enemy_root.get_child_count()):
			var e = enemy_root.get_child(idx)
			print("  Enemy %d: %s at %s" % [idx, e.name, e.global_position])

	quit(0)
