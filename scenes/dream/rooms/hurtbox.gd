extends Area2D

@onready var damage_owner = get_parent()


func get_damage_owner() -> Node:
	return damage_owner


func receive_damage(
	damage: float,
	hit_direction: Vector2,
	knockback_force: float = 1.0
) -> void:
	if damage_owner != null and damage_owner.has_method("take_damage"):
		damage_owner.take_damage(
			damage,
			hit_direction,
			knockback_force
		)
