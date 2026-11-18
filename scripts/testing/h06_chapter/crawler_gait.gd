extends RefCounted
## Six planted world-space feet; the imported rigid joints are solved as two-bone chains.
## No source mesh, deployment animation or material is replaced.
var model: Node3D
var ground: Callable
var foot_clear: Callable
var legs: Array[Dictionary] = []
var swing_group := 0
var stepping := false
var step_time := 0.0
var step_duration := .18
var body_offset := 0.0
var previous_position := Vector3.ZERO
var previous_yaw := 0.0
var previous_velocity := Vector3.ZERO
var total_steps := 0
var unreachable_feet := 0

func configure(visual: Node3D, surface: Callable, clearance: Callable) -> void:
	model = visual
	ground = surface
	foot_clear = clearance
	for side: String in ["L", "R"]:
		for i in 3:
			var prefix := "Leg_%s_%s_" % [side, ["Front", "Mid", "Rear"][i]]
			var root := model.find_child(prefix+"Root", true, false) as Node3D
			var hip := model.find_child(prefix+"HipPitch", true, false) as Node3D
			var knee := model.find_child(prefix+"KneePitch", true, false) as Node3D
			var ankle := model.find_child(prefix+"FootPitch", true, false) as Node3D
			var foot := model.find_child(prefix+"Foot_Mesh", true, false) as MeshInstance3D
			if not is_instance_valid(ankle) or not is_instance_valid(foot): continue
			var bounds := foot.global_transform * foot.get_aabb()
			var sole := ankle.global_position.y - bounds.position.y
			legs.append({"root":root, "hip":hip, "knee":knee, "ankle":ankle,
				"nominal":model.to_local(ankle.global_position), "sole":sole,
				"hip_local":model.to_local(hip.global_position),
				"upper":knee.position.length(), "lower":ankle.position.length(),
				"group":(i + (1 if side=="R" else 0)) % 2,
				"plant":ankle.global_position, "from":ankle.global_position,
				"to":ankle.global_position, "target":ankle.global_position,
				"swing":false})
	reset()

func surface(at: Vector3) -> Vector4:
	return ground.call(Vector2(at.x, at.z)) if ground.is_valid() else Vector4(0, 0, 1, 0)

func on_ground(at: Vector3, sole: float) -> Vector3:
	var plane := surface(at)
	var normal := Vector3(plane.y,plane.z,plane.w).normalized()
	at.y = plane.x + sole/maxf(normal.y,.1)
	return at

func reset() -> void:
	if not is_instance_valid(model): return
	stepping = false
	body_offset = 0
	for leg: Dictionary in legs:
		leg.plant = on_ground(model.to_global(leg.nominal), leg.sole)
		leg.target = leg.plant
		leg.swing = false
		_solve(leg, leg.plant)
	previous_position = model.global_position
	previous_yaw = model.rotation.y
	previous_velocity = Vector3.ZERO

