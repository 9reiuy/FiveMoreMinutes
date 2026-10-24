extends "res://tests/dream3d_door_ai_test.gd"
## Same route test with the new closer disabled in this process only.
func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is PhysicalDoor3D:
			node.door_return_delay=1000000.0
			node._return_hold_left.fill(1000000.0))
