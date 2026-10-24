class_name GamePhone
extends CanvasLayer
## One in-game device. Main owns routing; pages and shell retain their own roles.
const SHELL=preload("res://scripts/ui/flip_phone_shell.gd")
const SCREEN=preload("res://scripts/ui/phone_settings_screen.gd")
const ENVIRONMENT=preload("res://scripts/ui/phone_environment_bridge.gd")
const CONFIG=preload("res://resources/demo_config.tres")
const SFX=preload("res://scripts/audio/sfx_manager.gd")
const GLITCH=preload("res://shaders/glitch_overlay.gdshader")
const PAUSE_REASON:StringName=&"GAME_PHONE"
signal closed
var shell:Control
var screen:Control
var canvas:Control
var backdrop:ColorRect
var environment_bridge:Node
var active:=false
var _closing:=false
var _session_live:=false
var _main:Node
var _world:Node3D
var _bedroom:Node
var _backend:Control
var _pauses:Node
var _owns_pause:=false
var _previous_mouse_mode:=Input.MOUSE_MODE_VISIBLE
var _environment_materials:Array[Dictionary]=[]
var _fallback:Texture2D
var _held_keys:Dictionary={}
var _quarantined_keys:Dictionary={}
var _quarantined_buttons:Dictionary={}
var _input_player:WeakRef
var _previous_pointer_gate:Variant
var _had_pointer_gate:=false
var _right_held:=false
var _screen_mouse_active:=false
var _camera_weight:=0.0
var _camera_from:=0.0
var _camera_target:=0.0
var _camera_elapsed:=0.0
var _camera_started_usec:=0
var _last_usec:=0

func _ready()->void:
	layer=1100;process_mode=Node.PROCESS_MODE_ALWAYS
	_pauses=get_tree().root.get_node("PauseManager")
	canvas=Control.new();canvas.name="GamePhoneRoot";add_child(canvas)
	# Retain the input shield, without tinting the bedroom or 3D world.
	backdrop=ColorRect.new();backdrop.color=Color(0,0,0,0)
	canvas.add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=SHELL.new();canvas.add_child(shell)
	screen=SCREEN.new();shell.set_screen_content(screen)
	shell.action_pressed.connect(_physical_action)
	shell.action_released.connect(_physical_release)
	shell.screen_activity.connect(_screen_activity)
	shell.animation_finished.connect(_animation_finished)
	screen.close_requested.connect(close_phone)
	screen.feedback_requested.connect(_screen_feedback)
	screen.interaction_lock_changed.connect(func(_locked:bool)->void:_sync_freeze())
	screen.profile_changed.connect(_save_profile)
	screen.story_effect_requested.connect(play_story_effect)
	canvas.hide();get_viewport().size_changed.connect(_fit)
	_fit();_last_usec=Time.get_ticks_usec()

func configure(main:Node)->void:_main=main

func _value(node:Object,key:StringName,otherwise:Variant=null)->Variant:
	if not is_instance_valid(node):return otherwise
	for item in node.get_property_list():
		if item.name==key:return node.get(key)
	return otherwise

func _visible(node:Variant)->bool:
	return is_instance_valid(node) and node is CanvasItem and node.is_visible_in_tree()

func can_open()->bool:
	if not is_instance_valid(_main) or is_open():return false
	if bool(_value(_main,&"transition_running",false)):return false
	var pause_menu:Node=_value(_main,&"pause_menu")
	if is_instance_valid(pause_menu) and pause_menu.is_open():return false
	var world:Node3D=_value(_main,&"_supported_dream_world")
	if is_instance_valid(world):
		if String(world.scene_file_path).contains("tutorial"):return false
		for reason in [&"UPGRADE",&"DIALOGUE",&"MODAL_ANIMATION",&"SKILLS_MENU"]:
			if _pauses.has_pause_reason(reason):return false
		var run:Node=_value(world,&"run_interface")
		if _visible(_value(run,&"card")):return false
		var dialogue:Node=_value(world,&"dialogue_controller")
		if is_instance_valid(dialogue) and dialogue.has_method("is_active") and dialogue.is_active():return false
		if bool(_value(_value(world,&"player"),&"dead",false)):return false
		for key in [&"floor_transition_in_progress",&"elevator_transition_in_progress"]:
			if bool(_value(world,key,false)):return false
		for key in [&"dialogue_bubble",&"dialogue_dialog",&"tarot_overlay"]:
			if _visible(_value(world,key)):return false
		return true
	var scene:Node=_value(_main,&"current_screen")
	if not is_instance_valid(scene) or scene.get_node_or_null("PhoneLayer/BedroomPhone")==null:return false
	if bool(_value(scene,&"input_locked",false)):return false
	for key in [&"hallway",&"computer_overlay",&"confirmation_dialog",&"melatonin_ui"]:
		if _visible(_value(scene,key)):return false
	return true

