extends Node3D
## The 0-2 shutter ambush is owned by the generated garage floor.

const VAN := preload("res://scenes/dream/props/vehicles/VehicleCargoVan.tscn")
const SMOKE_SHADER := preload("res://shaders/dream3d/firearm_smoke_fx.gdshader")
const GARAGE_ART := preload("res://scripts/testing/parking_garage_art.gd")
const ENGINE_STREAM := preload("res://sfx/parking/van_engine.wav")
const SHUTTER_STREAM := preload("res://sfx/parking/roller_shutter.wav")
const CRASH_STREAM := preload("res://sfx/parking/van_crash.wav")
const BRAKE_STREAM := preload("res://sfx/parking/van_brake.wav")
const DOOR_STREAM := preload("res://sfx/parking/van_doors.wav")
const TRIGGER_Z := 15.15
const CAMERA_FOCUS := Vector2(7.25, 8.55)
const CAMERA_LEAD_IN := .42
const CAMERA_IMPACT_HOLD := .22
const CAMERA_RETURN_TIME := .26
const ACTOR_COLLISION_MASK := 1 | 2
const SHUTTER_CLOSE_TIME := .82
const SHUTTER_TAIL_CLEARANCE := .28
const OPEN_DOORS_AT := .40
const DOOR_OPEN_TIME := .32
const EXIT_STEP_TIME := .39
const SMOKE_COUNT := 18
const LOADOUTS := ["lucille", "lucille", "lucille", "shotgun"]

enum Stage { WAITING, DRIVING, CRASHED, COMPLETE }

var stage := Stage.WAITING
var van: Node3D
var blocker: AnimatableBody2D
var doors: Node3D
var smoke: MultiMeshInstance3D
var troops: Array[EmployeeEnemy] = []
var impact_point := Vector3.ZERO

var _world: Node3D
var _gate: Node3D
var _hall: Rect2i
var _origin := Vector2.ZERO
var _room_id := -1
var _previous_player := Vector2.ZERO
var _column := PackedVector2Array()
var _van_hull := PackedVector2Array()
var _impact_hull := ConvexPolygonShape2D.new()
var _impact_query := PhysicsShapeQueryParameters2D.new()
var _route := Curve2D.new()
var _focus := Node2D.new()
var _camera_owned := false
var _previous_zoom := 1.0
var _stage_time := 0.0
var _travel := 0.0
var _shutter_elapsed := -1.0
var _rear := 0.0
var _nose := 0.0
var _smoke_origin := Vector3.ZERO
var _passenger: EmployeeEnemy
var _exit_start := Vector2.ZERO
var _exit_end := Vector2.ZERO
var _step_elapsed := 0.0
var _next_exit := 0.0
var engine_voice: AudioStreamPlayer3D
var brake_voice: AudioStreamPlayer3D
var shutter_played := false
var doors_played := false
var brake_started := false


func configure(world: Node3D, gate: Node3D, column: Rect2, hall: Rect2i, room_id: int = -1) -> void:
	_world = world
	_gate = gate
	_hall = hall
	_origin = Vector2(global_position.x, global_position.z)
	_room_id = world.spawn_room_id if room_id < 0 else room_id
	_previous_player = _player_at()
	_column = PackedVector2Array([column.position, Vector2(column.end.x, column.position.y),
		column.end, Vector2(column.position.x, column.end.y)])
	van = VAN.instantiate()
	add_child(van)
	van.hide()
	doors = van.get_node("RearDoors")
	var trim_bounds: AABB = van.get_node("BumpersAndTrim").get_aabb()
	_rear = trim_bounds.position.z
	_nose = trim_bounds.end.z
	var width: float = van.get_meta(&"vehicle_footprint").x * .5
	_van_hull = PackedVector2Array([
		Vector2(-.89, _rear), Vector2(.89, _rear), Vector2(width, _rear + .50),
		Vector2(width, _nose - .67), Vector2(.83, _nose), Vector2(-.83, _nose),
		Vector2(-width, _nose - .67), Vector2(-width, _rear + .50),
	])
	_impact_query.shape = _impact_hull
	_impact_query.collision_mask = ACTOR_COLLISION_MASK
	# The nose enters straight through the shutter before drifting right.
	_route.bake_interval = .05
	_route.add_point(Vector2(gate.position.x - .36, gate.position.z - _nose - .55),
		Vector2.ZERO, Vector2(0, 5.2))
	_route.add_point(Vector2(10.20, 12.10), Vector2(-2.62, -7.70))
	for mesh: MeshInstance3D in van.find_children("*", "MeshInstance3D", true, false):
		mesh.set_instance_shader_parameter("reveal_after_z", gate.global_position.z)
	add_child(_focus)
	_attach_engine()
	_attach_brake()


