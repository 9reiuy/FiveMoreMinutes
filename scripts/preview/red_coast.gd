extends Node2D
## Standalone coast study. No dungeon, combat or save dependencies.
const TERRAIN_SIZE := Vector2(2400,1800)
const SPEED := 76.0
const ART = preload("res://art/Dream/dream_chr_32x32.png")
var coast_material: ShaderMaterial
var camera: Camera2D
var actor: Sprite2D
var actor_position := Vector2(855,900)
var clock := 0.0
var paused := false
var automatic := false
var external_step := false
var walking_distance := 0.0
var stride := 0
var splashes: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var emitted := 0

func _ready() -> void:
 random.seed=681013
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var terrain:=Sprite2D.new()
 var image:=Image.create(1,1,false,Image.FORMAT_RGBA8)
 image.fill(Color.WHITE)
 terrain.texture=ImageTexture.create_from_image(image)
 terrain.centered=false
 terrain.scale=TERRAIN_SIZE
 coast_material=ShaderMaterial.new()
 coast_material.shader=preload("res://shaders/preview/red_coast.gdshader")
 terrain.material=coast_material
 add_child(terrain)
 actor=Sprite2D.new()
 var frame:=AtlasTexture.new()
 frame.atlas=ART
 frame.region=Rect2(0,0,32,32)
 actor.texture=frame
 actor.scale=Vector2(1.25,1.25)
 actor.offset=Vector2(0,-15)
 actor.z_index=2
 add_child(actor)
 camera=Camera2D.new()
 camera.position=actor_position+Vector2(-60,-25)
 add_child(camera)
 var layer:=CanvasLayer.new()
 add_child(layer)
 var title:=Label.new()
 title.text="RED TIDE  /  红潮海岸"
 title.position=Vector2(22,18)
 title.add_theme_font_size_override("font_size",14)
 title.modulate=Color(.79,.82,.81,.85)
 layer.add_child(title)
 var hint:=Label.new()
 hint.text="WASD 移动  ·  空格 暂停海浪  ·  R 重置"
 hint.position=Vector2(22,330)
 hint.add_theme_font_size_override("font_size",10)
 hint.modulate=Color(.64,.72,.71,.85)
 layer.add_child(hint)
 _sync_visuals()

static func shoreline(y: float) -> float:
 return 850.0+65.0*sin(y*.005)+26.0*sin(y*.013)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_SPACE: paused=not paused
  if event.keycode==KEY_R: reset_coast()

func reset_coast() -> void:
 clock=0.0
 actor_position=Vector2(855,900)
 splashes.clear()
 walking_distance=0.0
 emitted=0
 random.seed=681013
 _sync_visuals()

func _process(delta: float) -> void:
 if external_step: return
 var direction:=Input.get_vector("move_left","move_right","move_up","move_down")
 if automatic: direction=Vector2(sin(clock*.6)*.35,-.85).normalized()
 advance(minf(delta,.05),direction)

func advance(delta: float, direction: Vector2) -> void:
 if paused: return
 clock+=delta
 var previous:=actor_position
 actor_position+=direction.limit_length()*SPEED*delta
 actor_position.y=clampf(actor_position.y,80,1720)
 actor_position.x=clampf(actor_position.x,shoreline(actor_position.y)-25,shoreline(actor_position.y)+275)
 var distance:=actor_position.distance_to(previous)
 walking_distance+=distance
 if distance>.01 and walking_distance>=9.0:
  walking_distance=fmod(walking_distance,9.0)
  stride+=1
  var foot:=actor_position+Vector2(-3 if stride%2==0 else 3,0)
  if actor_position.x-shoreline(actor_position.y)<140:
   emitted+=1
   for i in 8:
    var velocity:=Vector2(random.randf_range(-15,15),random.randf_range(-12,12))-direction*random.randf_range(5,17)
    splashes.append({"p":foot,"v":velocity,"age":0.0,"life":random.randf_range(.35,.85),"size":random.randf_range(1,3),"lift":random.randf_range(9,23)})
 for i in range(splashes.size()-1,-1,-1):
  splashes[i].age+=delta
  splashes[i].p+=splashes[i].v*delta
  splashes[i].v*=exp(-2.4*delta)
  if splashes[i].age>=splashes[i].life: splashes.remove_at(i)
 actor.flip_h=direction.x<-.1 if absf(direction.x)>.1 else actor.flip_h
 actor.position=actor_position+Vector2(0,-absf(sin(clock*13.0))*1.3 if distance>.01 else 0.0)
 camera.position=camera.position.lerp(actor_position+Vector2(-60,-25),1.0-exp(-delta*5.0))
 _sync_visuals()

func _sync_visuals() -> void:
 coast_material.set_shader_parameter("coast_time",clock)
 actor.position=actor_position if paused or clock==0.0 else actor.position
 queue_redraw()

func _draw() -> void:
 draw_ellipse_shadow(actor_position)
 for splash in splashes:
  var age: float=splash.age/splash.life
  var p: Vector2=splash.p+Vector2(0,-sin(age*PI)*splash.lift)
  var size: float=maxf(1.0,roundf(splash.size*(1.0-age*.7)))
  var alpha: float=1.0-smoothstep(.4,1.0,age)
  draw_rect(Rect2(p.floor(),Vector2(size*2,size)),Color(.83,.86,.82,alpha))
  if age<.45: draw_rect(Rect2(p.floor()+Vector2(size, -size),Vector2(size,size*3)),Color(.86,.87,.82,alpha*.85))

func draw_ellipse_shadow(p: Vector2) -> void:
 draw_set_transform(p,0,Vector2(1,.4))
 draw_circle(Vector2(4,2),8,Color(.0,.008,.015,.65))
 draw_set_transform(Vector2.ZERO)
