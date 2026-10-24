extends Node3D
## 楼层外巡逻无人机。
##
## 沿立面在墙外侧来回飞，巡逻朝室内，发现目标后机头与射灯转向目标。
## 沿真实外窗巡逻，发现玩家后先打亮探照灯预警，从机身枪口朝玩家开火。
##
## 2D 侧只负责受击：`exterior_drone_proxy.gd` 提供一个独立 Hurtbox（layer 16）
## 位置每帧由本节点同步；机器敌人不显示血条。

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const DRONE_BUILDER := preload("res://scripts/dream/units/drone_model_builder.gd")
const FIRE_RIG := preload("res://scripts/dream/units/drone_weapon_fire.gd")
const PROXY_SCRIPT := preload("res://scripts/entities/exterior_drone_proxy.gd")
const SIZE_RATIO := 2.0/3.0

const CELL_PIXELS := 32.0
const MAX_HP := 100.0
const DETECT_RANGE := 300.0
const SPOT_SECONDS := 0.5
const PATROL_HALF_LENGTH := 1.35
const PATROL_SPEED := 1.15

var world: Node3D
var player: Node2D
var hit_parent: Node2D
var patrol_center := Vector3.ZERO
var patrol_axis := Vector3.RIGHT
var boundary_2d := Vector2.ZERO
var inward_normal := Vector2.RIGHT
var patrol_points: Array[Vector3]=[]
var _waypoint:=0
var _route_direction:=1
var _muzzle_3d: Node3D
var _magazine_left:=0
var _magazine_primed:=false
var _reload_left:=0.0
var _aim_target:=Vector2.ZERO
var outline: Node3D
var body_recoil:=0.0
var hit_flash: Node

var hp := MAX_HP
var _health_bar: Node3D
var _travel := 0.0
var _direction := 1.0
var _cooldown := 0.9
var _spot_elapsed := -1.0
var _spot_light: SpotLight3D
var _rig: Node3D
var _body: Node3D
var _proxy: StaticBody2D
var _muzzle_2d: Node2D
var _dead := false


func _ready() -> void:
	_body = DRONE_BUILDER.build()
	_body.name = "ExteriorDroneBody"
	_body.scale = Vector3.ONE * 1.3*SIZE_RATIO
	add_child(_body)

	var muzzle := _body.get_node_or_null("Weapon/MuzzleBrake") as Node3D
	_muzzle_3d=muzzle
	if muzzle != null:
		_rig = FIRE_RIG.new()
		_rig.name = "MuzzleFire"
		muzzle.add_child(_rig)
		_rig.set("auto_fire", false)
		_rig.set("recoil_strength",.10)
		_rig.set("live_animation",true)
		_rig.set_meta(&"particle_flame",true)
		_rig.call("set_flash_time", 9.0)

	# 探照灯挂在机头正前方：机体正面是 -Z，灯沿 -Z 投出，只带很小的下压角，
	# 所以屏幕上是「一束朝前打的光」而不是照地板的圆斑。
	_spot_light = SpotLight3D.new()
	_spot_light.name = "PatrolLight"
	_spot_light.light_color = Color(1.0, 0.82, 0.55)
	_spot_light.light_energy = 0.0
	_spot_light.spot_range = 18.0
	_spot_light.spot_angle = 20.0
	_spot_light.spot_attenuation = 1.5
	_spot_light.position = Vector3(0.0, 0.1, -0.46)
	_spot_light.rotation.x = deg_to_rad(-12.0)
	_body.add_child(_spot_light)

	_build_proxy()
	global_position = patrol_center
	_apply_facing()
	_sync_2d()
	outline=preload("res://scripts/dream/units/special_unit_outline.gd").new()
	add_child(outline)
	outline.configure(world,_body,_proxy,Vector3.ZERO,2.2*SIZE_RATIO)
	hit_flash=preload("res://scripts/dream/units/special_unit_hit_flash.gd").new()
	add_child(hit_flash); hit_flash.configure(_body)
	_magazine_left=maxi(1,int(world.config.basic_magazine_size))


