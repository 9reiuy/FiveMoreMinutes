extends SceneTree

const ART = preload("res://scripts/dream/office_low_pixel_art.gd")
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const LOGIC = preload("res://scenes/dream/props/desk.tscn")
const VISUAL = preload("res://scripts/dream/furniture_3d_visual.gd")
const THEME = preload("res://scripts/dream/dream_room_environment_theme.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for kind in ["desk", "workstation", "chair", "cabinet", "cabinet_open", "partition"]:
		var source := LOGIC.instantiate() as Node2D
		root.add_child(source)
		CATALOG.configure(source, kind)
		source.set_meta(&"office_pixel_sample", true)
		var collision: RectangleShape2D = source.get_node("CollisionShape2D").shape
		var size_before := collision.size
		var adapter := VISUAL.new()
		root.add_child(adapter)
		adapter.configure(source, null, null, kind)
		var mesh: MeshInstance3D = adapter.visual_instance.get_child(0)
		var bounds := mesh.get_aabb()
		var footprint := CATALOG.footprint(kind)
		check(bounds.position.x >= footprint.position.x / 32.0 - .001 and bounds.end.x <= footprint.end.x / 32.0 + .001, kind + " visual inside X footprint")
		check(bounds.position.z >= footprint.position.y / 32.0 - .001 and bounds.end.z <= footprint.end.y / 32.0 + .001, kind + " visual inside Z footprint")
		check(bounds.end.y <= (1.301 if kind == "workstation" else CATALOG.size_of(kind).y + .001), kind + " visual height matches shot authority")
		var original_uv: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for step in 16:
			source.global_rotation = step * TAU / 16.0
			source.global_position = Vector2(step * 3.0, step * -2.0)
			adapter.call("_sync_transform")
			check(is_equal_approx(adapter.rotation.y, -source.global_rotation), kind + " continuous rotation")
			check(adapter.position.is_equal_approx(Vector3(source.global_position.x / 32.0, 0, source.global_position.y / 32.0)), kind + " follows gameplay position")
			check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == original_uv, kind + " UV invariant under motion")
		check(collision.size == size_before, kind + " collision unchanged")
		check(mesh.material_override == ART.material(), kind + " shared material")
		check(adapter.visual_instance.find_children("*", "CollisionObject3D", true, false).is_empty(), kind + " presentation has no physics")
		print("LOW_PIXEL_ASSET ", kind, " triangles=", mesh.mesh.surface_get_array_index_len(0) / 3, " bounds=", bounds)
		adapter.free()
		source.free()
	var room := {"authored_sample": true, "sample_key": "conference", "archetype": "conference_large"}
	var before := THEME.get_sample_base_floor_material(room)
	ART.enabled = false
	check(THEME.get_sample_base_floor_material(room) == before, "other room material unchanged")
	ART.enabled = true
	print("LOW_PIXEL_VALIDATION failures=", failures)
	quit(0 if failures == 0 else 1)
