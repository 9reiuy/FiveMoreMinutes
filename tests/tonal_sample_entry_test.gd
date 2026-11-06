extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: PackedScene=load("res://scenes/preview/tonal_stability_preview.tscn")
	var instance: Control=scene.instantiate()
	var valid: bool=instance.has_method("apply_sample") and instance.tonal_enabled and instance.stability_enabled
	instance.free()
	print("TONAL_ENTRY checks=1 failures=",0 if valid else 1)
	quit(0 if valid else 1)
