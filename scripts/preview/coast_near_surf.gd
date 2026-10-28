extends RefCounted
## One continuous coarse ocean patch, extending past the visible near-water band.
## Fine front water is separate; the sea no longer consists of three visible boxes.
var patches: Array[Dictionary]=[]
var accumulator:=0.
const WIDTH:=64
const HEIGHT:=56
const SPACING:=3.75
const K1:=Vector2(.10,.30)
const K2:=Vector2(.39,-.16)
const K3:=Vector2(-.29,-.27)

func wave_parts(p: Vector2,t: float) -> Vector3:
 var speed:=sqrt(9.81*2.8)
 return Vector3(.075*sin(p.dot(K1)-t*K1.length()*speed),.018*sin(p.dot(K2)-t*K2.length()*speed+1.7),.010*sin(p.dot(K3)-t*K3.length()*speed+.8))

func bind(coast: Node3D) -> void:
 var origin: Vector2=coast.near_surf_origin
 var flow: RefCounted=preload("res://scripts/simulation/surface_flow.gd").new()
 flow.configure(WIDTH,HEIGHT,SPACING)
 flow.drag=.08; flow.maximum_substep=1./15. # Actual coarse-grid CFL is still checked.
 for y in HEIGHT:
  for x in WIDTH:
   var p:=origin+Vector2(x+.5,y+.5)*SPACING
   var i:=y*WIDTH+x
   flow.bed[i]=coast.surface_height(p.x,p.y)
   if coast.obstacle_distance(p)<0: flow.solid[i]=1
   else:
    var waves:=wave_parts(p,coast.clock)
    flow.set_level(x,y,waves.x+waves.y+waves.z)
    if flow.depth[i]>.1:
     var c:=sqrt(flow.gravity*flow.depth[i])*SPACING
     var velocity: Vector2=(K1.normalized()*waves.x+K2.normalized()*waves.y+K3.normalized()*waves.z)*c
     flow.flux_x[i]=velocity.x; flow.flux_y[i]=velocity.y
 var foam: RefCounted=preload("res://scripts/preview/coast_surface_foam.gd").new()
 foam.configure(WIDTH,HEIGHT)
 patches.append({"flow":flow,"foam":foam,"origin":origin,"size":Vector2(WIDTH,HEIGHT)*SPACING,"state":ImageTexture.create_from_image(flow.state_image())})

func advance(dt: float,t: float) -> void:
 accumulator+=dt
 while accumulator>=1./15.:
  var patch: Dictionary=patches[0]
  var flow: RefCounted=patch.flow
  for y in HEIGHT:
   for x in [0,WIDTH-1]:
    var p: Vector2=patch.origin+Vector2(x+.5,y+.5)*SPACING
    var waves:=wave_parts(p,t)
    flow.set_level(x,y,waves.x+waves.y+waves.z)
  for x in range(1,WIDTH-1):
   for y in [0,HEIGHT-1]:
    var p: Vector2=patch.origin+Vector2(x+.5,y+.5)*SPACING
    var waves:=wave_parts(p,t)
    flow.set_level(x,y,waves.x+waves.y+waves.z)
  flow.step(1./15.)
  patch.foam.step(flow,1./15.)
  accumulator-=1./15.

func upload() -> void:
 for patch in patches:
  patch.state.update(patch.flow.state_image()); patch.foam.upload()

func clear() -> void:
 accumulator=0
 for patch in patches:
  var flow: RefCounted=patch.flow
  for y in flow.height:
   for x in flow.width: flow.set_level(x,y,0)
  flow.dye.fill(0); flow.flux_x.fill(0); flow.flux_y.fill(0)
  patch.foam.clear()
 upload()
