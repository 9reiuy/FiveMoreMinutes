extends SceneTree
const OUTPUT := "res://.runtime/exterior_destruction_20261022"
var main: Node
var captures := 0
func _init() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	captures += 1
func run() -> void:
	var diag := root.get_node_or_null("_DroneGameDiag")
	if diag != null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var pixel := not "--native" in OS.get_cmdline_user_args()
	var palette := not "--palette-off" in OS.get_cmdline_user_args()
	var output := OUTPUT+("/pixel" if pixel else "/native")+("_palette" if palette else "_original")
	output += "/fracture_v2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("SettingsManager").set_palette_enabled(palette)
	root.get_node("SettingsManager").set_setting(&"pixelation_enabled",pixel)
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	seed(120)
	main._show_dream("basic")
	await ready_main()
	var world: Node = main._supported_dream_world
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false); enemy.set_process(false)
	var pane: Node3D
	var best := -INF
	var facing := Vector2(world.camera_3d.global_basis.z.x,world.camera_3d.global_basis.z.z)
	for candidate in world.wall_root.find_children("ExteriorBreakablePane","",true,false):
		var inward: Vector2 = world._window_inward_normal(candidate.edge_data)
		# Far-facing facade remains visible under the normal cutaway policy.
		var cost := facing.dot(inward)
		if cost>best:
			best = cost
			pane = candidate
	if pane==null: main.free(); quit(2); return
	var center: Vector2 = world._edge_gameplay_position(pane.edge_data)
	var inward: Vector2 = world._window_inward_normal(pane.edge_data)
	world.player.set_physics_process(false)
	world.player.global_position = center+inward*72
	await frames(40)
	await shot(output+"/01_intact.png")
	pane.collision_body_2d.take_damage(40,-inward)
	await frames(5)
	await shot(output+"/02_cracked.png")
	pane.collision_body_2d.take_damage(60,-inward)
	for i in 65:
		await process_frame
		if i in [0,5,12,20,28,40,64]: await shot(output+"/glass_%02d.png" % i)
	var door: PhysicalDoor3D
	var door_effect_ok := false
	for candidate in world.door_root.get_children():
		if candidate is PhysicalDoor3D and not candidate.locked:
			door=candidate; break
	if door!=null:
		var door_center := door.get_leaf_center_2d(0)
		var normal := Vector2(door.basis.z.x,door.basis.z.z).normalized()
		world.player.global_position = door_center-normal*72
		await frames(35)
		await shot(output+"/door_closed.png")
		door.take_damage(200,normal)
		for burst in get_nodes_in_group(&"persistent_destruction_debris"):
			if burst.get_parent()==world.floor_root and burst.pieces.size()>=6: door_effect_ok=true
		for i in 65:
			await process_frame
			if i in [0,5,12,20,28,40,64]: await shot(output+"/door_%02d.png" % i)
	# Real collision/input probe: walk normally through this broken cell.
	world.player.global_position = center+inward*22
	world.player.movement_enabled = true
	world.player.attacking_enabled = true
	world.player.set_physics_process(true)
	var projected: Vector2 = world.player._camera_relative_movement_input(Vector2.RIGHT)
	var other: Vector2 = world.player._camera_relative_movement_input(Vector2.DOWN)
	var screen := Vector2((-inward).dot(projected),(-inward).dot(other))
	Input.action_press("move_right" if screen.x>=0 else "move_left",absf(screen.x))
	Input.action_press("move_down" if screen.y>=0 else "move_up",absf(screen.y))
	var fell := false
	for i in 80:
		await process_frame
		if world.player.get_meta(&"exterior_falling",false):
			if not fell: await shot(output+"/05_player_falling.png")
			fell = true
		if world.player.dead: break
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	var died: bool = world.player.dead
	print("EXTERIOR_CAMERA pixel=",pixel," palette=",palette," captures=",captures," door_fracture=",door_effect_ok," walking_fall=",fell," player_dead=",died," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(0 if fell and died and door_effect_ok else 1)
