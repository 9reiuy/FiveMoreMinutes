extends RefCounted
## Dive-roll cels assembled from Rei's original upper, fringe and leg art.
const ATLAS := preload("res://scripts/data/player_character_atlas.gd")
const CELL := Vector2i(72, 72)
const ANCHOR := Vector2i(36, 54)
const WORK_ANCHOR := Vector2i(36, 34)
const UPPER_CENTER := Vector2(16, 16)
const LEG_PIVOT := Vector2i(2, 1)
const KNEE := Vector2i(2, 4)
const LEG_ORIGINS := [Vector2i(10, 24), Vector2i(15, 24)]
const HAND_PIVOT := Vector2i(2, 2)

enum Cel { LOAD, PUSH, REACH, DIVE, LOWER, PALMS, TRANSFER, TUCK, BACK, HIP, FEET, RISE, GUARD, READY }
const FRAME_COUNT := Cel.READY + 1
const LIFT_PX := [0, 0, 2, 5, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]
enum { LEAD, PITCH, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_REACH, RIGHT_REACH }

# The dive stays extended until the palms are down. The shoulders then pass
# the hands, the knees fold separately, and the back and feet take the load.
const SIDE_POSES := [
	[0, 12.0, 16.0, -16.0, -8.0, 15.0, Vector2i(-7, 2), Vector2i(7, 2)], # load
	[2, 37.0, 28.0, -20.0, -23.0, 21.0, Vector2i(4, -4), Vector2i(11, 0)], # push
	[3, 65.0, 9.0, -20.0, -18.0, 9.0, Vector2i(17, -3), Vector2i(21, 2)], # reach
	[4, 83.0, 14.0, -16.0, -22.0, 7.0, Vector2i(21, -3), Vector2i(25, 4)], # dive
	[4, 96.0, 18.0, -16.0, -20.0, 5.0, Vector2i(21, 4), Vector2i(26, 7)], # lower
	[4, 109.0, 23.0, -17.0, -25.0, 6.0, Vector2i(19, 8), Vector2i(24, 11)], # palms
	[4, 126.0, 28.0, -20.0, -38.0, 15.0, Vector2i(11, 8), Vector2i(16, 12)], # transfer
	[2, 156.0, 45.0, -25.0, -56.0, 21.0, Vector2i(4, 7), Vector2i(8, 6)], # tuck
	[0, 199.0, 52.0, -26.0, -65.0, 32.0, Vector2i(-6, 4), Vector2i(3, -3)], # back
	[-1, 241.0, 48.0, -30.0, -62.0, 35.0, Vector2i(-8, 6), Vector2i(7, 3)], # hip
	[-1, 284.0, 47.0, -29.0, -57.0, 28.0, Vector2i(-9, 5), Vector2i(7, 4)], # feet
	[0, 318.0, 37.0, -17.0, -41.0, 20.0, Vector2i(-8, 4), Vector2i(7, 2)], # rise
	[0, 344.0, 16.0, -8.0, -20.0, 8.0, Vector2i(-8, 2), Vector2i(7, 1)], # guard
	[0, 360.0, 0.0, 0.0, 0.0, 0.0, Vector2i(-9, 2), Vector2i(6, 2)], # ready
]

# End-on dives have less screen-space pitch and a shortened, staggered reach.
const DEPTH_PITCH := [0.0, 16.0, 31.0, 47.0, 62.0, 79.0, 108.0, 147.0, 190.0, 237.0, 280.0, 318.0, 344.0, 360.0]
const DEPTH_REACH := [2, 5, 11, 16, 18, 18, 10, 7, 3, 2, 2, 2, 2, 2]

const TOWARD_VIEWS := [
	ATLAS.Facing.DOWN, ATLAS.Facing.DOWN, ATLAS.Facing.DOWN_RIGHT, ATLAS.Facing.DOWN_RIGHT,
	ATLAS.Facing.DOWN_RIGHT, ATLAS.Facing.DOWN_RIGHT, ATLAS.Facing.UP_RIGHT, ATLAS.Facing.UP,
	ATLAS.Facing.UP, ATLAS.Facing.UP, ATLAS.Facing.UP_LEFT, ATLAS.Facing.DOWN_LEFT,
	ATLAS.Facing.DOWN, ATLAS.Facing.DOWN,
]
const AWAY_VIEWS := [
	ATLAS.Facing.UP, ATLAS.Facing.UP, ATLAS.Facing.UP_LEFT, ATLAS.Facing.UP_LEFT,
	ATLAS.Facing.UP_LEFT, ATLAS.Facing.UP_LEFT, ATLAS.Facing.DOWN_LEFT, ATLAS.Facing.DOWN,
	ATLAS.Facing.DOWN, ATLAS.Facing.DOWN, ATLAS.Facing.DOWN_RIGHT, ATLAS.Facing.UP_RIGHT,
	ATLAS.Facing.UP, ATLAS.Facing.UP,
]

