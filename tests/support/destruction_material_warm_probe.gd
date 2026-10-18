extends RefCounted
## Test-only isolated renderer probe. No production entry point calls this.
static func run(tree: SceneTree, texture: Texture2D, shadows := false, light_variants := false, environment: Environment=null) -> Dictionary:
	var started:=Time.get_ticks_usec()
	BreakableGlassWindow3D._init_materials()
	if BreakableGlassWindow3D.shard_material==null:
		BreakableGlassWindow3D.shard_material=BreakableGlassWindow3D.glass_material.duplicate() as StandardMaterial3D
		BreakableGlassWindow3D.shard_material.albedo_color=Color(.4,.8,1.0,.6)
	var materials: Array[Material]=[BreakableGlassWindow3D.shard_material]
	for textured in [false,true]:
		if not Furniture3DDebris.shader_variant_anchors.has(textured):
			# Same immutable feature flags as the production burst material.
			# No dummy particle spawn or RNG call is needed to prepare a material.
			var material:=StandardMaterial3D.new()
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.roughness=0.9
			if textured: material.albedo_texture=texture
			Furniture3DDebris.shader_variant_anchors[textured]=material
		materials.append(Furniture3DDebris.shader_variant_anchors[textured])
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(16,16); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var space:=Node3D.new(); viewport.add_child(space)
	if environment!=null: space.get_world_3d().environment=environment
	viewport.positional_shadow_atlas_size=2048
	var camera:=Camera3D.new(); space.add_child(camera)
	camera.position=Vector3(0,1,5); camera.look_at(Vector3.ZERO); camera.current=true
	var sun:=DirectionalLight3D.new(); space.add_child(sun)
	sun.rotation_degrees=Vector3(-35,45,0); sun.shadow_enabled=shadows
	var point:=OmniLight3D.new(); space.add_child(point)
	point.position=Vector3(2,2,2); point.shadow_enabled=shadows
	var spot:=SpotLight3D.new(); space.add_child(spot)
	spot.position=Vector3(-2,2,3); spot.look_at(Vector3.ZERO); spot.shadow_enabled=shadows
	for index in materials.size():
		var mesh:=MeshInstance3D.new(); mesh.mesh=BoxMesh.new(); mesh.material_override=materials[index]
		mesh.position=Vector3(index-1,0,0)
		if index==0: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		space.add_child(mesh)
	if light_variants:
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
		for directional in 3:
			for omni in 3:
				for spotlight in 3:
					sun.visible=directional!=0; sun.shadow_enabled=directional==2
					point.visible=omni!=0; point.shadow_enabled=omni==2
					spot.visible=spotlight!=0; spot.shadow_enabled=spotlight==2
					for index in 2: await RenderingServer.frame_post_draw
	else:
		for index in 4: await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	for index in 4: await tree.process_frame
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"viewport_released":not is_instance_valid(viewport),"shadow_probe":shadows,"light_variants":light_variants}
