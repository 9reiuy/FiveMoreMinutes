extends SceneTree
const SAMPLE=preload("res://scripts/dream/floor_reflection_sample.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var world:=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	world.set_meta(&"test_floor_reflections_disabled",true)
	root.add_child(world); check(world.regenerate(42001),"Actual formal world generated")
	for i in 3: await process_frame
	world.player.set_physics_process(false)
	check(SAMPLE.profile("reception").x>SAMPLE.profile("restroom").x and SAMPLE.profile("restroom").x>SAMPLE.profile("corridor").x,"Polished material reflection ordering")
	check(SAMPLE.profile("corridor").x>SAMPLE.profile("conference").x and SAMPLE.profile("conference").x>SAMPLE.profile("office").x,"Stone, wood and carpet reflection ordering")
	check(SAMPLE.profile("office").x==0 and SAMPLE.profile("office").z==0,"Carpet keeps diffuse-only response")
	var rng:int=world._content_rng.state
	var camera_mask:int=world.camera_3d.cull_mask
	var layer_records:Array=[]
	for node in world.floor_root.get_children():
		if node is MeshInstance3D: layer_records.append([node,node.layers])
	var sample:=SAMPLE.new(); world.add_child(sample); sample.configure(world)
	print("SAMPLE_BINDINGS ",sample.surfaces.size()," ",sample.actor_materials.size()," floor children=",world.floor_root.get_child_count()," actor children=",world.actor_depth_bridges_root.get_child_count())
	check(sample.surfaces.size()>0 and sample.actor_materials.size()>0,"Live formal surfaces and character materials adapted")
	check(sample.viewport.world_3d==world.get_world_3d() and sample.viewport.get_child_count()==1,"One shared-world camera, no cloned actors")
	check(sample.camera.cull_mask&SAMPLE.EXCLUDED==0 and world.camera_3d.cull_mask&SAMPLE.EXCLUDED!=0,"Reflection excludes receiver without hiding it from main Camera")
	check(sample.viewport.positional_shadow_atlas_size==0,"No second positional shadow atlas")
	check(sample.surfaces.all(func(r:Dictionary)->bool:return r.material.get_shader_parameter("atlas")!=null),"Original approved textures retained")
	var bridge:Node=world.player_depth_bridge
	var material:ShaderMaterial=bridge.lit_material
	check(bridge.actor_sprite.material_override==material,"Bridge keeps same live material for moving depth uniforms")
	world.player.global_position+=Vector2(8,0); bridge._process(0)
	check(material.get_shader_parameter("reference_plane_origin").is_equal_approx(bridge.body_reference_origin),"Moving body reference plane still updates the actual rendered material")
	sample.set_preview_style("restroom")
	check(sample.surfaces.any(func(r:Dictionary)->bool:return is_equal_approx(float(r.material.get_shader_parameter("sample_reflection_strength")),.23)),"Controlled style binds its exact material profile")
	check(world._content_rng.state==rng,"Installation and material switching leave gameplay RNG untouched")
	sample.set_enabled(false)
	check(sample.surfaces.all(func(r:Dictionary)->bool:return r.material.get_shader_parameter("sample_surface_enabled")==false),"Disable gates all floor reflection and gloss")
	var reference:WeakRef=weakref(sample.viewport)
	world.floor_transition_in_progress=true
	for i in 4: await process_frame
	check(reference.get_ref()==null,"Transition tears down sample rendering viewport")
	check(world.camera_3d.cull_mask==camera_mask,"Transition restores original main camera mask")
	check(layer_records.all(func(r:Array)->bool:return r[0].layers==r[1]),"Transition restores original floor render layers")
	check(material.shader.resource_path=="res://shaders/dream3d/lit_pixel_carrier.gdshader" or not material.shader.code.contains("sample_capture_pass"),"Transition restores character shader")
	world.floor_transition_in_progress=false; world.free()
	print("FLOOR_REFLECTION_SAMPLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
