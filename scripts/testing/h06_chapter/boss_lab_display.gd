extends "res://scripts/dream/preview/selective_pixel_preview.gd"
const LOADING := preload("res://scenes/ui/loading_overlay.tscn")
const TITLES := ["直线炮击","六枚导弹","蓄力跳砸","旋转激光","蓄力冲刺","近身脚踩","半血六向激光","三排导弹齐射"]
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const REPLAY_BOARDING := &"h06_lab_replay_boarding"
var ready_lab := false
var entry_loading: LoadingOverlay
var panel: PanelContainer
var mode_label: Label
var immune: CheckBox
var pause_button: Button

func _ready() -> void:
	preview_mode=false
	muted=false
	world=preload("res://scenes/testing/H06BossAttackWorld.tscn").instantiate()
	if get_tree().has_meta(REPLAY_BOARDING):
		world.replay_boarding=true
		get_tree().remove_meta(REPLAY_BOARDING)
	world.set_meta(&"h06_evacuation_enabled",world.replay_boarding)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	super._ready()
	get_window().title="H06 Boss 攻击测试"
	_build_controls()
	world.special_practice_finished.connect(func():mode_label.text="H06 · 六招循环")
	entry_loading=LOADING.instantiate()
	add_child(entry_loading)
	entry_loading.show_loading("正在准备 H06 Boss 测试...")
	entry_loading.root_control.modulate.a=1.
	call_deferred("_prepare_lab")

func _prepare_lab() -> void:
	await get_tree().process_frame
	for i in 1200:
		if world._session_initialized:break
		await get_tree().process_frame
	if not is_inside_tree():return
	await world.prepare_chapter_streaming(entry_loading.set_progress)
	# Compile both warning shapes under the existing covered loading screen.
	if is_instance_valid(world.boss):
		world.boss.attacks.fx.warn_line(Vector2(36,0),Vector2(40,4),2.)
		world.boss.attacks.fx.mark(0,Vector2(42,1),1.95)
		world.boss.attacks.fx.charge_laser(world.boss.model.position,world.boss.model.rotation.y,.45,false)
	for i in 10:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if is_instance_valid(world.boss):world.boss.attacks.fx.clear()
	world.process_mode=Node.PROCESS_MODE_INHERIT
	ready_lab=true
	await entry_loading.hide_loading()
	entry_loading.queue_free()
	entry_loading=null

func _build_controls() -> void:
	var layer:=CanvasLayer.new()
	layer.layer=90
	add_child(layer)
	panel=PanelContainer.new()
	panel.position=Vector2(8,32)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("121820dc")
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel",style)
	panel.add_theme_font_override("font",FONT.get_font())
	panel.add_theme_font_size_override("font_size",10)
	layer.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",2)
	panel.add_child(column)
	mode_label=Label.new()
	mode_label.add_theme_font_override("font",FONT.get_font())
	mode_label.add_theme_font_size_override("font_size",10)
	mode_label.text="H06 · 六招循环"
	column.add_child(mode_label)
	_button(column,"0　正常攻击循环",func():choose(-1))
	for i in 5:_button(column,"%d　%s"%[i+1,TITLES[i]],choose.bind(i))
	var special := HBoxContainer.new()
	column.add_child(special)
	_button(special,"6 脚踩",choose.bind(5))
	_button(special,"7 六束",choose.bind(6))
	_button(special,"8 齐射",choose.bind(7))
	immune=CheckBox.new()
	immune.text="F2　测试无敌"
	immune.focus_mode=Control.FOCUS_NONE
	immune.add_theme_font_override("font",FONT.get_font())
	immune.add_theme_font_size_override("font_size",10)
	immune.button_pressed=true
	immune.toggled.connect(func(value:bool):
		if ready_lab:world.player.lab_ignore_damage=value)
	column.add_child(immune)
	pause_button=_button(column,"P　暂停 Boss",toggle_pause)
	_button(column,"F5　重新开始",restart)
	var hint:=Label.new()
	hint.text="9 重演登台 · F1 显隐面板"
	hint.add_theme_font_size_override("font_size",8)
	column.add_child(hint)

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button:=Button.new()
	button.text=title
	button.add_theme_font_override("font",FONT.get_font())
	button.add_theme_font_size_override("font_size",10)
	button.focus_mode=Control.FOCUS_NONE
	for state: String in ["normal","hover","pressed"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("273649" if state=="normal" else "3e526b")
		style.border_color=Color("52677f")
		style.set_border_width_all(1)
		style.content_margin_left=5
		style.content_margin_right=5
		style.content_margin_top=2
		style.content_margin_bottom=2
		button.add_theme_stylebox_override(state,style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _pointer_inside() -> bool:
	return super._pointer_inside() and (not is_instance_valid(panel) or not panel.visible or not panel.get_global_rect().has_point(_pointer_window))

func choose(index: int) -> void:
	if not ready_lab or not is_instance_valid(world.boss) or world.boss.dead:return
	world.select_attack(index)
	if index < 0: mode_label.text="H06 · 六招循环"
	elif world.ATTACKS.CYCLE.has(index): mode_label.text="H06 · "+TITLES[index]+"循环"
	else: mode_label.text="H06 · "+TITLES[index]
	pause_button.text="P　暂停 Boss"

func toggle_pause() -> void:
	if not ready_lab or not is_instance_valid(world.boss) or world.boss.dead:return
	world.set_attacks_paused(not world.attacks_paused)
	pause_button.text="P　继续 Boss" if world.attacks_paused else "P　暂停 Boss"

func restart() -> void:
	get_tree().paused=false
	get_tree().call_deferred("reload_current_scene")

func _input(event: InputEvent) -> void:
	super._input(event)
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key>=KEY_1 and key<=KEY_8:choose(key-KEY_1)
	elif key==KEY_9 and ready_lab and world.blockout.inclined_lift!=null:
		get_tree().set_meta(REPLAY_BOARDING,true)
		restart()
	elif key==KEY_0:choose(-1)
	elif key==KEY_F1:panel.visible=not panel.visible
	elif key==KEY_F2:immune.button_pressed=not immune.button_pressed
	elif key==KEY_F5:restart()
	elif key==KEY_P:toggle_pause()
	else:return
	get_viewport().set_input_as_handled()
