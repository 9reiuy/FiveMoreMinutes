extends RefCounted
## Artist-authored eight-way atlas, updated 2026-10-30. Upper body and head
## are one cell. Strand attachment and front/back layering are authored per view;
## do not mirror a front view merely because aim points right.
const ART: Texture2D = preload("res://art/Dream/dream_chr_32x32.png")
enum Facing { RIGHT, DOWN_RIGHT, DOWN, DOWN_LEFT, LEFT, UP_LEFT, UP, UP_RIGHT }
const UPPER_CELLS: Array[Vector2i] = [Vector2i(6,0),Vector2i(5,0),Vector2i(4,0),Vector2i(3,0),Vector2i(2,0),Vector2i(3,4),Vector2i(4,4),Vector2i(5,4)]
const BANGS_REGION := Rect2(46,43,4,11)
const LEFT_HAND_REGION := Rect2(37,16,5,4)
const RIGHT_HAND_REGION := Rect2(52,16,5,4)
const UPPER_ORIGIN := Vector2(-16,-17)
# Match the assembled reference at column 1: one-pixel upper/foot offset.
const FRINGE_LEFT_ROOT := Vector2(20,14)
const FRINGE_RIGHT_ROOT := Vector2(12,14) # Legacy whole-card fallback only.
const TORSO_CENTER := Vector2(16,25)

static func facing(direction: Vector2) -> int:
	return posmod(roundi(direction.angle()/(PI*.25)),8)
static func is_back(index: int) -> bool: return index in [Facing.UP_LEFT,Facing.UP,Facing.UP_RIGHT]
static func has_bangs(index: int) -> bool:
	return index>=Facing.RIGHT and index<=Facing.UP_RIGHT
static func bangs_root(index: int) -> Vector2:
	match index:
		Facing.LEFT: return Vector2(14,14)
		Facing.DOWN: return Vector2(23,14)
		Facing.RIGHT: return Vector2(10,14)
		Facing.DOWN_RIGHT: return Vector2(26,14)
		Facing.UP_LEFT: return Vector2(25,15)
		Facing.UP: return Vector2(24,15)
		Facing.UP_RIGHT: return Vector2(22,15)
		_: return FRINGE_LEFT_ROOT
static func bangs_mirrored(index: int) -> bool:
	return index==Facing.RIGHT
static func bangs_layer(index: int) -> int:
	return -1 if index in [Facing.RIGHT,Facing.UP_LEFT,Facing.UP,Facing.UP_RIGHT] else 1
static func upper_region(index: int,blink: int=0) -> Rect2:
	var cell:=UPPER_CELLS[posmod(index,8)]
	return Rect2(cell.x*32,(cell.y+(0 if is_back(index) else clampi(blink,0,2)))*32,32,32)
# Per-view painted hem centres differ; never move the actor/collision to compensate.
static func foot_offset(index: int) -> Vector2:
	match index:
		Facing.RIGHT, Facing.DOWN_RIGHT, Facing.UP_LEFT: return Vector2(3,0)
		Facing.UP: return Vector2(2,0)
		_: return Vector2.ZERO
static func foot_region(back: bool,left: bool) -> Rect2:
	return Rect2(43 if left else 48,140 if back else 76,4,9)
static func texture(region: Rect2) -> AtlasTexture:
	var result:=AtlasTexture.new(); result.atlas=ART; result.region=region; return result
static func frames(index: int) -> Array[Texture2D]:
	var result: Array[Texture2D]=[]
	for blink in (1 if is_back(index) else 3): result.append(texture(upper_region(index,blink)))
	return result
