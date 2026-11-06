extends RefCounted
## Distant silhouettes, haze, and defocused spatial dot/dash signals.
var root: Node3D
var rotors: Array[Node3D]=[]
var turbine_material: ShaderMaterial
var fog_material: ShaderMaterial
var signals: Array[ShaderMaterial]=[]
var signal_nodes: Array[MeshInstance3D]=[]
var dash_count:=0
var turbine_count:=0
var turbine_outline: ShaderMaterial

var animated_materials: Array[ShaderMaterial]=[]
var rotor_rest: Array[float]=[]
var city_signal := false
var signal_complete := false
var signal_message := "SOS"
var sequence = preload("res://scripts/preview/coast_morse_sequence.gd").new()
var signal_elapsed := 0.
var _last_signal_time := NAN
var _cloud_window := false

func bind(coast: Node3D) -> void:
 root=coast.get_node("OffshoreAtmosphere")
 city_signal=root.has_node("DistantCity")
 sequence.configure(signal_message)
 for turbine in root.get_children():
  if not turbine is Node3D or not String(turbine.name).begins_with("Turbine_"): continue
  turbine_count+=1
  for rotor in turbine.find_children("Rotor","Node3D",true,false):
   rotors.append(rotor); rotor_rest.append(rotor.rotation.z)
 for node in root.find_children("*","MeshInstance3D",true,false):
  var material: ShaderMaterial=node.material_override as ShaderMaterial
  if not material: continue
  var path: String=material.shader.resource_path
  if path.ends_with("coast_distant_signal.gdshader") or path.ends_with("coast_aviation_beacon.gdshader"):
   signals.append(material); signal_nodes.append(node)
   if path.ends_with("coast_distant_signal.gdshader") and bool(material.get_shader_parameter("long_signal")): dash_count+=1
  elif not animated_materials.has(material):
   animated_materials.append(material)
   if path.ends_with("coast_turbine.gdshader"): turbine_material=material
   if path.ends_with("coast_turbine_outline.gdshader"): turbine_outline=material
   if path.ends_with("coast_fog_ribbon.gdshader"): fog_material=material

func update(t: float,visibility: float,coast: Node3D) -> void:
 for material in animated_materials:
  material.set_shader_parameter("moon_visibility",visibility)
  if material.shader.resource_path.ends_with("coast_fog_ribbon.gdshader"):
   material.set_shader_parameter("scene_time",t)
 for i in rotors.size():
  var rotor:=rotors[i]
  rotor.rotation.z=rotor_rest[i]+t*float(rotor.get_meta("angular_speed",.065))+float(rotor.get_meta("phase",i*.9))
 for i in signals.size():
  # Spatial dots/dashes carry SOS; lamps stay on with small continuous shimmer.
  var level:=.88+.045*sin(t*.37+i*1.7)+.025*sin(t*.81+i*.83)
  signals[i].set_shader_parameter("power",level)
  signals[i].set_shader_parameter("moon_visibility",visibility)
 if city_signal:
  var dt := maxf(0.,t-_last_signal_time) if not is_nan(_last_signal_time) else 0.
  _last_signal_time=t
  if visibility<.025:
   signal_elapsed=signal_elapsed+dt if _cloud_window else 0.
   _cloud_window=true
   signal_complete=signal_elapsed>=sequence.content_duration
  else:
   _cloud_window=false; signal_elapsed=0.; signal_complete=false
  var flash: float=sequence.power_at(signal_elapsed) if _cloud_window else 0.
  var strength: float=lerpf(.012,flash,1.-smoothstep(.025,.10,visibility))
  for material in signals: material.set_shader_parameter("power",strength)

func configure_city_signal(message: String) -> void:
 signal_message=message; sequence.configure(message)
 signal_elapsed=0.; signal_complete=false; _cloud_window=false; _last_signal_time=NAN
