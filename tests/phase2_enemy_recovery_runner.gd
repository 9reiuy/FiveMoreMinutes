extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var test := preload("res://tests/phase2_enemy_recovery_test.gd").new()
	root.add_child(test)
