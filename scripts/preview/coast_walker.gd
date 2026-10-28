extends Node2D
## Presentation only. Original player atlas/part layout; no gameplay authority.
var phase:=0.0
var elapsed:=0.0
var moving:=false
var facing_back:=true
var facing_right:=false
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
  facing_back=direction.y<0 and absf(direction.y)>absf(direction.x)*.4
  if absf(direction.x)>.01: facing_right=direction.x>0
 else: phase=0
 pose()

func pose() -> void:
 var stride: float=sin(phase) if moving else 0.
 left.position=Vector2(-5+roundf(stride*2),-9-roundf(maxf(stride,0)*2))
 right.position=Vector2(roundf(-stride*2),-9-roundf(maxf(-stride,0)*2))
 body.position=Vector2(0,-16-roundf(absf(stride)*2))
 left_hand.position=Vector2(-11+roundf(-stride),8+roundf(stride))
 right_hand.position=Vector2(4+roundf(stride),8-roundf(stride))
 var row:=128 if facing_back else 0
 var blink:=32 if fmod(elapsed,4.7)>.0 and fmod(elapsed,4.7)<.11 else 0
 head.region_rect=Rect2(64 if facing_back or not facing_right else 96,row if facing_back else blink,32,32)
 coat.region_rect=Rect2(128,row,32,32)
 left.region_rect=Rect2(171,row+12,4,9)
 right.region_rect=Rect2(176,row+12,4,9)
 fringe.visible=not facing_back
 fringe.position=Vector2(8 if facing_right else 21,17)
 fringe.flip_h=facing_right
