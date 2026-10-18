extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String, player: Node2D, supplied_bridge: Node3D = null) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/default_fists_"+name+".png")
	var bridge = supplied_bridge
	if bridge == null:
		var reference: WeakRef = player.get_meta(&"depth_visual_bridge",null)
		if reference == null:
			failures+=1
			return
		bridge = reference.get_ref()
	var copied := false
	for copy in bridge.clone_roots:
		var left = copy.get_node_or_null("BodyPivot/LeftHand")
		var right = copy.get_node_or_null("BodyPivot/RightHand")
		if left!=null and right!=null:
			copied = left.visible and right.visible and left.position==player.left_hand_part.position and right.position==player.right_hand_part.position
	if not copied: failures+=1
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.approved_sample_art_enabled = false
	world.enable_game_start_cab_exit = false
	world.persist_profile = false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	world.regenerate(42001)
	await frames(20)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.equip_weapon("",world.config)
	world.interaction_prompt.dismiss(true)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		world.player.set_meta("aim_direction_override",direction)
		world.player._update_direction_animation(Vector2.ZERO,1.0/60)
		world._update_camera_and_actor_projection()
		await shot("floor_"+str(direction),world.player)
	world.transition_phase = &"CAB_RIDE"
	world._set_building_exterior_visible(false)
	world.active_transition_cab = IndependentElevatorCab3D.new(world.floor_index)
	world.add_child(world.active_transition_cab)
	world.active_transition_cab.position = Vector3(0,0,-100)
	world.active_transition_cab.global_rotation = Vector3.ZERO
	world.active_transition_cab.setup_gameplay_boundaries(world.gameplay_canvas.get_node("GameplayWorld"),Vector2(0,-3200))
	world.player.global_position = world.active_transition_cab.get_player_initial_position_2d()
	world.player.set_attacking_enabled(false)
	world.player.set_meta("aim_direction_override",Vector2.DOWN)
	world.player._update_direction_animation(Vector2.ZERO,1.0/60)
	world.camera_aim_offset = Vector3.ZERO
	for i in 90: world._update_camera_and_actor_projection()
	await shot("cabin",world.player)
	display.queue_free()
	await frames(6)
	var room = load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	var reception_display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	reception_display.world = room
	reception_display.preview_mode = false
	root.add_child(reception_display)
	await frames(30)
	room.set_process(false)
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	room.player.equip_weapon("",load("res://resources/demo_config.tres"))
	room.player.set_meta("aim_direction_override",Vector2.DOWN)
	room.player._update_direction_animation(Vector2.ZERO,1.0/60)
	room.dialogue_bubble.hide()
	room.interaction_prompt.dismiss(true)
	for i in 25: room._update_camera_and_projection(0.1)
	await shot("reception",room.player,room.player_depth_bridge)
	reception_display.queue_free()
	await frames(6)
	print("DEFAULT_FISTS_GPU failures=",failures)
	quit(1 if failures else 0)
