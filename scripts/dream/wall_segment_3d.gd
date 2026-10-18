extends Node3D

## One visual adapter owns the complete wall UV and opacity policy.
## Physics belongs to the existing generated 2D edge and never changes here.
const MATERIAL: Material = preload("res://materials/dream3d/interiors_a_wall_pixel_light_material.tres")
const GRADIENT_MATERIAL: ShaderMaterial = preload("res://materials/dream3d/interiors_a_wall_vertical_fade_material.tres")
const SUNSET_SKY_SHADER: Shader = preload("res://shaders/dream3d/window_sunset_sky.gdshader")
## One building-wide ray direction, shared by every eligible exterior window.
const WINDOW_SUN_RAY := Vector3(-0.45, -0.75, -0.48)
static var meshes: Dictionary = {}
static var window_meshes: Dictionary = {}
static var cutaway_meshes: Dictionary = {}
static var cutaway_window_meshes: Dictionary = {}
static var window_glass_material: ShaderMaterial


static func clear_mesh_cache() -> void:
	meshes.clear()
	window_meshes.clear()
	cutaway_meshes.clear()
	cutaway_window_meshes.clear()

@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.1
var wall_opacity := 1.0
var cutaway_mode := false
var wall_visual_visible := true
var wall_shadow_visible := true
## Window walls are a presentation-only variant.  The generated 2D edge and
## gameplay collision remain unchanged, while the visible mesh and shadow caster
## get matching window apertures with central mullion for physically correct sunlight beams.
var window_variant := false
var window_left_post := true
var window_right_post := true
var window_pane_span := 1
var window_pane_offset := 0.0
@onready var wall_mesh: MeshInstance3D = $WallMesh
## A window light is a presentation-only fixture.  The dungeon supplies the
## topology-derived inward normal; this adapter never guesses which side of a
## wall is the room side.
var window_inward_normal := Vector2.ZERO
var window_light_enabled := true
var floor_shadow_lighting_enabled := false
var window_light_energy := 2.2
var window_light_range := 6.5
var window_light_angle := 50.0
var window_light_attenuation := 1.3
var window_light_color := Color(0.52, 0.76, 1.0, 1.0)
var window_light_inset := 0.12
var window_light: SpotLight3D
## Kept for tree hierarchy backwards-compatibility, kept at 0 energy so directional sunlight dominates.
var window_radial_fill: OmniLight3D
## Kept for generator compatibility. The blocker now exactly follows the wall;
## light bias, rather than displaced architecture, handles shadow acne.
var shadow_outward_local_sign := 0.0
# Shadow-only twin of the visible wall, and the ONLY shadow source in both
# opacity states. A 30%-opacity wall is a visual state, never a lighting state:
# the SpotLight must not leak through the faded mesh (Godot turns transparent
# mesh shadow casting unreliable), and with an opaque wall a second coplanar
# depth writer (visible ON + twin) would fight itself into self-shadow stripe
# artifacts under raking light. One blocker per wall, in every state.
var shadow_mesh: MeshInstance3D
var window_pane: MeshInstance3D
var window_glass_cutaway_material: ShaderMaterial


func _ready() -> void:
	shadow_outward_local_sign = float(get_meta(&"shadow_outward_local_sign", 0.0))
	window_variant = bool(get_meta(&"window_variant", false))
	window_left_post = bool(get_meta(&"window_left_post", true))
	window_right_post = bool(get_meta(&"window_right_post", true))
	window_pane_span = int(get_meta(&"window_pane_span", 1))
	window_pane_offset = float(get_meta(&"window_pane_offset", 0.0))
	var inward_variant: Variant = get_meta(&"window_inward_normal", Vector2.ZERO)
	if inward_variant is Vector2:
		window_inward_normal = inward_variant
	_apply_height()
	if shadow_mesh == null:
		shadow_mesh = MeshInstance3D.new()
		shadow_mesh.name = "ShadowCasterMesh"
		# Shadow-only geometry must not inherit the transparent cutout shader used
		# by visible walls; it remains a solid blocker for light and gameplay.
		var shadow_material := StandardMaterial3D.new()
		shadow_material.albedo_color = Color.WHITE
		shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mesh.material_override = shadow_material
		shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(shadow_mesh)
	if shadow_mesh != null:
		shadow_mesh.mesh = _window_wall_mesh if (window_variant and _window_wall_mesh != null) else _base_wall_mesh
	_update_shadow_mesh_transform()
	_update_window_pane()
	_update_window_light()
	set_wall_opacity(wall_opacity)


