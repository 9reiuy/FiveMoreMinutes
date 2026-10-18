extends StaticBody2D

## 2D Gameplay collision proxy for PhysicalDoor3D leaf.
## Forwards damage from bullets, kicks, punches, and dashes to the door owner.

var door_owner: Node3D = null
var leaf_index: int = 0


func take_damage(amount: float, direction: Vector2 = Vector2.ZERO, force: float = 1.0) -> void:
	if door_owner != null and is_instance_valid(door_owner) and door_owner.has_method("take_damage"):
		door_owner.call("take_damage", amount, direction, force, leaf_index)


func is_damage_runtime_active() -> bool:
	return door_owner != null and is_instance_valid(door_owner) and not bool(door_owner.get("is_destroyed"))
