extends "res://tests/h06_boss_attack_load_test.gd"
func run() -> void:
	node_added.connect(func(node:Node):
		if node.get_script()==CHAPTER:node.set_meta(&"h06_soft_warnings",OS.get_environment("H06_WARNING_BASELINE")!="1"))
	await super.run()
