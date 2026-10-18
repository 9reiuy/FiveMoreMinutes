extends SceneTree
## Full production Main._show_dream integration with real Input singleton events.
## Mandatory isolated APPDATA/LOCALAPPDATA below project .runtime: no real saves.
## Headless validates logic only. GL Compatibility additionally captures the
## actual Camera, with a minimized no-focus window and six real reflection faces.
## Optional --artifact-dir=res://.runtime/<folder>; output stays below .runtime.
var artifact_dir: String = "res://.runtime/game_phone_full_dungeon_20261018"
var main:Node
var checks:=0
var failures:Array[String]=[]
var report:Dictionary={"scope":"Actual Main._show_dream full initial floor; headless functional validation only"}
func _init()->void:
    var user_path:=OS.get_user_data_dir().replace("\\","/").simplify_path()
    var isolated_root:=ProjectSettings.globalize_path("res://.runtime/").replace("\\","/").simplify_path()
    if not user_path.begins_with(isolated_root+"/"):
        push_error("Phone integration test requires isolated APPDATA/LOCALAPPDATA below project .runtime; refusing to run against real saves")
        quit(2)
        return
    call_deferred("run")
func check(ok:bool,label:String)->void:
    checks+=1;print("CHECK ",label,"=",ok)
    if not ok:failures.append(label);push_error(label)
func wait_real(seconds:float)->void:
    var until:int=Time.get_ticks_usec()+int(seconds*1000000)
    while Time.get_ticks_usec()<until:await process_frame
func key(code:Key,pressed:bool=true)->void:
    var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);Input.flush_buffered_events()
func mouse(button:MouseButton,pressed:bool=true)->void:
    var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;event.position=Vector2(500,250);event.global_position=event.position;Input.parse_input_event(event);Input.flush_buffered_events()
func tap(code:Key)->void:
    key(code);await wait_real(.04);key(code,false);await wait_real(.03)
