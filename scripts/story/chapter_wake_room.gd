extends Node3D
## A separate, authored top-down bedroom. No old bedroom background is used.
signal completed
signal sleep_requested
signal save_requested
signal phone_open_requested(page: StringName)
const UI=preload("res://scripts/story/chapter_panel.gd")
const CONFIG=preload("res://resources/demo_config.tres")
var config: DemoConfig=CONFIG
var profile_state: Dictionary={}
var mode: String="RETURN"
var wake_mode:=false
var finishing:=false
var elevator_transition_in_progress:=false
var phone_camera_weight:=0.
var current_minutes:=1260.
var floor_cells: Dictionary={}
@onready var player: CharacterBody2D=$GameplayCanvas/GameplayWorld/DreamPlayer
@onready var gameplay_canvas: CanvasLayer=$GameplayCanvas
@onready var camera_3d: Camera3D=$Camera3D
@onready var player_depth_bridge: Node3D=$PlayerDepthVisual3D
@onready var computer_overlay: Control=$ComputerLayer/ComputerOverlay
@onready var medicine_ui: Control=$ComputerLayer/MelatoninInteraction
@onready var phone: Control=$PhoneLayer/BedroomPhone
@onready var body: Sprite3D=$SleepingSelf
var actor: Node2D:
	get: return player
var destination: Vector2:
	get: return Vector2($Interactions/Bed.position.x,$Interactions/Bed.position.z)*32.
var panel: CanvasLayer
var selected: String=""
var proximity_hint: Label
var entry_open:=true
var entry_tween: Tween
var entry_collision: StaticBody2D
var wake_camera_weight := 0.
var wake_hint: Control
var sleeping_pose: Node2D
func _enter_tree() -> void:
	add_to_group(&"dream_world")
	set_meta(&"story_bedroom",true)
	set_meta(&"preserve_local_palette",true)
func _ready() -> void:
	if wake_mode: mode="WAKE"
	preload("res://scripts/app/game_input_actions.gd").configure()
	for x in range(-5,6):
		for z in range(-4,5): floor_cells[Vector2i(x,z)]=true
	for x in [2,3]: floor_cells[Vector2i(x,5)]=true
	_setup_collisions()
	for mesh in find_children("*","MeshInstance3D",true,false):
		if not mesh.has_meta("pixel_swatch") or not mesh.material_override is StandardMaterial3D: continue
		var color: Color=mesh.material_override.albedo_color
		var kind: String=mesh.get_meta("pixel_swatch","paint")
		if mesh.name=="Floor": mesh.material_override=OfficePixelMaterials.make_floor(color,kind)
		elif mesh.name!="LCD": mesh.material_override=OfficePixelMaterials.make(color,kind)
	player.global_position=Vector2($PlayerSpawn.position.x,$PlayerSpawn.position.z)*32.
	player.configure_weapon("basic",CONFIG,{})
	player.set_attacking_enabled(false); player.set_dash_enabled(false)
	player.movement_enabled=true
	player_depth_bridge.configure(player,player_depth_bridge.get_node("ActorDepthViewport"),player_depth_bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),gameplay_canvas,[NodePath("CharacterVisual")])
	player_depth_bridge.set_world_camera(camera_3d)
	_build_sleeping_self()
	body.visible=mode=="WAKE"
	panel=UI.new(); add_child(panel)
	wake_hint=preload("res://scripts/story/context_hint.gd").new(); panel.add_child(wake_hint)
	proximity_hint=Label.new(); proximity_hint.add_theme_font_override("font",preload("res://scripts/ui/crisp_interaction_font.gd").get_font()); proximity_hint.add_theme_font_size_override("font_size",12)
	proximity_hint.add_theme_color_override("font_shadow_color",Color.BLACK); proximity_hint.add_theme_constant_override("shadow_offset_x",1); proximity_hint.add_theme_constant_override("shadow_offset_y",1)
	proximity_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(proximity_hint); proximity_hint.hide()
	phone.configure_state(profile_state); phone.set_external_ui_enabled(true)
	phone.set_meta("chapter_read_only_shop",true)
	phone.open_requested.connect(func(page: StringName): phone_open_requested.emit(page))
	phone.balance_changed.connect(func(): save_requested.emit()); phone.state_changed.connect(func(): save_requested.emit())
	computer_overlay.configure(profile_state)
	computer_overlay.closed.connect(func(): player.movement_enabled=not finishing)
	computer_overlay.balance_changed.connect(func(): save_requested.emit())
	computer_overlay.state_changed.connect(func(): save_requested.emit())
	medicine_ui.completed.connect(_medicine_completed); medicine_ui.cancelled.connect(func(): player.movement_enabled=true)
	var dither:=preload("res://scripts/dream/office_dither_lighting.gd").new(); dither.name="OfficeDitherLighting"; add_child(dither)
	preload("res://scripts/audio/sfx_manager.gd").play_bedroom_music(false,get_instance_id())
	_update_projection()
