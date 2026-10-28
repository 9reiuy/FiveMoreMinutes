extends Node3D
## Runtime controller for the authored, editor-visible night_coast.tscn.
## Saved scene nodes own geometry, materials and layout; this script only animates them.
const FLOW = preload("res://scripts/simulation/surface_flow.gd")
const SLOPE_MOUNDS: Array[Vector4]=[Vector4(-7.4,26.,2.,.80),Vector4(.8,24.8,1.8,.70),Vector4(-7.6,20.4,1.5,.55),Vector4(1.3,18.5,1.8,.65),Vector4(-6.6,15.2,1.6,.60),Vector4(.2,30.,2.1,.85)]
var slope_dressing: RefCounted
var flow: RefCounted
var flow_texture: ImageTexture
var surface_foam: RefCounted
var coast_shape_texture: ImageTexture
var water_material: ShaderMaterial
var sand_material: ShaderMaterial
var sky_material: ShaderMaterial
var moon_light: DirectionalLight3D
var camera: Camera3D
var character: Sprite3D
@export_range(0, 3600, .1) var clock := 9.0
@export var follow_player_camera := true
@export var near_surf_origin:=Vector2(-120,-112)
var side_surf: RefCounted
var layout: RefCounted
var moon_anchor: Marker3D
var sky: ColorRect
var moon_base_energy := .65
var camera_position_adjustment := Vector3.ZERO
var camera_basis_adjustment := Basis.IDENTITY
var spawn_position := Vector3(-3,0,23)
var moon_visibility := 1.0
var paused := false
var external_step := false
var accumulator := 0.0
var player_position := Vector3(-3,0,23)
var camera_reveal := 0.0
var coast_atlas: AtlasTexture
var walker: Node2D
var status: Label
var show_diagnostics := false
var samples_usec: Array[int] = []
var injected_volume := 0.0
var walking_distance := 0.0
var wave_breakers: Array[Dictionary] = []
var pixel_materials: Array[ShaderMaterial]=[]
var atmosphere: RefCounted
var animated_surfaces: Array[ShaderMaterial]=[]

func _ready() -> void:
 layout=preload("res://scripts/preview/coast_authored_layout.gd").new()
 layout.bind(self)
 camera=get_node("CoastCamera")
 moon_anchor=get_node("WorldMoon")
 moon_light=get_node("MoonLight")
 moon_base_energy=moon_light.light_energy
 sky=get_node("SkyBackdrop/Sky")
 sky_material=sky.material
 sky.size=get_viewport().get_visible_rect().size
 get_viewport().size_changed.connect(_resize_sky)
 water_material=get_node("Water").material_override
 sand_material=get_node("SandRidge").material_override
 character=get_node("Player")
 coast_atlas=character.texture
 var capture: SubViewport=get_node("WalkerCapture")
 capture.world_2d=World2D.new()
 walker=capture.get_node("CoastWalker")
 character.texture=capture.get_texture()
 status=get_node("CoastHUD/Status")
 spawn_position=get_node("PlayerSpawn").position
 player_position=spawn_position
 var reference: Transform3D=camera.get_meta("reference_transform",camera.transform)
 camera_position_adjustment=camera.position-reference.origin
 camera_basis_adjustment=reference.basis.inverse()*camera.basis
 wave_breakers=layout.read_breakers(self)
 slope_dressing=preload("res://scripts/preview/coast_slope_dressing.gd").new()
 slope_dressing.bind(self)
 atmosphere=preload("res://scripts/preview/coast_atmosphere.gd").new()
 atmosphere.bind(self)
 pixel_materials.clear()
 for material in layout.materials(self):
  if material.shader.code.contains("office_dither_lighting.gdshaderinc"):
   pixel_materials.append(material)
 flow=FLOW.new()
 flow.configure(48,40,.5)
 flow.drag=.45
 surface_foam=preload("res://scripts/preview/coast_surface_foam.gd").new()
 surface_foam.configure(48,40)
 for y in 40:
  for x in 48:
   var px: float=-12+(x+.5)*.5
   var pz: float=-16+(y+.5)*.5
   var i:=y*48+x
   flow.bed[i]=surface_height(px,pz)
   if obstacle_distance(Vector2(px,pz))<0: flow.solid[i]=1
   else: flow.set_level(x,y,0)
 flow_texture=ImageTexture.create_from_image(flow.state_image())
 side_surf=preload("res://scripts/preview/coast_near_surf.gd").new()
 side_surf.bind(self)
 _build_coast_shape()
 for material in layout.materials(self):
  if material.shader==water_material.shader:
   animated_surfaces.append(material)
   material.set_shader_parameter("flow_state",flow_texture)
   material.set_shader_parameter("surface_foam",surface_foam.texture)
   material.set_shader_parameter("near_foam",side_surf.patches[0].foam.texture)
   material.set_shader_parameter("near_state",side_surf.patches[0].state)
   material.set_shader_parameter("near_origin",near_surf_origin)
   material.set_shader_parameter("near_size",side_surf.patches[0].size)
   material.set_shader_parameter("near_grid",Vector2(side_surf.patches[0].flow.width,side_surf.patches[0].flow.height))
   material.set_shader_parameter("coast_shape",coast_shape_texture)
 sand_material.set_shader_parameter("coast_shape",coast_shape_texture)
 _place_character()
 update_camera(0,true)
 set_pixel_enabled(bool(SettingsManager.get_setting(&"pixelation_enabled",true)))
 SettingsManager.setting_changed.connect(_on_pixel_setting)
 _update_light()

