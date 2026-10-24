extends SceneTree
const VOID=preload("res://scripts/dream/interior_void_geometry.gd")
const OUT="res://.runtime/interior_void_20261022"
var checks:=0
var failures:=0
var main: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int=6) -> void:
	for i in count: await process_frame
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func shot(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func pixel(camera: Camera3D,point: Vector3) -> Color:
	var image:=camera.get_viewport().get_texture().get_image()
	var p:=Vector2i(camera.unproject_position(point))
	p=Vector2i(Vector2(p)*Vector2(image.get_size())/camera.get_viewport().get_visible_rect().size)
	p=p.clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
	return image.get_pixelv(p)
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	await settle()
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state.tutorial_completed=true
	seed(120); main._show_dream("basic"); await settle()
	var world: Node=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	world.player.dash_invulnerability_left=3600
	check(world.room_visibility.outside_mask_layer==null,"Real Main entry creates no screen black mask")
	await shot("formal_native")
	for combination in [[true,false],[false,true],[true,true]]:
		settings.set_setting(&"pixelation_enabled",combination[0]); settings.set_palette_enabled(combination[1])
		await shot("formal_pixel_%s_palette_%s" % [combination[0],combination[1]])
		check(world.room_visibility.outside_mask_layer==null,"Filter combination does not recreate a mask")
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	await frames()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	# Controlled visual fixture, rendered by the real game's Camera3D and display bridge.
	# Far from gameplay geometry; it changes no floor/collision data.
	var fixture:=Node3D.new(); fixture.position=Vector3(1000,0,1000); world.add_child(fixture)
	var cells: Dictionary={}
	for y in 9:
		for x in 9:
			if x<2 or x>6 or y<2 or y>6: cells[Vector2i(x,y)]=true
	var backing:=VOID.build(cells,Rect2i(0,0,9,9)); fixture.add_child(backing)
	var surround:=MeshInstance3D.new()
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in cells:
		VOID.quad(surface,Vector3(cell.x-.5,0,cell.y-.5),Vector3(cell.x+.5,0,cell.y-.5),Vector3(cell.x+.5,0,cell.y+.5),Vector3(cell.x-.5,0,cell.y+.5))
	surround.mesh=surface.commit()
	var gray:=StandardMaterial3D.new(); gray.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; gray.albedo_color=Color(.4,.4,.4); gray.cull_mode=BaseMaterial3D.CULL_DISABLED
	surround.material_override=gray; fixture.add_child(surround)
	var background:=MeshInstance3D.new(); background.mesh=PlaneMesh.new(); background.mesh.size=Vector2(30,30); background.position=Vector3(4,-1,4)
	var blue:=StandardMaterial3D.new(); blue.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; blue.albedo_color=Color.BLUE
	background.material_override=blue; fixture.add_child(background)
	var marker:=MeshInstance3D.new(); marker.mesh=BoxMesh.new(); marker.mesh.size=Vector3(.6,2,.6)
	marker.position=Vector3(5,1,4)
	var red:=StandardMaterial3D.new(); red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; red.albedo_color=Color.RED
	marker.material_override=red; fixture.add_child(marker)
	var camera: Camera3D=world.camera_3d
	for index in 3:
		camera.global_position=fixture.to_global(Vector3(4+index*.3,11,14))
		camera.look_at(fixture.to_global(Vector3(4,0,4)),world.global_basis.y.normalized())
		world.room_visibility._update_outside_mask()
		await frames(); await RenderingServer.frame_post_draw
		var black:=pixel(camera,fixture.to_global(Vector3(3,VOID.DEPTH,4)))
		var visible:=pixel(camera,fixture.to_global(Vector3(5,1.5,4)))
		check(maxf(black.r,maxf(black.g,black.b))<.025,"Moving real camera keeps courtyard black")
		check(visible.r>.7 and visible.r>visible.g*4,"Foreground geometry is depth-tested, not painted black")
		var outside:=pixel(camera,fixture.to_global(Vector3(-1,-1,4)))
		check(outside.b>.7 and outside.r<.2,"Exterior is not filled by internal void backing")
		var floor_color:=pixel(camera,fixture.to_global(Vector3(0,0,4)))
		check(floor_color.r>.2 and absf(floor_color.r-floor_color.b)<.05,"Adjacent floor remains visible")
		backing.hide(); await frames(); await RenderingServer.frame_post_draw
		var uncovered:=pixel(camera,fixture.to_global(Vector3(3,-1,4)))
		check(uncovered.b>.7 and uncovered.r<.2,"Black courtyard comes from actual backing, not clear color")
		backing.show()
		await shot("depth_fixture_%d" % index)
	fixture.free(); main.free(); await frames()
	var sample: Node=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	sample.generate_on_ready=false; sample.spawn_content=false; sample.persist_profile=false
	var display: Node=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=sample; display.preview_mode=false; root.add_child(display)
	check(sample.regenerate(120),"Approved sample renders through its normal Camera3D")
	for room: Dictionary in sample.rooms:
		if String(room.get("sample_key",""))=="office":
			sample.player.global_position=Vector2(room.center_cell)*sample.CELL_PIXELS
			sample.activate_room(int(room.id))
			break
	sample._update_camera_and_actor_projection(0.0)
	await frames(40)
	check(sample.room_visibility.outside_black_gradient==null,"Rendered sample has no screen overlay")
	await shot("approved_sample")
	display.free()
	print("INTERIOR_VOID_GPU checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
