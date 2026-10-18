extends StaticBody2D

## 2D Gameplay collision proxy for BreakableGlassWindow3D.
## Forwards damage from bullets, kicks, punches, and dashes to the window owner.

var window_owner: Node3D = null


func take_damage(amount: float, direction: Vector2 = Vector2.ZERO, force: float = 1.0) -> void:
	if window_owner != null and is_instance_valid(window_owner) and window_owner.has_method("take_damage"):
		window_owner.call("take_damage", amount, direction, force)


func is_damage_runtime_active() -> bool:
	return window_owner != null and is_instance_valid(window_owner) and not bool(window_owner.get("is_shattered"))


func is_window_vault_target() -> bool:
	return false


func get_projectile_blocking_height() -> float:
	if not is_instance_valid(window_owner):
		return 0.0
	return 0.0 if window_owner.is_shattered else window_owner.structural_height


func get_projectile_blocking_rect(height_world: float) -> Rect2:
	var shape_node := get_node("CollisionShape2D") as CollisionShape2D
	var rect := shape_node.shape.get_rect()
	return Rect2() if not is_instance_valid(window_owner) or window_owner.is_shattered else rect


func commit_vault_contact(previous: Vector2, current: Vector2) -> void:
	# Full-height glass no longer participates in the furniture/vault path.
	pass
