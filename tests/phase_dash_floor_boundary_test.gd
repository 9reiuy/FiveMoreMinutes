extends SceneTree
## Real Player/PhaseDash, deterministic floor topology, and an independent exact
## circle-vs-missing-cell oracle rather than repeating the controller's samples.
const CONFIG := preload("res://resources/demo_config.tres")
class World extends Node3D:
	var floor_root := Node3D.new()
	var floor_cells: Dictionary = {}
	var pit_cells: Dictionary = {}
	var _layout_generation := 1
	var player: CharacterBody2D
	var gate_enabled := false
	var gate_x := 64.0
	var attacks: Array = []
	func _ready() -> void:
		add_child(floor_root)
		add_to_group(&"dream_world")
	func _cell_for_gameplay_position(point: Vector2) -> Vector2i:
		return Vector2i(roundi(point.x/32), roundi(point.y/32))
	func is_player_dash_landing_allowed(point: Vector2) -> bool:
		return not gate_enabled or point.x < gate_x
	func get_gameplay_aim_position() -> Vector2: return Vector2(300,0)
	func resolve_phase_dash_attack(start: Vector2, end: Vector2, _radius: float, _damage: float, _source: StringName, _handled: Variant = null, _feedback: bool = true) -> Dictionary:
		attacks.append([start,end])
		return {"hits":0,"kills":0}
var world: World
var player: CharacterBody2D
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
	print("PASS " if ok else "FAIL ", label)
func reset() -> void:
	player.cancel_dash()
	world.floor_cells.clear()
	for x in range(-16,17):
		for y in range(-16,17): world.floor_cells[Vector2i(x,y)] = true
	world.pit_cells.clear()
	world.attacks.clear()
	world.gate_enabled = false
	player.global_position = Vector2.ZERO
	player.dead = false
	player.movement_enabled = true
	player.set_attacking_enabled(true)
	player.max_dash_charges = 2
	player.dash_charges = 2
	player.dash_cooldown_left = 0.0
	player.invulnerability_left = 0.0
func exact_footprint_supported(point: Vector2) -> bool:
	if not player._dash_floor_position_valid(point): return false
	var collision: CollisionShape2D = player.body_collision
	var center := point + collision.global_position - player.global_position
	var radius: float = collision.shape.radius * maxf(collision.global_scale.x, collision.global_scale.y)
	var low := Vector2i(floori((center.x-radius+16.0)/32.0), floori((center.y-radius+16.0)/32.0))
	var high := Vector2i(floori((center.x+radius+16.0)/32.0), floori((center.y+radius+16.0)/32.0))
	for y in range(low.y, high.y+1):
		for x in range(low.x, high.x+1):
			var cell := Vector2i(x,y)
			if world.floor_cells.has(cell) and not world.pit_cells.has(cell): continue
			var bounds := Rect2(Vector2(cell)*32.0-Vector2(16,16),Vector2(32,32))
			var closest := center.clamp(bounds.position,bounds.end)
			if closest.distance_squared_to(center) < radius*radius-.00001: return false
	if world.gate_enabled and center.x + radius >= world.gate_x: return false
	return true
