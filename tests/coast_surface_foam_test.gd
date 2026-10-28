extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
 print("PASS " if ok else "FAIL ",label)
func _initialize() -> void:
 var flow: RefCounted=load("res://scripts/simulation/surface_flow.gd").new()
 flow.configure(20,20,.5); flow.bed.fill(-1); flow.depth.fill(1)
 var foam: RefCounted=load("res://scripts/preview/coast_surface_foam.gd").new()
 foam.configure(20,20)
 for i in 30: foam.step(flow,1./30.)
 check(foam.density.count(0.)==400,"flat still water creates no artificial foam")
 var cell:=10*20+8
 flow.depth[cell]=1.1
 flow.flux_x[cell]=-.03; flow.flux_x[cell-1]=.03
 var volume: float=flow.total_volume()
 var depths: PackedFloat32Array=flow.depth.duplicate()
 var flux: PackedFloat32Array=flow.flux_x.duplicate()
 foam.step(flow,1./30.)
 check(foam.production[cell]>.9 and foam.density[cell]>.05,"compressing positive pressure crest produces foam")
 check(is_equal_approx(flow.total_volume(),volume) and flow.depth==depths and flow.flux_x==flux,"foam tracer changes neither water volume nor momentum")
 foam.source_enabled=false; flow.depth.fill(1); flow.flux_x.fill(.2); flow.flux_y.fill(0)
 foam.clear(); foam.density[cell]=1
 for i in 20: foam.step(flow,.05)
 var sum:=0.; var moment:=0.
 for y in 20:
  for x in 20:
   var value: float=foam.density[y*20+x]
   sum+=value; moment+=x*value
 var forward: float=moment/maxf(sum,.000001)
 check(forward>8.7 and forward<8.9,"foam moves with measured positive local current")
 check(sum>.27 and sum<.30,"foam fades with its own finite lifetime")
 foam.clear(); foam.density[cell]=1; flow.flux_x.fill(-.2)
 for i in 20: foam.step(flow,.05)
 sum=0; moment=0
 for y in 20:
  for x in 20:
   var value: float=foam.density[y*20+x]
   sum+=value; moment+=x*value
 check(moment/maxf(sum,.000001)<7.3,"reversing flow reverses foam motion")
 foam.clear(); foam.density[cell]=1; flow.solid[cell]=1
 foam.step(flow,.05)
 check(foam.density[cell]==0,"solid obstacle clears foam in its occupied cell")
 foam.clear(); foam.upload()
 check(foam.density.count(0.)==400 and foam.texture.get_image().get_pixel(8,10).r==0,"reset clears both simulated and uploaded foam")
 print("FINAL checks=",checks," failures=",failures); quit(failures)
