extends CharacterBody2D
## 送餐机器人：2D 战斗实体，3D 模型由 `hotel_robot_visual.gd` 跟随渲染。
##
## 2D 这一层承担碰撞、受击、索敌、移动与开火；子弹走正式 `add_projectile` 链路。
## 受击体积必须是独立的 Hurtbox Area2D（layer 16，组 damage_hurtboxes）——
## basic_projectile 的射线掩码是 1|4|8|16，不含 body 所在的 layer 2，
## 所以直接在 body 上挂 CollisionShape2D 是打不到的。

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const HURTBOX_SCRIPT := preload("res://scenes/dream/rooms/hurtbox.gd")

const MAX_HP := 100.0
const NAV=preload("res://scripts/dream/units/robot_navigation.gd")
const PATROL_SPEED := 30.0
const CHASE_SPEED := 46.0
const DETECT_RANGE := 240.0
const ENGAGE_RANGE := 190.0
const DEPLOY_SECONDS := 0.34
## 视觉模型缩放：raptor 高约 1.0m，×2.4 后与员工立绘的屏幕高度接近。
const SIZE_RATIO := 2.0/3.0
const VISUAL_SCALE := 2.4*SIZE_RATIO

var world: Node3D
var player: Node2D
var bounds := Rect2()
var hp := MAX_HP
var dead := false
var alert := false
var deploy := 0.0
var facing := Vector2.DOWN
var alerted_at_ms := 0

## 3D 血条由外观节点创建并回绑（2D 层的 CanvasItem 不会上屏，见 billboard_health_bar.gd）。
var health_bar_3d: Node3D
var hurtbox: Area2D

var _fire_timer := 0.7
var _repath := 0.0
var _patrol_target := Vector2.ZERO
var _weapon_root: Node2D
var _weapon_motion: Node2D
var _muzzle: Marker2D
var _death_time := 0.0
var visual: Node3D
var shot_serial:=0
var last_shot_side:=-1.0
var _route: Array[Vector2]=[]
var _route_time:=0.0
var _route_goal:=Vector2(INF,INF)
var _magazine_left:=0
var _reload_left:=0.0
var _nav_query: PhysicsShapeQueryParameters2D
var _magazine_primed:=false
var _aiming:=false
var _aim_elapsed:=0.0
var _aim_target:=Vector2.ZERO
var _last_seen_position:=Vector2(INF,INF)


func configure(p_world: Node3D, p_player: Node2D, p_bounds: Rect2) -> void:
	world = p_world
	player = p_player
	bounds = p_bounds
	collision_layer = 2
	collision_mask = 47
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"dream_enemies")

	# 身体碰撞：只用于移动与敌人分离，不参与受击。
	var body_shape := CollisionShape2D.new()
	body_shape.name = "HitShape"
	var circle := CircleShape2D.new()
	circle.radius = 15.0*SIZE_RATIO
	body_shape.shape = circle
	body_shape.position = Vector2.ZERO
	add_child(body_shape)

	# Gameplay collision is in the floor plane, not projected screen pixels.
	# The full 3D model is rendered separately; moving its hurtbox upward in 2D
	# incorrectly makes a different tile receive the shot.
	hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.set_script(HURTBOX_SCRIPT)
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.add_to_group(&"damage_hurtboxes")
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 16.0*SIZE_RATIO
	capsule.height = 32.0*SIZE_RATIO
	hurt_shape.shape = capsule
	hurt_shape.position = Vector2.ZERO
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	# 武器根节点：弹道平面由射手位置推导，这里给出真实枪口（左右炮交替）。
	_weapon_root = Node2D.new()
	_weapon_root.name = "WeaponRoot"
	_weapon_root.position = Vector2(0.0, -30.0)
	add_child(_weapon_root)
	_weapon_motion = Node2D.new()
	_weapon_motion.name = "WeaponMotion"
	_weapon_root.add_child(_weapon_motion)
	_muzzle = Marker2D.new()
	_muzzle.name = "ProjectileOrigin"
	_muzzle.position = Vector2(0.0, 24.0)
	_weapon_motion.add_child(_muzzle)

	_pick_patrol_target()
	_magazine_left=maxi(1,int(world.config.assault_rifle_magazine_size))


## 外观节点把 3D 血条回绑给 2D 逻辑层，掉血/死亡时由逻辑层驱动。
## 2D 层的 CanvasItem 在这套管线里不会上屏（视觉全部走 depth bridge），
## 所以血条必须是 3D billboard，由 hotel_robot_visual.gd 创建。
func bind_health_bar(bar: Node3D) -> void:
	health_bar_3d = bar
	if is_instance_valid(health_bar_3d) and health_bar_3d.has_method("redraw"):
		health_bar_3d.call("redraw", hp, MAX_HP)


