extends SceneTree
const OUT="res://.runtime/visual_overhaul_20261029/lighting"
const STAGING=preload("res://scripts/story/chapter_room_staging.gd")
var main: Node
var checks:=0
var failures:=0
var metrics: Array=[]
func _initialize() -> void: call_deferred("run")
func frames(n: int=8) -> void:
	for i in n: await process_frame
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
	print("PASS " if value else "FAIL ",message)
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(20)
func capture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var result: Image=root.get_texture().get_image(); result.save_png(OUT+"/"+name+".png"); return result
func floor_measure(world: Node,label: String,room: Dictionary) -> void:
	# Paired depth-tested ID pass identifies visible floor only. It does not
	# change the captured colour image, lights, textures, gameplay or palette.
	paused=true; await frames(3)
	var original: Image=await capture(label)
	var display: Node=get_first_node_in_group("dream_display")
	var palette: bool=display.palette_enabled
	display.palette_material.set_shader_parameter("palette_enabled",false)
	display.palette_material.set_shader_parameter("tonal_sample",false)
	var marker:=ShaderMaterial.new(); var marker_shader:=Shader.new()
	marker_shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform vec2 room_center; varying vec3 world; void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;} void fragment(){ vec2 d=abs(world.xz-room_center); ALBEDO=(d.x<=1.25 && d.y<=1.25)?vec3(1.,0.,1.):vec3(0.); }"
	marker.shader=marker_shader; marker.set_shader_parameter("room_center",Vector2(room.center_cell))
	var replaced: Array=[]
	for mesh in world.floor_root.get_children():
		if mesh is MeshInstance3D and str(mesh.name).begins_with("FloorBatch"):
			replaced.append([mesh,mesh.material_override]); mesh.material_override=marker
	await frames(3)
	var mask: Image=await capture(label+"_floor_mask")
	for entry in replaced: entry[0].material_override=entry[1]
	display.palette_material.set_shader_parameter("palette_enabled",palette); display.palette_material.set_shader_parameter("tonal_sample",true)
	var maximum:=0.; var count:=0; var hotspots:=0
	for y in range(2,original.get_height()-2):
		for x in range(2,original.get_width()-2):
			var id: Color=mask.get_pixel(x,y)
			if id.r<.65 or id.b<.65 or id.g>.15: continue
			# Erode one pixel to avoid mixed raster edges and UI boundaries.
			var valid:=true
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var neighbor: Color=mask.get_pixel(x+delta.x,y+delta.y)
				if neighbor.r<.65 or neighbor.b<.65 or neighbor.g>.15: valid=false
			if not valid: continue
			var pixel: Color=original.get_pixel(x,y); var mean: float=(pixel.r+pixel.g+pixel.b)/3.
			maximum=maxf(maximum,mean); count+=1
			if mean>.68: hotspots+=1
	metrics.append({"view":label,"floor_pixels":count,"max_channel_mean":maximum,"pixels_above_068":hotspots})
	# A center covered by a conference table/fixture has no visible floor
	# receiver. Record that obstruction rather than misreporting brightness.
	if count>0: check(maximum<=.68001,label+" visible center floor <= 0.68; max="+str(maximum)+" n="+str(count))
	else: print("OCCLUDED ",label," center has no visible floor pixels")
	paused=false; await frames(2)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(600,true,false,true).timeout.connect(func(): quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.state.stage="ASCENT"; main.chapter_one.state.floor=2
	main._show_dream("basic"); await settle()
	var world: Node=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	await frames(30)
	world.player.set_meta("presentation_pointer_position",func(): return world.camera_3d.unproject_position(world.to_global(Vector3(world.player.position.x/32.,0,world.player.position.y/32.))))
	for type in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=type
		check(world.regenerate(42001),type+" formal generation")
		await frames(30)
		var adapter: Node=world.get_node("ChapterOneRun")
		check(not adapter.maintenance_site.is_empty() and is_instance_valid(adapter.terminal_collision),type+" has legal wall-mounted bay")
		check(world.last_validation_report.get("valid",false),type+" topology validation")
		if adapter.maintenance_site.is_empty(): continue
		var cabinets: Array=adapter.terminal_collision.get_children()
		for i in cabinets.size():
			for j in range(i+1,cabinets.size()):
				var a: Rect2=cabinets[i].shape.get_rect(); a.position+=cabinets[i].position
				var b: Rect2=cabinets[j].shape.get_rect(); b.position+=cabinets[j].position
				check(not a.intersects(b),type+" workbench solids do not overlap")
		for prop in world.furniture_root.get_children():
			if prop is Node2D: check(not STAGING.footprint(prop).intersects(adapter.maintenance_site.bounds),type+" reserved bay remains clear of generated furniture")
		for item in adapter.cameras.get_children():
			if not item.has_meta("wall_site"): continue
			var site: Dictionary=item.get_meta("wall_site")
			check(not world.door_opening_edges.has(site.key) and not world.window_wall_edges.has(site.key),type+" camera anchored to solid wall")
		for room in world.rooms:
			world.player.global_position=Vector2(room.center_cell)*32.; world.activate_room(int(room.id)); await frames(20)
			for scheme in [1,2]:
				root.get_node("SettingsManager").set_palette_scheme(scheme); await frames(3)
				await floor_measure(world,"%s_room%d_palette%d"%[type,int(room.id),scheme],room)
	var result: Dictionary={"checks":checks,"failures":failures,"metrics":metrics}
	FileAccess.open(OUT+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("VISUAL_OVERHAUL checks=",checks," failures=",failures)
	main.queue_free(); await frames(); quit(failures)
