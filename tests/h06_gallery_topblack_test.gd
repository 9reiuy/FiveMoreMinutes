extends "res://tests/h06_hangar_crew_test.gd"
const CAPS := preload("res://scripts/testing/h06_chapter/gallery_top_black.gd")
var collecting:=false
var last_usec:=0
var raw:Array[float]=[]
var metrics:Array[Dictionary]=[]
var reference:Dictionary={}

func tick() -> void:
	var now:=Time.get_ticks_usec()
	if collecting and last_usec>0:raw.append((now-last_usec)*0.001)
	last_usec=now

func open_chapter(save:int, enabled:bool) -> void:
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save,"staff_story":{"scientist_killed":true}})
	world=load(WORLD).instantiate()
	world.generate_on_ready=false
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.set_meta(&"h06_gallery_topblack_enabled",enabled)
	display=load(PREVIEW).instantiate()
	display.preview_mode=false
	display.world=world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	check(world.regenerate(11011),"1-1 generates with topblack="+str(enabled)+" checkpoint="+str(save))
	world._setup_chapter_session()
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1
	world._spotlight_triggered=true
	world.blockout.play_spotlight_reveal(true)
	var receipt:Dictionary=await world.prepare_chapter_streaming()
	check(receipt.get("ready",false),"covered future-region render preparation succeeds")

func signature() -> Dictionary:
	var bodies:Array=[]
	for body in world.blockout.physics_root.get_children():
		if body is StaticBody2D:
			var shape:Shape2D=body.get_child(0).shape
			bodies.append([body.position,body.collision_layer,body.collision_mask,shape.size if shape is RectangleShape2D else str(shape.get_class())])
	var lights:Array=[]
	for light:Light3D in world.find_children("*","Light3D",true,false):
		lights.append([light.position,light.light_color,light.light_energy,light.shadow_enabled])
	var env:Environment=world.get_node("Lighting/WorldEnvironment").environment
	return {"floor_cells":world.floor_cells.duplicate(true),"bodies":bodies,"lights":lights,"ambient":env.ambient_light_energy,"ambient_color":env.ambient_light_color,"background":env.background_color}

func inspect_caps() -> void:
	var area=world.blockout
	var root:Node3D=area.wall_root.get_node_or_null("GalleryTopBlack")
	check(is_instance_valid(root),"1-1 contains its own topblack shell")
	if not is_instance_valid(root):return
	var floors:=CAPS.protected_floors(area.visit)
	for cap:MeshInstance3D in root.get_children():
		check(cap.get_active_material(0)==area.cutout.top_black and cap.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"pure-black coping preserves lighting: "+str(cap.name))
		check(area.cutout._registered.has(cap.get_instance_id()),"coping participates in existing Occlusion Cutout: "+str(cap.name))
		if not cap.has_meta(&"topblack_fragments"):continue
		var clear:=true
		for fragment:Rect2 in cap.get_meta(&"topblack_fragments"):
			for floor:Rect2 in floors:
				var hit:=fragment.intersection(floor)
				if hit.size.x>0.0001 and hit.size.y>0.0001:clear=false
		check(clear,"coping leaves exhibit decks and door mouths open: "+str(cap.name))
		var blocker=area.cutout._blockers.filter(func(b)->bool:return b.visual==cap)[0]
		check(not blocker.faces.is_empty(),"cutout uses the carved mesh instead of its combined bounds: "+str(cap.name))
	check(not root.get_node("PlantNorth").visible and not root.get_node("PlantEast").visible,"secret-room caps begin concealed with the room")
	check(area.secret_roof.visible and area.secret_approach_roof.visible,"opaque roofs conceal the room and access throat when the player is outside")
	area.service_view(true,Vector2(6.0,1.5))
	check(area.under_cover and area.secret_roof.visible and root.get_node("EastFacade").visible,"the under-stair cutaway keeps the exterior and the concealed room roof")
	area.service_view(true,Vector2(16.5,-1.5))
	check(root.get_node("PlantNorth").visible and root.get_node("PlantEast").visible,"entering the hidden room reveals its matching coping")
	check(not area.secret_roof.visible and not area.secret_approach_roof.visible and root.get_node("EastFacade").visible,"entering opens the interior and the approach without removing the facade cap")
	check(area.service_room_view and area.service_entrance_surfaces.keys().any(func(mesh:MeshInstance3D)->bool:
		return mesh.material_overlay==area.service_entrance_shade),"the left entrance fades into the void when seen from inside")
	area.service_view(false,Vector2(5.5,6.0))
	check(not root.get_node("PlantNorth").visible and not root.get_node("PlantEast").visible,"leaving hides the secret-room coping again")
	check(area.secret_roof.visible and area.secret_approach_roof.visible,"leaving restores both opaque roofs")
	check(not area.service_room_view and area.service_entrance_surfaces.keys().all(func(mesh:MeshInstance3D)->bool:
		return mesh.material_overlay==area.service_entrance_surfaces[mesh]),"leaving restores the outside view of the entrance")
	check(world.get_node("Lighting/WorldEnvironment").environment.background_color==Color.BLACK,"outside void joins the black wall crowns")

