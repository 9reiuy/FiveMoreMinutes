extends "res://scripts/testing/game_test_lab.gd"

const AIM_WORLD := preload("res://scenes/testing/RangedEnemyLabWorld.tscn")
var use_new_aim := true

func _ready() -> void:
	super._ready()
	enemies.value = 1
	checks.ai.button_pressed = true
	checks.uncapped.button_pressed = false
	mode.select(1)

func _instantiate_world() -> Node3D:
	var instance := AIM_WORLD.instantiate()
	instance.use_new_aim = use_new_aim
	return instance

func rebuild() -> void:
	if busy:
		return
	await super.rebuild()
	if ready_world:
		world._exit_dream_time_mode()
		world._update_camera_and_actor_projection(10.0)
		panel.hide()
		_panel_changed()
