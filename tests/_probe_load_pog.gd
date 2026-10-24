extends SceneTree
func _init():
	var s = load("res://scripts/ui/pixel_option_group.gd")
	print("LOAD_OK ", s != null)
	quit(0 if s != null else 1)