func complete_and_check_path(label: String) -> void:
	var all_supported := true
	for i in 16:
		if not player.is_phase_dash_active(): break
		player._update_dash(player.dash_duration/14.0)
		all_supported = all_supported and exact_footprint_supported(player.global_position)
	check(all_supported, label + " every runtime body footprint stays on floor")
	check(not player.dashing and player.collision_layer != 0 and player.collision_mask != 0, label + " ends with collision restored")
	check(player.dash_charges == 1, label + " consumes exactly one charge")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world = World.new()
	root.add_child(world)
	player = load("res://scenes/entities/dream_player.tscn").instantiate()
	world.add_child(player)
	world.player = player
	player.configure_weapon("lucille",CONFIG,{})
	player.set_physics_process(false)
	await physics_frame
	# Four physical map boundaries include the actual upward collision offset.
	for heading in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		reset()
		for cell in world.floor_cells.keys():
			if Vector2(cell).dot(heading) > 1: world.floor_cells.erase(cell)
		check(player.try_start_phase_dash(heading), "map edge " + str(heading) + " starts only a short supported dash")
		check(player.dash_end.length() < 48 and exact_footprint_supported(player.dash_end), "map edge " + str(heading) + " endpoint stays fully supported")
		complete_and_check_path("map edge " + str(heading))
	# A distant island is not a legal target through an intermediate missing strip.
	for width in [1,3]:
		reset()
		for cell in world.floor_cells.keys():
			if cell.x >= 1 and cell.x <= width: world.floor_cells.erase(cell)
		check(world.floor_cells.has(Vector2i(width+1,0)), "gap " + str(width) + " has a real far platform")
		check(player.try_start_phase_dash(Vector2.RIGHT) and player.dash_end.x < 16, "gap " + str(width) + " cannot be skipped to the far platform")
		complete_and_check_path("gap " + str(width))
	# A broad diagonal gap is rejected using the whole body, not just its foot.
	reset()
	world.floor_cells.erase(Vector2i(1,-1))
	check(player.try_start_phase_dash(Vector2(1,-1)), "diagonal corner starts a shortened supported movement")
	check(player.dash_end.length() < 16 and exact_footprint_supported(player.dash_end), "diagonal corner endpoint does not enter missing cell")
	complete_and_check_path("diagonal corner")
	# The nearest corner lies between the old 0 and -45 degree perimeter probes.
	reset()
	world.floor_cells.erase(Vector2i(1,-1))
	player.global_position = Vector2(0,-.3)
	check(player.try_start_phase_dash(Vector2.RIGHT), "grazing corner starts before the corner")
	check(exact_footprint_supported(player.dash_end), "grazing corner exact circle cannot protrude between perimeter sample angles")
	complete_and_check_path("grazing corner")
	# A diagonal can graze a rounded missing-cell corner only between two
	# distance samples, even when each individual sampled circle is exact.
	reset()
	world.floor_cells.erase(Vector2i(1,-1))
	player.global_position = Vector2(0,-9.01)
	var grazing_start := player.global_position
	check(player.try_start_phase_dash(Vector2(1,1)), "short diagonal graze begins on safe floor")
	var grazing_end: Vector2 = player.dash_end
	var swept_safe := true
	var samples := ceili(grazing_start.distance_to(grazing_end)/.1)
	for i in range(samples+1):
		if not exact_footprint_supported(grazing_start.lerp(grazing_end,float(i)/maxi(1,samples))): swept_safe = false; break
	check(swept_safe, "continuous diagonal body sweep cannot skip a sub-two-pixel corner contact")
	complete_and_check_path("short diagonal graze")
	# Existing holes and tutorial gate policy remain authoritative.
	reset()
	world.pit_cells[Vector2i(2,0)] = true
	world.pit_cells[Vector2i(2,-1)] = true
	check(player.try_start_phase_dash(Vector2.RIGHT) and player.dash_end.x < 48, "pit truncates the whole swept route")
	complete_and_check_path("pit")
	reset()
	world.gate_enabled = true
	check(player.try_start_phase_dash(Vector2.RIGHT) and player.dash_end.x < world.gate_x-7, "tutorial landing gate also limits the swept body")
	complete_and_check_path("tutorial gate")
	# Removing future floor after commit terminates before that new edge.
	reset()
	check(player.try_start_phase_dash(Vector2.RIGHT), "dynamic floor starts on an intact route")
	player._update_dash(player.dash_duration*.35)
	var previous := player.global_position
	for cell in world.floor_cells.keys():
		if cell.x >= 3: world.floor_cells.erase(cell)
	player._update_dash(player.dash_duration)
	check(player.global_position.x >= previous.x and player.global_position.x < 80 and exact_footprint_supported(player.global_position), "future floor disappearance stops before void without travelling backward")
	check(not player.is_phase_dash_active() and player.collision_mask != 0 and player.dash_charges == 1, "floor disappearance restores body and consumes no additional charge")
	# Cancellation and entirely rejected attempts cannot silently spend charges.
	reset()
	check(player.try_start_phase_dash(Vector2.RIGHT), "cancel fixture starts")
	player._update_dash(player.dash_duration*.3)
	player.cancel_dash()
	player.cancel_dash()
	check(not player.dashing and exact_footprint_supported(player.global_position) and player.collision_mask != 0 and player.dash_charges == 1, "repeat cancel keeps one spent charge and a safe body")
	reset()
	for cell in world.floor_cells.keys():
		if cell.x >= 1: world.floor_cells.erase(cell)
	player.global_position = Vector2(8,0)
	check(exact_footprint_supported(player.global_position), "no-room fixture begins on supported floor")
	check(not player.try_start_phase_dash(Vector2.RIGHT) and player.dash_charges == 2 and player.dash_cooldown_left == 0, "no supported travel distance consumes no charge or cooldown")
	reset()
	world.floor_cells.clear()
	check(not player.try_start_phase_dash(Vector2.RIGHT) and player.dash_charges == 2 and player.collision_mask != 0, "unsupported origin consumes nothing and never turns collision off")
	# Interior masonry remains phaseable while the ground under it is continuous.
	reset()
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,120)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector2(64,0)
	await physics_frame
	check(player.try_start_phase_dash(Vector2.RIGHT) and is_equal_approx(player.dash_end.x, player.dash_distance), "continuous indoor floor still permits travel through a real wall")
	complete_and_check_path("indoor wall")
	check(is_equal_approx(player.global_position.x,player.dash_distance), "indoor wall reaches the normal full endpoint")
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"dash")
	await create_timer(.15,true,false,true).timeout
	for i in 4: await process_frame
	print("PHASE_DASH_FLOOR_BOUNDARY checks=",checks," failures=",failures.size()," labels=",failures)
	quit(0 if failures.is_empty() else 1)
