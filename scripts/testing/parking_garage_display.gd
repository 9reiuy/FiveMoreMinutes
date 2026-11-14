extends "res://scripts/dream/preview/selective_pixel_preview.gd"
## Keep the shared game Camera, input mapping and pixel display.

func _ready() -> void:
	preview_mode = false
	muted = false
	world = preload("res://scenes/testing/ParkingGarage.tscn").instantiate()
	super._ready()
	world.run_interface.hud.hide()
	# Keep the parking paint and fluorescent strips at their authored colours.
	if is_instance_valid(camera_finish):
		camera_finish.material.set_shader_parameter("base_strength", 0.0)
	get_window().title = "0-2 · 停车场"
	world.level_finished.connect(func(): get_window().title = "0-2 · 已到达出口（F5 重来）")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		get_tree().reload_current_scene()