func run()->void:
    report.scope="Actual Main._show_dream full initial floor; real Input.parse_input_event pressed/released singleton states"
    report.display=DisplayServer.get_name();report.renderer=RenderingServer.get_current_rendering_method()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--artifact-dir="):artifact_dir=argument.trim_prefix("--artifact-dir=")
    var absolute_output:=ProjectSettings.globalize_path(artifact_dir).replace("\\","/").simplify_path()
    var allowed_output:=ProjectSettings.globalize_path("res://.runtime/").replace("\\","/").simplify_path()+"/"
    if not absolute_output.begins_with(allowed_output):
        push_error("Phone integration artifacts must stay in project .runtime")
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(absolute_output)
    Engine.max_fps=60;root.size=Vector2i(640,360)
    if DisplayServer.get_name()!="headless":
        root.size=Vector2i(1920,1080)
        preload("res://tests/support/background_gpu.gd").start(self)
        process_frame.connect(func():
            if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
    main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await process_frame
    main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
    seed(120)
    var start:int=Time.get_ticks_usec();main._show_dream("basic")
    var deadline:int=Time.get_ticks_msec()+90000
    while main.transition_running and Time.get_ticks_msec()<deadline:await process_frame
    check(not main.transition_running,"actual Main initial floor load completes")
    var world:Node3D=main._supported_dream_world
    check(is_instance_valid(world),"actual full Dungeon exists")
    if not is_instance_valid(world):finish();return
    deadline=Time.get_ticks_msec()+30000
    while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:await process_frame
    report.initial_entry_ms=float(Time.get_ticks_usec()-start)/1000.0
    report.rooms=world.rooms.size();report.enemies=world.enemy_root.get_child_count();report.floor_index=world.floor_index
    check(world.rooms.size()>3 and world.enemy_root.get_child_count()>0,"full generated floor contains natural rooms and enemies")
    check(not world.floor_transition_in_progress,"initial elevator sequence finishes")
    world.persist_profile=false
    world.player.dash_invulnerability_left=3600.0
    var phone:Node=main.game_phone
    check(phone.can_open(),"Tab gate permits ready formal floor")
    world.refresh_phone_camera_presentation(0)
    var base_fov:float=world.camera_3d.fov
    var base_focus:Vector3=world.camera_rig.position
    var base_position:Vector2=world.player.global_position
    var original_gate:Variant=world.player.get_meta(&"presentation_pointer_gate",Callable())
    var base_seconds:float=world.run_interface.seconds
    await tap(KEY_TAB);await wait_real(.65)
    check(phone.is_open() and paused,"actual Tab opens phone and pauses formal floor")
    if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(artifact_dir.path_join("full_floor_phone.png"))
    check(is_equal_approx(world.camera_3d.fov,base_fov/1.4) and is_equal_approx(world.phone_camera_weight,1),"full floor camera reaches 1.4x zoom")
    check(world.run_interface.seconds==base_seconds and world.player.global_position==base_position,"phone stops actual formal floor clock and movement")
    var data:Dictionary=phone._clock_data()
    var minutes:float=world.config.dream_start_minutes+world.run_interface.seconds/maxf(world.config.real_seconds_per_game_minute,.001)
    check(data.time=="%02d:%02d"%[int(minutes)/60%24,int(minutes)%60],"phone shows actual formal game-clock conversion")
    phone.screen.open_app(&"shop")
    var money:int=main.persistent_day_state.balance
    var inventory:int=main.persistent_day_state.melatonin_inventory
    await tap(KEY_ENTER)
    check(main.persistent_day_state.balance==money and main.persistent_day_state.melatonin_inventory==inventory,"full floor shop remains read-only")
    key(KEY_W);await wait_real(.15)
    check(Input.is_physical_key_pressed(KEY_W),"fixture really holds physical W in Input singleton")
    check(not Input.is_action_pressed("move_up") and world.player.global_position==base_position,"held phone navigation cannot move actual player")
    var equipped:String=world.player.selected_weapon_id
    mouse(MOUSE_BUTTON_RIGHT);await wait_real(.04)
    check(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_action_pressed("throw_weapon"),"physical RMB is held while gameplay throw action stays released")
    mouse(MOUSE_BUTTON_RIGHT,false);await wait_real(.04)
    check(world.player.selected_weapon_id==equipped and not Input.is_action_pressed("throw_weapon"),"right-click return never throws actual held gun")
    mouse(MOUSE_BUTTON_LEFT);await wait_real(.08)
    check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not world.player.should_trigger_weapon_attack(),"true physical left hold cannot attack during phone UI")
    await tap(KEY_TAB);await wait_real(.65)
    check(not phone.is_open() and not paused,"actual Tab closing releases only phone pause")
    report.camera_restore={"before_fov":base_fov,"after_fov":world.camera_3d.fov,"before_focus":base_focus,"after_focus":world.camera_rig.position,"after_lookahead":world.camera_aim_offset,"weight":world.phone_camera_weight}
    check(is_equal_approx(world.camera_3d.fov,base_fov) and world.phone_camera_weight==0,"full floor restores original FOV and clears phone modifier")
    world.refresh_phone_camera_presentation(0)
    var ground:Vector2=world._player_ground_anchor_position()
    var expected_focus:Vector3=Vector3(ground.x/32.0,0,ground.y/32.0)+world.camera_aim_offset+world.camera_impulse_offset
    check(world.camera_rig.position.is_equal_approx(expected_focus),"full floor resumes the original live lookahead composition")
    check(not Input.is_action_pressed("move_up"),"still-held W remains quarantined after closing")
    check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not world.player.should_trigger_weapon_attack(),"left held through Tab close cannot fire after gameplay resumes")
    mouse(MOUSE_BUTTON_LEFT,false);await wait_real(.04)
    check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and world.player.get_meta(&"presentation_pointer_gate",Callable())==original_gate,"left release restores the original composed pointer gate")
    mouse(MOUSE_BUTTON_LEFT)
    check(world.player.should_trigger_weapon_attack(),"a fresh left press works after phone quarantine releases")
    mouse(MOUSE_BUTTON_LEFT,false)
    key(KEY_W,false);await wait_real(.08)
    check(not phone._quarantined_keys.has(KEY_W),"W release drains closing quarantine")
    await tap(KEY_ESCAPE)
    check(main.pause_menu.is_open() and not phone.is_open(),"original Esc pause remains available on full floor")
    await tap(KEY_ESCAPE)
    check(not main.pause_menu.is_open() and not paused,"original Esc pause resumes normally")
    await tap(KEY_TAB);await wait_real(.6)
    var pauses:Node=root.get_node("PauseManager")
    pauses.request_pause(&"FULL_DUNGEON_OTHER")
    main._show_bedroom(false)
    check(not phone.is_open() and not pauses.has_pause_reason(&"GAME_PHONE"),"scene transition aborts phone and releases its reason")
    check(pauses.has_pause_reason(&"FULL_DUNGEON_OTHER") and paused,"scene abort preserves an unrelated pause reason")
    check(world.phone_camera_weight==0 and phone.environment_bridge==null,"scene abort clears camera modifier and environment bridge")
    pauses.release_pause(&"FULL_DUNGEON_OTHER")
    deadline=Time.get_ticks_msec()+15000
    while main.transition_running and Time.get_ticks_msec()<deadline:await process_frame
    check(not main.transition_running and main.current_screen.get_node_or_null("PhoneLayer/BedroomPhone")!=null,"actual next bedroom transition completes")
    var events:Array=[]
    var bedroom:Node=main.current_screen
    bedroom.phone.external_story_effect_requested.connect(func(id):events.append(id))
    await tap(KEY_TAB);await wait_real(.6)
    bedroom.phone._play_screen_glitch()
    check(events==[&"phone_message_glitch"],"original story glitch routes to shared phone")
    check(bedroom.get_node("PhoneLayer").get_node_or_null("ScreenGlitch")==null,"external phone glitch leaves no legacy fullscreen overlay")
    phone.abort();await wait_real(.1)
    main.queue_free();await process_frame;await process_frame;await process_frame
    finish()
func finish()->void:
    report.checks=checks;report.failures=failures
    var out:=FileAccess.open(artifact_dir.path_join("results.json"),FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
    print("FULL_DUNGEON_PHONE_CHECKS=",checks," FAILURES=",failures.size())
    quit(0 if failures.is_empty() else 1)
