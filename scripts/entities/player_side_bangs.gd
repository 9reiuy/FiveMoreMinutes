extends Node2D
## Player-only, fixed-root visual spring. No collisions or gameplay updates.
## Uses the artist's row 2 / column 5 cell; tight opaque rectangle within it.
const CELL := Rect2(128,32,32,32)
const STRAND := Rect2(142,43,4,11)
const MAX_ANGLE := PI * 0.375 # Downward fan: 135 degrees total, +/-67.5.
var bend := 0.0
var bend_velocity := 0.0
var previous_velocity := Vector2.ZERO
var previous_aim := 0.0
var initialized := false
var actor: Node2D
var overlay: Node2D

func _ready() -> void:
	actor = owner as Node2D
	if actor == null: actor = get_parent().get_parent().get_parent().get_parent() as Node2D
	if actor != null:
		overlay = actor.get_node_or_null("HealOverlay/BodyPivot/Head/SideBangs") as Node2D
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
	previous_velocity = motion
	previous_aim = aim
	visible = not back
	position = Vector2(10,17) if right else Vector2(22,17)
	scale = Vector2(-1,1) if right else Vector2.ONE
	rotation = bend * side
	if is_instance_valid(overlay):
		overlay.transform = transform
		overlay.visible = visible

func apply_pose() -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_node_ready(): return
	step(1.0/60.0,actor.velocity,actor.get_aim_direction().angle(),actor.character_facing_right,actor.character_facing_back,actor.dashing,actor.dead)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): return
	step(delta,actor.velocity,actor.get_aim_direction().angle(),actor.character_facing_right,actor.character_facing_back,actor.dashing,actor.dead)
