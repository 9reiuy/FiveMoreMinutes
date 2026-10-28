extends "res://scripts/dream/preview/selective_pixel_preview.gd"
var tonal_enabled:=true
var stability_enabled:=true
func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	world.set_meta(&"pixel_stability_anchor",world.to_global(Vector3(world.player.global_position.x/32.,0.,world.player.global_position.y/32.)))
	apply_sample()
func apply_sample() -> void:
	palette_material.set_shader_parameter("tonal_sample",tonal_enabled)
	for component in get_tree().get_nodes_in_group("office_dither_lighting"):
		if component.get_parent()!=world: continue
		for material in component.materials.values():
			if material is ShaderMaterial: material.set_shader_parameter("office_tonal_sample",tonal_enabled)
	world.set_meta(&"pixel_stability_sample",stability_enabled)
	if not stability_enabled:
		world.camera_3d.h_offset=0.; world.camera_3d.v_offset=0.
	if status_label:
		status_label.text="F9 层次增强 %s | F10 像素稳定 %s | F11 配色 %d"%["开" if tonal_enabled else "关","开" if stability_enabled else "关",SettingsManager.get_palette_scheme()]
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F9: tonal_enabled=not tonal_enabled; apply_sample(); return
		if event.keycode==KEY_F10: stability_enabled=not stability_enabled; apply_sample(); return
		if event.keycode==KEY_F11:
			SettingsManager.set_palette_scheme(1 if SettingsManager.get_palette_scheme()==2 else 2)
			apply_sample(); return
	super._input(event)
