extends Control
## Persistent, independently launched test bench. No campaign integration.
const WORLD = preload("res://scenes/testing/LabWorld.tscn")
const DISPLAY = preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const RECORDER = preload("res://scripts/testing/lab_recorder.gd")
const WEAPONS := ["","basic","assault_rifle","shotgun","lucille"]
var world: Node3D
var display: Control
var recorder = RECORDER.new()
var panel: PanelContainer
var status: Label
var stats_label: Label
var hud: CanvasLayer
var mode: OptionButton
var scenario: OptionButton
var weapon: OptionButton
var station: OptionButton
var seed_box: SpinBox
var enemies: SpinBox
var duration: SpinBox
var checks: Dictionary = {}
var busy := false
var ready_world := false
var automation := false
var lab_enemy_archetypes: Array[StringName] = [&"employee"]
var elapsed := 0.0
var next_event := 0
var _ui_clock := 0.0
var _saved_vsync := 0
var _saved_max_fps := 0
var _shadow_restore: Dictionary = {}
var _session_config: Dictionary = {}
var last_export := ""
var output_root := "user://test_lab"
var load_generation := 0
var event_history: Array[String] = []
var _created_attack_action := false
var _original_pointer_gate: Callable
var shot_count := 0
var compact_status: Label
var _run_scenario := 0
var _run_duration := 30.0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output_root)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_saved_vsync=DisplayServer.window_get_vsync_mode(); _saved_max_fps=Engine.max_fps
	if not InputMap.has_action("attack"): InputMap.add_action("attack"); _created_attack_action=true
	# Keep F3's established recorder available. Lab reports describe its presence.
	get_tree().auto_accept_quit=false
	_build_ui()
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	call_deferred("rebuild")

func _build_ui() -> void:
	hud=CanvasLayer.new(); hud.layer=240; add_child(hud)
	panel=PanelContainer.new(); panel.position=Vector2(8,8); panel.size=Vector2(216,344); hud.add_child(panel)
	panel.visibility_changed.connect(_panel_changed)
	var theme_style:=StyleBoxFlat.new(); theme_style.bg_color=Color("101a28ef"); theme_style.border_color=Color("396fe2")
	theme_style.set_border_width_all(1); theme_style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",theme_style)
	panel.add_theme_font_size_override("font_size",12)
	var scroll:=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(206,328); panel.add_child(scroll)
	var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(box)
	_label(box,"FIVE MINUTE MORE / 测试场",11)
	_label(box,"F1 面板 / F8 截图 / F9 记录 / F10 重置",10)
	mode=_options(box,["白盒 · 规则与碰撞","同布局 · 正式美术","正式随机楼层 · 受控负载"])
	seed_box=_number(box,"种子",1,2147483647,71432)
	enemies=_number(box,"敌人数（重置生成）",0,40,8)
	_toggle(box,"furniture","场内家具（重置生效）",true)
	_toggle(box,"ai","运行敌人 AI（重置生效）",false)
	_toggle(box,"special","机器人 / 无人机（重置）",false)
	_button(box,"应用配置 / 重建整个场景",rebuild)
	station=_options(box,["加载中…"]); station.item_selected.connect(func(index:int): teleport(index))
	weapon=_options(box,["拳头","手枪","步枪","霰弹枪","球棍"]); weapon.select(2)
	weapon.item_selected.connect(func(_i:int): equip())
	_toggle(box,"invincible","测试无敌（不改正式数值）",true)
	_toggle(box,"cutout","Occlusion Cutout",true)
	_toggle(box,"shadows","室内灯投影（不关灯）",true)
	_toggle(box,"reflections","地面反射",true)
	_toggle(box,"pixels","游戏像素化",true)
	_toggle(box,"palette","调色板",false)
	_toggle(box,"tonal","色调增强",true)
	_toggle(box,"uncapped","解除垂直同步 / 限帧",true)
	for key in ["invincible","cutout","shadows","reflections","pixels","palette","tonal","uncapped"]:
		checks[key].toggled.connect(func(_value:bool): apply_options())
	_label(box,"功能触发（真实系统）",12)
	var actions:=[ ["烟雾", "smoke"],["击破灭火器","extinguisher"],["血液飞溅","blood"],["打碎最近门窗","break"],["点燃最近家具","fire"] ]
	for item in actions: _button(box,item[0],trigger.bind(item[1]))
	_label(box,"性能采样",12)
	scenario=_options(box,["手动游玩记录","固定姿势基线","自动开火","开火 + 灭火器 / 烟雾","混合事件压力"])
	duration=_number(box,"采样秒数",5,120,30)
	_button(box,"F9 开始 / 停止并导出",toggle_recording)
	_button(box,"F8 无面板截图 + 配置",capture)
	_button(box,"打开输出文件夹",func(): OS.shell_open(ProjectSettings.globalize_path(output_root)))
	stats_label=_label(box,"等待场景…",11)
	status=_label(box,"加载中",11)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x=184
	compact_status=_label(hud,"",10)
	compact_status.position=Vector2(420,8)
	compact_status.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _label(parent:Node,text:String,font_size:int)->Label:
	var node:=Label.new(); node.text=text; node.add_theme_font_size_override("font_size",font_size); parent.add_child(node); return node
