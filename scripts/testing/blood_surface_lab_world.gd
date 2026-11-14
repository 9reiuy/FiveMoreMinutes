extends "res://scripts/testing/lab_world.gd"
var surface_blood: Node3D
var blood_wound_height := .88
var accepted_blood_events := 0
func spawn_black_blood(at_position: Vector2, direction: Vector2 = Vector2.ZERO, lethal: bool = false, _source_room_id: int = -1, intensity: float = 1.0, _droplet_multiplier: float = 1.0, _speed_multiplier: float = 1.0, _spread_multiplier: float = 1.0) -> bool:
	if not is_instance_valid(surface_blood): return true
	var heading := global_basis*Vector3(direction.x,0,direction.y)
	var wound := get_gameplay_world_position(at_position,blood_wound_height)
	for bridge in actor_depth_bridges_root.get_children():
		var actor: Variant = bridge.get("source_actor")
		if actor is EmployeeEnemy and actor.global_position.distance_to(at_position) <= 28.0 and bridge.has_method("get_hit_feedback_world_position"):
			wound = bridge.get_hit_feedback_world_position()
			break
	surface_blood.emit_spray(wound,heading,lethal,maxf(intensity,.85))
	accepted_blood_events += 1
	return true

func spawn_death_blood_pool(at_position: Vector2, _source_room_id: int = -1, intensity: float = 1.0, _dismember: bool = false, direction: Vector2 = Vector2.ZERO) -> void:
	if is_instance_valid(surface_blood):
		surface_blood.emit_drips(get_gameplay_world_position(at_position,.12),8,3.5*clampf(intensity,.7,1.4))

func spawn_blood_trail(at_position: Vector2, _source_room_id: int = -1, _direction: Vector2 = Vector2.ZERO, intensity: float = 1.0, airborne_count: int = 0) -> void:
	if is_instance_valid(surface_blood):
		surface_blood.emit_drips(get_gameplay_world_position(at_position,.12),clampi(airborne_count,2,5),2.0*clampf(intensity,.7,1.4))

func clear_preview_blood() -> void:
	drag_art_reports.clear()
	if is_instance_valid(surface_blood): surface_blood.clear_blood()
	for effect in world_effects_root.get_children():
		if effect is BlackBloodEffect: effect.queue_free()