func configure_wall(height: float, thickness: float = -1.0) -> void:
	wall_height = maxf(height, 0.05)
	if thickness > 0.0:
		wall_thickness = thickness
	if is_node_ready():
		_apply_height()
		_update_window_pane()


func set_wall_height(height: float) -> void:
	configure_wall(height)


## Presentation-only wall variant.  This never changes the generated 2D
## collision, LOS/projectile blocker or navigation boundary.
func set_window_variant(enabled: bool) -> void:
	window_variant = enabled
	set_meta(&"window_variant", enabled)
	if not is_node_ready():
		return
	_apply_height()
	_update_window_pane()
	_update_window_light()
	set_wall_opacity(wall_opacity)


func set_window_run_edges(left_post: bool, right_post: bool) -> void:
	window_left_post = left_post
	window_right_post = right_post
	set_meta(&"window_left_post", left_post)
	set_meta(&"window_right_post", right_post)
	if is_node_ready():
		_apply_height()
		_update_window_pane()


## Configure the directional SpotLight used by a selected window.  The
## normal is expressed in gameplay X/Y (mapped to world X/Z) and is supplied
## by the dungeon topology authority.
func set_window_inward_normal(
	normal: Vector2,
	enabled: bool = true,
	energy: float = 2.2,
	light_range: float = 6.5,
	angle: float = 50.0,
	attenuation: float = 1.3,
	color: Color = Color(0.52, 0.76, 1.0, 1.0),
	inset: float = 0.12
) -> void:
	window_inward_normal = normal.normalized() if normal.length_squared() > 0.001 else Vector2.ZERO
	window_light_enabled = enabled
	window_light_energy = maxf(energy, 0.0)
	window_light_range = maxf(light_range, 0.1)
	window_light_angle = clampf(angle, 1.0, 179.0)
	window_light_attenuation = clampf(attenuation, 0.0, 2.0)
	window_light_color = color
	window_light_inset = maxf(inset, 0.0)
	set_meta(&"window_inward_normal", window_inward_normal)
	_update_window_light()


## The office floor opts into shared directional sunlight. Standalone rooms
## retain their existing window lights until they explicitly opt in.
func set_floor_shadow_lighting_enabled(enabled: bool) -> void:
	floor_shadow_lighting_enabled = enabled
	_update_window_light()


var wall_material_front: Material = MATERIAL
var wall_material_back: Material = MATERIAL
static var architecture_cap: ShaderMaterial
var office_full_mesh: Mesh
var office_cut_mesh: Mesh
var office_section_material: Material

func set_office_cutaway_profile(full_mesh: Mesh,cut_mesh: Mesh,section: Material)->void:
	if office_full_mesh==full_mesh and office_cut_mesh==cut_mesh and office_section_material==section: return
	office_full_mesh=full_mesh; office_cut_mesh=cut_mesh; office_section_material=section
	wall_mesh.mesh=office_cut_mesh if cutaway_mode else office_full_mesh
	_update_wall_materials()
	_update_window_pane()


func set_wall_materials(front_mat: Material, back_mat: Material = null) -> void:
	wall_material_front = front_mat if front_mat != null else MATERIAL
	wall_material_back = back_mat if back_mat != null else wall_material_front
	_update_wall_materials()


func _update_wall_materials() -> void:
	if wall_mesh == null:
		return
	if not cutaway_mode and wall_opacity < 1.0:
		wall_mesh.material_override = GRADIENT_MATERIAL
	else:
		wall_mesh.material_override = null
		for surface in 2:
			var source := wall_material_front if surface == 0 else wall_material_back
			var shown := source
			if cutaway_mode and office_cut_mesh==null and source is ShaderMaterial:
				shown = source.duplicate()
				shown.set_shader_parameter("architecture_cutaway", true)
				shown.set_shader_parameter("architecture_wall_height", wall_height)
			wall_mesh.set_surface_override_material(surface, shown)
		if wall_mesh.mesh != null and wall_mesh.mesh.get_surface_count() > 2:
			if architecture_cap == null:
				architecture_cap = ShaderMaterial.new()
				architecture_cap.shader = preload("res://shaders/dream3d/architecture_cap.gdshader")
			architecture_cap.set_shader_parameter("wall_height", wall_height)
			wall_mesh.set_surface_override_material(2, office_section_material if office_section_material!=null else architecture_cap)