func is_open()->bool:return active or _closing

func _fit()->void:
	canvas.size=get_viewport().get_visible_rect().size
	shell.position=Vector2(12,-20)

func open_phone()->void:
	if not can_open():return
	_world=_value(_main,&"_supported_dream_world") as Node3D
	_bedroom=null;_backend=null
	if not is_instance_valid(_world):
		_bedroom=_main.current_screen
		_backend=_bedroom.get_node_or_null("PhoneLayer/BedroomPhone") as Control
	_capture_background()
	_previous_mouse_mode=Input.mouse_mode;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	active=true;_closing=false;_session_live=true
	_clear_game_actions()
	_held_keys.clear();_right_held=false;_screen_mouse_active=false
	if is_instance_valid(_bedroom):_bedroom.set_game_phone_active(true)
	if is_instance_valid(_world):
		_install_pointer_gate()
		_pauses.request_pause(PAUSE_REASON);_owns_pause=true
		_begin_camera(1.0)
	screen.configure_apps(_main.persistent_day_state,_backend,_clock_data)
	screen.set_context(&"game" if is_instance_valid(_world) else &"bedroom")
	_fit();canvas.show();_configure_environment();shell.open_phone(true)
	_last_usec=Time.get_ticks_usec()

func close_phone(animated:bool=true)->void:
	if not _session_live or _closing:return
	active=false;_closing=true
	_quarantine_held_input()
	_clear_game_actions();_release_feedback();_begin_camera(0.0)
	shell.close_phone(animated)

func _quarantine_held_input()->void:
	for code in _held_keys:_quarantined_keys[code]=_held_keys[code]
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_E,KEY_Q,KEY_R,KEY_F,KEY_T,KEY_L,KEY_SPACE]:
		if Input.is_physical_key_pressed(code):_quarantined_keys[code]=true
	if _right_held:_quarantined_buttons[MOUSE_BUTTON_RIGHT]=true
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if Input.is_mouse_button_pressed(button):_quarantined_buttons[button]=true

func abort()->void:
	if not _session_live:return
	active=false;_closing=true
	_quarantine_held_input()
	_camera_weight=0.0;_camera_target=0.0;_refresh_camera()
	_release_feedback();shell.close_phone(false);_complete_close()

func _animation_finished(opened:bool)->void:
	if not opened:_complete_close()

func _complete_close()->void:
	if not _session_live:return
	_session_live=false;active=false;_closing=false
	_camera_weight=0.0;_camera_target=0.0;_refresh_camera()
	canvas.hide();_stop_environment()
	if is_instance_valid(_bedroom):_bedroom.set_game_phone_active(false)
	if _owns_pause:_pauses.release_pause(PAUSE_REASON);_owns_pause=false
	Input.mouse_mode=_previous_mouse_mode
	_clear_game_actions();_world=null;_backend=null;_bedroom=null
	for button in _quarantined_buttons.keys():
		if not Input.is_mouse_button_pressed(button):_quarantined_buttons.erase(button)
	_restore_pointer_gate_if_ready()
	closed.emit()

func _install_pointer_gate()->void:
	_restore_pointer_gate()
	var player:Node=_value(_world,&"player")
	if not is_instance_valid(player):return
	_input_player=weakref(player)
	_had_pointer_gate=player.has_meta(&"presentation_pointer_gate")
	_previous_pointer_gate=player.get_meta(&"presentation_pointer_gate",Callable())
	player.set_meta(&"presentation_pointer_gate",Callable(self,"_phone_pointer_allowed"))

func _phone_pointer_allowed()->bool:
	if is_open() or not _quarantined_buttons.is_empty():return false
	return not (_previous_pointer_gate is Callable and _previous_pointer_gate.is_valid()) or bool(_previous_pointer_gate.call())

func _restore_pointer_gate_if_ready()->void:
	if not is_open() and _quarantined_buttons.is_empty():_restore_pointer_gate()

