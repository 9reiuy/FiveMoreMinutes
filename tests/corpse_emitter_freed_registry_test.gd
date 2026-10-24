extends SceneTree
const WORLD = preload("res://scripts/dream/dream_3d_random_dungeon.gd")
class Emitter extends Node:
	var active := true
	var stopped := false
	func stop_and_free() -> void:
		active = false
		stopped = true
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	# Off-tree world isolates the actual owned registry algorithm from rendering.
	var world := WORLD.new()
	var stale := Emitter.new()
	world._owned_corpse_blood_emitters.append(stale)
	stale.free()
	var maximum: int = world.EMPLOYEE_CONFIG.max_active_corpse_blood_emitters
	var live: Array[Emitter] = []
	for index in maximum:
		var emitter := Emitter.new()
		emitter.set_meta(&"corpse_blood_spawn_serial", index + 1)
		world._owned_corpse_blood_emitters.append(emitter)
		live.append(emitter)
	world._enforce_corpse_blood_emitter_limit()
	check(world._owned_corpse_blood_emitters.size() == maximum, "Freed slot is removed while live emitters remain")
	check(live[0].stopped, "Oldest live emitter is evicted at the existing hard limit")
	check(live.filter(func(e: Emitter) -> bool: return e.stopped).size() == 1, "One eviction preserves remaining live emitters")
	for emitter in live: emitter.free()
	world._enforce_corpse_blood_emitter_limit()
	check(world._owned_corpse_blood_emitters.is_empty(), "Repeated trimming removes every subsequently freed slot")
	world.free()
	print("Corpse emitter registry: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
