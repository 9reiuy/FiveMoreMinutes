extends SceneTree
const CARRIER = preload("res://scripts/dream/blood_airborne_carrier_3d.gd")

class Source extends Node2D:
	var _airborne_visual_sink_ref: WeakRef
	var reads := 0
	var count := 9
	func get_airborne_visual_snapshot() -> Array[Dictionary]:
		reads += 1
		var result: Array[Dictionary] = []
		for index in count:
			result.append({"position": Vector2(index, 3), "height": 4.0, "size": 2.0, "velocity": Vector2.ZERO})
		return result
	func unbind_airborne_visual_sink(_sink: Node) -> void:
		_airborne_visual_sink_ref = null

class World extends Node3D:
	func get_current_room_id() -> int: return 0
	func get_gameplay_world_position(point: Vector2, height: float) -> Vector3:
		return Vector3(point.x / 32.0, height, point.y / 32.0)

var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new(); root.add_child(world)
	var source := Source.new(); root.add_child(source)
	var carrier = CARRIER.new(); world.add_child(carrier)
	carrier.configure(source, world, 0, null, 32.0, 0.0)
	check(carrier.multi_mesh.instance_count == 16 and carrier.multi_mesh.visible_instance_count == 9, "Capacity grows without losing droplets")
	source._airborne_visual_sink_ref = weakref(carrier)
	var before := source.reads
	carrier._process(0.0)
	check(source.reads == before, "Bound source must not be sampled twice by the watchdog")
	source.count = 5; carrier.sync_from_effect(source)
	check(carrier.multi_mesh.instance_count == 16 and carrier.multi_mesh.visible_instance_count == 5, "Landing retains buffer and hides spare instances")
	if DisplayServer.get_name() != "headless":
		check(carrier.multi_mesh.get_instance_transform(4).origin.is_equal_approx(Vector3(4.0/32.0, 4.0/32.0, 3.0/32.0)), "Formal particle position remains unchanged")
	else:
		print("SKIP dummy renderer does not retain MultiMesh transforms; checked by GPU run")
	if "--bench" in OS.get_cmdline_user_args():
		source.count = 32
		for pushed in [false, true]:
			source._airborne_visual_sink_ref = weakref(carrier) if pushed else null
			before = source.reads
			var started := Time.get_ticks_usec()
			for index in 2000:
				carrier.sync_from_effect(source)
				carrier._process(0.0)
			print("AIRBORNE_UPLOAD_BENCH pushed=%s us_per_simulated_frame=%f reads=%d particles=32 iterations=2000" % [pushed, float(Time.get_ticks_usec() - started)/2000.0, source.reads-before])
	source._airborne_visual_sink_ref = null
	before = source.reads; carrier._process(0.0)
	check(source.reads == before + 1, "Unbound sources retain pull synchronization")
	source.count = 0; carrier.sync_from_effect(source)
	check(carrier.cleanup_queued and not carrier.visible, "Last landing cleans up the carrier")
	world.free(); source.free()
	print("BLOOD AIRBORNE UPLOAD checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