func update(delta: float, velocity: Vector3, goal_velocity: Vector3 = Vector3.INF) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var angular_speed := angle_difference(previous_yaw, model.rotation.y) / maxf(delta, .0001)
	var yaw_speed := absf(angular_speed)
	var drift := [0.0, 0.0]
	for leg: Dictionary in legs:
		var neutral := on_ground(model.to_global(leg.nominal), leg.sole)
		if leg.get("tucked",false) and foot_clear.is_valid():
			if not foot_clear.call(neutral,leg.hip.global_position): neutral=_clear_placement(leg,neutral)
			else: leg.tucked=false
		drift[leg.group] = maxf(drift[leg.group], Vector2(neutral.x-leg.plant.x, neutral.z-leg.plant.z).length())
	if not stepping:
		var starting := speed>.1 and previous_velocity.length()<.1
		var step_threshold := .36 if speed>.1 or yaw_speed>.05 else .12
		var needs_step: bool = starting or maxf(drift[0], drift[1]) > step_threshold
		if needs_step:
			# Keep alternating when both tripods need work. A tucked foot has a
			# larger neutral error and must never starve the opposite support set.
			if drift[swing_group]<.12 and drift[1-swing_group]>.36: swing_group = 1-swing_group
			step_time = 0
			step_duration = clampf(.20-speed*.012, .065, .22)
			stepping = true
			for leg: Dictionary in legs:
				if leg.group != swing_group: continue
				var predicted_yaw := clampf(angular_speed*step_duration*1.5,-.55,.55)
				var desired := model.to_global(Basis(Vector3.UP,predicted_yaw)*(leg.nominal as Vector3))
				# Predict touchdown plus half the next stance. Predicting only the
				# swing midpoint leaves the support tripod behind the moving chassis.
				var horizon := step_duration*1.50
				if goal_velocity.is_finite():
					var acceleration := (goal_velocity-velocity).normalized()*18.
					var accelerating := minf(horizon,goal_velocity.distance_to(velocity)/18.)
					desired += velocity*accelerating + acceleration*.5*accelerating*accelerating + goal_velocity*(horizon-accelerating)
				else: desired += velocity*horizon
				desired = on_ground(desired, leg.sole)
				if foot_clear.is_valid() and not foot_clear.call(desired,leg.hip.global_position):
					desired = _clear_placement(leg,desired)
				leg.from = leg.plant
				leg.to = desired
				leg.swing = true
	if stepping: step_time = minf(step_time+delta, step_duration)
	var t := step_time / step_duration
	for leg: Dictionary in legs:
		var target: Vector3 = leg.plant
		if leg.swing:
			target = (leg.from as Vector3).lerp(leg.to, smoothstep(0., 1., t))
			target.y += sin(PI*t) * (.33 + minf(speed*.022, .20))
			target = _reachable(leg,target,t>=1.)
			if foot_clear.is_valid() and not foot_clear.call(target,leg.hip.global_position):
				target = _reachable(leg,_clear_placement(leg,target),t>=1.)
			if t>=1.: leg.to = target
		leg.target = target
		_solve(leg, target)
	if stepping and t>=1.0:
		for leg: Dictionary in legs:
			if leg.swing: leg.plant = leg.to; leg.swing = false
		stepping = false
		swing_group = 1-swing_group
		total_steps += 1
	previous_yaw = model.rotation.y
	previous_position = model.global_position
	previous_velocity = velocity

func grounded_pose() -> void:
	# Crouch and landing move the chassis, never the support feet.
	for leg: Dictionary in legs:
		leg.swing = false
		leg.target = leg.plant
		_solve(leg, leg.plant)

func stomp_target(index: int, ground_point: Vector3) -> Vector3:
	var leg := legs[index]
	var point := _reachable(leg, ground_point, true)
	if foot_clear.is_valid() and not foot_clear.call(point, leg.hip.global_position):
		return leg.plant
	return point

func pose_stomp(index: int, point: Vector3, planted: bool) -> void:
	var leg := legs[index]
	leg.swing = not planted
	leg.target = _reachable(leg, point, planted)
	if planted: leg.plant = leg.target
	_solve(leg, leg.target)

func can_support(pose: Transform3D) -> bool:
	# Do not pull a planted foot beyond the actual bone lengths. This also
	# limits chassis translation/turning when a corner forces a shorter step.
	var scale_at_hip := pose.basis.get_scale().x
	for leg: Dictionary in legs:
		if leg.swing: continue
		var hip: Vector3 = pose * (leg.hip_local as Vector3)
		if hip.distance_to(leg.plant) > (leg.upper+leg.lower)*scale_at_hip-.012: return false
	return true