func set_cutaway_mode(enabled: bool) -> void:
	if cutaway_mode == enabled:
		return
	cutaway_mode = enabled
	_update_active_mesh()


func set_wall_opacity(value: float) -> void:
	wall_opacity = 0.30 if value < 0.99 else 1.0
	set_cutaway_mode(wall_opacity < 0.99)


func _update_active_mesh() -> void:
	if wall_mesh == null:
		return
	if office_full_mesh!=null:
		wall_mesh.mesh=office_cut_mesh if cutaway_mode else office_full_mesh
	elif cutaway_mode:
		wall_mesh.mesh = _cutaway_window_mesh if (window_variant and _cutaway_window_mesh != null) else _cutaway_wall_mesh
	else:
		wall_mesh.mesh = _window_wall_mesh if (window_variant and _window_wall_mesh != null) else _base_wall_mesh
	_update_wall_materials()
	# 单一 shadow source：可见墙自身从不???shadow pass，共???twin 是唯一投影者???	wall_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shadow_mesh != null:
		shadow_mesh.mesh = _window_wall_mesh if (window_variant and _window_wall_mesh != null) else _base_wall_mesh
		_update_shadow_mesh_transform()
		shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow_mesh.visible = wall_shadow_visible
	wall_mesh.visible = wall_visual_visible
	_update_window_pane()


## Presentation-only visibility switch.  Corridor and room walls share this
## adapter; the generated 2D wall body, LOS/projectile queries and the
## shadow-only twin are deliberately left untouched.
func set_wall_visual_visible(value: bool) -> void:
	wall_visual_visible = value
	if wall_mesh != null:
		wall_mesh.visible = value
	_update_window_pane()
	_update_window_light()


## Presentation-only shadow switch.  It is intentionally independent from
## gameplay collision, LOS, projectile blocking and navigation.
func set_wall_shadow_visible(value: bool) -> void:
	wall_shadow_visible = value
	if shadow_mesh != null:
		shadow_mesh.visible = value


