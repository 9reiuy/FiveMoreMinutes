extends "res://scripts/dream/props/drivable_forklift.gd"
## Admission fixture: install the candidate before changing the live controller.
const WIND := preload("res://scripts/dream/props/forklift_boost_wind.gd")
var candidate_wind: WIND

func configure(owner_world: Node3D, model: MODEL, height := 0.0) -> void:
	super.configure(owner_world, model, height)
	candidate_wind = WIND.new()
	visual.add_child(candidate_wind)

func reset_motion() -> void:
	super.reset_motion()
	if is_instance_valid(candidate_wind): candidate_wind.clear()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_instance_valid(candidate_wind):
		if destroyed or not is_instance_valid(driver):
			candidate_wind.clear()
		else:
			candidate_wind.sync_motion(absf(speed), boost_left > 0.0 and Input.get_axis(&"move_down", &"move_up") > 0.0 and not handbraking, delta)
