extends CanvasLayer
## Opt-in review host. Production scenes keep their current entrypoints until approval.
const SHELL=preload("res://scripts/ui/flip_phone_shell.gd")
const SCREEN=preload("res://scripts/ui/phone_settings_screen.gd")
const PAUSE_REASON: StringName=&"PHONE_SETTINGS_SAMPLE"
const SFX=preload("res://scripts/audio/sfx_manager.gd")
signal closed
signal action_requested(action:StringName)
var shell:Control
var screen:Control
var backdrop:ColorRect
var canvas:Control
var active:=false
var _owns_pause:=false
var _pauses:Node
var _phone:Control
var _mounts:Array[Dictionary]=[]
var _phone_state:Dictionary={}
var _previous_mouse_mode:int
var environment_bridge:Node
var _environment_materials:Array[Dictionary]=[]
var _fallback_environment:Texture2D

class BedroomPage extends Control:
	var phone:Control
	var scroll:ScrollContainer
	var kind:StringName
	var selection:=0
	func navigate(action:StringName)->void:
		if kind==&"chat":
			if action in [&"up",&"down"]:scroll.scroll_vertical+=-28 if action==&"up" else 28
			return
		if action in [&"up",&"down"]:
			selection=posmod(selection+(-1 if action==&"up" else 1),3)
			scroll.scroll_vertical=int(phone.quicklink_content._card_rect(selection).position.y)-4
		elif action==&"confirm":
			# The original purchase authority checks price, capacity and daily limits.
			phone.call(["_purchase_melatonin","_purchase_cheap_meal","_purchase_sunshade"][selection])
			phone.quicklink_content.queue_redraw()

func _ready()->void:
	layer=1100;process_mode=Node.PROCESS_MODE_ALWAYS
	_pauses=get_tree().root.get_node("PauseManager")
	canvas=Control.new();canvas.name="PhoneSampleRoot";add_child(canvas)
	backdrop=ColorRect.new();backdrop.color=Color(0.015,0.02,0.045,0.58)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(backdrop)
	shell=SHELL.new();canvas.add_child(shell)
	screen=SCREEN.new();shell.set_screen_content(screen)
	shell.action_pressed.connect(_navigate)
	shell.animation_finished.connect(_animation_finished)
	screen.close_requested.connect(close_sample)
	screen.action_requested.connect(_request_action)
	screen.page_changed.connect(_page_changed)
	canvas.visible=false
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()

func _fit_to_viewport()->void:
	var logical_size:=get_viewport().get_visible_rect().size
	canvas.size=logical_size
	# Left-hand device: the long keypad may extend below the game frame.
	shell.position=Vector2(16,maxf(6,(logical_size.y-shell.size.y)*.5))

func show_sample(context:StringName,bedroom_phone:Control=null,animated:bool=true)->void:
	_stop_environment()
	if not active:_capture_background()
	_restore_bedroom()
	if _owns_pause:_pauses.release_pause(PAUSE_REASON);_owns_pause=false
	_previous_mouse_mode=Input.mouse_mode;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	canvas.visible=true;active=true
	_fit_to_viewport()
	if context==&"bedroom" and is_instance_valid(bedroom_phone):_mount_bedroom(bedroom_phone)
	if context!=&"bedroom":
		_pauses.request_pause(PAUSE_REASON);_owns_pause=true
	screen.set_context(context)
	_configure_environment()
	shell.open_phone(animated)

func _capture_background()->void:
	_fallback_environment=null
	if DisplayServer.get_name()=="headless":return
	# Freeze a clean frame before either the phone or its dimming layer appears.
	var texture:=get_viewport().get_texture()
	if texture==null:return
	var image:=texture.get_image()
	if image==null or image.is_empty():return
	image.resize(256,144,Image.INTERPOLATE_BILINEAR)
	_fallback_environment=ImageTexture.create_from_image(image)

func _configure_environment()->void:
	var source_world:Node3D
	var source_camera:Camera3D
	var main:=get_tree().root.find_child("Main",true,false)
	if main!=null:
		source_world=main.get("_supported_dream_world") as Node3D
		if is_instance_valid(source_world):source_camera=source_world.get("camera_3d") as Camera3D
	var bridge_script=load("res://scripts/ui/phone_environment_bridge.gd")
	if bridge_script==null:return
	environment_bridge=bridge_script.new()
	add_child(environment_bridge)
	environment_bridge.configure(source_world,source_camera,shell._camera,shell._stage.get_parent(),shell._ui.get_texture(),_fallback_environment)
	for mesh in shell._stage.find_children("*","MeshInstance3D",true,false):
		var previous:Material=mesh.material_override
		if mesh==shell._screen_plane:
			_environment_materials.append({"mesh":mesh,"material":previous})
			mesh.material_override=environment_bridge.get_lcd_material()
		elif previous is StandardMaterial3D:
			_environment_materials.append({"mesh":mesh,"material":previous})
			mesh.material_override=environment_bridge.get_body_material(previous)
	environment_bridge.start()

