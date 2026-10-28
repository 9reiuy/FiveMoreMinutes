extends Node3D
class_name Furniture3DDebris

## Presentation-only low-poly pixel debris burst for destroyed 3D furniture.
## Pure visual kinematics without RigidBody3D or physics server allocation.

const GRAVITY: float = 12.0
const LIFETIME: float = 1.6
const FADE_TIME: float = 0.4
const PERF=preload("res://scripts/app/performance_markers.gd")

# Keep at most two actually used Compatibility material variants resident:
# with and without an albedo texture. Each burst still owns its fading material.
# Do not share mutable alpha between overlapping bursts.
static var shader_variant_anchors: Dictionary = {}
static var _shared_box_mesh: BoxMesh

var pieces: Array[Dictionary] = []
var elapsed: float = 0.0
var material_override: StandardMaterial3D

func _ready() -> void:
	set_process(true)

static func spawn(parent: Node, spawn_pos: Vector3, texture: Texture2D, piece_count: int = 6, impulse_dir: Vector3 = Vector3.ZERO) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var diagnostic_started:=PERF.begin(parent)
	var debris_script = load("res://scripts/dream/furniture_3d_debris.gd")
	var debris: Node3D = debris_script.new()
	debris.position = spawn_pos
	parent.add_child(debris)
	debris.add_to_group(&"perf_furniture_debris")
	debris.call("_setup", texture, piece_count, impulse_dir)
	PERF.end(parent,"fracture_build",diagnostic_started)
	PERF.event(parent,"furniture_break",{"pieces":piece_count,"x":spawn_pos.x,"y":spawn_pos.y,"z":spawn_pos.z})
	return debris

func _setup(texture: Texture2D, count: int, impulse_dir: Vector3) -> void:
	material_override = StandardMaterial3D.new()
	material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_override.roughness = 0.9
	if texture != null:
		material_override.albedo_texture = texture
	if not bool(get_meta(&"test_legacy_debris_material_lifetime",false)):
		var textured := texture != null
		if not shader_variant_anchors.has(textured):
			shader_variant_anchors[textured] = material_override

	var rng := RandomNumberGenerator.new()
	if has_meta(&"test_debris_seed"):
		rng.seed = int(get_meta(&"test_debris_seed"))
	else:
		rng.randomize()

	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3(0.0625, 0.0625, 0.0625) # 2x2x2 px voxel cube

	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _shared_box_mesh
		mi.material_override = material_override
		add_child(mi)

		var offset := Vector3(
			rng.randf_range(-0.15, 0.15),
			rng.randf_range(0.05, 0.35),
			rng.randf_range(-0.15, 0.15)
		)
		mi.position = offset

		var base_dir := impulse_dir.normalized() if impulse_dir.length_squared() > 0.01 else Vector3.ZERO
		var vel := Vector3(
			base_dir.x * rng.randf_range(0.5, 1.8) + rng.randf_range(-1.2, 1.2),
			rng.randf_range(1.5, 3.2),
			base_dir.z * rng.randf_range(0.5, 1.8) + rng.randf_range(-1.2, 1.2)
		)

		var rot_axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var rot_speed := rng.randf_range(4.0, 12.0)

		pieces.append({
			"mesh": mi,
			"velocity": vel,
			"rot_axis": rot_axis,
			"rot_speed": rot_speed,
			"bounces": 0
		})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return

	var fade_start := LIFETIME - FADE_TIME
	if elapsed > fade_start and material_override != null:
		var alpha := clampf((LIFETIME - elapsed) / FADE_TIME, 0.0, 1.0)
		material_override.albedo_color.a = alpha

	for p in pieces:
		var mi: MeshInstance3D = p["mesh"]
		if mi == null or not is_instance_valid(mi):
			continue

		var vel: Vector3 = p["velocity"]
		vel.y -= GRAVITY * delta
		mi.position += vel * delta

		# Floor bounce at Y = 0.03
		if mi.position.y <= 0.03125:
			mi.position.y = 0.03125
			var bounces: int = p["bounces"]
			if bounces < 2 and absf(vel.y) > 0.5:
				vel.y = -vel.y * 0.35
				vel.x *= 0.6
				vel.z *= 0.6
				p["bounces"] = bounces + 1
			else:
				vel = Vector3.ZERO
				p["rot_speed"] = 0.0

		p["velocity"] = vel

		var speed: float = p["rot_speed"]
		if speed > 0.001:
			mi.rotate(p["rot_axis"], speed * delta)