func _setup_collisions() -> void:
	var root: Node=$GameplayCanvas/GameplayWorld
	for entry in [[Vector2(0,-4.5),Vector2(11.2,.2)],[Vector2(-1.775,4.5),Vector2(7.45,.2)],[Vector2(4.575,4.5),Vector2(1.85,.2)],[Vector2(-5.5,0),Vector2(.2,9.)],[Vector2(5.5,0),Vector2(.2,9.)],[Vector2(2.8,5.7),Vector2(1.9,.2)],[Vector2(1.9,5.1),Vector2(.15,1.2)],[Vector2(3.7,5.1),Vector2(.15,1.2)]]:
		_solid(root,entry[0],entry[1])
	for item in $Furniture.get_children():
		if item.has_meta("solid_size"):
			_solid(root,Vector2(item.position.x,item.position.z),item.get_meta("solid_size"))
	entry_collision=_solid(root,Vector2.ZERO,Vector2(1.4,.10)); entry_collision.name="EntryDoorCollision"
	_update_entry_collision()
func _solid(root: Node,point: Vector2,size: Vector2) -> StaticBody2D:
	var collision:=StaticBody2D.new(); collision.position=point*32.; collision.collision_layer=4; collision.collision_mask=0
	var shape:=CollisionShape2D.new(); var rect:=RectangleShape2D.new(); rect.size=size*32.; shape.shape=rect; collision.add_child(shape); root.add_child(collision)
	return collision
func _update_entry_collision() -> void:
	if not is_instance_valid(entry_collision): return
	var hinge: Node3D=$EntryDoor/Hinge
	var center: Vector3=to_local(hinge.to_global(Vector3(-.7,0,0)))
	entry_collision.position=Vector2(center.x,center.z)*32.
	entry_collision.rotation=-hinge.rotation.y
func _toggle_entry() -> void:
	if is_instance_valid(entry_tween) and entry_tween.is_running(): return
	entry_open=not entry_open
	entry_tween=create_tween(); entry_tween.tween_property($EntryDoor/Hinge,"rotation:y",PI/2. if entry_open else 0.,.38).set_trans(Tween.TRANS_SINE)
func _build_sleeping_self() -> void:
	var source: Node=preload("res://scenes/preview/night_coast.tscn").instantiate()
	var sleeping: Node2D=source.get_node("WalkerCapture/CoastWalker"); sleeping.get_parent().remove_child(sleeping); sleeping.owner=null
	var view:=SubViewport.new(); view.size=Vector2i(64,64); view.transparent_bg=true; view.world_2d=World2D.new(); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(view)
	view.add_child(sleeping); sleeping.position=Vector2(32,49)
	sleeping_pose=sleeping
	sleeping.facing_back=false; sleeping.moving=false; sleeping.pose(); sleeping.head.region_rect=Rect2(64,64,32,32)
	source.free(); body.texture=view.get_texture()
	var sleeping_material:=ShaderMaterial.new(); sleeping_material.shader=preload("res://shaders/story/sleeping_self.gdshader")
	sleeping_material.set_shader_parameter("sleep_texture",body.texture); body.material_override=sleeping_material
func _process(_delta: float) -> void:
	_update_projection()
	_update_entry_collision()
	phone.visible=not finishing and not computer_overlay.visible and not medicine_ui.visible
	proximity_hint.hide(); panel.status.hide()
	if finishing: return
	if computer_overlay.visible or medicine_ui.visible:
		panel.status.hide()
		return
	selected=""; var nearest:=48.
	for item in $Interactions.get_children():
		if mode not in ["EVENING","COMPLETE"] and item.name not in ["Bed","Entry"]: continue
		var point:=Vector2(item.position.x,item.position.z)*32.
		var distance:=player.global_position.distance_to(point)
		if distance<nearest: nearest=distance; selected=str(item.name)
	var text: String=""
	match selected:
		"Computer": text="[E] 使用笔记本"
		"Medicine": text="药物已服用" if profile_state.get("chapter_one",{}).get("medicine",false) else "[E] 服用公司配发的助眠药"
		"Bed": text="[F] 叫醒自己" if mode=="WAKE" else ("[E] 躺回床上" if mode=="RETURN" else "[E] 入睡")
		"Entry": text="[E] 关门" if entry_open else "[E] 开门"
	if selected=="Bed" and mode=="EVENING" and not profile_state.get("chapter_one",{}).get("medicine",false): text="先服用床头助眠药"
	if mode=="COMPLETE" and selected=="Bed": text="第一章已完成"
	if not selected.is_empty():
		var marker: Node3D=$Interactions.get_node(selected)
		proximity_hint.text=text; proximity_hint.position=camera_3d.unproject_position(marker.position+Vector3(0,1.,0))+Vector2(8,-14); proximity_hint.show()
