extends SceneTree
const OUT := "res://.runtime/surface_blood_20261114/promotion/alignment"
var sample: Control
var bridge: Node3D
var reference: Decal
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	create_timer(90.0,true,false,true).timeout.connect(func(): quit(3))
	DirAccess.make_dir_recursive_absolute(OUT)
	sample = load("res://scenes/testing/BloodSurfacePreview.tscn").instantiate(); root.add_child(sample)
	while not sample.ready_world: await process_frame
	var clock: Node = root.get_node("DreamTimeController")
	clock.set_lifecycle_enabled(false); clock.set_process(false); Engine.time_scale = 1.0
	sample.hide_hud = true; sample._update_label(); sample.set_process(false)
	sample.world.player.set_physics_process(false)
	sample.world.clear_preview_blood()
	var start := Vector2(6,8)*32.0
	sample.world.spawn_corpse_drag_trail(start,start+Vector2(24,3),1,1.0,24.0)
	var source: BlackBloodEffect
	for node in sample.world.world_effects_root.get_children():
		if node is BlackBloodEffect: source = node
	if not is_instance_valid(source): quit(2); return
	await frames(12)
	bridge = source.get_meta(&"depth_visual_bridge").get_ref()
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for p in source.ground_pixels:
		var pixel := Vector2i(p)+Vector2i(64,64)
		if Rect2i(0,0,128,128).has_point(pixel): image.set_pixelv(pixel,Color("df741e"))
	var texture := ImageTexture.create_from_image(image)
	reference = Decal.new(); reference.name = "PrivateSameMaskSurfaceReference"
	reference.texture_albedo = texture; reference.texture_emission = texture; reference.emission_energy = .42
	reference.cull_mask = sample.blood.RECEIVER_LAYER; reference.normal_fade = .75
	reference.upper_fade = 0.0; reference.lower_fade = 0.0
	reference.size = Vector3(4,.065,4)
	sample.world.add_child(reference)
	reference.global_position = sample.world.get_gameplay_world_position(start,.008)
	var lamp := OmniLight3D.new(); sample.world.add_child(lamp)
	lamp.omni_range = 6.0; lamp.light_energy = 4.0
	lamp.light_cull_mask = 1 | (1<<19)
	lamp.global_position = sample.world.get_gameplay_world_position(Vector2(7,8)*32,2.0)
	sample.set_dark(false); sample.environment.ambient_light_energy = 0.0
	var reflection: Node = sample.world.get_node_or_null("FloorReflections")
	if reflection!=null and RenderingServer.frame_pre_draw.is_connected(reflection._before_draw): RenderingServer.frame_pre_draw.disconnect(reflection._before_draw)
	sample.world.process_mode = Node.PROCESS_MODE_DISABLED
	for light in sample.world.find_children("*","Light3D",true,false): light.hide()
	var material: ShaderMaterial = bridge.actor_sprite.material_override
	var projected: Array = []
	for offset in [Vector2(-16,-16),Vector2(48,-16),Vector2(48,24),Vector2(-16,24)]:
		projected.append(str(sample.world.camera_3d.unproject_position(sample.world.get_gameplay_world_position(start+offset,.018))))
	FileAccess.open(OUT.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify({"pixels":source.ground_pixels.size(),"projected_corners":projected,"pid":OS.get_process_id()},"\t"))
	for phase in ["off","white","blue"]:
		lamp.visible = phase!="off"; lamp.light_color = Color("509dff") if phase=="blue" else Color.WHITE
		reference.hide(); bridge.actor_sprite.hide(); await frames(4)
		save(phase+"_background")
		reference.show(); await frames(4); save(phase+"_surface")
		reference.hide(); bridge.actor_sprite.show()
		for strength in [.25,.33,.5,1.0]:
			material.set_shader_parameter("blood_direct_light_strength",strength)
			await frames(4); save(phase+"_drag_"+str(strength))
	sample.free(); await frames(10)
	print("BLOOD_ALIGNMENT_CAPTURE_COMPLETE")
	quit(0)
func save(name: String) -> void:
	sample.display.world_viewport.get_texture().get_image().save_png(OUT.path_join(name+".png"))
