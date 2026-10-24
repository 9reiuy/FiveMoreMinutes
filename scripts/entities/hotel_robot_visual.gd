extends Node3D
## 送餐机器人的 3D 外观：把 `hotel_robot_unit` 的 2D 逻辑位置映射到 3D 世界，
## 驱动颜文字表情与左右武器展开。
##
## 位置换算使用地牢自己的约定：2D 像素 / CELL_PIXELS = 3D 米，模型原点在脚底，
## 因此不做假高度抬升（那是给 2D 立绘用的 screen-space 补偿）。

const ROBOT_BUILDER := preload("res://scripts/dream/units/hotel_robot_builder.gd")
const CELL_PIXELS := 32.0

var world: Node3D
var unit: Node2D

var _model: Node3D
var _rig: Node3D
var _expression := ""
var _alert_started := -1.0
var _dying := false
var _base_scale := Vector3.ONE
var _flash_left:=0.0
var _flash: MeshInstance3D
var _flash_side:=-1.0
var recoil: Dictionary={-1.0:0.0,1.0:0.0}
var gun_rest: Dictionary={}
var outline: Node3D
var hit_flash: Node


func _ready() -> void:
	# configure() 之前 _process 不能跑：那时 unit 还是 null，会被判成失效自毁。
	set_process(false)


func configure(p_world: Node3D, p_unit: Node2D, visual_scale: float) -> void:
	world = p_world
	unit = p_unit
	name = "HotelRobotVisual_%d" % (unit.get_instance_id() % 100000)
	_model = ROBOT_BUILDER.build("calm")
	_model.name = "RobotModel"
	_base_scale = Vector3.ONE * maxf(visual_scale, 0.1)
	_model.scale = _base_scale
	add_child(_model)
	_rig = _model.get_node_or_null("WeaponRig") as Node3D
	for side in [-1.0,1.0]:
		var gun: Node3D=muzzle_node(side).get_parent_node_3d()
		gun_rest[side]=gun.position
	outline=preload("res://scripts/dream/units/special_unit_outline.gd").new()
	add_child(outline)
	outline.configure(world,_model,unit,Vector3(0,1.35,0)*unit.SIZE_RATIO,2.0*unit.SIZE_RATIO)
	hit_flash=preload("res://scripts/dream/units/special_unit_hit_flash.gd").new()
	add_child(hit_flash); hit_flash.configure(_model)
	_expression = "calm"
	if unit != null and unit.is_inside_tree():
		_sync_transform()
	set_process(true)


func _process(delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		queue_free()
		return
	if unit.get("dead")==true:
		_begin_death()
		return
	for side in recoil: recoil[side]=maxf(0.0,float(recoil[side])-delta*.8)
	_sync_transform()
	_sync_pose()
	_sync_expression()
	_flash_left=maxf(0.0,_flash_left-delta)
	if is_instance_valid(_flash):
		_flash.visible=_flash_left>0.0
		_flash.global_position=muzzle_node(_flash_side).global_position
		_flash.scale=Vector3.ONE*(.7+_flash_left*12.0)


func _sync_transform() -> void:
	if world == null or not is_instance_valid(world):
		return
	var flat: Vector2 = unit.global_position
	global_position = world.to_global(Vector3(flat.x / CELL_PIXELS, 0.0, flat.y / CELL_PIXELS))
	var facing: Vector2 = unit.get("facing")
	if facing.length_squared() > 0.0001:
		# 模型正面是 +Z，2D 的 +Y 对应 3D 的 +Z，所以直接 atan2(x, y)。
		rotation.y = atan2(facing.x, facing.y)

func muzzle_node(side: float) -> Node3D:
	return _model.get_node_or_null("WeaponRig/Bay%s/ArmPivot/Gun/MuzzleBrake" % ("L" if side<0.0 else "R"))

func gameplay_muzzle(side: float) -> Vector2:
	_sync_transform(); _sync_pose()
	var muzzle:=muzzle_node(side)
	var local:=world.to_local(muzzle.global_position)
	return Vector2(local.x,local.z)*CELL_PIXELS

func get_weapon_visual_snapshot(point: Vector2) -> Dictionary:
	_sync_transform(); _sync_pose()
	var side: float=(-1.0 if unit.shot_serial%2==0 else 1.0) if unit._aiming else unit.last_shot_side
	var muzzle:=muzzle_node(side)
	return {"world_origin":muzzle.global_position,"gameplay_origin":point}

func flash_muzzle(side: float) -> void:
	if is_instance_valid(world) and is_instance_valid(unit):
		var direction: Vector2=unit.facing
		preload("res://scripts/dream/burning_effects.gd").install(world).muzzle(muzzle_node(side).global_position,world.global_basis*Vector3(direction.x,0,direction.y))
	_flash_side=side
	recoil[side]=.10
	_flash_left=.07

func flash_hit() -> void:
	if is_instance_valid(hit_flash): hit_flash.hit(float(world.config.enemy_hit_flash_seconds))


func _sync_pose() -> void:
	if _rig != null:
		var deploy: float = clampf(float(unit.get("deploy")), 0.0, 1.0)
		if _rig.has_method("set_deploy"):
			_rig.call("set_deploy", deploy)
		for side in recoil:
			var gun: Node3D=muzzle_node(side).get_parent_node_3d()
			gun.position=gun_rest[side]+Vector3(0,0,-float(recoil[side]))
		_model.position.z=-maxf(float(recoil[-1.0]),float(recoil[1.0]))*.3


func _sync_expression() -> void:
	if is_instance_valid(hit_flash) and hit_flash.left>0: return
	var wanted := "calm"
	if bool(unit.get("alert")):
		var alerted_at := int(unit.get("alerted_at_ms"))
		var since := (Time.get_ticks_msec() - alerted_at) / 1000.0
		if since >= 0.0 and since < 0.7:
			wanted = "surprised"
		else:
			wanted = "angry"
	if wanted == _expression:
		return
	_expression = wanted
	if _model != null:
		ROBOT_BUILDER.apply_expression(_model, wanted)


func _begin_death() -> void:
	if _dying:
		return
	_dying = true
	if is_instance_valid(hit_flash): hit_flash.apply(false)
	if is_instance_valid(outline): outline.set_enabled(false)
	var effect:=preload("res://scripts/dream/units/unit_death_effect.gd").new()
	get_parent().add_child(effect)
	effect.begin(_model,false,world)
	set_process(false)
	queue_free()