func _apply_height() -> void:
	if wall_mesh == null:
		return
	var along := position.x if absf(basis.x.x) > 0.5 else -position.z
	var phase := posmod(roundi(along), 3)
	var key := Vector3(wall_height, wall_thickness, phase)
	if not meshes.has(key):
		var mesh := ArrayMesh.new()
		var x := 0.5
		var z := wall_thickness * 0.5
		var h := wall_height
		var u := float(phase) / 3.0
		var face_uv := PackedVector2Array([Vector2(u, 1), Vector2(u + 1.0/3.0, 1), Vector2(u + 1.0/3.0, 0), Vector2(u, 0)])
		var top_uv := PackedVector2Array([Vector2(u,0.01),Vector2(u+1.0/3.0,0.01),Vector2(u+1.0/3.0,0.04),Vector2(u,0.04)])

		var side_u_span := (1.0 / 3.0) * (wall_thickness / 1.0)
		var side_uv_right := PackedVector2Array([
			Vector2(u + 1.0/3.0, 1.0),
			Vector2(u + 1.0/3.0 + side_u_span, 1.0),
			Vector2(u + 1.0/3.0 + side_u_span, 0.0),
			Vector2(u + 1.0/3.0, 0.0)
		])
		var side_uv_left := PackedVector2Array([
			Vector2(u - side_u_span, 1.0),
			Vector2(u, 1.0),
			Vector2(u, 0.0),
			Vector2(u - side_u_span, 0.0)
		])

		# Surface 0: Front face (+Z / BACK) and vertical side faces (RIGHT, LEFT)
		var v0 := PackedVector3Array(); var n0 := PackedVector3Array(); var uv0 := PackedVector2Array(); var idx0 := PackedInt32Array()
		_add_face(v0, n0, uv0, idx0, PackedVector3Array([Vector3(-x,0,z),Vector3(x,0,z),Vector3(x,h,z),Vector3(-x,h,z)]), Vector3.BACK, face_uv)
		_add_face(v0, n0, uv0, idx0, PackedVector3Array([Vector3(x,0,z),Vector3(x,0,-z),Vector3(x,h,-z),Vector3(x,h,z)]), Vector3.RIGHT, side_uv_right)
		_add_face(v0, n0, uv0, idx0, PackedVector3Array([Vector3(-x,0,-z),Vector3(-x,0,z),Vector3(-x,h,z),Vector3(-x,h,-z)]), Vector3.LEFT, side_uv_left)
		var data0 := []; data0.resize(Mesh.ARRAY_MAX)
		data0[Mesh.ARRAY_VERTEX] = v0; data0[Mesh.ARRAY_NORMAL] = n0; data0[Mesh.ARRAY_TEX_UV] = uv0; data0[Mesh.ARRAY_INDEX] = idx0
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data0)

		# Surface 1: Back face (-Z / FORWARD)
		var v1 := PackedVector3Array(); var n1 := PackedVector3Array(); var uv1 := PackedVector2Array(); var idx1 := PackedInt32Array()
		_add_face(v1, n1, uv1, idx1, PackedVector3Array([Vector3(x,0,-z),Vector3(-x,0,-z),Vector3(-x,h,-z),Vector3(x,h,-z)]), Vector3.FORWARD, face_uv)
		var data1 := []; data1.resize(Mesh.ARRAY_MAX)
		data1[Mesh.ARRAY_VERTEX] = v1; data1[Mesh.ARRAY_NORMAL] = n1; data1[Mesh.ARRAY_TEX_UV] = uv1; data1[Mesh.ARRAY_INDEX] = idx1
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data1)

		# Surface 2: Caps and edges (UP)
		var v2 := PackedVector3Array(); var n2 := PackedVector3Array(); var uv2 := PackedVector2Array(); var idx2 := PackedInt32Array()
		_add_face(v2, n2, uv2, idx2, PackedVector3Array([Vector3(-x,h,z),Vector3(x,h,z),Vector3(x,h,-z),Vector3(-x,h,-z)]), Vector3.UP, top_uv)
		var data2 := []; data2.resize(Mesh.ARRAY_MAX)
		data2[Mesh.ARRAY_VERTEX] = v2; data2[Mesh.ARRAY_NORMAL] = n2; data2[Mesh.ARRAY_TEX_UV] = uv2; data2[Mesh.ARRAY_INDEX] = idx2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data2)

		meshes[key] = mesh
	_base_wall_mesh = meshes[key]
	if not cutaway_meshes.has(key):
		cutaway_meshes[key] = _build_cutaway_beam_mesh(wall_height, wall_thickness, phase)
	_cutaway_wall_mesh = cutaway_meshes[key]

	if window_variant:
		var window_key := "%s:%s:%s:%s:%s" % [wall_height, wall_thickness, phase, window_left_post, window_right_post]
		if not window_meshes.has(window_key):
			window_meshes[window_key] = _build_window_mesh(wall_height, wall_thickness, phase)
		_window_wall_mesh = window_meshes[window_key]
		if not cutaway_window_meshes.has(key):
			cutaway_window_meshes[key] = _build_cutaway_window_mesh(wall_height, wall_thickness, phase)
		_cutaway_window_mesh = cutaway_window_meshes[key]
	else:
		_window_wall_mesh = null
		_cutaway_window_mesh = null

	wall_mesh.position = Vector3.ZERO
	_update_active_mesh()


var _base_wall_mesh: Mesh
var _window_wall_mesh: Mesh
var _cutaway_wall_mesh: Mesh
var _cutaway_window_mesh: Mesh


