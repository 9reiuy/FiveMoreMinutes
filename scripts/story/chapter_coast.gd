extends "res://scripts/preview/night_coast_display.gd"
signal fragment_observed
signal completed
var already_observed:=false
var readable_seconds:=0.
var panel: CanvasLayer
var leaving:=false
var return_hint: Control
var authored_cutout := preload("res://scripts/dream/authored_occlusion_cutout.gd").new()
func _ready() -> void:
	super._ready()
	coast.story_mode=true; coast.get_node("CoastHUD").hide()
	process_priority = 20
	for piece in coast.get_node(^"DuneDressing").get_children():
		if piece.has_meta(&"walk_obstacle_radius"):
			authored_cutout.register_tree(piece)
	authored_cutout.include_variants_in(coast.slope_dressing.outlines)
	authored_cutout.include_variants_in(coast.pixel_materials)
	panel=preload("res://scripts/story/chapter_panel.gd").new(); add_child(panel)
	return_hint=preload("res://scripts/story/context_hint.gd").new(); panel.add_child(return_hint)
	# Timed roof lights and fixed coastal codes retain their scene-authored message.
	if coast.atmosphere.city_signal: coast.atmosphere.configure_city_signal(String(coast.get_meta(&"coast_morse_message","S")))
	for i in coast.atmosphere.signal_nodes.size():
		var node: MeshInstance3D=coast.atmosphere.signal_nodes[i]
		node.visible=bool(node.get_meta("chapter_signal",false)) if coast.atmosphere.city_signal else i in [5,7,9]
		var mat: ShaderMaterial=node.material_override.duplicate(); node.material_override=mat
		if not coast.atmosphere.city_signal: mat.set_shader_parameter("long_signal",false)
		mat.set_shader_parameter("story_signal",true)
		coast.atmosphere.signals[i]=mat
func _process(delta: float) -> void:
	if not is_instance_valid(coast) or get_tree().paused: return
	authored_cutout.update_slots(coast.camera, [], .20, coast.character, true)
	if not already_observed:
		var readable: bool=coast.camera_reveal>.8 and coast.moon_visibility<.025
		readable_seconds=readable_seconds+delta if readable else 0.
		var full_message: bool=coast.atmosphere.signal_complete if coast.atmosphere.city_signal else true
		if readable_seconds>=1.5 and full_message:
			already_observed=true; fragment_observed.emit()
	return_hint.hide()
	if already_observed and not leaving:
		var hint: String="已记下楼顶短闪 · E 结束这一天" if coast.atmosphere.city_signal else "已记下远处光点 · E 结束这一天"
		if coast.atmosphere.horizon_signal: hint="已记下岸线短闪 · E 结束这一天"
		if coast.atmosphere.static_horizon: hint="已记下远岸光点 · E 结束这一天"
		return_hint.present(hint, Vector2(320, 296))
func _exit_tree() -> void:
	authored_cutout.clear_slots()
func _unhandled_input(event: InputEvent) -> void:
	if already_observed and not leaving and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		leaving=true; get_viewport().set_input_as_handled(); completed.emit(); return
	super._unhandled_input(event)
