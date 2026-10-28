extends RefCounted
## Conservative finite-volume surface flow. Metres, seconds, cubic metres.
## One height per cell: puddles/rivers, not overturning three-dimensional fluid.
var width: int
var height: int
var cell_size := 0.5
var gravity := 9.81
var drag := 1.6
var evaporation := 0.0
var maximum_substep := 1.0/60.0 # Coarse previews may raise this; CFL still bounds it.
var depth := PackedFloat32Array()
var bed := PackedFloat32Array()
var dye := PackedFloat32Array() # Dye volume, NOT concentration.
var solid := PackedByteArray()
var flux_x := PackedFloat32Array()
var flux_y := PackedFloat32Array()
var source_volume := 0.0
var sink_volume := 0.0
var evaporated_volume := 0.0
var simulation_seconds := 0.0
var steps := 0

func configure(w: int, h: int, spacing: float = 0.5) -> void:
 assert(w>1 and h>1 and spacing>0.0)
 width=w; height=h; cell_size=spacing
 var n:=w*h
 depth.resize(n); bed.resize(n); dye.resize(n); solid.resize(n)
 flux_x.resize(n); flux_y.resize(n)
 depth.fill(0); bed.fill(0); dye.fill(0); solid.fill(0)
 flux_x.fill(0); flux_y.fill(0)
 source_volume=0; sink_volume=0; evaporated_volume=0
 simulation_seconds=0; steps=0

func add_water(x: int, y: int, volume: float, concentration: float = 0.0) -> void:
 if x<0 or y<0 or x>=width or y>=height or volume<=0: return
 var i:=y*width+x
 if solid[i]!=0: return
 depth[i]+=volume/(cell_size*cell_size)
 dye[i]+=volume*clampf(concentration,0,1)
 source_volume+=volume

func set_level(x: int, y: int, level: float) -> void:
 var i:=y*width+x
 if solid[i]!=0: return
 var target:=maxf(0,level-bed[i])
 var difference: float=(target-depth[i])*cell_size*cell_size
 if difference>=0: source_volume+=difference
 else:
  sink_volume-=difference
  dye[i]*=target/maxf(depth[i],0.000001)
 depth[i]=target

func total_volume() -> float:
 var result:=0.0
 for v in depth: result+=v*cell_size*cell_size
 return result

func total_dye() -> float:
 var result:=0.0
 for v in dye: result+=v
 return result

func step(delta: float) -> void:
 # Split caller deltas using a shallow-water CFL bound.
 var maximum:=0.01
 for v in depth: maximum=maxf(maximum,v)
 var safe_dt:=minf(maximum_substep,0.22*cell_size/sqrt(gravity*maximum))
 var remaining:=maxf(delta,0.0)
 while remaining>0.000001:
  var dt:=minf(remaining,safe_dt)
  _substep(dt)
  remaining-=dt

func _substep(dt: float) -> void:
 var n:=width*height
 var outgoing:=PackedFloat32Array(); outgoing.resize(n)
 var area:=cell_size*cell_size
 var damping:=exp(-drag*dt)
 for y in height:
  for x in width:
   var i:=y*width+x
   if x+1<width: flux_x[i]=_pipe(i,i+1,flux_x[i],dt,damping)
   if y+1<height: flux_y[i]=_pipe(i,i+width,flux_y[i],dt,damping)
   var qx: float=flux_x[i]
   var qy: float=flux_y[i]
   if qx>0: outgoing[i]+=qx
   elif x+1<width: outgoing[i+1]-=qx
   if qy>0: outgoing[i]+=qy
   elif y+1<height: outgoing[i+width]-=qy
 var limiter:=PackedFloat32Array(); limiter.resize(n)
 for i in n: limiter[i]=minf(1.0,depth[i]*area/maxf(outgoing[i]*dt,0.0000001))
 var next_depth:=depth.duplicate()
 var next_dye:=dye.duplicate()
 for y in height:
  for x in width:
   var i:=y*width+x
   if x+1<width:
    flux_x[i]*=limiter[i if flux_x[i]>=0 else i+1]
    _transfer(i,i+1,flux_x[i]*dt,next_depth,next_dye,area)
   if y+1<height:
    flux_y[i]*=limiter[i if flux_y[i]>=0 else i+width]
    _transfer(i,i+width,flux_y[i]*dt,next_depth,next_dye,area)
 depth=next_depth; dye=next_dye
 if evaporation>0:
  for i in n:
   var loss:=minf(depth[i],evaporation*dt)
   depth[i]-=loss
   evaporated_volume+=loss*area
   # Dye is transported with the remaining fluid; residue retained on drying.
 simulation_seconds+=dt
 steps+=1

func _pipe(a: int,b: int,q: float,dt: float,damping: float) -> float:
 if solid[a]!=0 or solid[b]!=0: return 0.0
 var surface_a: float=bed[a]+depth[a]
 var surface_b: float=bed[b]+depth[b]
 var hydraulic_depth:=maxf(0,maxf(surface_a,surface_b)-maxf(bed[a],bed[b]))
 return (q+gravity*hydraulic_depth*(surface_a-surface_b)*dt)*damping

func _transfer(a: int,b: int,volume: float,next_depth: PackedFloat32Array,next_dye: PackedFloat32Array,area: float) -> void:
 var donor:=a if volume>=0 else b
 var concentration:=clampf(dye[donor]/maxf(depth[donor]*area,0.0000001),0,1)
 next_depth[a]-=volume/area; next_depth[b]+=volume/area
 next_dye[a]-=volume*concentration; next_dye[b]+=volume*concentration

func state_image() -> Image:
 var pixels:=PackedFloat32Array(); pixels.resize(width*height*4)
 for i in width*height:
  pixels[i*4]=depth[i]
  pixels[i*4+1]=bed[i]+depth[i]
  pixels[i*4+2]=clampf(dye[i]/maxf(depth[i]*cell_size*cell_size,0.000001),0,1)
  pixels[i*4+3]=sqrt(flux_x[i]*flux_x[i]+flux_y[i]*flux_y[i])
 return Image.create_from_data(width,height,false,Image.FORMAT_RGBAF,pixels.to_byte_array())
