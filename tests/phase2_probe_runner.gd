extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := preload("res://tests/phase2_player_caster_probe.gd").new()
	root.add_child(probe)
