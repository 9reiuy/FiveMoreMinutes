extends "res://tests/rendering_backend_unification_camera_test.gd"
## The opposite side must use the same real cab/office handoff with its own yaw.
func _initialize() -> void:
	selected_lobby_door_index=5
	stop_after_first_office=true
	super._initialize()
