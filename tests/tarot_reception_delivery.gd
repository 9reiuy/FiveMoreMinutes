extends SceneTree
var output := "res://.runtime/tarot_reception_20261014/before"
var main: Node
var room: Dream3DReceptionRoom
var samples: Array[Dictionary] = []
var checks := 0
var failures := 0
var clock := 0.0
var validate := false
var recording := false
var record_tick := 0
var revision := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output=arg.trim_prefix("--artifact-dir=")
	validate="--validate" in OS.get_cmdline_user_args()
	revision="--revision" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
		if recording:
			clock+=1.0/60.0; record_tick+=1
			if record_tick%4==0:
				var file: String="frame_%03d.png"%samples.size()
				root.get_texture().get_image().save_png(output+"/"+file)
				samples.append({"file":file,"game_seconds":clock,"player":room.player.global_position})
func capture(label: String) -> void:
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func release_move() -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
func move_to(point: Vector2, npc: bool=false) -> bool:
	for i in 900:
		if npc and room.dialogue_controller.is_active(): release_move(); return true
		var delta: Vector2=point*32-room.player.global_position
		if delta.length()<6: release_move(); return true
		# Use real digital key combinations. Fractional synthetic action strengths
		# below the project's input deadzone silently discard steering corrections.
		var input:=Vector2.ZERO
		var score: float=-INF
		for candidate in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var mapped: Vector2=room.player._camera_relative_movement_input(candidate.normalized())
			var alignment: float=mapped.normalized().dot(delta.normalized())
			if alignment>score: score=alignment; input=candidate
		release_move()
		Input.action_press("move_right" if input.x>0 else "move_left",absf(input.x))
		Input.action_press("move_down" if input.y>0 else "move_up",absf(input.y))
		await frames(1)
	release_move(); return false
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	await frames(3)
	main.persistent_day_state=main._create_initial_state(); main._show_reception("basic")
	for i in 600:
		await frames(1)
		if main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running:
			room=main._supported_dream_world; break
	check(is_instance_valid(room),"Formal Main reception entry completes")
	if room==null: quit(1); return
	var pointer:=InputEventMouseMotion.new()
	pointer.position=root.get_visible_rect().size*.5
	pointer.global_position=pointer.position
	Input.parse_input_event(pointer)
	var camera_fov: float=room.camera_3d.fov
	var requested_palette: bool=root.get_node("SettingsManager").get_palette_enabled()
	if validate:
		check(not bool(main.current_screen.palette_material.get_shader_parameter("palette_enabled")),"Lobby preserves the approved native furniture palette")
		var lobby_doors: Array=[room.elevator_floor_door,room.door_root.get_node("BackgroundElevator2"),room.door_root.get_node("BackgroundElevator3")]
		for i in lobby_doors.size():
			check(lobby_doors[i].industrial_facade.has_node("FreightStructuralFrame"),"Lobby bay uses approved freight facade")
			check(lobby_doors[i].industrial_facade.get_node("FreightNumber").text=="%02d"%(i+1),"Lobby bay retains distinct 01/02/03 numbering")
	await frames(30); capture("entrance")
	var measured_viewport: RID=room.camera_3d.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(measured_viewport,true)
	await frames(30)
	var cpu_render: Array[float]=[]
	var gpu_render: Array[float]=[]
	var draw_calls: Array[int]=[]
	for i in 120:
		await frames(1)
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		cpu_render.append(RenderingServer.viewport_get_measured_render_time_cpu(measured_viewport))
		gpu_render.append(RenderingServer.viewport_get_measured_render_time_gpu(measured_viewport))
	draw_calls.sort()
	cpu_render.sort(); gpu_render.sort()
	var stats := {"draw_calls_median":draw_calls[60],"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"scope":"120 capped rendered frames at entrance, render counters only; not full GPU frame time or combat FPS"}
	stats["cpu_viewport_render_median_ms"]=cpu_render[60] if cpu_render[119]>0 else null
	stats["gpu_viewport_render_median_ms"]=gpu_render[60] if gpu_render[119]>0 else null
	stats["gpu_viewport_render_p99_ms"]=gpu_render[118] if gpu_render[119]>0 else null
	stats["world_viewport_size"]=room.camera_3d.get_viewport().get_visible_rect().size
	stats["timer_scope"]="RenderingServer viewport timers only; excludes gameplay CPU, root composition and frame cap. Null means unavailable."
	room.player.global_position=Vector2(float(room.MAIN_HALL_WIDTH)*.5-0.5,float(room.MAIN_HALL_HEIGHT)*.5)*32
	await frames(30); capture("hall")
	if revision:
		room.set_process(false)
		var center: Vector2=room.camera_3d.unproject_position(room.to_global(Vector3(11,0,10.5)))
		var region:=Rect2i(Vector2i(center)-Vector2i(4,4),Vector2i(8,8))
		main.current_screen.set_palette_enabled(false); await frames(4)
		capture("palette_off")
		var before: PackedByteArray=room.camera_3d.get_viewport().get_texture().get_image().get_region(region).get_data()
		main.current_screen.set_palette_enabled(true); await frames(4)
		capture("palette_on")
		var after: PackedByteArray=room.camera_3d.get_viewport().get_texture().get_image().get_region(region).get_data()
		check(before==after,"Rendered marble floor remains identical when palette toggles")
		check(not bool(main.current_screen.palette_material.get_shader_parameter("palette_enabled")),"Palette ON request cannot recolour this lobby")
		main.current_screen.set_palette_enabled(requested_palette)
		room.set_process(true)
	room.player.global_position=room.RECEPTION_DESK_POS_2D+Vector2(0,45)
	await frames(30); capture("desk")
	room.dialogue_controller.dismiss_if_active()
	room._tween_dialogue_camera_weight(0,0)
	room.player.global_position=room.ELEVATOR_POS_2D+Vector2(0,80)
	await frames(30); capture("elevators")
	if validate:
		room.player.global_position=room.PLAYER_SPAWN
		room.waitress_approached_this_session=false
		room.dialogue_controller.dismiss_if_active(); await frames(30)
		recording=true
		for point in [Vector2(12.5,7.2),Vector2(4.8,7.2),Vector2(4.8,8.7),Vector2(4.8,7.2),Vector2(12.5,7.2)]:
			check(await move_to(point),"Ordinary movement reaches lobby waypoint "+str(point))
		capture("lounge")
		check(await move_to(Vector2(16,5)),"Walk to passive left counter")
		check(not room.dialogue_controller.is_active(),"Passive NPC only hints on approach")
		Input.action_press("pickup_weapon"); await frames(2); Input.action_release("pickup_weapon")
		await frames(60); capture("dialogue")
		check(room.dialogue_controller.is_active() and not room.dialogue_bubble.options_container.visible,"E opens growing dialogue without options")
		var cancel:=InputEventAction.new(); cancel.action="ui_cancel"; cancel.pressed=true
		Input.parse_input_event(cancel); await frames(2)
		cancel=InputEventAction.new(); cancel.action="ui_cancel"; cancel.pressed=false; Input.parse_input_event(cancel)
		await frames(20)
		check(not room.tarot_overlay.visible and not room.tarot_visit_state.selected,"Closing dialogue does not draw or select tarot")
		
		for point in [Vector2(12.5,5.5),Vector2(3.5,5.5),Vector2(3.5,1.3)]:
			check(await move_to(point),"Ordinary movement reaches elevator waypoint "+str(point))
		capture("elevator_ready")
		check(room.elevator_approach_active,"Only functional elevator offers entry prompt")
		recording=false
		Input.action_press("pickup_weapon"); await frames(2); Input.action_release("pickup_weapon")
		var opened:=false
		var closed:=false
		for i in 1200:
			await frames(1)
			if revision and is_instance_valid(room):
				if not opened and room.elevator_floor_door.current_state==ElevatorFloorDoor3D.State.OPEN:
					capture("lobby_elevator_open"); opened=true
				if opened and not closed and room.elevator_floor_door.current_state==ElevatorFloorDoor3D.State.CLOSED:
					capture("lobby_elevator_closed"); closed=true
			if is_instance_valid(main._supported_dream_world) and not main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running: break
		check(is_instance_valid(main._supported_dream_world) and not main._supported_dream_world is Dream3DReceptionRoom,"Existing elevator enters the actual formal game floor")
		check(bool(main.current_screen.palette_material.get_shader_parameter("palette_enabled"))==requested_palette,"Formal floor still follows the user's palette setting")
		capture("floor_entry")
		if revision:
			check(opened and closed,"Actual lobby entry records new door open and closed states")
			var floor_world: Node3D=main._supported_dream_world
			var entry: Dictionary=floor_world.rooms[floor_world.elevator_room_id]
			var floor_art: Node=floor_world.office_art_root.get_node("ApprovedOfficeArt").floors
			var material: Material=floor_art.floor_material(entry)
			var found:=false
			for mesh in floor_world.floor_root.get_children():
				if not mesh is MeshInstance3D: continue
				for surface in mesh.mesh.get_surface_count():
					if mesh.mesh.surface_get_material(surface)==material: found=true
			check(found,"Actual formal reception displays the final approved floor material")
			var environment: Environment=floor_world.get_node("Lighting/WorldEnvironment").environment
			check(is_equal_approx(environment.ambient_light_energy,.38) and is_equal_approx(floor_world.get_node("Lighting/KeyLight").light_energy,.025),"Lobby night baseline matches the actual formal floor")
			floor_world.player.global_position=Vector2(entry.center_cell)*32
			await frames(30); capture("floor_reception_palette")
			main.current_screen.set_palette_enabled(false); await frames(10); capture("floor_reception_native")
			var door: Node3D=floor_world.elevator_floor_door
			check(door.industrial_facade.has_node("FreightStructuralFrame"),"Formal floor uses the same approved freight facade")
			floor_world.player.global_position=door.get_corridor_approach_position_2d()-door.get_inward_2d()*32
			await frames(30)
			# Diagnostic translation only: retain the real gameplay camera angle,
			# projection and FOV while centering the authored door, outside live
			# transition/dialogue focus overrides. Main input flow is tested above.
			floor_world.set_process(false)
			floor_world.camera_rig.global_position=door.global_position
			await frames(4); capture("floor_elevator_closed")
			await door.open_doors(.2); await frames(4); capture("floor_elevator_open")
			check(door.doors_open,"Formal door opens with industrial panels attached")
			await door.close_doors(.2); await frames(4)
			floor_world.set_process(true)
			main.current_screen.set_palette_enabled(requested_palette)
	var report := {"main_entry":true,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"resolution":[1920,1080],"camera_fov":camera_fov,"stats":stats,"checks":checks,"failures":failures,"samples":samples,"requested_palette":requested_palette,"ui_validation":"ordinary movement input; passive NPC E interaction and Esc dismissal without tarot; elevator E input"}
	var file=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RECEPTION_DELIVERY checks=",checks," failures=",failures)
	main.free(); quit(1 if failures else 0)

