extends SceneTree
## Regression for the two symptoms one bug produced: the last plume froze on screen
## when a run ended, and a stale plume was already sitting there when the next run
## started. Both came from the overlay living outside the dream world, so it was
## never freed with it. SelectivePixelPreview reparents every CanvasLayer it finds
## inside the world onto the root canvas unless the layer opts out with
## world_post_effect, so "parented to the smoke node" alone is not enough: this test
## lets the preview run its reparent pass and then tears the world down.
## Mirrors tests/selective_pixel_formal_wrapper_test.gd for the headless setup.

var checks := 0
var failures: Array[String] = []

const SCENE := "res://scenes/dream/Dream3D_RandomDungeon.tscn"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


## The display wrapper is what owns the world viewport and the reparent pass, so the
## test has to build one exactly like the game does instead of a bare world.
func build_wrapper(world: Node3D) -> Control:
	var wrapper := Control.new()
	wrapper.set_script(load("res://scripts/dream/preview/selective_pixel_preview.gd"))
	wrapper.preview_mode = false
	wrapper.muted = false
	wrapper.initial_selective_enabled = false
	wrapper.world = world
	root.add_child(wrapper)
	return wrapper


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)
	var world: Node3D = (load(SCENE) as PackedScene).instantiate()
	world.generate_on_ready = false
	var wrapper := build_wrapper(world)
	await frames(6)
	var smoke: Node3D = world._muzzle_smoke()
	smoke.burst(world.get_gameplay_world_position(Vector2.ZERO, 0.72), Vector3(1, 0, 0))
	await frames(8)
	var overlay: CanvasLayer = smoke.overlay
	check(overlay != null and is_instance_valid(overlay), "A shot builds a muzzle overlay")
	if overlay == null or not is_instance_valid(overlay):
		_print_result(1); return
	var live := 0
	for sprite in smoke.fills:
		if sprite.visible: live += 1
	check(live > 0, "The burst is really on screen before teardown")
	check(overlay.get_parent() == smoke, "Overlay is parented to the smoke node")
	check(world.is_ancestor_of(overlay), "Overlay survives the preview reparent pass inside the world")
	check(bool(overlay.get_meta(&"world_post_effect", false)), "Overlay opts out of crisp HUD reparenting")
	check(overlay.get_viewport() == wrapper.world_viewport, "Overlay draws into the world viewport, above the palette")
	check(overlay.layer > 18, "Overlay sits above the palette layer")

	# End the run: the world goes away, the display stays. Anything that outlives the
	# world is what froze the plume on screen and carried it into the next run.
	world.free()
	await frames(4)
	check(root.find_child("MuzzleSmokeOverlay", true, false) == null, "No muzzle overlay survives the freed world")

	# And a fresh run must start clean, not inherit the previous plume.
	var world2: Node3D = (load(SCENE) as PackedScene).instantiate()
	world2.generate_on_ready = false
	var wrapper2 := build_wrapper(world2)
	await frames(6)
	check(root.find_child("MuzzleSmokeOverlay", true, false) == null, "A new run starts with no leftover muzzle overlay")
	wrapper.free()
	wrapper2.free()
	await frames(2)
	_print_result(0)


func _print_result(code: int) -> void:
	print("MUZZLE_SMOKE_LIFECYCLE checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(1 if failures.size() else code)
