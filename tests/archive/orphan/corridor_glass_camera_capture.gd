extends SceneTree
var output := "res://.runtime/corpse_corridor_revision_20261014/corridor_after"
var before := false
var main: Node
var world: Node
var samples: Array[Dictionary]=[]
var checks := 0
var failures := 0
var clock := 0.0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=").replace("\\","/")
	before="--glass-before" in OS.get_cmdline_user_args()
	node_added.connect(func(node: Node) -> void:
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/dream/office_skeleton_world_base.gd": node.persist_profile=false; node.native_skeleton_type="V3"
	)
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count := 3) -> void:
	for index in count: await RenderingServer.frame_post_draw
func capture(direction: String) -> void:
	var filename := "frame_%03d.png"%samples.size()
	root.get_texture().get_image().save_png(output+"/"+filename)
	samples.append({"file":filename,"game_seconds":clock,"position":world.player.global_position,"direction":direction,"player_visible":world.player.visual.visible})
func walk(actions: Array[String], expected_distance: float) -> float:
	var start: Vector2=world.player.global_position
	for action in actions: Input.action_press(action)
	for frame in 100:
		await frames(1); clock+=1.0/60.0
		capture("+".join(actions))
		if world.player.global_position.distance_to(start)>=expected_distance: break
	for action in actions: Input.action_release(action)
	await frames(3)
	return world.player.global_position.distance_to(start)
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Real GPU Camera required"); quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main entry completes")
	if failures: quit(1); return
	world.native_skeleton_type="V3"; world.enable_game_start_cab_exit=false
	check(world.regenerate(120),"Formal V3 repro floor generates")
	var data: Dictionary=world.skeleton_source
	var portal: Dictionary={}
	for door in data.doors:
		if "main" in [String(door.a),String(door.b)] and "crosshall" in [String(door.a),String(door.b)] and not bool(door.glass): portal=door; break
	check(not portal.is_empty() and bool(portal.open),"Former blocked corridor endpoint is open")
	if failures: main.free(); quit(1); return
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	var player: Node2D=world.player
	player.invulnerability_left=0.0; player.invulnerability_reason=&""; player.hurt_flash_left=0.0; player.revive_flash_left=0.0
	player.set_attacking_enabled(false); player.movement_enabled=true
	# Rebuild only the original endpoint on this same floor for the before
	# comparison: two middle glass cells and one wall cell at either side.
	if before:
		for slot in range(int(portal.start),int(portal.start)+int(portal.width)):
			var edge := {"axis":"V","x":int(portal.line),"y":slot}
			var key: String=world._edge_key(edge)
			if slot==int(portal.start) or slot==int(portal.start)+int(portal.width)-1:
				world._build_wall_visual(edge,key); world._build_wall_collision(edge,key)
			else:
				var pane=preload("res://scripts/dream/continuous_office_glass.gd").new()
				pane.position=world._edge_world_position(edge); world.wall_root.add_child(pane)
				pane.configure_window(edge,key,world.wall_height,world.wall_thickness,world.collision_root)
	var center_y := (float(portal.start)+float(portal.width-1)*.5)*32.0
	var left := Vector2(float(portal.line-2)*32.0,center_y)
	var right := Vector2(float(portal.line+2)*32.0,center_y)
	check(world._is_blood_ground_allowed(left) and world._is_blood_ground_allowed(right),"Both endpoints are actual connected floor")
	player.global_position=left; player.velocity=Vector2.ZERO
	world.activate_room(world.resolve_environment_debris_room_id(left,world.current_room_id))
	await frames(15)
	root.get_texture().get_image().save_png(output+"/start.png")
	# Formal camera-relative controls: right+up maps onto gameplay +X.
	var forward := await walk(["move_right","move_up"],128.0)
	check(forward<55.0 if before else forward>=128.0,"Old glass blocks forward input" if before else "Real player input crosses former glass endpoint")
	check(player.global_position.x<float(portal.line)*32.0 if before else player.global_position.x>float(portal.line)*32.0,"Forward path really crosses the corridor boundary" if not before else "Original endpoint collision prevents forward crossing")
	if before: player.global_position=right; player.velocity=Vector2.ZERO; await frames(10)
	var backward := await walk(["move_left","move_down"],128.0)
	check(backward<75.0 if before else backward>=128.0,"Old glass blocks reverse input" if before else "Real player input crosses back through endpoint")
	check(samples.all(func(sample: Dictionary) -> bool: return sample.player_visible),"Player remains visible without test invulnerability flashing")
	var report := {"before_reconstructed_original_endpoint":before,"main_entry":true,"formal_seed":120,"skeleton":"V3","portal":portal,"normal_player_input":true,"forward_distance":forward,"backward_distance":backward,"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"gpu":RenderingServer.get_video_adapter_name(),"samples":samples,"checks":checks,"failures":failures,"performance_claim":false}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CORRIDOR_GLASS_CAMERA ",JSON.stringify({"before":before,"forward":forward,"backward":backward,"checks":checks,"failures":failures}))
	main.free(); quit(1 if failures else 0)