func inspect_deck_edges() -> void:
	var area = world.blockout
	var deck: MeshInstance3D = area.floor_root.get_node("Base1FHangarPlatform")
	var deck_top := (deck.global_transform * deck.get_aabb()).end.y
	for edge: String in ["BaseEdgeWest","BaseEdgeSouth"]:
		var fascia: MeshInstance3D = area.floor_root.get_node(edge)
		check((fascia.global_transform * fascia.get_aabb()).end.y < deck_top-.01,"the steel fascia is below the walking surface: "+edge)
	var plant: Node3D = area.floor_root.get_node("UnderStairPlantRoom")
	var raised: MeshInstance3D = plant.get_node("RaisedPlantFloor")
	var tile: MeshInstance3D = plant.get_node("PlantFloorTiles")
	check(is_equal_approx((raised.global_transform * raised.get_aabb()).end.y,(tile.global_transform * tile.get_aabb()).position.y),
		"hidden-room tiles have one exposed deck surface")
	var facade: MeshInstance3D = area.wall_root.get_node("EastCorridorOuterShell")
	var inner_panel: MeshInstance3D = area.wall_root.get_node("EastSolidPanel")
	check((inner_panel.global_transform * inner_panel.get_aabb()).end.x < (facade.global_transform * facade.get_aabb()).position.x,
		"the inner panel and the cover at the hidden-room approach have separate end faces")
	if area.visit==PLAN.Visit.GALLERY:
		var end_panels := 0
		for visual: MeshInstance3D in area.wall_root.find_children("*","MeshInstance3D",true,false):
			var bounds := visual.global_transform * visual.get_aabb()
			if absf(bounds.get_center().x-11.45)<.06 and bounds.size.z>2.75 and bounds.size.x<.10:
				end_panels += 1
		check(end_panels==0,"the right spur's dark end has no transverse rail, panel or crossbar")
		check(area.upper_bodies.any(func(body:StaticBody2D)->bool:
			return (body.position/world.CELL_PIXELS).is_equal_approx(Vector2(11.5,6.0))),
			"the original right spur barrier is still present in gameplay")
	else:
		var apron: MeshInstance3D = area.floor_root.get_node("bay_apron")
		var shade := apron.material_overlay as ShaderMaterial
		var edge: Vector4 = shade.get_shader_parameter("west_hangar_edge")
		var outgoing: Vector4 = shade.get_shader_parameter("south_exit")
		var door: Dictionary = PLAN.PASSAGES[PLAN.Visit.EMPTY_HANGAR]
		check(not area.wall_root.has_node("GalleryTopBlack/GroundWest") and edge.w>0.0,"the west edge of the empty hangar uses a floor fade")
		check(is_equal_approx(outgoing.x,door.at.x) and is_equal_approx(outgoing.y,door.width*.5)
			and outgoing.z<outgoing.w and outgoing.w<=door.at.y,"the outgoing fade reaches black before the south floor edge")

