extends "res://scripts/testing/game_test_lab.gd"
const GAS_WORLD := preload("res://scripts/testing/interactive_gas_world.gd")
const GAS := preload("res://scripts/testing/interactive_gas_volume.gd")
var gas: Node3D
var hint: Label
var _gas_rebuilding := false
var reference_preview: Control
var _saved_reference_process_mode:=Node.PROCESS_MODE_INHERIT
var _saved_reference_update_mode:=SubViewport.UPDATE_ALWAYS
var _saved_reference_hud_visible:=true

func _ready() -> void:
	super._ready()
	enemies.value=0
	checks.furniture.button_pressed=false
	checks.ai.button_pressed=false
	mode.select(0)
	hint=Label.new()
	hint.text="WASD 移动 · 空格翻滚 · 鼠标射击 · G 补烟 · P 暂停 · F2 参考烟柱 · F1 面板"
	hint.add_theme_font_override("font",preload("res://scripts/ui/crisp_interaction_font.gd").get_font())
	hint.add_theme_font_size_override("font_size",10)
	hint.position=Vector2(12,314)
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)
	if "--smoke-reference" in OS.get_cmdline_user_args():
		call_deferred("_open_initial_reference")

func _open_initial_reference()->void:
	while not ready_world or _gas_rebuilding: await get_tree().process_frame
	if not is_instance_valid(reference_preview): toggle_reference()

func _instantiate_world() -> Node3D:
	var instance: Node3D=WORLD.instantiate()
	instance.set_script(GAS_WORLD)
	instance.generate_on_ready=false
	instance.persist_profile=false
	instance.enable_game_start_cab_exit=false
	instance.disable_player_combat=false
	instance.sparse_lighting_enabled=false
	# The fluid lab owns its Camera environment and volume lights.
	instance.set_meta(&"test_office_light_optics_disabled",true)
	return instance

func rebuild() -> void:
	if _gas_rebuilding or busy: return
	_gas_rebuilding=true
	gas=null
	await super.rebuild()
	if not ready_world:
		_gas_rebuilding=false
		return
	station.select(1)
	world._exit_dream_time_mode()
	var preferred:=Vector2(6.5,10.0)*32.0
	var spawn:=preferred
	var nearest:=INF
	for cell: Vector2i in world.rooms[1].get("usable_cells",[]):
		var point:=Vector2(cell)*32.0
		if not world._content_position_is_clear(point,18.0,false): continue
		var distance:=point.distance_squared_to(preferred)
		if distance<nearest:
			spawn=point
			nearest=distance
	world.player.global_position=spawn
	world.player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(10.0)
	gas=GAS.new()
	gas.name="InteractiveGas"
	world.floor_root.add_child(gas)
	world.interactive_gas=gas
	await gas.configure(world)
	panel.hide()
	_gas_rebuilding=false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F2 or (is_instance_valid(reference_preview) and event.physical_keycode==KEY_ESCAPE):
			toggle_reference()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(reference_preview): return
	if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(gas) and gas.solver!=null and gas.solver.ready:
		if event.physical_keycode==KEY_G:
			gas.reset()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_P:
			gas.paused=not gas.paused
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func toggle_reference() -> void:
	if not ready_world or _gas_rebuilding: return
	if is_instance_valid(reference_preview):
		reference_preview.free()
		reference_preview=null
		world.process_mode=_saved_reference_process_mode
		if is_instance_valid(gas) and is_instance_valid(gas.extinguisher):gas.extinguisher.set_paused(gas.paused)
		display.world_viewport.render_target_update_mode=_saved_reference_update_mode
		display.show()
		hud.visible=_saved_reference_hud_visible
	else:
		_saved_reference_process_mode=world.process_mode
		_saved_reference_update_mode=display.world_viewport.render_target_update_mode
		_saved_reference_hud_visible=hud.visible
		if is_instance_valid(gas) and is_instance_valid(gas.extinguisher):gas.extinguisher.set_paused(true)
		world.process_mode=Node.PROCESS_MODE_DISABLED
		display.world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		display.hide()
		hud.hide()
		reference_preview=preload("res://scripts/testing/stylized_smoke_reference.gd").new()
		add_child(reference_preview)
