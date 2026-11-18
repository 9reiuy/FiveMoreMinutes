extends Node3D
## One controller per floor. Launched bottles survive their thrower; overlapping
## puddles share one exposure clock per unit.
const PUDDLE := preload("res://scripts/dream/scientist_poison_puddle.gd")
const ATLAS := preload("res://art/Dream/enemy/Scientist.png")
const LARGE_REGION := Rect2(138,8,12,15)
const SMALL_REGION := Rect2(142,40,4,14)
const SMALL_RANGE := 252.0
const DAMAGE := 5.0

class Flight:
	var large: bool
	var start: Vector2
	var finish: Vector2
	var previous: Vector2
	var visual_start: Vector3
	var duration: float
	var age := 0.0
	var sprite: Sprite3D

var world: Node3D
var flights: Array[Flight] = []
var puddles: Array[PUDDLE] = []
var exposure: Dictionary = {}
var variant_index := 0
var spare_bottles: Array[Sprite3D] = []
var spare_puddles: Array[PUDDLE] = []

static func ensure(owner_world: Node3D) -> Node3D:
	var host: Node3D = owner_world.floor_root
	var existing := host.get_node_or_null("ScientistPotions")
	if existing != null:
		return existing
	var field: Node3D = new()
	field.name = "ScientistPotions"
	field.world = owner_world
	host.add_child(field)
	field.prepare()
	field.set_physics_process(false)
	return field

func prepare() -> void:
	spare_bottles.append(_make_bottle())
	spare_puddles.append(_make_puddle())

func clear_region() -> void:
	for flight in flights:
		flight.sprite.hide()
		spare_bottles.append(flight.sprite)
	for pool in puddles:
		pool.hide()
		spare_puddles.append(pool)
	flights.clear()
	puddles.clear()
	exposure.clear()
	set_physics_process(false)

func _make_puddle() -> PUDDLE:
	var pool := PUDDLE.new()
	pool.hide()
	pool.mesh = PUDDLE.flat_mesh()
	pool.material_override = PUDDLE.MATERIAL
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	return pool

func _make_bottle() -> Sprite3D:
	var bottle := Sprite3D.new()
	bottle.texture = ATLAS
	bottle.region_enabled = true
	bottle.region_rect = LARGE_REGION
	bottle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bottle.pixel_size = 1.0 / 32.0
	bottle.shaded = true
	bottle.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	bottle.hide()
	add_child(bottle)
	return bottle

func launch(large: bool, start: Vector2, visual_start: Vector3, aim: Vector2) -> void:
	var flight := Flight.new()
	flight.large = large
	flight.start = start
	flight.previous = start
	flight.visual_start = visual_start
	var heading := start.direction_to(aim)
	flight.finish = aim if large else start + heading * SMALL_RANGE
	var length := start.distance_to(flight.finish)
	flight.duration = clampf(.44 + length / 470.0, .52, .96) if large else maxf(.04, length / 360.0)
	flight.sprite = _make_bottle() if spare_bottles.is_empty() else spare_bottles.pop_back()
	flight.sprite.region_rect = LARGE_REGION if large else SMALL_REGION
	flight.sprite.show()
	flights.append(flight)
	_draw_bottle(flight, 0.0)
	set_physics_process(true)

func _draw_bottle(flight: Flight, t: float) -> void:
	var above_floor := 0.0 if flight.large else .65 * (1.0 - smoothstep(.80, 1.0, t))
	var landing: Vector3 = world.get_gameplay_world_position(flight.finish, above_floor)
	flight.sprite.global_position = flight.visual_start.lerp(landing, t)
	if flight.large:
		flight.sprite.global_position.y += 4.0 * t * (1.0 - t) * 1.65
	var camera: Camera3D = world.camera_3d
	var aim: Vector3 = world.get_gameplay_world_position(flight.finish,.65) - world.get_gameplay_world_position(flight.start,.65)
	var side := 1.0 if camera.global_basis.x.dot(aim) >= 0.0 else -1.0
	var angle := -side * (t * TAU if flight.large else PI * .48)
	flight.sprite.global_basis = camera.global_basis.orthonormalized() * Basis(Vector3.BACK, angle)