func get_camera_weight() -> float:
	return _world.dialogue_camera.get_dialogue_weight() if _camera_owned else 0.0


func begin_player_tracking() -> void:
	_previous_player = _player_at()
	set_physics_process(true)


func reset_camera() -> void:
	_silence_engine()
	_silence_brake()
	if _camera_owned:
		_world.clear_dialogue_focus()
		_restore_zoom()


func release_for_area_exit() -> float:
	_silence_engine()
	_silence_brake()
	if not _camera_owned:
		return -1.0
	# The shared camera freezes its last focus and can finish after this
	# encounter and its focus node have been freed.
	_return_camera()
	_camera_owned = false
	return _previous_zoom


func _restore_zoom() -> void:
	_world.dialogue_camera.dialogue_zoom_factor = _previous_zoom
	_camera_owned = false


func _return_camera() -> void:
	if _camera_owned:
		_world.dialogue_camera.end_dialogue_focus(CAMERA_RETURN_TIME)


func _player_at() -> Vector2:
	return _world._player_ground_anchor_position() / _world.CELL_PIXELS - _origin


func _physics_process(delta: float) -> void:
	if stage == Stage.WAITING:
		var at := _player_at()
		if not _world.player.dead and _previous_player.y > TRIGGER_Z and at.y <= TRIGGER_Z:
			var x := lerpf(_previous_player.x, at.x, inverse_lerp(_previous_player.y, at.y, TRIGGER_Z))
			if x >= _hall.position.x - .5 and x < _hall.end.x - .5:
				_start_drive()
		_previous_player = at
		return
	_stage_time += delta
	if _camera_owned:
		match _world.dialogue_camera.state:
			Dream3DDialogueCamera.FocusState.INACTIVE:
				_restore_zoom()
			Dream3DDialogueCamera.FocusState.ENTERING, Dream3DDialogueCamera.FocusState.ACTIVE:
				if _world.player.dead:
					_return_camera()
				elif stage == Stage.DRIVING:
					_update_focus()
	if stage == Stage.DRIVING and is_instance_valid(engine_voice):
		_update_engine_pitch()
	if stage == Stage.DRIVING:
		if _stage_time >= CAMERA_LEAD_IN:
			_drive(delta)
			_update_shutter(delta)
		return
	_update_shutter(delta)
	if is_instance_valid(smoke):
		_update_smoke()
	if stage == Stage.CRASHED:
		_disembark(delta)
	if stage == Stage.COMPLETE and not _camera_owned and not is_instance_valid(smoke):
		set_physics_process(false)


func _update_focus() -> void:
	var at := _player_at()
	var local_focus := Vector2(clampf(CAMERA_FOCUS.x, at.x - 7.0, at.x + 7.0),
		clampf(CAMERA_FOCUS.y, at.y - 7.0, at.y + 7.0))
	_focus.position = (local_focus + _origin) * _world.CELL_PIXELS


func _start_drive() -> void:
	stage = Stage.DRIVING
	_update_focus()
	_previous_zoom = _world.dialogue_camera.dialogue_zoom_factor
	_world.dialogue_camera.dialogue_zoom_factor = 1.0
	_camera_owned = true
	_world.begin_dialogue_focus(_focus, Dream3DDialogueCamera.FocusMode.SPEAKER_FOCUS)
	blocker = AnimatableBody2D.new()
	blocker.name = "CargoVanBody"
	blocker.sync_to_physics = false
	blocker.collision_layer = 4
	blocker.collision_mask = 0
	var hull := CollisionPolygon2D.new()
	var pixel_scale: float = _world.CELL_PIXELS
	hull.polygon = Transform2D(Vector2.RIGHT * pixel_scale, Vector2.DOWN * pixel_scale, Vector2.ZERO) * _van_hull
	blocker.add_child(hull)
	_place_van(_route.sample_baked_with_rotation(0.0, true))
	add_child(blocker)
	van.show()
	if is_instance_valid(engine_voice):
		engine_voice.volume_db = -5.0
		engine_voice.play()


