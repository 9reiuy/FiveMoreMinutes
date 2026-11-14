extends RefCounted
# Fuse three retained effects: brushed lobe -> toon response -> illuminated rim.
const TOON="res://shaders/dream3d/office_style_toon.gdshaderinc"
const ACCEPTED="res://shaders/dream3d/office_style_materials.gdshaderinc"
const BRUSH="res://shaders/dream3d/office_style_brushed.gdshaderinc"
var records:Array[Dictionary]=[]
var shaders:Dictionary={}
var enabled:=false
var toon_enabled:=true
var brush_enabled:=true
var statistics:Dictionary={"edge":0,"furniture":0,"plain":0}

func setup(world:Node) -> void:
	for node in world.find_children("*","MeshInstance3D",true,false):
		if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		if node.material_override!=null:register(node.material_override)
		elif node.mesh!=null:
			for s in node.mesh.get_surface_count():register(node.get_active_material(s))
	set_enabled(true)

func register(material:Material) -> void:
	if not material is ShaderMaterial or material.shader==null:return
	if records.any(func(r:Dictionary)->bool:return r.material==material):return
	var raw:String=material.shader.code
	if raw.contains("stack_toon_enabled") or raw.contains("unshaded") or raw.contains("capture_texture"):return
	if not raw.contains("void light()") or not raw.contains("ATTENUATION"):return
	if not (raw.contains("architecture_world") or raw.contains("office_dither_position") or raw.contains("apply_light_noise_contour")):return
	var furniture:=raw.contains(ACCEPTED)
	var edge:=raw.contains("edge_style_coverage")
	if not shaders.has(raw):
		var code:=raw.replace("shader_type spatial;","shader_type spatial;\n#include \""+TOON+"\"\nuniform bool stack_toon_enabled=true;\n")
		if furniture:
			code=code.replace("#include \""+ACCEPTED+"\"","#include \""+ACCEPTED+"\"\n#include \""+BRUSH+"\"\n")
			code=code.replace("furniture_finish_lobe(LIGHT, VIEW, furniture_direct_normal, furniture_direct_finish)","comparison_finish_lobe(LIGHT, VIEW, furniture_direct_normal, furniture_direct_finish)")
		var prefix:="\nvec3 stack_diffuse_before=DIFFUSE_LIGHT;vec3 stack_specular_before=SPECULAR_LIGHT;\n"
		var factor:="(1.0-.35*material_family(furniture_direct_finish).x)" if furniture else "1.0"
		var suffix:="""
if(stack_toon_enabled){
 vec3 stack_luma=vec3(.2126,.7152,.0722);
 float stack_light=max(dot(LIGHT_COLOR,stack_luma),0.0);
 vec3 stack_diffuse=DIFFUSE_LIGHT-stack_diffuse_before;
 float stack_amount=dot(stack_diffuse,stack_luma);
 if(stack_light>0.000001 && stack_amount>0.000001){
  float stack_response=stack_amount*PI/(stack_light*%s);
  DIFFUSE_LIGHT=stack_diffuse_before+stack_diffuse*(preview_toon_diffuse(stack_response)/max(stack_response,.000001));
 }
"""%factor
		if furniture:
			suffix+="""
 vec3 stack_specular=SPECULAR_LIGHT-stack_specular_before;
 float stack_highlight=dot(stack_specular,stack_luma);
 if(stack_light>0.000001 && stack_highlight>0.000001){
  float stack_response=stack_highlight*PI/stack_light;
  SPECULAR_LIGHT=stack_specular_before+stack_specular*(preview_toon_specular(stack_response)/max(stack_response,.000001));
 }
"""
		suffix+="}\n"
		code=inject_prefix(code,"light",prefix)
		# Keep the light-driven edge as a final lobe; the toon body must not
		# threshold away the narrow rim or force extra varyings into this shader.
		if edge:code=code.replace("if(edge_style_rim){",suffix+"\nif(edge_style_rim){")
		else:code=inject_suffix(code,"light",suffix)
		var shader:=Shader.new();shader.code=code;shaders[raw]=shader
	records.append({"material":material,"original":material.shader,"combined":shaders[raw],"edge":edge,"furniture":furniture})
	statistics["furniture" if furniture else "plain"]+=1
	if edge:statistics.edge+=1

func inject_prefix(code:String,function:String,prefix:String) -> String:
	var opening:=code.find("{",code.find("void "+function+"()"))
	return code.substr(0,opening+1)+prefix+code.substr(opening+1)

func inject_suffix(code:String,function:String,suffix:String) -> String:
	var opening:=code.find("{",code.find("void "+function+"()"));var ending:=opening+1;var depth:=1
	while depth>0 and ending<code.length():
		if code[ending]=="{":depth+=1
		elif code[ending]=="}":depth-=1
		ending+=1
	return code.substr(0,ending-1)+suffix+code.substr(ending-1)

func set_enabled(value:bool) -> void:
	enabled=value
	for r:Dictionary in records:
		var material:ShaderMaterial=r.material;var parameters:Dictionary={}
		for uniform in material.shader.get_shader_uniform_list():
			var current:Variant=material.get_shader_parameter(uniform.name)
			if current!=null:parameters[uniform.name]=current
		material.shader=r.combined if value else r.original
		for key in parameters:
			if key not in ["stack_toon_enabled","comparison_brush_enabled"]:material.set_shader_parameter(key,parameters[key])
		if value:
			material.set_shader_parameter("stack_toon_enabled",toon_enabled)
			if r.furniture:material.set_shader_parameter("comparison_brush_enabled",brush_enabled)

func set_components(toon:bool,brush:bool,rim:bool) -> void:
	toon_enabled=toon;brush_enabled=brush
	for r:Dictionary in records:
		r.material.set_shader_parameter("stack_toon_enabled",toon)
		if r.furniture:r.material.set_shader_parameter("comparison_brush_enabled",brush)
		if r.edge:
			r.material.set_shader_parameter("edge_style_rim",rim)

func restore() -> void:set_enabled(false);records.clear();shaders.clear()
