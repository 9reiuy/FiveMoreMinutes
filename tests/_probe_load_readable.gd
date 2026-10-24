extends SceneTree
func _init():
	var s = load("res://tests/_capture_nier_readable.gd")
	print("LOAD ", s)
	var p = load("res://scripts/ui/pixel_option_group.gd")
	print("POG ", p)
	quit(0)
