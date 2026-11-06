extends CanvasLayer
const PIXEL=preload("res://scripts/ui/pixel_transition.gd")
const CAB = preload("res://scripts/dream/independent_elevator_cab_3d.gd")
## Root-output cover owns the pause, including cancellation/world teardown.
## Work may replace the floor token; the transition token must stay unchanged.
var previous_pause := false
var released := false
var owner_reference: WeakRef
var black: ColorRect
var animation_phase:=&"cover"
var loading_picture: TextureRect
var loading_status: Label
var status_elapsed:=0.0
var live_reference_cab: WeakRef
var solid_hold: ColorRect
const DEPARTURE_IRIS_START := .63

static func run(tree: SceneTree, world: Node3D, work: Callable, token: int, preview: Callable=Callable(), live_cab := false) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
	var cover := new()
	cover.name = "ElevatorLoadingCover"
	cover.layer = 1000
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	cover.previous_pause = tree.paused
	cover.owner_reference = weakref(world)
	var saved_pause := tree.paused
	var reference: WeakRef = cover.owner_reference
	tree.root.add_child(cover)
	cover._install_black()
	world.tree_exiting.connect(cover.release, CONNECT_ONE_SHOT)
	tree.paused = true
	var transition_started:=Time.get_ticks_usec()
	if DisplayServer.get_name()!="headless":
		await PIXEL.animate(cover.black,0,1,PIXEL.COVER_SECONDS,cover._is_current.bind(token))
	if not is_instance_valid(cover): return {"cancelled":true,"cover_released":true,"pause_restored":tree.paused==saved_pause}
	cover.black.material.set_shader_parameter("progress",1.0)
	cover.animation_phase=&"hold"
	var started := Time.get_ticks_usec()
	if DisplayServer.get_name() != "headless":
		for frame in 2: await RenderingServer.frame_post_draw
	var report: Dictionary = {"cancelled":true}
	var current: Node = reference.get_ref()
	# Death retry shows the real cab first, then keeps its already-composited
	# Camera output visible while the SAME world renders the destination behind
	# it. No second gameplay world/player, timer gate, or duplicate palette pass.
	if is_instance_valid(cover) and cover._is_current(token) and preview.is_valid():
		if live_cab and DisplayServer.get_name() != "headless":
			cover._hold_departure_black()
		preview.call()
		if live_cab and is_instance_valid(current.active_transition_cab):
			var cab: Node3D = current.active_transition_cab
			cover.live_reference_cab = weakref(cab)
			cab.reference_view_ending.connect(cover._hold_cab_picture.bind(false), CONNECT_ONE_SHOT)
		if DisplayServer.get_name()!="headless":
			await PIXEL.present(tree,2)
			if is_instance_valid(cover) and cover._is_current(token):
				if live_cab and cover.live_reference_cab != null:
					var cab: Node3D = cover.live_reference_cab.get_ref()
					cover.animation_phase = &"cab_preparing"
					cover.black.material.set_shader_parameter("progress", DEPARTURE_IRIS_START)
					var prepared := await CAB.prepare_reference_departure(cab, cover._is_current.bind(token))
					if not is_instance_valid(cover) or not cover._is_current(token):
						if is_instance_valid(cover):
							cover.release()
						return {"cancelled":true,"cover_released":not is_instance_valid(cover) or cover.released,"pause_restored":tree.paused==saved_pause}
					if prepared:
						cab.set_reference_cover_motion(not saved_pause)
						cover.animation_phase = &"cab_live"
						cover.solid_hold.hide()
						await cover._reveal_live_cab(token)
					else:
						# A valid load can still finish if the visual Camera is unavailable.
						cover.animation_phase = &"cab_preparation_unavailable"
						cover.black.material.set_shader_parameter("progress", 1.0)
				else:
					if is_instance_valid(cover.solid_hold): cover.solid_hold.hide()
					await PIXEL.animate(cover.black,1,0,PIXEL.REVEAL_SECONDS,cover._is_current.bind(token))
					await PIXEL.present(tree)
					if is_instance_valid(cover) and cover._is_current(token): cover._hold_cab_picture()
		current = reference.get_ref()
	if is_instance_valid(current) and current.is_inside_tree() and current.transition_generation_token == token and work.is_valid():
		report = await work.call()
	current = reference.get_ref()
	if not is_instance_valid(current) or not current.is_inside_tree():
		report["cancelled"] = true
	elif current.transition_generation_token != token:
		report["cancelled"] = true
	report["covered_elapsed_ms"]=(Time.get_ticks_usec()-started)/1000.0
	var was_cancelled: bool=bool(report.get("cancelled",true))
	if is_instance_valid(cover) and (not was_cancelled or bool(report.get("rolled_back",false))):
		if is_instance_valid(cover.solid_hold): cover.solid_hold.hide()
		var animation_ok:=true
		if live_cab and is_instance_valid(cover.loading_picture):
			animation_ok = await cover._reveal_arrival(token)
		else:
			if is_instance_valid(cover.loading_picture):
				await PIXEL.animate(cover.black,0,1,PIXEL.COVER_SECONDS,cover._is_current.bind(token))
				if is_instance_valid(cover):
					cover.loading_picture.hide()
					if is_instance_valid(cover.loading_status): cover.loading_status.hide()
			if not is_instance_valid(cover): return {"cancelled":true,"cover_released":true,"pause_restored":tree.paused==saved_pause}
			cover.animation_phase=&"reveal"
			if DisplayServer.get_name()!="headless":
				animation_ok=await PIXEL.animate(cover.black,1,0,PIXEL.REVEAL_SECONDS,cover._is_current.bind(token))
		report["cancelled"]=was_cancelled or not animation_ok or not is_instance_valid(cover) or not is_instance_valid(reference.get_ref())
	if is_instance_valid(cover): cover.release()
	for frame in 2: await tree.process_frame
	report["transition_elapsed_ms"]=(Time.get_ticks_usec()-transition_started)/1000.0
	report["animation_seconds"]=PIXEL.COVER_SECONDS+PIXEL.REVEAL_SECONDS if DisplayServer.get_name()!="headless" else 0.0
	report["cover_released"] = not is_instance_valid(cover)
	report["pause_restored"] = tree.paused == saved_pause
	return report

