extends SceneTree
const PROTOTYPE=preload("res://scripts/dream/elevator_freight_facade.gd")
var output: String="res://.runtime/freight_delivery_20261015/animation"
var samples: Array[Dictionary]=[]
var clock:=0.0
var recording:=false
var checks:=0
var failures:=0
var main: Node
var room: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
		if recording:
			clock+=1.0/60.0
			if Engine.get_process_frames()%4==0:
				var file: String="frame_%03d.png"%samples.size()
				root.get_texture().get_image().save_png(output+"/"+file)
				samples.append({"file":file,"game_seconds":clock})
func capture(label: String) -> void:
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func luminance(image: Image) -> float:
	var total:=0.0
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			total+=color.r*.2126+color.g*.7152+color.b*.0722
	return total/float(image.get_width()*image.get_height())
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	await frames(3)
	main.persistent_day_state=main._create_initial_state(); main._show_reception("basic")
	for i in 600:
		await frames(1)
		if main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running:
			room=main._supported_dream_world; break
	check(room!=null,"Actual Main reception loaded")
	if room==null: quit(1); return
	var pointer:=InputEventMouseMotion.new(); pointer.position=Vector2(960,540)
	pointer.global_position=pointer.position; Input.parse_input_event(pointer)
	room.player.global_position=room.ELEVATOR_POS_2D+Vector2(0,120)
	await frames(30); room.set_process(false)
	room.interaction_prompt.hide()
	room.camera_rig.global_position=room.elevator_floor_door.global_position+Vector3(0,0,3.5)
	await frames(4)
	capture("before")
	var door: Node3D=room.elevator_floor_door
	var width: float=door.opening_width
	var collider_width: float=door.door_shape_2d.shape.size.x
	var facade: Node3D=door.industrial_facade
	for label in room.find_children("*","Label3D",true,false):
		if label.text=="01  READY": label.hide()
	check(is_equal_approx(door.opening_width,width),"Prototype retains original opening width")
	check(is_equal_approx(door.door_shape_2d.shape.size.x,collider_width),"Prototype retains original collision footprint")
	check(facade.get_node("FreightStructuralFrame")!=null,"Thick frame and drive housing built")
	check(door.left_door_mesh.get_child_count()>0,"Details follow the original animated leaf")
	await frames(20); capture("closed")
	check(is_zero_approx(facade.spill_light.light_energy),"Closed door emits no interior spill light")
	recording=true
	await frames(45)
	door.open_doors(.65)
	await frames(55); capture("open")
	var lit_open_image: Image=root.get_texture().get_image()
	check(door.doors_open,"Original door animation opens decorated prototype")
	check(facade.opening_fraction>.95 and facade.spill_light.light_energy>1,"Fully open doorway enables warm internal spill")
	check(door.door_collider_2d.collision_layer==0,"Open prototype retains original passage collision state")
	await frames(45)
	door.close_doors(.65)
	await frames(55); capture("closed_after")
	check(not door.doors_open,"Original door animation closes decorated prototype")
	check(is_zero_approx(facade.spill_light.light_energy) and is_zero_approx(facade.interior_light.light_energy),"Closed animation extinguishes interior spill without a lingering leak")
	check(door.door_collider_2d.collision_layer==door.WORLD_WALL_LAYER,"Closed prototype restores original door collision state")
	recording=false
	# Prove the mask in real GPU pixels, with spill and the inner scene hidden
	# so illumination changes cannot masquerade as exposed moving steel.
	facade.set_process(false); facade.interior_light.light_energy=0; facade.spill_light.light_energy=0
	facade.get_node("FreightLitRecess").hide(); facade.get_node("FreightInteriorLamp").hide()
	await frames(4)
	var mask_before: Image=root.get_texture().get_image()
	var regions: Array[Rect2i]=[]
	var scale: Vector2=Vector2(root.size)/room.camera_3d.get_viewport().get_visible_rect().size
	for side in [-1.0,1.0]:
		var pixel: Vector2=room.camera_3d.unproject_position(door.to_global(Vector3(side*(width*.5+.38),1.6,.35)))*scale
		regions.append(Rect2i(Vector2i(pixel)-Vector2i(4,4),Vector2i(8,8)))
	door.open_doors(.15); await frames(25)
	var mask_after: Image=root.get_texture().get_image()
	var ground_pixel: Vector2=room.camera_3d.unproject_position(door.to_global(Vector3(0,0,1.25)))*scale
	var ground_region:=Rect2i(Vector2i(ground_pixel)-Vector2i(4,4),Vector2i(8,8))
	check(luminance(lit_open_image.get_region(ground_region))>luminance(mask_after.get_region(ground_region))+.025,
		"GPU ground pixels outside the doorway brighten from the internal warm light")
	for region in regions:
		check(mask_before.get_region(region).get_data()==mask_after.get_region(region).get_data(),"GPU outside-aperture pixels unchanged when masked leaves retract")
	for material in facade.aperture_materials: material.shader=preload("res://scripts/dream/office_pixel_materials.gd").SHADER
	await frames(4)
	var unmasked: Image=root.get_texture().get_image()
	var exposed:=false
	for region in regions:
		if unmasked.get_region(region).get_data()!=mask_after.get_region(region).get_data(): exposed=true
	check(exposed,"GPU control without the mask exposes steel in the checked outside region")
	for material in facade.aperture_materials:
		material.shader=PROTOTYPE.aperture_shader
		material.set_shader_parameter("world_to_door",door.global_transform.affine_inverse())
		material.set_shader_parameter("aperture_half_width",width*.5-.10)
	door.close_doors(.15); await frames(25)
	facade.get_node("FreightLitRecess").show(); facade.get_node("FreightInteriorLamp").show(); facade.set_process(true)
	# Diagnostic close view: same gameplay camera angle, explicitly changed distance.
	var original_position: Vector3=room.camera_3d.position
	room.camera_3d.position*=.70
	room.camera_rig.global_position=door.global_position+Vector3(0,1.1,0)
	await frames(10); capture("detail_diagnostic")
	room.camera_3d.position=original_position
	var file=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,
		"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,
		"scope":"Actual shared production freight facade in Main lobby. Game camera angle/FOV retained; review focus translated to doorway. Diagnostic close view changes distance. Includes GPU mask and spill checks, not a normal movement test."},"\t"))
	file.close(); print("FREIGHT_PROTOTYPE checks=",checks," failures=",failures)
	main.queue_free(); await process_frame; quit(1 if failures else 0)