func _drive(delta: float) -> void:
	var speed := lerpf(5.4, 9.0, smoothstep(0.0, .68, _stage_time - CAMERA_LEAD_IN))
	var next := minf(_route.get_baked_length(), _travel + speed * delta)
	var pose := _route.sample_baked_with_rotation(next, true)
	var hit := _hits_column(pose)
	if hit:
		# Refine the contact so the wreck never penetrates the concrete pillar.
		var inside := next
		next = _travel
		for iteration in 8:
			var mid := (next + inside) * .5
			if _hits_column(_route.sample_baked_with_rotation(mid, true)):
				inside = mid
			else:
				next = mid
		pose = _route.sample_baked_with_rotation(next, true)
	if next > _travel:
		_hit_actors(pose)
	_place_van(pose)
	_start_brake()
	for wheel: Node3D in van.get_node("Wheels").get_children():
		wheel.get_node("Spin").rotation.x += (next - _travel) / wheel.position.y
	_travel = next
	if hit:
		_crash(pose.x)


func _hit_actors(pose: Transform2D) -> void:
	# Cover the space the physical footprint crosses, including the turn.
	var px: float = _world.CELL_PIXELS
	var gameplay := Transform2D(Vector2.RIGHT * px, Vector2.DOWN * px, _origin * px)
	var previous := _route.sample_baked_with_rotation(_travel, true)
	var corners := (gameplay * _body_pose(previous)) * _van_hull
	corners.append_array((gameplay * _body_pose(pose)) * _van_hull)
	var sweep := Geometry2D.convex_hull(corners)
	sweep.resize(sweep.size() - 1) # Geometry2D repeats the first vertex at the end.
	_impact_hull.points = sweep
	var space: PhysicsDirectSpaceState2D = _world.player.get_world_2d().direct_space_state
	var impact_origin := gameplay * previous.origin
	for contact: Dictionary in space.intersect_shape(_impact_query):
		var actor: Object = contact.collider
		if actor == _world.player:
			_world.player.force_hazard_death(&"vehicle_impact")
		elif actor is EmployeeEnemy and int(actor.get_meta(&"dream_room_id", -1)) == _room_id:
			var impulse := 340.0 if bool(actor.get_meta(&"garage_crash_guard", false)) else 1.0
			actor.take_damage(actor.current_health, impact_origin, impulse, &"vehicle_impact")


func _body_pose(pose: Transform2D) -> Transform2D:
	return Transform2D(-pose.y, pose.x, pose.origin)


func _hits_column(pose: Transform2D) -> bool:
	return not Geometry2D.intersect_polygons(_body_pose(pose) * _van_hull, _column).is_empty()


func _place_van(pose: Transform2D) -> void:
	# Curve2D's local X points forward. The vehicle's local +Z points forward.
	var yaw := atan2(pose.x.x, pose.x.y)
	van.position = Vector3(pose.origin.x, 0, pose.origin.y)
	van.rotation.y = yaw
	blocker.position = (pose.origin + _origin) * _world.CELL_PIXELS
	blocker.rotation = -yaw


func _update_shutter(delta: float) -> void:
	if _shutter_elapsed >= SHUTTER_CLOSE_TIME:
		return
	if _shutter_elapsed < 0.0:
		var tail_left := van.to_global(Vector3(-.90, 0, _rear)).z
		var tail_right := van.to_global(Vector3(.90, 0, _rear)).z
		if minf(tail_left, tail_right) < _gate.global_position.z + SHUTTER_TAIL_CLEARANCE:
			return
		_shutter_elapsed = 0.0
		_play_shutter()
	_shutter_elapsed = minf(_shutter_elapsed + delta, SHUTTER_CLOSE_TIME)
	GARAGE_ART.lower_vehicle_shutter(_gate, smoothstep(0.0, SHUTTER_CLOSE_TIME, _shutter_elapsed))