func _button(parent:Node,text:String,action:Callable)->void:
	var node:=Button.new(); node.text=text; node.add_theme_font_size_override("font_size",12); node.pressed.connect(action); parent.add_child(node)
func _options(parent:Node,items:Array)->OptionButton:
	var node:=OptionButton.new(); node.add_theme_font_size_override("font_size",12)
	for item in items: node.add_item(str(item))
	parent.add_child(node); return node
func _number(parent:Node,text:String,low:float,high:float,value:float)->SpinBox:
	var row:=HBoxContainer.new(); parent.add_child(row)
	var label:=_label(row,text,11); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var node:=SpinBox.new(); node.min_value=low; node.max_value=high; node.value=value; node.custom_minimum_size.x=78; node.add_theme_font_size_override("font_size",11); row.add_child(node); return node
func _toggle(parent:Node,key:String,text:String,value:bool)->void:
	var node:=CheckBox.new(); node.text=text; node.button_pressed=value; node.add_theme_font_size_override("font_size",11); parent.add_child(node); checks[key]=node

func rebuild() -> void:
	if busy: return
	if recorder.active: stop_recording("scene_reset")
	busy=true; ready_world=false; load_generation+=1
	status.text="正在重建；此过程不计入采样…"
	_release_automation()
	if is_instance_valid(display):
		display.free(); world=null
		await get_tree().process_frame
	world=WORLD.instantiate()
	world.lab_native_layout=mode.selected==2; world.lab_whitebox=mode.selected==0
	world.approved_sample_art_enabled=not world.lab_whitebox
	world.lab_enemy_count=int(enemies.value); world.lab_furniture=checks.furniture.button_pressed
	world.lab_ai=checks.ai.button_pressed; world.lab_special_units=checks.special.button_pressed
	world.lab_enemy_archetypes=lab_enemy_archetypes
	world.persist_profile=false
	# Lab owns its menu; don't let the standalone pause menu change user settings.
	var pause_bridge:=world.get_node_or_null("Dream3DPauseBridge")
	if pause_bridge!=null: pause_bridge.free()
	display=DISPLAY.instantiate(); display.world=world; display.preview_mode=false
	add_child(display); move_child(display,0)
	# LabWorld has a distinct scene path, so the formal scene bootstrap does not
	# install its material component automatically. Production-art modes need
	# the same furniture response and live material refresh as the real entry.
	if not world.lab_whitebox:
		get_node("/root/DreamDisplayBootstrap")._ensure_dither(world)
	var success:bool=world.regenerate(int(seed_box.value))
	if not success:
		status.text="布局生成失败；请重置。"; busy=false; return
	world.populate_lab()
	shot_count=0
	world.player.weapon_fired.connect(_on_weapon_fired)
	_original_pointer_gate=world.player.get_meta(&"presentation_pointer_gate",Callable())
	world.player.set_meta(&"presentation_pointer_gate",_pointer_allowed)
	station.clear()
	for room in world.rooms: station.add_item(str(room.get("name","房间 %s"%room.id)))
	station.select(1 if world.rooms.size()>1 else 0)
	_session_config={"mode":mode.selected,"seed":int(seed_box.value),"requested_enemies":int(enemies.value),"generate_furniture":checks.furniture.button_pressed,"enemy_ai":checks.ai.button_pressed,"special_units":checks.special.button_pressed}
	ready_world=true
	teleport(station.selected); equip(); apply_options()
	RenderingServer.viewport_set_measure_render_time(world.get_viewport().get_viewport_rid(),true)
	busy=false
	status.text="就绪。F1 收起面板后操作角色。\n白盒成绩不能替代正式美术成绩。"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func teleport(index:int)->void:
	if not ready_world or recorder.active: return
	world.player.global_position=world.station_position(index)
	world.player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)
	_event("teleport",{"station":index})

