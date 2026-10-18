extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func snapshot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/bangs_"+name+".png")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false
	world.approved_sample_art_enabled=false
	world.enable_game_start_cab_exit=false
	world.persist_profile=false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world
	display.preview_mode=false
	root.add_child(display)
	world.regenerate(42001)
	world.transition_phase=&"IDLE"
	world.player.invulnerability_left=0
	world.player.movement_enabled=true
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(20)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.interaction_prompt.dismiss(true)
	var hair = world.player.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	hair.set_physics_process(false)
	for dir in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		world.player.set_meta("aim_direction_override",dir)
		world.player._update_direction_animation(Vector2.ZERO,1.0/60)
		for i in 90: hair.step(1.0/60,Vector2.ZERO,dir.angle(),world.player.character_facing_right,world.player.character_facing_back,false,false)
		world._update_camera_and_actor_projection()
		await snapshot("direction_"+str(dir.x)+"_"+str(dir.y))
	world.player.set_meta("aim_direction_override",Vector2.LEFT)
	world.player._update_direction_animation(Vector2.LEFT,1.0/60)
	for i in 18: hair.step(1.0/60,Vector2(290,0),PI,false,false,false,false)
	await snapshot("moving")
	for i in 12: hair.step(1.0/60,Vector2.ZERO,PI,false,false,false,false)
	await snapshot("stopping")
	for i in 120: hair.step(1.0/60,Vector2(290,0),PI,false,false,false,false)
	print("SIDE_BANGS_NORMAL_DEGREES=",rad_to_deg(hair.bend))
	await snapshot("135_normal")
	for i in 120: hair.step(1.0/60,Vector2(5000,0),PI,false,false,false,false)
	await snapshot("135_left_limit")
	for i in 120: hair.step(1.0/60,Vector2(-5000,0),PI,false,false,false,false)
	await snapshot("135_right_limit")
	# Capture the actual source visual at integer zoom for pixel attachment review.
	var closeup := SubViewport.new()
	closeup.size=Vector2i(128,128)
	closeup.transparent_bg=true
	closeup.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(closeup)
	var copy = world.player.visual.duplicate(0)
	copy.position=Vector2(64,108)
	copy.scale=Vector2(2,2)
	copy.visible=true
	copy.modulate=Color.WHITE
	copy.process_mode=Node.PROCESS_MODE_DISABLED
	closeup.add_child(copy)
	await frames(6)
	await RenderingServer.frame_post_draw
	closeup.get_texture().get_image().save_png("res://.runtime/bangs_attachment.png")
	closeup.queue_free()
	display.queue_free()
	await frames(5)
	print("SIDE_BANGS_GPU_DONE")
	quit()