func _crash(forward: Vector2) -> void:
	stage = Stage.CRASHED
	_stage_time = 0.0
	if _camera_owned:
		# The exit beat follows wall time even when gameplay slows on contact.
		get_tree().create_timer(CAMERA_IMPACT_HOLD, false, true, true).timeout.connect(_return_camera)
	_next_exit = OPEN_DOORS_AT + DOOR_OPEN_TIME + .04
	impact_point = van.to_global(Vector3(.55, .48, _nose))
	_world.request_camera_impulse(&"heavy", forward)
	_silence_engine()
	_silence_brake()
	_play_one_shot(CRASH_STREAM, impact_point, 2.0, 32.0)
	if _world.has_method(&"duck_garage_bed"):
		_world.duck_garage_bed()
	_smoke_origin = to_local(van.to_global(Vector3(.12, 1.07, _nose - .33)))
	var material := ShaderMaterial.new()
	material.shader = SMOKE_SHADER
	material.set_shader_parameter("gun_smoke", Color("8a8a8a"))
	material.set_shader_parameter("contact_dust", Color("777777"))
	material.set_shader_parameter("glass_dust", Color("999999"))
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	puff.material = material
	var particles := MultiMesh.new()
	particles.transform_format = MultiMesh.TRANSFORM_3D
	particles.use_custom_data = true
	particles.mesh = puff
	particles.instance_count = SMOKE_COUNT
	particles.visible_instance_count = 0
	smoke = MultiMeshInstance3D.new()
	smoke.name = "HoodSmoke"
	smoke.multimesh = particles
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	_update_smoke()


func _update_smoke() -> void:
	var particles := smoke.multimesh
	var visible_puffs := 0
	for index in SMOKE_COUNT:
		var age := _stage_time - index * .18
		if age < 0.0:
			break
		var life := 2.55 + .19 * (index % 3)
		if age >= life:
			continue
		var phase := age / life
		var angle := index * 2.39996
		var expansion := sqrt(phase)
		var drift := Vector3(cos(angle) * .38 - .44, 1.24, sin(angle) * .51 + .17)
		var center := _smoke_origin + drift * expansion + Vector3(cos(angle) * .12, 0, sin(angle) * .14)
		var size := lerpf(.76, 1.78, expansion)
		particles.set_instance_transform(visible_puffs, Transform3D(Basis.from_scale(Vector3.ONE * size), center))
		particles.set_instance_custom_data(visible_puffs, Color(phase, fposmod(angle / TAU, 1.0), .54 + .16 * (index % 2), .64))
		visible_puffs += 1
	particles.visible_instance_count = visible_puffs
	if visible_puffs == 0 and _stage_time > SMOKE_COUNT * .18:
		smoke.queue_free()
		smoke = null


func _disembark(delta: float) -> void:
	if not doors_played and _stage_time >= OPEN_DOORS_AT:
		doors_played = true
		_play_one_shot(DOOR_STREAM, van.to_global(Vector3(0.0, 0.9, _rear)), -3.0, 18.0)
	var swing := smoothstep(OPEN_DOORS_AT, OPEN_DOORS_AT + DOOR_OPEN_TIME, _stage_time) * 1.67
	doors.get_node("Left").rotation.y = swing
	doors.get_node("Right").rotation.y = -swing
	if is_instance_valid(_passenger):
		_step_elapsed += delta
		var progress := clampf(_step_elapsed / EXIT_STEP_TIME, 0.0, 1.0)
		if not _passenger.dead:
			_passenger.global_position = _exit_start.lerp(_exit_end, progress)
			_passenger.knockdown_height = lerpf(17.0, 0.0, progress * progress)
			_passenger._update_human_animation(delta)
			if progress < 1.0:
				return
		_release_passenger()
	if troops.size() == LOADOUTS.size():
		stage = Stage.COMPLETE
	elif _stage_time >= _next_exit:
		_start_passenger()


func _start_passenger() -> void:
	var slot := troops.size()
	var side := -1.0 if slot % 2 == 0 else 1.0
	var sill := _van_gameplay_point(Vector2(side * .28, _rear + .08))
	var landing := Vector2.INF
	# Vary the exit side and leave room if a guard or the Player is at the door.
	for offset: Vector2 in [Vector2(side * 1.13, -1.13), Vector2(-side * 1.13, -1.13),
		Vector2(side * .36, -1.75), Vector2(-side * .68, -2.08), Vector2(side * 1.84, -.77),
		Vector2(-side * 1.84, -.77), Vector2(0, -2.60)]:
		var candidate := _van_gameplay_point(Vector2(offset.x, _rear + offset.y))
		if candidate.distance_to(_world.player.global_position) >= 28.0 and _world._content_position_is_clear(candidate, 14.0, false):
			landing = candidate
			break
	if not landing.is_finite():
		_next_exit = _stage_time + .12
		return
	var actor: EmployeeEnemy = _world._spawn_regular_employee(_room_id, sill, &"employee", false, LOADOUTS[slot])
	if actor == null:
		return
	actor.name = "VanShotgunner" if slot == LOADOUTS.size() - 1 else "VanMelee%d" % (slot + 1)
	actor.set_room_runtime_active(false)
	actor.set_room_preview_visible(true)
	actor.knockdown_height = 17.0
	actor.velocity = (landing - sill) / EXIT_STEP_TIME
	actor._update_weapon_aim()
	_passenger = actor
	_exit_start = sill
	_exit_end = landing
	_step_elapsed = 0.0
	troops.append(actor)