func _resize_sky() -> void:
 sky.size=get_viewport().get_visible_rect().size

func surface_height(x: float,z: float) -> float:
 return layout.height_at(x,z)

func _on_pixel_setting(key: StringName,value: Variant) -> void:
 if key==&"pixelation_enabled": set_pixel_enabled(bool(value))

func set_pixel_enabled(value: bool) -> void:
 for material in pixel_materials:
  material.set_shader_parameter("office_dither_enabled",value)
  material.set_shader_parameter("office_dither_step",1.0/32.0)

static func coast_edge_x(z: float,side: int) -> float:
 var center:=ridge_center(z)
 for i in range(1,440):
  var x: float=center+side*float(i)*.05
  if coast_distance(x,z)>=0: return x
 return center+side*22.

func obstacle_distance(p: Vector2) -> float:
 var distance:=100.0
 for breaker in wave_breakers: distance=minf(distance,p.distance_to(breaker.p)-float(breaker.radius))
 return distance

static func shore(x: float) -> float:
 return 2.0+sin(x*.38)*1.1+sin(x*.91)*.55+sin(x*1.63)*.18

static func coast_distance(x: float,z: float) -> float:
 var beach_width:=6.8+maxf(z-10.0,0.0)*.10+sin(z*.45)*1.05+sin(z*1.15+1.7)*.4
 var side:=absf(x+3.0)-beach_width
 var coast:=maxf(shore(x)-z,side)
 # Connected shallow inlets on either flank, then sand tongues into the sea.
 coast=maxf(coast,1.6-Vector2((x+9.0)*.7,(z-11.0)*.5).length())
 coast=maxf(coast,1.5-Vector2((x-4.0)*.8,(z-9.0)*.55).length())
 coast=minf(coast,Vector2((x+8.6)*.7,(z-5.0)*.65).length()-1.8)
 coast=minf(coast,Vector2((x-4.6)*.7,(z-14.0)*.9).length()-1.8)
 return coast

static func ridge_center(z: float) -> float:
 return -3.0+sin((z-5.0)*.26)*.45+sin(z*.71)*.12

static func ridge_width(z: float) -> float:
 return 2.2+1.2*exp(-pow((z-9.0)/4.5,2.0))+.06*maxf(z-12.0,0.0)+sin(z*.8)*.25

static func terrain_height(x: float,z: float) -> float:
 var coast:=coast_distance(x,z)
 var beach_raw: float=-coast*.14
 var beach: float=1.15*tanh(beach_raw/1.15) if coast<0 else maxf(-2.8,beach_raw)
 beach+=sin(x*.81+z*.22)*sin(z*.63)*.12*smoothstep(.3,2.0,absf(coast))
 var width:=ridge_width(z)
 var cross_section:=1.0-smoothstep(width-.85,width+1.8,absf(x-ridge_center(z)))
 var front:=4.6+pow(x-ridge_center(z),2)*.10+sin(x*1.6)*.30
 var tip:=smoothstep(front-.6,front+1.65,z)
 var back:=1.0-smoothstep(26.0,33.0,z)
 var climb:=smoothstep(0.0,1.0,clampf((25.0-z)/19.0,0.0,1.0))
 var terrain: float=beach+(0.15+3.85*climb)*cross_section*tip*back
 terrain+=.14*sin(x*1.2+z*.4)*sin(z*.72)*cross_section*tip*climb
 return terrain+slope_mound_height(x,z)

