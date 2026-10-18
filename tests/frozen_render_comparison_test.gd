extends SceneTree
const FREEZE = preload("res://tests/support/frozen_render_comparison.gd")
const BRIDGE_PARITY = preload("res://tests/support/bridge_transform_camera_parity.gd")
const VOLUME_DIAG = preload("res://tests/support/volume_shadow_draw_diagnostic.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var original_scale := Engine.time_scale
	var original_pause := paused
	var node := Node.new()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(node)
	var particles := CPUParticles3D.new()
	particles.speed_scale = .35
	particles.emitting = false
	node.add_child(particles)
	var frozen := FREEZE.freeze(self)
	check(Engine.time_scale == 0.0 and paused, "Shader scaled_step and gameplay freeze")
	check(node.process_mode == Node.PROCESS_MODE_DISABLED and particles.speed_scale == 0.0, "Always processing and CPU particles freeze")
	FREEZE.restore(self, frozen)
	check(Engine.time_scale == original_scale and paused == original_pause, "Original time and pause restore")
	check(node.process_mode == Node.PROCESS_MODE_ALWAYS and is_equal_approx(particles.speed_scale, .35), "Original mode and speed restore")
	var first := Image.create(7, 5, false, Image.FORMAT_RGBA8)
	first.fill(Color.BLACK)
	var second := first.duplicate() as Image
	check(FREEZE.difference(first, second).exact, "Exact image control")
	second.set_pixel(2, 1, Color.RED)
	second.set_pixel(4, 3, Color.BLUE)
	var diff: Dictionary = FREEZE.difference(first, second)
	check(not diff.exact and diff.changed_bytes == 2 and diff.changed_pixels == 2 and diff.bbox == [2, 1, 3, 3], "Exact byte and pixel differences with bounding box")
	node.free()
	print("Frozen render comparison: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
