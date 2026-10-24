extends Node
## Space's sole gameplay controller. The player remains the only physics actor.
const VISUAL := preload("res://scripts/dream/phase_dash_visual_3d.gd")
const TAIL_DURATION := .24
var player: CharacterBody2D
var active := false
var origin := Vector2.ZERO
var endpoint := Vector2.ZERO
var direction := Vector2.RIGHT
var elapsed := 0.0
var damage := 0.0
var source: StringName = &"player_punch"
var old_layer := 0
var old_mask := 0
var world: Node
var floor_token := -1
var effect: Node3D
var tail_left := 0.0
var previous_usec := 0
var query := PhysicsShapeQueryParameters2D.new()
var last_result := {"hits":0,"kills":0}
var body_scale := Vector2.ONE
var handled := {}
var previous_attack_position := Vector2.ZERO
var impact_played := false

func _strike_segment(point: Vector2) -> void:
	if not _current(): return
	var result: Dictionary = world.resolve_phase_dash_attack(previous_attack_position,point,float(player.runtime_config.phase_dash_attack_radius),damage,source,handled,not impact_played)
	last_result.hits += int(result.get("hits",0))
	last_result.kills += int(result.get("kills",0))
	impact_played = impact_played or int(result.get("hits",0))>0
	previous_attack_position = point

func configure(actor: CharacterBody2D) -> void:
	player = actor
	query.collide_with_bodies = true
	query.collide_with_areas = false
	previous_usec = Time.get_ticks_usec()

func _current() -> bool:
	return is_instance_valid(world) and (floor_token < 0 or int(world.get("_layout_generation"))==floor_token)

func _standable(point: Vector2, mask: int) -> bool:
	if not player._dash_floor_position_valid(point): return false
	var shape: CollisionShape2D = player.body_collision
	var offset := shape.global_position-player.global_position
	var radius := float(shape.shape.radius) if shape.shape is CircleShape2D else 8.0
	for i in 8:
		if not player._dash_floor_position_valid(point+offset+Vector2.RIGHT.rotated(i*PI/4)*radius): return false
	query.shape = shape.shape
	query.transform = Transform2D(shape.global_rotation,point+offset)
	query.collision_mask = mask
	query.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func find_landing(start: Vector2, heading: Vector2, distance: float, mask: int) -> Vector2:
	# Walls and void are phaseable; only the landing footprint must be safe.
	# Search backwards without exceeding range, stopping on this side of an
	# exterior edge only when no reachable floor exists beyond the gap.
	var steps := ceili(distance/2.0)
	for i in range(steps+1):
		var point := start+heading*maxf(0.0,distance-i*2.0)
		if _standable(point,mask): return point
	return Vector2.INF

func _recover_landing(distance: float) -> Vector2:
	var landing := find_landing(origin,direction,distance,old_mask)
	if landing.is_finite(): return landing
	# Exceptional case: moving furniture covers the entire original segment.
	# Search nearby first, then the current floor; never restore inside a wall.
	for radius in range(8,257,8):
		for i in 16:
			var point := origin+Vector2.RIGHT.rotated(i*TAU/16)*radius
			if _standable(point,old_mask): return point
	var nearest := Vector2.INF
	var best := INF
	for cell in world.floor_cells:
		var point := Vector2(cell)*32.0
		var cost := origin.distance_squared_to(point)
		if cost<best and _standable(point,old_mask):
			nearest = point
			best = cost
	return nearest

