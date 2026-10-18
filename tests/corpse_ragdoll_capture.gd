extends SceneTree
var world: Node3D
var enemy: EmployeeEnemy
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/corpse_ragdoll_"+label+".png")
	if enemy.dead:
		var reference: WeakRef = enemy.get_meta(&"depth_visual_bridge")
		var bridge: Node3D = reference.get_ref()
		var lowest: float = bridge.lowest_visible_pixel
		var viewport: SubViewport = bridge.render_viewport
		var up_y: float = world.camera_3d.global_basis.orthonormalized().y.y
		var bottom: float = bridge.actor_sprite.global_position.y-up_y*(lowest+bridge.viewport_offset.y-float(viewport.size.y)*0.5)/32.0
		print("CORPSE_GPU_BOTTOM ",label,"=",bottom)
		if lowest>0 and bottom < -0.01: failures+=1
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.approved_sample_art_enabled = false
	world.enable_game_start_cab_exit = false
	world.persist_profile = false
	world.spawn_content = false
	var display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	world.regenerate(42001)
	world.transition_phase = &"IDLE"
	world.player.set_physics_process(false)
	await frames(20)
	world.set_process(false)
	world.set_physics_process(false)
	world.interaction_prompt.dismiss(true)
	var start: Vector2 = world.player.global_position+Vector2(30,-20)
	enemy = world._spawn_regular_employee(world.current_room_id,start,&"employee",false,"luger")
	enemy.set_process(false)
	enemy.set_physics_process(false)
	await frames(6)
	await snapshot("before")
	enemy.take_damage(999,Vector2.RIGHT,100,&"rifle")
	enemy.set_process(false)
	for i in 150:
		enemy._update_death_presentation(1.0/60)
		world._update_camera_and_actor_projection()
		await frames(1)
		if i==10: await snapshot("falling")
		if i==100: await snapshot("landed")
	if not enemy.death_landed or enemy.knockdown_height!=0: failures+=1
	var before_push := enemy.global_position
	var sensor = enemy.corpse_contact
	sensor._physics_process(1.0/60)
	world.player.global_position = sensor.global_position-Vector2(12,0)
	world.player.velocity = Vector2(290,0)
	# Real Area2D contacts, not direct calls to the corpse impulse method.
	for i in 40:
		world.player.global_position += Vector2(1.8,0)
		enemy._update_death_presentation(1.0/60)
		world._update_camera_and_actor_projection()
		await physics_frame
		await frames(1)
	world.player.velocity = Vector2.ZERO
	world.player.global_position -= Vector2(30,0)
	await snapshot("pushed")
	print("CORPSE_GPU_PLAYER_DISPLACEMENT=",enemy.global_position.distance_to(before_push))
	if enemy.global_position.distance_to(before_push)<0.5: failures+=1
	for i in 180:
		enemy._update_death_presentation(1.0/60)
		world._update_camera_and_actor_projection()
		await frames(1)
	await snapshot("settled")
	if enemy.ragdoll_active: failures+=1
	display.queue_free()
	await frames(6)
	print("CORPSE_RAGDOLL_GPU failures=",failures)
	quit(1 if failures else 0)