func sample(label:String, feet:Vector2) -> void:
	world._place_feet(feet)
	world._sync_height_immediate()
	world.process_mode=Node.PROCESS_MODE_INHERIT
	await frames(90)
	raw=[]
	last_usec=Time.get_ticks_usec()
	collecting=true
	for i in 180:
		world.player.set_scripted_locomotion(Vector2.RIGHT if i<90 else Vector2.LEFT,12.0)
		await physics_frame
	world.player.clear_scripted_locomotion()
	collecting=false
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var sorted:=raw.duplicate()
	sorted.sort()
	metrics.append({"label":label,"frames":raw.size(),"raw_ms":raw.duplicate(),"p50":sorted[int(sorted.size()*.50)],"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted[-1]})
	await photograph(label)

func cross(id:int) -> void:
	var gate:Dictionary=PLAN.PASSAGES[id]
	world.previous_feet=gate.at-gate.forward
	var feet:Vector2=gate.at+gate.forward*(PLAN.ENTRY_DEPTH+.4)
	world._place_feet(feet)
	world._update_passage(feet)

func dispose() -> void:
	display.queue_free()
	await frames(8)

func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(tick)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for save:int in [CHAPTER.Save.ENTRANCE,CHAPTER.Save.RETURN_BAY]:
		for enabled:bool in [false,true]:
			await open_chapter(save,enabled)
			var state:=signature()
			if not enabled:reference=state
			else:
				check(state.floor_cells==reference.floor_cells and state.bodies==reference.bodies,"topblack preserves the exact floor grid and physical collision")
				check(state.lights==reference.lights and state.ambient==reference.ambient and state.ambient_color==reference.ambient_color,"all existing lights shadows and ambient illumination remain identical")
				inspect_caps()
				inspect_deck_edges()
			var prefix:=str(save)+("-caps" if enabled else "-before")
			if save==CHAPTER.Save.ENTRANCE:
				await sample(prefix+"-gallery",Vector2(5.5,0.7))
				await sample(prefix+"-monitor",Vector2(-3.8,-16.0))
			if enabled:
				var old_caps:WeakRef=weakref(world.blockout.wall_root.get_node("GalleryTopBlack"))
				if save==CHAPTER.Save.ENTRANCE:world.checkpoint=CHAPTER.Save.OBSERVATION
				cross(PLAN.Visit.GALLERY if save==CHAPTER.Save.ENTRANCE else PLAN.Visit.EMPTY_HANGAR)
				check(world.blockout.visit==(PLAN.Visit.WEST if save==CHAPTER.Save.ENTRANCE else PLAN.Visit.FREIGHT),"actual outgoing passage still enters the next district")
				check(world.blockout.wall_root.get_node_or_null("GalleryTopBlack")==null,"other districts do not inherit the 1-1 shell")
				var expected_background: Color=Color.BLACK if world.blockout.visit==PLAN.Visit.WEST else reference.background
				check(world.get_node("Lighting/WorldEnvironment").environment.background_color==expected_background,"the west wing gap is black and the freight district restores its own background")
				await dispose()
				check(old_caps.get_ref()==null,"scene exit releases the coping and its registration owner")
			else:await dispose()
	for i in [0,1]:
		check(metrics[i+2].p95<25.0 and metrics[i+2].p99<35.0,"bounded native sample has no sustained rendering slowdown: "+metrics[i+2].label)
	var failures:Array=checks.filter(func(row:Dictionary)->bool:return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_GALLERY_TOPBLACK checks=",checks.size()," failures=",failures.size())
	for metric in metrics:
		var brief:Dictionary=metric.duplicate()
		brief.erase("raw_ms")
		print(JSON.stringify(brief))
	quit(0 if failures.is_empty() else 1)
