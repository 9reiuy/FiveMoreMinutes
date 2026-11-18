extends RefCounted
## Attack timing and damage use the same physics space as the player and H06.
signal event(kind: StringName, data: Dictionary)

const RIG := preload("res://scripts/testing/h06_chapter/crawler_weapon_rig.gd")
const FX := preload("res://scripts/testing/h06_chapter/crawler_attack_effects.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const MOTION := preload("res://scripts/testing/h06_chapter/crawler_motion.gd")
const CARGO := preload("res://scripts/testing/h06_chapter/crawler_cargo.gd")

enum Attack { CANNON, MISSILES, SLAM, LASER, CHARGE, STOMP, BURST, BARRAGE }
enum State { REST, WINDUP, ACTIVE, RECOVER, STUNNED }
const NAMES := [&"cannon", &"missiles", &"slam", &"laser", &"charge", &"stomp", &"burst", &"barrage"]
const WINDUPS := [.80, 0.0, .525, .60, .50, .32, .60, .60]
const CYCLE := [Attack.CANNON, Attack.MISSILES, Attack.SLAM, Attack.LASER, Attack.CHARGE, Attack.BARRAGE]
const RECOVER_TIME := .24
const INTER_ATTACK_GAP := .16
const CANNON_KICK_TIME := .27
const BLOCKERS := 4 | 8 | 32
const LASER_SWEEP := .54
const LASER_RANGE := 50.0
const LASER_WIDTH := .55
const MISSILE_COUNT := FX.MISSILE_TUBES
const FIRST_LOCK := .14
const LOCK_INTERVAL := .30
const LAUNCH_DELAY := .17
const MISSILE_RADIUS := 1.95
const BARRAGE_DEPTH := 3.5
const BARRAGE_GAP := .13
const BARRAGE_FLIGHT_TIME := .72
const STOMP_RADIUS := 1.45
const STOMP_DISTANCE := 4.85
const BURST_DURATION := .34
const BURST_SWEEP := TAU/6.
const ARMOR_FACTOR := .10
const SHIELD_HEALTH := 2.0/3.0
const STUN_DURATION := 3.0
const STUN_DAMAGE_LIMIT := 50.0

class Rocket:
	var slot: int
	var index: int
	var marker: int
	var row: int
	var start: Vector3
	var first_tangent: Vector3
	var last_tangent: Vector3
	var end: Vector3
	var launched_at: float
	var duration: float

var boss: Node2D
var world: Node3D
var motion: MOTION
var rig: RIG
var fx: FX
var cargo: CARGO
var health_ratio := 1.0
var stun_left := 0.0
var stun_damage := 0.0
var attack: int = Attack.CANNON
var next_attack: int = Attack.CANNON
var state := State.REST
var age := 0.0
var elapsed := 0.0
var wait := 1.15
var aim := Vector2.ZERO
var heading := Vector2.DOWN
var targets: Array[Dictionary] = []
var rockets: Array[Rocket] = []
var launched := 0
var launched_rows := 0
var shell_active := false
var shell_at := Vector2.ZERO
var shell_direction := Vector2.DOWN
var shell_height := 0.0
var shell_distance := 0.0
var spin_progress := 0.0
var spin_start_yaw := 0.0
var hit_left := 0.0
var charge_distance := 0.0
var charge_stuck := 0.0
var leap_landed := false
var stomp_leg := -1
var stomp_from := Vector3.ZERO
var stomp_to := Vector3.ZERO
var stomp_cooldown := 0.0
var burst_pending := false
var burst_used := false
var burst_did_hit := false
var practice_single := false
var query := PhysicsRayQueryParameters2D.new()
var placement_query := PhysicsShapeQueryParameters2D.new()
var placement_circle := CircleShape2D.new()
var exclusions: Array[RID] = []
var stopped := false

func configure(owner_boss: Node2D) -> void:
	boss = owner_boss
	world = boss.world
	motion = boss.motion
	rig = RIG.new()
	rig.configure(boss.model)
	fx = FX.new()
	world.floor_root.add_child(fx)
	fx.configure(world, boss.model)
	cargo = world.blockout.arena_cargo
	if cargo != null: cargo.event.connect(_forward_cargo_event)
	query.hit_from_inside = true
	query.collide_with_areas = true
	exclusions = [boss.get_rid(), motion.get_rid()]
	placement_query.shape = placement_circle
	placement_query.collision_mask = BLOCKERS
	placement_query.exclude = exclusions
	motion.landed.connect(_landed)

func _forward_cargo_event(kind: StringName, data: Dictionary) -> void:
	event.emit(kind,data)

func origin() -> Vector2:
	return Vector2(boss.model.position.x, boss.model.position.z)

func player_at() -> Vector2:
	return world.player.body_collision.global_position / MOTION.PIXELS

func _forward(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))

