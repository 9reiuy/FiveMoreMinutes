extends "res://scenes/dream/rooms/hurtbox.gd"
## A projected upper-body capsule plus a torso/leg volume at the foot plane.
## The latter follows the camera depth so diagonal train views stay hittable.
@onready var body_volume: CollisionShape2D = $BodyCollision
var _world: Node3D


func _physics_process(_delta: float) -> void:
	var primary: CollisionShape2D = damage_owner.get_node("Hurtbox/CollisionShape2D")
	var inactive: bool = damage_owner.dead or primary.disabled
	if body_volume.disabled != inactive: body_volume.set_deferred("disabled",inactive)
	if inactive: return
	if not is_instance_valid(_world): _world = get_tree().get_first_node_in_group(&"dream_world") as Node3D
	if not is_instance_valid(_world) or not is_instance_valid(_world.camera_3d): return
	var depth: Vector3 = _world.global_basis.inverse()*_world.camera_3d.global_basis.z
	var offset := Vector2(depth.x,depth.z).normalized()*8.0
	var foot: CollisionShape2D = damage_owner.body_collision
	body_volume.position = foot.position+offset
