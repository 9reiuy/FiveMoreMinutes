extends SceneTree
## Final composed Camera RGB, with paired floor-only masks to exclude objects/UI.
const OUT := "res://.runtime/art_revision_20261102/floor_review"
var main: Node
var world: Node
var checks := 0
var failures: Array[String] = []
var samples: Array = []
func _initialize() -> void: call_deferred("run")
func frames(n := 8) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func settle() -> void:
	while main.transition_running: await process_frame
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	await frames(50)
func shot(label: String) -> Image:
	await frames(8); await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image()
	im.save_png(OUT+"/"+label+".png")
	return im
func measure(label: String) -> void:
	world.player.set_physics_process(false); world._update_camera_and_actor_projection(0.)
	await frames(15)
	var mode: int=world.process_mode; world.process_mode=Node.PROCESS_MODE_DISABLED
	var actual:=await shot(label)
	var originals: Array=[]
	for mesh in world.floor_root.get_children():
		if not mesh is MeshInstance3D or not String(mesh.name).begins_with("FloorBatch_"): continue
		originals.append([mesh,mesh.material_override])
		if originals.size()==1:
			var material: Material=mesh.get_active_material(0)
			if material is ShaderMaterial: FileAccess.open(OUT+"/"+label+"_floor.gdshader",FileAccess.WRITE).store_string(material.shader.code)
	var shader:=Shader.new(); shader.code="shader_type spatial; render_mode unshaded, fog_disabled; uniform vec4 marker : source_color; void fragment(){ ALBEDO=marker.rgb; }"
	var mat:=ShaderMaterial.new(); mat.shader=shader
	for pair in originals: pair[0].material_override=mat
	mat.set_shader_parameter("marker",Color.WHITE); var white:=await shot(label+"_white_mask")
	mat.set_shader_parameter("marker",Color.BLACK); var black:=await shot(label+"_black_mask")
	for pair in originals: pair[0].material_override=pair[1]
	world.process_mode=mode
	var mask:=Image.create(actual.get_width(),actual.get_height(),false,Image.FORMAT_RGB8)
	var peak:=0.; var count:=0; var over:=0
	# Erode by 2 output pixels; keep only pixels where the floor marker fully
	# replaces all RGB channels. Opaque furniture, walls, actors and UI fail it.
	for y in range(4,actual.get_height()-35,2):
		for x in range(4,actual.get_width()-4,2):
			var eligible:=true
			for offset in [Vector2i.ZERO,Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2)]:
				var p: Vector2i=Vector2i(x,y)+offset; var delta:=white.get_pixelv(p)-black.get_pixelv(p)
				if minf(delta.r,minf(delta.g,delta.b))<.55: eligible=false; break
			if not eligible: continue
			var c:=actual.get_pixel(x,y); var value:=maxf(c.r,maxf(c.g,c.b))
			peak=maxf(peak,value); count+=1
			if value>.68: over+=1
			mask.set_pixel(x,y,Color.RED if value>.68 else Color.GREEN)
	mask.save_png(OUT+"/"+label+"_samples.png")
	samples.append({"frame":label,"samples":count,"peak_srgb":peak,"over_0_68":over})
	check(count>100,"floor mask has enough visible samples: "+label)
	check(over==0,"floor rendered RGB <= 0.68: %s peak=%.4f samples=%d over=%d"%[label,peak,count,over])
func key_e() -> void:
	var event:=InputEventKey.new(); event.physical_keycode=KEY_E; event.keycode=KEY_E; event.pressed=true
	root.push_input(event,true); await frames(2); event=event.duplicate(); event.pressed=false; root.push_input(event,true)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	create_timer(300.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	while main.transition_running: await process_frame
	await frames(50)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new()
	main.chapter_one.state.seed=42001; main.chapter_one.state.stage="ASCENT"; main.chapter_one.state.floor=2
	main.chapter_one.resume(); await settle()
	world.player.invulnerability_left=999.
	var adapter: Node=world.get_node("ChapterOneRun")
	world.player.global_position=adapter.terminal_position+Vector2(0,70)
	for palette in [1,2]:
		root.get_node("SettingsManager").set_palette_scheme(palette)
		await measure("rest_palette%d"%palette)
	check(not adapter.maintenance_site.is_empty(),"rest floor retains a legal anchored maintenance bay")
	await key_e(); await frames(3)
	check(adapter.panel.center.visible,"real E opens maintenance choices")
	if adapter.panel.center.visible:
		adapter.panel.choices.get_child(0).pressed.emit(); await frames(3)
		check(main.chapter_one.state.build=="damage" and not paused,"maintenance choice commits and restores input")
	var inspected:=0
	for room in world.rooms:
		if room.id==world.current_room_id or room.get("room_type","")=="corridor": continue
		var bounds: Rect2=world._room_bounds_pixels(room.id,0.)
		world.player.global_position=bounds.get_center()
		world.set_current_room_id(room.id); world._rebuild_active_room_presentation(); world.activate_room(room.id)
		await frames(30)
		for palette in [1,2]:
			root.get_node("SettingsManager").set_palette_scheme(palette)
			await measure("room%d_palette%d"%[room.id,palette])
		inspected+=1
		if inspected>=2: break
	var screens:=0; var standby:=0
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		if not bool(mesh.get_meta(&"standby_screen_eligible",false)): continue
		var material: ShaderMaterial=mesh.material_override as ShaderMaterial
		if material==null: continue
		if bool(mesh.get_meta(&"standby_screen")):
			standby+=1
			check(material.get_shader_parameter("standby_screen_enabled")==true,"selected monitor retains standby after material processing")
			check(material.get_shader_parameter("standby_screen_rect")!=Vector4.ZERO,"standby mask targets the rebaked screen face")
		screens+=1
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"floor":samples,"marked_meshes":screens,"standby_screens":standby,"scope":"Three actual seeded floor Camera views, palette 1 and 2, final composed 8-bit display RGB. Paired black/white floor material masks, cross-eroded two pixels. Not an all-map/all-light proof."},"\t"))
	main.queue_free(); await frames(10)
	quit(0 if failures.is_empty() else 1)