func _walk(goal: Vector2, delta: float, facing: Vector2) -> void:
	motion.move_toward_point(Vector3(goal.x, 0, goal.y), delta, facing)
	boss.position = motion.position

func _hold(delta: float) -> void:
	_walk(origin(), delta, origin()+_forward(boss.model.rotation.y))

func advance(delta: float) -> void:
	if stopped or boss.dead or not is_instance_valid(world) or world.player.dead: return
	elapsed += delta
	age += delta
	hit_left = maxf(0., hit_left-delta)
	stomp_cooldown = maxf(0., stomp_cooldown-delta)
	rig.advance(delta)
	if state == State.STUNNED:
		_advance_stun(delta)
	if is_instance_valid(cargo) and cargo.advance(delta,motion):
		_stun(&"cargo_fall")
	if state == State.STUNNED: return
	if shell_active: _advance_shell(delta)
	_advance_rockets(delta)
	match state:
		State.REST: _rest(delta)
		State.WINDUP: _windup(delta)
		State.ACTIVE: _active(delta)
		State.RECOVER: _recovery(delta)

func _rest(delta: float) -> void:
	if burst_pending and not burst_used and not practice_single:
		begin(Attack.BURST)
		return
	var here := origin()
	var player := player_at()
	if not practice_single and stomp_cooldown <= 0. and here.distance_to(player) <= STOMP_DISTANCE:
		if begin(Attack.STOMP): return
	wait -= delta
	if wait <= 0.:
		begin(next_attack)
		return
	var forward := _forward(boss.model.rotation.y)
	var goal := here
	var facing := here + forward
	if here.distance_to(player) > 9.0:
		goal = here.move_toward(player, delta*2.3)
		facing = player
	elif here.distance_to(player) > 5.3:
		# Alternate lateral steps with a stable heading. The same six-foot
		# support and swept collision used for forward travel apply here.
		var side := forward.orthogonal() * (1.0 if next_attack%2 == 0 else -1.0)
		goal += side*delta*2.7
	var safe := _arena_inset(PLAN.CRAWLER_RADIUS)
	_walk(goal.clamp(safe.position, safe.end), delta, facing)

func begin(kind: int) -> bool:
	if stopped or state==State.STUNNED or motion.jump != MOTION.Jump.NONE: return false
	if kind == Attack.STOMP and not _choose_stomp(player_at()): return false
	attack = clampi(kind, 0, Attack.size()-1)
	var cycle_index := CYCLE.find(attack)
	if cycle_index >= 0:
		next_attack = CYCLE[(cycle_index+1)%CYCLE.size()]
	state = State.WINDUP
	age = 0.
	aim = player_at()
	match attack:
		Attack.SLAM:
			aim = _safe_landing(aim, PLAN.CRAWLER_RADIUS)
		Attack.LASER, Attack.BURST:
			motion.velocity = Vector2.ZERO
		Attack.STOMP:
			aim = Vector2(stomp_to.x, stomp_to.z)
	heading = origin().direction_to(aim)
	if heading.length_squared() < .01: heading = _forward(boss.model.rotation.y)
	targets.clear()
	launched = 0
	launched_rows = 0
	hit_left = 0.
	fx.clear_windup()
	rig.open_lid(0.)
	rig.raise_launcher = attack == Attack.MISSILES or attack == Attack.BARRAGE
	if attack == Attack.BARRAGE:
		for row in FX.BARRAGE_ROWS:
			fx.warn_barrage_row(row, _barrage_area(row))
			fx.charge_barrage_row(row, 0.)
	boss.winding = true
	boss.warning = fx.marks[0]
	world.SFX.play_world_sfx_3d(&"enemy_fire_cue", boss.model.global_position, 1.2, 38.)
	event.emit(&"windup", {"attack":NAMES[attack], "target":aim, "time":elapsed})
	return true

