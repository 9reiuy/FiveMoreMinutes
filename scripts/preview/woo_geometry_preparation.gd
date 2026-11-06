extends RefCounted
## Submit real resident mesh layouts during the loading cover. Material boxes
## alone do not prepare their UV2/tangent/instancing layouts on Compatibility.
static func prepare_footstep_slots(tree: SceneTree, world: Node3D) -> void:
	var pool: Node = world.floor_root.get_node_or_null(^"FootstepSmoke")
	if pool == null: return
	var saved: Array[Dictionary] = []
	var point: Vector3 = world.get_gameplay_world_position(world.player.global_position, 0.12)
	for index in pool.sprites.size():
		var sprite: Sprite3D = pool.sprites[index]
		saved.append({"sprite": sprite, "visible": sprite.visible, "transform": sprite.transform, "modulate": sprite.modulate, "flip": sprite.flip_h, "texture": sprite.texture, "pixel_size": sprite.pixel_size})
		sprite.texture = pool.variants[index % pool.variants.size()]
		sprite.pixel_size = pool.variant_pixel_size
		sprite.global_position = point + Vector3((index % 9) * 0.02, 0, (index / 9) * 0.02)
		sprite.scale = Vector3.ONE * 0.6
		sprite.modulate = Color.WHITE
		sprite.flip_h = (index % 2) == 0
		sprite.visible = true
	await RenderingServer.frame_post_draw
	for record in saved: record.sprite.modulate.a = 0.6
	await RenderingServer.frame_post_draw
	for record in saved:
		var sprite: Sprite3D = record.sprite
		sprite.transform = record.transform
		sprite.visible = record.visible
		sprite.modulate = record.modulate
		sprite.flip_h = record.flip
		sprite.texture = record.texture
		sprite.pixel_size = record.pixel_size
	await tree.process_frame

static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	var viewport := SubViewport.new()
	viewport.name = "WooGeometryPreparation"
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = world.get_viewport().positional_shadow_atlas_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var space := Node3D.new()
	viewport.add_child(space)
	space.get_world_3d().environment = world.get_world_3d().environment
	var camera := Camera3D.new()
	space.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.position = Vector3(0, 14, 14)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	camera.cull_mask = 65535
	var key := DirectionalLight3D.new()
	space.add_child(key)
	key.rotation_degrees = Vector3(-35, 45, 0)
	key.light_cull_mask = 65535
	var sun := DirectionalLight3D.new()
	space.add_child(sun)
	sun.rotation_degrees = Vector3(-50, -45, 0)
	sun.shadow_enabled = true
	sun.light_cull_mask = 65535
	if is_instance_valid(world.shadow_manager) and is_instance_valid(world.shadow_manager.sun):
		sun.directional_shadow_mode = world.shadow_manager.sun.directional_shadow_mode
		sun.directional_shadow_blend_splits = world.shadow_manager.sun.directional_shadow_blend_splits
	var families: Array[Dictionary] = []
	var seen: Dictionary = {}
	var actors: Node = world.get_node_or_null(^"ActorDepthBridges")
	var capture_roots: Array[Node] = []
	if actors != null:
		for child in actors.get_children():
			var script := child.get_script() as Script
			if script != null and script.resource_path in ["res://scripts/dream/dream_3d_actor_depth_bridge.gd", "res://scripts/dream/blood_airborne_carrier_3d.gd"]: capture_roots.append(child)
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or node.is_queued_for_deletion(): continue
		var captured := false
		for capture in capture_roots:
			if capture.is_ancestor_of(node): captured = true; break
		if captured: continue
		if is_instance_valid(world.player_depth_bridge) and world.player_depth_bridge.is_ancestor_of(node): continue
		_collect(node.mesh, node, seen, families)
	# Full/cut variants share materials, but their real vertex layouts must both
	# be resident before the first room/door transition.
	for wall in world.wall_root.get_children():
		if wall.get_script() != preload("res://scripts/dream/wall_segment_3d.gd"): continue
		for mesh: Mesh in [wall.office_full_mesh, wall.office_cut_mesh]:
			if mesh != null: _collect(mesh, wall.wall_mesh, seen, families)
	for state in 16:
		var layer := 1 << state
		var at := Vector3((state % 4 - 1.5) * 3, 0, (state / 4 - 1.5) * 3)
		for family in families:
			var mesh := MeshInstance3D.new()
			mesh.mesh = family.mesh
			mesh.material_override = family.override
			mesh.material_overlay = family.overlay
			if family.override == null:
				for index in family.surfaces.size(): mesh.set_surface_override_material(index, family.surfaces[index])
			var bounds: AABB = family.mesh.get_aabb()
			var largest: float = maxf(0.01, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
			mesh.scale = Vector3.ONE * (0.6 / largest)
			mesh.position = at - bounds.get_center() * (0.6 / largest)
			mesh.layers = layer
			space.add_child(mesh)
		for index in 2:
			if (state / 4) in ([1, 3] if index == 0 else [2, 3]):
				var light := OmniLight3D.new()
				space.add_child(light)
				light.position = at + Vector3(index * 2 - 1, 1, 1)
				light.omni_range = 3
				light.shadow_enabled = index == 1
				light.light_cull_mask = layer
			if (state % 4) in ([1, 3] if index == 0 else [2, 3]):
				var light := SpotLight3D.new()
				space.add_child(light)
				light.position = at + Vector3(index * 2 - 1, 2, 1)
				light.look_at(at)
				light.spot_range = 4
				light.shadow_enabled = index == 1
				light.light_cull_mask = layer
	for index in 2: await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	for index in 2: await tree.process_frame
	return {"families": families.size(), "light_states": 16, "image_bytes": image.get_data().size(), "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}

static func _collect(mesh: Mesh, node: MeshInstance3D, seen: Dictionary, families: Array[Dictionary]) -> void:
	var surfaces: Array[Material] = []
	var key := str(mesh.get_instance_id())
	for index in mesh.get_surface_count():
		var material: Material = node.material_override
		if material == null:
			material = node.get_surface_override_material(index) if index < node.get_surface_override_material_count() else null
			if material == null: material = mesh.surface_get_material(index)
		surfaces.append(material)
		key += ":" + str(material.get_rid()) if material != null else ":null"
	if seen.has(key): return
	seen[key] = true
	families.append({"mesh": mesh, "override": node.material_override, "overlay": node.material_overlay, "surfaces": surfaces})
