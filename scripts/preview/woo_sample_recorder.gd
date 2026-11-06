extends "res://scripts/testing/lab_recorder.gd"
## Wall intervals need no synchronous render-server queries. A measurement
## instrument must not flush a separate render thread on every sampled frame.
func begin(config: Dictionary) -> void:
	super.begin(config)
	metadata["measurement"] = "All adjacent process-frame wall intervals and pre/post-draw wall spans. No render-server timing/info queries during sampling; unavailable render counters are -1. First effects and every spike retained."

func frame(world: Node3D) -> void:
	if not active or not is_instance_valid(world): return
	var now := Time.get_ticks_usec()
	if previous_usec != 0 and rows.size() < MAX_FRAMES:
		rows.append([Engine.get_process_frames(), (now-start_usec)/1000000.0, (now-previous_usec)/1000.0, draw_ms, physics_steps, -1, -1.0, -1.0, float(world.lab_cutout_usec)/1000.0, int(world.player.dead), int(world.current_room_id)])
	previous_usec = now
	physics_steps = 0
	world.lab_cutout_usec = 0
