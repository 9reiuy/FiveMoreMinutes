extends Node2D
## Player-only, fixed-root visual spring. No collisions or gameplay updates.
## Uses the artist's row 2 / column 5 cell; tight opaque rectangle within it.
const CELL := Rect2(128,32,32,32)
const STRAND := Rect2(142,43,4,11)
const MAX_ANGLE := PI * 0.375 # Downward fan: 135 degrees total, +/-67.5.
# The authored hop/lean is only a few sprite pixels. Amplify that visual-only
# drive so a short stationary strike reaches the slow tip sections visibly.
const MELEE_VISUAL_MOTION_GAIN := 12.0
var bend := 0.0
var bend_velocity := 0.0
var previous_velocity := Vector2.ZERO
var previous_aim := 0.0
var initialized := false
var previous_melee_head_offset := Vector2.ZERO
var actor: Node2D
var overlay: Node2D
## Approved continuous curve, shared by all instances of the player scene.
var segmented_enabled := true
var segment_angles := Vector3.ZERO
var segment_velocities := Vector3.ZERO
var curve: Polygon2D
var overlay_curve: Polygon2D
var centerline := PackedVector2Array()
var render_centerline := PackedVector2Array()
const SECTION_LENGTHS := Vector3(3.0,4.0,4.0)
const RENDER_STEPS := 22 # Half-pixel rows, independent of the three simulated sections.

func set_segmented_enabled(enabled: bool) -> void:
	segmented_enabled = enabled
	if enabled:
		if not is_instance_valid(curve):
			curve = _make_curve(self)
			if is_instance_valid(overlay): overlay_curve = _make_curve(overlay)
		segment_angles = Vector3(bend*0.24,bend*0.65,bend)
		segment_velocities = Vector3.ZERO
	_update_strand_pose(-1.0 if scale.x < 0.0 else 1.0)
	if is_instance_valid(overlay): overlay.transform = transform

func _make_curve(parent: Node2D) -> Polygon2D:
	var sprite: Sprite2D = parent.get_node("Strand")
	var polygon := Polygon2D.new()
	polygon.name = "CurvedStrand"
	# Reuse exact artist pixels in a clampable 4x11 texture. The full atlas
	# permits a deformed edge to sample neighbouring transparent texels.
	polygon.texture = ImageTexture.create_from_image(sprite.texture.get_image())
	polygon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var uv := PackedVector2Array()
	for row in RENDER_STEPS+1:
		var y := 11.0*float(row)/RENDER_STEPS
		uv.append(Vector2(0,y))
		uv.append(Vector2(STRAND.size.x,y))
	polygon.uv = uv
	var triangles: Array[PackedInt32Array] = []
	for row in RENDER_STEPS:
		var i := row*2
		triangles.append(PackedInt32Array([i,i+1,i+2]))
		triangles.append(PackedInt32Array([i+1,i+3,i+2]))
	polygon.polygons = triangles
	parent.add_child(polygon)
	return polygon

func _smooth_centerline() -> void:
	# A single cubic has no internal section seams at all. All three springs
	# feed its controls, with a downward root tangent and the driven tip tangent.
	var p0 := centerline[0]
	var p1 := p0+Vector2.DOWN*4.0
	var p2 := centerline[2]
	var p3 := centerline[3]
	var dense := PackedVector2Array([centerline[0]])
	var distances := PackedFloat32Array([0.0])
	for sample in range(1,49):
		var t := float(sample)/48.0
		var u := 1.0-t
		var point := p0*u*u*u+p1*3*u*u*t+p2*3*u*t*t+p3*t*t*t
		distances.append(distances[-1]+dense[-1].distance_to(point))
		dense.append(point)
	# Even arc-length sampling prevents UV compression from clustering at the
	# old 3px/7px boundaries. Keep exactly 11px of rendered centerline length.
	render_centerline = PackedVector2Array()
	var cursor := 0
	for row in RENDER_STEPS+1:
		var wanted := distances[-1]*float(row)/RENDER_STEPS
		while cursor+1 < distances.size()-1 and distances[cursor+1] < wanted: cursor+=1
		var weight := (wanted-distances[cursor])/maxf(distances[cursor+1]-distances[cursor],0.000001)
		render_centerline.append(dense[cursor].lerp(dense[cursor+1],weight))
	var length := 0.0
	for i in RENDER_STEPS: length += render_centerline[i].distance_to(render_centerline[i+1])
	for i in range(1,render_centerline.size()):
		render_centerline[i] = centerline[0]+(render_centerline[i]-centerline[0])*(11.0/maxf(length,0.000001))

func _advance_sections(dt: float) -> void:
	# Absolute section angles share the old bounded drive, but follow it with
	# different response times. The tip lags rather than rotating a rigid card.
	var targets := Vector3(bend*0.24,bend*0.65,bend)
	for i in 3:
		var stiffness: float = [140.0,105.0,75.0][i]
		var damping: float = [19.0,15.0,12.0][i]
		segment_velocities[i] += ((targets[i]-segment_angles[i])*stiffness-segment_velocities[i]*damping)*dt
		segment_angles[i] = clampf(segment_angles[i]+segment_velocities[i]*dt,-MAX_ANGLE,MAX_ANGLE)
		if i > 0:
			segment_angles[i] = clampf(segment_angles[i],segment_angles[i-1]-0.7,segment_angles[i-1]+0.7)
		if absf(segment_angles[i]) >= MAX_ANGLE and segment_angles[i]*segment_velocities[i] > 0.0: segment_velocities[i] = 0.0

