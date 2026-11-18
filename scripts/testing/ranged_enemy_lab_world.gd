extends "res://scripts/testing/lab_world.gd"

var use_new_aim := true
var range_gunner: EmployeeEnemy

func _regular_employee_scene(enemy_type: StringName) -> PackedScene:
	if not use_new_aim and enemy_type == &"employee":
		return EMPLOYEE_SCENE
	return super._regular_employee_scene(enemy_type)

func populate_lab() -> void:
	# Put the single opponent next to the player's starting lane on every reset.
	if lab_enemy_count != 1 or lab_native_layout or lab_enemy_archetypes != [&"employee"]:
		super.populate_lab()
		return
	var start := station_position(1)
	var at := start + Vector2(96, 0)
	range_gunner = _spawn_regular_employee(1, at, &"employee", false, "assault_rifle")
	range_gunner.last_facing_direction = at.direction_to(start)
	range_gunner.weapon_root.rotation = range_gunner.last_facing_direction.angle()
	lab_enemy_count = 0
	super.populate_lab()
	lab_enemy_count = 1