func _windup(delta: float) -> void:
	if attack == Attack.MISSILES:
		_missiles(delta)
		return
	var duration: float = WINDUPS[attack]
	var progress := clampf(age/duration, 0., 1.)
	var here := origin()
	match attack:
		Attack.SLAM:
			_hold(delta)
			fx.mark(0, aim, FX.LANDING_RADIUS)
		Attack.STOMP:
			_stomp_pose(.64*progress)
			fx.mark(0, aim, STOMP_RADIUS)
		Attack.LASER, Attack.BURST:
			rig.open_lid(progress)
			fx.show_core(boss.model.position, boss.model.rotation.y, rig.lid_open, false)
			fx.charge_laser(boss.model.position,boss.model.rotation.y,progress,attack==Attack.BURST)
			if attack == Attack.LASER:
				var forward := _forward(boss.model.rotation.y)
				fx.warn_line(here, _wall_end(here, here+forward*LASER_RANGE), 1.10, progress)
		Attack.BARRAGE:
			_hold(delta)
			for row in FX.BARRAGE_ROWS:
				fx.charge_barrage_row(row, age/(duration+row*BARRAGE_GAP+BARRAGE_FLIGHT_TIME))
		Attack.CHARGE:
			_walk(here, delta, here+heading*10.)
			fx.warn_line(here, _wall_end(here, here+heading*30.), PLAN.CRAWLER_RADIUS*2., progress)
		Attack.CANNON:
			_walk(here, delta, aim)
			rig.aim_cannon(world.to_global(Vector3(aim.x, 2.7, aim.y)))
			var muzzle := world.to_local(rig.cannon_muzzle())
			var start := Vector2(muzzle.x, muzzle.z)
			var axis := rig.cannon.global_basis.z
			var forward := Vector2(axis.x, axis.z).normalized()
			fx.warn_line(start, _wall_end(start, start+forward*LASER_RANGE), 1.25, progress)
	fx.charge_warning(progress)
	if age >= duration and (attack != Attack.CANNON or not shell_active):
		_activate()

func _activate() -> void:
	state = State.ACTIVE
	age = 0.
	boss.winding = false
	fx.clear_windup()
	match attack:
		Attack.CANNON:
			rig.fire_cannon()
			var muzzle := rig.cannon_muzzle()
			var local := world.to_local(muzzle)
			shell_at = Vector2(local.x, local.z)
			shell_height = local.y
			var forward := rig.cannon.global_basis.z
			shell_direction = Vector2(forward.x, forward.z).normalized()
			shell_distance = 0.
			shell_active = true
			fx.shell.position = local
			fx.shell.show()
			fx.muzzle(muzzle, Vector3(shell_direction.x, 0, shell_direction.y))
			world.SFX.play_world_sfx_3d(&"wall_break", muzzle, 1.0, 42.)
			event.emit(&"cannon_fired", {"at":shell_at, "direction":shell_direction, "recoil":rig.recoil})
		Attack.SLAM:
			fx.mark(0, aim, FX.LANDING_RADIUS)
			fx.charge_mark(0, 1.0)
			leap_landed = false
			if not motion.begin_jump(Vector3(aim.x, 0, aim.y), 9.6, .5):
				_recover()
				return
			event.emit(&"jump_started", {"at":aim, "time":elapsed})
		Attack.LASER, Attack.BURST:
			spin_progress = 0.
			spin_start_yaw = boss.model.rotation.y
			if attack == Attack.BURST:
				burst_used = true
				burst_pending = false
				burst_did_hit = false
			_update_lasers()
			if attack == Attack.BURST:
				world.SFX.play_world_sfx_3d(&"wall_break", boss.model.global_position, 1.6, 42.)
				event.emit(&"burst_fired", {"beams":6, "time":elapsed})
			else:
				world.SFX.play_world_sfx_3d(&"h06_laser_sweep", boss.model.global_position + Vector3.UP * FX.EMITTER_HEIGHT, 0.0, 42.0)
				event.emit(&"laser_started", {"time":elapsed})
		Attack.STOMP:
			fx.mark(0, aim, STOMP_RADIUS)
			fx.charge_mark(0, 1.0)
		Attack.CHARGE:
			charge_distance = 0.
			charge_stuck = 0.
			event.emit(&"charge_started", {"at":origin(), "direction":heading, "time":elapsed})
		Attack.BARRAGE:
			_fire_barrage()

func _active(delta: float) -> void:
	match attack:
		Attack.CANNON: _cannon_recoil(delta)
		Attack.SLAM:
			motion.advance_jump(delta)
			boss.position = motion.position
			if motion.jump == MOTION.Jump.NONE and leap_landed: _recover()
		Attack.LASER, Attack.BURST: _update_lasers()
		Attack.CHARGE: _charge(delta)
		Attack.STOMP:
			_stomp_pose(.64+.36*clampf(age/.10, 0., 1.))
			if age >= .10: _stomp_impact()
		Attack.BARRAGE: _fire_barrage()