func _build_window_mesh(height: float, thickness: float, phase: int) -> ArrayMesh:
	var v0 := PackedVector3Array(); var n0 := PackedVector3Array(); var uv0 := PackedVector2Array(); var idx0 := PackedInt32Array()
	var v1 := PackedVector3Array(); var n1 := PackedVector3Array(); var uv1 := PackedVector2Array(); var idx1 := PackedInt32Array()
	var v2 := PackedVector3Array(); var n2 := PackedVector3Array(); var uv2 := PackedVector2Array(); var idx2 := PackedInt32Array()
	var half_depth := thickness * 0.5
	var phase_u := float(phase) / 3.0
	var face_uv := PackedVector2Array([
		Vector2(phase_u, 1.0),
		Vector2(phase_u + 1.0 / 3.0, 1.0),
		Vector2(phase_u + 1.0 / 3.0, 0.0),
		Vector2(phase_u, 0.0),
	])
	var top_uv := PackedVector2Array([
		Vector2(phase_u, 0.01),
		Vector2(phase_u + 1.0 / 3.0, 0.01),
		Vector2(phase_u + 1.0 / 3.0, 0.04),
		Vector2(phase_u, 0.04),
	])
	var window_bottom := 0.06
	var window_top := height - 0.05
	var window_half_width := 0.48
	var frame_half_depth := half_depth * 0.5
	_add_box_section_multi(v0, n0, uv0, idx0, v1, n1, uv1, idx1, v2, n2, uv2, idx2, -0.5, 0.5, 0.0, window_bottom, -frame_half_depth, frame_half_depth, face_uv, top_uv)
	_add_box_section_multi(v0, n0, uv0, idx0, v1, n1, uv1, idx1, v2, n2, uv2, idx2, -0.5, 0.5, window_top, height, -frame_half_depth, frame_half_depth, face_uv, top_uv)
	if window_left_post:
		_add_box_section_multi(v0, n0, uv0, idx0, v1, n1, uv1, idx1, v2, n2, uv2, idx2, -0.5, -window_half_width, window_bottom, window_top, -frame_half_depth, frame_half_depth, face_uv, top_uv)
	if window_right_post:
		_add_box_section_multi(v0, n0, uv0, idx0, v1, n1, uv1, idx1, v2, n2, uv2, idx2, window_half_width, 0.5, window_bottom, window_top, -frame_half_depth, frame_half_depth, face_uv, top_uv)

	var mesh := ArrayMesh.new()
	var d0 := []; d0.resize(Mesh.ARRAY_MAX); d0[Mesh.ARRAY_VERTEX] = v0; d0[Mesh.ARRAY_NORMAL] = n0; d0[Mesh.ARRAY_TEX_UV] = uv0; d0[Mesh.ARRAY_INDEX] = idx0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d0)
	var d1 := []; d1.resize(Mesh.ARRAY_MAX); d1[Mesh.ARRAY_VERTEX] = v1; d1[Mesh.ARRAY_NORMAL] = n1; d1[Mesh.ARRAY_TEX_UV] = uv1; d1[Mesh.ARRAY_INDEX] = idx1
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d1)
	var d2 := []; d2.resize(Mesh.ARRAY_MAX); d2[Mesh.ARRAY_VERTEX] = v2; d2[Mesh.ARRAY_NORMAL] = n2; d2[Mesh.ARRAY_TEX_UV] = uv2; d2[Mesh.ARRAY_INDEX] = idx2
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d2)
	return mesh