func _update_projection() -> void:
	if not is_instance_valid(player): return
	var ground:=Vector3(player.global_position.x/32.,0,player.global_position.y/32.)
	camera_3d.size=13.2-2.6*phone_camera_weight
	camera_3d.position=Vector3(9,14,14).lerp(ground+Vector3(6,11,10),phone_camera_weight)
	camera_3d.look_at(ground*.15*phone_camera_weight)
	if wake_camera_weight>0.:
		camera_3d.size=lerpf(camera_3d.size,11.8,wake_camera_weight)
	var projected:=camera_3d.unproject_position(ground)
	gameplay_canvas.transform=Transform2D(Vector2.RIGHT,Vector2.DOWN,projected-player.global_position)
func _unhandled_input(event: InputEvent) -> void:
	if finishing or get_tree().paused or computer_overlay.visible or medicine_ui.visible: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code==KEY_F and selected=="Bed" and mode=="WAKE":
		get_viewport().set_input_as_handled(); finish(); return
	if code!=KEY_E: return
	match selected:
		"Entry": _toggle_entry()
		"Computer":
			player.movement_enabled=false; computer_overlay.open()
		"Medicine":
			if not profile_state.get("chapter_one",{}).get("medicine",false):
				player.movement_enabled=false; medicine_ui.open(profile_state)
		"Bed":
			if mode=="RETURN": finish()
			elif mode=="EVENING":
				if profile_state.get("chapter_one",{}).get("medicine",false): finish()
				else: proximity_hint.text="先服用床头的助眠药。"
	get_viewport().set_input_as_handled()
func _medicine_completed() -> void:
	profile_state.chapter_one.medicine=true; player.movement_enabled=true; save_requested.emit()
func consume_escape() -> bool:
	if computer_overlay.visible: computer_overlay.close(); return true
	if medicine_ui.visible: medicine_ui.force_cancel(); player.movement_enabled=true; return true
	return false
func set_game_phone_active(active: bool) -> void:
	phone.set_external_ui_active(active)
	if is_instance_valid(panel): panel.status.hide()
	if is_instance_valid(proximity_hint): proximity_hint.visible=false
func set_phone_camera_weight(weight: float) -> void: phone_camera_weight=weight
func refresh_phone_camera_presentation(_delta: float=0.) -> void: _update_projection()
func get_gameplay_aim_position() -> Vector2: return player.global_position+Vector2.UP*100.
func get_gameplay_world_position(point: Vector2,height: float=.65) -> Vector3: return Vector3(point.x/32.,height,point.y/32.)
func finish() -> void:
	if finishing: return
	finishing=true; elevator_transition_in_progress=true; player.movement_enabled=false
	if mode!="WAKE": player_depth_bridge.hide(); body.show()
	panel.show_status("……醒过来。" if mode=="WAKE" else "眼皮越来越沉……")
	if mode=="WAKE":
		proximity_hint.hide(); wake_hint.present("……醒过来。",Vector2(320,296))
		var tween:=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self,"wake_camera_weight",1.,.8)
		tween.tween_callback(func():
			var head: Sprite2D=sleeping_pose.get("head"); head.region_rect=Rect2(64,0,32,32))
		tween.tween_interval(.35)
		await tween.finished
	else:
		await get_tree().create_timer(1.).timeout
	if mode=="EVENING": sleep_requested.emit()
	else: completed.emit()
func restore_after_failed_finish() -> void:
	finishing=false; elevator_transition_in_progress=false; wake_camera_weight=0.
	player.movement_enabled=true; wake_hint.hide()
	var head: Sprite2D=sleeping_pose.get("head"); head.region_rect=Rect2(64,64,32,32)
func _exit_tree() -> void:
	preload("res://scripts/audio/sfx_manager.gd").stop_music(.2,get_instance_id())
