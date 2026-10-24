extends Node
## Floor-owned defense queries. Projectile movement remains authoritative.
var world: Node
var click_serial := 0
var claimed_serial := 0
var click_at := -1.0
var clock := 0.0
var chain_ready := false
var hit_feedback_count := 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		register_click()
	elif event is InputEventKey and not event.echo and InputMap.has_action("attack") and event.is_action_pressed("attack"):
		register_click()

func register_click() -> void:
	if not available(): return
	click_serial+=1
	click_at=clock
	var controller: Node = world.player._get_dream_time_controller()
	if chain_ready and controller!=null and controller.is_reaction_time_active():
		var weapon: Node=world.player._get_weapon_node(world.player.selected_weapon_id)
		if weapon!=null and world.player.selected_weapon_id in ["lucille","books"]:
			weapon.cancel_swing()
			weapon.cooldown_left=0.0
			chain_ready=false

func claim_click() -> bool:
	if not available() or click_serial==claimed_serial or clock-click_at>.15: return false
	claimed_serial=click_serial
	return true

func available() -> bool:
	return is_instance_valid(world) and is_instance_valid(world.player) and not world.player.dead and world.player.movement_enabled and world.player.attacking_enabled and world.transition_phase==&"IDLE" and not world.floor_transition_in_progress and not get_tree().paused

func _process(delta: float) -> void:
	clock+=delta/maxf(Engine.time_scale,.001)
	if not available():
		chain_ready=false
		claimed_serial=click_serial

func inspect_segment(bullet: Node, start: Vector2, end: Vector2) -> bool:
	if not available() or bullet.source_faction!=&"enemy" or bullet.consumed: return false
	var player: Node=world.player
	var weapon: Node=player._get_weapon_node(player.selected_weapon_id)
	if player.selected_weapon_id in ["lucille","books"] and weapon!=null and weapon.melee_action_active and weapon.parry_armed and weapon.swing_elapsed>=weapon.windup_seconds and weapon.swing_elapsed<=weapon.windup_seconds+weapon.strike_seconds and not player.dashing:
		var entry: Variant=circle_entry(start,end,player.global_position,float(weapon.attack_range))
		if entry is Vector2 and (entry-player.global_position).normalized().dot(weapon.swing_direction)>=cos(weapon.attack_arc_radians*.5) and Vector2(bullet.direction).dot(player.global_position-start)>0:
			var blocking: Dictionary=bullet._cast_movement_segment(start,entry)
			if blocking.is_empty() or (is_instance_valid(blocking.get("collider")) and bullet._resolve_damage_owner(blocking.collider)==player):
				bullet.reflect_from_player(player,entry)
				if not weapon.parry_feedback_sent:
					weapon.parry_feedback_sent=true
					chain_ready=true
					hit_feedback_count+=1
					var controller: Node=player._get_dream_time_controller()
					if controller!=null: controller.begin_reaction_time(&"parry")
					world.spawn_parry_feedback(entry)
				return true
	# Measure the real projectile hurt capsule, not the sprite's floor anchor.
	if not bullet.get_meta(&"near_miss_used",false) and not player.dead:
		var hurt: CollisionShape2D=player.get_node("ProjectileHurtbox/CollisionShape2D")
		var capsule: CapsuleShape2D=hurt.shape
		var center: Vector2=hurt.global_position
		var half_spine:=maxf(0.0,capsule.height*.5-capsule.radius)
		var spine:=hurt.global_transform.y.normalized()*half_spine
		var points:=Geometry2D.get_closest_points_between_segments(start,end,center-spine,center+spine)
		var distance:=points[0].distance_to(points[1])
		var offset: Vector2=center-start
		if distance>capsule.radius and distance<capsule.radius+8 and offset.dot(bullet.direction)>0 and (center-end).dot(bullet.direction)<=0:
			var blocking: Dictionary=bullet._cast_movement_segment(start,end)
			if blocking.is_empty():
				bullet.set_meta(&"near_miss_used",true)
				var controller: Node=player._get_dream_time_controller()
				if controller!=null: controller.begin_reaction_time(&"near_miss")
	return false

func circle_entry(start: Vector2,end: Vector2,center: Vector2,radius: float) -> Variant:
	if start.distance_squared_to(center)<=radius*radius: return start
	var segment:=end-start
	var offset:=start-center
	var a:=segment.length_squared()
	if a<.000001: return null
	var b:=2.0*offset.dot(segment)
	var c:=offset.length_squared()-radius*radius
	var disc:=b*b-4.0*a*c
	if disc<0: return null
	var t:=(-b-sqrt(disc))/(2.0*a)
	return start+segment*t if t>=0 and t<=1 else null