static func play_reception_departure(main: Node, source: Node3D, current: Callable) -> bool:
	var cab: Node3D = source.entry_cab
	if not is_instance_valid(cab):
		return false
	if DisplayServer.get_name() == "headless":
		cab.begin_reference_ride(0, false, source.camera_3d)
		return true
	var cover := new()
	cover.name = "ReceptionDepartureCover"
	cover.layer = 1000
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(cover)
	cover._install_black()
	var covered := await PIXEL.animate(cover.black, 0.0, 1.0, PIXEL.COVER_SECONDS, current)
	if not covered or not is_instance_valid(cover) or not is_instance_valid(cab) or not bool(current.call()):
		if is_instance_valid(cover):
			cover.queue_free()
		return false
	await RenderingServer.frame_post_draw
	if not is_instance_valid(cover) or not is_instance_valid(cab) or not bool(current.call()):
		if is_instance_valid(cover):
			cover.queue_free()
		return false
	cover._hold_departure_black()
	cover.animation_phase = &"cab_preparing"
	cover.black.material.set_shader_parameter("progress", DEPARTURE_IRIS_START)
	# The reception Camera's normal rig must not overwrite the sampled cab poses.
	var source_process := source.is_processing()
	source.set_process(false)
	cab.begin_reference_ride(0, false, source.camera_3d, true)
	var prepared := await CAB.prepare_reference_departure(cab, current)
	if is_instance_valid(source):
		source.set_process(source_process)
	if not prepared or not is_instance_valid(cover) or not is_instance_valid(cab) or not bool(current.call()):
		if is_instance_valid(cover):
			cover.queue_free()
		return false
	cab.start_reference_departure()
	cover.animation_phase = &"cab_live"
	cover.solid_hold.hide()
	var revealed := await PIXEL.animate(cover.black, DEPARTURE_IRIS_START, 0.0, PIXEL.REVEAL_SECONDS, current)
	if is_instance_valid(cover):
		cover.queue_free()
	return revealed and is_instance_valid(cab)

func _install_black() -> void:
	black = ColorRect.new()
	black.color = Color.BLACK
	black.material = PIXEL.material()
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	_resize()
	get_tree().root.size_changed.connect(_resize)

