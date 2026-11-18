extends "res://tests/h06_boss_attacks_test.gd"
func run() -> void:
	node_added.connect(func(node:Node):
		if node.get_script()==CHAPTER:node.set_meta(&"h06_soft_warnings",true))
	await super.run()