static func slope_mound_height(x: float,z: float) -> float:
 if z<11 or z>35: return 0.0
 var result:=0.0
 for feature in SLOPE_MOUNDS:
  var offset:=Vector2(x-feature.x,z-feature.y)
  var warp: float=1.0+.12*sin(offset.x*1.7+offset.y*.8)+.08*sin(offset.y*2.1-offset.x*.7)
  var distance:=offset.length()/(feature.z*warp)
  if distance<2.3: result+=feature.w*exp(-distance*distance*1.4)
 # Keep the existing central route free from abrupt lateral bumps.
 return result*smoothstep(1.30,2.0,absf(x-ridge_center(z)))

func _build_coast_shape() -> void:
 # Geometry, flow bed and both surface materials share this sampled shoreline.
 var pixels:=PackedFloat32Array(); pixels.resize(256*256*4)
 for y in 256:
  for x in 256:
   var px: float=-28+(x+.5)*56.0/256.0
   var pz: float=-22+(y+.5)*70.0/256.0
   var i: int=(y*256+x)*4
   pixels[i]=surface_height(px,pz)
   var local: Vector3=layout.local_point(px,pz)
   pixels[i+1]=coast_distance(local.x,local.z)
   pixels[i+2]=obstacle_distance(Vector2(px,pz))
   pixels[i+3]=slope_mound_height(px,pz)
 coast_shape_texture=ImageTexture.create_from_image(Image.create_from_data(256,256,false,Image.FORMAT_RGBAF,pixels.to_byte_array()))

func visibility_at(t: float) -> float:
 var direction: Vector3=(moon_anchor.global_position-camera.global_position).normalized()
 var x: float=.72+.55*(direction.x/maxf(-direction.z,.001)-.40)
 var y: float=.16+.8*(.18-direction.y/maxf(-direction.z,.001))
 var field: float=(sin(x*11-t*.22)+.65*sin(x*21+y*30-t*.35)+.35*sin(x*39-y*17-t*.18))*.5
 return 1.0-smoothstep(.1,.65,field)

func _place_character() -> void:
 player_position.y=surface_height(player_position.x,player_position.z)
 character.position=player_position+Vector3(0,.75,0)

func update_camera(delta: float,snap: bool=false) -> void:
 if not follow_player_camera: return
 var local: Vector3=layout.local_point(player_position.x,player_position.z)
 var target_reveal:=smoothstep(0.0,1.0,clampf((20.0-local.z)/11.0,0,1))
 camera_reveal=target_reveal if snap else lerpf(camera_reveal,target_reveal,1.0-exp(-delta*3.5))
 var high_offset: Vector3=get_node("CameraRig/HighOffset").position
 var low_offset: Vector3=get_node("CameraRig/LowOffset").position
 var target_position:=player_position+high_offset.lerp(low_offset,camera_reveal)+camera_position_adjustment
 var look_at_player:=player_position+Vector3(0,.2,-.8)
 var look_at_sea: Vector3=get_node("CameraRig/SeaLookTarget").position
 look_at_sea.x+=player_position.x*.3
 var look_target:=look_at_player.lerp(look_at_sea,camera_reveal)
 if snap: camera.position=target_position
 else: camera.position=camera.position.lerp(target_position,1.0-exp(-delta*6.0))
 camera.look_at(to_global(look_target))
 camera.basis=camera.basis*camera_basis_adjustment

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_SPACE: paused=not paused
  if event.keycode==KEY_F1:
   show_diagnostics=not show_diagnostics
   status.visible=show_diagnostics
  if event.keycode==KEY_R:
   for y in flow.height:
    for x in flow.width: flow.set_level(x,y,0)
   flow.dye.fill(0); flow.flux_x.fill(0); flow.flux_y.fill(0)
   surface_foam.clear()
   side_surf.clear()
   player_position=spawn_position; injected_volume=0
   walker.phase=0; walker.moving=false; walker.pose()
   _place_character(); update_camera(0,true)
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not paused:
  var ray:=camera.project_ray_normal(event.position)
  if ray.y<-.001:
   var hit:=camera.global_position+ray*(-camera.global_position.y/ray.y)
   inject_at(hit,0.55,1.0)

