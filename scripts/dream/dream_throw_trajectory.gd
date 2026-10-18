extends Node3D
## Visual-only throw prediction.  The gameplay throw remains owned by the
## existing WorldWeaponPickup; this node only displays sampled points.

## Visual samples are denser than the predictor's physics samples. This count
## only controls cheap presentation meshes; it never increases collision work.
const DOT_COUNT := 64
const DOT_SPACING_MS := 82
var dots: Array[MeshInstance3D] = []
var trajectory_points: Array[Vector3] = []
var impact_point := Vector3.ZERO
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.96)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 1.0, 1.0, 1.0)
	_material.emission_energy_multiplier = 1.2
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in DOT_COUNT:
		var dot := MeshInstance3D.new()
		dot.name = "TrajectoryDot%02d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.025
		sphere.height = 0.05
		sphere.radial_segments = 4
		sphere.rings = 2
		dot.mesh = sphere
		dot.material_override = _material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		add_child(dot)
		dots.append(dot)
	hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	var phase := int(Time.get_ticks_msec() / DOT_SPACING_MS)
	for index in dots.size():
		var dot := dots[index]
		if index >= trajectory_points.size():
			dot.visible = false
			continue
		# A moving gap makes the trajectory readable without adding particles or
		# a second physics object for every predicted point.
		dot.visible = ((index + phase) % 3) != 2


func set_points(points: Array, _impact: Vector3 = Vector3.ZERO) -> void:
	trajectory_points.clear()
	for point_variant in points:
		if point_variant is Vector3:
			trajectory_points.append(point_variant)
	impact_point = _impact
	visible = not trajectory_points.is_empty()
	# Resample the already-computed polyline across all visual dots. The predictor
	# intentionally samples physics only every other frame (normally fewer than
	# DOT_COUNT points), so interpolation must also handle the common "shorter
	# source polyline" case. This increases visual dash density without adding
	# predictor physics steps or collision queries.
	if trajectory_points.size() >= 2 and trajectory_points.size() != DOT_COUNT:
		var resampled: Array[Vector3] = []
		resampled.resize(DOT_COUNT)
		var last_index := trajectory_points.size() - 1
		for index in DOT_COUNT:
			var normalized := float(index) / float(maxi(DOT_COUNT - 1, 1))
			var sample := normalized * float(last_index)
			var lower := clampi(int(floor(sample)), 0, last_index)
			var upper := clampi(lower + 1, 0, last_index)
			resampled[index] = trajectory_points[lower].lerp(
				trajectory_points[upper],
				sample - float(lower)
			)
		trajectory_points = resampled
	for index in dots.size():
		var dot := dots[index]
		if index < trajectory_points.size():
			dot.global_position = trajectory_points[index]
			dot.visible = true
		else:
			dot.visible = false


func clear_points() -> void:
	trajectory_points.clear()
	impact_point = Vector3.ZERO
	hide()
	for dot in dots:
		if is_instance_valid(dot):
			dot.visible = false
