extends EmployeeEnemy
## Projectile-compatible training authority; the dummy has no human AI or corpse.
const MODEL=preload("res://art/Dream/enemy/Human body model.png")

func prepare_model() -> void:
	var frame:=AtlasTexture.new();frame.atlas=MODEL;frame.region=Rect2(0,0,32,32)
	body_pivot.position=Vector2.ZERO
	head.texture=frame;head.position=Vector2(-16,-32);head.centered=false
	body.hide();left_hand.hide();right_hand.hide();left_leg.hide();right_leg.hide()
	# The passive 3D projection uses foot bounds as its floor-contact reference.
	var foot:=AtlasTexture.new();foot.atlas=MODEL;foot.region=Rect2(9,27,5,5)
	left_leg.texture=foot;right_leg.texture=foot
	left_leg_base_position=Vector2(-4,-5);right_leg_base_position=Vector2(1,-5)
	left_leg.position=left_leg_base_position;right_leg.position=right_leg_base_position
	set_process(false);set_physics_process(false)
	set_meta(&"training_model_source",MODEL.resource_path)

func take_damage(amount: float,_hit_origin: Vector2=Vector2.INF,_knockback_force: float=1.0,_damage_source: StringName=&"player_projectile") -> void:
	if dead or amount<=0.0 or not is_damage_runtime_active():return
	current_health=maxf(0.0,current_health-amount)
	if current_health<=0.0:_die()

func _die() -> void:
	if dead:return
	dead=true;velocity=Vector2.ZERO
	_disable_damage_and_collision()
	defeated.emit(global_position,0)
