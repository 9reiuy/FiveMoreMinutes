extends SceneTree
const SYSTEM := preload("res://scripts/dream/surface_blood_system.gd")
const MODEL := preload("res://scripts/dream/props/mini_forklift_3d.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var blood := SYSTEM.new()
	scene.add_child(blood)
	check(blood.use_surface_meshes, "normal game defaults to the verified fitted blood renderer")
	blood.set_surface_meshes(true)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.2, 6)
	floor_mesh.mesh = box
	scene.add_child(floor_mesh)
	check(blood.register_receiver(floor_mesh, "floor") == 0, "real floor retains its isolated blood query")
	await frames(3)
	var hit := blood.trace(Vector3(0.4, 2, 0.2), Vector3(0.4, -1, 0.2))
	check(not hit.is_empty(), "blood traces actual geometry")
	if hit.is_empty(): quit(1); return
	blood.deposit(hit, 4.0)
	blood._flush_faces()
	var face: Dictionary = blood.faces[0]
	var mark: MeshInstance3D = face.ref.get_ref()
	check(mark != null and mark.mesh.get_surface_count() == 1, "paint creates receiving-surface triangles rather than a projected decal")
	var fitted := true
	for vertex in mark.mesh.get_faces():
		fitted = fitted and absf(vertex.y - 0.103) < 0.0001 and absf(vertex.x) <= 3.001 and absf(vertex.z) <= 3.001
	check(fitted, "blood covers only the actual top face with a small stable world-space separation")
	check(mark.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and bool(mark.get_meta(&"surface_blood_excluded")), "blood creates neither shadow geometry nor recursive receivers")
	check((mark.layers & SYSTEM.RECEIVER_LAYER) == 0, "blood cannot receive another projected stain")
	check(mark.material_override.get_shader_parameter(&"blood_texture") == face.texture, "merged pixel blood image is preserved")
	var mark_id := mark.get_instance_id()
	blood.deposit(hit, 3.0)
	blood._flush_faces()
	check(blood.faces.size() == 1 and blood.faces[0].ref.get_ref().get_instance_id() == mark_id and face.paint_count == 2, "repeated impacts update one surface instead of overlapping transparent sheets")
	var expected := Vector3(0.4, 0.103, 0.2)
	floor_mesh.position = Vector3(7, 2, -3)
	floor_mesh.rotation.y = 0.7
	check(mark.to_global(expected).is_equal_approx(floor_mesh.to_global(expected)), "blood follows the receiver without leaving marks on nearby geometry")
	var stash := Node3D.new()
	root.add_child(stash)
	floor_mesh.reparent(stash)
	blood.reparent(stash)
	await frames(2)
	floor_mesh.reparent(scene)
	blood.reparent(scene)
	check(is_instance_valid(mark) and mark.get_instance_id() == mark_id, "stash and restore preserve the original stain")
	blood.set_surface_meshes(false)
	check(blood.faces[0].ref.get_ref() is Decal and blood.faces[0].paint_count == 2, "legacy diagnostic switch preserves painted data")
	blood.set_surface_meshes(true)
	check(blood.faces[0].ref.get_ref() is MeshInstance3D and floor_mesh.find_children("*", "Decal", true, false).is_empty(), "switching back removes all legacy projection volumes")
	blood.clear_blood()
	check(blood.faces.is_empty() and floor_mesh.find_children("AttachedOrangeBlood", "Node3D", true, false).is_empty(), "clear releases attached marks")
	floor_mesh.rotation.z = 0.25
	floor_mesh.scale = Vector3(1.2, 0.8, 0.9)
	await frames(3)
	var slope_hit := blood.trace(floor_mesh.to_global(Vector3(0, 1, 0)), floor_mesh.to_global(Vector3(0, -1, 0)))
	check(not slope_hit.is_empty(), "moved and scaled receiver still takes blood")
	if not slope_hit.is_empty():
		blood.deposit(slope_hit, 3.0)
		var slope_mark: MeshInstance3D = blood.faces[0].ref.get_ref()
		var world_plane := floor_mesh.to_global(Vector3(0, 0.1, 0))
		var normal: Vector3 = slope_hit.normal
		var depth_ok := true
		for vertex in slope_mark.mesh.get_faces():
			depth_ok = depth_ok and absf((floor_mesh.to_global(vertex) - world_plane).dot(normal) - 0.003) < 0.0001
		check(depth_ok and slope_mark.mesh.get_surface_count() == 1, "scaled slope preserves a three-millimetre separation without depth flicker")
	blood.clear_blood()
	var model := MODEL.new()
	scene.add_child(model)
	blood.register_receiver(model.body_mesh_instance, "vehicle")
	await frames(3)
	var vehicle_hit := blood.trace(Vector3(-0.5, 4, 0.2), Vector3(-0.5, 0, 0.2))
	check(not vehicle_hit.is_empty(), "original forklift has receiving geometry")
	if not vehicle_hit.is_empty():
		blood.deposit(vehicle_hit, 3.0)
		blood._flush_faces()
		var vehicle_mark: MeshInstance3D = blood.faces[0].ref.get_ref()
		var material := vehicle_mark.material_override
		model.set_driver_onboard(true)
		check(vehicle_mark.material_override == material and material.get_shader_parameter(&"blood_texture") != null, "boarding preserves the attached blood material")
		model.set_driver_onboard(false)
		check(vehicle_mark.material_override == material, "dismount restores cutout without stripping the blood")
	var receiver_ref: WeakRef = weakref(floor_mesh)
	var system_ref: WeakRef = weakref(blood)
	scene.free()
	stash.free()
	await frames(2)
	check(receiver_ref.get_ref() == null and system_ref.get_ref() == null, "unload releases receivers and their blood host")
	print("SURFACE_BLOOD_MESH checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
