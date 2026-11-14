extends "res://scripts/dream/preview/selective_pixel_preview.gd"
## Standalone tutorial review; does not enable it in the campaign.
func _ready() -> void:
	preview_mode=false
	muted=false
	world=preload("res://scenes/dream/Dream3D_TutorialRoom.tscn").instantiate()
	super._ready()
	get_window().title="教程"
	world.tutorial_finished.connect(func():get_window().title="教程 · 已完成（F5 重试）")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F5:
		get_viewport().set_input_as_handled()
		get_tree().paused=false
		get_tree().reload_current_scene()
