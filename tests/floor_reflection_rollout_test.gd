extends SceneTree
const EFFECT=preload("res://scripts/dream/floor_reflections.gd")
const WORLD=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count:int)->void:
	for i in count: await process_frame
func validate(world:Node3D)->void:
	var effect:Node=world.get_node_or_null("FloorReflections")
	check(effect!=null,"Production entry installs reflections without test intervention")
	if effect==null: return
	check(EFFECT.install(world)==effect,"Repeated install keeps one component")
	check(effect.viewport.world_3d==world.get_world_3d(),"One shared authoritative world")
	check(effect.floor_materials.size()<effect.surfaces.size(),"Repeated room surfaces share reflection material updates")
	for record in effect.surfaces:
		var mesh:MeshInstance3D=record.node.get_ref()
		var base:ShaderMaterial=mesh.mesh.surface_get_material(record.index)
		check(record.material.get_shader_parameter("atlas")==base.get_shader_parameter("atlas"),"Room retains its exact atlas resource")
		check(record.style==String(base.get_meta(&"floor_surface_style","")),"Reflection follows actual room material identity")
		check(is_equal_approx(float(record.material.get_shader_parameter("sample_surface_gloss")),EFFECT.profile(record.style).z),"Room uses its approved gloss profile")
func run()->void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	var world:=WORLD.instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world)
	var previous:WeakRef
	for skeleton in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=skeleton
		check(world.regenerate(42001),"Generated production skeleton "+skeleton)
		await frames(4)
		check(previous==null or previous.get_ref()==null,"Previous floor reflection viewport released")
		validate(world)
		var effect:Node=world.get_node("FloorReflections")
		previous=weakref(effect.viewport)
		var lamp:=OmniLight3D.new(); lamp.light_cull_mask=7; world.add_child(lamp)
		await frames(3)
		print("REFLECTION_LIFECYCLE ",skeleton," pending=",effect.pending.size()," processing=",effect.can_process()," restored=",effect.restored," signal=",node_added.is_connected(effect._on_node_added)," paused=",paused," lamp=",lamp.light_cull_mask)
		check(lamp.light_cull_mask&EFFECT.EXCLUDED!=0,"Runtime lamp illuminates reflective receivers "+skeleton)
		var enemy:Node=world._spawn_regular_employee(world.spawn_room_id,world.player.global_position+Vector2(12,0),&"employee",false,"basic")
		await frames(8)
		check(effect.actor_bindings.any(func(r:Dictionary)->bool:
			var sprite:Node=r.node.get_ref()
			return is_instance_valid(sprite) and sprite.get_parent().get("source_actor")==enemy),"Runtime enemy joins reflection without whole-floor scan "+skeleton)
		var wall_mat:ShaderMaterial
		for mesh in world.wall_root.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is ShaderMaterial and mesh.material_override.shader.code.contains("sample_capture_pass"):
				wall_mat=mesh.material_override; break
		check(wall_mat!=null,"Live wall material has reflected clipping "+skeleton)
		if wall_mat!=null:
			check(world.get_node("OfficeDitherLighting")._material(wall_mat)==wall_mat,"Lighting refresh preserves authoritative wall material")
		lamp.queue_free()
	# Exercise the same stash/rollback transaction as the formal elevator.
	var old_atlas:Texture2D=world.get_node("FloorReflections").surfaces[0].material.get_shader_parameter("atlas")
	world.transition_generation_token+=1
	var token:int=world.transition_generation_token
	world._stash_current_floor_for_rollback(); await frames(2)
	check(previous.get_ref()==null and world.get_node_or_null("FloorReflections")==null,"Stash releases viewport and restores old floor resources")
	world._rollback_failed_transition(token,world.floor_index); await frames(4)
	validate(world)
	check(world.get_node("FloorReflections").surfaces[0].material.get_shader_parameter("atlas")==old_atlas,"Rollback keeps exact previous texture")
	world.free(); await frames(3)
	var hall:=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	root.add_child(hall); await frames(5)
	validate(hall)
	check(hall.get_node("FloorReflections").surfaces.all(func(r:Dictionary)->bool:return r.style=="reception"),"Tarot hall uses the same marble profile as floor reception")
	check(preload("res://scripts/dream/office_pixel_materials.gd").materials.values().all(func(m:ShaderMaterial)->bool:return not m.shader.code.contains("sample_capture_pass")),"Hall never modifies process-wide shared swatches")
	check(not preload("res://scripts/dream/office_room_low_pixel_art.gd").material().shader.code.contains("sample_capture_pass"),"Hall never modifies the shared furniture atlas shader")
	var hall_view:WeakRef=weakref(hall.get_node("FloorReflections").viewport)
	hall.free(); await frames(3)
	check(hall_view.get_ref()==null,"Leaving hall releases reflection viewport")
	print("FLOOR_REFLECTION_ROLLOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
