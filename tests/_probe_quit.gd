extends SceneTree
func _init():
	var f = FileAccess.open("E:/GameProjects/FiveMinuteMore/_probe_quit.txt", FileAccess.WRITE)
	f.store_string("ok")
	f.close()
	print("PROBE_OK")
	quit(0)
