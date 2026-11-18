extends CharacterBody2D
## The only moving gameplay body for the displayed H06, including its six legs.
## X/Z and swept collision use the existing 2D gameplay space; Y is a ballistic height.
signal took_off
signal landed
signal jump_finished
const GAIT := preload("res://scripts/testing/h06_chapter/crawler_gait.gd")
const MOVE_AUDIO := preload("res://scripts/testing/h06_chapter/crawler_move_audio.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const ROAD_LAYER := 1 << 20
const PIXELS := 32.0
const GRAVITY := 16.5
enum Jump { NONE, CROUCH, PUSH, FLIGHT, COMPRESS, RECOVER }
var world: Node3D
var model: Node3D
var gait: GAIT
var damage_owner: Node
var dead := false
var road: Node2D
var road_shapes: Array[CollisionShape2D] = []
var heavy_gate: CollisionShape2D
var leg_shapes: Array[Array] = []
var hull: CollisionShape2D
var arena := false
var jump := Jump.NONE
var jump_age := 0.0
var air_age := 0.0
var jump_origin := Vector3.ZERO
var jump_target := Vector3.ZERO
var vertical_speed := 0.0
var launch_speed := 5.8
var takeoff_time_scale := 1.0
var flight_duration := 0.0
var horizontal_velocity := Vector2.ZERO
var landing_speed := 0.0
var landing_compression := .32
var contact_player := false
var last_tick := -1
var movement_distance := 0.0
var blocked_distance := 0.0
var support_height := 0.0
var road_signature: Array[Rect2] = []
var move_audio: MOVE_AUDIO

func configure(host: Node3D, visual: Node3D) -> void:
	world = host
	model = visual
	name = "H06PhysicalBody"
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0
	max_slides = 6
	safe_margin = .012 * PIXELS
	process_physics_priority = 100
	collision_layer = 0
	collision_mask = ROAD_LAYER | 1 | 2 | 8 | 32
	set_meta(&"dream_room_id", 0)
	set_meta(&"content_kind", &"boss")
	set_meta(&"shot_height_pixels", 1.5*PIXELS)
	position = Vector2(model.position.x, model.position.z)*PIXELS
	rotation = -model.rotation.y
	gait = GAIT.new()
	gait.configure(model, _surface, _foot_clear)
	move_audio=MOVE_AUDIO.new()
	move_audio.name="CrawlerMoveAudio"
	move_audio.configure(self)
	model.add_child(move_audio)
	_build_shapes()
	road = Node2D.new()
	road.name = "H06RoadCollision"
	road.top_level = true
	add_child(road)
	heavy_gate = _road_box("HeavyShutter", PLAN.HEAVY_GATE)
	sync_road(PLAN.crawler_obstacles(), false)
	_sync_shapes()

func _road_box(label: String, rect: Rect2) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.name = label
	body.collision_layer = ROAD_LAYER
	body.collision_mask = 0
	body.position = rect.get_center()*PIXELS
	road.add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size*PIXELS
	shape.shape = box
	body.add_child(shape)
	return shape

func sync_road(obstacles: Array[Rect2], gate_open: bool) -> void:
	if not is_instance_valid(road): return
	for i in obstacles.size():
		var rect := obstacles[i]
		if i>=road_shapes.size():
			road_shapes.append(_road_box("CrawlerObstacle%d"%i, rect))
			road_signature.append(rect)
		elif road_signature[i] != rect:
			road_signature[i] = rect
			road_shapes[i].get_parent().position = rect.get_center()*PIXELS
			(road_shapes[i].shape as RectangleShape2D).size = rect.size*PIXELS
		road_shapes[i].disabled = arena
	for i in range(obstacles.size(), road_shapes.size()): road_shapes[i].disabled = true
	heavy_gate.disabled = arena or gate_open
	# These are the actual authored, destructible gameplay bodies, not permanent proxies.
	# Add only the crawler query bit; player, shot and destruction rules stay with their owner.
	if world.get("blockout") != null:
		var art = world.blockout
		for body: Node in art.physics_root.get_children():
			if body is StaticBody2D and str(body.name).begins_with("FreightClutter_"):
				body.set_collision_layer_value(21,(body.collision_layer & 4)!=0)
		for entry: Dictionary in art.freight_breakables + art.freight_deck_drops:
			var body := entry.get("body") as StaticBody2D
			if is_instance_valid(body):
				body.set_collision_layer_value(21, (body.collision_layer & 4)!=0)

func _build_shapes() -> void:
	hull = CollisionShape2D.new()
	hull.name = "Chassis"
	var polygon := ConvexPolygonShape2D.new()
	var corners := PackedVector2Array([Vector2(-1.24,-1.70),Vector2(-.95,-1.98),
		Vector2(.95,-1.98),Vector2(1.24,-1.70),Vector2(1.24,2.10),
		Vector2(.96,2.40),Vector2(-.96,2.40),Vector2(-1.24,2.10)])
	for i in corners.size(): corners[i] *= PIXELS
	polygon.points = corners
	hull.shape = polygon
	add_child(hull)
	for leg: Dictionary in gait.legs:
		var parts: Array = []
		for label: String in ["Thigh", "Shin", "Foot"]:
			var shape := CollisionShape2D.new()
			shape.name = str(leg.root.name)+label
			if label=="Foot":
				var foot := CircleShape2D.new()
				foot.radius = .42*PIXELS
				shape.shape = foot
			else:
				var segment := CapsuleShape2D.new()
				segment.radius = (.24 if label=="Thigh" else .20)*PIXELS
				segment.height = 1.5*PIXELS
				shape.shape = segment
			add_child(shape)
			parts.append(shape)
		leg_shapes.append(parts)

func _point(at: Vector3) -> Vector2:
	return to_local(Vector2(at.x, at.z)*PIXELS)

func _sync_shapes() -> void:
	if not is_instance_valid(model): return
	for i in gait.legs.size():
		var leg := gait.legs[i]
		var hip := _point(leg.hip.global_position)
		var knee := _point(leg.knee.global_position)
		var ankle := _point(leg.ankle.global_position)
		for j in 2:
			var a: Vector2 = hip if j==0 else knee
			var b: Vector2 = knee if j==0 else ankle
			var shape: CollisionShape2D = leg_shapes[i][j]
			shape.position = (a+b)*.5
			shape.rotation = (b-a).angle()-PI*.5
			var capsule := shape.shape as CapsuleShape2D
			capsule.height = a.distance_to(b)+capsule.radius*2
		leg_shapes[i][2].position = ankle
	_sync_layers()

func _sync_layers() -> void:
	var visible_on_floor := model.is_visible_in_tree() and absf(model.position.y)<1.45
	if not arena and world.get("on_lower_floor")==false: visible_on_floor = false
	if jump==Jump.FLIGHT: visible_on_floor = false
	collision_layer = (2|16) if visible_on_floor else 0

func teleport(at: Vector3, yaw: float = INF) -> void:
	if is_instance_valid(move_audio):move_audio.stop_all()
	jump = Jump.NONE
	model.position = at
	if is_finite(yaw): model.rotation.y = yaw
	position = Vector2(at.x, at.z)*PIXELS
	rotation = -model.rotation.y
	support_height = at.y
	velocity = Vector2.ZERO
	var plane := _surface(Vector2(at.x,at.z))
	var normal := Vector3(plane.y,plane.z,plane.w)
	model.rotation.x = atan2(normal.dot(Vector3(sin(model.rotation.y),0,cos(model.rotation.y))),normal.y)
	gait.reset()
	_sync_shapes()

func set_arena(owner_node: Node) -> void:
	arena = true
	damage_owner = owner_node
	collision_mask = 4 | 1 | 2 | 8 | 32
	for shape in road_shapes: shape.disabled = true
	heavy_gate.disabled = true
	add_to_group(&"dream_enemies")
	gait.reset()
	_sync_shapes()

func move_toward_point(target: Vector3, delta: float, face: Vector2 = Vector2.INF) -> Vector3:
	last_tick = Engine.get_physics_frames()
	if jump!=Jump.NONE: return model.position
	var before := global_position
	var planar_target := Vector2(target.x, target.z)*PIXELS
	var offset := planar_target-before
	contact_player = false
	var facing := offset if face==Vector2.INF else face*PIXELS-before
	if facing.length_squared()>.01:
		_turn_to(-atan2(facing.x, facing.y), delta)
	var desired_velocity := offset/maxf(delta, .0001)
	velocity = velocity.move_toward(desired_velocity,18.*PIXELS*delta)
	velocity = velocity.limit_length(desired_velocity.length())
	var fraction := _supported_fraction(global_position,velocity*delta,rotation)
	velocity *= fraction
	move_and_slide()
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider()==world.get("player"): contact_player = true
	var actual := global_position-before
	movement_distance += actual.length()/PIXELS
	blocked_distance += maxf(0., offset.length()-actual.length())/PIXELS
	model.position.x = global_position.x/PIXELS
	model.position.z = global_position.y/PIXELS
	model.rotation.y = -rotation
	var plane := _surface(global_position/PIXELS)
	support_height = plane.x
	model.position.y = support_height
	var normal := Vector3(plane.y, plane.z, plane.w)
	var forward := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	model.rotation.x = atan2(normal.dot(forward), normal.y)
	gait.update(delta, Vector3(actual.x, 0, actual.y)/(PIXELS*maxf(delta, .0001)),Vector3(desired_velocity.x,0,desired_velocity.y)/PIXELS)
	_sync_shapes()
	return model.position

func _turn_to(yaw: float, delta: float) -> void:
	var change := clampf(angle_difference(rotation, yaw), -delta*2.5, delta*2.5)
	var steps := maxi(1, ceili(absf(change)/deg_to_rad(2.)))
	for i in steps:
		var candidate := Transform2D(rotation+change/steps, global_position)
		if not gait.can_support(_model_pose(global_position,candidate.get_rotation())): break
		if test_move(candidate, Vector2.ZERO, null, .01*PIXELS, true): break
		global_rotation += change/steps

func pose_stomp(index: int, point: Vector3, planted: bool) -> void:
	last_tick = Engine.get_physics_frames()
	velocity = Vector2.ZERO
	gait.pose_stomp(index, point, planted)
	_sync_shapes()

func pose_stun(compression: float, pitch: float) -> void:
	last_tick = Engine.get_physics_frames()
	velocity = Vector2.ZERO
	model.position.y = support_height-compression
	model.rotation.x = pitch
	gait.grounded_pose()
	_sync_shapes()

func _model_pose(at: Vector2, yaw: float) -> Transform3D:
	var plane := _surface(at/PIXELS)
	var normal := Vector3(plane.y,plane.z,plane.w)
	var pitch := atan2(normal.dot(Vector3(sin(-yaw),0,cos(-yaw))),normal.y)
	var pose := Transform3D(Basis.from_euler(Vector3(pitch,-yaw,0)).scaled(model.scale),Vector3(at.x/PIXELS,plane.x,at.y/PIXELS))
	return (model.get_parent() as Node3D).global_transform * pose

func _supported_fraction(at: Vector2, displacement: Vector2, yaw: float) -> float:
	if gait.can_support(_model_pose(at+displacement,yaw)): return 1.
	var low := 0.
	var high := 1.
	for i in 7:
		var middle := (low+high)*.5
		if gait.can_support(_model_pose(at+displacement*middle,yaw)): low=middle
		else: high=middle
	return low

func _surface(at: Vector2) -> Vector4:
	if jump in [Jump.COMPRESS,Jump.RECOVER]: return Vector4(jump_target.y,0,1,0)
	if arena: return Vector4(0, 0, 1, 0)
	if PLAN.MACHINE_RAMP.has_point(at):
		return Vector4(PLAN.ramp_height(at.y), 0, 1, PLAN.HOIST_Y/PLAN.MACHINE_RAMP.size.y)
	if model.position.y>PLAN.HOIST_Y*.5 and (PLAN.HOIST_DECK.grow(.1).has_point(at) or PLAN.HOIST_BRIDGE.grow(.1).has_point(at)):
		return Vector4(PLAN.HOIST_Y, 0, 1, 0)
	return Vector4(0, 0, 1, 0)

func _foot_clear(at: Vector3, hip: Vector3 = Vector3.INF) -> bool:
	if not is_inside_tree(): return true
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = .44*PIXELS
	query.shape = circle
	query.transform = Transform2D(0, Vector2(at.x,at.z)*PIXELS)
	query.collision_mask = (4|8|32) if arena else ROAD_LAYER
	query.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	if not hip.is_finite(): return true
	var a := Vector2(hip.x,hip.z)*PIXELS
	var b := Vector2(at.x,at.z)*PIXELS
	var segment := CapsuleShape2D.new()
	segment.radius = .25*PIXELS
	segment.height = a.distance_to(b)+segment.radius*2
	query.shape = segment
	query.transform = Transform2D((b-a).angle()-PI*.5,(a+b)*.5)
	return space.intersect_shape(query,1).is_empty()

func begin_jump(destination: Vector3, takeoff_speed: float = 5.8, preparation_scale := 1.0) -> bool:
	if jump!=Jump.NONE: return false
	launch_speed=clampf(takeoff_speed,2.,12.)
	if destination.y-model.position.y > launch_speed*launch_speed/(2*GRAVITY): return false
	takeoff_time_scale = preparation_scale
	jump_origin = model.position
	jump_target = destination
	jump_age = 0
	air_age = 0
	jump = Jump.CROUCH
	gait.reset()
	velocity = Vector2.ZERO
	return true

func begin_drop(destination: Vector3) -> void:
	jump_origin = model.position
	jump_target = destination
	air_age = 0.
	velocity = Vector2.ZERO
	_enter_flight(-1.5)
	gait.airborne_pose(.75,0.)
	_sync_shapes()

func _enter_flight(start_speed: float) -> void:
	jump = Jump.FLIGHT
	jump_age = 0.
	vertical_speed = start_speed
	var fall := model.position.y-jump_target.y
	flight_duration = (vertical_speed+sqrt(vertical_speed*vertical_speed+2*GRAVITY*fall))/GRAVITY
	horizontal_velocity = Vector2(jump_target.x-model.position.x,jump_target.z-model.position.z)/flight_duration
	took_off.emit()

func advance_jump(delta: float) -> void:
	last_tick = Engine.get_physics_frames()
	jump_age += delta
	match jump:
		Jump.CROUCH:
			var t := clampf(jump_age/(.42*takeoff_time_scale), 0., 1.)
			model.position.y = jump_origin.y-.34*smoothstep(0.,1.,t)
			gait.grounded_pose()
			if t>=1: jump = Jump.PUSH; jump_age = 0
		Jump.PUSH:
			var t := clampf(jump_age/(.16*takeoff_time_scale), 0., 1.)
			model.position.y = jump_origin.y+lerpf(-.34,.12,t*t)
			gait.grounded_pose()
			if t>=1:
				_enter_flight(launch_speed)
		Jump.FLIGHT:
			air_age += delta
			var dt := minf(delta, maxf(0., flight_duration-(air_age-delta)))
			model.position += Vector3(horizontal_velocity.x,vertical_speed,horizontal_velocity.y)*dt-Vector3.UP*.5*GRAVITY*dt*dt
			vertical_speed -= GRAVITY*dt
			position = Vector2(model.position.x,model.position.z)*PIXELS
			var fold := smoothstep(0., .16, air_age)
			var extension := smoothstep(.63,.97,clampf(air_age/flight_duration,0.,1.))
			gait.airborne_pose(fold, extension)
			model.rotation.x = lerpf(model.rotation.x, -.055*(1-extension), minf(1.,delta*8))
			if air_age>=flight_duration:
				model.position = jump_target
				position = Vector2(jump_target.x,jump_target.z)*PIXELS
				landing_speed = absf(vertical_speed)
				landing_compression = clampf(landing_speed*.024,.20,.38)
				jump = Jump.COMPRESS
				jump_age = 0
				gait.reset()
				landed.emit()
		Jump.COMPRESS:
			var t := clampf(jump_age/.13,0.,1.)
			model.position.y = jump_target.y-landing_compression*sin(t*PI*.5)
			model.rotation.x = .055*sin(t*PI*.5)
			gait.grounded_pose()
			if t>=1: jump = Jump.RECOVER; jump_age = 0
		Jump.RECOVER:
			var t := clampf(jump_age/.57,0.,1.)
			model.position.y = jump_target.y-landing_compression*(1-smoothstep(0.,1.,t))
			model.rotation.x = .055*(1-smoothstep(0.,1.,t))
			gait.grounded_pose()
			if t>=1:
				jump = Jump.NONE
				velocity = Vector2.ZERO
				gait.reset()
				jump_finished.emit()
	_sync_shapes()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(model): queue_free(); return
	if last_tick==Engine.get_physics_frames(): return
	if jump!=Jump.NONE: advance_jump(delta); return
	if not model.is_visible_in_tree(): collision_layer = 0; return
	gait.update(delta, Vector3.ZERO)
	_sync_shapes()

func take_damage(amount: float, origin: Vector2 = Vector2.ZERO, force: float = 1., source: StringName = &"") -> void:
	if is_instance_valid(damage_owner): damage_owner.take_damage(amount, origin, force, source)

func get_damage_owner() -> Node:
	return damage_owner if is_instance_valid(damage_owner) else self

func disable() -> void:
	if is_instance_valid(move_audio):move_audio.stop_all()
	dead = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	remove_from_group(&"dream_enemies")
	if is_instance_valid(road): road.queue_free()
