extends SceneTree
## Real production display, physics walking, optional branch and linked retirement.
const EGG := preload("res://scripts/testing/level01_easter_layout.gd")
var display: Control
var world: Node3D
var player: CharacterBody2D
var output := ""
var checks := 0
var failures: Array[String] = []
var frames: Array[float] = []
var previous := 0


func _initialize() -> void: call_deferred("run")


func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title)
	print("PASS " if ok else "FAIL ",title)


func ticks(count: int) -> void:
	for frame in count: await physics_frame


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if previous > 0: frames.append((now-previous)/1000.0)
	previous = now
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
	return false


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = display.world_viewport.get_texture().get_image()
	check(picture != null and picture.save_png(output.path_join(label+".png")) == OK,"Actual Camera "+label)


func pose(at: Vector2) -> void:
	player.global_position = at*32.0
	player.velocity = Vector2.ZERO
	await ticks(12)


func hold(direction: Vector2) -> void:
	var basis := Transform2D(player._camera_relative_movement_input(Vector2.RIGHT),player._camera_relative_movement_input(Vector2.DOWN),Vector2.ZERO)
	var screen := basis.affine_inverse().basis_xform(direction.normalized())
	for item in [["move_right",screen.x],["move_left",-screen.x],["move_down",screen.y],["move_up",-screen.y]]:
		if item[1] > .02: Input.action_press(item[0],item[1])
		else: Input.action_release(item[0])


func release() -> void:
	for action in ["move_right","move_left","move_down","move_up"]: Input.action_release(action)


func run() -> void:
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	display = load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	player = world.player
	player.dash_invulnerability_left = 600.0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		process_frame.connect(func(): RenderingServer.force_draw(false))
	await ticks(15)
	check(world._validate_layout().valid,"The extended linked floor remains connected and valid")
	check(EGG.WALK_LENGTH == 152 and EGG.MAIN_LENGTH == 38,"The reveal is four original level lengths west")
	check(world.rooms.size() == 8 and world.rooms[0].center_cell.x > 0,"Original rooms and encounter anchors stay in place")
	check(player.selected_weapon_id == "books" and is_instance_valid(world.opening_projectile),"The actual 0-1 opening and poster are preserved")
	var egg: Node3D = world.floor_root.get_node("WestEasterEgg")
	check(not egg.display.visible and egg.fire.particles.is_empty(),"The remote display and fire are inactive during ordinary 0-1 play")
	check(world.collision_root.get_node_or_null("LeftBoundary") == null,"The left black gradient has no invisible end wall")
	await capture("01_original_entry")
	for enemy: EmployeeEnemy in world.enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1)) < world.GARAGE_ROOM_ID and not enemy.dead:
			enemy.take_damage(enemy.maximum_health+100.0,player.global_position,0.0,&"easter_validation")
	await ticks(20)
	await pose(Vector2(1.0,6.0))
	hold(Vector2.LEFT)
	for frame in 140:
		if player.global_position.x < -1.5*32.0: break
		await physics_frame
	release()
	check(player.global_position.x < -1.5*32.0,"Player physically walks through the existing left gradient")
	await pose(Vector2(-38,6.0))
	check(not egg.display.visible,"One map length into the hidden branch is still black")
	await capture("02_black_path")
	# Traverse the complete remaining route using ordinary player movement.
	hold(Vector2.LEFT)
	var travel_start := Time.get_ticks_msec()
	for frame in 2800:
		if player.global_position.x < (EGG.CAR_AT.x+4.6)*32.0: break
		await physics_frame
	release()
	await ticks(12)
	check(player.global_position.x < (EGG.CAR_AT.x+4.6)*32.0,"Unmodified player movement reaches the car along the long route")
	check(egg.display.visible and egg.spotlight.is_visible_in_tree() and egg.spotlight.shadow_enabled,"The stainless car is revealed under its real shadowed spotlight")
	check(egg.fire.fires.size() == 6 and not egg.fire.particles.is_empty(),"Two persistent burning tyre trails emit production fire and smoke")
	check(egg.car.get_node("StainlessWedgeCoupe").mesh.get_surface_count() >= 6,"The car has distinct steel, glass, rubber, alloy and lamp surfaces")
	await pose(EGG.CAR_AT+Vector2(3.8,2.2))
	await capture("03_spotlit_dmc12")
	await pose(EGG.CAR_AT+Vector2(-3.7,3.3))
	await capture("04_rear_fire_trails")
	var query := PhysicsRayQueryParameters2D.create((EGG.CAR_AT+Vector2(0,3))*32.0,(EGG.CAR_AT+Vector2(0,-3))*32.0,4)
	check(not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"The parked car has a solid gameplay footprint")
	await pose(Vector2(1.0,6.0))
	check(not egg.display.visible and egg.fire.fires.is_empty(),"Returning to the main route stops hidden fire work")
	var old: WeakRef = weakref(egg)
	await pose(Vector2(41.36,5.5))
	await ticks(80)
	check(world.garage_visible and old.get_ref() == null,"Entering 0-2 unloads the entire optional branch")
	world.regenerate(world.seed)
	await ticks(25)
	check(world.floor_root.find_children("WestEasterEgg","Node3D",false,false).size() == 1,"Restart creates exactly one fresh Easter egg")
	display.free()
	await ticks(8)
	display = load("res://scenes/testing/MegastructureWhiteboxDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	player = world.player
	await ticks(15)
	check(world.rooms.size() == 3 and world._validate_layout().valid,"The normal standalone 0-1 entry also includes a valid hidden branch")
	await pose(EGG.CAR_AT+Vector2(3.8,2.2))
	await capture("05_standalone_car")
	frames.sort()
	var timing := {}
	for value in [.5,.95,.99,1.0]: timing[str(value)] = frames[clampi(ceili(frames.size()*value)-1,0,frames.size()-1)]
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frame_ms_percentiles":timing,"frames":frames.size(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"travel_sample_ms":Time.get_ticks_msec()-travel_start,"scope":"Source-engine optional-branch walking and lifecycle; includes loads and Camera readback, not whole-game performance certification"},"\t"))
	print("EASTER_EGG checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