func _build_proxy() -> void:
	if hit_parent == null or not is_instance_valid(hit_parent):
		return
	_proxy = PROXY_SCRIPT.new()
	_proxy.name = "ExteriorDroneHitbox"
	hit_parent.add_child(_proxy)
	_proxy.call("bind", self, MAX_HP)

	# The gameplay muzzle follows the real 3D barrel, outside the window.
	_muzzle_2d = Node2D.new()
	_muzzle_2d.name = "ExteriorDroneMuzzle"
	_muzzle_2d.set_meta(&"exterior_flying",true)
	hit_parent.add_child(_muzzle_2d)
	_proxy.set_meta(&"dream_room_id",get_meta(&"dream_room_id",-1))


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(world) or world.floor_transition_in_progress:
		return
	_patrol(delta)
	_sync_2d()
	_update_detection(delta)
	_apply_facing()
	_sync_2d()

func _process(delta: float) -> void:
	if _dead: return
	body_recoil=maxf(0.0,body_recoil-delta*5.5)
	if is_instance_valid(_body):
		_body.position.z=body_recoil*.09
		_body.rotation.x=body_recoil*.08


func _patrol(delta: float) -> void:
	if not patrol_points.is_empty():
		var next:=global_position.move_toward(patrol_points[_waypoint],PATROL_SPEED*delta)
		var map_point:=world.to_local(next)
		if world.floor_cells.has(Vector2i(Vector2(map_point.x,map_point.z).round())):
			_route_direction=-_route_direction
			_waypoint=clampi(_waypoint+_route_direction,0,patrol_points.size()-1)
			return
		global_position=next
		if global_position.distance_to(patrol_points[_waypoint])<.01 and patrol_points.size()>1:
			if _waypoint==patrol_points.size()-1: _route_direction=-1
			elif _waypoint==0: _route_direction=1
			_waypoint+=_route_direction
		_apply_facing()
		return
	_travel += _direction * PATROL_SPEED * delta
	if absf(_travel) >= PATROL_HALF_LENGTH:
		_travel = clampf(_travel, -PATROL_HALF_LENGTH, PATROL_HALF_LENGTH)
		_direction = -_direction
		_apply_facing()
	global_position = patrol_center + patrol_axis * _travel


## Patrol faces indoors; target acquisition overrides patrol yaw until its magazine ends.
func _apply_facing() -> void:
	var inward_3d: Vector3=world.global_basis*Vector3(inward_normal.x, 0.0, inward_normal.y)
	var tracking: bool=(_spot_elapsed>=0.0 or _magazine_primed) and is_instance_valid(player) and not player.dead and not _smoke_blocks_player()
	if tracking:
		var point: Vector2=_aim_target if _spot_elapsed>=0.0 else player.global_position
		inward_3d=world.get_gameplay_world_position(point,0.0)-global_position
		inward_3d.y=0.0
	if inward_3d.length_squared() <= 0.0001:
		return
	inward_3d = inward_3d.normalized()
	# 机体正面是 -Z：让 -Z 指向室内方向。
	global_basis=Basis.looking_at(inward_3d,Vector3.UP)
	if is_instance_valid(_spot_light):
		var target: Vector3
		if tracking:
			var point: Vector2=_aim_target if _spot_elapsed>=0.0 else player.global_position
			target=world.get_gameplay_world_position(point,.35)
		else:
			target=global_position+inward_3d*6.0+Vector3.DOWN*1.0
		if _spot_light.global_position.distance_squared_to(target)>.001: _spot_light.look_at(target,Vector3.UP)


