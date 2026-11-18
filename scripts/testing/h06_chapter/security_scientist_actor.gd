extends EmployeeEnemy
## A damageable seated character using the normal pose, lighting and death rig, without AI.
signal story_killed
const PORTRAIT:=preload("res://art/Dream/enemy/Scientist2.png")
var seated := true
var turned := false
var story_active := false
var story_bridge:Node3D
var floor_height := 3.04
var story_collision_states:Array[Dictionary]=[]

func _character_atlas()->Texture2D:return PORTRAIT
func _back_atlas_region()->Rect2:return Rect2(64,0,32,32)

func _setup_character_parts()->void:
	super._setup_character_parts()
	set_meta(&"character_authored_facing_x",0.0)
	left_leg.texture=_make_employee_atlas_texture(Rect2(108,44,4,9))
	right_leg.texture=_make_employee_atlas_texture(Rect2(113,44,4,9))
	left_hand.texture=_make_employee_atlas_texture(Rect2(102,79,5,4))
	right_hand.texture=_make_employee_atlas_texture(Rect2(117,79,5,4))
	left_leg.position=body_pivot.position+head.position+Vector2(10,26)
	right_leg.position=body_pivot.position+head.position+Vector2(15,26)
	left_hand.position=Vector2(-12,6)
	right_hand.position=Vector2(5,6)

func _ready()->void:
	set_meta(&"narrative_character_pose",true)
	enemy_archetype=&"scientist"
	super._ready()
	_remove_awareness()
	held_weapon_id=""
	weapon_root.hide()
	if health_bar!=null:health_bar.hide_immediately()
	experience_drop_count=0
	var objects:Array=[self]
	objects.append_array(find_children("*","CollisionObject2D",true,false))
	for object:CollisionObject2D in objects:
		story_collision_states.append({"object":weakref(object),"layer":object.collision_layer,"mask":object.collision_mask})
	set_seated_facing(false)

func set_story_active(value:bool)->void:
	story_active=value
	room_runtime_active=value
	var objects:Array=[self]
	objects.append_array(find_children("*","CollisionObject2D",true,false))
	for object:CollisionObject2D in objects:
		object.collision_layer=0
		object.collision_mask=0
	if value and not dead:
		for state:Dictionary in story_collision_states:
			var object:CollisionObject2D=state.object.get_ref()
			if is_instance_valid(object):
				object.collision_layer=state.layer
				object.collision_mask=state.mask

func _remove_awareness()->void:
	target=null
	hostile=false
	can_see_target=false
	has_last_known_target_position=false
	velocity=Vector2.ZERO

func set_seated_facing(front:bool)->void:
	if dead:return
	turned=front
	var offset:=Vector2.ZERO if front else Vector2(-3,0)
	head.offset=offset
	body.offset=offset
	_set_back_facing(not front)
	body_pivot.position=body_pivot_base_position
	body_pivot.rotation=0
	head.rotation=0
	left_hand.position=Vector2(-9,8)
	right_hand.position=Vector2(4,8)
	# Each short leg pivots at its own hip; no new limb artwork is introduced.
	var hip:=Vector2(2,0)
	left_leg.rotation=-.38 if front else .28
	right_leg.rotation=.38 if front else -.28
	left_leg.position=left_leg_base_position+hip-hip.rotated(left_leg.rotation)
	right_leg.position=right_leg_base_position+hip-hip.rotated(right_leg.rotation)

func _process(delta:float)->void:
	if dead:super._process(delta)
	elif story_active:
		_remove_awareness()
		_update_enemy_blink(delta)

func _physics_process(delta:float)->void:
	if dead:super._physics_process(delta)

func is_damage_runtime_active()->bool:
	var world:=_get_world()
	return story_active and not dead and is_instance_valid(world) and not world.on_lower_floor

func set_room_runtime_active(active:bool)->void:
	room_runtime_active=active
	_remove_awareness()

func take_damage(amount:float,origin:Vector2=Vector2.INF,force:float=1.0,source:StringName=&"player_projectile")->void:
	super.take_damage(amount,origin,force,source)
	if not dead:
		_remove_awareness()
		set_seated_facing(turned)

func _die()->void:
	if dead:return
	seated=false
	head.offset=Vector2.ZERO
	body.offset=Vector2.ZERO
	_set_back_facing(false)
	left_leg.rotation=0
	right_leg.rotation=0
	left_leg.position=left_leg_base_position
	right_leg.position=right_leg_base_position
	if is_instance_valid(story_bridge):story_bridge.ground_surface_height=floor_height
	super._die()
	if dead:story_killed.emit()
