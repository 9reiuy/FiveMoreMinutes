extends SceneTree
## The reference plume is strung out along the shot line and then splits: the white
## puffs push further forward, the coloured puffs recede behind them and float up.
## Birth distance is random, so nothing here may assume an evenly spaced ladder; the
## trail has to be long, narrow, and free of any puff sitting on the muzzle.
## Everything is measured over several shots: a single burst of five puffs is far too
## small a sample for a max/min assertion to be stable.
const MUZZLE=preload("res://scripts/dream/muzzle_smoke.gd")

var checks:=0
var failures:=0

const SHOTS := 8


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

	for aim in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var dir: Vector3 = (aim as Vector3).normalized()
		var whites := 0
		var colours := 0
		var lowest := 0.0
		var across := 0.0
		var near := 99.0
		var far := 0.0
		var white_forward := 99.0
		var colour_forward := -99.0
		for shot in SHOTS:
			smoke.clear()
			smoke.burst(Vector3.ZERO, aim * 5.0)
			for puff in smoke.puffs:
				var origin: Vector3 = puff["origin"]
				var flat := Vector3(origin.x, 0.0, origin.z)
				var reach: float = flat.dot(dir)
				across = maxf(across, (flat - dir * reach).length())
				near = minf(near, reach)
				far = maxf(far, reach)
				lowest = minf(lowest, origin.y)
				var forward: float = (puff["velocity"] as Vector3).dot(dir)
				if bool(puff.get("white", false)):
					whites += 1
					white_forward = minf(white_forward, forward)
				else:
					colours += 1
					colour_forward = maxf(colour_forward, forward)
		check(whites >= SHOTS * 4 and colours >= SHOTS * 4,
			"Both layers spawn every shot (%s) white=%d colour=%d" % [aim, whites, colours])
		check(white_forward > 0.5, "Every white puff pushes forward (%s) min=%.2f" % [aim, white_forward])
		check(colour_forward < -0.5, "Every coloured puff recedes (%s) max=%.2f" % [aim, colour_forward])
		# Spread out down the shot, but stay a narrow trail rather than a round cloud.
		check(near > 0.30, "Nothing is born on top of the muzzle (%s) near=%.2f" % [aim, near])
		check(far > 2.00, "The trail stretches well past the muzzle (%s) far=%.2f" % [aim, far])
		check(across < 0.45, "Trail stays narrow, not a cloud (%s) across=%.2f" % [aim, across])
		check(lowest > -0.12, "No puff sinks below the muzzle (%s) low=%.2f" % [aim, lowest])
		# Once the puffs have lived a while the two layers must have separated.
		var white_along := 0.0
		var colour_along := 0.0
		var white_n := 0
		var colour_n := 0
		for shot in SHOTS:
			smoke.clear()
			smoke.burst(Vector3.ZERO, aim * 5.0)
			for step in 12:
				smoke.call("_physics_process", 0.08)
			for puff in smoke.puffs:
				var origin: Vector3 = puff["origin"]
				# Read the accumulated drift, never velocity * age: the implementation
				# decays velocity every frame, so the product discounts the decay twice.
				var travelled: float = (origin + (puff.get("drift", Vector3.ZERO) as Vector3)).dot(dir)
				if bool(puff.get("white", false)):
					white_along += travelled
					white_n += 1
				else:
					colour_along += travelled
					colour_n += 1
		if white_n > 0 and colour_n > 0:
			var w := white_along / float(white_n)
			var c := colour_along / float(colour_n)
			check(w > 0.0, "White layer ends up ahead (%s) along=%.2f" % [aim, w])
			check(c < w, "Coloured layer trails the white one (%s) colour=%.2f white=%.2f" % [aim, c, w])
			# Guards the length: a plume that collapses back onto the muzzle is the
			# regression this whole file exists to catch.
			check(w - c > 0.50, "The plume spans a real stretch of the shot (%s) span=%.2f" % [aim, w - c])

	print("MUZZLE_SMOKE_DIRECTION checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