func equip()->void:
	if ready_world and not recorder.active: world.player.equip_weapon(WEAPONS[weapon.selected],world.config)

func apply_options()->void:
	if not ready_world: return
	if recorder.active:
		stop_recording("configuration_changed")
	world.lab_invulnerable=checks.invincible.button_pressed
	world.player.lab_ignore_damage=world.lab_invulnerable
	world.set_lab_cutout(checks.cutout.button_pressed)
	display.set_selective_enabled(checks.pixels.button_pressed)
	display.set_palette_enabled(checks.palette.button_pressed)
	display.set_visual_enhancement(checks.tonal.button_pressed)
	var reflection:=world.get_node_or_null("FloorReflections")
	if reflection!=null: reflection.set_enabled(checks.reflections.button_pressed and not world.lab_whitebox)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if checks.uncapped.button_pressed else _saved_vsync)
	Engine.max_fps=0 if checks.uncapped.button_pressed else _saved_max_fps

func configuration()->Dictionary:
	var result:=_session_config.duplicate(true)
	for key in ["invincible","cutout","shadows","reflections","pixels","palette","tonal","uncapped"]: result[key]=checks[key].button_pressed
	result.merge({"scenario":scenario.selected,"duration_s":duration.value,"station":station.selected,"weapon":WEAPONS[weapon.selected],"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"output_size":str(get_viewport().get_visible_rect().size),"window_size":str(DisplayServer.window_get_size()),"scope":"Controlled lab; fixed seeds/commands, not deterministic physics replay; real F3 monitor remains present; not whole-game acceptance"})
	if ready_world:
		result["sparse_lighting"] = is_instance_valid(world.sparse_lighting) and world.sparse_lighting.enabled
		result.merge({"world_viewport":str(world.get_viewport().size),"rooms":world.rooms.size(),"furniture_actual":world.furniture_root.get_child_count(),"enemy_roots_actual":world.enemy_root.get_child_count(),"reflection_effective":checks.reflections.button_pressed and not world.lab_whitebox,"player_position":str(world.player.global_position),"camera_transform":str(world.camera_3d.global_transform),"shadow_quality":world.shadow_manager.quality})
	return result

func _event(kind:String,details:Dictionary={})->void:
	event_history.append(kind)
	if event_history.size()>64: event_history.pop_front()
	recorder.mark(kind,details)

func _on_weapon_fired(_multiplier:float)->void:
	shot_count+=1
	if recorder.active: recorder.mark("player_shot",{"weapon":world.player.selected_weapon_id,"shot":shot_count})

func trigger(kind:String)->void:
	if not ready_world or busy: return
	var p:Vector2=world.player.global_position
	var aim:Vector2=world.player.get_aim_direction()
	var success:=false
	match kind:
		"smoke":
			var system:Node3D=preload("res://scripts/dream/fire_extinguisher_system.gd").install(world)
			system.discharge(p+aim*32.0); success=true
		"extinguisher":
			var nearest:Node2D=null; var distance:=INF
			for tank in get_tree().get_nodes_in_group(&"fire_extinguishers"):
				if not world.is_ancestor_of(tank) or tank.broken: continue
				var d:float=p.distance_squared_to(tank.global_position)
				if d<distance: distance=d; nearest=tank
			if nearest!=null: nearest.take_damage(100.0,nearest.global_position.direction_to(p)); success=true
		"blood": success=world.spawn_black_blood(p+aim*48.0,-aim,false,-1)
		"break":
			var nearest:Node3D=null; var distance:=INF
			for root_node in [world.wall_root,world.door_root]:
				for target in root_node.get_children():
					if not target.has_method("take_damage"): continue
					if target.get("is_shattered")==true or target.get("is_broken")==true: continue
					var d:float=target.global_position.distance_squared_to(world.get_gameplay_world_position(p))
					if d<distance: distance=d; nearest=target
			if nearest!=null: nearest.take_damage(10000.0,aim); success=true
		"fire":
			var nearest:Node2D=null; var distance:=INF
			for prop in world.furniture_root.get_children():
				var d:float=p.distance_squared_to(prop.global_position)
				if d<distance: distance=d; nearest=prop
			if nearest!=null: success=preload("res://scripts/dream/burning_effects.gd").install(world).ignite(nearest)
	_event(kind,{"success":success,"position":str(p)})
	status.text=("已触发：" if success else "附近没有可用对象：")+kind

func toggle_recording()->void:
	if recorder.active: stop_recording("manual_stop"); return
	if busy or not ready_world: return
	busy=true; status.text="稳定基础场景 2 秒；首个特效仍在采样内触发…"
	# More than the renderer's multi-camera tail. Loading is not a gameplay sample.
	var started:=Time.get_ticks_usec(); var frames:=0
	while frames<90 or Time.get_ticks_usec()-started<2000000:
		await get_tree().process_frame; frames+=1
	busy=false
	if not ready_world: return
	recorder.begin(configuration()); elapsed=0; next_event=0; shot_count=0
	_run_scenario=scenario.selected; _run_duration=duration.value
	automation=_run_scenario>0
	if automation:
		world.player.set_physics_process(true); world.player.movement_enabled=false
		world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	panel.hide(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_event("sample_started",{"warmup_frames":frames,"scenario":scenario.selected})

func stop_recording(reason:String)->void:
	if not recorder.active: return
	_event("sample_stopped",{"reason":reason,"shots_fired":shot_count})
	_release_automation()
	last_export=recorder.finish(output_root,reason)
	panel.show()
	status.text="已保存：\n"+ProjectSettings.globalize_path(last_export) if not last_export.is_empty() else recorder.last_error

func _release_automation()->void:
	Input.action_release("attack"); automation=false
	if is_instance_valid(world) and is_instance_valid(world.player):
		world.player.movement_enabled=true
		world.player.remove_meta(&"aim_direction_override")
		world.player.remove_meta(&"force_weapon_attack")

func _pointer_allowed()->bool:
	if automation: return true
	return not panel.visible and (not _original_pointer_gate.is_valid() or bool(_original_pointer_gate.call()))

func _panel_changed()->void:
	if not ready_world or not is_instance_valid(world): return
	world.player.movement_enabled=not panel.visible and not automation and not world.player.dead
	if panel.visible and not automation: world.player.clear_scripted_locomotion()

func _process(delta:float)->void:
	if not ready_world: return
	if not world.player.dead: world.player.movement_enabled=not automation and not panel.visible
	recorder.frame(world)
	if recorder.active:
		elapsed=(Time.get_ticks_usec()-recorder.start_usec)/1000000.0
		if automation and _run_scenario>=2: world.player.set_meta(&"force_weapon_attack",true)
		if automation and elapsed>=2.0+float(next_event)*3.0:
			if _run_scenario==3 and next_event==0: trigger("extinguisher"); trigger("smoke")
			elif _run_scenario==4:
				var sequence:=["break","blood","extinguisher","fire","smoke"]
				if next_event<sequence.size(): trigger(sequence[next_event])
			next_event+=1
		if elapsed>=_run_duration or recorder.rows.size()>=RECORDER.MAX_FRAMES: stop_recording("duration_reached")
	_ui_clock+=delta
	if _ui_clock>.25:
		_ui_clock=0
		stats_label.text="%.1f FPS | %.2f ms\n家具 %d / 敌人节点 %d\n%s" % [Engine.get_frames_per_second(),delta*1000.0,world.furniture_root.get_child_count(),world.enemy_root.get_child_count(),"记录 %.1f / %.0f 秒"%[elapsed,duration.value] if recorder.active else "未采样 / F9 开始"]
		compact_status.text="F1 测试台 | %.0f FPS\n%s" % [Engine.get_frames_per_second(),"● 记录 %.1f / %.0fs"%[elapsed,_run_duration] if recorder.active else "F8 截图 / F9 采样"]

func _physics_process(_delta:float)->void:
	if recorder.active: recorder.physics_steps+=1

func _pre_draw()->void:
	recorder.draw_start_usec=Time.get_ticks_usec()
	if ready_world and not checks.shadows.button_pressed and is_instance_valid(world.sparse_lighting):
		var main_light: Light3D = world.sparse_lighting.main
		_shadow_restore[main_light] = main_light.shadow_enabled
		main_light.shadow_enabled = false
	if ready_world and not checks.shadows.button_pressed and is_instance_valid(world.shadow_manager):
		for light in world.shadow_manager.candidates:
			if is_instance_valid(light): _shadow_restore[light]=light.shadow_enabled; light.shadow_enabled=false

func _post_draw()->void:
	recorder.draw_ms=(Time.get_ticks_usec()-recorder.draw_start_usec)/1000.0
	for light in _shadow_restore:
		if is_instance_valid(light): light.shadow_enabled=_shadow_restore[light]
	_shadow_restore.clear()

func capture()->void:
	if busy or not ready_world: return
	if recorder.active: status.text="请先结束采样，避免截图读回污染帧耗时。"; return
	if DisplayServer.get_name()=="headless": status.text="无窗口模式不能作为截图验收。"; return
	busy=true
	var visible_before:=hud.visible
	hud.hide()
	var monitor:=get_tree().root.get_node_or_null("PerformanceMonitor")
	var monitor_visible:bool=monitor.visible if monitor is CanvasLayer else false
	if monitor is CanvasLayer: monitor.hide()
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var folder:=RECORDER.unique_directory(output_root,"shot")
	var error:=ERR_CANT_CREATE
	if not folder.is_empty():
		error=image.save_png(folder.path_join("camera.png"))
		var file:=FileAccess.open(folder.path_join("config.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(configuration(),"\t")); file.close()
	hud.visible=visible_before
	if monitor is CanvasLayer: monitor.visible=monitor_visible
	busy=false; status.text="截图已保存：\n"+ProjectSettings.globalize_path(folder) if error==OK else "截图保存失败"

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1: panel.visible=not panel.visible
			KEY_F8: capture()
			KEY_F9: toggle_recording()
			KEY_F10: rebuild()
			KEY_ESCAPE: panel.show()
			_: return
		get_viewport().set_input_as_handled()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if recorder.active: stop_recording("window_closed")
		get_tree().quit()

func _exit_tree()->void:
	_release_automation()
	if recorder.active: recorder.finish(output_root,"scene_exited")
	if RenderingServer.frame_pre_draw.is_connected(_pre_draw): RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_post_draw): RenderingServer.frame_post_draw.disconnect(_post_draw)
	Engine.max_fps=_saved_max_fps; DisplayServer.window_set_vsync_mode(_saved_vsync)
	if _created_attack_action: InputMap.erase_action("attack")