func _physics_process(delta: float) -> void:
	if get_parent() != world.floor_root or world.floor_transition_in_progress:
		return
	for i in range(puddles.size()-1,-1,-1):
		var pool := puddles[i]
		pool.advance(delta)
		if pool.age >= PUDDLE.LIFETIME:
			pool.hide()
			spare_puddles.append(pool)
			puddles.remove_at(i)
	_update_exposure(delta)
	for i in range(flights.size()-1,-1,-1):
		if _advance_bottle(flights[i], delta):
			flights[i].sprite.hide()
			spare_bottles.append(flights[i].sprite)
			flights.remove_at(i)
	if flights.is_empty() and puddles.is_empty():
		set_physics_process(false)

func _advance_bottle(flight: Flight, delta: float) -> bool:
	flight.age += delta
	var t := minf(1.0, flight.age / flight.duration)
	var next := flight.start.lerp(flight.finish, t)
	var from := flight.previous
	# Tall walls and closed doors stop both. Low furniture only stops the flat throw.
	var mask: int = world.WORLD_WALL_LAYER if flight.large else world.WORLD_WALL_LAYER | 8
	var ray := PhysicsRayQueryParameters2D.create(from, next, mask)
	var hit := world.player.get_world_2d().direct_space_state.intersect_ray(ray) as Dictionary
	var limit := next if hit.is_empty() else Vector2(hit.position)
	var player: Node2D = world.player
	if not flight.large and not player.dead:
		var feet: Vector2 = player.body_collision.global_position
		var fraction := Geometry2D.segment_intersects_circle(from, limit, feet, 9.0)
		if from.distance_squared_to(feet) <= 81.0 or fraction >= 0.0:
			player.receive_damage(DAMAGE, &"scientist_vial", flight.start, flight.start.direction_to(feet))
			spill(feet, false)
			return true
	if not hit.is_empty():
		spill(limit + Vector2(hit.normal) * 2.0, flight.large)
		return true
	if not flight.large and not world.floor_cells.has(world._cell_for_gameplay_position(next)):
		# A vial leaving a walkway breaks at the last supported floor pixel.
		var last_floor := from
		var steps := maxi(1, ceili(from.distance_to(next)))
		for i in range(1, steps + 1):
			var point := from.lerp(next, float(i) / steps)
			if not world.floor_cells.has(world._cell_for_gameplay_position(point)):
				break
			last_floor = point
		spill(last_floor, false)
		return true
	if t >= 1.0:
		spill(next, flight.large)
		return true
	flight.previous = next
	_draw_bottle(flight, t)
	return false

func spill(at: Vector2, large: bool) -> void:
	if not world._is_blood_ground_allowed(at):
		return
	var pool: PUDDLE = _make_puddle() if spare_puddles.is_empty() else spare_puddles.pop_back()
	pool.configure(world, at, large, variant_index % 4)
	pool.show()
	variant_index += 1
	puddles.append(pool)
	set_physics_process(true)

func _update_exposure(delta: float) -> void:
	if puddles.is_empty():
		exposure.clear()
		return
	var standing := {}
	var units: Array[Node] = world.enemy_root.get_children()
	units.append(world.player)
	for unit in units:
		if not unit is Node2D or unit.is_queued_for_deletion() or unit.get("dead") == true:
			continue
		# A hovering patrol drone, a vaulting player and airborne ragdolls have no ground contact.
		if unit.get("drone") != null or unit.get("sky_drop_active") == true or unit.get("knockdown_airborne") == true:
			continue
		if unit == world.player:
			var jump_height: Variant = world.get("jump_lift")
			if unit.vault_active or unit.knockback_height > 3.0 or world.get("climbing") == true or (jump_height != null and jump_height > .1):
				continue
		if unit != world.player and not unit.has_method("take_damage"):
			continue
		var at: Vector2 = unit.global_position
		if unit == world.player or unit is EmployeeEnemy:
			at = unit.body_collision.global_position
		if not contains(at):
			continue
		var id := unit.get_instance_id()
		var seconds := float(exposure.get(id, 0.0)) + delta
		while seconds >= 1.0 - .000001:
			seconds = maxf(0.0, seconds - 1.0)
			if unit == world.player:
				unit.receive_damage(DAMAGE, &"scientist_poison")
			else:
				unit.take_damage(DAMAGE, at, 0.0, &"scientist_poison")
		standing[id] = seconds
	exposure = standing

func contains(point: Vector2) -> bool:
	for pool in puddles:
		if point.distance_squared_to(pool.center) <= pool.radius * pool.radius and pool.contains(point):
			var ground: Vector3 = world.get_gameplay_world_position(point, 0.0)
			if absf(ground.y - pool.floor_y) <= .42:
				return true
	return false
