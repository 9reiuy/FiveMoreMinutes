extends SceneTree
## Verifies the muzzle plume actually moves: away from the shot first (recede),
## then upward (float), and that the displacement is large enough to read on screen.
const MUZZLE=preload("res://scripts/dream/muzzle_smoke.gd")

var checks:=0
var failures:=0


class Host extends Node3D:
	pass


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var smoke := MUZZLE.new()
	host.add_child(smoke)
	smoke.configure()
	smoke.set_physics_process(false)
	var aim := Vector3(0, 0, 1)
	smoke.burst(Vector3.ZERO, aim * 4.0)
	# Track one coloured puff over its life.
	var target: Dictionary = {}
	for puff in smoke.puffs:
		if not bool(puff.get("white", false)) and not bool(puff.get("core", false)):
			target = puff
			break
	check(not target.is_empty(), "A coloured puff exists")
	var start: Vector3 = target["origin"]
	var samples: Array[float] = []
	var heights: Array[float] = []
	for step in 10:
		smoke.call("_physics_process", 0.1)
		# Accumulated drift, not velocity * age: velocity decays every frame, so the
		# product would discount the decay twice and understate the real displacement.
		var p: Vector3 = (target["origin"] as Vector3) + (target.get("drift", Vector3.ZERO) as Vector3) \
			+ Vector3.UP * (0.22 * float(target["age"]) + 0.30 * float(target.get("rise", 0.0)) * pow(float(target["age"]), 2.0))
		samples.append(p.dot(aim.normalized()) - start.dot(aim.normalized()))
		heights.append(p.y - start.y)
	# Recede: distance along the shot must shrink, not grow.
	check(samples[9] < -0.15, "Plume recedes from its birth point along the shot (%.2f)" % samples[9])
	# Float: height must rise clearly within the puff's life.
	check(heights[9] > 0.30, "Plume floats upward while it cools (%.2f)" % heights[9])
	# One page, one colour: every puff of a shot cools on the same clock.
	smoke.clear()
	smoke.burst(Vector3.ZERO, Vector3(0, 0, 4))
	var cages: Array[float] = []
	for puff in smoke.puffs:
		if not bool(puff.get("white", false)) and not bool(puff.get("core", false)):
			cages.append(float(puff.get("cage", -1.0)))
	check(cages.size() > 2 and cages.min() == cages.max(), "All puffs share one colour clock")
	# Near the muzzle must not be smaller than far away.
	# Size is purely random with a 70/30 big-to-small split; sample many puffs.
	var big := 0
	var total := 0
	for shot in 30:
		smoke.clear()
		smoke.burst(Vector3.ZERO, Vector3(0, 0, 4))
		for puff in smoke.puffs:
			if bool(puff.get("white", false)):
				continue
			total += 1
			if float(puff["size"]) >= 0.36:
				big += 1
	check(total > 100, "Enough puffs sampled for the size split")
	var ratio := float(big) / float(maxi(1, total))
	check(ratio > 0.55 and ratio < 0.85, "About 70%% of puffs are big (%.2f)" % ratio)
	print("MUZZLE_MOTION recede=%.2f rise=%.2f big_ratio=%.2f checks=%d failures=%d" % [samples[9], heights[9], ratio, checks, failures])
	quit(0 if failures == 0 else 1)
