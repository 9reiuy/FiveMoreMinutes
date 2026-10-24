extends SceneTree
var main: Node
const OUTPUT := "res://.runtime/door_hinge_20261022"
func _init() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func run() -> void:
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	var output := OUTPUT+("/before" if legacy else "/after")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("SettingsManager").set_palette_enabled(true)
	root.get_node("SettingsManager").set_setting(&"pixelation_enabled",true)
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
	world.player.set_physics_process(false)
	world.spawn_content = false
	world.floor_transition_in_progress = true
	world.transition_phase = &"CAB_RIDE"
	if not await world._regenerate_staged(42002,1,world.transition_generation_token):
		main.free(); quit(2); return
	var door: PhysicalDoor3D
	for node in world.door_root.get_children():
		if node is PhysicalDoor3D and not node.locked:
			door = node
			break
	if door==null: main.free(); quit(2); return
	if legacy:
		# Reproduce the old suspend policy in this owned test world only.
		for body in door._anchors+door._leaves:
			body.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
	world._set_floor_runtime_suspended_for_cab(true)
	await frames(5)
	world._set_floor_runtime_suspended_for_cab(false)
	world._set_building_exterior_visible(true)
	world.floor_transition_in_progress = false
	world.transition_phase = &"IDLE"
	var center := door.get_leaf_center_2d(0)
	var normal := Vector2(door.basis.z.x,door.basis.z.z).normalized()
	world.player.global_position = center-normal*80.0
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/closed.png")
	var leaf := door.left_leaf
	var edge := Vector3(door.leaf_width*.5,0,0)
	var hinge := door.left_anchor.global_position
	var accepted := door.apply_door_impact(&"player_push",leaf.global_position,door.global_basis.z,260.0,&"",0)
	var drift := 0.0
	for i in 48:
		await physics_frame
		await process_frame
		drift = maxf(drift,(leaf.global_transform*edge).distance_to(hinge))
		if i in [5,15,25,35,47]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/swing_%02d.png" % i)
	print("DOOR_HINGE_LIVE legacy=",legacy," accepted=",accepted," edge_drift=",drift," gpu=",RenderingServer.get_video_adapter_name())
	var ok := accepted and (drift>.2 if legacy else drift<.025)
	if not legacy:
		var close_drift := 0.0
		var returned := false
		for i in 600:
			await physics_frame
			await process_frame
			close_drift = maxf(close_drift, (leaf.global_transform*edge).distance_to(hinge))
			if i in [60,180,300]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/return_%03d.png" % i)
			if door.latched:
				returned = true
				break
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/returned.png")
		var collision_error := door._collision_bodies[0].global_position.distance_to(door.get_leaf_center_2d(0))
		print("DOOR_RETURN_LIVE latched=",returned," edge_drift=",close_drift," angle=",door.get_open_angle()," collision_error=",collision_error)
		ok = ok and returned and close_drift<.025 and collision_error<.02
	main.free()
	await frames(5)
	quit(0 if ok else 1)
