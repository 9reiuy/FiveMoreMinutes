extends Node3D
## Style the existing player capture and depth carriers in the sample world.
const SOURCE_INKS = preload("res://shaders/preview/hellkind_sample/authored_body_inks.gdshader")
const ACTOR_INKS = preload("res://shaders/preview/hellkind_sample/two_ink_actor.gdshader")
const FLOOR_INKS = preload("res://shaders/preview/hellkind_sample/floor_ink_falloff.gdshader")
const ENVIRONMENT_INKS = preload("res://scripts/preview/sample_environment_halftone.gd")
const GROUND_LENGTH := 1.62

var bridge: Node3D
var player: Node2D
var head: Sprite2D
var source_inks: ShaderMaterial
var actor_inks: ShaderMaterial
var weapon_inks: ShaderMaterial
var floor_ink: MeshInstance3D
var original_head: Material
var original_actor: ShaderMaterial
var original_weapon: ShaderMaterial

func configure(player_bridge: Node3D, camera: Camera3D) -> void:
	bridge = player_bridge
	player = bridge.source_actor
	head = player.get_node(^"CharacterVisual/BodyPivot/Head")
	original_head = head.material
	original_actor = bridge.lit_material
	original_weapon = bridge.weapon_material
	source_inks = ShaderMaterial.new()
	source_inks.shader = SOURCE_INKS
	actor_inks = _make_carrier(original_actor, false)
	actor_inks.set_shader_parameter(&"room_dark_ink", ENVIRONMENT_INKS.ROOM_DARK_RGB / 255.0)
	actor_inks.set_shader_parameter(&"room_light_ink", ENVIRONMENT_INKS.ROOM_LIGHT_RGB / 255.0)
	weapon_inks = _make_carrier(original_weapon, true)
	process_priority = bridge.process_priority - 1
	var down := -camera.global_basis.y
	down.y = 0.0
	down = down.normalized()
	floor_ink = MeshInstance3D.new()
	floor_ink.name = "FootDither"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.16, GROUND_LENGTH)
	floor_ink.mesh = plane
	floor_ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FLOOR_INKS
	material.render_priority = -3
	floor_ink.material_override = material
	add_child(floor_ink)
	floor_ink.global_basis = Basis(Vector3.UP.cross(down), Vector3.UP, down)
	set_enabled(false)

func _make_carrier(original: ShaderMaterial, weapon: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ACTOR_INKS
	material.render_priority = original.render_priority
	material.set_shader_parameter("is_weapon", weapon)
	material.set_shader_parameter("warm_outline", not weapon)
	for key in [&"capture_texture", &"reference_depth_enabled", &"reference_plane_origin", &"reference_plane_normal"]:
		material.set_shader_parameter(key, original.get_shader_parameter(key))
	return material

func set_enabled(enabled: bool) -> void:
	head.material = source_inks if enabled else original_head
	bridge.lit_material = actor_inks if enabled else original_actor
	bridge.weapon_material = weapon_inks if enabled else original_weapon
	bridge.actor_sprite.material_override = bridge.lit_material
	bridge.weapon_sprite.material_override = bridge.weapon_material
	floor_ink.visible = enabled
	set_process(enabled)
	if enabled: _process(0.0)

func set_body_palette(enabled: bool) -> void:
	actor_inks.set_shader_parameter(&"use_room_palette", enabled)

func _process(_delta: float) -> void:
	var region := head.texture as AtlasTexture
	if region != null:
		source_inks.set_shader_parameter("frame_origin", region.region.position)
		source_inks.set_shader_parameter("facing", player.character_facing_index)
	floor_ink.visible = player.visible and not bridge.smoke_silhouette
	floor_ink.global_position = bridge._character_ground() + Vector3.UP * 0.027 \
		+ floor_ink.global_basis.z * (GROUND_LENGTH * 0.5 - 0.13)
