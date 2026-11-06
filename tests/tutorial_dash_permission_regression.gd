extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var arena:=Node2D.new(); root.add_child(arena)
	var player=load("res://scenes/entities/dream_player.tscn").instantiate(); arena.add_child(player)
	player.set_dash_enabled(false)
	var callback:=func():
		if is_instance_valid(player): player.set_dash_enabled(false)
	process_frame.connect(callback)
	Input.action_press("move_right")
	var start:=Vector2.ZERO
	for tick in 90:
		await physics_frame
		await process_frame
		if tick==44: start=player.position
	var speed: float=player.position.distance_to(start)/(.75)
	var expected: float=player.movement_speed
	print("REPEATED_DISABLED_DASH measured_px_s=",speed," expected_px_s=",expected)
	check(speed>expected*.85,"repeated disabled-dash permissions do not reset actual locomotion acceleration")
	check(player.get_time_locomotion_speed()>expected*.85,"DreamTime locomotion sample stays at the real running speed")
	Input.action_release("move_right"); process_frame.disconnect(callback)
	arena.queue_free(); await process_frame; await process_frame
	quit(1 if failures else 0)

