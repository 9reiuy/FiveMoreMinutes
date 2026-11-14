extends "res://scripts/preview/screen_wall_display.gd"
## Pause choices stay legible without waiting for the hover reveal.
var full_content := false
func _init() -> void:
	# Random signal failures and the shared blue tint belong to the wall.
	ambient_signals_enabled = false
func _process(delta: float) -> void:
	super._process(delta)
	if not powering_off and not powered_off:
		effect.set_shader_parameter("option_mix",1.0 if full_content else maxf(option_mix,0.82))
