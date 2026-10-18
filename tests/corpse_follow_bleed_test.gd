extends SceneTree

const EMITTER := preload("res://scripts/entities/corpse_blood_emitter.gd")
const PART := preload("res://scenes/entities/enemy_body_part.tscn")
var failures := 0

class BloodWorld extends Node:
	var token := 1
	var pulses: Array[Dictionary] = []
	func get_current_floor_token() -> int:
		return token
	func resolve_environment_debris_room_id(position: Vector2, _fallback: int) -> int:
		return 2 if position.x >= 100.0 else 1
	func spawn_corpse_blood_pulse(position: Vector2, room: int, _direction: Vector2, amount: float, airborne: int) -> void:
		pulses.append({"position": position, "room": room, "amount": amount, "airborne": airborne})
	func spawn_blood_trail(position: Vector2, room: int, _direction: Vector2, amount: float) -> void:
		pulses.append({"position": position, "room": room, "amount": amount, "airborne": 0})

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func make_emitter(world: Node, source: Node2D, duration := 2.2) -> CorpseBloodEmitter:
	var emitter := EMITTER.new()
	root.add_child(emitter)
	emitter.configure(world, source.global_position, 1, Vector2.RIGHT, 1.0, duration, 0.22, 0.78, source)
	emitter.set_process(false)
	return emitter

func run() -> void:
	var world := BloodWorld.new()
	root.add_child(world)
	var source := Node2D.new()
	root.add_child(source)
	var sprite := Sprite2D.new()
	source.add_child(sprite)
	sprite.position.y = -90.0
	source.position = Vector2(10, 20)
	var emitter := make_emitter(world, source)
	check(world.pulses.size() == 1, "initial pulse once")
	check(world.pulses[0].position == source.position, "ground root instead of fake height")
	emitter._process(0.01)
	check(world.pulses.size() == 1, "no duplicate next-frame pulse")
	source.position = Vector2(110, 40)
	emitter._process(0.23)
	check(world.pulses[-1].position == source.position and world.pulses[-1].room == 2, "follow across room boundary")
	check(world.pulses[-1].amount < world.pulses[0].amount, "seep amount decays")
	var before := world.pulses.size()
	emitter._process(1.0)
	check(world.pulses.size() - before <= 2, "bounded long-frame scheduler")
	check(absf(emitter.intensity - pow(0.78, 1.24 / 0.22)) < 0.0001, "decay follows elapsed time despite skipped pulses")
	for pulse in world.pulses:
		check(pulse.airborne == 0, "corpse emits no airborne droplets")
	world.token = 2
	before = world.pulses.size()
	emitter._process(0.3)
	check(not emitter.active and world.pulses.size() == before, "floor change stops")
	var sleeping := make_emitter(world, source)
	sleeping.set_room_runtime_active(false)
	before = world.pulses.size()
	sleeping._process(0.3)
	check(not sleeping.active and world.pulses.size() == before, "inactive room stops seepage")
	var vanished := make_emitter(world, source)
	source.free()
	before = world.pulses.size()
	vanished._process(0.3)
	check(not vanished.active and world.pulses.size() == before, "weak source removal stops")
	var part := PART.instantiate() as EnemyBodyPart
	root.add_child(part)
	part.set_physics_process(false)
	part.set_process(false)
	part.position = Vector2(130, 60)
	part.visual.position.y = -80.0
	part.configure_ground_bleed(world, 1)
	part.set_process(false)
	before = world.pulses.size()
	for i in 6:
		part.position.x += 5.0
		part._process(0.2)
		if i == 0:
			part.configure_ground_bleed(world, 1)
	check(world.pulses.size() - before == 3, "part has three droplets and cannot restart")
	check(world.pulses[-1].position.y == 60.0 and world.pulses[-1].room == 2, "part uses floor projection and current room")
	var other := PART.instantiate() as EnemyBodyPart
	root.add_child(other)
	other.set_physics_process(false)
	other.configure_ground_bleed(world, 1)
	other.set_process(false)
	before = world.pulses.size()
	other._process(2.0)
	check(world.pulses.size() - before <= 1, "part long-frame budget")
	world.token += 1
	before = world.pulses.size()
	other._process(0.2)
	check(world.pulses.size() == before, "part floor change stops")
	part.free()
	other.free()
	world.free()
	for i in 3:
		await process_frame
	print("CORPSE_FOLLOW_BLEED failures=", failures)
	quit(0 if failures == 0 else 1)