func _build_cutaway_beam_mesh(height: float, thickness: float, phase: int) -> ArrayMesh:
	var v0 := PackedVector3Array(); var n0 := PackedVector3Array(); var uv0 := PackedVector2Array(); var idx0 := PackedInt32Array()
	var v1 := PackedVector3Array(); var n1 := PackedVector3Array(); var uv1 := PackedVector2Array(); var idx1 := PackedInt32Array()
	var v2 := PackedVector3Array(); var n2 := PackedVector3Array(); var uv2 := PackedVector2Array(); var idx2 := PackedInt32Array()
	var half_depth := thickness * 0.5
	var phase_u := float(phase) / 3.0
	var top_uv := PackedVector2Array([
		Vector2(phase_u, 0.01),
		Vector2(phase_u + 1.0 / 3.0, 0.01),
		Vector2(phase_u + 1.0 / 3.0, 0.04),
		Vector2(phase_u, 0.04),
	])

	# A flat shared cutoff; the material supplies a stationary pixel fade.
	var cutaway_height := height * 0.3
	var bb_top_v := 1.0 - (cutaway_height / height)
	var wall_uv := PackedVector2Array([
		Vector2(phase_u, 1.0),
		Vector2(phase_u + 1.0 / 3.0, 1.0),
		Vector2(phase_u + 1.0 / 3.0, bb_top_v),
		Vector2(phase_u, bb_top_v),
	])
	_add_box_section_multi(v0, n0, uv0, idx0, v1, n1, uv1, idx1, v2, n2, uv2, idx2, -0.5, 0.5, 0.0, cutaway_height, -half_depth, half_depth, wall_uv, top_uv)

	var mesh := ArrayMesh.new()
	var d0 := []; d0.resize(Mesh.ARRAY_MAX); d0[Mesh.ARRAY_VERTEX] = v0; d0[Mesh.ARRAY_NORMAL] = n0; d0[Mesh.ARRAY_TEX_UV] = uv0; d0[Mesh.ARRAY_INDEX] = idx0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d0)
	var d1 := []; d1.resize(Mesh.ARRAY_MAX); d1[Mesh.ARRAY_VERTEX] = v1; d1[Mesh.ARRAY_NORMAL] = n1; d1[Mesh.ARRAY_TEX_UV] = uv1; d1[Mesh.ARRAY_INDEX] = idx1
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d1)
	var d2 := []; d2.resize(Mesh.ARRAY_MAX); d2[Mesh.ARRAY_VERTEX] = v2; d2[Mesh.ARRAY_NORMAL] = n2; d2[Mesh.ARRAY_TEX_UV] = uv2; d2[Mesh.ARRAY_INDEX] = idx2
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d2)
	return mesh


func _build_cutaway_window_mesh(height: float, thickness: float, phase: int) -> ArrayMesh:
	return _build_cutaway_beam_mesh(height, thickness, phase)


func _add_box_section_multi(
	v0: PackedVector3Array, n0: PackedVector3Array, uv0: PackedVector2Array, idx0: PackedInt32Array,
	v1: PackedVector3Array, n1: PackedVector3Array, uv1: PackedVector2Array, idx1: PackedInt32Array,
	v2: PackedVector3Array, n2: PackedVector3Array, uv2: PackedVector2Array, idx2: PackedInt32Array,
	min_x: float, max_x: float, min_y: float, max_y: float, min_z: float, max_z: float,
	face_uv: PackedVector2Array, top_uv: PackedVector2Array
) -> void:
	if max_x <= min_x or max_y <= min_y or max_z <= min_z:
		return
	var side_u_span := (1.0 / 3.0) * (max_z - min_z)
	var side_uv_right := PackedVector2Array([
		Vector2(face_uv[1].x, face_uv[1].y),
		Vector2(face_uv[1].x + side_u_span, face_uv[1].y),
		Vector2(face_uv[1].x + side_u_span, face_uv[2].y),
		Vector2(face_uv[1].x, face_uv[2].y),
	])
	var side_uv_left := PackedVector2Array([
		Vector2(face_uv[0].x - side_u_span, face_uv[0].y),
		Vector2(face_uv[0].x, face_uv[0].y),
		Vector2(face_uv[0].x, face_uv[3].y),
		Vector2(face_uv[0].x - side_u_span, face_uv[3].y),
	])
	# Surface 0: Front face (+Z / BACK) and vertical side faces (RIGHT, LEFT)
	_add_face(v0, n0, uv0, idx0, PackedVector3Array([
		Vector3(min_x, min_y, max_z), Vector3(max_x, min_y, max_z),
		Vector3(max_x, max_y, max_z), Vector3(min_x, max_y, max_z),
	]), Vector3.BACK, face_uv)
	_add_face(v0, n0, uv0, idx0, PackedVector3Array([
		Vector3(max_x, min_y, max_z), Vector3(max_x, min_y, min_z),
		Vector3(max_x, max_y, min_z), Vector3(max_x, max_y, max_z),
	]), Vector3.RIGHT, side_uv_right)
	_add_face(v0, n0, uv0, idx0, PackedVector3Array([
		Vector3(min_x, min_y, min_z), Vector3(min_x, min_y, max_z),
		Vector3(min_x, max_y, max_z), Vector3(min_x, max_y, min_z),
	]), Vector3.LEFT, side_uv_left)
	# Surface 1: Back face (-Z / FORWARD)
	_add_face(v1, n1, uv1, idx1, PackedVector3Array([
		Vector3(max_x, min_y, min_z), Vector3(min_x, min_y, min_z),
		Vector3(min_x, max_y, min_z), Vector3(max_x, max_y, min_z),
	]), Vector3.FORWARD, face_uv)
	# Surface 2: Horizontal caps (UP, DOWN)
	_add_face(v2, n2, uv2, idx2, PackedVector3Array([
		Vector3(min_x, max_y, max_z), Vector3(max_x, max_y, max_z),
		Vector3(max_x, max_y, min_z), Vector3(min_x, max_y, min_z),
	]), Vector3.UP, top_uv)
	_add_face(v2, n2, uv2, idx2, PackedVector3Array([
		Vector3(min_x, min_y, min_z), Vector3(max_x, min_y, min_z),
		Vector3(max_x, min_y, max_z), Vector3(min_x, min_y, max_z),
	]), Vector3.DOWN, top_uv)


