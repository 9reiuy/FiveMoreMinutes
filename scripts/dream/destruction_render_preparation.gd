extends RefCounted
## Loading-only Compatibility receiver preparation. Uses a small, private
## World3D: no furniture is destroyed and no gameplay/RNG state is simulated.
## Material references are the same families used by the formal constructors.
static func run(tree: SceneTree,world: Node3D) -> Dictionary:
	if DisplayServer.get_name()=="headless": return {"skipped":"headless"}
	if not tree.paused: return {"skipped":"gameplay_not_frozen"}
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
	var token: int=world.get_current_floor_token()
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new()
	viewport.set_meta(&"destruction_render_preparation",true)
	viewport.size=Vector2i(64,64); viewport.own_world_3d=true
	viewport.positional_shadow_atlas_size=world.camera_3d.get_viewport().positional_shadow_atlas_size
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var space:=Node3D.new(); viewport.add_child(space)
	space.get_world_3d().environment=world.get_world_3d().environment
	var camera:=Camera3D.new(); space.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16.0
	camera.cull_mask=65535; camera.position=Vector3(0,12,12)
	camera.look_at(Vector3.ZERO); camera.current=true
	var key:=DirectionalLight3D.new(); space.add_child(key)
	key.rotation_degrees=Vector3(-35,45,0); key.light_cull_mask=65535
	var sun:=DirectionalLight3D.new(); space.add_child(sun)
	sun.rotation_degrees=Vector3(-50,-45,0); sun.shadow_enabled=true; sun.light_cull_mask=65535
	if is_instance_valid(world.shadow_manager) and is_instance_valid(world.shadow_manager.sun):
		sun.directional_shadow_mode=world.shadow_manager.sun.directional_shadow_mode
		sun.directional_shadow_blend_splits=world.shadow_manager.sun.directional_shadow_blend_splits
	var materials: Array[Material]=[]
	var texture_image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var texture:=ImageTexture.create_from_image(texture_image)
	for textured in [false,true]:
		var debris:=Furniture3DDebris.new()
		# Zero pieces and a private deterministic RNG; no motion or gameplay source.
		debris.set_meta(&"test_debris_seed",1)
		debris._setup(texture if textured else null,0,Vector3.ZERO)
		materials.append(debris.material_override); debris.free()
	BreakableGlassWindow3D._init_materials()
	if BreakableGlassWindow3D.shard_material==null:
		BreakableGlassWindow3D.shard_material=BreakableGlassWindow3D.glass_material.duplicate() as StandardMaterial3D
		BreakableGlassWindow3D.shard_material.albedo_color=Color(.4,.8,1.0,.6)
	materials.append(BreakableGlassWindow3D.shard_material)
	# Both material states exist in the shared 3D door factory. This loads no
	# retired 2D scene, nor a door/furniture physics node.
	for metal in [false,true]:
		if not PhysicalDoor3D.shard_shader_anchors.has(metal):
			var material:=StandardMaterial3D.new(); material.roughness=.8
			material.albedo_color=Color(.42,.49,.52) if metal else Color(.35,.22,.12,1)
			if metal: material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
			PhysicalDoor3D.shard_shader_anchors[metal]=material
		materials.append(PhysicalDoor3D.shard_shader_anchors[metal])
	var box:=BoxMesh.new(); box.size=Vector3(.5,.5,.5)
	for point_state in 4:
		for spot_state in 4:
			var index:=point_state*4+spot_state
			var layer:=1<<index
			var origin:=Vector3((index%4-1.5)*3,0,(index/4-1.5)*3)
			for material_index in materials.size():
				var piece:=MeshInstance3D.new(); piece.mesh=box
				piece.material_override=materials[material_index]; piece.layers=layer
				piece.position=origin+Vector3((material_index%3-1)*.7,0,-.7*(material_index/3))
				if material_index==2: piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				space.add_child(piece)
			for light_index in 2:
				if point_state in ([1,3] if light_index==0 else [2,3]):
					var point:=OmniLight3D.new(); space.add_child(point)
					point.position=origin+Vector3(light_index*2-1,1,1); point.omni_range=3
					point.shadow_enabled=light_index==1; point.light_cull_mask=layer
				if spot_state in ([1,3] if light_index==0 else [2,3]):
					var spot:=SpotLight3D.new(); space.add_child(spot)
					spot.position=origin+Vector3(light_index*2-1,2,1); spot.look_at(origin)
					spot.spot_range=4; spot.shadow_enabled=light_index==1; spot.light_cull_mask=layer
	var build_ms: float=(Time.get_ticks_usec()-started)/1000.0
	var draw_started:=Time.get_ticks_usec()
	for frame in 2: await RenderingServer.frame_post_draw
	var draw_wait_ms: float=(Time.get_ticks_usec()-draw_started)/1000.0
	# Complete native GPU work before deleting the private world or revealing
	# the actual level. A disabled dormant mesh alone does not prepare shaders.
	var readback_started:=Time.get_ticks_usec()
	var image:=viewport.get_texture().get_image()
	var readback_ms: float=(Time.get_ticks_usec()-readback_started)/1000.0
	var cleanup_started:=Time.get_ticks_usec()
	var reference: WeakRef=weakref(viewport)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.queue_free()
	for frame in 2: await tree.process_frame
	var cancelled:=not is_instance_valid(world) or not world.is_inside_tree()
	if not cancelled: cancelled=world.get_current_floor_token()!=token
	return {"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"build_ms":build_ms,"draw_wait_ms":draw_wait_ms,"readback_ms":readback_ms,"cleanup_ms":(Time.get_ticks_usec()-cleanup_started)/1000.0,"cancelled":cancelled,"viewport_released":reference.get_ref()==null,"private_image_bytes":image.get_data().size(),"states":16,"material_families":materials.size()}
