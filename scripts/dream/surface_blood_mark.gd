extends RefCounted
## Paint only the receiving triangles. No projection volume or shared decal atlas.
const SHADER := preload("res://shaders/dream3d/surface_blood_mark.gdshader")
const PLANE_TOLERANCE := 0.011
const SURFACE_LIFT := 0.003

static func prewarm(host: Node3D, camera: Camera3D) -> void:
	if not is_instance_valid(camera) or DisplayServer.get_name() == "headless": return
	# Compile the opaque, alpha-clipped pipeline during floor loading, before
	# the first visible hit. The tiny triangle is completely transparent.
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"blood_texture", ImageTexture.create_from_image(image))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.01,-0.01,0),Vector3(0,0.01,0),Vector3(0.01,-0.01,0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var warm := MeshInstance3D.new()
	warm.name = "BloodMaterialWarmup"
	warm.set_meta(&"surface_blood_excluded", true)
	warm.mesh = mesh
	warm.material_override = material
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	host.add_child(warm)
	warm.global_transform = camera.global_transform * Transform3D(Basis.IDENTITY, Vector3(0,0,-maxf(camera.near + 0.1, 1.0)))
	await RenderingServer.frame_post_draw
	if is_instance_valid(warm): warm.queue_free()


static func create(receiver: Dictionary, face: Dictionary) -> MeshInstance3D:
	var owner: Node3D = receiver.owner.get_ref()
	var body: StaticBody3D = receiver.body.get_ref()
	var mark := MeshInstance3D.new()
	mark.name = "AttachedOrangeBlood"
	mark.set_meta(&"surface_blood_excluded", true)
	mark.set_meta(&"surface_blood_mark", true)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mark.layers = (owner.layers if owner is VisualInstance3D else 1) & ~(1 << 16)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"blood_texture", face.texture)
	# Reflection carriers must retain this live material: later splashes update
	# its merged image, and floor rollback must not restore an empty old copy.
	material.set_meta(&"runtime_uniform_owner", true)
	if owner is MeshInstance3D:
		for surface in owner.mesh.get_surface_count():
			var source: Material = owner.get_active_material(surface)
			if source is ShaderMaterial and source.shader != null and source.shader.code.contains("occlusion_cutout.gdshaderinc"):
				var cutout: Variant = source.get_shader_parameter(&"occlusion_cutout_enabled")
				material.set_shader_parameter(&"occlusion_cutout_enabled", cutout != false)
				break
	mark.material_override = material
	if is_instance_valid(body):
		var collision := body.get_child(0) as CollisionShape3D
		mark.mesh = _surface_mesh(collision.shape.get_faces(), face, owner.global_basis)
	owner.add_child(mark)
	return mark


static func _surface_mesh(triangles: PackedVector3Array, face: Dictionary, owner_basis: Basis) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var u: Vector3 = face.u
	var v: Vector3 = face.v
	var normal := v.cross(u).normalized()
	var origin: Vector3 = face.origin
	var metres: Vector2 = Vector2(face.dimensions) / 32.0
	# Offset in world metres even on scaled furniture; do not bias the depth test.
	var lift := SURFACE_LIFT / maxf((owner_basis * normal).length(), 0.001)
	for i in range(0, triangles.size(), 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		var surface_normal := (c - a).cross(b - a).normalized()
		if absf(surface_normal.dot(normal)) < 0.99: continue
		if surface_normal.dot(normal) < 0.0:
			var swap := b; b = c; c = swap
			surface_normal = -surface_normal
		var polygon := PackedVector3Array([a, b, c])
		# Clip to this atlas tile AND its actual plane. Nearby panels and the
		# underside of a floor never inherit the same blood image.
		for boundary in [
			[u, u.dot(origin) + metres.x * 0.5], [-u, -u.dot(origin) + metres.x * 0.5],
			[v, v.dot(origin) + metres.y * 0.5], [-v, -v.dot(origin) + metres.y * 0.5],
			[normal, normal.dot(origin) + PLANE_TOLERANCE],
			[-normal, -normal.dot(origin) + PLANE_TOLERANCE]]:
			polygon = _clip(polygon, boundary[0], boundary[1])
			if polygon.size() < 3: break
		for j in range(1, polygon.size() - 1):
			if (polygon[j] - polygon[0]).cross(polygon[j + 1] - polygon[0]).length_squared() < 1e-12: continue
			for point: Vector3 in [polygon[0], polygon[j], polygon[j + 1]]:
				vertices.append(point + surface_normal * lift)
				normals.append(surface_normal)
				var relative := point - origin
				uvs.append(Vector2(relative.dot(u) / metres.x, relative.dot(v) / metres.y) + Vector2.ONE * 0.5)
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _clip(polygon: PackedVector3Array, axis: Vector3, limit: float) -> PackedVector3Array:
	var clipped := PackedVector3Array()
	if polygon.is_empty(): return clipped
	var previous := polygon[-1]
	var previous_distance := previous.dot(axis) - limit
	for current in polygon:
		var distance := current.dot(axis) - limit
		if (distance <= 0.0) != (previous_distance <= 0.0):
			clipped.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance <= 0.0: clipped.append(current)
		previous = current
		previous_distance = distance
	return clipped