func hp_ratio() -> float:
	return clampf(hp / MAX_HP, 0.0, 1.0)


func visual_scale() -> float:
	return VISUAL_SCALE


func is_damage_runtime_active() -> bool:
	return not dead


func get_hurt_radius() -> float:
	return 30.0*SIZE_RATIO


func distance_to_hurtbox(world_point: Vector2) -> float:
	return maxf(0.0, global_position.distance_to(world_point) - get_hurt_radius())


func get_damage_number_offset() -> Vector2:
	return Vector2(0.0, -58.0)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world) or world.floor_transition_in_progress:
		return
	_route_time-=delta
	_reload_left=maxf(0.0,_reload_left-delta)
	if player == null or not is_instance_valid(player) or player.get("dead") == true:
		_patrol(delta)
		return
	if _smoke_blocks_player():
		_aiming=false;_aim_elapsed=0.0
		velocity=Vector2.ZERO
		if alert and _last_seen_position.is_finite() and global_position.distance_to(_last_seen_position)>10:
			_move_toward(_last_seen_position,CHASE_SPEED)
		return
	if _can_see_player():_last_seen_position=player.global_position
	var distance := global_position.distance_to(player.global_position)
	if not alert and _can_see_player():
		alert = true
		alerted_at_ms = Time.get_ticks_msec()
	if alert:
		deploy = minf(1.0, deploy + delta / DEPLOY_SECONDS)
		_engage(delta, distance)
		return
	_patrol(delta)


func _patrol(delta: float) -> void:
	deploy = maxf(0.0, deploy - delta / DEPLOY_SECONDS)
	_repath -= delta
	if _repath <= 0.0 or global_position.distance_to(_patrol_target) < 8.0:
		_pick_patrol_target()
	var direction := _patrol_target - global_position
	if direction.length_squared() > 4.0:
		direction = direction.normalized()
		_move_toward(_patrol_target,PATROL_SPEED)
	else:
		velocity = Vector2.ZERO


func _engage(delta: float, distance: float) -> void:
	if _smoke_blocks_player():
		_aiming=false;_aim_elapsed=0.0
		return
	var to_player := player.global_position - global_position
	if to_player.length_squared() < 1.0:
		return
	var dir := to_player.normalized()
	_face(dir)
	if _reload_left<=0.0 and not _magazine_primed and _can_see_player():
		_aiming=true
		if _aim_elapsed<.38: _aim_target=player.global_position
		_aim_elapsed=minf(.5,_aim_elapsed+delta)
	else:
		_aiming=false
	# 武器展开完成后才会开火：先从柜口伸出炮管，再射击。
	if deploy < 0.98:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if distance>ENGAGE_RANGE*.7: _move_toward(player.global_position,CHASE_SPEED)
	elif distance<ENGAGE_RANGE*.45: _move_toward(global_position-dir*64,CHASE_SPEED*.6)
	else: velocity=Vector2.ZERO
	_face(dir)
	_fire_timer -= delta
	if _fire_timer <= 0.0 and _reload_left<=0.0 and (_magazine_primed or _aim_elapsed>=.5) and _can_see_player():
		_fire(dir)
		_fire_timer = firearm_parameters().interval

func firearm_parameters() -> Dictionary:
	return FIREARM_RULES.parameters(world.config,&"assault_rifle")

func get_ranged_telegraph_state() -> Dictionary:
	if _smoke_blocks_player():return {}
	if dead or not _aiming or _magazine_primed or _reload_left>0.0: return {}
	var start:=global_position+facing*20.0
	if is_instance_valid(visual): start=visual.gameplay_muzzle(-1.0 if shot_serial%2==0 else 1.0)
	return {"start":start,"target":_aim_target,"progress":_aim_elapsed/.5}

func _move_toward(goal: Vector2, speed_value: float) -> void:
	goal=goal.clamp(bounds.position+Vector2.ONE*2,bounds.end-Vector2.ONE*2)
	if _route_time<=0.0 or (_route_goal.distance_squared_to(goal)>4096.0 and _route_time<.25):
		_route=NAV.path(self,goal); _route_goal=goal; _route_time=.55
	while not _route.is_empty() and global_position.distance_to(_route[0])<4.0: _route.pop_front()
	if _route.is_empty(): velocity=Vector2.ZERO; return
	var direction:=global_position.direction_to(_route[0])
	velocity=direction*minf(speed_value,global_position.distance_to(_route[0])/maxf(get_physics_process_delta_time(),.001))
	_face(direction)
	move_and_slide()
	if get_slide_collision_count()>0: _route_time=minf(_route_time,.15)