func _add_box_section(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	min_z: float,
	max_z: float,
	face_uv: PackedVector2Array,
	top_uv: PackedVector2Array
) -> void:
	if max_x <= min_x or max_y <= min_y or max_z <= min_z:
		return
	var side_u_span := (1.0 / 3.0) * (max_z - min_z)
	var side_uv_right := PackedVector2Array([
		Vector2(face_uv[1].x, face_uv[1].y),
		Vector2(face_uv[1].x + side_u_span, face_uv[1].y),
		Vector2(face_uv[1].x + side_u_span, face_uv[2].y),
		Vector2(face_uv[1].x, face_uv[2].y),
	])
	var side_uv_left := PackedVector2Array([
		Vector2(face_uv[0].x - side_u_span, face_uv[0].y),
		Vector2(face_uv[0].x, face_uv[0].y),
		Vector2(face_uv[0].x, face_uv[3].y),
		Vector2(face_uv[0].x - side_u_span, face_uv[3].y),
	])
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(min_x, min_y, max_z), Vector3(max_x, min_y, max_z),
		Vector3(max_x, max_y, max_z), Vector3(min_x, max_y, max_z),
	]), Vector3.BACK, face_uv)
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(max_x, min_y, min_z), Vector3(min_x, min_y, min_z),
		Vector3(min_x, max_y, min_z), Vector3(max_x, max_y, min_z),
	]), Vector3.FORWARD, face_uv)
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(max_x, min_y, max_z), Vector3(max_x, min_y, min_z),
		Vector3(max_x, max_y, min_z), Vector3(max_x, max_y, max_z),
	]), Vector3.RIGHT, side_uv_right)
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(min_x, min_y, min_z), Vector3(min_x, min_y, max_z),
		Vector3(min_x, max_y, max_z), Vector3(min_x, max_y, min_z),
	]), Vector3.LEFT, side_uv_left)
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(min_x, max_y, max_z), Vector3(max_x, max_y, max_z),
		Vector3(max_x, max_y, min_z), Vector3(min_x, max_y, min_z),
	]), Vector3.UP, top_uv)
	_add_face(vertices, normals, uvs, indices, PackedVector3Array([
		Vector3(min_x, min_y, min_z), Vector3(max_x, min_y, min_z),
		Vector3(max_x, min_y, max_z), Vector3(min_x, min_y, max_z),
	]), Vector3.DOWN, top_uv)


func _update_window_pane() -> void:
	if not window_variant or window_pane_span <= 0:
		if window_pane != null:
			window_pane.visible = false
		return
	if window_pane == null:
		window_pane = MeshInstance3D.new()
		window_pane.name = "WindowGlassVisual"
		window_pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(window_pane)
	if window_glass_material == null:
		window_glass_material = ShaderMaterial.new()
		window_glass_material.shader = SUNSET_SKY_SHADER
	if cutaway_mode:
		if window_glass_cutaway_material == null:
			window_glass_cutaway_material = window_glass_material.duplicate() as ShaderMaterial
			window_glass_cutaway_material.set_shader_parameter("architecture_cutaway", true)
		window_glass_cutaway_material.set_shader_parameter("architecture_wall_height", wall_height)
		window_pane.material_override = window_glass_cutaway_material
	else:
		window_pane.material_override = window_glass_material
	var window_bottom := 0.06
	var window_top := wall_height - 0.05
	var pane_h := window_top - window_bottom
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = Vector3(float(window_pane_span), pane_h, wall_thickness * 0.5)
	window_pane.mesh = pane_mesh
	window_pane.position = Vector3(window_pane_offset, (window_bottom + window_top) * 0.5, 0.0)
	window_pane.visible = wall_visual_visible and not (office_cut_mesh!=null and cutaway_mode)