func _cast(a: Vector2, b: Vector2, mask: int) -> Dictionary:
	query.from = a*MOTION.PIXELS
	query.to = b*MOTION.PIXELS
	query.collision_mask = mask
	query.exclude = exclusions
	var space := motion.get_world_2d().direct_space_state
	# Loose pickups use a prop collision layer, but are not solid cover.
	for i in 8:
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not hit.collider.is_in_group(&"world_weapon_pickups"): return hit
		var ignored := query.exclude
		ignored.append(hit.rid)
		query.exclude = ignored
	return {}

func _wall_end(a: Vector2, b: Vector2) -> Vector2:
	var hit := _cast(a, b, BLOCKERS)
	return (hit.position as Vector2)/MOTION.PIXELS if not hit.is_empty() else b

func _arena_inset(radius: float) -> Rect2:
	return PLAN.ARENA_DECK.grow(-radius-.15)

func _placement_clear(at: Vector2, radius: float) -> bool:
	placement_circle.radius = radius*MOTION.PIXELS
	placement_query.transform = Transform2D(0, at*MOTION.PIXELS)
	return motion.get_world_2d().direct_space_state.intersect_shape(placement_query, 1).is_empty()

func _safe_landing(target: Vector2, radius: float) -> Vector2:
	var safe := _arena_inset(radius)
	var at := target.clamp(safe.position, safe.end)
	if _placement_clear(at, radius): return at
	# Search both lateral directions as well as depth. A pillar next to the
	# target must not always pull a sideways leap back to the arena centre.
	for ring in range(1, 5):
		var best := Vector2.INF
		var best_distance := INF
		for index in 8:
			var candidate := (at+Vector2.from_angle(index*TAU/8.)*(ring*1.25)).clamp(safe.position, safe.end)
			var distance := candidate.distance_squared_to(target)
			if distance < best_distance and _placement_clear(candidate, radius):
				best = candidate
				best_distance = distance
		if best.is_finite(): return best
	return PLAN.BOSS_MARK if _placement_clear(PLAN.BOSS_MARK, radius) else origin()

