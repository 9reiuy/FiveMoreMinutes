extends "res://scripts/dream/preview/selective_pixel_preview.gd"
func _ready() -> void:
	preview_mode=false
	muted=false
	world=preload("res://scenes/testing/ResearchAtrium.tscn").instantiate()
	for flag: StringName in [&"test_level11_whitebox",&"test_level11_without_mech"]:
		if get_meta(flag,false) or get_parent().get_meta(flag,false):world.set_meta(flag,true)
	super._ready()
	world.run_interface.hud.hide()
	get_window().title="1-1 · 研究中庭（F5 重来）"
	world.level11_completed.connect(func():get_window().title="1-1 · 已到达走道末端（F5 重来）")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F5 or event.keycode==KEY_F5):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
