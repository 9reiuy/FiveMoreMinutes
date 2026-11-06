extends "res://scripts/entities/dream_player.gd"
## Lab-only immunity: no permanent hurt timer, blink or changed max HP.
var lab_ignore_damage := true
func receive_damage(amount:float,damage_source:StringName=&"enemy_contact",source_position:Vector2=Vector2.INF,source_direction:Vector2=Vector2.ZERO)->void:
	if not lab_ignore_damage: super.receive_damage(amount,damage_source,source_position,source_direction)
