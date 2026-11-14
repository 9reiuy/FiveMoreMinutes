extends "res://scripts/dream/preview/selective_pixel_preview.gd"
## Use the exact production pixel display and pointer/HUD coordinate mapping.
func _ready() -> void:
	preview_mode = false
	muted = false
	world = preload("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	super._ready()
	get_window().title=String(world.get_meta(&"level_id"))