func inject_at(point: Vector3,volume: float,concentration: float) -> void:
 var x:=int(floor((point.x+12)/.5)); var y:=int(floor((point.z+16)/.5))
 if x<0 or y<0 or x>=48 or y>=40: return
 var before: float=flow.source_volume
 flow.add_water(x,y,volume,concentration)
 injected_volume+=flow.source_volume-before

func _process(delta: float) -> void:
 if external_step: return
 var direction:=Input.get_vector("move_left","move_right","move_up","move_down")
 advance(minf(delta,.1),direction)

func advance(delta: float,direction: Vector2=Vector2.ZERO) -> void:
 if paused: return
 clock+=delta
 var previous:=player_position
 player_position+=Vector3(direction.x,0,direction.y)*delta*1.5
 player_position=slope_dressing.resolve_motion(previous,player_position)
 var local: Vector3=layout.local_point(player_position.x,player_position.z)
 local.z=clampf(local.z,6.3,25.0)
 var half_width:=maxf(.10,ridge_width(local.z)-.5)
 local.x=clampf(local.x,ridge_center(local.z)-half_width,ridge_center(local.z)+half_width)
 player_position=layout.terrain.transform*local
 _place_character()
 update_camera(delta)
 var travelled:=Vector2(player_position.x-previous.x,player_position.z-previous.z).length()
 walker.advance(delta,travelled,direction)
 walking_distance+=player_position.distance_to(previous)
 if walking_distance>.25:
  walking_distance=0
  var x:=int((player_position.x+12)/.5); var y:=int((player_position.z+16)/.5)
  if x>=1 and x<47 and y>=1 and y<39 and flow.depth[y*48+x]>.01:
   # A foot displaces existing fluid through the pipes; it creates no water.
   flow.flux_x[y*48+x]+=.16*direction.x
   flow.flux_y[y*48+x]+=.16*direction.y
 accumulator+=delta
 var started:=Time.get_ticks_usec()
 while accumulator>=1.0/30:
  for x in flow.width:
   var group:=.45+.55*pow(.5+.5*sin(float(x)*.22+clock*.06),2.)
   var tide: float=(.14*sin(clock*2.4+float(x)*.10)+.025*sin(clock*3.8-float(x)*.23))*group
   flow.set_level(x,0,tide)
  flow.step(1.0/30)
  surface_foam.step(flow,1.0/30)
  side_surf.advance(1.0/30,clock)
  accumulator-=1.0/30
 if samples_usec.size()<1200: samples_usec.append(Time.get_ticks_usec()-started)
 flow_texture.update(flow.state_image())
 surface_foam.upload()
 side_surf.upload()
 _update_light()

func _update_light() -> void:
 moon_visibility=visibility_at(clock)
 character.modulate=Color(.44,.53,.68).lerp(Color(.83,.88,.96),moon_visibility)
 moon_light.light_energy=moon_base_energy*moon_visibility
 moon_light.look_at(moon_light.global_position-moon_anchor.global_position.normalized(),Vector3.UP)
 slope_dressing.set_moon(moon_visibility)
 for material in animated_surfaces:
  material.set_shader_parameter("scene_time",clock)
  material.set_shader_parameter("moon_visibility",moon_visibility)
 sky_material.set_shader_parameter("scene_time",clock)
 sky_material.set_shader_parameter("moon_visibility",moon_visibility)
 sky_material.set_shader_parameter("sky_inverse_projection",camera.get_camera_projection().inverse())
 sky_material.set_shader_parameter("sky_camera_to_world",camera.global_transform)
 sky_material.set_shader_parameter("moon_direction",(moon_anchor.global_position-camera.global_position).normalized())
 sand_material.set_shader_parameter("scene_time",clock)
 sand_material.set_shader_parameter("moon_visibility",moon_visibility)
 atmosphere.update(clock,moon_visibility,self)
 for material in pixel_materials: material.set_shader_parameter("moon_visibility",moon_visibility)
 var horizon: Vector2=camera.unproject_position(Vector3(camera.global_position.x,0,-800))
 sky_material.set_shader_parameter("horizon_y",clampf(horizon.y/maxf(sky.size.y,1.),0,1))
 status.text="月光 %02d%%  /  地表流动 48×40  /  染色水 %.2f m³"%[moon_visibility*100,injected_volume]
