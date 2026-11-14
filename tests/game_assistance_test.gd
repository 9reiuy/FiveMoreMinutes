extends SceneTree
const CATALOG=preload("res://scripts/dream/office_furniture_catalog.gd")
var checks:=0
var failures:=0
var world: Node
var player: Node
var manager: Node
var origin:=Vector2(12000,12000)
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func prop(kind: String) -> RigidBody2D:
	var item: RigidBody2D=load("res://scenes/dream/props/desk.tscn").instantiate()
	CATALOG.configure(item,kind)
	world.furniture_root.add_child(item)
	item.freeze=true
	return item
func reset_actor() -> void:
	player._cancel_vault()
	player.global_position=origin
	player._auto_vault_cooldown_left=0
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: quit(2))
	print("GAME_ASSISTANCE_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		push_error("Game assistance test needs a pre-muted private profile")
		quit(2)
		return
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	manager=root.get_node("SettingsManager")
	check(manager.defaults.auto_vault_enabled and manager.defaults.screen_shake_enabled,"Movement assistance defaults on")
	check(manager.get_setting(&"canned_laughter_enabled"), "Existing settings default to enabling audience reactions")
	var audio := root.get_node("SFXManager")
	var reactions: Array[StringName] = [&"canned_laughter", &"audience_applause", &"golf_clap"]
	for reaction in reactions:
		audio.play_multi_kill_reaction(reaction)
		check(audio.players[reaction].playing and audio.music_duck_reasons.has(&"multi_kill_reaction"), "Enabled reaction plays and ducks music: " + String(reaction))
	paused = true
	manager.set_setting(&"canned_laughter_enabled", false)
	for reaction in reactions:
		check(not audio.players[reaction].playing, "Disabling stops overlapping reaction during pause: " + String(reaction))
	check(not audio.music_duck_reasons.has(&"multi_kill_reaction") and audio.multi_kill_duck_tween == null, "Disabling clears the reaction music duck and pending release")
	paused = false
	for reaction in reactions:
		check(not audio.play(reaction), "Disabled reaction is rejected by direct playback: " + String(reaction))
		audio.play_multi_kill_reaction(reaction)
		check(not audio.players[reaction].playing and not audio.music_duck_reasons.has(&"multi_kill_reaction"), "Disabled reaction neither plays nor ducks music: " + String(reaction))
	audio.play_multi_kill_reaction()
	check(not audio.music_duck_reasons.has(&"multi_kill_reaction"), "Random reaction selection also respects the combined toggle")
	manager.set_setting(&"auto_vault_enabled",false)
	manager.set_setting(&"screen_shake_enabled",false)
	var reloaded: Node=load("res://scripts/app/settings_manager.gd").new()
	reloaded.values=reloaded.defaults.duplicate(true)
	reloaded._load_settings()
	check(not reloaded.get_setting(&"auto_vault_enabled") and not reloaded.get_setting(&"screen_shake_enabled"),"Both options persist through settings reload")
	check(not reloaded.get_setting(&"canned_laughter_enabled") and reloaded.get_volume(&"master_volume") == 0, "Saved combined toggle reloads from the existing setting key in the muted profile")
	var legacy:=ConfigFile.new()
	legacy.set_value("audio", "master_volume", 0)
	legacy.set_value("graphics","pixelation_enabled",true)
	legacy.save("user://assistance_legacy.cfg")
	reloaded.values=reloaded.defaults.duplicate(true)
	reloaded._load_settings("user://assistance_legacy.cfg")
	check(reloaded.get_setting(&"auto_vault_enabled") and reloaded.get_setting(&"screen_shake_enabled"),"Older settings gain safe default values")
	check(reloaded.get_setting(&"canned_laughter_enabled") and reloaded.get_volume(&"master_volume") == 0, "Legacy settings retain default laughter and private mute")
	reloaded.free()
	var panel: Node=load("res://scenes/ui/settings_panel.tscn").instantiate()
	root.add_child(panel)
	panel.assistance_button.pressed.emit()
	await create_timer(0.2).timeout
	check(panel.assistance_options.visible and not panel.rows.get_node("Master").visible,"Shared menu opens game assistance page")
	check(not panel.auto_vault_check.button_pressed and not panel.screen_shake_check.button_pressed,"Checkboxes reflect saved values")
	check(not panel.canned_laughter_check.button_pressed, "Assistance shows the saved laughter state")
	check(panel.canned_laughter_desc.text == "罐头笑声和掌声", "Shared menu labels the combined reaction toggle")
	panel.auto_vault_check.button_pressed=true
	check(manager.get_setting(&"auto_vault_enabled"),"Menu checkbox changes live setting")
	var phone: Node=load("res://scripts/ui/phone_settings_screen.gd").new()
	root.add_child(phone)
	phone.set_context(&"settings")
	check(phone._rows().size()==3,"Phone settings includes assistance category")
	phone._push_page(&"assistance")
	check(phone._rows().size() == 3 and phone.get_control_point(&"canned_laughter_enabled").x >= 0 and phone._rows()[2][1] == "罐头笑声和掌声", "Phone assistance includes the same combined reaction control")
	phone.navigate(&"left")
	check(not manager.get_setting(&"auto_vault_enabled") and not panel.auto_vault_check.button_pressed,"Phone keyboard controls synchronize shared menu")
	phone.navigate(&"right")
	check(manager.get_setting(&"auto_vault_enabled"),"Phone can restore auto jump")
	phone.navigate(&"down")
	phone.navigate(&"down")
	phone.navigate(&"confirm")
	check(manager.get_setting(&"canned_laughter_enabled") and panel.canned_laughter_check.button_pressed, "Phone confirmation restores audience reactions in the shared menu")
	for reaction in reactions:
		audio.play_multi_kill_reaction(reaction)
		check(audio.players[reaction].playing, "Re-enabling allows the reaction again: " + String(reaction))
	audio.request_music_duck(&"assistance_test_other", -2.0, 0.0)
	manager.set_setting(&"canned_laughter_enabled", false)
	for reaction in reactions:
		check(not audio.players[reaction].playing, "Combined toggle stops every overlapping reaction: " + String(reaction))
	check(not audio.music_duck_reasons.has(&"multi_kill_reaction") and audio.music_duck_reasons.has(&"assistance_test_other"), "Disabling releases only the audience reaction music duck")
	audio.release_music_duck(&"assistance_test_other", 0.0)
	manager.set_setting(&"canned_laughter_enabled", true)
	panel.free(); phone.free()
	if "--settings-only" in OS.get_cmdline_user_args():
		finish()
		return
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false
	world.spawn_content=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	root.add_child(world)
	check(world.regenerate(42001),"Formal world generates")
	await frames(4)
	world.set_process(false)
	player=world.player
	player.set_physics_process(false)
	player.movement_enabled=true
	player.attacking_enabled=true
	manager.set_setting(&"screen_shake_enabled",true)
	world.request_camera_impulse_strength(.7,Vector2.RIGHT)
	check(world.camera_impulse_offset.length()>0 and world.camera_shake_amplitude>0,"Enabled camera shake accepts impacts")
	paused=true
	manager.set_setting(&"screen_shake_enabled",false)
	check(world.camera_impulse_offset==Vector3.ZERO and world.camera_shake_amplitude==0,"Disabling clears current impact immediately")
	paused=false
	world.request_camera_impulse_strength(1.2,Vector2.DOWN)
	check(world.camera_impulse_offset==Vector3.ZERO and world.camera_shake_duration==0,"Disabled camera rejects new impacts")
	world._phone_camera_refresh_only=true
	world._update_camera_and_actor_projection()
	var before: Vector3=world.camera_rig.position
	player.global_position+=Vector2(32,0)
	world._update_camera_and_actor_projection()
	check(world.camera_rig.position.distance_to(before+Vector3(1,0,0))<.001,"Normal follow remains active with shake off")
	before=world.camera_rig.position
	world.elevator_rumble_active=true
	world._update_camera_and_actor_projection(.02)
	check(world.camera_rig.position.distance_to(before)<.001,"Elevator rumble produces no camera displacement when disabled")
	world.elevator_rumble_active=false
	manager.set_setting(&"screen_shake_enabled",true)
	check(world.camera_impulse_offset==Vector3.ZERO,"Re-enabling does not replay stale impact")
	for x in range(370,385):
		for y in range(370,385): world.floor_cells[Vector2i(x,y)]=true
	reset_actor()
	var low:=prop("box")
	var low_shape: CollisionShape2D=low.get_node("CollisionShape2D")
	var radius: float=player.body_collision.shape.radius
	var half_width: float=low_shape.shape.get_rect().size.x*.5
	low.global_position=player.body_collision.global_position+Vector2(radius+half_width+2,0)
	await frames(4)
	await physics_frame
	check(not player.try_auto_vault(Vector2.ZERO),"Standing beside furniture does not auto jump")
	check(not player.try_auto_vault(Vector2.DOWN),"Walking parallel to furniture does not auto jump")
	check(not player.try_auto_vault(Vector2.LEFT),"Moving away does not auto jump")
	var placed:=low.global_position
	low.global_position+=Vector2(40,0)
	await physics_frame
	check(not player.try_auto_vault(Vector2.RIGHT),"Distant low furniture does not trigger")
	low.global_position=placed
	await physics_frame
	manager.set_setting(&"auto_vault_enabled",false)
	check(not player.try_auto_vault(Vector2.RIGHT),"Disabled automatic jump leaves movement alone")
	check(player._try_start_vault(Vector2.RIGHT),"Manual legacy vault helper is unaffected by assistance toggle")
	reset_actor()
	manager.set_setting(&"auto_vault_enabled",true)
	check(player.try_auto_vault(Vector2.RIGHT) and player.vault_active,"Approaching close low furniture starts existing vault action")
	check(player.get_collision_exceptions().has(low),"Vault owns exactly the furniture collision exception")
	manager.set_setting(&"auto_vault_enabled",false)
	for i in 20:
		if not player.vault_active: break
		player._update_vault(.02)
	check(not player.vault_active and player.global_position.x>low.global_position.x,"Disabling during a vault still finishes safely beyond furniture")
	check(not player.get_collision_exceptions().has(low),"Completed vault removes collision exception")
	reset_actor()
	manager.set_setting(&"auto_vault_enabled",true)
	low.vaultable=false
	check(not player.try_auto_vault(Vector2.RIGHT),"Non-vaultable furniture stays solid")
	low.vaultable=true
	low.set_meta(&"office_furniture_kind","cabinet")
	check(not player.try_auto_vault(Vector2.RIGHT),"High furniture is rejected even with stale vaultable metadata")
	low.set_meta(&"office_furniture_kind","box")
	low.sky_drop_height=8.0
	check(not player.try_auto_vault(Vector2.RIGHT),"Airborne low furniture cannot trigger a ground auto vault")
	low.sky_drop_height=0.0
	var wall:=StaticBody2D.new()
	wall.collision_layer=4
	var shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=Vector2(8,100)
	shape.shape=rectangle
	wall.add_child(shape)
	world.collision_root.add_child(wall)
	wall.global_position=origin+Vector2(45,-13)
	await physics_frame
	check(not player.try_auto_vault(Vector2.RIGHT),"Blocked landing prevents automatic jump")
	wall.free()
	var floors: Dictionary=world.floor_cells.duplicate()
	for cell in world.floor_cells.keys():
		if cell.x>=376: world.floor_cells.erase(cell)
	check(not player.try_auto_vault(Vector2.RIGHT),"Missing exterior landing floor prevents automatic jump")
	world.floor_cells=floors
	paused=true
	check(not player.try_auto_vault(Vector2.RIGHT),"Pause prevents automatic jump")
	paused=false
	player.movement_enabled=false
	check(not player.try_auto_vault(Vector2.RIGHT),"Dialogue or transition control lock prevents automatic jump")
	player.movement_enabled=true
	player._auto_vault_cooldown_left=1
	check(not player.try_auto_vault(Vector2.RIGHT),"Short recovery prevents immediate repeated auto jumps")
	world.free()
	await frames(4)
	finish()

func finish() -> void:
	print("GAME_ASSISTANCE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
