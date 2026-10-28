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

func bind(coast: Node3D) -> void:
 root=coast.get_node("OffshoreAtmosphere")
 for turbine in root.get_children():
  if not turbine is Node3D or not String(turbine.name).begins_with("Turbine_"): continue
  turbine_count+=1
  for rotor in turbine.find_children("Rotor","Node3D",true,false):
   rotors.append(rotor); rotor_rest.append(rotor.rotation.z)
 for node in root.find_children("*","MeshInstance3D",true,false):
  var material: ShaderMaterial=node.material_override as ShaderMaterial
  if not material: continue
  var path: String=material.shader.resource_path
  if path.ends_with("coast_distant_signal.gdshader"):
   signals.append(material); signal_nodes.append(node)
   if bool(material.get_shader_parameter("long_signal")): dash_count+=1
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
