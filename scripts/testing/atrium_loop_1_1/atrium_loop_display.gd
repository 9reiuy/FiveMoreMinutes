extends "res://scripts/dream/preview/selective_pixel_preview.gd"
## Parallel Level 1-1 Chronon Research Unit display host matching levels 0-1..0-6 (640x360 pixel pipeline).


func _ready() -> void:
	preview_mode = false
	muted = false
	pixel_size = DEFAULT_PIXEL_SIZE
	world = preload("res://scenes/testing/AtriumLoop11.tscn").instantiate()
	super._ready()
	if world.run_interface != null and is_instance_valid(world.run_interface.hud):
		world.run_interface.hud.hide()
	if is_instance_valid(camera_finish) and camera_finish.get("material") is ShaderMaterial:
		# Keep architectural concrete, amber stripes, and crisp signage free of baseline RGB fringe.
		camera_finish.material.set_shader_parameter("base_strength", 0.0)
	var win := get_window()
	if win != null:
		win.title = "1-1 · Chronon Research Unit（回字形大厅 · F5 重来）"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F5 or event.keycode == KEY_F5):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		get_tree().reload_current_scene()
