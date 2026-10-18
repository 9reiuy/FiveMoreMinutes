extends SceneTree
## Actual Main Camera material parity. Geometry, AI state and uniforms stay
## identical within each original/original/cache/restored frozen comparison.
const FREEZE=preload("res://tests/support/frozen_render_comparison.gd")
const WALL=preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
var world: Node
var main: Node
var output: String="res://.runtime/perf_delivery_20261013/art_camera"
var checks:=0
var failures:=0
var saved_materials: Array=[]
var saved_floor_map: Dictionary={}
var saved_wall_map: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=").replace("\\","/")
	node_added.connect(func(node: Node) -> void:
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/dream/dream_3d_random_dungeon.gd":
			node.set_meta(&"test_approved_art_texture_cache",false); node.persist_profile=false
	)
	call_deferred("run")
func frames(count: int=5) -> void:
	for i in count: await RenderingServer.frame_post_draw
func copy_uniforms(old: ShaderMaterial,replacement: ShaderMaterial,except: Array) -> void:
	for uniform in old.shader.get_shader_uniform_list():
		if String(uniform.name) in except: continue
		var value: Variant=old.get_shader_parameter(uniform.name)
		if value!=null: replacement.set_shader_parameter(uniform.name,value)
func replace_material(node: MeshInstance3D,material: ShaderMaterial) -> void:
	saved_materials.append({"node":node,"old":node.material_override,"surface":-1})
	node.material_override=material
func apply_cached(art: Node) -> void:
	saved_floor_map=art.floors.materials.duplicate(); saved_wall_map=art.walls.wall_materials.duplicate()
	art.floors.materials.clear(); art.walls.wall_materials.clear()
	world.set_meta(&"test_approved_art_texture_cache",true)
	for room in world.rooms: art.floors.floor_material(room)
	art.floors.floor_material({})
	for record in art.floors.records:
		var mesh: ArrayMesh=record.new
		for surface in mesh.get_surface_count():
			var old: Material=mesh.surface_get_material(surface)
			for key in saved_floor_map:
				if old!=saved_floor_map[key]: continue
				var replacement: ShaderMaterial=art.floors.materials[key]
				copy_uniforms(old,replacement,["atlas","review_bevel"])
				saved_materials.append({"mesh":mesh,"old":old,"surface":surface})
				mesh.surface_set_material(surface,replacement)
	for record in art.walls.walls:
		var wall: Node=record.node.get_ref()
		if not is_instance_valid(wall): continue
		var cells: Array=world._edge_side_cells(wall.get_meta(&"edge"))
		var front: ShaderMaterial=art.walls._wall_material(world.room_cells.get(cells[1],-1),wall)
		var back: ShaderMaterial=art.walls._wall_material(world.room_cells.get(cells[0],-1),wall)
		copy_uniforms(wall.wall_material_front,front,["atlas"])
		copy_uniforms(wall.wall_material_back,back,["atlas"])
		saved_materials.append({"wall":wall,"front":wall.wall_material_front,"back":wall.wall_material_back,"surface":-2})
		wall.set_wall_materials(front,back)
	for record in art.walls.doors:
		for leaf in record.leaves:
			var visual: MeshInstance3D=leaf.node.get_ref()
			if not is_instance_valid(visual): continue
			var old: ShaderMaterial=visual.material_override
			var replacement:=ShaderMaterial.new(); replacement.shader=WALL._door_shader(true)
			replacement.set_shader_parameter("review_door_size",leaf.size)
			replacement.set_shader_parameter("atlas",WALL._door_texture(leaf.size,record.style,leaf.index,true))
			copy_uniforms(old,replacement,["atlas"]); replace_material(visual,replacement)
			if is_instance_valid(leaf.glass):
				var glass: MeshInstance3D=leaf.glass
				var mat: ShaderMaterial=WALL._glass_material(glass.mesh.size,true)
				copy_uniforms(glass.material_override,mat,["glass_pixels"]); replace_material(glass,mat)
	for record in art.walls.windows:
		var pane: MeshInstance3D=record.pane.get_ref()
		if not is_instance_valid(pane): continue
		var mat: ShaderMaterial=WALL._glass_material(pane.mesh.size,true,false)
		# The cache path still generates the authored continuous window image.
		copy_uniforms(pane.material_override,mat,[]); replace_material(pane,mat)
func restore_materials(art: Node) -> void:
	for record in saved_materials:
		if record.surface>=0: record.mesh.surface_set_material(record.surface,record.old)
		elif record.surface==-2: record.wall.set_wall_materials(record.front,record.back)
		else: record.node.material_override=record.old
	saved_materials.clear()
	art.floors.materials=saved_floor_map; art.walls.wall_materials=saved_wall_map
	world.set_meta(&"test_approved_art_texture_cache",false)
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Actual Main Camera required"); quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60
	root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main entry completed")
	if not is_instance_valid(world): quit(1); return
	world.player.invulnerability_left=3600.0
	var art: Node=world.office_art_root.get_child(0)
	var points: Array[Vector2]=[world.player.global_position]
	for door in world.door_root.get_children():
		if points.size()>=3: break
		var position: Vector2=Vector2(door.position.x,door.position.z)*32.0+Vector2(0,64)
		if world._content_position_is_clear(position,12.0): points.append(position)
	check(points.size()>=2,"Camera coverage includes a natural door view")
	var reports: Array=[]
	for index in points.size():
		world.player.global_position=points[index]; await frames(20)
		var state: Dictionary=FREEZE.freeze(self)
		await frames(); var original: Image=root.get_texture().get_image()
		await frames(); var control: Image=root.get_texture().get_image()
		apply_cached(art); await frames(); var candidate: Image=root.get_texture().get_image()
		restore_materials(art); await frames(); var restored: Image=root.get_texture().get_image()
		var aa: Dictionary=FREEZE.difference(original,control)
		var ab: Dictionary=FREEZE.difference(control,candidate)
		var ar: Dictionary=FREEZE.difference(control,restored)
		var valid: bool=aa.exact and ar.exact
		var paths: Dictionary=FREEZE.save({"original":original,"control":control,"cached":candidate,"restored":restored},output.path_join("view_%d" % index))
		FREEZE.restore(self,state)
		check(valid,"Frozen original controls and restoration are exact")
		check(valid and ab.exact,"Cached actual Camera pixels match original")
		reports.append({"view":index,"point":str(points[index]),"comparison_valid":valid,"control":aa,"candidate":ab,"restoration":ar,"images":paths})
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"views":reports,"scope":"Actual Main Camera, same frozen geometry and game state; texture and Shader cache parity, not FPS"},"\t")); file.close()
	main.queue_free(); await process_frame
	print("APPROVED_ART_CAMERA_CACHE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
