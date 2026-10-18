extends Node3D

## Floor B contains six bricks on each axis. One gameplay cell is ONE brick.
## UVs are baked once from the cell, never from a camera/player uniform.
const MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_pixel_light_material.tres")
const BRICKS_PER_TEXTURE := 6
static var meshes: Dictionary = {}

@onready var floor_mesh: MeshInstance3D = $FloorMesh


func _ready() -> void:
	floor_mesh.mesh = get_phase_mesh(phase())
	floor_mesh.material_override = MATERIAL
	# Floor is a world receiver (layer 1), matching ceiling and flashlight
	# cull masks.  This is presentation-only and does not add gameplay layers.
	floor_mesh.layers = 1
	# 地板是纯受光面：不进 shadow pass，避免掠射手电下的自阴影 acne 条纹。
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 该格的 6×6 纹理相位（烘焙进 UV，Floor visual variant 的唯一来源）。
func phase() -> Vector2i:
	return Vector2i(posmod(roundi(position.x), 6), posmod(roundi(position.z), 6))


## 静态网格工厂：同相位共享同一 ArrayMesh（含烘焙 UV）。
## 供本场景与 Floor 批渲染器（MultiMesh）共用，保证外观逐字节一致。
static func get_phase_mesh(phase: Vector2i) -> ArrayMesh:
	if not meshes.has(phase):
		var data := []
		data.resize(Mesh.ARRAY_MAX)
		data[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5),
			Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)])
		data[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		var uv := Vector2(phase) / float(BRICKS_PER_TEXTURE)
		var step := 1.0 / float(BRICKS_PER_TEXTURE)
		data[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			uv, uv + Vector2(step, 0), uv + Vector2(step, step), uv + Vector2(0, step)])
		data[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
		meshes[phase] = mesh
	return meshes[phase]
