extends SceneTree
const EMITTER = preload("res://scripts/entities/corpse_blood_emitter.gd")
const BLOOD = preload("res://scripts/entities/black_blood_effect.gd")
class TestWorld extends Node:
	var token := 1
	var marks: Array[Dictionary] = []
	var pulses := 0
	var room_queries := 0
	func get_current_floor_token() -> int: return token
	func resolve_environment_debris_room_id(_point: Vector2, fallback: int) -> int:
		room_queries += 1
		return fallback
	func spawn_blood_trail(_point: Vector2, _room: int, _direction: Vector2, _amount: float) -> void: pulses += 1
	func spawn_corpse_blood_pulse(_point: Vector2, _room: int, _direction: Vector2, _amount: float, _airborne: int) -> void: pulses += 1
	func spawn_corpse_drag_trail(start: Vector2, finish: Vector2, room: int, _amount: float, width: float) -> bool:
		marks.append({"start": start, "finish": finish, "room": room, "width": width})
		return true
class Surface extends Node:
	func _is_blood_ground_allowed(point: Vector2) -> bool:
		return point.x >= 0 and point.x <= 32 and absf(point.y) <= 3
class ProjectedCorpse extends Node2D:
	var contact_offset := Vector2(20,-12)
	func get_corpse_blood_ground_position() -> Vector2:
		return global_position + contact_offset
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	var source := Node2D.new()
	root.add_child(source)
	var sprite := Sprite2D.new()
	sprite.position.y = -100
	source.add_child(sprite)
	var emitter := EMITTER.new()
	root.add_child(emitter)
	emitter.configure(world, Vector2.ZERO, 1, Vector2.RIGHT, 1, 6, .22, .78, source)
	emitter.set_process(false)
	emitter._process(.01)
	check(world.marks.is_empty(), "Stationary corpse has no drag mark")
	source.position = Vector2(8, 0)
	emitter._process(.01)
	check(world.marks.size() == 1 and world.marks[0].start == Vector2.ZERO and world.marks[0].finish == Vector2(8, 0), "Full accumulated ground stroke follows actual root")
	check(world.marks[0].width == 24.0, "Drag produces a broad smear rather than a dot line")
	check(world.marks[0].start.y == 0 and world.marks[0].finish.y == 0, "Fake-height visual does not move the ground smear")
	source.position = Vector2(8, 8)
	emitter._process(.01)
	check(world.marks[-1].start == Vector2(8, 0) and world.marks[-1].finish == Vector2(8, 8), "Direction change follows real path")
	var count := world.marks.size()
	source.position = Vector2(300, 300)
	emitter._process(.01)
	check(world.marks.size() == count, "Teleport rejects connecting trail")
	source.position += Vector2(8, 0)
	emitter._process(.01)
	check(world.marks[-1].start == Vector2(300, 300), "Sampling restarts after relocation")
	count = world.marks.size()
	source.position += Vector2(40, 0)
	emitter._process(.01)
	check(world.marks.size() - count == emitter.drag_max_segments_per_frame, "Long movement obeys per-frame mark budget")
	count = world.marks.size()
	emitter._process(.01)
	check(world.marks.size() == count, "Skipped movement samples are never replayed at rest")
	for index in 40:
		source.position += Vector2(16, 0)
		emitter._process(.01)
	check(world.marks.size() == emitter.drag_max_segments_per_corpse, "Per-corpse marks remain bounded")
	world.token += 1
	emitter._process(.01)
	check(not emitter.active, "Floor token change stops mark scheduling")
	var weak_emitter := EMITTER.new()
	root.add_child(weak_emitter)
	weak_emitter.configure(world, source.global_position, 1, Vector2.RIGHT, 1, 2, .22, .78, source)
	weak_emitter.set_process(false)
	source.free()
	weak_emitter._process(.01)
	check(not weak_emitter.active, "Weak corpse disposal stops scheduler")
	var late_source := Node2D.new()
	root.add_child(late_source)
	var late := EMITTER.new()
	root.add_child(late)
	late.configure(world, Vector2.ZERO, 1, Vector2.RIGHT, 1, 2.2, .22, .78, late_source)
	late.set_process(false)
	late._process(3.0)
	check(late.active and late.duration_left <= 0.0, "Drag-only tracking survives the original bleed duration")
	var pulse_count := world.pulses
	var query_count := world.room_queries
	count = world.marks.size()
	for frame in 120: late._process(.01)
	check(world.marks.size() == count and world.pulses == pulse_count, "Late stationary corpse produces neither marks nor drip pulses")
	check(world.room_queries == query_count, "Stationary late tracking does not repeat spatial room queries")
	late_source.position += Vector2(8, 0)
	late._process(.01)
	check(world.marks.size() == count + 1 and world.pulses == pulse_count, "Real movement after 2.2 seconds creates only a drag mark")
	late._process(20.0)
	check(not late.active, "Drag-only tracking has a bounded lifetime")
	late_source.free()
	var slow_source := Node2D.new(); root.add_child(slow_source)
	var slow := EMITTER.new(); root.add_child(slow)
	slow.configure(world,Vector2.ZERO,1,Vector2.RIGHT,1,0,.22,.78,slow_source)
	slow.set_process(false)
	count=world.marks.size()
	for x in range(1,9):
		slow_source.position.x=x; slow._process(.016)
		if x==1:
			check(world.marks.size()==count+1 and world.marks[-1].start==Vector2.ZERO and world.marks[-1].finish==Vector2(1,0),"First 1px movement immediately starts the smear")
	check(world.marks.size()==count+1,"Sustained slow motion retains the existing segment budget")
	slow._process(.016)
	check(world.marks.size()==count+2 and world.marks[-1].start==Vector2(1,0) and world.marks[-1].finish==Vector2(8,0),"Stopping commits the complete remaining 7px path")
	count=world.marks.size()
	for frame in 10: slow._process(.016)
	check(world.marks.size()==count,"Stationary tail is emitted once without repeated work")
	slow_source.position=Vector2(11,0); slow._process(.016)
	check(world.marks.size()==count+1 and world.marks[-1].start==Vector2(8,0) and world.marks[-1].finish==Vector2(11,0),"Resumed 3px contact starts immediately")
	slow_source.position=Vector2(11,8); slow._process(.016)
	check(world.marks[-2].start==Vector2(8,0) and world.marks[-2].finish==Vector2(11,0),"Resumed straight segment stays intact at a corner")
	check(world.marks[-1].start==Vector2(11,0) and world.marks[-1].finish==Vector2(11,8),"Turn does not cut across the actual path")
	slow_source.position=Vector2(11,11); slow._process(.016)
	slow_source.position=Vector2(19,11); slow._process(.016)
	check(world.marks[-2].start==Vector2(11,8) and world.marks[-2].finish==Vector2(11,11),"Pending short stroke still flushes before a turn")
	check(world.marks[-1].start==Vector2(11,11) and world.marks[-1].finish==Vector2(19,11),"Turn remains connected without drawing a diagonal chord")
	slow_source.free(); slow.free()
	var projected := ProjectedCorpse.new(); root.add_child(projected)
	var attached := EMITTER.new(); root.add_child(attached)
	attached.configure(world,Vector2.ZERO,1,Vector2.RIGHT,1,0,.22,.78,projected)
	attached.set_process(false)
	check(attached.origin_gameplay_position==Vector2(20,-12),"Initial drag anchor uses the visible corpse floor contact")
	count=world.marks.size()
	projected.position=Vector2(1,0); attached._process(.016)
	check(world.marks.size()==count+1 and world.marks[-1].start==Vector2(20,-12) and world.marks[-1].finish==Vector2(21,-12),"Trail follows projected body contact instead of distant collision root")
	check(projected.position==Vector2(1,0),"Visual attachment never moves authoritative collision position")
	count=world.marks.size()
	projected.contact_offset+=Vector2(2,1); attached._process(.016)
	check(world.marks.size()==count,"Camera or pose offset alone never draws a false stationary trail")
	attached.free(); projected.free()
	var surface := Surface.new()
	root.add_child(surface)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(12, 0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 20)
	collision.shape = rectangle
	wall.add_child(collision)
	root.add_child(wall)
	var blood := BLOOD.new()
	root.add_child(blood)
	blood.set_surface_context(surface, 1)
	await physics_frame
	await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 741
	blood.setup_drag_smear(rng, 1, Vector2.ZERO, Vector2(24, 0), 1, 4)
	check(not blood.ground_pixels.is_empty() and blood.ground_pixels.all(func(point: Vector2) -> bool: return point.x < 11), "Actual closed wall or door clips smear pixels")
	check(blood.airborne_pixels.is_empty() and blood.settled and not blood.is_processing(), "Smear has no airborne droplets or ongoing simulation")
	check(blood.ground_pixels.all(func(point: Vector2) -> bool: return surface._is_blood_ground_allowed(blood.to_global(point))), "Floor footprint clips every generated pixel")
	check(blood.ground_pixel_types.all(func(kind: int) -> bool: return kind == BLOOD.StampType.PIXEL_CELL), "Smear uses independently clipped single-pixel stamps")
	wall.collision_layer = 0
	await physics_frame
	await physics_frame
	rng.seed = 741
	blood.setup_drag_smear(rng, 1, Vector2.ZERO, Vector2(24, 0), 1, 4)
	check(blood.ground_pixels.any(func(point: Vector2) -> bool: return point.x > 12), "Open doorway allows the actual floor path")
	blood.setup_drag_smear(rng, 1, Vector2.ZERO, Vector2(100, 0), 1, 4)
	check(blood.ground_pixels.is_empty(), "Direct smear API rejects overlong teleport segment")
	blood.free()
	wall.free()
	surface.free()
	world.free()
	for index in 3: await process_frame
	print("Corpse drag trail: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
