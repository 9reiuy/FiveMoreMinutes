extends Node3D
## Passive reusable renderer: no damage, physics, timers or AI.
const SHADER := preload("res://shaders/dream3d/melee_pixel_sweep.gdshader")
var mesh: MeshInstance3D
var material: ShaderMaterial
var capacity := 0.0
func _init() -> void:
	mesh = MeshInstance3D.new()
	mesh.name = "PixelSweep"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = SHADER
	# The weapon owns live opacity/sweep/collision uniforms. Reflection wrapping
	# may adapt its shader in place, but must never freeze a copied material.
	material.set_meta(&"runtime_uniform_owner", true)
	mesh.material_override = material
	add_child(mesh)
	hide()
func sync_snapshot(world: Node3D, snapshot: Dictionary, limits: PackedFloat32Array) -> void:
	var reach: float = snapshot.reach
	if not is_equal_approx(capacity, reach):
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * (reach * 2.0 + 4.0) / 32.0
		mesh.mesh = plane
		capacity = reach
	var point: Vector2 = snapshot.origin
	# Slightly under the authoritative grip plane keeps the weapon readable
	# without disabling depth, forcing draw order or punching through cover.
	var height := maxf(0.025, float(snapshot.get("visual_height", 0.4)) - 0.012)
	global_transform = world.global_transform * Transform3D(Basis.IDENTITY, Vector3(point.x / 32.0, height, point.y / 32.0))
	material.set_shader_parameter("reach", reach)
	material.set_shader_parameter("facing", (snapshot.direction as Vector2).angle())
	material.set_shader_parameter("arc", snapshot.arc)
	material.set_shader_parameter("sweep", snapshot.sweep)
	material.set_shader_parameter("opacity", snapshot.opacity)
	material.set_shader_parameter("band_width", 18.0 if snapshot.weapon_id == "books" else 22.0)
	material.set_shader_parameter("paper", snapshot.weapon_id == "books")
	material.set_shader_parameter("reach_limits", limits)
	visible = float(snapshot.opacity) > 0.01 and float(snapshot.sweep) > 0.0