func _reachable(leg: Dictionary, point: Vector3, grounded: bool) -> Vector3:
	var hip: Vector3 = leg.hip.global_position
	var reach: float = (leg.upper+leg.lower)*model.global_basis.get_scale().x-.025
	if not grounded:
		return hip+(point-hip).limit_length(reach)
	for i in 3:
		point = on_ground(point,leg.sole)
		var horizontal := Vector2(point.x-hip.x,point.z-hip.z)
		var span := sqrt(maxf(.01,reach*reach-(point.y-hip.y)*(point.y-hip.y)))
		horizontal = horizontal.limit_length(span)
		point.x = hip.x+horizontal.x
		point.z = hip.z+horizontal.y
	return on_ground(point,leg.sole)

func _clear_placement(leg: Dictionary, desired: Vector3) -> Vector3:
	# Tuck an individual foot inward beside crates rather than repeatedly
	# trying to plant it inside the same obstacle or dragging its old anchor.
	var hip: Vector3 = leg.hip.global_position
	var neutral := on_ground(model.to_global(leg.nominal),leg.sole)
	var lift := maxf(0.,desired.y-on_ground(desired,leg.sole).y)
	for fraction: float in [.18,.32,.46,.58]:
		for point: Vector3 in [desired,neutral]:
			var candidate := on_ground(point.lerp(hip,fraction),leg.sole)
			candidate.y += lift
			if foot_clear.call(candidate,hip):
				leg.tucked=true
				return candidate
	return leg.plant

func airborne_pose(fold: float, extension: float = 0.0) -> void:
	for leg: Dictionary in legs:
		var nominal: Vector3 = leg.nominal
		var tucked := model.to_global(Vector3(nominal.x*.69, .53, nominal.z*.76))
		var extended := model.to_global(nominal)
		var target: Vector3 = (leg.plant as Vector3).lerp(tucked, fold).lerp(extended, extension)
		leg.target = target
		leg.swing = true
		_solve(leg, target)

func _solve(leg: Dictionary, target: Vector3) -> void:
	var root: Node3D = leg.root
	var hip: Node3D = leg.hip
	var knee: Node3D = leg.knee
	var ankle: Node3D = leg.ankle
	var local := (root.get_parent() as Node3D).to_local(target) - root.position
	root.rotation = Vector3(0, atan2(-local.z, local.x), 0)
	var horizontal := Vector2(local.x, local.z).length()
	var distance := Vector2(horizontal, local.y).length()
	var upper: float = leg.upper
	var lower: float = leg.lower
	var reach := clampf(distance, absf(upper-lower)+.001, upper+lower-.003)
	if distance > upper+lower+.015: unreachable_feet += 1
	var knee_angle := -acos(clampf((reach*reach-upper*upper-lower*lower)/(2*upper*lower), -1., 1.))
	var hip_angle := atan2(local.y, horizontal)-atan2(lower*sin(knee_angle), upper+lower*cos(knee_angle))
	hip.rotation = Vector3(0, 0, hip_angle)
	knee.rotation = Vector3(0, 0, knee_angle)
	var normal := Vector3.UP
	if not leg.swing:
		var plane := surface(target)
		normal = Vector3(plane.y, plane.z, plane.w).normalized()
	var outward := (ankle.global_position - hip.global_position).slide(normal).normalized()
	if outward.length_squared()<.01: outward = Vector3.RIGHT
	# Preserve imported scale while keeping each sole parallel to its actual support plane.
	var scale_at_foot := ankle.global_basis.get_scale()
	var basis_at_foot := Basis(outward, normal, outward.cross(normal).normalized())
	ankle.global_basis = basis_at_foot.scaled(scale_at_foot)

func debug_state() -> Array[Dictionary]:
	var state: Array[Dictionary] = []
	for leg: Dictionary in legs:
		state.append({"name":str(leg.root.name), "swing":leg.swing,
			"plant":leg.plant, "target":leg.target, "ankle":leg.ankle.global_position,
			"error":(leg.ankle.global_position as Vector3).distance_to(leg.target)})
	return state
