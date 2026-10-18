extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var original: RigidBody2D=load("res://scenes/dream/props/office_chair_01.tscn").instantiate()
	var candidate: RigidBody2D=load("res://scenes/dream/props/office_chair_01.tscn").instantiate()
	original.set_meta(&"test_skip_unchanged_furniture_velocity",false)
	original.position=Vector2(200,200); candidate.position=Vector2(600,200)
	root.add_child(original); root.add_child(candidate)
	for frame in 150: await physics_frame
	check(not original.sleeping,"Original repeatedly reawakens at zero velocity")
	check(candidate.sleeping,"Exact unchanged velocity allows engine sleeping")
	check(original.linear_velocity==candidate.linear_velocity and original.rotation==candidate.rotation,"Resting velocity and rotation unchanged")
	print("FURNITURE_SLEEP_IDLE ",JSON.stringify({"original_sleeping":original.sleeping,"candidate_sleeping":candidate.sleeping,"original_velocity":original.linear_velocity,"candidate_velocity":candidate.linear_velocity}))
	seed(246)
	original.apply_combat_impulse(Vector2.RIGHT,200,original.global_position+Vector2(0,5))
	seed(246)
	candidate.apply_combat_impulse(Vector2.RIGHT,200,candidate.global_position+Vector2(0,5))
	for frame in 20: await physics_frame
	check(not candidate.sleeping,"Real impulse wakes candidate")
	check(original.linear_velocity==candidate.linear_velocity,"Moving impulse velocity exact")
	check(is_equal_approx(original.rotation,candidate.rotation),"Moving impulse rotation exact")
	check(original.seat_rotation==candidate.seat_rotation,"Independent chair-seat rotation exact")
	check((original.position-Vector2(200,200)).is_equal_approx(candidate.position-Vector2(600,200)),"Moving impulse displacement matches")
	original.queue_free(); candidate.queue_free()
	for frame in 4: await process_frame
	print("FURNITURE_SLEEP_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
