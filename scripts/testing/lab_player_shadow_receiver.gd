extends Node
## Sample overhead lighting just above the player's own proxy on the face.

const ORIGINAL_LIGHT_POSITION := "if (reference_depth_enabled) { LIGHT_VERTEX = spatial_position; }"
const FACE_PARAMETERS := """
uniform bool lab_face_receiver = false;
uniform float lab_face_shadow_top = 0.0;
uniform vec3 lab_capture_to_head_row;
"""
const FACE_LIGHT_POSITION := """
	if (reference_depth_enabled) {
		LIGHT_VERTEX = spatial_position;
		if (lab_face_receiver) {
			float head_row = dot(lab_capture_to_head_row, vec3(UV, 1.0));
			float face_weight = 1.0 - smoothstep(23.0, 26.0, head_row);
			if (face_weight > 0.0) {
				vec3 sample_world = (INV_VIEW_MATRIX * vec4(spatial_position, 1.0)).xyz;
				sample_world.y += max(lab_face_shadow_top - sample_world.y, 0.0) * face_weight;
				LIGHT_VERTEX = (VIEW_MATRIX * vec4(sample_world, 1.0)).xyz;
			}
		}
	}
"""

var enabled := true
@onready var world := get_parent() as Node3D
var _material: ShaderMaterial
var _original_shader: Shader
var _face_shader: Shader


func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_update_face_sample)


func _update_face_sample() -> void:
	var bridge: Node3D = world.player_depth_bridge
	var body: Sprite3D = bridge.actor_sprite
	var volume: Node3D = bridge.volume_shadow
	if not is_instance_valid(body) or not is_instance_valid(volume):
		return
	var material := body.material_override as ShaderMaterial
	if material == null or material.shader == null:
		return
	if material != _material or material.shader != _face_shader:
		_restore()
		if not material.shader.code.contains(ORIGINAL_LIGHT_POSITION):
			return
		_material = material
		_original_shader = material.shader
		_face_shader = Shader.new()
		_face_shader.code = _original_shader.code.replace("shader_type spatial;", "shader_type spatial;" + FACE_PARAMETERS)
		_face_shader.code = _face_shader.code.replace(ORIGINAL_LIGHT_POSITION, FACE_LIGHT_POSITION)
		# Keep the material that the actor and floor-reflection systems update.
		_material.shader = _face_shader

	_material.set_shader_parameter("lab_face_receiver", enabled)
	if not enabled:
		return
	var capture_index: int = bridge.source_paths.find(^"CharacterVisual")
	var capture: Node2D = bridge.clone_roots[capture_index]
	var head := capture.get_node(^"BodyPivot/Head") as Sprite2D
	var to_head := head.global_transform.affine_inverse()
	var capture_size: Vector2i = bridge.render_viewport.size
	var head_row := Vector3(to_head.x.y * capture_size.x, to_head.y.y * capture_size.y, to_head.origin.y)
	var proxy_top := -INF
	for part: MeshInstance3D in volume.parts.values():
		var bounds := part.global_transform * part.get_aabb()
		proxy_top = maxf(proxy_top, bounds.end.y)
	_material.set_shader_parameter("lab_capture_to_head_row", head_row)
	_material.set_shader_parameter("lab_face_shadow_top", proxy_top + 0.03)


func _restore() -> void:
	if is_instance_valid(_material) and _material.shader == _face_shader:
		_material.shader = _original_shader


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_update_face_sample)
	_restore()
