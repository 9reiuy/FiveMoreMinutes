extends Node2D

## Lightweight visual-only projectile streak.
##
## The gameplay projectile remains BasicProjectile.  This node only draws a
## short tapered white mark behind it and is mirrored into the existing 3D
## depth bridge as an unlit carrier.  It owns no collision, damage, range or
## lifetime state.

@export var trail_length: float = 12.0
@export var trail_width: float = 3.0
@export var head_gap: float = 2.0
@export var trail_color: Color = Color.WHITE

## The gameplay projectile supplies its actual travel velocity.  The streak
## keeps a local -X drawing axis, but its rotation is derived here from that
## velocity rather than from a weapon or actor aim transform.
var velocity := Vector2.RIGHT

var _configured := false


func configure(
	requested_length: float = 36.0,
	requested_width: float = 2.0,
	requested_color: Color = Color.WHITE,
	requested_head_gap: float = -1.0
) -> void:
	trail_length = maxf(requested_length, 1.0)
	trail_width = maxf(requested_width, 1.0)
	trail_color = requested_color
	if requested_head_gap > 0.0:
		head_gap = maxf(requested_head_gap, 0.5)
	_configured = true
	queue_redraw()


func set_velocity(value: Vector2) -> void:
	velocity = value
	# ProjectileTrail is a child of BasicProjectile.  The gameplay root already
	# rotates to `velocity.angle()`, so keeping a second local rotation here
	# would rotate the world-space trail twice (most visible on vertical and
	# diagonal shots).  The draw axis remains local -X and inherits the root's
	# single authoritative rotation.
	rotation = 0.0


func _ready() -> void:
	queue_redraw()


func copy_depth_visual_state_to(target: Node2D) -> void:
	## ActorDepthBridge creates a passive scripted copy for this custom draw.
	## Copy only visual parameters; never copy gameplay/lifetime state.
	if target == null:
		return
	target.set("trail_length", trail_length)
	target.set("trail_width", trail_width)
	target.set("head_gap", head_gap)
	target.set("trail_color", trail_color)
	target.set("velocity", velocity)
	target.set("rotation", rotation)
	target.set("_configured", _configured)
	target.queue_redraw()


func _draw() -> void:
	if not _configured:
		return
	var half_width := trail_width * 0.5
	var tail_width := maxf(half_width * 0.24, 0.5)
	var tail_x := -trail_length
	var front_x := -maxf(head_gap, 0.5)
	# Draw contiguous tapered strips with decreasing alpha.  This produces a
	# real tail-to-head gradient in both the 2D source and its depth-bridge copy,
	# while keeping the head gap clear so the trail cannot render in front.
	const GRADIENT_STEPS := 8
	var base_alpha := clampf(trail_color.a, 0.0, 1.0)
	for index in range(GRADIENT_STEPS):
		var t0 := float(index) / float(GRADIENT_STEPS)
		var t1 := float(index + 1) / float(GRADIENT_STEPS)
		var x0 := lerpf(front_x, tail_x, t0)
		var x1 := lerpf(front_x, tail_x, t1)
		var width0 := lerpf(half_width, tail_width, t0)
		var width1 := lerpf(half_width, tail_width, t1)
		var alpha0 := base_alpha * pow(1.0 - t0, 1.35)
		var alpha1 := base_alpha * pow(1.0 - t1, 1.35)
		var points := PackedVector2Array([
			Vector2(x0, -width0),
			Vector2(x1, -width1),
			Vector2(x1, width1),
			Vector2(x0, width0),
		])
		# Adjacent strips overlap at their shared edge; use the brighter front
		# value so there is no transparent seam at nearest-neighbour scale.
		draw_colored_polygon(points, Color(trail_color, maxf(alpha0, alpha1)))
