extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	Furniture3DDebris.shader_variant_anchors.clear()
	PhysicalDoor3D.shard_shader_anchors.clear()
	var retained_glass: Material
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color(.3,.4,.5))
	var texture:=ImageTexture.create_from_image(image)
	for floor_index in 3:
		var floor_root:=Node3D.new(); root.add_child(floor_root)
		var collision_root:=Node2D.new(); root.add_child(collision_root)
		var window:=BreakableGlassWindow3D.new(); floor_root.add_child(window)
		window.configure_window({"axis":"H","x":10,"y":10},"10_10_H",2.6,0.125,collision_root)
		window.take_damage(1.0,Vector2.RIGHT)
		check(window.is_shattered and not window.glass_pane.visible,"Glass damage and hiding unchanged")
		var shards: Node=window.get_node("GlassShards")
		check(shards.get_child_count()==8,"Eight independent original glass shards")
		for shard in shards.get_children():
			check(shard.material_override==shards.get_child(0).material_override and shard.material_override.albedo_color==Color(.4,.8,1.0,.6) and shard.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Original per-burst glass material and no shard shadows")
		if floor_index==0: retained_glass=BreakableGlassWindow3D.shard_material
		else: check(retained_glass==BreakableGlassWindow3D.shard_material,"Glass material reused across floors")
		await process_frame
		check(window.collision_body_2d.collision_layer==0 and window.collision_shape_2d.disabled,"Shattered window still releases actual collision")
		for textured in [false,true]:
			var first:=Furniture3DDebris.new(); floor_root.add_child(first)
			first._setup(texture if textured else null,6,Vector3.RIGHT)
			first._process(1.4)
			var second:=Furniture3DDebris.new(); floor_root.add_child(second)
			second._setup(texture if textured else null,6,Vector3.RIGHT)
			check(first.material_override!=second.material_override,"Overlapping furniture fade is isolated")
			check(is_equal_approx(first.material_override.albedo_color.a,0.5) and second.material_override.albedo_color.a==1.0,"Faded first burst does not fade new burst")
			check(second.pieces.size()==6 and second.material_override.albedo_texture==(texture if textured else null),"Furniture quantity and texture preserved")
		check(Furniture3DDebris.shader_variant_anchors.size()==2,"Only two retained furniture variants")
		for metal in [false,true]:
			var door:=PhysicalDoor3D.new()
			door.set_meta(&"office_metal_door",metal)
			floor_root.add_child(door)
			door._spawn_wood_shards(Vector2.RIGHT)
			var fragments: Node3D=door.get_node("DoorShards")
			check(fragments.get_child_count()==10,"Door preserves ten fragments")
			check(fragments.get_child(0).material_override.albedo_color==(Color(.42,.49,.52) if metal else Color(.35,.22,.12,1)),"Door original fragment colors preserved")
		check(PhysicalDoor3D.shard_shader_anchors.size()==2,"Only two door material resources retained")
		floor_root.queue_free(); collision_root.queue_free()
		for index in 4: await process_frame
		check(not is_instance_valid(floor_root) and not is_instance_valid(shards),"No previous floor or shards retained by material anchors")
	Furniture3DDebris.shader_variant_anchors.clear()
	PhysicalDoor3D.shard_shader_anchors.clear()
	print("DESTRUCTION_MATERIAL_LIFETIME_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
