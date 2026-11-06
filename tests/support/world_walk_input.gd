extends RefCounted
## Test driver: turn a requested map direction into actual screen-relative keys.
static func hold(player: Node, desired: Vector2) -> void:
	var basis:=Transform2D(player._camera_relative_movement_input(Vector2.RIGHT),player._camera_relative_movement_input(Vector2.DOWN),Vector2.ZERO)
	var screen:=basis.affine_inverse().basis_xform(desired.normalized())
	for entry in [["move_right",screen.x],["move_left",-screen.x],["move_down",screen.y],["move_up",-screen.y]]:
		if entry[1]>.02: Input.action_press(entry[0],entry[1])
		else: Input.action_release(entry[0])
static func release() -> void:
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
