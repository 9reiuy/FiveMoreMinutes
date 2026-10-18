extends SceneTree

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	var world := SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	_check(world.regenerate(42001), "Initial floor generated")
	await _frames(2)
	_check(world.active_transition_cab == null, "Floor contains only the wall-flush elevator door")
	_check(world.elevator_floor_door != null, "Floor elevator door exists")
	world.player_has_left_elevator_cab = true
	world.has_floor_badge = true
	world.player.global_position = world.elevator_floor_door.get_corridor_approach_position_2d()
	world._on_elevator_approach_entered(world.player)
	_check(world.transition_phase == &"ENTERING", "Badge starts scripted entry")
	var reached_cab := false
	var deadline:=Time.get_ticks_msec()+20000
	var loading_seen:=false
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if world.transition_phase==&"LOADING" and root.has_node("ElevatorLoadingCover"):
			loading_seen=true
			_check(paused and not world.player.movement_enabled,"Loading is covered and player frozen")
		if world.transition_phase == &"CAB_RIDE" and not paused:
			reached_cab = true
			break
	_check(reached_cab, "Player reaches independent loading cab")
	_check(loading_seen,"Heavy generation happens in a separate black loading phase")
	var ride_start:=Time.get_ticks_msec()
	var actual_pause_ms:=0
	if reached_cab:
		var cab: IndependentElevatorCab3D = world.active_transition_cab
		_check(cab != null, "Loading cab exists during ride")
		_check(absf(cab.global_rotation.y) < 0.001, "Loading cab stays screen-aligned")
		_check(cab.boundary_root_2d != null, "Rotated gameplay boundary follows cab")
		_check(world.player.movement_enabled and world._next_floor_render_ready, "Player can move after floor completely prepared")
		_check(not world.wall_root.visible, "Old floor hidden during ride")
		paused=true
		var pause_start:=Time.get_ticks_msec()
		await create_timer(.2,true).timeout
		actual_pause_ms=Time.get_ticks_msec()-pause_start
		_check(world.transition_phase==&"CAB_RIDE","Pause does not advance ready-cab ride timer")
		paused=false
	var completed := false
	deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if ride_start>0 and world.transition_phase!=&"CAB_RIDE":
			var visible_ms:=Time.get_ticks_msec()-ride_start
			print("CAB_RIDE_DURATION ",JSON.stringify({"visible_ms":visible_ms,"actual_pause_ms":actual_pause_ms}))
			_check(visible_ms-actual_pause_ms>=2990,"Visible cab lasts at least three unpaused seconds")
			ride_start=0
		if world.floor_index == 1 and world.transition_phase == &"IDLE":
			completed = true
			break
	_check(completed, "Arrival and exit complete")
	_check(world.active_transition_cab == null, "Cab removed after floor exit")
	_check(world.floor_index == 1, "Next floor loaded")
	_check(world.elevator_floor_door != null and not world.elevator_floor_door.doors_open, "New floor door closes after exit")
	_check(world.player.movement_enabled, "Player regains movement on new floor")
	_check(not paused and not root.has_node("ElevatorLoadingCover") and world._cab_suspended_floor_state.is_empty(),"No cover, global pause or suspended floor survives exit")
	# Exercise the real covered transaction's failure path, not just the pure
	# generator rollback. The previous floor and its objects must survive.
	var marker:=Node2D.new(); marker.name="RetainedOldFloorMarker"
	world.world_effects_root.add_child(marker)
	var cells: Dictionary=world.floor_cells.duplicate()
	world.max_layout_attempts=0
	world.has_floor_badge=true
	world._begin_elevator_entry_transition()
	deadline=Time.get_ticks_msec()+15000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	_check(world.floor_index==1 and world.floor_cells==cells and is_instance_valid(marker) and marker.get_parent()==world.world_effects_root,"Covered generation failure restores exact old floor and effects")
	_check(not paused and not root.has_node("ElevatorLoadingCover") and world.active_transition_cab==null,"Failed transition releases cab, cover and global pause")
	_check(world.player.movement_enabled and world.player.dash_enabled and not world.floor_transition_in_progress,"Failed loading restores player control")
	world.queue_free()
	await _frames(3)
	print("ELEVATOR_ANIMATION_FLOW failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