func try_start() -> bool:
	if active or not player.can_start_dash_aim(true) or not player.attacking_enabled or player.throw_aim_active or player.tactical_plan_active or player.is_dash_hunger_disabled() or not player._presentation_pointer_input_allowed(): return false
	world = player._dream_world()
	if world == null or not world.has_method("resolve_phase_dash_attack"): return false
	origin = player.global_position
	direction = origin.direction_to(player.get_constrained_aim_position())
	if direction.length_squared()<.001: direction = player.last_aim_direction.normalized()
	if direction.length_squared()<.001: direction = Vector2.RIGHT
	old_layer = player.collision_layer
	old_mask = player.collision_mask
	endpoint = find_landing(origin,direction,player.dash_distance,old_mask)
	if not endpoint.is_finite() or origin.distance_to(endpoint)<1.0: return false
	floor_token = int(world.get("_layout_generation"))
	source = StringName(player.melee_weapon_id) if not player.melee_weapon_id.is_empty() else &"player_punch"
	var weapon: Node = player._get_weapon_node(player.melee_weapon_id)
	damage = float(weapon.damage) if is_instance_valid(weapon) else float(player.runtime_config.player_punch_damage)
	player._cancel_melee_visual()
	player._cancel_punch()
	player._cancel_dash_input()
	player._set_weapon_activity(false)
	player.dash_charges -= 1
	player.dash_cooldown_left = player.dash_cooldown
	player.dash_start = origin
	player.dash_end = endpoint
	player.active_dash_duration = player.dash_duration
	player.dash_elapsed = 0.0
	player.dash_roll_direction = direction
	player.dashing = true
	player.is_diving = false
	player.dash_invulnerability_left = player.dash_duration
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector2.ZERO
	player._time_locomotion_velocity = Vector2.ZERO
	elapsed = 0.0
	tail_left = 0.0
	last_result = {"hits":0,"kills":0}
	handled.clear()
	impact_played = false
	previous_attack_position = origin
	active = true
	body_scale = player.body_pivot.scale
	if is_instance_valid(player.held_weapon_sprite): player.held_weapon_sprite.visible = not player.selected_weapon_id.is_empty()
	if not is_instance_valid(effect):
		effect = VISUAL.new()
		effect.name = "PlayerPhaseDashVisual"
		world.floor_root.add_child(effect)
	effect.begin(world,player,origin,endpoint)
	preload("res://scripts/audio/sfx_manager.gd").play_event(&"dash")
	_strike_segment(origin)
	player._emit_dash_state()
	return true

func step(delta: float) -> void:
	if not active: return
	if not _current() or player.dead or not player.movement_enabled or not player.attacking_enabled:
		cancel()
		return
	elapsed += maxf(delta,0.0)
	var progress := clampf(elapsed/maxf(player.dash_duration,.001),0.0,1.0)
	player.dash_elapsed = elapsed
	player.dash_invulnerability_left = maxf(player.dash_duration-elapsed,.001)
	player.global_position = origin.lerp(endpoint,progress)
	player.velocity = Vector2.ZERO
	player.visual.rotation = 0.0
	var snap := sin(pow(progress,.65)*PI)
	player.body_pivot.rotation = player.body_base_rotation + snap*.32*(-1 if direction.x>0 else 1)
	player.body_pivot.scale = body_scale*Vector2(1.0+snap*.08,1.0-snap*.06)
	if is_instance_valid(effect): effect.sync_pose(world,player,progress,1.0,false)
	if progress < 1.0:
		_strike_segment(player.global_position)
		return
	# A moving prop/enemy can occupy a previously legal endpoint during 140ms.
	var landing := find_landing(origin,direction,origin.distance_to(endpoint),old_mask)
	if not landing.is_finite():
		# Recovery is not a successful dash and must not deal remote damage.
		landing = _recover_landing(origin.distance_to(endpoint))
		if landing.is_finite():
			player.global_position = landing
			_restore()
			if is_instance_valid(effect): effect.fade(0.0)
		return
	endpoint = landing
	player.global_position = endpoint
	_strike_segment(endpoint)
	var killed := int(last_result.get("kills",0))>0
	_restore()
	if killed:
		player.dash_charges = mini(player.max_dash_charges,player.dash_charges+1)
		player.dash_cooldown_left = player.dash_cooldown if player.dash_charges<player.max_dash_charges else 0.0
	tail_left = TAIL_DURATION
	if is_instance_valid(effect): effect.finish(endpoint,killed)
	player._emit_dash_state()

func _restore() -> void:
	active = false
	player.collision_layer = old_layer
	player.collision_mask = old_mask
	player.dashing = false
	player.is_diving = false
	player.dash_invulnerability_left = 0.0
	player.velocity = Vector2.ZERO
	player.visual.rotation = 0.0
	player.body_pivot.scale = body_scale
	player.body_pivot.rotation = player.body_base_rotation
	player.dash_roll_visual_offset = Vector2.ZERO
	player._set_weapon_activity(not player.dead)
	player._update_direction_animation(Vector2.ZERO,0.0)
	player._update_visual_feedback()

func cancel() -> void:
	if active:
		if _current():
			var landing := _recover_landing(origin.distance_to(player.global_position))
			if landing.is_finite(): player.global_position = landing
			else: return
		_restore()
	tail_left = 0.0
	if is_instance_valid(effect): effect.fade(0.0)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now-previous_usec)/1000000.0,0.0,.1)
	previous_usec = now
	if active or tail_left<=0.0: return
	tail_left = maxf(0.0,tail_left-real_delta)
	if is_instance_valid(effect): effect.fade(tail_left/TAIL_DURATION)

func _exit_tree() -> void:
	if active and is_instance_valid(player): _restore()
	if is_instance_valid(effect): effect.queue_free()
