extends Node
## Keep enemy captures and pooled blood on the original camera and depth buffer.
const ACTOR_BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
const ENVIRONMENT_INKS = preload("res://scripts/preview/sample_environment_halftone.gd")
const SOURCE_OUTLINE = preload("res://shaders/sprite_alpha_outline.gdshader")
const ENEMY_INK_HEADER := """
#include "res://shaders/preview/hellkind_sample/ink_points.gdshaderinc"
uniform bool use_room_palette = false;
uniform vec3 room_dark_ink;
uniform vec3 room_light_ink;
"""
const ENEMY_INK := """
	if (pixel.a > 0.05 && !smoke_silhouette && hurt_flash_amount <= 0.5) {
		float luminance = dot(ink_linear(ALBEDO), vec3(0.2126, 0.7152, 0.0722));
		float coverage = sqrt(clamp((luminance - 0.014) / 0.986, 0.0, 1.0));
		float peak = max(ALBEDO.r, max(ALBEDO.g, ALBEDO.b));
		vec3 bright_ink = ALBEDO * (0.90 / max(peak, 0.00001));
		vec3 dark_ink = vec3(5.0, 6.0, 10.0) / 255.0;
		float ink_scale = max(1.0, VIEWPORT_SIZE.y / 360.0);
		if (use_room_palette) {
			bright_ink = room_light_ink;
			dark_ink = room_dark_ink;
		}
		EMISSION = ink_output(coverage >= ink_threshold(FRAGCOORD.xy / ink_scale) ? bright_ink : dark_ink);
		ALBEDO = vec3(0.0);
	}
"""
const SOLID_BODY_INK := """
	if (pixel.a > 0.05 && !smoke_silhouette && hurt_flash_amount <= 0.5) {
		vec3 bright_ink = use_room_palette ? room_light_ink : vec3(236.0, 239.0, 246.0) / 255.0;
		vec3 dark_ink = use_room_palette ? room_dark_ink : vec3(0.0);
		EMISSION = ink_output(pixel.r >= 0.5 ? bright_ink : dark_ink);
		ALBEDO = vec3(0.0);
	}
"""

var _bridges: Node3D
var _enabled := false
var _body_palette_enabled := false
var _materials: Dictionary = {}
var _body_materials: Dictionary[ShaderMaterial, bool] = {}
var _shaders: Dictionary[Shader, Shader] = {}
var _solid_body_shaders: Dictionary[Shader, Shader] = {}
var _source_materials: Dictionary[ShaderMaterial, bool] = {}
var _source_inks: Shader

func configure(bridges: Node3D) -> void:
	_bridges = bridges
	_source_inks = Shader.new()
	_source_inks.code = SOURCE_OUTLINE.code.replace("shader_type canvas_item;", """shader_type canvas_item;
#include "res://shaders/preview/hellkind_sample/authored_enemy_inks.gdshaderinc"
""").replace("vec4 result = base;", """vec4 result = base;
	result.rgb = vec3(authored_enemy_ink(base.rgb, ivec2(floor(UV / TEXTURE_PIXEL_SIZE))));
""")
	for bridge in _bridges.get_children():
		_register_bridge(bridge)
	get_tree().node_added.connect(_node_added)

func _node_added(node: Node) -> void:
	if node is Sprite3D and is_instance_valid(_bridges) and node.get_parent().get_parent() == _bridges:
		_register_bridge.call_deferred(node.get_parent())

func _register_bridge(bridge: Node) -> void:
	if not is_instance_valid(bridge) or bridge.get_parent() != _bridges or bridge.get_script() != ACTOR_BRIDGE: return
	if bridge.blood_material != null:
		_register(bridge, bridge.blood_material, false)
	elif bridge.character_projection and is_instance_valid(bridge.source_actor) and bridge.source_actor.is_in_group(&"dream_enemies"):
		var authored := bridge.source_actor is EmployeeEnemy
		if authored: _register_body_sources(bridge, bridge.source_actor)
		_register(bridge, bridge.lit_material, true, true, authored)
		_register(bridge, bridge.weapon_material, true)

func _register_body_sources(owner: Node, actor: EmployeeEnemy) -> void:
	for sprite in actor.outline_controller.target_sprites:
		var material := sprite.material as ShaderMaterial
		if material == null or material.shader != SOURCE_OUTLINE or _source_materials.has(material): continue
		_source_materials[material] = actor.enemy_archetype == &"waitress"
		owner.tree_exiting.connect(func():
			if material.shader == _source_inks: _replace_shader(material, SOURCE_OUTLINE)
			_source_materials.erase(material), CONNECT_ONE_SHOT)
		if _enabled: _apply_source_ink(material)

func _apply_source_ink(material: ShaderMaterial) -> void:
	_replace_shader(material, _source_inks if _enabled else SOURCE_OUTLINE)
	if _enabled: material.set_shader_parameter(&"waitress_inks", _source_materials[material])

func _register(owner: Node, material: ShaderMaterial, enemy: bool, body: bool = false, authored: bool = false) -> void:
	if material == null or _materials.has(material): return
	var source := material.shader
	var cache := _solid_body_shaders if authored else _shaders
	if not cache.has(source):
		var code := source.code
		if not code.contains("ALPHA_SCISSOR_THRESHOLD = 0.05;"): return
		# The original shader has already computed per-pixel coverage.
		# Explicit discard retains that coverage but lets colour draw later.
		var tail := "if (ALPHA <= 0.05) { discard; }"
		if enemy:
			code = code.replace("shader_type spatial;", "shader_type spatial;\n" + ENEMY_INK_HEADER)
			code = code.replace("depth_draw_opaque", "depth_draw_always")
			tail += SOLID_BODY_INK if authored else ENEMY_INK
		var variant := Shader.new()
		variant.code = code.replace("ALPHA_SCISSOR_THRESHOLD = 0.05;", tail)
		cache[source] = variant
	_materials[material] = {"source": source, "ink": cache[source]}
	if body: _body_materials[material] = true
	owner.tree_exiting.connect(func():
		_materials.erase(material)
		_body_materials.erase(material), CONNECT_ONE_SHOT)
	if _enabled:
		_replace_shader(material, cache[source])
		if body: _bind_body_palette(material)

func set_enabled(value: bool) -> void:
	if _enabled == value: return
	_enabled = value
	for material in _source_materials:
		_apply_source_ink(material)
	for material: ShaderMaterial in _materials:
		var variants: Dictionary = _materials[material]
		_replace_shader(material, variants.ink if value else variants.source)
	if value:
		for material: ShaderMaterial in _body_materials:
			_bind_body_palette(material)

func set_body_palette(value: bool) -> void:
	_body_palette_enabled = value
	if not _enabled: return
	for material: ShaderMaterial in _body_materials:
		material.set_shader_parameter(&"use_room_palette", value)

func _bind_body_palette(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"room_dark_ink", ENVIRONMENT_INKS.ROOM_DARK_RGB / 255.0)
	material.set_shader_parameter(&"room_light_ink", ENVIRONMENT_INKS.ROOM_LIGHT_RGB / 255.0)
	material.set_shader_parameter(&"use_room_palette", _body_palette_enabled)

func _replace_shader(material: ShaderMaterial, shader: Shader) -> void:
	var saved: Dictionary = {}
	for uniform in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(uniform.name)
		if value != null: saved[uniform.name] = value
	material.shader = shader
	for uniform in shader.get_shader_uniform_list():
		if saved.has(uniform.name): material.set_shader_parameter(uniform.name, saved[uniform.name])
