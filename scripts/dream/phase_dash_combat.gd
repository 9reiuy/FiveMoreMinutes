extends RefCounted
## Sweep the ground circle, not the standing sprite's elevated gun hurtbox.
## A shared hit set survives all segments of one dash.
static func resolve(world: Node, _player: CharacterBody2D, start: Vector2, end: Vector2, radius: float, damage: float, source: StringName, already_hit: Variant = null) -> Dictionary:
	# Do not reuse the multi-frame AI cache for a fast sweep, or include a
	# disabled rollback floor that happens to share the same coordinates.
	var enemy_root: Node = world.get("enemy_root")
	var enemies: Array = enemy_root.get_children() if is_instance_valid(enemy_root) else world.get_dream_enemies_snapshot()
	var handled: Dictionary = already_hit if already_hit is Dictionary else {}
	var accepted := 0
	var kills := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D or not enemy.is_in_group(&"dream_enemies") or not enemy.is_inside_tree() or not enemy.can_process() or enemy.is_queued_for_deletion() or enemy.get("dead")==true or handled.has(enemy.get_instance_id()): continue
		var ground_radius := maxf(float(enemy.get_hurt_radius()),0.0) if enemy.has_method("get_hurt_radius") else 0.0
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position,start,end)
		if closest.distance_squared_to(enemy.global_position)>pow(radius+ground_radius,2.0)+.001: continue
		var enemy_id: int = enemy.get_instance_id()
		var result: Dictionary = world.resolve_player_hit(enemy,damage,start,source)
		if result.is_empty(): continue
		handled[enemy_id] = true
		accepted += 1
		if not is_instance_valid(enemy) or enemy.get("dead")==true: kills += 1
	return {"hits":accepted,"kills":kills}
