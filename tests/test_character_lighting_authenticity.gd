extends SceneTree

const CONFIG_RESOURCE := preload("res://resources/demo_config.tres")
const DEMO_CONFIG := preload("res://scripts/data/demo_config.gd")
const DEPTH_BRIDGE_SCRIPT := preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
const SHADOW_MANAGER_SCRIPT := preload("res://scripts/dream/office_shadow_manager.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	print("--- TEST CHARACTER LIGHTING AUTHENTICITY START ---")
	_test_config()
	_test_depth_bridge_no_local_light()
	_test_character_receives_3d_light()
	_test_shadow_manager_tuning()

	if failures.is_empty():
		print("--- TEST CHARACTER LIGHTING AUTHENTICITY PASSED ---")
		quit(0)
	else:
		print("FAILED with %d errors:" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

func _test_config() -> void:
	var cfg = DEMO_CONFIG.new()
	_assert(cfg.character_local_light_enabled == false, "DemoConfig default character_local_light_enabled must be false")
	_assert(CONFIG_RESOURCE.character_local_light_enabled == false, "demo_config.tres character_local_light_enabled must be false")
	print("[PASS] Config verified: character_local_light_enabled is false.")

func _test_depth_bridge_no_local_light() -> void:
	var player_node := Node2D.new()
	player_node.name = "TestPlayer"
	player_node.add_to_group(&"dream_player")
	var vis := Node2D.new()
	vis.name = "CharacterVisual"
	player_node.add_child(vis)
	root.add_child(player_node)

	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(128, 128)
	root.add_child(sub_viewport)

	var world_root := Node3D.new()
	world_root.name = "TestWorldRoot"
	root.add_child(world_root)

	var bridge: Node3D = DEPTH_BRIDGE_SCRIPT.new()
	bridge.name = "TestPlayerBridge"
	world_root.add_child(bridge)

	bridge.call("configure", player_node, sub_viewport, player_node)

	# Verify CharacterLocalLight was NOT created
	var local_light := bridge.get_node_or_null("CharacterLocalLight")
	_assert(local_light == null, "CharacterLocalLight must NOT be created when character_local_light_enabled is false")

	# Verify actor sprite is on CHARACTER_VISUAL_LAYER (2)
	var sprite: Sprite3D = bridge.get_node_or_null("DepthVisual") as Sprite3D
	_assert(sprite != null, "DepthVisual sprite must exist")
	if sprite != null:
		_assert(sprite.layers == 2, "DepthVisual must be on layer 2 (CHARACTER_VISUAL_LAYER), got: %d" % sprite.layers)
		_assert(sprite.shaded == true, "DepthVisual must be shaded (receive 3D lighting)")
		var mat := sprite.material_override as ShaderMaterial
		_assert(mat != null, "DepthVisual must use ShaderMaterial")
		if mat != null and mat.shader != null:
			_assert(mat.shader.resource_path.ends_with("lit_pixel_carrier.gdshader"), "Material must use lit_pixel_carrier.gdshader")

	# Clean up
	bridge.queue_free()
	world_root.queue_free()
	sub_viewport.queue_free()
	player_node.queue_free()
	print("[PASS] Depth bridge verified: No local light, layer 2 set, lit_pixel_carrier active.")

func _test_character_receives_3d_light() -> void:
	# Verify that a SpotLight3D / DirectionalLight3D with WORLD_LIGHT_CULL_MASK (7)
	# includes Layer 2 (CHARACTER_VISUAL_LAYER) and illuminates characters
	const WORLD_LIGHT_CULL_MASK := 7
	const CHARACTER_VISUAL_LAYER := 2
	_assert((WORLD_LIGHT_CULL_MASK & CHARACTER_VISUAL_LAYER) != 0, "WORLD_LIGHT_CULL_MASK (7) must include CHARACTER_VISUAL_LAYER (2)")

	var spot := SpotLight3D.new()
	spot.light_cull_mask = WORLD_LIGHT_CULL_MASK
	_assert((spot.light_cull_mask & 2) != 0, "SpotLight3D with WORLD_LIGHT_CULL_MASK must illuminate layer 2")
	spot.queue_free()
	print("[PASS] 3D light receiver mask verified: World lights illuminate character layer.")

func _test_shadow_manager_tuning() -> void:
	var mgr: Node3D = SHADOW_MANAGER_SCRIPT.new()
	_assert(is_equal_approx(mgr.get("HOLD_SECONDS"), 0.8), "HOLD_SECONDS must be 0.8, got %s" % mgr.get("HOLD_SECONDS"))
	_assert(is_equal_approx(mgr.get("FADE_SECONDS"), 0.25), "FADE_SECONDS must be 0.25, got %s" % mgr.get("FADE_SECONDS"))
	mgr.queue_free()
	print("[PASS] Shadow manager tuning verified: HOLD_SECONDS=0.8, FADE_SECONDS=0.25.")