func _hold_cab_picture(with_status := true) -> void:
	if DisplayServer.get_name() == "headless" or (is_instance_valid(solid_hold) and solid_hold.visible):
		return
	var owner: Node = owner_reference.get_ref()
	var viewport: Viewport = get_tree().root
	if not with_status and is_instance_valid(owner) and float(black.material.get_shader_parameter("progress")) > .05:
		# If generation finished during the concurrent mask, sample the real
		# cab viewport below the temporary mask so the held frame stays readable.
		viewport = owner.get_viewport()
	var captured := viewport.get_texture().get_image()
	if captured==null or captured.is_empty():
		black.material.set_shader_parameter("progress",1.0)
		return
	loading_picture=TextureRect.new()
	loading_picture.name="RestartElevatorView"
	loading_picture.texture=ImageTexture.create_from_image(captured)
	loading_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	loading_picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	loading_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(loading_picture)
	move_child(loading_picture,0)
	if with_status:
		loading_status=Label.new()
		loading_status.name="RestartLoadingStatus"
		loading_status.text="正在准备楼层"
		loading_status.add_theme_font_override("font",PixelFont.get_font())
		loading_status.add_theme_font_size_override("font_size",12)
		loading_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		loading_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(loading_status)
	move_child(black,get_child_count()-1)
	_resize()
	animation_phase=&"cab_loading"
	if not with_status:
		black.hide()

func _hold_departure_black() -> void:
	solid_hold = ColorRect.new()
	solid_hold.name = "SolidDepartureHold"
	solid_hold.color = Color.BLACK
	solid_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(solid_hold)
	_resize()

func _reveal_live_cab(token: int) -> void:
	# Open on the first propulsion beat. Finish the existing iris before
	# the synchronous stage can stall the visible light and camera movement.
	await PIXEL.animate(black, DEPARTURE_IRIS_START, 0.0, PIXEL.REVEAL_SECONDS, _is_live_cab.bind(token))

func _is_live_cab(token: int) -> bool:
	return animation_phase == &"cab_live" and _is_current(token)

func _reveal_arrival(token: int) -> bool:
	animation_phase = &"reveal"
	var tree := get_tree()
	var started := Time.get_ticks_usec()
	while _is_current(token):
		var progress := clampf((Time.get_ticks_usec() - started) / (PIXEL.REVEAL_SECONDS * 1000000.0), 0.0, 1.0)
		loading_picture.modulate.a = 1.0 - smoothstep(0.0, 1.0, progress)
		if progress >= 1.0:
			return true
		await tree.process_frame
	return false

func _process(delta:float)->void:
	if not is_instance_valid(loading_status) or not loading_status.visible:return
	status_elapsed+=delta
	loading_status.text="正在准备楼层"+".".repeat(int(status_elapsed/0.4)%4)

func _is_current(token: int)->bool:
	var owner: Node=owner_reference.get_ref()
	return not released and is_instance_valid(owner) and owner.is_inside_tree() and owner.transition_generation_token==token

func _resize() -> void:
	if is_instance_valid(black): black.size = get_tree().root.get_visible_rect().size
	if is_instance_valid(solid_hold): solid_hold.size = get_tree().root.get_visible_rect().size
	if is_instance_valid(loading_picture): loading_picture.size=get_tree().root.get_visible_rect().size
	if is_instance_valid(loading_status):
		var size:=get_tree().root.get_visible_rect().size
		loading_status.position=Vector2(0,size.y*.70)
		loading_status.size=Vector2(size.x,24)

func _input(_event: InputEvent) -> void:
	# A hidden pause menu must not release or take over the loading pause.
	# This includes the retry cab preview; free-roam cab input lives elsewhere.
	get_viewport().set_input_as_handled()

func release() -> void:
	if released: return
	released = true
	var tree := get_tree()
	if tree == null: return
	var owner: Node = owner_reference.get_ref()
	if live_reference_cab != null:
		var cab: Node3D = live_reference_cab.get_ref()
		if is_instance_valid(cab): cab.set_reference_cover_motion(false)
	if is_instance_valid(owner) and owner.tree_exiting.is_connected(release): owner.tree_exiting.disconnect(release)
	if tree.root.size_changed.is_connected(_resize): tree.root.size_changed.disconnect(_resize)
	tree.paused = previous_pause
	queue_free()
