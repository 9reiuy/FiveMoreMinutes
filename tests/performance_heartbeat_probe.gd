extends "res://tests/random_combat_perf.gd"
## Reuse the existing real-render combat fixture; isolate unrelated local diagnostics.
func run() -> void:
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	await super.run()