func _face(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0001:
		return
	facing = direction
	if _weapon_root != null:
		_weapon_root.rotation = direction.angle()


## 索敌：先靠射程，再靠真实的 2D 射线（墙体/家具挡视线就看不见）。
func _can_see_player() -> bool:
	if _smoke_blocks_player():return false
	if global_position.distance_to(player.global_position) > DETECT_RANGE:
		return false
	if world != null and world.has_method("is_room_projectile_path_clear"):
		return bool(world.call("is_room_projectile_path_clear", global_position, player.global_position))
	return true

func _smoke_blocks_player() -> bool:
	return is_instance_valid(player) and is_instance_valid(world) and world.has_method("is_smoke_sight_blocked") and world.is_smoke_sight_blocked(global_position,player.global_position)


func _fire(direction: Vector2) -> void:
	if _smoke_blocks_player():return
	if not is_instance_valid(world) or not is_instance_valid(_muzzle):
		return
	if _reload_left>0.0: return
	if _magazine_left<=0: _magazine_left=maxi(1,int(world.config.assault_rifle_magazine_size))
	last_shot_side=-1.0 if shot_serial%2==0 else 1.0
	shot_serial+=1
	var origin:=global_position+direction*20.0+direction.orthogonal()*last_shot_side*24.0
	if is_instance_valid(visual): origin=visual.gameplay_muzzle(last_shot_side)
	_muzzle.global_position=origin
	# Converge on the target from the selected side barrel; parallel offset
	# trajectories otherwise miss a stationary player between the two guns.
	var aim_target:=_aim_target if _aiming else (player.global_position if is_instance_valid(player) else origin+direction)
	var shot_direction:=origin.direction_to(aim_target)
	var rules:=firearm_parameters()
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	FIREARM_RULES.setup_projectile(
		projectile,
		shot_direction,
		rules.damage,
		rules.range,
		rules.speed,
		&"enemy",
		self,
		&"assault_rifle"
	)
	if world.has_method("add_projectile"):
		world.call("add_projectile", projectile, self)
		world.SFX.play_weapon_fire()
		if not _magazine_primed: world.SFX.play_event(&"enemy_fire_cue")
	else:
		projectile.queue_free()
	_magazine_left-=1
	_magazine_primed=true
	_aiming=false
	if _magazine_left==0:
		_reload_left=float(world.config.weapon_reload_duration)
		deploy=0.0
		_magazine_primed=false
		_aim_elapsed=0.0
	if is_instance_valid(visual): visual.flash_muzzle(last_shot_side)


func _pick_patrol_target() -> void:
	_repath = randf_range(1.8, 3.4)
	if bounds.size.x < 32.0 or bounds.size.y < 32.0:
		_patrol_target = position
		return
	_patrol_target = Vector2(
		randf_range(bounds.position.x + 16.0, bounds.end.x - 16.0),
		randf_range(bounds.position.y + 16.0, bounds.end.y - 16.0)
	)
	_patrol_target=_patrol_target.snapped(Vector2(32,32))
	if not NAV.clear(self,_patrol_target):
		_patrol_target=global_position
		for i in 12:
			var candidate:=Vector2(randf_range(bounds.position.x,bounds.end.x),randf_range(bounds.position.y,bounds.end.y)).snapped(Vector2(32,32))
			if NAV.clear(self,candidate): _patrol_target=candidate; break

func defeat_by_parry(_origin: Vector2) -> void:
	if not dead: _die()

func get_weapon_visual_snapshot(point: Vector2) -> Dictionary:
	return visual.get_weapon_visual_snapshot(point) if is_instance_valid(visual) else {}


## 玩家弹道通过 resolve_player_hit 调用，签名固定为四个参数。
func take_damage(amount: float, _hit_origin: Vector2 = Vector2.ZERO, _force: float = 1.0,
		_source: StringName = &"") -> void:
	if dead:
		return
	hp -= amount
	alert = true
	if amount>0.0 and hp>0.0 and is_instance_valid(visual): visual.flash_hit()
	if is_instance_valid(health_bar_3d) and health_bar_3d.has_method("redraw"):
		health_bar_3d.call("redraw", hp, MAX_HP)
	if hp <= 0.0:
		_die()
	elif hp<=MAX_HP*.30 and is_instance_valid(world):
		preload("res://scripts/dream/burning_effects.gd").install(world).ignite(self)


func _die() -> void:
	dead = true
	_aiming=false
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)
	hp = 0.0
	velocity = Vector2.ZERO
	set_physics_process(false)
	_death_time = Time.get_ticks_msec()
	set_meta(&"died_at_ms", _death_time)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("collision_layer",0)
	if is_instance_valid(health_bar_3d):
		health_bar_3d.visible = false
	remove_from_group(&"dream_enemies")
	if is_instance_valid(visual): visual._begin_death()
	# 留 0.55 秒给 3D 外观播放消失，再移除本体。
	if is_inside_tree():
		await get_tree().create_timer(0.55).timeout
	queue_free()