func _sync_2d() -> void:
	if _proxy == null or not is_instance_valid(_proxy):
		return
	if world == null or not is_instance_valid(world):
		return
	var local := world.to_local(global_position)
	_proxy.global_position = Vector2(local.x, local.z) * CELL_PIXELS
	if is_instance_valid(_muzzle_2d) and is_instance_valid(_muzzle_3d):
		var muzzle_local:=world.to_local(_muzzle_3d.global_position)
		_muzzle_2d.global_position=Vector2(muzzle_local.x,muzzle_local.z)*CELL_PIXELS


func _update_detection(delta: float) -> void:
	if not is_instance_valid(player) or player.get("dead") == true:
		_set_light(0.0)
		return
	if _smoke_blocks_player():
		_spot_elapsed=-1.0
		_set_light(0.0)
		_cooldown=maxf(0,_cooldown-delta)
		_reload_left=maxf(0,_reload_left-delta)
		return
	if _cooldown > 0.0:
		_cooldown -= delta
	if _reload_left>0.0:
		_reload_left=maxf(0.0,_reload_left-delta)
		return
	if _spot_elapsed >= 0.0:
		if _spot_elapsed<.38: _aim_target=player.global_position
		_spot_elapsed += delta
		_set_light(lerpf(1.4, 5.2, clampf(_spot_elapsed / SPOT_SECONDS, 0.0, 1.0)))
		if _spot_elapsed >= SPOT_SECONDS:
			if _can_see_player(): _fire()
			_spot_elapsed = -1.0
			_set_light(0.0)
		return
	if _cooldown <= 0.0 and _can_see_player():
		if _magazine_primed: _fire()
		else:
			_spot_elapsed = 0.0
			_aim_target=player.global_position


## 只有在「窗口内侧 → 玩家」真的通视时才开火。
## 玻璃不算遮挡（子弹本来就穿过玻璃），墙体、门、家具算。
func _can_see_player() -> bool:
	if _smoke_blocks_player():return false
	if _muzzle_2d == null or not is_instance_valid(_muzzle_2d):
		return false
	var from_2d := _muzzle_2d.global_position
	var to_2d := player.global_position
	if from_2d.distance_to(to_2d) > firearm_parameters().range:
		return false
	if inward_normal.dot((to_2d - boundary_2d).normalized()) < 0.0:
		return false
	if world != null and world.has_method("exterior_drone_sight_clear"):
		return bool(world.call("exterior_drone_sight_clear", from_2d, to_2d))
	if world != null and world.has_method("is_room_projectile_path_clear"):
		return bool(world.call("is_room_projectile_path_clear", from_2d, to_2d))
	return true

func _smoke_blocks_player() -> bool:
	return is_instance_valid(player) and is_instance_valid(world) and is_instance_valid(_muzzle_2d) and world.has_method("is_smoke_sight_blocked") and world.is_smoke_sight_blocked(_muzzle_2d.global_position,player.global_position)

func firearm_parameters() -> Dictionary:
	return FIREARM_RULES.parameters(world.config,&"basic")

func get_ranged_telegraph_state() -> Dictionary:
	if _smoke_blocks_player():return {}
	if _dead or _spot_elapsed<0.0 or not is_instance_valid(_muzzle_2d): return {}
	return {"start":_muzzle_2d.global_position,"target":_aim_target,"progress":clampf(_spot_elapsed/SPOT_SECONDS,0,1)}

func get_weapon_visual_snapshot(gameplay_position: Vector2) -> Dictionary:
	return {"world_origin":_muzzle_3d.global_position,"gameplay_origin":gameplay_position} if is_instance_valid(_muzzle_3d) else {}


func _set_light(energy: float) -> void:
	if _spot_light != null:
		_spot_light.light_energy = energy