static func source_facing(facing: int, index: int) -> int:
	if facing == ATLAS.Facing.DOWN:
		return TOWARD_VIEWS[index]
	if facing == ATLAS.Facing.UP:
		return AWAY_VIEWS[index]
	if index >= Cel.TUCK and index <= Cel.HIP:
		return ATLAS.Facing.UP_RIGHT if facing <= ATLAS.Facing.DOWN_RIGHT or facing == ATLAS.Facing.UP_RIGHT else ATLAS.Facing.UP_LEFT
	return facing

static func build(include_hands := false) -> Dictionary:
	var source := ATLAS.ART.get_image()
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	var sheet := Image.create_empty(CELL.x * FRAME_COUNT, CELL.y * 8, false, Image.FORMAT_RGBA8)
	var hand_offsets: Array[PackedVector2Array] = []
	var left_hand := source.get_region(Rect2i(ATLAS.LEFT_HAND_REGION))
	var right_hand := source.get_region(Rect2i(ATLAS.RIGHT_HAND_REGION))
	var views: Array[Array] = []
	for facing in 8:
		var back := ATLAS.is_back(facing)
		views.append([_upper(source, facing),
			source.get_region(Rect2i(ATLAS.foot_region(back, true))),
			source.get_region(Rect2i(ATLAS.foot_region(back, false))), left_hand, right_hand])
	for facing in 8:
		for index in FRAME_COUNT:
			var pose := _pose_cel(views[source_facing(facing, index)], facing, index, include_hands)
			sheet.blit_rect(pose.image, Rect2i(Vector2i.ZERO, CELL), Vector2i(index, facing) * CELL)
			hand_offsets.append(pose.hands)
	return {"image": sheet, "hands": hand_offsets}

static func _upper(source: Image, facing: int) -> Image:
	var upper := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var fringe := source.get_region(Rect2i(ATLAS.BANGS_REGION))
	if ATLAS.bangs_mirrored(facing):
		fringe.flip_x()
	var fringe_at := Vector2i(ATLAS.bangs_root(facing)) - Vector2i(1, 0)
	var torso := source.get_region(Rect2i(ATLAS.upper_region(facing)))
	if ATLAS.bangs_layer(facing) < 0:
		_paste(upper, fringe, fringe_at)
	_paste(upper, torso, Vector2i.ZERO)
	if ATLAS.bangs_layer(facing) > 0:
		_paste(upper, fringe, fringe_at)
	return upper

static func _pose_cel(pieces: Array, facing: int, index: int, include_hands: bool) -> Dictionary:
	var parts := _pose_parts(pieces, facing, index)
	var cel: Image = parts.jacket
	var lower := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for leg in parts.legs:
		_paste(lower, leg, Vector2i.ZERO)
	_paste(lower, cel, Vector2i.ZERO)
	var bounds := lower.get_used_rect()
	var hand_origins: Array[Vector2i] = parts.hand_origins
	var contact_y := bounds.end.y
	if index >= Cel.REACH and index <= Cel.TRANSFER:
		var forward_y := sin(float(facing) * TAU / 8.0)
		var reach_distance := 7.0 if index == Cel.TRANSFER else 13.0
		if facing == ATLAS.Facing.UP:
			reach_distance += 12.0
		var lane := forward_y * reach_distance
		var palm_bottom := (hand_origins[0].y + hand_origins[1].y) * 0.5 + HAND_PIVOT.y * 2
		var palm_contact := roundi(palm_bottom - lane)
		contact_y = maxi(contact_y, palm_contact)
		if index >= Cel.PALMS:
			for hand in hand_origins.size():
				hand_origins[hand].y += contact_y - palm_contact
	contact_y += int(LIFT_PX[index])
	var grounded_offset := Vector2i(0, ANCHOR.y - contact_y)
	var grounded := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	var hands := PackedVector2Array()
	for hand in hand_origins.size():
		var at := hand_origins[hand] + grounded_offset
		if include_hands:
			_paste(grounded, pieces[3 + hand], at)
		hands.append(Vector2(at - ANCHOR) + Vector2(pieces[3 + hand].get_size()) * 0.5)
	grounded.blit_rect_mask(lower, lower, bounds, bounds.position + grounded_offset)
	return {"image": grounded, "hands": hands}

