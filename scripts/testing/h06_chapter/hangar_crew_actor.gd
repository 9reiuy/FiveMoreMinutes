extends EmployeeEnemy
## Uses the existing character pose/capture rig, with no combat authority.
var portrait_atlas: Texture2D
var engineer := false
var work_activity: RefCounted

func start_work(role: int) -> void:
	work_activity = preload("res://scripts/testing/h06_chapter/hangar_crew_activity.gd").new()
	work_activity.bind(self,role)

func _character_atlas() -> Texture2D:
	return portrait_atlas

func _back_atlas_region() -> Rect2:
	return Rect2(64,0,32,32)

func _setup_character_parts() -> void:
	super._setup_character_parts()
	set_meta(&"character_authored_facing_x", 0.0)
	left_leg.texture = _make_employee_atlas_texture(Rect2(108,44,4,9))
	right_leg.texture = _make_employee_atlas_texture(Rect2(113,44,4,9))
	left_hand.texture = _make_employee_atlas_texture(Rect2(102,79,5,4))
	right_hand.texture = _make_employee_atlas_texture(Rect2(117,79,5,4))
	left_leg.position = body_pivot.position + head.position + Vector2(10,26)
	right_leg.position = body_pivot.position + head.position + Vector2(15,26)
	left_hand.position = Vector2(-12,6)
	right_hand.position = Vector2(5,6)
	left_leg_base_position = left_leg.position
	right_leg_base_position = right_leg.position
	left_hand_base_position = left_hand.position
	right_hand_base_position = right_hand.position

func _ready() -> void:
	set_meta(&"narrative_character_pose", true)
	super._ready()
	for group in get_groups(): remove_from_group(group)
	target = null
	hostile = false
	can_see_target = false
	has_last_known_target_position = false
	held_weapon_id = ""
	weapon_root.hide()
	base_visual_scale = Vector2.ONE * 0.92
	character_visual.scale = base_visual_scale
	_disable_damage_and_collision()
	for area: Area2D in find_children("*","Area2D",true,false):
		area.collision_layer = 0
		area.collision_mask = 0
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	if health_bar != null: health_bar.hide_immediately()
	if engineer:
		safety_helmet = SAFETY_HELMET.new()
		helmet_equipped = true
		safety_helmet.attach(self,head)
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	show()

func face(direction: Vector2) -> void:
	last_facing_direction = direction.normalized()
	_set_back_facing(direction.y < -0.2)
	if absf(direction.x) > 0.05: character_visual.scale.x = -signf(direction.x)*absf(base_visual_scale.x)

func pose_escape_run(direction: Vector2, phase: float, running: bool) -> void:
	face(direction)
	var stride := sin(phase) if running else 0.
	left_leg.position = left_leg_base_position+Vector2(0,stride*1.35)
	right_leg.position = right_leg_base_position-Vector2(0,stride*1.35)
	left_hand.position = left_hand_base_position+Vector2(0,stride*1.5)
	right_hand.position = right_hand_base_position-Vector2(0,stride*1.5)
	character_visual.position = character_visual_base_position-Vector2(0,absf(stride)*.6)

func _set_back_facing(back: bool) -> void:
	if dead: return
	# All three authored sheets shift their rear coat three pixels right.
	# Register that drawing to the planted feet, including the separate helmet.
	var draw_offset := Vector2(-3,0) if back else Vector2.ZERO
	head.offset = draw_offset
	body.offset = draw_offset
	super._set_back_facing(back)
	if engineer and safety_helmet != null and is_instance_valid(safety_helmet.sprite):
		safety_helmet.sprite.position = SAFETY_HELMET.HEAD_OFFSET + draw_offset

func pose_corpse(angle: float, variant: int) -> void:
	_set_back_facing(false)
	dead = true
	current_health = 0
	death_landed = true
	death_presentation_left = 1000000000.0
	knockdown_height = 0
	death_ground_velocity = Vector2.ZERO
	death_vertical_speed = 0
	death_plasma_spawned = true
	death_pool_spawned = true
	corpse_bleed_spawned = true
	_prepare_corpse_upper_parts()
	_set_enemy_head_frame(2)
	character_visual.rotation = angle
	ragdoll_active = false
	ragdoll_head_rot = -0.13 if variant%2 == 0 else 0.17
	ragdoll_left_hand_rot = -0.38
	ragdoll_right_hand_rot = 0.58
	ragdoll_left_foot_rot = -0.16
	ragdoll_right_foot_rot = 0.21
	ragdoll_left_hand_pos = Vector2(-1,2)
	ragdoll_right_hand_pos = Vector2(2,-1)
	_apply_ragdoll_transforms()
	modulate = Color(0.82,0.82,0.82,1)

func pose_living() -> void:
	# A prepared return room may have been built before the story choice.
	# Reuse its three sources, restoring the complete normal upper-body rig.
	dead=false
	current_health=maximum_health
	death_presentation_left=0
	death_landed=false
	ragdoll_active=false
	character_visual.rotation=0
	character_visual.position=character_visual_base_position
	character_visual.scale=base_visual_scale
	body_pivot.position=body_pivot_base_position
	body_pivot.rotation=0
	head.position=head_base_position
	head.rotation=0
	head.offset=Vector2.ZERO
	body.offset=Vector2.ZERO
	_setup_character_parts()
	_set_back_facing(false)
	_set_enemy_head_frame(0)
	left_leg.rotation=0
	right_leg.rotation=0
	left_hand.rotation=0
	right_hand.rotation=0
	modulate=Color.WHITE
	_disable_damage_and_collision()

func is_damage_runtime_active() -> bool:
	return false

func set_room_runtime_active(_active: bool) -> void:
	pass

func take_damage(_amount: float, _origin: Vector2 = Vector2.INF, _force: float = 1.0, _source: StringName = &"player_projectile") -> void:
	pass

func _die() -> void:
	pass

func receive_corpse_contact(_impulse: Vector2) -> void:
	pass