func _fire() -> void:
	if _smoke_blocks_player():return
	if not is_instance_valid(_muzzle_2d) or not is_instance_valid(player) or not is_instance_valid(_proxy) or _reload_left>0.0:
		return
	var from_2d := _muzzle_2d.global_position
	var target_point:=_aim_target if _spot_elapsed>=0.0 else player.global_position
	var direction := (target_point - from_2d)
	if direction.length_squared() <= 1.0:
		return
	direction = direction.normalized()
	# 机头转向玩家，火光才会出现在正确的一侧。
	if direction.length_squared() > 0.0001:
		global_basis=Basis.looking_at(world.global_basis*Vector3(direction.x,0,direction.y),Vector3.UP)
		_sync_2d()
		from_2d=_muzzle_2d.global_position
		direction=from_2d.direction_to(target_point)
	if _rig != null:
		_rig.call("fire")
	body_recoil=1.0
	var projectile := PROJECTILE_SCENE.instantiate()
	var rules:=firearm_parameters()
	projectile.global_position = from_2d
	FIREARM_RULES.setup_projectile(
		projectile,
		direction,
		rules.damage,
		rules.range,
		rules.speed,
		&"enemy",
		_proxy,
		&"basic"
	)
	if world.has_method("add_projectile"):
		world.call("add_projectile", projectile, _proxy)
		if is_instance_valid(_muzzle_3d):
			preload("res://scripts/dream/burning_effects.gd").install(world).muzzle(_muzzle_3d.global_position,world.global_basis*Vector3(direction.x,0,direction.y))
		world.SFX.play_weapon_fire()
		if not _magazine_primed: world.SFX.play_event(&"enemy_fire_cue")
	else:
		projectile.queue_free()
	_cooldown = float(rules.interval)
	_magazine_primed=true
	_magazine_left-=1
	if _magazine_left<=0:
		_magazine_left=maxi(1,int(world.config.basic_magazine_size))
		_magazine_primed=false
		_reload_left=float(world.config.weapon_reload_duration)


func health_bar() -> Node3D:
	return _health_bar

func defeat_by_parry(origin: Vector2) -> void:
	if not _dead:
		hp=0.0
		take_damage(1.0,origin,1.0,&"player_projectile_parry")


func take_damage(amount: float, _hit_origin: Vector2 = Vector2.ZERO, _force: float = 1.0,
		_source: StringName = &"") -> void:
	if _dead:
		return
	hp = maxf(0.0, hp - amount)
	if hp>0.0 and hp<=MAX_HP*.30 and is_instance_valid(world):
		preload("res://scripts/dream/burning_effects.gd").install(world).ignite(self)
	if amount>0.0 and hp>0.0 and is_instance_valid(hit_flash): hit_flash.hit(float(world.config.enemy_hit_flash_seconds))
	if _health_bar != null and _health_bar.has_method("redraw"):
		_health_bar.call("redraw", hp, MAX_HP)
	# 被打会立刻进入预警-还击，而不是继续慢慢巡逻。
	_cooldown = 0.0
	if hp <= 0.0:
		_dead = true
		if is_instance_valid(hit_flash): hit_flash.apply(false)
		_spot_elapsed=-1.0
		if is_instance_valid(outline): outline.set_enabled(false)
		if is_instance_valid(_proxy):
			_proxy.dead=true
			_proxy.remove_from_group(&"dream_enemies")
		_set_light(0.0)
		if is_instance_valid(_rig):
			_rig.set_flash_time(9.0)
			_rig.set_process(false)
		var effect:=preload("res://scripts/dream/units/unit_death_effect.gd").new()
		get_parent().add_child(effect)
		effect.begin(_body,true,world)
		if _health_bar != null:
			_health_bar.visible = false
		if is_instance_valid(_proxy):
			_proxy.queue_free()
		if is_instance_valid(_muzzle_2d):
			_muzzle_2d.queue_free()
		if is_inside_tree():
			await get_tree().create_timer(0.45).timeout
		queue_free()
		return


func _notification(what: int) -> void:
	# Reparenting during floor stash must not destroy the surviving 2D proxy.
	if what!=NOTIFICATION_PREDELETE: return
	if is_instance_valid(_proxy):
		_proxy.queue_free()
	if is_instance_valid(_muzzle_2d):
		_muzzle_2d.queue_free()
