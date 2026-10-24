extends SceneTree
const OUTPUT="res://.runtime/game_assistance_20261022"
var main: Node
var checks:=0
var failures:=0
var output: String=OUTPUT
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func click_at(position: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=position
	root.push_input(motion,true)
	var button:=InputEventMouseButton.new()
	button.position=position
	button.button_index=MOUSE_BUTTON_LEFT
	button.pressed=true
	root.push_input(button,true)
	await frames(2)
	button=button.duplicate(); button.pressed=false
	root.push_input(button,true)
	await frames(3)
func walk(player: Node,pressed: bool) -> void:
	for action in ["move_right","move_left","move_down","move_up"]: Input.action_release(action)
	if not pressed: return
	var right: Vector2=player._camera_relative_movement_input(Vector2.RIGHT)
	var down: Vector2=player._camera_relative_movement_input(Vector2.DOWN)
	var screen:=Vector2(Vector2.RIGHT.dot(right),Vector2.RIGHT.dot(down))
	Input.action_press("move_right" if screen.x>=0 else "move_left",absf(screen.x))
	Input.action_press("move_down" if screen.y>=0 else "move_up",absf(screen.y))
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720)
	Engine.max_fps=60
	var settings:=root.get_node("SettingsManager")
	var pixel: bool="--pixel" in OS.get_cmdline_user_args()
	if pixel: output+="/pixel_palette"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	settings.set_setting(&"pixelation_enabled",pixel)
	settings.set_palette_enabled(pixel)
	settings.set_setting(&"auto_vault_enabled",true)
	settings.set_setting(&"screen_shake_enabled",true)
	main=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	var menu: Node=main.current_screen
	menu._show_settings()
	await frames(4)
	var panel: Node=menu.settings_panel
	check(panel.assistance_button.get_global_rect().end.y<=root.get_visible_rect().end.y,"Main menu assistance entry is not clipped")
	await shot("01_menu_general")
	await click_at(panel.assistance_button.get_global_rect().get_center())
	check(panel.assistance_open,"Actual mouse click opens game assistance")
	check(panel.screen_shake_check.get_global_rect().end.y<=root.get_visible_rect().end.y,"Both assistance controls fit on screen")
	await shot("02_menu_assistance")
	await click_at(panel.auto_vault_check.get_global_rect().get_center())
	check(not settings.get_setting(&"auto_vault_enabled"),"Actual menu checkbox disables automatic jump")
	await click_at(panel.auto_vault_check.get_global_rect().get_center())
	check(settings.get_setting(&"auto_vault_enabled"),"Actual menu checkbox restores automatic jump")
	main.persistent_day_state=main._create_initial_state()
	main.persistent_day_state.tutorial_completed=true
	seed(120)
	main._show_dream("basic")
	await ready_main()
	var world: Node=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	main._open_pause_menu()
	main.pause_menu._open_settings()
	await frames(3)
	var pause_panel: Node=main.pause_menu.settings_panel
	pause_panel.assistance_button.pressed.emit()
	await frames(3)
	check(pause_panel.auto_vault_check.button_pressed,"Paused settings share the enabled value")
	check(pause_panel.screen_shake_check.get_global_rect().end.y<=root.get_visible_rect().end.y,"Paused assistance controls remain on screen")
	await shot("03_pause_assistance")
	main._resume_from_pause()
	var player: Node=world.player
	player.maximum_health=1000000
	player.current_health=1000000
	player.set_physics_process(false)
	var found:=false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32.0
			if world._content_position_is_clear(point,85):
				player.global_position=point
				world.activate_room(int(room.id))
				found=true
				break
		if found: break
	check(found,"Formal office supplies a clear real-input test area")
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	var origin: Vector2=player.global_position
	var table: RigidBody2D=load("res://scenes/dream/props/desk.tscn").instantiate()
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(table,"coffee_table")
	table.set_meta(&"office_visual_style","approved_room")
	world.furniture_root.add_child(table)
	table.global_position=origin+Vector2(40,-13)
	table.freeze=true
	world._spawn_furniture_presentation(table)
	await frames(25)
	player._auto_vault_cooldown_left=0
	player.set_physics_process(true)
	walk(player,true)
	var seen_vault:=false
	var max_height:=0.0
	for frame in 45:
		await process_frame
		seen_vault=seen_vault or player.vault_active
		max_height=maxf(max_height,player.vault_height)
		if frame%2==0: await shot("vault_%03d" % (frame/2))
		if seen_vault and not player.vault_active: break
	walk(player,false)
	check(seen_vault and max_height>2,"Normal movement alone triggers visible vault, without Space")
	check(player.global_position.x>table.global_position.x and not player.vault_active,"Real-input vault lands beyond the furniture")
	check(not player.get_collision_exceptions().has(table),"Live vault restores normal collision")
	player.set_physics_process(false)
	player.global_position=origin
	player._time_locomotion_velocity=Vector2.ZERO
	player._auto_vault_cooldown_left=0
	settings.set_setting(&"auto_vault_enabled",false)
	await frames(4)
	player.set_physics_process(true)
	walk(player,true)
	var disabled_vault:=false
	for frame in 25:
		await process_frame
		disabled_vault=disabled_vault or player.vault_active
	walk(player,false)
	check(not disabled_vault and player.global_position.x<table.global_position.x,"Disabling assistance keeps furniture blocking ordinary walking")
	settings.set_setting(&"auto_vault_enabled",true)
	print("GAME_ASSISTANCE_CAMERA checks=",checks," failures=",failures," pixel=",pixel," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(1 if failures else 0)