func _restore_pointer_gate()->void:
	var player:Object=_input_player.get_ref() if _input_player!=null else null
	if is_instance_valid(player):
		if player.get_meta(&"presentation_pointer_gate",Callable())==Callable(self,"_phone_pointer_allowed"):
			if _had_pointer_gate:player.set_meta(&"presentation_pointer_gate",_previous_pointer_gate)
			else:player.remove_meta(&"presentation_pointer_gate")
	_input_player=null;_previous_pointer_gate=null;_had_pointer_gate=false

func _begin_camera(target:float)->void:
	_camera_from=_camera_weight;_camera_target=target;_camera_elapsed=0.0
	_camera_started_usec=Time.get_ticks_usec()

func _refresh_camera()->void:
	if is_instance_valid(_world) and _world.is_inside_tree() and _world.has_method("set_phone_camera_weight"):
		_world.set_phone_camera_weight(_camera_weight)
		_world.refresh_phone_camera_presentation(0.0)

func _process(_delta:float)->void:
	var now:=Time.get_ticks_usec()
	_last_usec=now
	if not _session_live:return
	if not is_instance_valid(_main) or bool(_value(_main,&"transition_running",false)):
		abort();return
	if is_instance_valid(_world) and not _world.is_inside_tree():abort();return
	_camera_elapsed=float(now-_camera_started_usec)/1000000.0
	_camera_weight=lerpf(_camera_from,_camera_target,smoothstep(0.0,1.0,minf(_camera_elapsed/.4,1.0)))
	_refresh_camera()

func _key_action(event:InputEventKey)->StringName:
	var code:=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	match code:
		KEY_UP,KEY_W:return &"up"
		KEY_DOWN,KEY_S:return &"down"
		KEY_LEFT,KEY_A:return &"left"
		KEY_RIGHT,KEY_D:return &"right"
		KEY_ENTER,KEY_KP_ENTER,KEY_E:return &"confirm"
		KEY_Q,KEY_HOME:return &"home"
		KEY_ESCAPE,KEY_BACKSPACE:return &"back"
	return &""

func handle_event(event:InputEvent)->bool:
	if not is_open():return _drain_input(event)
	_clear_game_actions()
	if event is InputEventKey:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_TAB:
			if event.pressed and not event.echo and active:close_phone()
			return true
		var action:=_key_action(event)
		if not event.pressed:
			_held_keys.erase(code);_quarantined_keys.erase(code)
			if not action in _held_keys.values():shell.release_action(action)
			_sync_freeze();return true
		if not active or shell.is_animating or action.is_empty():return true
		if event.echo:
			if action in [&"up",&"down",&"left",&"right"]:_navigate(action)
			return true
		_held_keys[code]=action;shell.press_action(action);_sync_freeze();_navigate(action)
		return true
	if event is InputEventMouseButton and not event.pressed:_quarantined_buttons.erase(event.button_index)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		_right_held=event.pressed
		if event.pressed and active and not shell.is_animating:
			shell.press_action(&"back");_navigate(&"back")
		elif not event.pressed:
			shell.release_action(&"back");_quarantined_buttons.erase(MOUSE_BUTTON_RIGHT)
		_sync_freeze();return true
	if event is InputEventMouseMotion:shell.set_pointer_position(event.position)
	# The shell forwards screen/physical-left clicks before Main, or afterward.
	# Consume gameplay keys above; do not mark left/motion handled before shell.
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _navigate(action:StringName)->void:
	if not active or shell.is_animating:return
	SFX.play_event(&"phone_operation");screen.navigate(action)

func _physical_action(action:StringName)->void:_navigate(action)
func _physical_release(_action:StringName)->void:_sync_freeze()
func _screen_activity(value:bool)->void:_screen_mouse_active=value;_sync_freeze()

func _screen_feedback(action:StringName,pressed:bool)->void:
	if pressed:shell.press_action(action);SFX.play_event(&"phone_operation")
	else:shell.release_action(action)
	_sync_freeze()

func _sync_freeze()->void:
	shell.set_interaction_frozen(not _held_keys.is_empty() or _right_held or _screen_mouse_active or screen.get_interaction_locked())

