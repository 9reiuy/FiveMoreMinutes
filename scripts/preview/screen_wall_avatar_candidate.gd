extends "res://scripts/ui/screen_wall_main_menu.gd"
## Lab wrapper for the avatar presentation, also usable before scene promotion.
func _ready() -> void:
	super._ready()
	wall_view.avatar_scene = preload("res://art/preview/screen_wall/avatar/screen_wall_avatar.tscn")
	wall_view._setup_avatar()
	wall_view._align_image_to_eye_monitor()
