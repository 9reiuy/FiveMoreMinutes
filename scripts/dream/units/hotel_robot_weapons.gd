extends Node3D
## Deployable side weapon bays for the hotel robot.
##
## Timeline (deploy 0 -> 1):
##   0.00 - 0.32  hatch slides out of the hull and back along -Z
##   0.22 - 0.78  arm telescopes outward past the body silhouette
##   0.55 - 1.00  gun swings from stowed to forward-facing, tips down to aim
##
## set_deploy() drives the whole thing deterministically, which keeps the
## turntable frames stable; auto_cycle is only for free-running previews.

const DEPLOY_SECONDS := 1.10

var deploy := 0.0
var auto_cycle := false
var _clock := 0.0
var _bays: Array[Dictionary] = []


func _ready() -> void:
	for child in get_children():
		if not String(child.name).begins_with("Bay"):
			continue
		var side := -1.0 if String(child.name).ends_with("L") else 1.0
		var hatch := child.get_node_or_null("HatchPivot") as Node3D
		var arm := child.get_node_or_null("ArmPivot") as Node3D
		_bays.append({
			"side": side,
			"hatch": hatch,
			"hatch_base": hatch.position if hatch != null else Vector3.ZERO,
			"arm": arm,
			"arm_base": arm.position if arm != null else Vector3.ZERO,
			"gun": child.get_node_or_null("ArmPivot/Gun") as Node3D,
		})
	set_deploy(deploy)


func _process(delta: float) -> void:
	if not auto_cycle:
		return
	_clock += delta
	# 1.1 s deploy, hold, 1.1 s retract, hold.
	var period := DEPLOY_SECONDS * 2.0 + 1.6
	var phase := fmod(_clock, period)
	if phase < 1.4:
		set_deploy(0.0)
	elif phase < 1.4 + DEPLOY_SECONDS:
		set_deploy((phase - 1.4) / DEPLOY_SECONDS)
	elif phase < 2.8 + DEPLOY_SECONDS:
		set_deploy(1.0)
	else:
		set_deploy(1.0 - (phase - (2.8 + DEPLOY_SECONDS)) / DEPLOY_SECONDS)


func set_deploy(value: float) -> void:
	deploy = clampf(value, 0.0, 1.0)
	var hatch_open := smoothstep(0.0, 0.32, deploy)
	var extend := smoothstep(0.22, 0.78, deploy)
	var aim := smoothstep(0.55, 1.0, deploy)
	for bay in _bays:
		var side: float = bay["side"]
		var hatch: Node3D = bay["hatch"]
		var arm: Node3D = bay["arm"]
		var gun: Node3D = bay["gun"]
		if hatch != null:
			var hatch_base: Vector3 = bay["hatch_base"]
			hatch.position = hatch_base + Vector3(side * 0.032 * hatch_open, 0.0, -0.200 * hatch_open)
		if arm != null:
			var arm_base: Vector3 = bay["arm_base"]
			arm.position = arm_base + Vector3(side * 0.205 * extend, 0.0, 0.0)
		if gun != null:
			# Stowed the barrel folds inward (hidden inside the hull); deploying
			# swings it 90 degrees out to point forward, then tips down to aim.
			gun.rotation = Vector3(
				deg_to_rad(-6.0 * aim),
				deg_to_rad(-side * 90.0 * (1.0 - aim) + side * 14.0 * aim),
				0.0
			)


## Convenience for the lab: jump straight to the deployed pose.
func deploy_now() -> void:
	set_deploy(1.0)