static func _pose_parts(pieces: Array, facing: int, index: int) -> Dictionary:
	var end_on := facing == ATLAS.Facing.UP or facing == ATLAS.Facing.DOWN
	var pose: Array = SIDE_POSES[index]
	var side := -1 if facing in [ATLAS.Facing.LEFT, ATLAS.Facing.UP_LEFT, ATLAS.Facing.UP, ATLAS.Facing.DOWN_LEFT] else 1
	var forward_y := sin(float(facing) * TAU / 8.0)
	var pitch := deg_to_rad(float(DEPTH_PITCH[index] if end_on else pose[PITCH]))
	var perspective_pitch := deg_to_rad(18.0 * forward_y) * sin(pitch) if not end_on else 0.0
	var body_angle := (pitch + perspective_pitch) * side
	var center := WORK_ANCHOR + Vector2i(int(pose[LEAD]) * side, 0)
	var jacket := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	_place(jacket, pieces[0], center, UPPER_CENTER, body_angle)
	var legs: Array[Image] = []
	var angles := PackedFloat32Array()
	var hem_drop := mini(2, mini(index, FRAME_COUNT - 1 - index))
	var foot_offset := ATLAS.foot_offset(source_facing(facing, index))
	for leg_index in 2:
		var in_jacket := Vector2(LEG_ORIGINS[leg_index] + LEG_PIVOT + Vector2i(0, hem_drop))
		if index == Cel.READY:
			in_jacket += ATLAS.standing_foot_adjustment(facing, leg_index == 0)
		var root := Vector2(center) + (in_jacket + foot_offset - UPPER_CENTER).rotated(body_angle)
		var angle_index := leg_index if side > 0 else 1 - leg_index
		var bend := deg_to_rad(float(pose[LEFT_HIP + angle_index]) * side)
		var knee := deg_to_rad(float(pose[LEFT_KNEE + angle_index]) * side)
		var leg := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
		_place_leg(leg, pieces[1 + leg_index], root, body_angle + bend, knee)
		legs.append(leg)
		angles.append(bend)
	var chest := Vector2(center) + (Vector2(16.0 + foot_offset.x * 0.65, 23.0) - UPPER_CENTER).rotated(body_angle)
	var hand_origins: Array[Vector2i] = []
	for index_hand in 2:
		var across := 1 if index_hand == 1 else -1
		var reach: Vector2i = pose[LEFT_REACH + index_hand]
		if end_on:
			reach = Vector2i(across * (8 if index <= Cel.TRANSFER else 7), roundi(DEPTH_REACH[index] * forward_y) + across * 2)
		else:
			reach.x *= side
			reach.y += roundi(absf(reach.x) * forward_y * 0.52) if index >= Cel.REACH and index <= Cel.TRANSFER else 0
		hand_origins.append(Vector2i(chest.round()) + reach - HAND_PIVOT)
	return {"jacket": jacket, "legs": legs, "hand_origins": hand_origins,
		"body_angle": body_angle, "leg_angles": angles}

static func _place_leg(cel: Image, part: Image, hip: Vector2, angle: float, bend: float) -> void:
	if is_zero_approx(bend):
		_place(cel, part, hip, LEG_PIVOT, angle)
		return
	var knee_world := hip + Vector2(KNEE - LEG_PIVOT).rotated(angle)
	# Reuse two overlapping slices of the same leg at the knee joint.
	var shin := part.get_region(Rect2i(0, 3, 4, 6))
	var thigh := part.get_region(Rect2i(0, 0, 4, 6))
	_place(cel, shin, knee_world, Vector2(KNEE - Vector2i(0, 3)), angle + bend)
	_place(cel, thigh, hip, LEG_PIVOT, angle)

static func _place(cel: Image, part: Image, at: Vector2, pivot: Vector2, angle: float) -> void:
	if is_zero_approx(wrapf(angle, -PI, PI)):
		_paste(cel, part, Vector2i((at - pivot).round()))
		return
	var size := Vector2(part.get_size())
	var bounds := Rect2(at - pivot.rotated(angle), Vector2.ZERO)
	for corner in [Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		bounds = bounds.expand(at + (corner - pivot).rotated(angle))
	var first := Vector2i(bounds.position.floor()).max(Vector2i.ZERO)
	var last := Vector2i(bounds.end.ceil()).min(CELL)
	var source_rect := Rect2i(Vector2i.ZERO, part.get_size())
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var offset := Vector2(x + 0.5, y + 0.5) - at
			var texel := Vector2i((offset.rotated(-angle) + pivot).floor())
			if source_rect.has_point(texel):
				var pixel := part.get_pixelv(texel)
				if pixel.a > 0.0:
					cel.set_pixel(x, y, pixel)

static func _paste(canvas: Image, part: Image, at: Vector2i) -> void:
	canvas.blit_rect_mask(part, part, Rect2i(Vector2i.ZERO, part.get_size()), at)