func _release_passenger() -> void:
	if not _passenger.dead:
		_passenger.knockdown_height = 0.0
		_passenger.velocity = Vector2.ZERO
		var player_at: Vector2 = _world.player.global_position
		_passenger.set_room_runtime_active(true)
		_passenger._apply_live_facing(_passenger.global_position.direction_to(player_at))
		_passenger._remember_target_position(player_at, _world.get_current_room_id())
		_passenger.hostile = true
		_passenger.state = EmployeeEnemy.State.ALERT
		_passenger._begin_hostile_reaction()
	_passenger = null
	_next_exit = _stage_time + .085


func _van_gameplay_point(local: Vector2) -> Vector2:
	var point := van.to_global(Vector3(local.x, 0, local.y))
	return Vector2(point.x, point.z) * _world.CELL_PIXELS


func _attach_engine() -> void:
	engine_voice = AudioStreamPlayer3D.new()
	engine_voice.name = "VanEngine"
	engine_voice.bus = &"Environment"
	engine_voice.volume_db = -5.0
	engine_voice.unit_size = 9.0
	engine_voice.max_distance = 34.0
	engine_voice.attenuation_model = 0
	engine_voice.panning_strength = 1.0
	var stream := ENGINE_STREAM.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine_voice.stream = stream
	van.add_child(engine_voice)
	engine_voice.position = Vector3(0.0, 0.7, 0.2)


func _update_engine_pitch() -> void:
	var driven := maxf(_stage_time - CAMERA_LEAD_IN, 0.0)
	var speed := 5.4 if driven <= 0.0 else lerpf(5.4, 9.0, smoothstep(0.0, 0.68, driven))
	engine_voice.pitch_scale = lerpf(0.94, 1.08, inverse_lerp(5.4, 9.0, speed))


func _silence_engine() -> void:
	_fade_voice(engine_voice, 0.06)


func _attach_brake() -> void:
	brake_voice = AudioStreamPlayer3D.new()
	brake_voice.name = "VanBrake"
	brake_voice.bus = &"Environment"
	brake_voice.stream = BRAKE_STREAM
	brake_voice.volume_db = -1.5
	brake_voice.unit_size = 8.0
	brake_voice.max_distance = 30.0
	brake_voice.attenuation_model = 0
	brake_voice.panning_strength = 1.0
	van.add_child(brake_voice)
	brake_voice.position = Vector3(0.0, 0.22, 0.35)


func _start_brake() -> void:
	if brake_started or not is_instance_valid(brake_voice):
		return
	brake_started = true
	brake_voice.play()


func _silence_brake() -> void:
	_fade_voice(brake_voice, 0.04)


func _fade_voice(voice: AudioStreamPlayer3D, seconds: float) -> void:
	if not is_instance_valid(voice) or not voice.playing:
		return
	var tween := create_tween()
	tween.tween_property(voice, "volume_db", -40.0, seconds)
	tween.tween_callback(voice.stop)


func _play_shutter() -> void:
	if shutter_played:
		return
	shutter_played = true
	_play_one_shot(SHUTTER_STREAM, _gate.global_position + Vector3(0.0, 1.4, 0.0), -1.0, 26.0)


func _play_one_shot(stream: AudioStream, at: Vector3, db: float, distance: float) -> void:
	var voice := AudioStreamPlayer3D.new()
	voice.bus = &"Environment"
	voice.stream = stream
	voice.volume_db = db
	voice.unit_size = 8.0
	voice.max_distance = distance
	voice.attenuation_model = 0
	voice.panning_strength = 1.0
	add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	voice.play()