func _update_strand_pose(side: float) -> void:
	get_node("Strand").visible = not segmented_enabled
	if is_instance_valid(overlay): overlay.get_node("Strand").visible = not segmented_enabled
	if is_instance_valid(curve): curve.visible = segmented_enabled
	if is_instance_valid(overlay_curve): overlay_curve.visible = segmented_enabled
	rotation = 0.0 if segmented_enabled else bend*side
	if not segmented_enabled: return
	centerline = PackedVector2Array([Vector2(1,0)])
	var directions: Array[Vector2] = []
	var raw_tip := Vector2.ZERO
	for i in 3: raw_tip += Vector2.DOWN.rotated(segment_angles[i])*SECTION_LENGTHS[i]
	# Keep the overall tip swing while introducing curvature. Without this
	# correction, root stiffness would quietly reduce the visible swing range.
	var correction := segment_angles.z-Vector2.DOWN.angle_to(raw_tip)
	for i in 3:
		# The curved vertices are already inside the mirrored parent. Applying
		# side a second time would make right-facing hair lead the motion.
		var direction := Vector2.DOWN.rotated(segment_angles[i]+correction)
		directions.append(direction)
		centerline.append(centerline[i]+direction*SECTION_LENGTHS[i])
	_smooth_centerline()
	var vertices := PackedVector2Array()
	for i in render_centerline.size():
		var tangent := Vector2.DOWN if i==0 else (render_centerline[i]-render_centerline[i-1]).normalized() if i==RENDER_STEPS else (render_centerline[i+1]-render_centerline[i-1]).normalized()
		var normal := Vector2.RIGHT if i==0 else Vector2(tangent.y,-tangent.x)
		vertices.append(render_centerline[i]-normal*2.0)
		vertices.append(render_centerline[i]+normal*2.0)
	curve.polygon = vertices
	if is_instance_valid(overlay_curve): overlay_curve.polygon = vertices

func _ready() -> void:
	actor = owner as Node2D
	if actor == null: actor = get_parent().get_parent().get_parent().get_parent() as Node2D
	if actor != null:
		overlay = actor.get_node_or_null("HealOverlay/BodyPivot/Head/SideBangs") as Node2D
	set_segmented_enabled(segmented_enabled)
	set_physics_process(actor != null)
	# Child _ready runs before the player's onready muzzle/head references exist.
	call_deferred("apply_pose")

func step(delta: float, motion: Vector2, aim: float, right: bool, back: bool, rolling: bool, disabled: bool) -> void:
	if not initialized:
		previous_velocity = motion
		previous_aim = aim
		initialized = true
	var dt := clampf(delta,0.0,0.05)
	if dt <= 0.0: return
	var turn := wrapf(aim-previous_aim,-PI,PI)
	var velocity_change := motion-previous_velocity
	var side := -1.0 if right else 1.0
	# The strand points down (+Y): positive rotation moves its tip left.
	var target := clampf(side*(motion.x*0.0025+motion.y*0.0015),-MAX_ANGLE,MAX_ANGLE)
	if rolling or disabled:
		target = 0.0
	else:
		# Velocity changes give an impulse, not a one-frame spring target.
		# This makes stopping/turning readable without depending on frame duration.
		bend_velocity += side*(velocity_change.x*0.009+velocity_change.y*0.005+turn*2.0)
	# Small substeps keep the damped spring stable at low frame rates.
	var count := maxi(1,int(ceilf(dt/(1.0/120.0))))
	var subdt := dt/float(count)
	for i in count:
		bend_velocity += ((target-bend)*90.0-bend_velocity*10.0)*subdt
		bend = clampf(bend+bend_velocity*subdt,-MAX_ANGLE,MAX_ANGLE)
		if absf(bend) >= MAX_ANGLE and bend*bend_velocity > 0.0:
			bend_velocity = 0.0 # Do not accumulate outward momentum at the limit.
		if segmented_enabled: _advance_sections(subdt)
	previous_velocity = motion
	previous_aim = aim
	visible = not back
	position = Vector2(10,17) if right else Vector2(22,17)
	scale = Vector2(-1,1) if right else Vector2.ONE
	_update_strand_pose(side)
	if is_instance_valid(overlay):
		overlay.transform = transform
		overlay.visible = visible

func apply_pose() -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_node_ready(): return
	step(1.0/60.0,actor.velocity,actor.get_aim_direction().angle(),actor.character_facing_right,actor.character_facing_back,actor.dashing,actor.dead)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): return
	step_actor(delta)

func step_actor(delta: float) -> void:
	# Gameplay velocity does not include the stationary attack's visual lean
	# and hop. Sample that head motion once on the physics clock and feed the
	# existing spring, including its stop/recovery inertia. No second simulator.
	if not is_instance_valid(actor) or delta <= 0.0: return
	var lean: float = actor.lucille_body_lean_rotation
	var head_offset: Vector2 = actor.lucille_character_offset + Vector2(0,-12).rotated(lean) - Vector2(0,-12)
	var visual_velocity := ((head_offset - previous_melee_head_offset) / maxf(delta,0.001)).limit_length(600.0)
	previous_melee_head_offset = head_offset
	step(delta,actor.velocity + visual_velocity * MELEE_VISUAL_MOTION_GAIN,actor.get_aim_direction().angle(),actor.character_facing_right,actor.character_facing_back,actor.dashing,actor.dead)