func _damage(amount: float, source: StringName, at: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	if world.player.dead: return
	world.player.receive_damage(amount, source, at*MOTION.PIXELS, direction)

func _blast(at: Vector2, radius: float, damage: float, source: StringName, height := .15, explosive := true) -> void:
	if explosive: fx.explosion(at, 2., height)
	var player := player_at()
	if player.distance_to(at) <= radius and (player==at or _cast(at, player, BLOCKERS).is_empty()):
		_damage(damage, source, at, at.direction_to(player))
	if is_instance_valid(cargo): cargo.break_in_radius(at,radius,source)
	world.request_camera_impulse(&"heavy" if source==&"h06_slam" else &"medium", at.direction_to(player))

func _cannon_recoil(delta: float) -> void:
	var remaining := clampf(1.0-(age-delta)/CANNON_KICK_TIME, 0., 1.)
	var kick := -shell_direction * (7.4*remaining*remaining)
	var here := origin()
	motion.velocity = kick*MOTION.PIXELS
	_walk(here+kick*delta, delta, here+_forward(boss.model.rotation.y))
	if age >= CANNON_KICK_TIME: _recover()

func _advance_shell(delta: float) -> void:
	var next := shell_at+shell_direction*26.*delta
	var hit := _cast(shell_at, next, 1 | 2 | 16 | BLOCKERS)
	if not hit.is_empty():
		var normal: Vector2 = hit.normal
		var at: Vector2 = hit.position/MOTION.PIXELS+normal*.035
		fx.shell.hide()
		shell_active = false
		_blast(at, 3., 25., &"h06_cannon", shell_height)
		event.emit(&"cannon_impact", {"at":at, "collider":str(hit.collider.name), "normal":normal, "time":elapsed})
		return
	shell_distance += shell_at.distance_to(next)
	shell_at = next
	fx.shell.position = Vector3(shell_at.x, shell_height, shell_at.y)
	if shell_distance >= 90.:
		fx.shell.hide()
		shell_active = false

func _lock_missile() -> void:
	var marker := fx.available_lock_mark()
	if marker < 0: return
	var index := targets.size()
	var at := player_at()
	targets.append({"at":at, "launch_age":age+LAUNCH_DELAY, "marker":marker})
	fx.mark(marker, at, MISSILE_RADIUS)
	fx.charge_mark(marker, 0.0)
	world.SFX.play_world_sfx_3d(&"enemy_fire_cue", world.to_global(Vector3(at.x, .1, at.y)), .6, 28.)
	event.emit(&"lock", {"index":index, "at":at, "time":elapsed})

func _launch_rocket(tube: int, at: Vector2, marker: int, row: int = -1) -> bool:
	var slot := fx.available_rocket()
	if slot < 0: return false
	var muzzle := rig.fire_port(tube)
	var tube_direction := rig.launch_direction()
	var flight := Rocket.new()
	flight.slot = slot
	flight.index = tube
	flight.marker = marker
	flight.row = row
	flight.start = world.to_local(muzzle)
	flight.end = Vector3(at.x, .11, at.y)
	flight.first_tangent = flight.start+tube_direction*1.65
	var distance := Vector2(flight.start.x,flight.start.z).distance_to(at)
	flight.last_tangent = flight.end+Vector3.UP*clampf(distance*.16,1.9,3.8)
	flight.launched_at = elapsed
	flight.duration = BARRAGE_FLIGHT_TIME if row >= 0 else clampf(.47+distance*.014,.53,.78)
	rockets.append(flight)
	var rocket := fx.missiles[slot]
	rocket.position = flight.start
	rocket.quaternion = Quaternion(Vector3.FORWARD, tube_direction)
	rocket.show()
	# Every tube shows its rocket. Share one muzzle flash for a simultaneous row.
	if row < 0 or tube == 2:
		fx.muzzle(muzzle, tube_direction)
	if row < 0:
		event.emit(&"missile_launched", {"index":tube, "port":tube, "at":muzzle, "target":at, "elevation":rig.elevation, "time":elapsed, "flight":flight.duration})
	return true

func _missiles(delta: float) -> void:
	_walk(origin(), delta, player_at())
	if launched < targets.size():
		var target := targets[launched]
		fx.charge_mark(target.marker, .46*(1.-clampf((float(target.launch_age)-age)/LAUNCH_DELAY, 0., 1.)))
		if age >= float(target.launch_age) and _launch_rocket(launched, target.at, target.marker):
			target.left_tube_at = elapsed
			launched += 1
	if launched == MISSILE_COUNT:
		_recover()
		return
	if launched == targets.size():
		var tube_cleared := launched == 0 or elapsed-float(targets.back().left_tube_at) >= .06
		if tube_cleared and age >= FIRST_LOCK+targets.size()*LOCK_INTERVAL:
			_lock_missile()

func _barrage_area(row: int) -> Rect2:
	var arena := PLAN.ARENA_DECK
	var depth := arena.size.y/FX.BARRAGE_ROWS
	var center := arena.position.y+(row+.5)*depth
	return Rect2(arena.position.x,center-BARRAGE_DEPTH*.5,arena.size.x,BARRAGE_DEPTH)

func _barrage_point(area: Rect2, index: int) -> Vector2:
	return Vector2(area.position.x+(index+.5)*area.size.x/MISSILE_COUNT,area.get_center().y)

func _fire_barrage() -> void:
	if age < launched_rows*BARRAGE_GAP or rockets.size()+MISSILE_COUNT > fx.missiles.size(): return
	var area := _barrage_area(launched_rows)
	for tube in MISSILE_COUNT:
		_launch_rocket(tube, _barrage_point(area,tube), -1, launched_rows)
	event.emit(&"barrage_row_fired", {"row":launched_rows,"count":MISSILE_COUNT,"time":elapsed})
	launched_rows += 1
	if launched_rows == FX.BARRAGE_ROWS: _recover()

func _advance_rockets(delta: float) -> void:
	if rockets.is_empty(): return
	var landed_rows := 0
	for i in range(rockets.size()-1,-1,-1):
		var flight := rockets[i]
		var rocket := fx.missiles[flight.slot]
		var flight_age := elapsed-flight.launched_at
		var t := clampf(flight_age/flight.duration,0.,1.)
		var point := flight.start.bezier_interpolate(flight.first_tangent,flight.last_tangent,flight.end,t)
		var direction := (point-rocket.position).normalized()
		rocket.position = point
		if not direction.is_zero_approx():
			var rotation := Quaternion(Vector3.FORWARD,direction)
			rocket.quaternion = rocket.quaternion.slerp(rotation,minf(1.,delta*26.))
			var trail_rate := 10. if flight.row >= 0 else 20.
			if int(flight_age*trail_rate) != int((flight_age-delta)*trail_rate):
				fx.exhaust(rocket.global_position,direction,1 if flight.row >= 0 else 3)
		if flight.marker > 0:
			fx.charge_mark(flight.marker,lerpf(.46,1.,t))
		elif flight.index == 0:
			fx.charge_barrage_row(flight.row,lerpf(.46,1.,t))
		if t >= 1.:
			var at := Vector2(flight.end.x,flight.end.z)
			rocket.hide()
			rockets.remove_at(i)
			if flight.row >= 0:
				fx.barrage_impact(at,flight.index==1 or flight.index==4)
				landed_rows |= 1 << flight.row
			else:
				fx.marks[flight.marker].hide()
				_blast(at,MISSILE_RADIUS,18.,&"h06_missile")
				event.emit(&"missile_impact", {"index":flight.index,"at":at,"time":elapsed,"flight":flight_age})
	for row in FX.BARRAGE_ROWS:
		if (landed_rows & (1 << row)) != 0:
			_resolve_barrage_row(row)

func _resolve_barrage_row(row: int) -> void:
	fx.salvo_rows[row].hide()
	var area := _barrage_area(row)
	var player := player_at()
	var nearest := Vector2.INF
	if area.has_point(player):
		var column := clampi(floori((player.x-area.position.x)*MISSILE_COUNT/area.size.x),0,MISSILE_COUNT-1)
		nearest = _barrage_point(area,column)
		if player == nearest or _cast(nearest,player,BLOCKERS).is_empty():
			_damage(18.,&"h06_barrage",nearest,nearest.direction_to(player))
	if is_instance_valid(cargo): cargo.break_in_area(area,origin(),&"h06_barrage")
	world.request_camera_impulse(&"medium",area.get_center().direction_to(player))
	event.emit(&"barrage_row_impact", {"row":row,"count":MISSILE_COUNT,"time":elapsed})

func _landed() -> void:
	if stopped or state != State.ACTIVE or attack != Attack.SLAM: return
	leap_landed = true
	var at := origin()
	fx.marks[0].hide()
	fx.landing(boss.model.position, motion.gait.legs, FX.LANDING_RADIUS)
	_blast(at, FX.LANDING_RADIUS, 25., &"h06_slam", .15, false)
	world.SFX.play_world_sfx_3d(&"wall_break", boss.model.global_position, 1.6, 42.)
	event.emit(&"slam_impact", {"at":at, "radius":FX.LANDING_RADIUS, "smoke":fx.smoke_bursts})

func _update_lasers() -> void:
	var radial := attack == Attack.BURST
	var duration := BURST_DURATION if radial else LASER_SWEEP
	var sweep := BURST_SWEEP if radial else TAU
	var previous := spin_progress
	var progress := clampf(age/duration,0.,1.)
	spin_progress = sweep*(.50*progress+.50*progress*progress)
	var center := origin()
	var height: float = boss.model.position.y+FX.EMITTER_HEIGHT
	var target := player_at()
	fx.show_core(boss.model.position,spin_start_yaw,rig.lid_open,true)
	var ray_count := 6 if radial else 1
	for index in ray_count:
		var base_yaw := spin_start_yaw+index*TAU/6.
		var forward := _forward(base_yaw+spin_progress)
		var start := center+forward*FX.EMITTER_RADIUS
		var hit := _cast(start,start+forward*LASER_RANGE,BLOCKERS)
		var end: Vector2 = start+forward*LASER_RANGE if hit.is_empty() else hit.position/MOTION.PIXELS
		var wall_side := 0.0
		var contact_normal := Vector2.ZERO
		if not hit.is_empty():
			var collider: Object = hit.collider
			wall_side = float(collider.get_meta(&"h06_shaft_wall_side",0.0))
			if height*MOTION.PIXELS <= float(collider.get_meta(&"shot_height_pixels",0.0)):
				contact_normal = hit.normal
		fx.set_laser(Vector3(start.x,height,start.y),Vector3(end.x,height,end.y),index,
			wall_side,LASER_RANGE,contact_normal,age,radial)
		if hit_left<=0. and (not radial or not burst_did_hit) and _laser_crossed_target(target,center,start,end,base_yaw,previous):
			_damage(12.,&"h06_burst" if radial else &"h06_laser",target,forward)
			hit_left = .40
			burst_did_hit = radial
			event.emit(&"laser_contact", {"at":target,"radial":radial})
		if is_instance_valid(cargo):
			_cut_cargo(hit,center,base_yaw,previous,&"h06_burst" if radial else &"h06_laser")
	fx.apply_laser_illumination(ray_count)
	if progress >= 1.0:
		var completion := &"burst_complete" if radial else &"laser_complete"
		event.emit(completion, {"rotation":spin_progress,"duration":age})
		_recover()

func _cut_cargo(hit: Dictionary, center: Vector2, base_yaw: float, previous: float, source: StringName) -> void:
	if not hit.is_empty(): cargo.break_body(hit.collider,center,source)
	# A fast sweep can pass a container between two visible beam positions.
	for drop in cargo.drops:
		if drop.phase!=CARGO.Phase.LANDED: continue
		var at := drop.rect.get_center()
		var bearing := center.direction_to(at)
		var crossed := fposmod(atan2(bearing.x,bearing.y)-base_yaw-previous,TAU)
		if crossed > spin_progress-previous: continue
		var contact := _cast(center+bearing*FX.EMITTER_RADIUS,at,BLOCKERS)
		if contact.get("collider")==drop.body: cargo.break_body(drop.body,center,source)

func _laser_crossed_target(target: Vector2, center: Vector2, start: Vector2, end: Vector2, base_yaw: float, previous: float) -> bool:
	var nearest := Geometry2D.get_closest_point_to_segment(target,start,end)
	if start.distance_squared_to(end) > .001 and target.distance_to(nearest) < LASER_WIDTH:
		return target==start or _cast(start,target,BLOCKERS).is_empty()
	# Fast sweeps also cover angles crossed between consecutive physics frames.
	var distance := center.distance_to(target)
	if distance < FX.EMITTER_RADIUS or distance > FX.EMITTER_RADIUS+LASER_RANGE: return false
	var bearing := center.direction_to(target)
	var crossed := fposmod(atan2(bearing.x,bearing.y)-base_yaw-previous,TAU)
	if crossed > spin_progress-previous: return false
	var swept_start := center+bearing*FX.EMITTER_RADIUS
	return target==swept_start or _cast(swept_start,target,BLOCKERS).is_empty()

func _choose_stomp(at: Vector2) -> bool:
	stomp_leg = -1
	var best := INF
	for i in motion.gait.legs.size():
		var leg: Dictionary = motion.gait.legs[i]
		var desired := Vector3(at.x, 0., at.y)
		var point := motion.gait.stomp_target(i, desired)
		var error := at.distance_to(Vector2(point.x, point.z))
		var plant: Vector3 = leg.plant
		var stride := Vector2(plant.x,plant.z).distance_to(Vector2(point.x,point.z))
		var score := error+stride*.4
		if error < STOMP_RADIUS-.12 and stride < 2.15 and score < best:
			best = score
			stomp_leg = i
			stomp_from = leg.ankle.global_position
			stomp_to = point
	return stomp_leg >= 0

func _stomp_pose(progress: float) -> void:
	var foot := stomp_from.lerp(stomp_to, smoothstep(0., 1., progress))
	foot.y += sin(PI*progress)*.86
	motion.pose_stomp(stomp_leg, foot, progress >= 1.)

func _stomp_impact() -> void:
	var foot: Vector3 = motion.gait.legs[stomp_leg].ankle.global_position
	var at := Vector2(foot.x, foot.z)
	fx.stomp(Vector3(at.x,0.,at.y))
	_blast(at, STOMP_RADIUS, 25., &"h06_stomp", .15, false)
	world.SFX.play_world_sfx_3d(&"wall_break", foot, 1.05, 35.)
	event.emit(&"stomp_impact", {"leg":stomp_leg, "at":at})
	stomp_cooldown = 2.75
	_recover()

func _charge(delta: float) -> void:
	var before := origin()
	_walk(before+heading*14.*delta, delta, before+heading*15.)
	if is_instance_valid(cargo):
		for index in motion.get_slide_collision_count():
			var collision := motion.get_slide_collision(index)
			if cargo.break_body(collision.get_collider(),before,&"h06_charge"):
				_stun(&"cargo_charge")
				return
	var moved := before.distance_to(origin())
	charge_distance += moved
	charge_stuck = charge_stuck+delta if moved < .008 else 0.
	if motion.contact_player:
		_damage(25., &"h06_charge", origin(), heading)
		event.emit(&"charge_contact", {"at":origin()})
		_recover()
	elif charge_distance >= 13. or age >= 1.65 or charge_stuck > .13:
		fx.landing(boss.model.position, motion.gait.legs)
		world.request_camera_impulse(&"medium", heading)
		event.emit(&"charge_finished", {"distance":charge_distance, "blocked":charge_stuck>.13, "at":origin()})
		_recover()

func health_changed(ratio: float, player_damage := 0.0) -> void:
	health_ratio = ratio
	if ratio > 0. and ratio <= SHIELD_HEALTH and is_instance_valid(cargo) and not practice_single:
		cargo.release(origin())
	if ratio > 0. and ratio < .5 and not burst_used: burst_pending = true
	if state==State.STUNNED and ratio>0.:
		stun_damage += player_damage
		if stun_damage>STUN_DAMAGE_LIMIT:
			finish_stun(&"damage")
	fx.shield.set_shield_active(ratio>0. and ratio<=SHIELD_HEALTH and state!=State.STUNNED)

func _stun(source: StringName) -> void:
	if state!=State.STUNNED:
		stun_damage = 0.0
		cancel_projectiles()
		rig.reset()
		boss.set_stun_lamps(true)
		boss.winding = false
		if motion.jump!=MOTION.Jump.NONE:
			var at := origin()
			motion.teleport(Vector3(at.x,0.,at.y))
	state = State.STUNNED
	stun_left = STUN_DURATION
	fx.shield.set_shield_active(false)
	motion.pose_stun(.29,.14)
	event.emit(&"cargo_stun",{"source":source,"at":origin(),"time":elapsed})

func _advance_stun(delta: float) -> void:
	stun_left = maxf(0.,stun_left-delta)
	if stun_left <= .00001:
		finish_stun(&"timer")
		return
	var stun_age := STUN_DURATION-stun_left
	var wobble := exp(-stun_age*7.)*cos(stun_age*19.)
	motion.pose_stun(.25+wobble*.09,wobble*.14)

func finish_stun(reason: StringName) -> void:
	if state!=State.STUNNED: return
	state = State.REST
	wait = INTER_ATTACK_GAP
	stun_left = 0.0
	motion.pose_stun(0.,0.)
	boss.set_stun_lamps(false)
	fx.shield.set_shield_active(health_ratio>0. and health_ratio<=SHIELD_HEALTH)
	event.emit(&"cargo_stun_finished",{"reason":reason,"damage":stun_damage,"time":elapsed})

func _rear_plate_hit(at: Vector2) -> bool:
	var local := motion.to_local(at)/MOTION.PIXELS
	return local.y <= -1.50 and absf(local.x) < 1.13

func _is_full_damage_hit(at: Vector2, source: StringName) -> bool:
	if source == &"": return true
	if String(source).contains("projectile"): return _rear_plate_hit(at)
	if source == &"burning": return false
	var attacker := motion.to_local(player_at()*MOTION.PIXELS)/MOTION.PIXELS
	return attacker.y < -1.50 and absf(attacker.x) <= -attacker.y*.80

func damage_factor(at: Vector2, source: StringName) -> float:
	return 1.0 if _is_full_damage_hit(at, source) else ARMOR_FACTOR

func blocks_projectile_penetration(at: Vector2, direction: Vector2, height: float) -> bool:
	if not fx.shield.is_shield_active() or _rear_plate_hit(at): return false
	var point := at/MOTION.PIXELS-direction*.06
	var impact := Vector3(point.x, clampf(height,.65,1.45)+boss.model.position.y, point.y)
	fx.shield_impact(impact, direction)
	world.SFX.play_world_sfx_3d(&"h06_shield_hit", world.to_global(impact), 0.0, 28.0)
	event.emit(&"shield_block", {"at":at, "direction":direction})
	return true

func _recover() -> void:
	fx.clear_windup()
	rig.raise_launcher = false
	rig.relax_cannon = true
	state = State.RECOVER
	age = 0.
	boss.winding = false
	event.emit(&"attack_finished", {"attack":NAMES[attack]})

func _recovery(delta: float) -> void:
	_hold(delta)
	if attack == Attack.LASER or attack == Attack.BURST:
		rig.open_lid(1.-age/RECOVER_TIME)
		fx.show_core(boss.model.position, boss.model.rotation.y, rig.lid_open, false)
	if age >= RECOVER_TIME:
		state = State.REST
		wait = INTER_ATTACK_GAP
		event.emit(&"recovered", {"attack":NAMES[attack]})

func cancel_projectiles() -> void:
	rockets.clear()
	shell_active = false
	fx.clear()

func stop() -> void:
	if stopped: return
	stopped = true
	if is_instance_valid(motion) and motion.landed.is_connected(_landed): motion.landed.disconnect(_landed)
	if is_instance_valid(cargo):
		if cargo.event.is_connected(_forward_cargo_event):
			cargo.event.disconnect(_forward_cargo_event)
		cargo.finish()
	if is_instance_valid(fx):
		cancel_projectiles()
		fx.queue_free()
