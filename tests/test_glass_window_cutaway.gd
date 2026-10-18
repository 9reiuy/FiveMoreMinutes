extends SceneTree

const WINDOW_SCRIPT := preload("res://scripts/dream/breakable_glass_window_3d.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("TEST FAILED: %s" % msg)
		quit(1)
	else:
		print("TEST PASSED: %s" % msg)

func _run_tests() -> void:
	print("--- Running Glass Window Cutaway Tests ---")
	var window = WINDOW_SCRIPT.new()
	root.add_child(window)

	var dummy_parent := Node2D.new()
	root.add_child(dummy_parent)

	var edge := {"axis": "H", "x": 10, "y": 10}
	window.configure_window(edge, "10_10_H", 2.6, 0.125, dummy_parent)

	# 1. Initial state checks
	_assert(window.cutaway_mode == false, "Initial cutaway_mode is false")
	_assert(window.frame_root != null, "frame_root is initialized")
	_assert(window.frame_root.visible == true, "frame_root is initially visible")
	_assert(window.cutaway_caps.is_empty(), "cutaway_caps initially empty")
	_assert(window.glass_pane != null, "glass_pane is created")
	_assert(window.glass_pane.visible == true, "glass_pane is initially visible")

	# 2. Enable cutaway mode
	window.set_cutaway_mode(true)
	_assert(window.cutaway_mode == true, "cutaway_mode is now true")
	_assert(window.cutaway_caps.size() == 2, "cutaway_caps has exactly 2 elements (dual side posts)")
	_assert(window.cutaway_caps[0].visible == true, "cutaway_caps[0] is visible")
	_assert(window.cutaway_caps[1].visible == true, "cutaway_caps[1] is visible")

	# Check post cap positions: -0.475 and +0.475
	var cap0 = window.cutaway_caps[0]
	var cap1 = window.cutaway_caps[1]
	_assert(is_equal_approx(cap0.position.x, -0.475), "Cap 0 X position is -0.475 (got %f)" % cap0.position.x)
	_assert(is_equal_approx(cap1.position.x, 0.475), "Cap 1 X position is 0.475 (got %f)" % cap1.position.x)

	# Check that NO 1.0m width cap exists
	var all_caps := 0
	for child in window.get_children():
		if child is MeshInstance3D and child.name.begins_with("ArchitecturalCutSurface"):
			all_caps += 1
	_assert(all_caps == 2, "Window has exactly 2 cut surfaces, no full-width overlay")

	# Check glass shader cutaway parameter
	var glass_mat := window.glass_pane.material_override as ShaderMaterial
	_assert(glass_mat != null, "Glass pane has ShaderMaterial")
	_assert(glass_mat.get_shader_parameter("architecture_cutaway") == true, "architecture_cutaway uniform is true on glass pane")

	# 3. Disable cutaway mode
	window.set_cutaway_mode(false)
	_assert(window.cutaway_mode == false, "cutaway_mode is false")
	_assert(window.cutaway_caps[0].visible == false, "cutaway_caps[0] is hidden")
	_assert(window.cutaway_caps[1].visible == false, "cutaway_caps[1] is hidden")
	_assert(glass_mat.get_shader_parameter("architecture_cutaway") == false, "architecture_cutaway uniform is false on glass pane")

	# Re-enable cutaway mode before shatter
	window.set_cutaway_mode(true)
	_assert(window.cutaway_caps[0].visible == true, "cutaway_caps[0] re-enabled")

	# 4. Shatter window
	window.shatter(Vector2.RIGHT)
	_assert(window.is_shattered == true, "Window is marked shattered")
	_assert(window.glass_pane.visible == false, "glass_pane is hidden after shatter")
	_assert(window.frame_root.visible == false, "frame_root is hidden after shatter")
	_assert(window.cutaway_caps[0].visible == false, "cutaway_caps[0] is hidden after shatter")
	_assert(window.cutaway_caps[1].visible == false, "cutaway_caps[1] is hidden after shatter")

	# Late set_cutaway_mode call does not resurrect caps after shatter
	window.set_cutaway_mode(true)
	_assert(window.cutaway_caps[0].visible == false, "cutaway_caps remain hidden even if set_cutaway_mode(true) called post-shatter")

	print("--- All Glass Window Cutaway Tests PASSED! ---")
	window.queue_free()
	dummy_parent.queue_free()
	quit(0)
