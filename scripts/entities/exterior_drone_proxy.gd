extends StaticBody2D
## 楼层外无人机的 2D 受击代理。
##
## 无人机本体是 3D 节点，玩家的 2D 子弹打不到它；这里在 2D 玩法世界放一个
## **独立 Hurtbox（layer 16）**，因为 basic_projectile 的射线掩码是 1|4|8|16，
## 不含 body 所在的 layer 2。命中后把伤害转回无人机本体。

const HURTBOX_SCRIPT := preload("res://scenes/dream/rooms/hurtbox.gd")

var drone: Node
var dead:=false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group(&"dream_enemies")
	set_meta(&"exterior_flying",true)

	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.set_script(HURTBOX_SCRIPT)
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.add_to_group(&"damage_hurtboxes")
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	# Gameplay hit tests use the horizontal floor plane, not screen projection.
	var capsule := CapsuleShape2D.new()
	capsule.radius = 18.0*(2.0/3.0)
	capsule.height = 36.0*(2.0/3.0)
	shape.shape = capsule
	shape.position = Vector2.ZERO
	hurtbox.add_child(shape)
	add_child(hurtbox)

func bind(p_drone: Node, _max_hp: float) -> void:
	drone = p_drone

func is_damage_runtime_active() -> bool:
	return is_instance_valid(drone) and not drone._dead

func get_hurt_radius() -> float: return 18.0*(2.0/3.0)
func distance_to_hurtbox(point: Vector2) -> float: return maxf(0.0,point.distance_to(global_position)-get_hurt_radius())
func get_weapon_visual_snapshot(point: Vector2) -> Dictionary:
	return drone.get_weapon_visual_snapshot(point) if is_instance_valid(drone) else {}
func get_ranged_telegraph_state() -> Dictionary:
	return drone.get_ranged_telegraph_state() if is_instance_valid(drone) else {}
func defeat_by_parry(origin: Vector2) -> void:
	if is_instance_valid(drone): drone.defeat_by_parry(origin)


## resolve_player_hit 固定按四个参数调用，签名必须对齐。
func take_damage(amount: float, hit_origin: Vector2 = Vector2.ZERO, force: float = 1.0,
		source: StringName = &"") -> void:
	if drone != null and is_instance_valid(drone):
		drone.call("take_damage", amount, hit_origin, force, source)
