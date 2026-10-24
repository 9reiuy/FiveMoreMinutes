extends SceneTree
## Locks the two things the reference reads on and that are easy to lose: the plume
## has to be long, and it has to sit out along the shot instead of hugging the muzzle.
## One burst of ten puffs is far too noisy to measure, so this samples many shots and
## reports the distribution of where puffs actually end up when they die.
const MUZZLE=preload("res://scripts/dream/muzzle_smoke.gd")

var checks:=0
var failures:=0

const SHOTS := 120


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
	var aim := Vector3(1, 0, 0)

	var born_min := 99.0
	var born_max := -99.0
	var ends: Array[float] = []
	var ends_white: Array[float] = []
	var ends_colour: Array[float] = []
	for shot in SHOTS:
		smoke.clear()
		smoke.burst(Vector3.ZERO, aim * 5.0)
		for puff in smoke.puffs:
			var reach: float = (puff["origin"] as Vector3).dot(aim)
			born_min = minf(born_min, reach)
			born_max = maxf(born_max, reach)
			# A random head start is a visual trick; it would also cull puffs before
			# they could be measured. Reset them so every puff runs a full life.
			puff["age"] = 0.0
			puff["cage"] = 0.0
			puff["drift"] = Vector3.ZERO
		# Run the whole plume to the end of its life, which is where its length shows.
		for step in 14:
			smoke.call("_physics_process", 0.08)
		for puff in smoke.puffs:
			var along: float = ((puff["origin"] as Vector3) + (puff.get("drift", Vector3.ZERO) as Vector3)).dot(aim)
			ends.append(along)
			if bool(puff.get("white", false)):
				ends_white.append(along)
			else:
				ends_colour.append(along)

	ends.sort()
	var lo: float = ends[0]
	var hi: float = ends[ends.size() - 1]
	var mean := 0.0
	for v in ends:
		mean += v
	mean /= float(ends.size())
	var nearest := 99.0
	for v in ends:
		nearest = minf(nearest, v)
	var white_mean := 0.0
	for v in ends_white:
		white_mean += v
	white_mean /= float(maxi(1, ends_white.size()))
	var colour_mean := 0.0
	for v in ends_colour:
		colour_mean += v
	colour_mean /= float(maxi(1, ends_colour.size()))

	check(ends.size() > SHOTS, "Enough puffs survived to the end to measure (%d)" % ends.size())
	# Born out along the shot, not at the muzzle.
	check(born_min > 0.30, "No puff is born on the muzzle (min=%.2f)" % born_min)
	check(born_max > 2.00, "Births stretch far down the shot (max=%.2f)" % born_max)
	# Dead puffs mark the two ends of the trail; the gap between them is its length.
	check(hi - lo > 2.00, "The trail spans a long stretch of the shot (%.2f)" % (hi - lo))
	check(mean > 0.80, "The plume sits away from the muzzle on average (%.2f)" % mean)
	check(white_mean - colour_mean > 0.60, "White and colour separate clearly (%.2f)" % (white_mean - colour_mean))

	print("MUZZLE_REACH born=[%.2f..%.2f] ends=[%.2f..%.2f] span=%.2f mean=%.2f nearest=%.2f white=%.2f colour=%.2f checks=%d failures=%d"
		% [born_min, born_max, lo, hi, hi - lo, mean, nearest, white_mean, colour_mean, checks, failures])
	quit(0 if failures == 0 else 1)