func _stop_environment()->void:
	for record in _environment_materials:
		if is_instance_valid(record.mesh):record.mesh.material_override=record.material
	_environment_materials.clear()
	if is_instance_valid(environment_bridge):
		environment_bridge.stop()
		environment_bridge.free()
	environment_bridge=null

func _mount_bedroom(phone:Control)->void:
	_phone=phone
	_phone_state={"visible":phone.visible,"state":phone.state,"screen_state":phone.screen_state,"position":phone.position}
	for pair in [[&"chat",phone.online_scroll],[&"shop",phone.quicklink_scroll]]:
		var scroll:ScrollContainer=pair[1]
		_mounts.append({"node":scroll,"parent":scroll.get_parent(),"position":scroll.position,"size":scroll.size,"visible":scroll.visible})
		var wrapper:=BedroomPage.new();wrapper.kind=pair[0];wrapper.phone=phone;wrapper.scroll=scroll
		wrapper.size=screen.get_page_content_rect().size;wrapper.clip_contents=true
		scroll.reparent(wrapper,false);scroll.position=Vector2.ZERO;scroll.size=wrapper.size
		if pair[0]==&"chat":screen.set_meta(&"sample_chat_page",wrapper)
		else:screen.set_meta(&"sample_shop_page",wrapper)
	phone.hide();phone.state=phone.PhoneState.EXPANDED;phone.screen_state=phone.ScreenState.HOME
	phone.interaction_locked=false
	screen.set_bedroom_pages(screen.get_meta(&"sample_chat_page"),screen.get_meta(&"sample_shop_page"))
	phone._build_online_messages()

func _page_changed(page:StringName)->void:
	if not is_instance_valid(_phone):return
	if page==&"chat":_phone._open_app("online")
	elif page==&"shop":_phone._open_app("quicklink")
	else:_phone.screen_state=_phone.ScreenState.HOME;_phone._sync_content_visibility()
	# The backend keeps its actual scrolling references; only the outer pages moved.
	if page==&"chat":_phone.online_scroll.show()
	if page==&"shop":_phone.quicklink_scroll.show()

func _restore_bedroom()->void:
	if not is_instance_valid(_phone):_mounts.clear();return
	for record in _mounts:
		var scroll:Control=record.node
		if is_instance_valid(scroll) and is_instance_valid(record.parent):
			scroll.reparent(record.parent,false);scroll.position=record.position;scroll.size=record.size;scroll.visible=record.visible
	_mounts.clear()
	if is_instance_valid(screen):
		var pages:Array=[]
		for key in [&"sample_chat_page",&"sample_shop_page"]:
			if screen.has_meta(key):pages.append(screen.get_meta(key));screen.remove_meta(key)
		screen.set_bedroom_pages(null,null)
		for page in pages:
			if is_instance_valid(page):page.queue_free()
	_phone.state=_phone_state.state;_phone.screen_state=_phone_state.screen_state
	_phone.position=_phone_state.position;_phone.visible=_phone_state.visible
	_phone._sync_content_visibility();_phone._build_online_messages()
	_phone=null;_phone_state.clear()

func _navigate(action:StringName)->void:
	if not active or not shell.is_open or shell.is_animating:return
	SFX.play_event(&"phone_operation")
	screen.navigate(action)

func _request_action(action:StringName)->void:
	action_requested.emit(action)
	if action in [&"resume",&"exit_to_menu"]:close_sample()

func close_sample()->void:
	if not active:return
	active=false;shell.close_phone(true)

func _animation_finished(opened:bool)->void:
	if opened:return
	canvas.hide();_stop_environment();_restore_bedroom()
	if _owns_pause:_pauses.release_pause(PAUSE_REASON);_owns_pause=false
	Input.mouse_mode=_previous_mouse_mode
	closed.emit()

func _input(event:InputEvent)->void:
	if not active and not shell.is_animating:return
	if not event is InputEventKey:return
	# Consume the whole key event, including key-up and unsupported gameplay keys.
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo or shell.is_animating:return
	var action:StringName=&""
	match event.keycode:
		KEY_UP,KEY_W:action=&"up"
		KEY_DOWN,KEY_S:action=&"down"
		KEY_LEFT,KEY_A:action=&"left"
		KEY_RIGHT,KEY_D:action=&"right"
		KEY_ENTER,KEY_KP_ENTER,KEY_E:action=&"confirm"
		KEY_ESCAPE,KEY_BACKSPACE:action=&"back"
		KEY_HOME:action=&"home"
	if not action.is_empty():_navigate(action)

func _exit_tree()->void:
	_stop_environment()
	_restore_bedroom()
	if _owns_pause:_pauses.release_pause(PAUSE_REASON)
