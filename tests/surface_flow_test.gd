extends SceneTree
const FLOW=preload("res://scripts/simulation/surface_flow.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
 print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var f:=FLOW.new(); f.configure(18,14,.5)
 f.add_water(4,6,2,0.7)
 for i in 180: f.step(1.0/60)
 check(absf(f.total_volume()-2)<.0001,"closed basin conserves water")
 check(absf(f.total_dye()-1.4)<.0001,"advection conserves dye mass")
 var minimum:=1.0; var wet:=0
 for d in f.depth: minimum=minf(minimum,d); wet+=int(d>.0001)
 check(minimum>-.000001,"positivity limiter prevents negative water")
 check(wet>15,"injected volume flows beyond source cell")
 f.configure(18,14,.5)
 for y in 14: f.solid[y*18+8]=1
 f.add_water(4,6,2,1)
 for i in 180: f.step(1.0/60)
 var blocked_volume:=0.0
 for y in 14:
  for x in range(8,18): blocked_volume+=f.depth[y*18+x]
 check(blocked_volume<.000001,"solid wall seals flow and dye")
 f.solid[6*18+8]=0
 for i in 360: f.step(1.0/60)
 var beyond:=0.0
 for y in 14:
  for x in range(9,18): beyond+=f.depth[y*18+x]
 check(beyond>.005,"water finds opening around solid barrier")
 check(absf(f.total_volume()-2)<.0001,"obstacle routing retains total volume")
 f.configure(16,10,.5)
 for y in 10:
  for x in 16: f.bed[y*16+x]=float(15-x)*.035
 f.add_water(3,5,1,1)
 var start_moment:=3.0
 for i in 240: f.step(1.0/60)
 var weighted:=0.0; var total:=0.0
 for y in 10:
  for x in 16: weighted+=x*f.depth[y*16+x]; total+=f.depth[y*16+x]
 check(weighted/maxf(total,.0001)>start_moment+1,"terrain gradient sends water downhill")
 f.set_level(0,0,1)
 f.set_level(0,0,0)
 check(absf(f.total_volume()-(f.source_volume-f.sink_volume))<.0001,"boundary exchange has explicit volume ledger")
 f.evaporation=.01
 f.step(.2)
 check(absf(f.total_volume()-(f.source_volume-f.sink_volume-f.evaporated_volume))<.0001,"evaporation has explicit volume ledger")
 check(f.state_image().get_format()==Image.FORMAT_RGBAF,"render output retains float depth level dye and flux")
 print("SURFACE_FLOW checks=",checks," failures=",failures)
 quit(failures)
