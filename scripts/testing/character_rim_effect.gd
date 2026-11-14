extends RefCounted
## Test-only A/B binding. Production uses the shared carrier directly.
const INCLUDE := "res://shaders/dream3d/character_pixel_rim.gdshaderinc"
var bindings: Array[Dictionary] = []
var variants: Dictionary = {}
var _bound: Dictionary = {}
var _bridges: Dictionary = {}
var enabled := false
var strength := 1.8
var width := 1.0
var backscatter := 0.4

static func inject(code: String, function: String, suffix: String) -> String:
	var start := code.find("void "+function+"()")
	if start < 0: return code+"\nvoid "+function+"(){"+suffix+"}\n"
	var opening := code.find("{",start)
	var ending := opening+1
	var depth := 1
	while depth > 0 and ending < code.length():
		if code[ending] == "{": depth += 1
		elif code[ending] == "}": depth -= 1
		ending += 1
	return code.substr(0,ending-1)+suffix+code.substr(ending-1)

func variant(original: Shader) -> Shader:
	var code := original.code
	if variants.has(code): return variants[code]
	# Include after the existing uniforms so its functions can read capture and
	# the existing smoke/hit states. Standard lighting and reference depth stay.
	var first_function := code.find("float cutout_factor")
	code = code.insert(first_function,"#include \""+INCLUDE+"\"\n")
	code = inject(code,"fragment","\nactor_pixel_rim_sides = actor_pixel_rim_fragment(UV, ALPHA);\n")
	code = inject(code,"light","\nSPECULAR_LIGHT += actor_pixel_rim_light(actor_pixel_rim_sides, LIGHT, NORMAL, LIGHT_COLOR, ATTENUATION);\n")
	var shader := Shader.new(); shader.code = code
	variants[original.code] = shader
	return shader

func baseline(original: Shader) -> Shader:
	var code := original.code
	if variants.has(code): return variants[code]
	code = code.replace("#include \""+INCLUDE+"\"","")
	code = code.replace("actor_pixel_rim_sides = actor_pixel_rim_fragment(UV, ALPHA);","")
	code = code.replace("SPECULAR_LIGHT += actor_pixel_rim_light(actor_pixel_rim_sides, LIGHT, NORMAL, LIGHT_COLOR, ATTENUATION);","")
	var shader := Shader.new(); shader.code=code
	variants[original.code]=shader
	return shader

func bind_material(material: ShaderMaterial, role: StringName = &"body", other: Texture2D = null) -> void:
	if material == null or material.shader == null: return
	if _bound.has(material.get_instance_id()): return
	if not material.shader.code.contains("uniform float character_emission_strength"): return
	var native := material.shader.code.contains(INCLUDE)
	var saved: Dictionary = {}
	if native:
		for key in ["actor_pixel_rim_enabled","actor_pixel_rim_strength","actor_pixel_rim_width","actor_pixel_rim_backscatter","actor_pixel_rim_has_other_capture","actor_pixel_rim_other_capture","actor_pixel_rim_other_uv_scale","actor_pixel_rim_other_uv_offset"]:
			saved[key]=material.get_shader_parameter(key)
	var binding := {"material":weakref(material),"original":material.shader,"baseline":baseline(material.shader) if native else material.shader,"candidate":material.shader if native else variant(material.shader),"role":role,"other":other,"saved":saved}
	bindings.append(binding)
	_bound[material.get_instance_id()]=true
	_apply(binding,enabled)

func bind_bridge(bridge: Node) -> void:
	if bridge.get("character_projection") != true: return
	var body := bridge.get("lit_material") as ShaderMaterial
	var weapon := bridge.get("weapon_material") as ShaderMaterial
	var id := bridge.get_instance_id()
	if _bridges.get(id,[])==[body,weapon]: return
	_bridges[id]=[body,weapon]
	bind_material(body,&"body",weapon.get_shader_parameter("capture_texture") if weapon != null else null)
	bind_material(weapon,&"weapon",body.get_shader_parameter("capture_texture") if body != null else null)

func _apply(binding: Dictionary, active: bool) -> void:
	var material: ShaderMaterial = binding.material.get_ref()
	if material == null: return
	material.shader = binding.candidate if active else binding.baseline
	if active:
		material.set_shader_parameter("actor_pixel_rim_enabled",true)
		material.set_shader_parameter("actor_pixel_rim_strength",strength)
		material.set_shader_parameter("actor_pixel_rim_width",width)
		material.set_shader_parameter("actor_pixel_rim_backscatter",backscatter)
		material.set_shader_parameter("actor_pixel_rim_has_other_capture",binding.other != null)
		if binding.other != null:
			material.set_shader_parameter("actor_pixel_rim_other_capture",binding.other)
			var texture: Texture2D = material.get_shader_parameter("capture_texture")
			var uv_scale: Vector2 = texture.get_size()/binding.other.get_size()
			material.set_shader_parameter("actor_pixel_rim_other_uv_scale",uv_scale)
			material.set_shader_parameter("actor_pixel_rim_other_uv_offset",(Vector2.ONE-uv_scale)*0.5)

func set_enabled(value: bool) -> void:
	enabled = value
	for binding in bindings: _apply(binding,value)

func clear() -> void:
	for binding in bindings:
		var material: ShaderMaterial = binding.material.get_ref()
		if material == null: continue
		material.shader=binding.original
		for key in binding.saved: material.set_shader_parameter(key,binding.saved[key])
	enabled=false
	bindings.clear(); variants.clear(); _bound.clear(); _bridges.clear()
