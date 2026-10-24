extends "res://tests/phone_tab_delivery.gd"

func hold_keys(label:String,codes:Array)->void:
	for code in codes:key(code)
	await wait(.18);await shot(label)
	evidence[label]=phone.shell.get_feedback_state()
	for code in codes:key(code,false)
	await wait(.30)

func run()->void:
	var isolated_root:=ProjectSettings.globalize_path("res://.runtime/").replace("\\","/").simplify_path()+"/"
	if not OS.get_user_data_dir().replace("\\","/").simplify_path().begins_with(isolated_root):
		push_error("Use isolated phone_key_clearance_20261019 APPDATA");quit(2);return
	output="res://.runtime/phone_key_clearance_20261019/camera"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	if not ProjectSettings.globalize_path(output).replace("\\","/").simplify_path().begins_with(isolated_root):
		push_error("Camera artifacts must stay in project .runtime");quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.persistent_day_state=main._create_initial_state();main._show_bedroom(false);await ready_main()
	phone=main.game_phone;await tap(KEY_TAB);await settled();await shot("idle")
	begin("directional_clearance")
	await hold_keys("right",[KEY_D])
	await hold_keys("upper_right",[KEY_D,KEY_W])
	await hold_keys("lower_right",[KEY_D,KEY_S])
	await hold_keys("upper_left",[KEY_A,KEY_W])
	await hold_keys("lower_left",[KEY_A,KEY_S]);finish()
	check(phone.active,"All directional and diagonal input preserves the actual phone session")
	begin("buttons_and_labels")
	key(KEY_Q);await wait(.18);await shot("left_softkey")
	key(KEY_Q,false);await wait(.30)
	key(KEY_E);await wait(.18);await shot("centre")
	# Keep the centre depressed while the directional ring tilts.
	key(KEY_D);key(KEY_W);await wait(.15);await shot("centre_and_ring")
	key(KEY_D,false);key(KEY_W,false);key(KEY_E,false);await wait(.30)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=Vector2(430,270);event.pressed=true
	root.push_input(event,true);await wait(.18);await shot("right_softkey")
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await wait(.30)
	check(phone.active and phone.backdrop.color.a==0,"Existing phone state and undimmed background remain intact")
	await back();await tap(KEY_TAB);await settled();finish()
	check(not phone.is_open() and not paused,"Closing restores normal bedroom interactions")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Actual GPU window stays minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"evidence":evidence,"scope":"Actual Main bedroom entry, real input and original phone Camera: directional/diagonal/centre/softkey maximum poses","gpu":RenderingServer.get_video_adapter_name()}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHONE_KEY_CLEARANCE_GPU ",checks," checks ",failures.size()," failures")
	main.free();quit(1 if not failures.is_empty() else 0)
