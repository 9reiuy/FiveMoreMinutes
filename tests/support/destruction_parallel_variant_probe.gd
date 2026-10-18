extends RefCounted
## Test-only: prepare all 16 light feature combinations in one private view.
static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new(); viewport.size=Vector2i(64,64); viewport.own_world_3d=true
	viewport.set_meta(&"test_destruction_warm_viewport",true)
	viewport.positional_shadow_atlas_size=world.get_viewport().positional_shadow_atlas_size
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; tree.root.add_child(viewport)
	var scene:=Node3D.new(); viewport.add_child(scene)
	scene.get_world_3d().environment=world.get_world_3d().environment
	var camera:=Camera3D.new(); scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16.0
	camera.cull_mask=65535; camera.position=Vector3(0,12,12); camera.look_at(Vector3.ZERO); camera.current=true
	var key:=DirectionalLight3D.new(); scene.add_child(key); key.rotation_degrees=Vector3(-35,45,0); key.light_cull_mask=65535
	var sun:=DirectionalLight3D.new(); scene.add_child(sun); sun.rotation_degrees=Vector3(-50,-45,0); sun.shadow_enabled=true; sun.light_cull_mask=65535
	if is_instance_valid(world.shadow_manager) and is_instance_valid(world.shadow_manager.sun):
		sun.directional_shadow_mode=world.shadow_manager.sun.directional_shadow_mode
		sun.directional_shadow_blend_splits=world.shadow_manager.sun.directional_shadow_blend_splits
	var debris:=Furniture3DDebris.new(); debris.set_meta(&"test_debris_seed",1); debris._setup(null,0,Vector3.ZERO)
	var material: Material=debris.material_override; debris.free()
	var materials: Array[Material]=[material]
	var families: Array[String]=["furniture_untextured"]
	if "--all-destruction-families" in OS.get_cmdline_user_args():
		var texture_image:=Image.create(4,4,false,Image.FORMAT_RGBA8); texture_image.fill(Color.WHITE)
		var textured:=Furniture3DDebris.new(); textured.set_meta(&"test_debris_seed",1)
		textured._setup(ImageTexture.create_from_image(texture_image),0,Vector3.ZERO)
		materials.append(textured.material_override); families.append("furniture_textured"); textured.free()
		BreakableGlassWindow3D._init_materials()
		if BreakableGlassWindow3D.shard_material==null:
			BreakableGlassWindow3D.shard_material=BreakableGlassWindow3D.glass_material.duplicate() as StandardMaterial3D
			BreakableGlassWindow3D.shard_material.albedo_color=Color(.4,.8,1.0,.6)
		materials.append(BreakableGlassWindow3D.shard_material); families.append("glass")
		for metal in [false,true]:
			var door_material:=StandardMaterial3D.new(); door_material.roughness=.8
			door_material.albedo_color=Color(.42,.49,.52) if metal else Color(.35,.22,.12,1)
			if metal: door_material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
			if not PhysicalDoor3D.shard_shader_anchors.has(metal): PhysicalDoor3D.shard_shader_anchors[metal]=door_material
			materials.append(door_material); families.append("door_metal" if metal else "door_wood")
	for point_state in 4:
		for spot_state in 4:
			var index:=point_state*4+spot_state
			var layer:=1<<index
			var origin:=Vector3((index%4-1.5)*3,0,(index/4-1.5)*3)
			var piece:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.5,.5,.5)
			piece.mesh=box; piece.material_override=material; piece.layers=layer; piece.position=origin; scene.add_child(piece)
			for material_index in range(1,materials.size()):
				var other:=MeshInstance3D.new(); other.mesh=box; other.material_override=materials[material_index]; other.layers=layer
				other.position=origin+Vector3((material_index%3-1)*.7,0,-.7*(1+material_index/3)); scene.add_child(other)
				if families[material_index]=="glass": other.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if "--airborne-variant" in OS.get_cmdline_user_args():
				# Exact production MultiMesh factory, no blood source or simulation.
				var blood:=BloodAirborneCarrier3D.new(); scene.add_child(blood)
				blood.pixels_per_world_cell=32.0; blood._create_multimesh(); blood.set_process(false)
				blood.multi_mesh.instance_count=8; blood.multi_mesh.visible_instance_count=8
				blood.multi_instance.layers=layer; blood.multi_instance.visible=true
				for particle_index in 8:
					blood.multi_mesh.set_instance_transform(particle_index,Transform3D(camera.global_basis.scaled(Vector3.ONE*8),origin+Vector3((particle_index%4-1.5)*.2,.4+particle_index/4*.3,.8)))
			var caster:=MeshInstance3D.new(); caster.mesh=box; caster.layers=layer; caster.position=origin+Vector3(.3,.6,0); scene.add_child(caster)
			for light_index in 2:
				if point_state in ([1,3] if light_index==0 else [2,3]):
					var point:=OmniLight3D.new(); scene.add_child(point)
					point.position=origin+Vector3(light_index*2-1,1,1); point.omni_range=3
					point.shadow_enabled=light_index==1; point.light_cull_mask=layer
				if spot_state in ([1,3] if light_index==0 else [2,3]):
					var spot:=SpotLight3D.new(); scene.add_child(spot)
					spot.position=origin+Vector3(light_index*2-1,2,1); spot.look_at(origin); spot.spot_range=4
					spot.shadow_enabled=light_index==1; spot.light_cull_mask=layer
	for frame in 2: await RenderingServer.frame_post_draw
	# Wait for this tiny private target's GPU work, not four more full-floor
	# process/render frames. Deferred node cleanup is verified by the caller.
	var image:=viewport.get_texture().get_image()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.queue_free()
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"viewport_released":false,"release_scheduled":viewport.is_queued_for_deletion(),"release_ref":weakref(viewport),"image_bytes":image.get_data().size(),"states":16,"parallel_variants":true,"families":families}
