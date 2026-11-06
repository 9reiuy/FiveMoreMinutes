extends Node2D
## Presentation only. Shares the eight-way authored atlas with the real player.
const ATLAS=preload("res://scripts/data/player_character_atlas.gd")
var phase:=0.0
var elapsed:=0.0
var moving:=false
var facing_back:=true
var facing_right:=false
var facing_index:=ATLAS.Facing.UP
@onready var left: Sprite2D=$LeftFoot
@onready var right: Sprite2D=$RightFoot
@onready var body: Node2D=$BodyPivot
@onready var head: Sprite2D=$BodyPivot/Head
@onready var coat: Sprite2D=$BodyPivot/Body
@onready var left_hand: Sprite2D=$BodyPivot/LeftHand
@onready var right_hand: Sprite2D=$BodyPivot/RightHand
@onready var fringe: Sprite2D=$BodyPivot/Head/SideBangs

func _ready() -> void:
 pose()

func advance(delta: float,distance: float,direction: Vector2) -> void:
 elapsed+=delta
 moving=distance>.0001
 if moving:
  phase=fposmod(phase+distance/.68*TAU,TAU)
  facing_index=ATLAS.facing(direction)
  facing_back=ATLAS.is_back(facing_index)
  facing_right=direction.x>0
 else: phase=0
 pose()

func pose() -> void:
 var stride: float=sin(phase) if moving else 0.
 var leg_offset:=ATLAS.foot_offset(facing_index)
 left.position=Vector2(-6+roundf(stride*2),-9-roundf(maxf(stride,0)*2))+leg_offset
 right.position=Vector2(-1+roundf(-stride*2),-9-roundf(maxf(-stride,0)*2))+leg_offset
 body.position=Vector2(0,-16-roundf(absf(stride)*2))
 left_hand.position=Vector2(-12+roundf(-stride),8+roundf(stride))
 right_hand.position=Vector2(3+roundf(stride),8-roundf(stride))
 var blink:=1 if fmod(elapsed,4.7)<.11 else 0
 head.region_rect=ATLAS.upper_region(facing_index,blink)
 head.position=ATLAS.UPPER_ORIGIN
 coat.visible=false
 left.region_rect=ATLAS.foot_region(facing_back,true)
 right.region_rect=ATLAS.foot_region(facing_back,false)
 fringe.region_rect=ATLAS.BANGS_REGION
 fringe.visible=ATLAS.has_bangs(facing_index)
 var mirror:=ATLAS.bangs_mirrored(facing_index)
 fringe.position=ATLAS.bangs_root(facing_index)+Vector2(-3 if mirror else -1,0)
 fringe.flip_h=mirror
 fringe.z_index=ATLAS.bangs_layer(facing_index)
