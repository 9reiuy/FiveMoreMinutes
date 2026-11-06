extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	var effects_root = scene.get_node("GameplayCanvas/GameplayWorld/WorldEffectsRoot")
	print("Bullet count at spawn: ", effects_root.get_child_count())
	for idx in range(effects_root.get_child_count()):
		var b = effects_root.get_child(idx)
		print("  Bullet %d: pos=%s vel=%s speed=%s" % [idx, b.global_position, b.velocity, b.speed])

	for f in range(10):
		await physics_frame
		print("FRAME %d: count=%d" % [f, effects_root.get_child_count()])
		for idx in range(effects_root.get_child_count()):
			var b = effects_root.get_child(idx)
			print("  Bullet %d: pos=%s" % [idx, b.global_position])

	quit(0)