func _update_window_light() -> void:
	if floor_shadow_lighting_enabled or not window_variant or not window_light_enabled or window_inward_normal.length_squared() < 0.001:
		if window_light != null:
			window_light.visible = false
		if window_radial_fill != null:
			window_radial_fill.visible = false
		if window_radial_fill != null:
			window_radial_fill.visible = false
		return
	if window_light == null:
		window_light = SpotLight3D.new()
		window_light.name = "WindowLight"
		add_child(window_light)
	if window_radial_fill == null:
		window_radial_fill = OmniLight3D.new()
		window_radial_fill.name = "WindowRadialFill"
		add_child(window_radial_fill)

	# Direct golden-hour sunlight through window aperture casting crisp contact shadows
	# One soft source per continuous pane run.  Per-cell hard shadow cones made
	# intersecting triangular bands across entire rooms.
	window_light.shadow_enabled = false
	window_light.shadow_blur = 0.8
	window_light.shadow_bias = 0.03
	window_light.shadow_normal_bias = 1.0
	window_light.shadow_opacity = 0.95
	# Illuminate Layer 1 (floor, walls, furniture, props, enemies), Layer 2 (player visual), Layer 4 (player shadow proxy)
	window_light.light_cull_mask = 1 | 2 | 4 | 8  # + furniture cutout layer
	window_light.spot_range = maxf(window_light_range, 0.1)
	window_light.spot_angle = clampf(window_light_angle, 1.0, 89.0)
	window_light.spot_attenuation = clampf(window_light_attenuation, 0.0, 2.0)
	window_light.light_energy = maxf(window_light_energy, 0.0)
	window_light.light_color = window_light_color
	window_light.light_specular = 0.3

	# Keep radial fill node for node tree compatibility, but disable it so it doesn't wash out shadows
	window_radial_fill.visible = false
	window_radial_fill.light_energy = 0.0
	window_radial_fill.shadow_enabled = false
	window_radial_fill.global_position = global_position + Vector3.UP * (wall_height * 0.5)

	var inward_local := Vector3(window_inward_normal.x, 0.0, window_inward_normal.y)
	var map_parent := get_parent_node_3d()
	var map_basis := map_parent.global_basis if map_parent != null else Basis.IDENTITY
	var inward := (map_basis * inward_local).normalized()
	var ray := WINDOW_SUN_RAY.normalized()
	var ray_horizontal := Vector3(ray.x, 0.0, ray.z).normalized()
	# Facades facing away from the shared sun have sky colour but no impossible
	# direct beam through the wall from the room side.
	if inward.dot(ray_horizontal) <= 0.25:
		window_light.visible = false
		return
	var light_pos := global_position - ray_horizontal * 1.05 + Vector3.UP * (wall_height * 0.90)
	var target := light_pos + ray * 3.0

	window_light.global_position = light_pos
	window_light.look_at(target, Vector3.UP)
	window_light.visible = wall_visual_visible


func _update_shadow_mesh_transform() -> void:
	if shadow_mesh == null:
		return
	# Moving the blocker by half a wall thickness detaches contact shadows and
	# opens corner leaks. It must use the exact uncut architectural geometry.
	shadow_mesh.transform = Transform3D.IDENTITY


func _add_face(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, corners: PackedVector3Array, normal: Vector3, face_uv: PackedVector2Array) -> void:
	var start := vertices.size()
	vertices.append_array(corners)
	for _i in range(4):
		normals.append(normal)
	uvs.append_array(face_uv)
	indices.append_array(PackedInt32Array([start, start+2, start+1, start, start+3, start+2]))
