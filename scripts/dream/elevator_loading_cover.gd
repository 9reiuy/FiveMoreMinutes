extends CanvasLayer
const PIXEL=preload("res://scripts/ui/pixel_transition.gd")
## Root-output cover owns the pause, including cancellation/world teardown.
## Work may replace the floor token; the transition token must stay unchanged.
var previous_pause := false
var released := false
var owner_reference: WeakRef
var black: ColorRect
var animation_phase:=&"cover"

static func run(tree: SceneTree, world: Node3D, work: Callable, token: int) -> Dictionary:
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
	cover.black = ColorRect.new()
	cover.black.color = Color.BLACK
	cover.black.material=PIXEL.material()
	cover.black.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.add_child(cover.black)
	cover._resize()
	tree.root.size_changed.connect(cover._resize)
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
		cover.animation_phase=&"reveal"
		var animation_ok:=true
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

func _is_current(token: int)->bool:
	var owner: Node=owner_reference.get_ref()
	return not released and is_instance_valid(owner) and owner.is_inside_tree() and owner.transition_generation_token==token

func _resize() -> void:
	if is_instance_valid(black): black.size = get_tree().root.get_visible_rect().size

func _input(_event: InputEvent) -> void:
	# A hidden pause menu must not release or take over the loading pause.
	# The visible cab has no cover and retains normal pause/menu controls.
	get_viewport().set_input_as_handled()

func release() -> void:
	if released: return
	released = true
	var tree := get_tree()
	if tree == null: return
	var owner: Node = owner_reference.get_ref()
	if is_instance_valid(owner) and owner.tree_exiting.is_connected(release): owner.tree_exiting.disconnect(release)
	if tree.root.size_changed.is_connected(_resize): tree.root.size_changed.disconnect(_resize)
	tree.paused = previous_pause
	queue_free()
