extends SceneTree
const DOOR = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var door: PhysicalDoor3D = DOOR.instantiate()
	for rate in [30,60,120]:
		for direction in [-1.0,1.0]:
			var angle: float = deg_to_rad(85.0)*direction
			var omega := 0.0
			var peak := 0.0
			for frame in rate*10:
				omega = door._return_angular_velocity(angle,omega,1.0/rate)
				angle += omega/rate
				peak=maxf(peak,absf(omega))
			check(absf(angle)<deg_to_rad(2.0),"Return converges from either opening direction at %d Hz" % rate)
			check(peak<=door.door_passive_max_angular_velocity,"Return respects safe passive speed")
			check(absf(omega)<door.latch_velocity_threshold,"Return slows enough to latch")
	check(door.door_max_angle_degrees==100.0,"Existing hinge limit preserved")
	check(door.max_health==100.0,"Existing destruction health preserved")
	door.free()
	print("DOOR_RETURN_MOTION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