func _release_feedback()->void:
	screen.cancel_interaction()
	for action in [&"up",&"down",&"left",&"right",&"confirm",&"home",&"back"]:shell.release_action(action)
	_held_keys.clear();_right_held=false;_screen_mouse_active=false;shell.set_interaction_frozen(false)

func _clear_game_actions()->void:
	for action in [&"move_left",&"move_right",&"move_up",&"move_down",&"throw_weapon",&"attack",&"shoot",&"skill_menu",&"reload_weapon",&"pickup_weapon",&"kick",&"dash",&"block",&"weapon_next",&"weapon_previous",&"toggle_flashlight",&"toggle_slow_time",&"bullet_time"]:
		if InputMap.has_action(action):Input.action_release(action)

func _drain_input(event:InputEvent)->bool:
	if event is InputEventKey:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if _quarantined_keys.has(code):
			if not event.pressed:_quarantined_keys.erase(code)
			_clear_game_actions();return true
	if event is InputEventMouseButton and _quarantined_buttons.has(event.button_index):
		if not event.pressed:_quarantined_buttons.erase(event.button_index)
		_clear_game_actions();_restore_pointer_gate_if_ready();return true
	return false

func _clock_data()->Dictionary:
	var minutes:float=_value(_bedroom,&"current_minutes",CONFIG.dream_start_minutes)
	if is_instance_valid(_backend):return {"time":"%02d:%02d"%[int(minutes)/60%24,int(minutes)%60],"battery":_backend._get_battery_ratio()}
	if is_instance_valid(_main):
		minutes=_main._dream_start_minutes_for_melatonin_count(int(_main.night_state.get("melatonin_count",0)))
	if is_instance_valid(_world):
		var run:Node=_value(_world,&"run_interface")
		var config:Resource=_value(_world,&"config",CONFIG)
		if is_instance_valid(run):minutes=float(config.dream_start_minutes)+float(run.seconds)/maxf(config.real_seconds_per_game_minute,.001)
	var stress:=float(_main.persistent_day_state.get("stress_value",CONFIG.stress_default)) if is_instance_valid(_main) else 0.0
	return {"time":"%02d:%02d"%[int(minutes)/60%24,int(minutes)%60],"battery":1.0-clampf(stress/maxf(CONFIG.stress_max,1),0,1)}

func _save_profile()->void:
	if is_instance_valid(_main):_main._save_progress()

func play_story_effect(effect:StringName)->void:
	if effect!=&"phone_message_glitch" or not active:return
	var overlay:=ColorRect.new();overlay.name="PhoneMessageGlitch"
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=GLITCH;overlay.material=material
	canvas.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a=0.0
	var tween:=overlay.create_tween().set_ignore_time_scale(true)
	tween.tween_property(overlay,"modulate:a",1.0,.08)
	tween.tween_interval(.24)
	tween.tween_property(overlay,"modulate:a",0.0,.08)
	tween.tween_callback(overlay.queue_free)

func _capture_background()->void:
	_fallback=null
	if DisplayServer.get_name()=="headless":return
	var image:=get_viewport().get_texture().get_image()
	if image==null or image.is_empty():return
	image.resize(256,144,Image.INTERPOLATE_BILINEAR);_fallback=ImageTexture.create_from_image(image)

func _configure_environment()->void:
	environment_bridge=ENVIRONMENT.new();add_child(environment_bridge)
	var camera:Camera3D=_world.get("camera_3d") if is_instance_valid(_world) else null
	environment_bridge.configure(_world,camera,shell._camera,shell._stage.get_parent(),shell._ui.get_texture(),_fallback)
	for mesh in shell._stage.find_children("*","MeshInstance3D",true,false):
		var previous:Material=mesh.material_override
		if mesh==shell._screen_plane:
			_environment_materials.append({"mesh":mesh,"material":previous});mesh.material_override=environment_bridge.get_lcd_material()
		elif previous is StandardMaterial3D:
			_environment_materials.append({"mesh":mesh,"material":previous});mesh.material_override=environment_bridge.get_body_material(previous)
	environment_bridge.start()

func _stop_environment()->void:
	for record in _environment_materials:
		if is_instance_valid(record.mesh):record.mesh.material_override=record.material
	_environment_materials.clear()
	if is_instance_valid(environment_bridge):environment_bridge.stop();environment_bridge.free()
	environment_bridge=null;_fallback=null

func _exit_tree()->void:
	if _session_live:abort()
	_restore_pointer_gate()
	_stop_environment()
