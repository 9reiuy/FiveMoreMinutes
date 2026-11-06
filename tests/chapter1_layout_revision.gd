extends SceneTree
const WALK=preload("res://tests/support/world_walk_input.gd")
const OUT="res://.runtime/visual_overhaul_20261029/layout"
var main: Node
var room: Node
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int=4) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(12)
func key(code: int) -> void:
	if code==KEY_SPACE: Input.action_press("dash")
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true; root.push_input(event,true); await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames(2)
	if code==KEY_SPACE: Input.action_release("dash")
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(OUT+"/"+name+".png")
func walk(point: Vector2) -> void:
	var deadline:=Time.get_ticks_msec()+12000
	while room.player.position.distance_to(point)>10. and Time.get_ticks_msec()<deadline:
		var difference: Vector2=point-room.player.position
		WALK.hold(room.player,Vector2(0 if absf(difference.x)<7 else difference.x,0 if absf(difference.y)<7 else difference.y))
		await physics_frame; await process_frame
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
	await frames()
	check(room.player.position.distance_to(point)<25.,"actual walking reaches "+str(point)+" actual="+str(room.player.position))
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(240,true,false,true).timeout.connect(func(): quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.show_room(false); await settle()
	room=main._supported_dream_world; room.mode="EVENING"
	var bed: Node3D=room.get_node("Furniture/Bed")
	var window: Node3D=room.get_node("Window")
	var cabinet: Node3D=room.get_node("Furniture/Wardrobe")
	var bed_box:=bounds(bed); var window_box:=bounds(window); var cabinet_box:=bounds(cabinet)
	check(bed.position.x< -3. and bed.position.z< -2.5 and is_equal_approx(bed.rotation.y,PI/2),"bed is horizontal in the marked rear-left area")
	check(not window_box.intersects(bed_box),"window clears bed head geometry")
	check(not window_box.intersects(cabinet_box),"window and cabinet geometry do not intersect")
	check(window.position.x< -1.5 and window.position.x> -4. and window.position.z< -4.,"window occupies the marked left section of the north wall")
	check(cabinet_box.end.z<4.43 and cabinet_box.end.x<2.1,"cabinet clears both south wall and entrance")
	var rug_box:=bounds(room.get_node("Furniture/Rug"))
	check(rug_box.position.x<bed_box.position.x and rug_box.end.x>bed_box.end.x and rug_box.position.z<bed_box.position.z and rug_box.end.z>bed_box.end.z,"rug fully covers the bed footprint")
	check(room.get_node("Furniture/Desk").position.x< -4. and room.get_node("Furniture/Chair").position.x< -3.,"desk and chair are on the left")
	check(room.get_node_or_null("BedLight")==null and bounds(room.get_node("Furniture/Nightstand")).end.y<1.2,"bedside light and tall lamp mesh are removed")
	var overlap:=false
	for rib in room.get_node("ArtRevisionRibs").get_children():
		if rib is MeshInstance3D: overlap=overlap or window_box.intersects(rib.global_transform*rib.get_aabb())
	check(not overlap,"window clears industrial ribs and vent slats")
	print("BEDROOM_AABBS ",JSON.stringify({"bed":str(bed_box),"window":str(window_box),"cabinet":str(cabinet_box)}))
	check(not room.panel.status.visible,"bedroom has no permanent upper-left status")
	await snap("bedroom_entry")
	WALK.hold(room.player,Vector2.UP)
	for i in 12:
		await create_timer(.1).timeout; await snap("walk_%02d"%i)
	WALK.release()
	check(room.player.position.y<4.5*32.,"open entrance is physically passable from outside landing")
	await walk(Vector2(2.8,3.10)*32.)
	await key(KEY_E); await create_timer(.5).timeout
	check(not room.entry_open,"E closes actual entrance leaf")
	WALK.hold(room.player,Vector2.DOWN); await create_timer(.7).timeout; WALK.release()
	check(room.player.get_node("CollisionShape2D").global_position.y<4.5*32.,"closed door collision blocks the actual player collider")
	await key(KEY_E); await create_timer(.5).timeout
	check(room.entry_open,"E reopens entrance")
	await walk(Vector2(2.8,5.15)*32.)
	await walk(Vector2(2.8,3.5)*32.)
	await snap("bedroom")
	await walk(Vector2(2.8,1.5)*32.); await walk(Vector2(-2.45,1.5)*32.); await walk(Vector2(-2.45,-1.0)*32.); await key(KEY_E)
	check(room.computer_overlay.visible,"repositioned laptop opens original computer interface")
	check(not room.panel.status.visible and not room.proximity_hint.visible,"computer hides local interaction hints too")
	await snap("laptop_ui")
	room.consume_escape(); await frames(20)
	await walk(Vector2(-1.45,-1.0)*32.); await walk(Vector2(-1.45,-3.1)*32.); await key(KEY_E)
	check(room.medicine_ui.visible,"repositioned bedside medicine remains reachable")
	room.consume_escape(); await frames(5)
	await walk(Vector2(-1.45,-2.5)*32.); await walk(room.destination)
	check(room.selected=="Bed","new bedside interaction is reachable")
	main.chapter_one.state.flow_revision=1; main.chapter_one.state.stage="WAKE"; main.chapter_one.show_room(true); await settle(); room=main._supported_dream_world
	check(room.body.visible and room.body.position.distance_to(room.get_node("Furniture/Bed").position+Vector3(0,.88,0))<.01,"sleeping self follows moved and rotated bed")
	await snap("sleeping_self")
	await walk(Vector2(2.8,1.5)*32.); await walk(Vector2(-1.,1.5)*32.); await walk(Vector2(-1.,-2.5)*32.); await walk(room.destination); await key(KEY_F)
	while not main.chapter_one.state.complete: await process_frame
	await settle(); check(main.chapter_one.state.complete,"F wake works at new bed position")
	await create_timer(1.).timeout
	for panel in main.get_children():
		if panel.get_script()==load("res://scripts/story/chapter_panel.gd") and panel.center.visible: panel.choices.get_child(0).pressed.emit()
	await frames()
	main.chapter_one.state.stage="TUTORIAL"; main.chapter_one.state.complete=false; main.chapter_one.resume(); await settle()
	var tutorial: Node=main._supported_dream_world
	var approved:=0; var old_refs:=0
	var footprints_match:=true
	for prop in tutorial.get_node("TutorialGeometry/ChapterLayout").find_children("*","Node3D",true,false):
		if prop.has_meta("approved_kind"):
			approved+=1
			footprints_match=footprints_match and prop.get_meta("solid_size")==preload("res://scripts/dream/office_furniture_catalog.gd").footprint(prop.get_meta("approved_kind")).size/32.
		if prop.scene_file_path.begins_with("res://scenes/dream/3d/props/"): old_refs+=1
	check(approved==11 and old_refs==0,"tutorial uses approved office meshes and face textures, no old prop prefabs")
	check(footprints_match,"tutorial collisions match current approved furniture footprints")
	check(not tutorial.get_node("ChapterTraining").panel.status.visible,"tutorial upper-left task panel removed")
	await snap("tutorial")
	tutorial.player.set_meta("presentation_pointer_gate",func(): return true)
	room=tutorial; await walk(Vector2(128,21*32.))
	tutorial._spawn_guide_once(); await create_timer(.8).timeout
	await walk(tutorial.guide.position+Vector2(-35,20)); await key(KEY_E)
	var training: Node=tutorial.get_node("ChapterTraining")
	for i in 60:
		if training.stage>=2: break
		await key(KEY_E); await create_timer(.1).timeout
	check(training.stage==2,"registration dialogue unlocks movement corridor")
	await walk(Vector2(224,21*32.))
	await walk(Vector2(352,21*32.))
	await walk(Vector2(352,15*32.))
	await walk(Vector2(128,15*32.))
	await walk(Vector2(128,14.4*32.))
	WALK.hold(tutorial.player,Vector2.UP); await key(KEY_SPACE); await create_timer(.7).timeout; WALK.release(); await frames(10)
	check(training.stage==3,"real walking through first door and dash advance tutorial")
	await walk(Vector2(128,15*32.))
	await walk(Vector2(352,15*32.))
	await walk(Vector2(352,7*32.))
	await walk(Vector2(224,7*32.))
	check(not training._gate("RangeSafety").is_open,"target lane remains physically separated before completion")
	await snap("tutorial_movement")
	# Compare the actual HUD draw before/after clock updates on a frozen world.
	main.current_screen.process_mode=Node.PROCESS_MODE_DISABLED; await frames()
	await RenderingServer.frame_post_draw
	var before: Image=root.get_texture().get_image().get_region(Rect2i(180,35,280,55))
	var layer:=CanvasLayer.new(); main.add_child(layer)
	var hud: Control=load("res://scenes/ui/dream_hud.tscn").instantiate(); layer.add_child(hud); hud.set_clock("12:34"); await frames()
	await RenderingServer.frame_post_draw
	var after: Image=root.get_texture().get_image().get_region(Rect2i(180,35,280,55))
	check(before.get_data()==after.get_data(),"real Dream HUD clock update adds no top-screen pixels")
	await snap("hud_no_clock")
	print("CHAPTER1_LAYOUT_REVISION checks=",checks," failures=",failures," approved_props=",approved)
	main.queue_free(); await frames(); quit(failures)

func bounds(node: Node3D) -> AABB:
	var result:=AABB(); var first:=true
	var meshes:=node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.append(node)
	for mesh in meshes:
		var b: AABB=mesh.global_transform*mesh.get_aabb()
		result=b if first else result.merge(b); first=false
	return result
