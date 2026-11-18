extends EmployeeEnemy
## Original Employee combat/physics, authored Engineer appearance and independent helmet loot.
const ART := preload("res://art/Dream/enemy/Engineer.png")
var loot_random := RandomNumberGenerator.new()
var helmet_drop_checked := false


func _ready() -> void:
	enemy_archetype = &"engineer"
	super._ready()
	safety_helmet = SAFETY_HELMET.new()
	safety_helmet.attach(self, head)
	helmet_equipped = true
	var world := _get_world()
	var seed_value: int = world.active_seed if is_instance_valid(world) else 0
	loot_random.seed = hash(["engineer_helmet", seed_value, Vector2i(position.round())])


func configure_archetype(_archetype: StringName) -> void:
	enemy_archetype = &"engineer"


func _character_atlas() -> Texture2D:
	return ART


func _back_atlas_region() -> Rect2:
	return Rect2(64, 0, 32, 32)


func _setup_character_parts() -> void:
	super._setup_character_parts()
	left_leg.texture = _make_employee_atlas_texture(Rect2(108, 44, 4, 9))
	right_leg.texture = _make_employee_atlas_texture(Rect2(113, 44, 4, 9))
	left_hand.texture = _make_employee_atlas_texture(Rect2(102, 79, 5, 4))
	right_hand.texture = _make_employee_atlas_texture(Rect2(117, 79, 5, 4))
	left_leg.position = body_pivot.position + head.position + Vector2(10, 26)
	right_leg.position = body_pivot.position + head.position + Vector2(15, 26)
	left_hand.position = Vector2(-12, 6)
	right_hand.position = Vector2(5, 6)
	left_leg_base_position = left_leg.position
	right_leg_base_position = right_leg.position
	left_hand_base_position = left_hand.position
	right_hand_base_position = right_hand.position


func _die() -> void:
	if dead:
		return
	super._die()
	if not dead or helmet_drop_checked:
		return
	helmet_drop_checked = true
	# Loot is rolled once on the actual defeat, separately from consuming the worn helmet.
	var roll := loot_random.randf()
	if roll >= SAFETY_HELMET.DROP_CHANCE or bool(get_meta(&"pit_death", false)):
		return
	var world := _get_world()
	if is_instance_valid(world) and world.has_method("spawn_safety_helmet_pickup"):
		world.call_deferred("spawn_safety_helmet_pickup", death_origin_gameplay_position,
			death_origin_room_id, int(world.get("_layout_generation")))
