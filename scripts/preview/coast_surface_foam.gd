extends RefCounted
## Foam tracer driven by the shallow-water solver, not a scrolling texture.
## It has its own lifetime; it never changes water volume or momentum.
var width: int
var height: int
var density:=PackedFloat32Array()
var production:=PackedFloat32Array()
var velocity_x:=PackedFloat32Array()
var velocity_y:=PackedFloat32Array()
var texture: ImageTexture
var source_enabled:=true

func configure(w: int,h: int) -> void:
 width=w; height=h
 density.resize(w*h); density.fill(0)
 production.resize(w*h); production.fill(0)
 velocity_x.resize(w*h); velocity_x.fill(0)
 velocity_y.resize(w*h); velocity_y.fill(0)
 texture=ImageTexture.create_from_image(state_image())

func clear() -> void:
 density.fill(0); production.fill(0); velocity_x.fill(0); velocity_y.fill(0); texture.update(state_image())

func sample_field(field: PackedFloat32Array,x: float,y: float) -> float:
 x=clampf(x,0,width-1.00001); y=clampf(y,0,height-1.00001)
 var ix:=int(x); var iy:=int(y)
 var u:=x-ix; var v:=y-iy; var i:=iy*width+ix
 return lerpf(lerpf(field[i],field[i+1],u),lerpf(field[i+width],field[i+width+1],u),v)

func step(flow: RefCounted,dt: float) -> void:
 var next:=density.duplicate()
 var area: float=flow.cell_size*flow.cell_size
 for y in height:
  for x in width:
   var i:=y*width+x
   production[i]=0
   if flow.solid[i]!=0 or flow.depth[i]<.03:
    next[i]=0; continue
   var left:=i-1 if x>0 else i; var up:=i-width if y>0 else i
   var right:=i+1 if x+1<width else i; var down:=i+width if y+1<height else i
   var vx: float=(flow.flux_x[i]+flow.flux_x[left])*.5/maxf(flow.depth[i]*flow.cell_size,.025)
   var vy: float=(flow.flux_y[i]+flow.flux_y[up])*.5/maxf(flow.depth[i]*flow.cell_size,.025)
   velocity_x[i]=vx; velocity_y[i]=vy
   var advected:=sample_field(density,x-vx*dt/flow.cell_size,y-vy*dt/flow.cell_size)
   var level: float=flow.bed[i]+flow.depth[i]
   var curvature: float=maxf(0,level-(flow.bed[left]+flow.depth[left]+flow.bed[right]+flow.depth[right]+flow.bed[up]+flow.depth[up]+flow.bed[down]+flow.depth[down])*.25)
   var compression: float=maxf(0,-(flow.flux_x[i]-flow.flux_x[left]+flow.flux_y[i]-flow.flux_y[up])/area)
   var crest: float=smoothstep(.008,.035,compression)*smoothstep(.00003,.00035,curvature)*smoothstep(.005,.035,level)
   var interior:=smoothstep(0.,3.,minf(minf(x,width-1-x),minf(y,height-1-y)))
   production[i]=crest*interior if source_enabled else 0.
   next[i]=clampf(advected*exp(-dt/.80)+production[i]*dt*2.5,0,1)
 density=next

func upload() -> void:
 texture.update(state_image())

func state_image() -> Image:
 var pixels:=PackedFloat32Array(); pixels.resize(width*height*4)
 for i in density.size():
  pixels[i*4]=density[i]; pixels[i*4+1]=production[i]
  pixels[i*4+2]=velocity_x[i]; pixels[i*4+3]=velocity_y[i]
 return Image.create_from_data(width,height,false,Image.FORMAT_RGBAF,pixels.to_byte_array())
